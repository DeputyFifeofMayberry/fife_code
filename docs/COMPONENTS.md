# Component inventory

Adoption classifies every component per the gap matrix in
[ADOPTION.md](ADOPTION.md): **Adopted**, **Adapted**, **Present-sufficient**,
**NA-justified**, or **Missing**. Required components may be adapted or
matched by an existing equivalent, but never silently dropped.

## Required for every project

Exactly the documents `scripts/verify.py` enforces (`MANDATORY_DOCS`, 19
total); the two lists must stay identical. Deleting or emptying any of them
fails verification.

| Component | Why (here) |
| --- | --- |
| `AGENTS.md` | Compact always-read router: folder structure and the build/test/live-server rules; pre-existing, preserved |
| `README.md` | Human onboarding (install, features, build); pre-existing, preserved |
| `docs/USER_GUIDE.md` | Owner (non-engineer) app-level operating instructions |
| `docs/INDEX.md` | Knowledge map; `docs/README.md` stays canonical for features/archive/skills detail |
| `docs/CHECKLISTS.md` | Before-work/definition-of-done gates + the FifeCode build/test rules from `AGENTS.md` |
| `CHANGELOG.md` | Release-visible summary; `docs/WORKING.md` remains the detailed log |
| `docs/RUNBOOKS.md` | CI lanes, TestFlight/ASC procedures, external controls |
| `docs/REVIEW_EVIDENCE.md` | Independent review and acceptance evidence contract |
| `docs/TECH_DEBT.md` | Deferred-work queue |
| `ARCHITECTURE.md` | Real module map and dependency rules; RFC stays canonical |
| `docs/BASELINE.md` | Observed repository facts and fresh gate results |
| `docs/PRODUCT.md` | Journeys and behavioral expectations (PRD stays canonical) |
| `docs/PRODUCT_SENSE.md` | Product judgment principles |
| `docs/DESIGN.md` | Visual acceptance rules; `docs/design.md` stays canonical |
| `docs/FRONTEND.md` | Runtime UI/device verification (Tiers 2–4) |
| `docs/TESTING.md` | Executable check inventory and risk levels; `docs/tests.md` stays canonical for tiers |
| `docs/SECURITY.md` | Threats, secrets, live-server rules |
| `docs/RELIABILITY.md` | SSE/reconnect behavior, recovery tests, SLO placeholders |
| `docs/QUALITY_SCORE.md` | Evidence-backed scorecard |

## Required components beyond the doc gate

| Component | Why (here) |
| --- | --- |
| `docs/specs/SPEC_TEMPLATE.md` | Acceptance criteria before implementation |
| `docs/decisions/` | Why-decisions (ADRs); seeded with the adoption ADR |
| `docs/agents/` | Implementer, reviewer, debugging, handoff, intake, orchestrator contracts (org roles) |
| `.foundation/project.json` (schema v2) | The executable verification contract; all eight categories mandatory |
| `scripts/verify.py` + `scripts/selftest_verify.py` | The gate (verbatim from v2.2.1) plus proof the gate works |
| `.github/workflows/tests.yml` | CI enforcement: macOS app gate + Linux foundation job (this repo predates a separate `verify.yml`; the jobs live in `tests.yml`) |

## Adoption-time inventory (not gate-enforced)

| Component | Why (here) |
| --- | --- |
| `docs/ADOPTION.md` | This adoption's procedure record, gap matrix, and results |
| `docs/COMPONENTS.md` | This inventory |
| `docs/STACKS.md` | Minimum verification sets per stack |
| `docs/HARNESS_MAINTENANCE.md` | Maintenance cadence, lessons process, foundation release rules |

## Stack-conditional

| Component | When required | Why (here) |
| --- | --- | --- |
| `docs/DESIGN.md` + `docs/FRONTEND.md` | Any UI — required here (GUI app); NA mechanism unused | UI/UX contracts |
| Stack-specific CI runners | macOS/iOS target | App verification must run on macOS (`docs/STACKS.md`); Linux runs infrastructure only |
| `docs/orchestration/` | Paperclip in use | Orchestrator adapter contract (`PAPERCLIP.md`), adapted to org roles |

### NA mechanism

Not used by this project: the app is a GUI product, so neither
`docs/DESIGN.md` nor `docs/FRONTEND.md` is declared not applicable, and
`.foundation/project.json` carries no `not_applicable` object.

## Optional

| Component | Status here |
| --- | --- |
| `docs/plans/` | Not used; per-feature docs live in `docs/features/` (Present-sufficient) |
| `SETUP_PROMPT.md` | Skipped — already-adopted repository (onboarding done) |
| `INTERNAL_AUDIT_PROMPT.md`, `AUDIT_REPORT.md`, `examples/` | Foundation-meta; not copied into this app repo |
| `RESEARCH_DECISION.md` | Present (root): the research decisions behind this adoption |
| `skills/` | Pre-existing repo-root agent skills (Present-sufficient; indexed in `docs/README.md`) |
