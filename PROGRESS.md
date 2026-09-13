# Progress

## Goal
Notch app (fork of CodexIsland) showing Claude Code + Codex quota, live per-session state via hooks,
multi-session view, and per-project/per-model cost. All local. See PLAN.md.

## Now
- [ ] Phase 2 — payload capture first (dump-only hooks for one Claude + one Codex session → Tests/Fixtures), then HookServer, SessionStore, installer

## Backlog
- [ ] Phase 3 — multi-session UI, click-to-switch desktop apps (§3.8), Terminal.app focus
- [ ] Phase 4 — per-project / per-model cost
- [ ] Phase 5 — README, privacy doc, Developer ID signed build

## Done
- [x] Phase 1 — 2026-09-13 — Grok/Antigravity/OpenCode + connected-provider architecture removed, Haiku ping removed (credential watcher kept), Sparkle + release.sh + release.yml + Casks removed, renamed to NotchBridge / com.alecmarinov.NotchBridge, CLAUDE.md+AGENTS.md rewritten, scripts/audit-network.sh added. 95 files, −3258/+345. build ✓, run-tests 356 PASS / 0 FAIL, audit-network ✓, 90 s runtime lsof sample caught no sockets (calls are too brief to catch; static allowlist audit is the real gate)
- [x] Phase 0 — 2026-09-13 — repo YungGravy0002/NotchBridge holds full CodexIsland history (366 commits); unmodified build.sh OK (3m15s, Swift 6.2.4, CLT-only); run-tests.sh: 15 binaries, all pass (pricing-catalog-race-tests segfaulted once under -sanitize=thread, passed 3/3 on rerun — watch for flakiness)
- [x] All PLAN.md §9 decisions recorded — 2026-09-13 — see PLAN.md §9A
- [x] Research + plan v0.1 — 2026-09-13 — PLAN.md saved here
- [x] Machine recon — 2026-09-13 — see PLAN.md §10 (pre-answers §9.2, 9.7, 9.8; toolchain OK)

## Notes / gotchas
- No full Xcode installed, only Command Line Tools (Swift 6.2.4). CodexIsland uses bare swiftc, so OK; never add an .xcodeproj step.
- ~/.claude/projects is 3.2 GB / 24 projects — the Phase 4 "cold parse < 3 s" gate is probably unrealistic; expect to rely on LogParseCache and re-baseline.
- ~/.claude/settings.json has NO hooks and NO statusLine today; ~/.codex has no hooks.json. Codex config.toml has a `notify` entry (Codex Computer Use) — installer must not clobber it.
- Terminal in use: Terminal.app (plus Claude desktop app sessions, which have no terminal window).
- Developer ID Application cert present (Alec Marinov, KFZ67HDT6P) → can sign properly.
- gh authenticated as YungGravy0002.
- Desktop apps: Claude.app = com.anthropic.claudefordesktop; Codex desktop is /Applications/ChatGPT.app with bundle id com.openai.codex.
- Codex rollouts: `session_meta.payload.source` is `vscode` (desktop app), `cli`, `exec`, or a `{subagent: …}` object. Decision: cost counts only `vscode`/`cli` sessions (+ their sub-agents); `exec` excluded entirely.
- Astra (GPT-6 orchestrator) launches the `claude` CLI; Claude launches Codex via `codex exec` from Bash. Lineage env vars inherit naturally.
- Repo layout: NotchBridge/ (git clone) sits inside the 'Notch Usage' folder; PLAN.md/PROGRESS.md are mirrored in both places — edit the repo copy and cp up.
- Test runner compiles into a mktemp dir; to rerun one test, copy its swiftc line from scripts/run-tests.sh.
- pricing-catalog-race-tests: `-sanitize=thread` crashes inside the TSan runtime's own init (`__tsan::InitializePlatform → CheckAndProtect → dyld iterate`) on Swift 6.2.4 CLT + macOS 26.5, before any test code runs; passes without TSan. Flag removed from run-tests.sh in Phase 1; re-add when a toolchain update fixes it.
- OpenCode IS installed on this Mac (~/.opencode/bin, ~/.local/share/opencode/opencode.db). Its reader was removed per PLAN §3.7; usage made through OpenCode is not counted in Cost.
