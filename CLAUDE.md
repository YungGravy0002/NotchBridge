# CLAUDE.md — NotchBridge

**Read `PROGRESS.md` first.** It holds the live task list and the latest
checkpoint. `PLAN.md` holds the full design; this file is the short version.

## What this is

NotchBridge is a macOS notch overlay showing Claude Code + Codex quota and
local token cost. It is a fork of [CodexIsland](https://github.com/ericjypark/codex-island)
by Eric Park (MIT). The fork strips Grok/Antigravity/OpenCode, the auto-updater,
and the automatic Haiku token-refresh ping, and adds live
per-session state, a multi-session view, and per-project/per-model cost.

Bundle ID: `com.alecmarinov.NotchBridge`. App name: `NotchBridge`.

## Build

```sh
./build.sh          # universal arm64+x86_64, macOS 13+, ~3 min → build/NotchBridge.app
./scripts/verify.sh # build + 1-second smoke launch
```

Bare `swiftc`, one invocation per arch, hand-written `Info.plist`. **No
SwiftPM, no `.xcodeproj`.** Only Xcode Command Line Tools are installed on
this machine — never add a step that needs full Xcode.

## Tests

```sh
scripts/run-tests.sh
```

Standalone test binaries, no XCTest. Each binary hand-lists its source files
— adding a source to an existing test target means editing that `swiftc`
line. `pricing-catalog-race-tests` runs without `-sanitize=thread`: the TSan
runtime in Swift 6.2.4 CLT crashes in its own init on macOS 26.5. Re-add the
flag when a toolchain update fixes it. `scripts/audit-network.sh` enforces the
URL allowlist; run it before every commit that touches `Sources/`.

## Invariants (PLAN.md §5) — do not break

1. **Local-only network allowlist.** The only endpoints the app may contact
   are `api.anthropic.com`, `chatgpt.com`, the pricing-catalog JSON and the
   currency endpoint already present in `Sources/`, and `127.0.0.1`.
   Any other host is a defect.
2. **Never emit a hook `decision`.** Hook handling must always answer
   200 with an empty body and never block a CLI. Forwarder scripts
   `exit 0` unconditionally.
3. **Never add a model call.** The app makes no LLM requests, ever. The
   upstream Haiku refresh ping was removed on purpose; do not reintroduce it
   or any equivalent.
4. **Claude credentials are read-only.** The app never calls the OAuth
   refresh endpoint and never writes the keychain — Anthropic revokes the
   whole token family on old-token reuse. Re-reading is fine; the CLI is the
   only legitimate refresher.
5. **Five-minute polling floor** (`Sources/Model/RefreshIntervalStore.swift`)
   and the `claude-code/X.Y.Z` User-Agent stay as they are.
6. **UserDefaults keys keep the `MacIsland.` prefix.** It is stale upstream
   naming, but renaming orphans stored preferences. Same for the two legacy
   storage keys marked `// TODO(notchbridge): legacy key name`.

## Style

- Conventional Commits: `feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`.
- No force-unwraps without justification.
- Default to no comments; add one only when the WHY is non-obvious.
- Match the existing style of the file you are editing.
