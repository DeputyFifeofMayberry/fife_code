# Review evidence contract

For any substantive task, the handoff (Paperclip evidence document or PR
note) names:

- Issue/spec ID, baseline commit, branch/worktree, and final commit.
- Acceptance criteria and the evidence for each: test results, reproduction
  before/after, CI run links, screenshots/videos where applicable.
- Exact verification command(s), platform/runtime, exit codes, and the
  checks that did **not** run (with the reason — e.g. macOS-only checks on a
  Linux host are SKIP/BLOCKED, never passes).
- Before/after behavior for affected user journeys, including failure paths
  and persistence.
- Security, dependency, compatibility, and rollout/rollback impact.
- Independent reviewer decision (APPROVE / REQUEST_CHANGES / BLOCKED) with
  unresolved concerns; product-owner acceptance when required.

## Repo conventions

- Unit/UI evidence cites the `xcodebuild`/`scripts/test_unit.sh` result and,
  where available, the GitHub Actions run for the commit (the macOS
  `unit-tests` job is the required app gate; the Linux `foundation-verify`
  job alone is infrastructure health).
- Wire-protocol changes cite the updated row(s) in
  `docs/v2_server_compatibility.md` plus the tier-1 tests that pin them
  (`ServerGenerationTests`, `V2MapperTests`, `V2APIWireTests`,
  `V2SSETests`).
- Regression fixes cite the reproducing test added first (TDD RED→GREEN),
  following the house pattern in `docs/WORKING.md` entries.
- When the tested state has no commit (adopted copies, artifact-only
  deliveries), record the exact content identity instead: source tree path
  plus a `sha256` manifest, noting any line-ending normalization used.
- An orchestrator run ending with exit code zero is *not* acceptance
  evidence; a local success does not replace the required CI check; an
  agent-generated screenshot must represent the actual tested app and
  commit.

## Release evidence

For a TestFlight release, evidence for the exact released revision includes:
green `tests.yml` on the release commit, the release workflow run URL, the
ASC build state (processing complete / VALID from
`check-testflight.yml`), and the smoke check of the key journeys on device.
GitHub-side protections (required checks) are confirmed by observation, not
inferred from configuration (`docs/RUNBOOKS.md`, External controls).
