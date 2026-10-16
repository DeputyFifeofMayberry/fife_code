# Paperclip integration — pilot, not a verified deployment

## Decision

Paperclip is the preferred *pilot* because it coordinates existing OpenCode/Codex sessions and has runtime-enforced per-issue review/approval stages **when executionPolicy is configured**. It is not a standalone reliable-coding benchmark winner.

## Mandatory pilot safeguards

1. Pin and record tested versions of Paperclip, OpenCode and the adapter. Record exact `cwd`, model, relevant subagent/plugin configuration, and sanitized logs.
2. Start with one implementer and one independent reviewer, one active change at a time. Use isolated worktree/branch; never share production credentials. Initial auto-merge: **off**.
3. Set per-issue `executionPolicy` with independent `review` and high-risk human `approval` stages. Empty policies do **not** enforce those stages. Verify actual policies on newly created issues, not just a template description.
4. Supply `AGENTS.md`, the spec, and `docs/REVIEW_EVIDENCE.md` to executor/reviewer. Require commit-specific CI links and tests. Paperclip issue status alone does not prove a codebase is correct.
5. **Review `dangerouslySkipPermissions`: Paperclip documents the `opencode_local` adapter as defaulting to `true` for unattended runs, which grants tools/connections full permission. Set `false` where compatible and use isolated low-privilege runners regardless; confirm the effective settings in your version.**
6. Set a finite, nonzero `timeoutSec` (`0` means no timeout). Validate cancellation and child-process cleanup. If tools spawn detached background subagents, verify they are fully joined before completion.
7. **Do not assume a correction-round cap is built in.** The published execution-policy spec describes a review loop that repeats until approval. If two rounds fail, require a separate manual/controller watchdog to block further speculative work and escalate.
8. Test: successful task, a deliberately failing test, reviewer rejection, high-risk human approval, crash/timeout recovery, session resume, pending child agents, and nonzero remote model connection errors. If these fail, halt unattended runs.
9. Keep GitHub branch ruleset and required independent CI separate from Paperclip statuses.

## Known risk reports (not measured failure rates)

- [Issue 889](https://github.com/paperclipai/paperclip/issues/889): parent OpenCode heartbeat may end successfully while background subagent tasks remain unfinished.
- [Issue 11615](https://github.com/paperclipai/paperclip/issues/11615): reported intermittent hang with local models and HTTP 499 conditions. A referenced fix does not constitute verified resolution for your pinned installation.

## References

- [OpenCode adapter](https://docs.paperclip.ing/reference/adapters/opencode/)
- [Execution policy](https://github.com/paperclipai/paperclip/blob/master/docs/guides/execution-policy.md)

Do not store API keys, machine addresses, or tokens in this document. Configuration and external rules are not installed by copying this file.
