# NotchBridge

Read [CLAUDE.md](CLAUDE.md) and `PROGRESS.md` before editing this repository.
NotchBridge is a macOS notch overlay for Claude Code + Codex quota and local
token cost — a fork of CodexIsland by Eric Park (MIT).

Build: `./build.sh` (bare `swiftc`, CLT-only, no Xcode, no SwiftPM).
Tests: `scripts/run-tests.sh`.

## Code Review Rules

- Report actionable P0-P2 bugs introduced by the change, with the triggering
  scenario, impact, and a precise changed-line reference. Skip style nits and
  speculative refactors. Distinguish unavailable review services from failing
  app tests.
- Flag any network call to a host outside the allowlist: `api.anthropic.com`,
  `chatgpt.com`, the pricing-catalog JSON and currency endpoints already in
  `Sources/`, and `127.0.0.1`.
- Flag any code path that emits a hook `decision`, returns non-200 from hook
  handling, or could block a CLI. Hook handling is observation only.
- Flag any new model/LLM call. The app makes none; the upstream Haiku
  token-refresh ping was removed deliberately.
- Claude credentials are owned by Claude Code. Flag app-side OAuth refresh
  calls or credential-store writes; never recommend adding them. Re-reading
  credentials and letting the CLI refresh its own is allowed. Preserve the
  documented usage headers and the five-minute polling floor.
- UserDefaults keys keep the `MacIsland.` prefix; keys marked
  `// TODO(notchbridge): legacy key name` keep their old names. Renaming
  orphans stored data.
- Check display changes, notched-screen placement, idle and Low Power
  behavior, concurrency, and provider error states when affected. Keep
  missing quota readings distinct from a real zero, and API-equivalent value
  distinct from actual billing. Persistent usage history must survive missing
  source logs.
