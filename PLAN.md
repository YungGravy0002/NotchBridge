# Notch Usage App — Research & Implementation Plan (v0.1, for review)

Status: DRAFT for Alec's review. Nothing has been built. Edit freely; execution starts only after sign-off.

---

## 0. One-paragraph summary

Fork CodexIsland (MIT, ~14.7k Swift LOC, bare `swiftc` build, no Xcode project) into a new GitHub repo, strip it to Claude + Codex, and add three features on top of its existing notch rendering and quota polling: (1) live per-session state driven by Claude Code HTTP hooks and Codex command hooks, (2) a multi-session view (one pip per running agent, click to focus its terminal), and (3) per-project and per-model cost from local transcripts. All of it stays local; no new model calls are introduced, and the one existing automatic model call in CodexIsland (a Haiku token-refresh ping) is removed.

---

## 1. Decisions already made

| Decision | Choice | Why |
|---|---|---|
| Base | Fork `ericjypark/codex-island` | Notch geometry, keychain reads, Codex auth, cost pipeline, SQLite ledger already solved and tested |
| Providers | Claude + Codex only | Grok/Antigravity add ~20 files of switch cases with no value to you |
| v1 features | Live session state, multi-session view, per-project/per-model cost | Your selection |
| Deferred | Burn rate/forecast, routing hints, compaction warnings, reset notifications, task completion feed, sub-agent tree | Post-v1 |
| Repo | New GitHub repo you own; builds on your Mac | Swift for macOS cannot compile in the cloud workspace |

Open decisions for you are collected in §9.

---

## 2. What the research established (verified against primary sources)

### 2.1 CodexIsland internals (from the cloned source, main @ 2026-09-10)

- Build: `build.sh` compiles every file under `Sources/` with one `swiftc` invocation per arch, `lipo`s a universal binary, hand-writes `Info.plist`, targets macOS 13+. No SwiftPM, no `.xcodeproj`. Xcode Command Line Tools suffice.
- Tests: `scripts/run-tests.sh` — 24 standalone test binaries, each hand-listing its source files. No XCTest.
- Window: `BorderlessFloatingWindow` (NSWindow, 900×360, `.popUpMenu` level, all spaces), centered on the target screen's top edge. Handles no-notch Macs and external displays via `NotchInfo.detect` fallback.
- State: `UsageStore` (`Sources/Usage/UsageStore.swift`) polls quota every 5/15/30 min (5-min floor) and publishes `claude`/`codex` `AppUsage` values. Views observe it.
- Layout: `ProviderVisibilityStore.selected` is an ordered array; `left = selected[0]`, `right = selected[1]`. **Default is Claude left, Codex right, and there is already a `swap()`.** So your left/right requirement is met out of the box and is user-configurable.
- Pages: `ScreenPref.Screen { usage, cost, overview }` drives a swipeable `PagedContent`. Adding a page = new enum case + view + one hard-coded shortcut array in `IslandWindowController.swift:164`.
- Cost: `ClaudeLogReader` parses `~/.claude/projects/**/*.jsonl` (assistant records only; dedupe on `message.id:requestId`). `CodexLogReader` parses `~/.codex/sessions/**/rollout-*.jsonl` `token_count` events. **Per-model breakdown exists. Per-project does not** — the readers discard `cwd`/`sessionId` even though Claude's JSONL carries them. History persists in a SQLite ledger.
- Infrastructure gaps: **no file watching** (everything is mtime-polled), **no IPC/HTTP listener**, **no hook receiver**. All three are greenfield.
- Fork hazards: Sparkle auto-update key + feed URL point at upstream (`build.sh:33,35`); bundle ID `dev.codexisland.CodexIsland` also names the SQLite dir; UserDefaults keys carry a stale `MacIsland.` prefix.
- Removed in fork: `ClaudeCredentials.spawnTokenRefreshPing()` (the `claude -p ok --model haiku` call).

### 2.2 Claude Code hooks (code.claude.com/docs/en/hooks — verified 2026-09-13)

- **HTTP handler type exists**: `{"type":"http","url":"http://127.0.0.1:PORT/hook"}` POSTs the same JSON body a command hook would get on stdin. This is the cleanest integration: no shell script, no process spawn per event.
- Events relevant to v1: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `Notification` (`notification_type: permission_prompt | idle_prompt | …`), `Stop`, `StopFailure`, `SubagentStart`, `SubagentStop`, `PreCompact`, `PostCompact`, `SessionEnd`.
- Every payload carries `session_id`, `transcript_path`, `cwd`, `hook_event_name`, `permission_mode`.
- **`PermissionRequest` cannot block** (exit 2 not honored) — safe for pure observation. `PostToolUse` etc. also non-blocking. `PreToolUse`, `UserPromptSubmit`, `Stop` *can* block on exit 2 / decision JSON, so our handler must always return 200 with an empty body and never emit a decision.
- **Hooks merge across settings levels**; user + project hooks both run. We write into `~/.claude/settings.json` by JSON-merging a new entry, never overwriting.
- Statusline stdin (documented) is the richest per-session live feed: `session_id`, `model`, `workspace.current_dir`, `cost.total_cost_usd`, `context_window.used_percentage`, `rate_limits.{five_hour,seven_day}.{used_percentage,resets_at}`. Worth tapping as a second signal (see §5.2).
- **Not documented**: the transcript JSONL record schema (`message.usage.*`, `requestId`, `isSidechain`) — observed only. Also `api.anthropic.com/api/oauth/usage` is undocumented. Both already underpin CodexIsland; we inherit that risk, not add to it.
- **Documented pitfall**: per-record `output_tokens` in transcripts is a placeholder (set at `message_start`); summing it undercounts. Input and cache tokens deduped by message id are accurate. CodexIsland inherits this inaccuracy today.

### 2.3 Codex CLI hooks (learn.chatgpt.com/docs/hooks — verified 2026-09-13)

- Events: `SessionStart`, `SessionEnd`, `SubagentStart`, `SubagentStop`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PreCompact`, `PostCompact`, `UserPromptSubmit`, `Stop`, `Interrupt`.
- Config: `~/.codex/hooks.json` or `[hooks]` in `~/.codex/config.toml`. Handler types: **`command` and `mcp_tool` only — no HTTP.** Payload is one JSON object on stdin with `session_id`, `transcript_path`, `cwd`, `hook_event_name`, `model`, plus `turn_id`/`permission_mode` on turn-scoped events.
- **Trust gate**: "Before a non-managed hook can run, Codex requires you to review and trust the exact hook definition" via `/hooks`. Our installer cannot silently enable Codex hooks; the app must tell you to approve once.
- `SessionEnd`/`Interrupt` hooks have a 1s default timeout (3s max) — the forwarder must be fast (a `curl` to localhost is fine).
- Codex rollout logs and the `wham/usage` endpoint are undocumented; the `token_count` event is absent from `codex exec` (non-interactive) sessions, so Codex cost will only cover interactive runs. CodexIsland has the same limit.

---

## 3. Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  Notch app (forked CodexIsland, Swift/SwiftUI, LSUIElement)      │
│                                                                  │
│  UsageStore ──(quota poll, unchanged)──► Usage page               │
│  CostStore  ──(extended: +cwd,+sessionId)──► Cost page            │
│  SessionStore (NEW) ◄── HookServer (NEW, localhost HTTP)          │
│       │                       ▲                                  │
│       ▼                       │ POST /hook  (JSON)               │
│  Sessions page (NEW) + compact-state pips                         │
└───────────────────────────────┼──────────────────────────────────┘
                                │
        ┌───────────────────────┴──────────────────────────┐
        │                                                  │
  Claude Code                                         Codex CLI
  ~/.claude/settings.json                             ~/.codex/hooks.json
  hooks: type "http" → localhost:PORT/hook            hooks: type "command" →
  (native, no script)                                 `notch-forward` tiny binary/script
                                                      that pipes stdin to localhost:PORT/hook
```

### 3.1 HookServer
- `NWListener` (Network.framework) on `127.0.0.1`, fixed port (default 47777, configurable), minimal HTTP/1.1 parser — only `POST /hook`, `GET /health`. No third-party dependency; keeps the bare-`swiftc` build.
- Always responds `200` with empty body within milliseconds. Never returns a decision object. If the app is not running, Claude Code hooks fail non-blocking (connection refused → logged, action proceeds). Verify this in Phase 2.
- Optional shared secret header (`X-Notch-Token`) written into the hook config at install; rejects requests without it. Cheap defense against other local processes injecting fake state.

### 3.2 SessionStore
State machine per `(provider, session_id)`:

| Event | New state |
|---|---|
| `SessionStart` | `idle` (record cwd, model, transcript_path, start time) |
| `UserPromptSubmit` | `thinking` |
| `PreToolUse` | `tool(name)` |
| `PermissionRequest`, or `Notification[permission_prompt]` | `waiting_permission(tool)` — **alert state** |
| `PostToolUse` / `PostToolUseFailure` | `thinking` |
| `PreCompact` | `compacting` |
| `PostCompact` | previous state |
| `Stop` | `done` (keep `last_assistant_message` preview) → `idle` after N s |
| `StopFailure[rate_limit]` | `rate_limited` — alert state |
| `Notification[idle_prompt]` | `idle_waiting_input` |
| `SessionEnd`, or no event for T min (default 30) | remove |
| `SubagentStart`/`SubagentStop` | increment/decrement `activeSubagents` on parent |

Codex maps the same way (its event names match) minus `Notification`/`StopFailure`; `Interrupt` → `idle`.

Persist nothing across app restarts except a small JSON snapshot so a relaunch mid-session doesn't show empty; stale entries expire by the T-minute rule.

### 3.3 Terminal focus (multi-session "click to focus")
Hook payloads don't include the terminal PID. Approach, in order of preference:
1. Claude Code: add `TERM_PROGRAM`, `TERM_SESSION_ID`, `ITERM_SESSION_ID`, `WEZTERM_PANE`, `KITTY_WINDOW_ID` etc. to the HTTP hook via `headers` + `allowedEnvVars` (documented feature). The app then focuses via AppleScript/`open` per terminal type (Terminal.app, iTerm2, WezTerm, Kitty, Ghostty, VS Code integrated terminal). Codex: the forwarder script sends the same env vars as headers.
2. Fallback: match `cwd` against terminal windows' titles via Accessibility — brittle, only if (1) fails for your terminal.
**Need from you:** which terminal(s) you use (§9).

### 3.4 Cost extension
- `ClaudeLogReader.parseLine`: also capture `cwd`, `sessionId`, `isSidechain`; bump `LogParseCache` version so old caches rebuild.
- `CodexLogReader`: capture `cwd` from `session_meta`/`turn_context` (observed fields — verify on your machine's logs in Phase 3).
- `CodexLogReader`: read `session_meta.payload.source`; skip files where it is `exec` (decision §9A.5). Sub-agent rollouts (`source.subagent.thread_spawn.parent_thread_id`) attribute to the parent session and are skipped if the parent is `exec`. Fixture test covers all four source shapes.
- `UsageLedger` SQLite: add `project` and `session_id` columns (migration).
- `CostSummary`: new grouping by project (display as last path component, full path on hover) × model × day. Windows: today, 7d, 30d.
- Output-token placeholder issue: v1 ships with the same behavior as CodexIsland (documented inaccuracy, undercounts output). Post-v1 option: tap the statusline `cost.total_cost_usd` per session for an authoritative-ish number. Flagged, not fixed, in v1.

### 3.5 UI additions
- Compact state: unchanged logos, plus a thin state bar under each provider's logo showing one dot per live session (color = state; amber pulse for `waiting_permission`). Zero sessions → nothing extra, so at rest it looks like CodexIsland.
- Peek (hover): existing pill plus "2 sessions · 1 waiting" text.
- New **Sessions** page (Cmd+4): list grouped by provider; each row = project name, state icon, elapsed, model, sub-agent count, last message preview when `done`; click focuses terminal.
- Cost page: add a project breakdown toggle (existing Cmd-click cycling pattern).
- Alert: `waiting_permission` and `rate_limited` trigger a notch pulse (reuse `AlertEngine`). Optional macOS notification, default off.

### 3.6 Installer (in-app, Settings → Integrations)
- Claude: read `~/.claude/settings.json`, JSON-merge an `http` hook entry for each event in §3.2 under a recognizable marker, write back atomically with a `.bak`. Show a diff before writing. "Remove" reverses it by marker.
- Codex: install `~/.codex/hooks.json` entries pointing at a bundled forwarder (`Contents/Resources/notch-forward`, a ~20-line shell script using `curl --max-time 0.5`), then tell you to run `/hooks` in Codex and trust them. Show the exact definitions so you can compare.
- Never touch project-level settings.

### 3.7 Removals / renames
- Delete Grok, Antigravity, OpenCode reader code paths (§2.1 list, ~20 files + switch sites).
- Delete `spawnTokenRefreshPing`. Keep `spawnReauth` (user-initiated button).
- New bundle ID, new Sparkle key or Sparkle removed entirely (recommend remove: you build locally; auto-update is upstream's concern).
- Keep `MacIsland.` defaults prefix for v1 (renaming buys nothing and risks a migration bug); note as tech debt.
- App name: TBD (§9).

---

## 4. Phases

Each phase ends with a verification gate. Nothing proceeds until the gate passes on your Mac.

### Phase 0 — Repo & build baseline (½ day)
- Create GitHub repo (you own), push CodexIsland as initial commit preserving upstream history and LICENSE attribution.
- On your Mac: confirm `xcode-select -p`, `swift --version`, run `./build.sh` and `scripts/run-tests.sh` unmodified.
- **Gate:** upstream builds and launches on your Mac; test suite green. Record toolchain versions in README.

### Phase 1 — Strip & de-risk (1 day)
- Remove Grok/Antigravity/OpenCode; remove Haiku ping; new bundle ID; remove or re-key Sparkle; update `build.sh` logo copies and `run-tests.sh` lists.
- **Gate:** builds; all remaining tests green; quota page shows Claude + Codex live; `grep -r 'haiku\|spawnTokenRefreshPing' Sources` empty; network calls limited to the two usage endpoints + pricing/currency JSON (verify with `nettop`/Little Snitch or a `tcpdump` filter for 60 s).

### Phase 2 — HookServer + SessionStore + hooks installer (2–3 days)
- Implement `NWListener` HTTP server, `SessionStore` state machine, installer UI, Codex forwarder.
- Unit tests (standalone-binary style, matching repo convention): HTTP parser on malformed input, state transitions for every event in §3.2, installer JSON merge preserving existing hooks (fixture with pre-existing hooks), expiry logic.
- **Gate:** run a real Claude Code session and a real Codex session; every event listed in §3.2 observed in an in-app debug log with correct `session_id`/`cwd`; `PermissionRequest` state appears within 1 s of the prompt; killing the app mid-session does not block or slow Claude Code/Codex (time a `PreToolUse` with server down: must be < 100 ms overhead). Verify Codex hooks fire after `/hooks` trust.

### Phase 3 — Multi-session UI + terminal focus (2 days)
- Compact pips, peek text, Sessions page, `AlertEngine` integration, terminal focus for your terminal(s).
- **Gate:** three concurrent sessions (2 Claude, 1 Codex) render correctly; click-to-focus works for each; pulse fires on permission prompt; layout intact on a no-notch external display.

### Phase 4 — Per-project / per-model cost (1–2 days)
- Reader changes, ledger migration, `CostSummary` grouping, Cost page toggle.
- **Gate:** for one chosen project, per-model input+cache token totals match an independent script (`jq` over the same JSONL with the same dedupe rule) to within 0.1 %; ledger migration from an existing CodexIsland database succeeds without data loss; cold-start parse of your full `~/.claude/projects` under 3 s.

### Phase 5 — Polish & release (½–1 day)
- README (install, hook trust step, privacy statement listing every network endpoint), CHANGELOG, signed build with your Apple Development cert if you have one (else ad-hoc + documented `xattr -d com.apple.quarantine`).
- **Gate:** clean install on your Mac from the built `.app` following only the README.

Total: roughly 7–9 working days of agent time, gated on your builds. Calendar time depends on how fast you can run gates.

---

## 5. Verification & anti-hallucination controls

You asked for controls, not volume. These apply to every phase.

1. **Source-of-truth rule.** Every hook event name, payload field, and config path used in code must be traceable to either the official doc URL (§2.2, §2.3) or a captured real payload from your machine saved under `Tests/Fixtures/`. Observed-but-undocumented fields (transcript JSONL, Codex rollout) are marked `// OBSERVED, not documented` in code and covered by a fixture test so a format change fails loudly.
2. **Payload capture first, code second.** Phase 2 starts by installing a dump-only hook that writes raw JSON to a file for one real session of each CLI. Fixtures come from that, not from memory.
3. **Never block the CLIs.** HookServer returns 200/empty unconditionally; a test asserts no code path can emit a `decision` or non-200. Claude Code `Stop` and `PreToolUse` hooks can block on exit 2 — the HTTP handler makes exit codes moot, but the Codex forwarder script must `exit 0` always (`curl … || true`).
4. **Local-only invariant.** CI-style script `scripts/audit-network.sh` greps `Sources/` for `http` literals and fails on anything outside an allowlist (`api.anthropic.com`, `chatgpt.com`, pricing JSON, currency API, `127.0.0.1`).
5. **Independent cost cross-check** (Phase 4 gate) with a `jq`/Python script that does not share code with the app.
6. **Sub-agent discipline.** Implementation work is distributed to Opus/Sonnet agents per component; the main session reviews every diff against this plan before it is committed, runs the gate, and rejects anything that introduces an unlisted endpoint, an unlisted hook event, or a decision-emitting code path. Agents get the fixtures and doc URLs, not permission to browse for "how hooks work."
7. **Statusline as a second opinion (optional, Phase 3+).** A statusline command that forwards its stdin to the HookServer gives per-session `rate_limits` and `cost.total_cost_usd` from a documented source; used to sanity-check the undocumented `oauth/usage` numbers. Only if you don't already have a statusline you like.

---

## 6. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Transcript JSONL or Codex rollout format changes | Medium (undocumented) | Fixture tests fail loudly; readers degrade to "unknown" rather than wrong numbers |
| `oauth/usage` or `wham/usage` endpoint changes/blocks | Medium | Inherited from CodexIsland; UI shows "stale since HH:MM" rather than a number |
| Codex hooks trust step confuses future-you | Low | Installer shows exact definitions and the `/hooks` instruction |
| Terminal focus unreliable for your terminal | Medium | Depends on §9 answer; fallback to "copy cwd" button |
| Port 47777 conflict | Low | Configurable; installer rewrites hook URL on change |
| Output-token undercount in cost | Certain (documented) | Labelled "estimate" in UI; statusline cross-check post-v1 |
| Hook overhead on every tool call | Low | HTTP to localhost; measured in Phase 2 gate |
| Upstream CodexIsland diverges | Certain | We don't track upstream after fork; cherry-pick only security fixes |

---

## 7. Out of scope for v1 (explicitly)

Burn-rate forecast; routing hints; compaction pre-warning; reset notifications; task completion feed beyond `last_assistant_message` preview; sub-agent tree view (only a count in v1); Windows/Linux; menu-bar-only mode; iCloud/shared state; any cloud sync.

---

## 8. Deliverables

- GitHub repo with: forked source, `PLAN.md` (this file, updated), `docs/HOOKS.md` (exact hook config written, with doc links), `docs/PRIVACY.md` (every endpoint), `Tests/Fixtures/*.json` (captured payloads), `scripts/audit-network.sh`.
- Built `.app` per phase gate.
- Per-phase summary of what changed, what was verified, what was not.

---

## 9. Decisions needed from you

1. **App name** — **Notch Bridge** (decided 2026-09-13, see §9A).
2. **Terminal(s)** you run Claude Code and Codex in (Terminal.app / iTerm2 / Warp / Ghostty / WezTerm / Kitty / VS Code / Cursor). Determines §3.3. *(Recon §10: Terminal.app is the only terminal installed/running; plus the Claude desktop app itself.)*
3. **Sparkle**: remove entirely (recommended) or keep with your own key.
4. **Alert style** for `waiting_permission`: notch pulse only (default), or also a macOS notification.
5. **Codex cost**: accept interactive-only coverage for v1, or drop Codex cost from the Cost page until it's reliable.
6. **Statusline forwarder** (§5.7): include in v1 or defer. *(Recon §10: no statusline configured today, so nothing to conflict with.)*
7. **Existing CodexIsland install**: do you have one whose SQLite history should migrate, or start fresh? *(Recon §10: none found → start fresh.)*
8. **Signing**: do you have an Apple Developer account/cert, or ad-hoc signing? *(Recon §10: Developer ID Application cert present → sign properly.)*
9. **Build execution**: you run `build.sh` yourself at each gate, or I drive Terminal on your Mac through the desktop link (you'd approve app access once). *(Recon §10: this session already runs on the Mac with Bash access, so the agent can run builds directly.)*
10–12. See §11.5 (Astra, how Claude starts Codex, lineage in v1 or later).

---

## 9A. Decisions recorded (2026-09-13)

| # | Decision | Alec's answer | Plan impact |
|---|---|---|---|
| 1 | App name | **Notch Bridge** | Bundle ID `com.alecmarinov.NotchBridge`; repo `YungGravy0002/NotchBridge`; SQLite dir follows bundle ID |
| 2 | Terminal | Terminal.app + **Claude desktop app + Codex desktop app** (recon) | §3.3 focus target is the *app*, not a terminal: see §3.8 |
| 3 | Sparkle | Remove (Alec had no preference; recommended default) | Delete Sparkle framework, key, feed URL from `build.sh`; updates = rebuild locally |
| 4 | Alert style | Animated notch animation **plus** macOS notification, with a **persistent, configurable usage threshold** per window: Claude 5-hour, weekly, and per-model weekly (e.g. Fable/Opus) if the endpoint exposes it; Codex 5-hour and weekly | New §3.5a. Threshold alerts join `waiting_permission` / `rate_limited` as alert sources |
| 7 | Existing install | None (recon) | Start fresh, no ledger migration |
| 8 | Signing | Developer ID cert present (recon) | Sign + notarize-optional in Phase 5 |
| 9 | Build execution | Agent runs builds on this Mac | Gates run by agent, results reported |
| new | Click usage to switch apps | Wanted | New §3.8 |

| 5 | Codex cost scope | **Interactive sessions only** (Alec, 2026-09-13): count rollouts whose `session_meta.payload.source` is `vscode` or `cli`, plus their sub-agent threads (rolled up to the parent). Exclude `exec` entirely | Recon of 1,254 rollouts on this Mac: desktop-app sessions 489 (99 % carry `token_count`), `cli` 5 (80 %), `exec` 11 (54 %), ~750 sub-agent threads (100 %). The gap is small in practice |
| 6 | Statusline forwarder | Defer to v1.1 (recommended) | §5.7 stays optional |
| 10 | Astra | GPT-6-based orchestrator; launches the `claude` **CLI** | Lineage via a `claude` shell wrapper that exports `NOTCH_PARENT`, or Astra exporting it if it can |
| 11 | Claude → Codex | Bash tool running the `codex` CLI (`codex exec`) | Child inherits env vars automatically; lineage works with no prompt changes |
| 12 | Lineage in v1 | Yes (recommended); may slip to v1.1 if Phase 2 runs long | §11.2 + run tree (§11.3.1) enter Phase 2/3 data model |

All §9 decisions are now recorded. Phase 0 may start.

### 3.5a Threshold alerts (replaces "optional macOS notification, default off")
- Settings: per provider, per window (Claude: 5h, 7d, per-model 7d where `oauth/usage` returns it; Codex: 5h, 7d), a percentage threshold (default 80 %) and on/off. Persisted in UserDefaults.
- Trigger: when a polled window crosses its threshold (rising edge only; re-arms after the window resets). Fires the notch animation (`AlertEngine`) **and** a `UNUserNotification` ("Claude 5-hour at 82 %, resets 15:40"). Same dual output for `waiting_permission` and `rate_limited`.
- Notification permission requested once on first enable. Clicking the notification opens the notch expanded on the Usage page.

### 3.8 Click-to-switch between desktop apps
- Clicking the Claude usage area activates `com.anthropic.claudefordesktop` (`/Applications/Claude.app`); clicking the Codex usage area activates `com.openai.codex` (installed as `/Applications/ChatGPT.app`, verified 2026-09-13). Uses `NSWorkspace.openApplication(at:)` so it works across Spaces without the user changing desktops.
- Session rows in the Sessions page: if the session's hook headers show a terminal (`TERM_PROGRAM=Apple_Terminal`), focus that Terminal.app window via AppleScript; otherwise activate the desktop app for that provider.
- Modifier: Cmd-click keeps the existing page-cycling behaviour so the two gestures don't collide (verify against `IslandWindowController` click handling in Phase 3).

## 10. Machine reconnaissance (2026-09-13, read-only, this Mac)

| Item | Finding | Effect on plan |
|---|---|---|
| Toolchain | Command Line Tools only (`/Library/Developer/CommandLineTools`), Swift 6.2.4, no full Xcode | OK for bare `swiftc`; never introduce an `.xcodeproj`/`xcodebuild` step |
| git / gh | git 2.50.1; gh 2.96.0 authenticated as `YungGravy0002` with `repo` scope | Phase 0 repo creation can be done from here |
| Claude Code | 2.1.268 at `~/.local/bin/claude` | HTTP hook type is available in this version (doc re-verified today) |
| Codex CLI | 0.145.0 (npm, node 25.8) | Hooks feature present |
| `~/.claude/settings.json` | No `hooks`, no `statusLine`; `model: opus[1m]` | Installer starts from a clean slate; still must merge, not overwrite |
| `~/.codex` | No `hooks.json`; `config.toml` has a `notify` array pointing at Codex Computer Use | Installer must preserve `notify` and only add `[hooks]` / `hooks.json` |
| Transcript JSONL | Assistant records carry `cwd`, `sessionId`, `isSidechain`, `requestId`, `message.id`, `message.model`, `message.usage.{input_tokens,cache_creation_input_tokens,cache_read_input_tokens,output_tokens}` | Confirms §3.4 per-project fields exist |
| Transcript volume | 24 project dirs, 3.2 GB | Phase 4 gate "cold parse < 3 s" is likely unrealistic; re-baseline against measured time |
| Codex rollouts | 1,246 files; `session_meta.payload.cwd` and `turn_context.payload.cwd` present | Confirms §3.4 Codex `cwd` source |
| Terminal | Terminal.app only (installed and running); no iTerm/Warp/Ghostty/etc. | §3.3 targets Terminal.app via AppleScript; Claude desktop-app sessions have no terminal window to focus |
| Existing CodexIsland | None in /Applications, Application Support, or defaults | §9.7: start fresh; skip ledger migration path |
| Signing | `Developer ID Application: Alec Marinov (KFZ67HDT6P)` | §9.8: sign with Developer ID |
| Port 47777 | Free | Default stands |

### 10.1 Doc re-verification (today)
- Claude Code hooks: `type: "http"` confirmed with `url`, `headers` (env interpolation `$VAR`), `allowedEnvVars`, `timeout`. Body is the hook JSON; response uses the same JSON output format as command hooks. `PermissionRequest` exit 2 not honored; a `decision` object *can* deny — so our server must never emit one. Notification matcher values include `permission_prompt`, `idle_prompt`, `agent_needs_input`, `agent_completed`, `quota_auto_resume_*`. Full event list is now 32 events; §3.2's subset is still valid.
- Codex hooks: handler types `command` and `mcp_tool` only (`prompt`/`agent` parsed but skipped); config at `~/.codex/hooks.json` or `[hooks]` in `config.toml`; trust-by-hash gate via `/hooks` confirmed; SessionEnd/Interrupt 1 s default, 3 s max; payload fields `session_id`, `transcript_path`, `cwd`, `hook_event_name`, `model`, `permission_mode`, `turn_id`.
- HTTP-hook failure semantics (doc, verified today): 2xx + empty body = success; 2xx + JSON body = parsed as decision output; non-2xx = non-blocking error, execution continues; **connection failure = non-blocking error, execution continues**; timeout = hook canceled. "HTTP hooks can't signal a blocking error through status codes alone" — a decision requires a 2xx JSON body, which our server never sends. Default HTTP hook `timeout` is 600 s, so the installer must write an explicit small `timeout` (e.g. 2 s) on every entry so a hung app cannot stall Claude Code. Phase 2 gate still measures overhead empirically.

---

## 11. Brainstorm — the notch as a cross-agent orchestration surface

Context you gave mid-plan: Astra starts Claude agents, and Claude agents start Codex agents. I do not know what Astra is (a tool of yours? a custom orchestrator? a product?) — see question 10 in §9. The ideas below assume it is a process on your Mac that spawns `claude` sessions, and that Claude spawns `codex` via Bash or a hook. Correct me where that is wrong.

### 11.1 What the hook data already gives us for free
- Every `SessionStart` payload carries `cwd` and, for Claude, `session_start_type`. Every `SubagentStart` carries `agent_id`/`agent_type`. So the app can already see *that* a Claude session exists and *that* it has sub-agents.
- What it cannot see: **who started whom across process boundaries.** A Codex session started by a Claude Bash call arrives as an unrelated Codex `SessionStart`. Parentage must be injected.

### 11.2 Lineage tracking (the foundation everything else needs)
Give every agent an identity chain via environment variables, the same way `TERM_SESSION_ID` propagates:
- The app defines `NOTCH_PARENT=<provider>:<session_id>` and `NOTCH_ROOT=<run-id>`.
- Claude Code hooks can forward env vars as HTTP headers (`allowedEnvVars`, documented). Codex forwarder script reads the same env vars. Child processes inherit them automatically — a Codex started from Claude's Bash tool inherits `NOTCH_PARENT` pointing at that Claude session, **with zero changes to your prompts**, as long as the Claude session itself had the var set.
- Setting it on the Claude session: whatever launches `claude` (Astra) exports it, or a `SessionStart` hook writes it into a per-session env file that Bash tool calls source. Simplest: a shell wrapper `claude` → real `claude` that exports `NOTCH_PARENT=self`. Needs Astra's launch mechanism to be known.
- Result: the app has a tree `Astra run → Claude session(s) → Codex session(s) → sub-agents`, with cost and state rolling up each level.

### 11.3 Features that become possible once lineage exists (ranked by value/effort)
1. **Run tree in the Sessions page.** Collapsible tree instead of a flat list; each node shows state, elapsed, cost so far; parent rows aggregate children. Permission prompts anywhere in the tree bubble to the root row so you see "run X is blocked" without knowing which grandchild asked.
2. **Cross-provider cost per run.** "This Astra run cost $1.20 Claude + $0.40 Codex." Directly from lineage + the per-session cost work in Phase 4.
3. **Handoff visibility.** When a Claude session spawns Codex, show it as a handoff event in the run timeline, with the prompt Claude gave Codex (`UserPromptSubmit.prompt` on the Codex side). This is the "what did my agent tell the other agent" question, answered without reading transcripts.
4. **Routing hints at spawn time.** Because the app knows both providers' remaining quota, a tiny CLI (`notch which`) returns `claude` or `codex` based on headroom. Astra or a Claude skill can call it before spawning. Cheap to build, but only useful if your orchestration code is willing to ask.
5. **Launch from the notch.** Buttons/shortcuts in the expanded view: "new Claude in <recent cwd>", "new Codex in <recent cwd>", "re-run last Astra run". Requires knowing how you launch things (terminal app, Astra's CLI). Moderate value; mostly saves alt-tabbing.
6. **Handoff bridge (bigger).** A local endpoint the agents can call — `POST /handoff {to: codex, cwd, prompt}` — that the app fulfils by opening a new terminal tab with the target CLI pre-filled. Turns "Claude writes a Bash command to start Codex" into a structured, visible, cancellable action with lineage attached automatically. This is the feature most likely to make the workflow *simpler* rather than just *visible*, and the most work (~2 days). Also the one that needs a sharp look at what could go wrong if a misbehaving agent spams it (rate limit, confirmation toggle).
7. **Approve-from-notch.** `PermissionRequest` cannot be decided by our hook (non-blocking, documented), so a true "approve here" button is not possible for Claude via hooks. What *is* possible: click the alert → focus the right terminal, cursor ready. Codex's `PermissionRequest` hook *can* return a decision, but only for the hook that is asked, and doing so from a GUI would require the hook to block on the app's answer — feasible (command hook waits on a localhost long-poll up to its timeout) but it means a stalled app stalls Codex. Flag for discussion; not recommended for v1.
8. **Run summaries.** On root `Stop`, collect `last_assistant_message` from each node into one card: what each agent concluded. Pairs with the deferred "task completion feed."

### 11.4 What I'd propose adding to v1 vs later
- **Into v1:** 11.2 lineage (env-var chain + headers) and 11.3.1 run tree. These change the Phase 2/3 data model, so they are far cheaper now than retrofitted. Adds roughly 1 day.
- **v1.1:** cross-provider cost per run (11.3.2), handoff visibility (11.3.3), `notch which` (11.3.4).
- **v2:** handoff bridge (11.3.6), launch from notch (11.3.5), run summaries (11.3.8). Approve-from-notch (11.3.7) only after discussing the blocking trade-off.

### 11.5 Additional decisions needed (append to §9)
10. **What is Astra**, and how does it launch Claude — shell, Python subprocess, Claude Agent SDK, something else? Can it export an env var into the child?
11. How do your Claude agents start Codex today — Bash tool running `codex exec`, a skill, an MCP server?
12. Do you want lineage in v1 (recommended) or keep v1 to the three features and add orchestration in v1.1?

## 12. Sources

- CodexIsland source: https://github.com/ericjypark/codex-island (clone at main, 2026-09-10)
- Claude Code hooks reference: https://code.claude.com/docs/en/hooks
- Claude Code settings: https://code.claude.com/docs/en/settings
- Claude Code `~/.claude` layout: https://code.claude.com/docs/en/claude-directory
- Claude Code statusline: https://code.claude.com/docs/en/statusline
- Claude Code cost tracking (dedupe / placeholder caveat): https://code.claude.com/docs/en/agent-sdk/cost-tracking
- Claude Code monitoring/OTel: https://code.claude.com/docs/en/monitoring-usage
- Codex hooks: https://learn.chatgpt.com/docs/hooks (redirect from developers.openai.com/codex/hooks)
- Codex advanced config (`notify`): https://developers.openai.com/codex/config-advanced
- Codex issues re: rollout `token_count` and `wham/usage`: https://github.com/openai/codex/issues/9660, https://github.com/openai/codex/issues/10869
