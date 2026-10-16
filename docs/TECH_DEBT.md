# Technical debt and known issues

Deferred work with owner, severity, evidence, risk, and a review trigger.
Do not hide knowingly broken behavior under a successful completion claim.
Reassess at each release per `docs/HARNESS_MAINTENANCE.md`. Detailed status
history stays in `docs/WORKING.md` ("Follow-ups"); this table is the queue.

| ID | Problem and evidence | Impact | Priority | Next action | Status |
| --- | --- | --- | --- | --- | --- |
| TD-1 | iPhone heat investigation paused (`docs/WORKING.md` Follow-ups) | Battery/perf on device | Medium | Instruments re-check when resumed | Open, deferred by owner |
| TD-2 | AppState Coordinator extraction undecided (Stores done; code review 3.1 partial) | Maintainability of the app core | Medium | Decide split in a scoped refactor task | Open |
| TD-3 | v2 `type:"synthetic"` real body untested against a live server (fixture mirrors the user-row shape; falls back to dark) | Cosmetic risk on real receipts | Low | Verify in the live v2 contract run | Open |
| TD-4 | `opencodev2-integration` live verification pending: `v2_contract_check.py` live run + TestFlight verification | v2 correctness confidence | High (before v2 release claim) | Human-invoked live run with credentials | Open |
| TD-5 | Newest-first fix: on-device reading order still to verify in TestFlight | UX confirmation | Low | On-device check at next TestFlight build | Open |
| TD-6 | Shortlist reorder on-device drag acceptance awaits manual verification | UX confirmation | Low | On-device check | Open |
| TD-7 | iPad/Vision Pro Preview column ("pin/close current file") considered optional | Enhancement | Low | Product decision first | Open, optional |
| TD-8 | Swift layer-import rules not machine-enforced (`ARCHITECTURE.md` dependency rules are prose) | Architecture drift risk | Medium | Add a SwiftLint/import check as a scoped task | Open |
| TD-9 | Foundation backlog pointers: Paperclip LOC-20 (external controls setup: branch protection, ASC secrets lifecycle) and LOC-21 (backlog items carried from the R2 adoption) | Governance/ops | Medium | Board-owned setup tasks; see `docs/RUNBOOKS.md` External controls | Tracked on Paperclip |
| TD-10 | `scripts/check_required_checks.py` (adopted verbatim from foundation v2.2.1) fails closed on `.github/workflows/check-testflight.yml`: step-level `env:` with `${{ secrets.* }}` is outside the tool's supported workflow subset, so a repo-wide `--required` validation run cannot complete until that workflow is refactored or the tool is extended | Blocks the optional local pre-validation of GitHub required checks at the board's publication step; `verify.py --ci`, the self-test, and both required CI jobs are unaffected | Low (publication-time) | When the board prepares branch protection (LOC-20), either narrow the validator run to `tests.yml` or port the validator's supported-subset parser to cover step-level `env` | Open |

Historical lessons that produced standing rules live in `docs/lessons.md`
(e.g. SSH TOFU defaults, SSE compensating sync, fence-aware normalization);
they are enforced through tests and checklists, not tracked here.
