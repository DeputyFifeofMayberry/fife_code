# Documentation index

The repository, not a chat transcript, is the durable source of truth. The
detailed per-feature/per-archive listing lives in [README.md](README.md) and
stays canonical for those sections; this page is the top-level knowledge map:
where every fact lives and when each file is updated.

| Domain | Source of truth | When to update |
| --- | --- | --- |
| Mission, users, journeys | [PRODUCT.md](PRODUCT.md), [PRODUCT_SENSE.md](PRODUCT_SENSE.md) (adapters; the PRD stays canonical) | Feature intent changes |
| System components/dependencies | [../ARCHITECTURE.md](../ARCHITECTURE.md), [decisions/](decisions/) | Architecture or API boundary changes |
| Full technical design | [OpenCode_iOS_Client_RFC.md](OpenCode_iOS_Client_RFC.md) (canonical) | Architecture changes |
| Wire contract v1/v2 | [v2_server_compatibility.md](v2_server_compatibility.md) (canonical) | Any protocol change |
| UI/UX/device behavior | [DESIGN.md](DESIGN.md), [FRONTEND.md](FRONTEND.md) (canonical visual spec: [design.md](design.md)) | UI or navigation changes |
| Tests and gates | [TESTING.md](TESTING.md), [../.foundation/project.json](../.foundation/project.json); canonical tier spec: [tests.md](tests.md) | New/changed checks |
| Threats/secrets/data | [SECURITY.md](SECURITY.md) | Security/data change |
| SLOs/recovery | [RELIABILITY.md](RELIABILITY.md) | Operational behavior changes |
| Feature contracts | [features/](features/) | Before implementing features |
| Important why-decisions | [decisions/](decisions/) | Architecture decisions |
| Progress/decision log | [WORKING.md](WORKING.md) (canonical changelog source), [../CHANGELOG.md](../CHANGELOG.md) | Every substantive task |
| Retrospectives | [lessons.md](lessons.md) | After each failure/finding |
| Backlog of cleanup | [TECH_DEBT.md](TECH_DEBT.md), [QUALITY_SCORE.md](QUALITY_SCORE.md) | When deferring work |
| Agent contracts | [agents/](agents/), repo-root [../AGENTS.md](../AGENTS.md) | Workflow changes |
| Release/incident steps | [RUNBOOKS.md](RUNBOOKS.md) | Deployment procedure changes |
| Orchestration | [orchestration/PAPERCLIP.md](orchestration/PAPERCLIP.md), [agents/ORCHESTRATOR.md](agents/ORCHESTRATOR.md) | Paperclip workflow changes |
| Baseline and owner instructions | [BASELINE.md](BASELINE.md), [USER_GUIDE.md](USER_GUIDE.md) | Baseline changes |
| Review evidence | [REVIEW_EVIDENCE.md](REVIEW_EVIDENCE.md) | On each substantive task |
| Adoption record | [ADOPTION.md](ADOPTION.md) | Foundation upgrades, component changes |
| Component inventory | [COMPONENTS.md](COMPONENTS.md) | When adding or changing components |
| Stack minimum verification | [STACKS.md](STACKS.md) | When configuring checks |
| Harness upkeep | [HARNESS_MAINTENANCE.md](HARNESS_MAINTENANCE.md) | Each release; drift review |
| Specs | [specs/](specs/) | Before implementing features |
| Per-feature/archive/skills detail | [README.md](README.md) (canonical for those sections) | New feature docs |
| Agent operational skills | repo-root `skills/` (indexed in [README.md](README.md)) | Skill changes |

## Documentation standards

Create or update documentation when: a decision is made (ADR in
`decisions/`), a public contract changes, a dependency changes, user-visible
behavior changes, or a documented limitation is resolved or newly discovered.
Status claims must match verified repository state; "present/verified" claims
require the referenced file or command to exist and have been executed at a
recorded revision. The repo-root `AGENTS.md` stays a concise router; project
knowledge belongs in the domain files it indexes.
