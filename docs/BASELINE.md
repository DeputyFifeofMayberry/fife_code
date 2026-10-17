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

## v2.2.1 adoption record (2026-10-16)

Agent Project Foundation v2.2.1 (tag 43d6a5cb913c05919c02ddd3cbc1d15c6d5d4008) adopted on dev via PR #7 (merge dc9cebe96fc801030fdaadcc6de07498b7b24196). Category mapping and project-specific adaptations: see docs/ADOPTION.md and docs/decisions/ADR-0001-fife-foundation.md.

Branch protection enabled on dev and master: required checks Unit tests + Foundation verify (Linux), strict up-to-date, admins included; validated both directions (blocked failing PR #8 probe; this PR validates the passing direction under the same protection).

## v2.2.2 delta record (2026-10-16)

Installed foundation version is now **Agent Project Foundation v2.2.2** (release [v2.2.2](https://github.com/DeputyFifeofMayberry/agent-project-foundation/releases/tag/v2.2.2), commit `ab72c85a36141ce70073f1ffd215de57f5e30635`), superseding v2.2.1 (standard 9). File-level sync, no git-history cherry-pick:

| File | Sync | sha256 |
| --- | --- | --- |
| `scripts/check_required_checks.py` | Byte-identical to v2.2.2 tag | `f2eddd13eec6c235351a2e6972434994d26a4b48bd12c5d3703d0ec2f48810e5` |
| `scripts/selftest_verify.py` | Byte-identical to v2.2.2 tag | `1d61aa0760c9a0f962459e25bb8a9bb5c2258411fb79ea93e9b04a9f775186b5` |

The v2.2.2 validator leaves workflows that implement none of the configured required checks (e.g. adopter-owned release workflows with step-level `env:` secrets, such as `check-testflight.yml`) unvalidated with a "not validated" note instead of failing closed; required-check workflows still fail closed. TD-10 is resolved by this release and unparked in `docs/TECH_DEBT.md`.
