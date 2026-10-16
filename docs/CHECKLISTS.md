# Change checklists

Gate and rules reference for this repository. The permanent verification-by-
design rules are summarized at the end; the FifeCode-specific build/test rules
from the repo-root `AGENTS.md` are merged here so agents have one checklist.

## Before work

- [ ] Baseline branch, commit, and existing tests observed; `docs/BASELINE.md`
      current
- [ ] Task scope, non-goals, acceptance criteria, and unchanged behavior
      recorded
- [ ] Valid, writable execution workspace established and verified **before**
      implementation (isolated branch/worktree or authorized clone with a
      valid HEAD; canonical/preserved sources untouched; no unrelated changes
      touched)
- [ ] Test strategy selected before implementation (`docs/TESTING.md`)

## Definition of done

- [ ] All acceptance conditions demonstrated with evidence
- [ ] Real `python3 scripts/verify.py --ci` passed; output retained
- [ ] Appropriate regression/integration checks ran (`docs/TESTING.md`); on
      Linux, macOS-only checks are recorded as SKIP/BLOCKED — never as passes
- [ ] No unauthorized weakening of tests, lint, CI, or security checks
- [ ] Runtime UI/device behavior exercised where applicable
      (`docs/FRONTEND.md`)
- [ ] Docs, decision records, known debt, and `CHANGELOG.md` updated as
      applicable
- [ ] Independent review evidence per `docs/REVIEW_EVIDENCE.md`
- [ ] Rollback path stated; no unresolved blocker disguised as success

## FifeCode build/test rules (from the repo-root `AGENTS.md`)

- Default unit tests: `./scripts/test_unit.sh`; UI tests:
  `./scripts/test_ui.sh` (launch/perf skipped by default;
  `OPENCODE_UI_TEST_INCLUDE_LAUNCH=1` includes them, `OPENCODE_UI_TEST_ONLY`
  narrows). Shared pinning/preflight lives in `scripts/lib_simulator.sh`
  (pinned UDID in `.occlient/simulator-udid`, 15s screenshot preflight,
  dedicated `-derivedDataPath`).
- `xcodebuild build` and `xcodebuild test` run **sequentially**, never in
  parallel (shared build database; concurrent runs fail with
  `build.db: database is locked`).
- Boot the simulator **before** `xcodebuild test`; resolve flaky
  name-based destinations by UUID from the error's own "Available
  destinations" list.
- Test-hang triage (`Restarting after unexpected exit...` + ~10 min silence):
  stop concurrent xcodebuild, `xcrun simctl shutdown <UDID>`, separate
  simulators per repo; kill at the 600s diagnostics timeout. Do not debug it
  as an app bug.
- Tests building `AppState` pass an isolated `UserDefaults` suite
  (`UserDefaults(suiteName: "...\(UUID().uuidString)")!`); `MessageStore` and
  SessionStatsStore persist to `.standard` and leak across suites otherwise.
- Chat input UI tests anchor on accessibility identifiers, not
  `TextField`-specific queries.
- "Build with the latest code" means: fetch upstream `origin/dev`, rebase the
  local integration branch preserving local commits, then build/test from the
  rebased state; on conflicts, stop and ask.
- Never kill or restart the user's live OpenCode server (especially anything
  on port `4096`); use a separate temporary port/process for runtime
  validation.

## Verification by design (permanent rules)

- Acceptance criteria are written **before** implementation and describe
  observable plus unchanged behavior (`docs/specs/SPEC_TEMPLATE.md`).
- Every gate check maps to an executable command in
  `.foundation/project.json`; "verified" means the exact command, its
  revision, and the exit code are recorded (`docs/REVIEW_EVIDENCE.md`).
- Outcomes are classified explicitly: **PASS / FAIL / NOT RUN / BLOCKED /
  SKIP with reason**. A skip never counts as success; the gate fails closed.
- Implementation is not verification: written code is a claim, not a
  demonstrated behavior. A green gate proves infrastructure health only —
  for this repo, app verification requires the macOS build/unit/UI checks
  (`docs/STACKS.md`); Linux-runnable checks alone never verify the app.
- Read-only checkout rule: checks must not write bytecode, caches, or
  artifacts into the source tree. The Python checks compile in memory and
  the gate cleans `scripts/**/__pycache__` it creates; a check that cannot
  run read-only is FAIL/BLOCKED, never success.
- No weakening to pass: tests, lint, CI, or verifier configuration must not
  be edited or loosened to obtain a passing outcome; such changes require
  explicit human approval and their own review evidence.
- CI enforcement and branch protection are confirmed by observation, never
  inferred from workflow files (`docs/RUNBOOKS.md`).

## Git-workspace preflight (permanent standard)

Run all eight checks **before** implementation, and re-run whenever the
workspace, mount, or host environment changes:

1. **Valid HEAD** — `git rev-parse HEAD` resolves to a real commit; record
   the SHA and expect the task's authorized baseline.
2. **Execution workspace exists** — the assigned path is the intended
   checkout/clone (not an empty default agent directory); confirm the branch.
3. **Workspace writable** — create and remove a probe file.
4. **Git administrative directories writable** — probe inside `.git` (where
   `index.lock` lives); a read-only mount fails here even when 1–3 pass.
5. **Staging and committing supported** — prove the full write path with the
   disposable test below; never assume it from checks 3–4.
6. **Committed results persist** — the repository lives in persistent
   storage, not a recreated-per-run temp workspace.
7. **Sync will not discard modifications** — confirm from
   `git status --porcelain` that uncommitted work survives any tooling-driven
   sync/rebase/checkout; destructive resets over dirty state are prohibited.
8. **Isolated agents cannot overwrite each other's work** — one isolated
   worktree/clone per agent; confirm any dirty state belongs to you.

### Disposable staging/commit test

Preconditions: working tree clean or dirty state explicitly recorded and
restored afterward; empty staging area; `HEAD` not detached. Record outputs,
then discard the probe:

```bash
git diff --cached --quiet || { echo 'BLOCKED: staging area not empty' >&2; exit 1; }
orig_ref=$(git symbolic-ref --short HEAD) || { echo "BLOCKED: detached HEAD" >&2; exit 1; }
git checkout -b preflight-probe
echo probe > PROBE.txt
git add PROBE.txt && git commit -m "preflight probe" -- PROBE.txt   # must succeed; record SHA
git checkout "$orig_ref" && git branch -D preflight-probe           # discard; return to baseline
```

### Preflight failure is an environment blocker

If any check fails: **stop**. Do not implement, do not work around with
destructive git operations, and do not report partial success. Record the
exact command, error, and filesystem evidence on the assigned issue as
**BLOCKED** and wait for an authorized resolution.
