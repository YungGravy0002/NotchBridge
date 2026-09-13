# Notch Bridge

A macOS notch app that shows your Claude Code and Codex usage side by side, tracks every running agent session live, and breaks cost down per project and per model. Everything stays on your Mac.

**GitHub one-liner:** Claude Code + Codex usage, live agent sessions, and per-project cost in the MacBook notch. A fork of CodexIsland by @ericjypark.

## Credit

Notch Bridge is a fork of [CodexIsland](https://github.com/ericjypark/codex-island) by [Eric Park](https://github.com/ericjypark), released under the MIT License. The notch window, quota polling, keychain and Codex auth handling, cost pipeline, and SQLite ledger all come from his work. This project would not exist without it. The original copyright notice and license are preserved in `LICENSE`, and upstream history is kept in this repository's git log.

What Notch Bridge changes on top of CodexIsland:

- Trims the providers to Claude and Codex only.
- Adds a local hook receiver so each Claude Code and Codex session reports its state (thinking, running a tool, waiting for permission, done) into the notch in real time.
- Adds a Sessions page with one pip per running agent, and click-to-switch between the Claude and Codex desktop apps.
- Adds per-project and per-model cost from local transcripts.
- Adds configurable usage-threshold alerts with a notch animation and macOS notifications.
- Removes the Sparkle auto-updater and the automatic Haiku token-refresh call. No new network endpoints are introduced.

## Privacy

Notch Bridge makes no model calls of its own. The only network traffic is the two usage endpoints CodexIsland already used, plus the public pricing and currency JSON files. Hook traffic stays on `127.0.0.1`. See `docs/PRIVACY.md` for the full list.
