# Test and verification strategy

The canonical test architecture (Tiers 1–4, fixtures, observability) is
[tests.md](tests.md); this page maps the executable verification contract.

## Executable check inventory (`.foundation/project.json`, schema v2)

| Category | Command | Platform | Validates |
| --- | --- | --- | --- |
| lint | `python3 scripts/checks/lint.py` | Linux + macOS | App: all Python under `scripts/` compiles (in-memory, read-only-safe) |
| typecheck | `python3 scripts/checks/typecheck.py` | Linux + macOS | Infra: `.foundation/project.json` parses and passes the gate's schema-v2 validation |
| unit | `python3 scripts/checks/unit.py` → `./scripts/test_unit.sh` | macOS (SKIP on Linux) | App: Xcode unit suites (807 tests / 92 suites at the 2026-10-13 baseline) |
| integration | `python3 scripts/checks/integration.py` → offline guard over `scripts/v2_contract_check.py` | Linux + macOS | App: the live v2 contract gate refuses to run without `V2_PASSWORD` (exit 2, no network); the live run itself is human-invoked |
| e2e | `python3 scripts/checks/e2e.py` → `./scripts/test_ui.sh` | macOS (SKIP on Linux) | App: Tier 2/4 XCUITest suites |
| build | `python3 scripts/checks/build.py` → `xcodebuild build` | macOS (SKIP on Linux) | App: the iOS app target builds |
| security | `python3 scripts/checks/security.py` | Linux + macOS | App: v2 offline guard (no server contact by automation) |
| architecture | `python3 scripts/checks/architecture.py` | Linux + macOS | Infra + app: required docs present (the 19-doc gate) and `scripts/tests/` unit tests pass; plus the doc/config layer checks (workflow YAML when PyYAML is present) |

`python3 scripts/verify.py --ci` enforces all eight categories; macOS-only
categories report SKIP honestly on Linux and are never counted as success
(`docs/STACKS.md`: Linux checks alone never verify the app). Removing a
category from the config is invalid; no-ops are rejected by a heuristic
denylist that is not exhaustive — reviewers examine behavior, not exit codes.

Plus the verifier's own proof: `python3 scripts/selftest_verify.py`
(31 tests) and the script unit tests
(`python3 -m unittest discover -s scripts/tests -t scripts`, the carried
`resize_icon` suite).

## CI cadence

The `Tests` workflow (`.github/workflows/tests.yml`) runs on every push to
`master`/`dev` and every pull request; `Unit tests` (macOS simulator) and
`Foundation verify (Linux)` are the branch-protection required checks. The
`UI tests (manual)` job keeps its on-demand path (`workflow_dispatch` with
`run_ui_tests`) and additionally runs from a weekly schedule trigger
(`23 5 * * 1`, Mondays 05:23 UTC), so the Tier 2/4 XCUITest suites get
non-manual coverage without slowing every pull request. Job steps are
identical for both triggers.

## Test design

Prefer observable behavior and contracts over implementation coupling. Every
regression keeps a reproducing test (TDD RED→GREEN is the house pattern —
see the newest-first fix in `docs/WORKING.md`). External integrations are
isolated with deterministic fixtures (`UITEST_*` offline fixtures; the v2
probe test uses a saved body). A small number of controlled live checks
(Tier 3, the human-invoked contract run) cover real integration.

## Test inventory

| Journey / invariant | Test file(s) | Layer | Failure reproduced |
| --- | --- | --- | --- |
| Transcript newest-first decodes ascending (v1+v2) | `WireDecodingTests`, `V2MapperTests` | 1 | 2026-10-13 newest-first bug |
| Session switch lands at bottom | `SessionScrollAnchorUITests` | 2 | 2026-09-29 stuck scroll |
| Subagent receipts render as cards | `TaskNotificationParserTests`, `TaskNotificationRenderingTests`, `TaskNotificationUITests` | 1+2 | 2026-09-27 raw XML |
| Subagent busy aggregation | `SessionTreeTests` | 1 | 2026-10-08 invisible work |
| v2 generation detection/mapping/SSE | `ServerGenerationTests`, `V2MapperTests`, `V2APIWireTests`, `V2SSETests` | 1 | v2 spec table rows |
| SSH tunnel close races | tunnel manager tests | 1 | 2026 NIO channel-state crash (`docs/WORKING.md` Problem 8) |
| Selected server profile + saved hosts survive terminate + relaunch | `RelaunchPersistenceUITests` | 2 | relaunch-persistence coverage gap (LOC-89) |

Live runs (Tier 3/4, live contract, TestFlight on-device) are recorded in
`docs/WORKING.md` and `docs/REVIEW_EVIDENCE.md` when executed.

## Change risk levels

- Low: docs, localization strings, focused checks + link validation.
- Medium: functional UI/logic changes — full unit suite via
  `./scripts/test_unit.sh` plus the relevant Tier 2 fixture test; sequential
  `xcodebuild build` when sources change.
- High: wire protocol, host-profile persistence, SSH/security, build
  settings — tier-1 protocol tests, `scripts/test_ui.sh` relevant suites, a
  documented rollback (revert), and human acceptance; live contract runs are
  human-invoked with credentials.

CI runs the required baseline regardless of subjective risk classification.
No silent skipping; environment limitations are blockers, not passes.

## Protected-branch regression scenarios

Covered by the foundation's standing coverage: `scripts/selftest_verify.py`
(unconfigured adopter fails closed; configured passes) and
`scripts/check_required_checks.py --required unit-tests,foundation-verify`
(required names match the workflow jobs and pass on the tree). Hosted
enforcement (PR blocked on a failing check; ordinary change merging through)
is observed during board-level GitHub setup — `docs/RUNBOOKS.md`, External
controls; until that board step, protections are **unconfirmed**, not absent.
