# Verified repository baseline

Observed facts for this checkout. Distinguish failures that predate the
foundation adoption from regressions introduced by it. Recheck when baseline
assumptions change. Enforcement claims are recorded from observation only.

| Field | Actual observed value |
| --- | --- |
| Repository provenance | Adoption clone of the FifeCode iOS client (public home `github.com/grapeot/opencode_ios_client` per `README.md`); clone created in Stage A (LOC-81) from the preserved checkout `projects/fifecode-ios`; `origin` points at that preserved local checkout (never pushed/pulled by adoption work) |
| Baseline commit SHA | `5b93d32` ("Snapshot current local source for isolated Paperclip tasks"), branch `paperclip-current-state`; adoption work on branch `foundation-v2.2.1-adoption` |
| Runtime versions and OS | Gate host: Linux (WSL), `python3` with PyYAML available; app: Xcode 16-era toolchain on macOS runners (`macos-15`), deployment target iOS 17.0 / visionOS 26.0+ |
| Dependency installation | None required for the gate (Python stdlib; PyYAML optional — present on this host). Swift packages resolve via Xcode on macOS (two pinned visionOS forks; `README.md`) |
| CI / local commands and evidence | `.github/workflows/tests.yml`: ubuntu `foundation-verify` (`scripts/selftest_verify.py` + `scripts/verify.py --ci`) and macOS `unit-tests` app gate. Local evidence for this adoption: see `docs/ADOPTION.md` results table |
| Known failing tests before work | None observed at baseline: last recorded full app run in `docs/WORKING.md` (2026-10-13) was 807 tests / 92 suites green, CI run `38484956844`; no failing checks were inherited by this clone |
| Critical user journeys with test links | `docs/PRODUCT.md` UJ-1…UJ-8 with their test files |
| Current deploy / rollback method | Manual TestFlight dispatch (`.github/workflows/release-testflight.yml`); rollback = disable build in TestFlight + revert commit (`docs/RUNBOOKS.md`) |
| GitHub ruleset status | **Not independently confirmed** in this clone: workflow content exists locally, but hosted branch protection/required checks are board-level settings outside this task's scope; treat protections as unconfirmed until the board's publication step demonstrates both enforcement paths (`docs/RUNBOOKS.md`, External controls) |
| App-vs-infrastructure classification | App: unit, e2e, build, integration (offline guard), security (offline guard). Infrastructure: lint (Python scripts), typecheck (config schema), architecture (docs + script unit tests + workflow YAML). Full rationale: `docs/TESTING.md` |
| Read-only checkout verification | The Python checks compile in memory (`lib_checks.py` `check_python_compile` — never writes `__pycache__`) and the gate runs on read-only checkouts; gate evidence in `docs/ADOPTION.md` was produced with no stray artifacts (verification item: `git status` clean after runs) |

Never declare the project stable merely because it builds: the macOS app
checks are the app gate, and this Linux host can only demonstrate
infrastructure health plus the honest SKIP of the macOS trio
(`docs/STACKS.md`).
