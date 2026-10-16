# Owner's guide (app level)

You do not need to know the engineering terms to use FifeCode or to check
what the agents claim. This guide covers the app itself; the general
process/claims guide lives in the foundation docs this repo adapted
(`docs/CHECKLISTS.md`, `docs/REVIEW_EVIDENCE.md`).

## Install and connect

1. Install the TestFlight beta from the link in the repo `README.md` (no
   Apple Developer account needed).
2. Start OpenCode on your computer (`opencode serve --port 4096`).
3. In the app: Settings → enter the server address (a missing `http://` is
   added automatically) → Test Connection.
4. Chat: create or pick a session and talk to your agent. Files: browse
   files and diffs. Settings: theme, voice input, optional SSH tunnel and
   usage dashboard.

## The daily loop (Steer)

- Read what the AI reports in the chat window (markdown, screenshots,
  diffs).
- If the direction is wrong, speak or type a correction — short natural
  language is fine ("stop, use composition instead").
- Background subagents show as "N subagents running" — tap to jump into the
  child session.
- The quota pill shows your provider's usage window for the selected model.

## Understand the status words

- **Designed** — agreed spec; nothing built yet.
- **Implemented** — code written; not yet proven.
- **Verified** — the configured checks ran green on a stated commit; bugs
  may still exist.
- **Accepted** — you reviewed real behavior and accepted known limitations.
- **Released** — the build passed TestFlight processing and basic checks.

These are separate states; an agent saying "done" means implemented, not
verified or accepted. Evidence (command + exit code, CI link, on-device
check) is what upgrades a claim — see `docs/REVIEW_EVIDENCE.md`.

## What requires your decision

- Releases to TestFlight and any GitHub settings/protection changes
  (board-level governed actions).
- High-risk changes: wire protocol, SSH/security, signing material.
- Product tradeoffs (new journeys, scope changes).
- Live server validation: agents will never touch your running server; a
  human runs live contract checks with credentials when needed.

## If an agent keeps breaking things

Stop after two speculative repairs, keep the logs, compare against the last
known good commit, and require a reproducible failing test plus a
root-cause report before more changes (`docs/agents/DEBUGGING.md`). If your
tests miss an important regression, improve the harness before new features.
