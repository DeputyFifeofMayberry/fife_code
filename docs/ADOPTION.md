# Foundation adoption record

Installed foundation: **v2.2.1** (`agent-project-foundation` tag `v2.2.1`,
commit `43d6a5c`). This page records how the adoption was performed, the
component gap matrix, and the verification results. Upgrade procedure:
reconcile against the new tag's `CHANGELOG.md`, repeat the matrix and gate,
and update this page — local adaptations are re-reviewed each time.

## Execution context

- Workspace: writable adoption clone created in Stage A (LOC-81, verdict
  VERIFIED) from the preserved checkout at commit `5b93d32` (branch
  `paperclip-current-state`); all Stage B work is on branch
  `foundation-v2.2.1-adoption`, committed only in this clone. The preserved
  checkouts (`projects/fifecode-ios` and its worktrees, and the R2
  `data/repos/fifecode-ios` adoption at `2f9d16c`) are read-only references
  and were never modified.
- Foundation reference read at tag `v2.2.1` only; never modified.

## Gap matrix (component decisions)

| Component | Classification | Note |
| --- | --- | --- |
| 19 mandatory docs | Adapted (2 present-sufficient) | New adapters reference the FifeCode canonical sources (PRD, RFC, `docs/README.md`, `design.md`, `tests.md`, `WORKING.md`) instead of generic prose; `AGENTS.md`/`README.md` pre-existing and preserved |
| `scripts/verify.py`, `scripts/selftest_verify.py` | Adopted | Verbatim from tag v2.2.1 (byte-identical, verified by diff) |
| `.foundation/project.json` | Adapted | Schema v2 with all 8 categories; argv per the Technical Lead's binding category-mapping decision (ADR-0001) |
| `scripts/checks/*` | Adapted | R2 gate check logic ported verbatim into category wrappers + shared `lib_checks.py`; macOS trio (unit/e2e/build) exec the real scripts on macOS and report honest SKIP on Linux |
| `scripts/tests/` + `resize_icon.py` fix | Adopted | Carried verbatim from R2 `2f9d16c`; sha256 checked against the LOC-35 table (CRLF-normalized where needed) |
| `.gitignore` (+`__pycache__/`, `*.pyc`) | Adopted | From R2 `2f9d16c` |
| `.github/workflows/tests.yml` | Adapted | Added ubuntu `foundation-verify` job (selftest + `verify.py --ci`); macOS `unit-tests` stays the required app gate; activates only at board publication |
| `docs/specs/`, `docs/agents/`, `docs/orchestration/` | Adapted | Templates adapted to org roles (Paperclip: Technical Lead / Software Engineer / Code Review / QA) |
| `docs/plans/`, `SETUP_PROMPT.md`, foundation-meta files | NA-justified | Rationale in `docs/COMPONENTS.md` optional table |
| `skills/`, `docs/features/`, `docs/archive/` | Present-sufficient | Pre-existing; indexed; untouched |

## Category mapping (binding decision, details in ADR-0001)

lint/typecheck/security/architecture → Linux-safe wrappers under
`scripts/checks/` (R2 logic verbatim); unit → `./scripts/test_unit.sh`
(macOS); e2e → `./scripts/test_ui.sh` (macOS); integration → offline guard
over `scripts/v2_contract_check.py` on Linux; build → `xcodebuild build`
(macOS). `required_ci_checks` names all eight categories (schema
requirement); the GitHub-level required checks (`unit-tests`,
`foundation-verify`) are board settings, not this file's.

## Environment/paths facts (R2 project.json → here)

R2's free-form project facts moved into the wrappers/docs: app tree
`OpenCodeClient`, project `OpenCodeClient/OpenCodeClient.xcodeproj`
(`docs/ARCHITECTURE.md`, `docs/STACKS.md`), unit/UI test paths and script
commands (`docs/TESTING.md`, `docs/STACKS.md`), contract-check command shape
(`docs/SECURITY.md`, `scripts/checks/integration.py`), simulator tooling
(`scripts/lib_simulator.sh`, `docs/CHECKLISTS.md`), docs index
(`docs/README.md` + this set).

## Verification results (this adoption)

Recorded on the adoption branch (see the Paperclip evidence document for the
full transcript; commands run from the clone root):

| Check | Result | Evidence |
| --- | --- | --- |
| `python3 scripts/selftest_verify.py` | PASS — 31 tests, OK | Full output in the Stage B evidence document |
| `python3 scripts/verify.py --ci` | PASS (exit 0) — 19-doc gate green; lint/typecheck/integration/security/architecture PASS; unit/e2e/build honest SKIP (macOS-only on Linux) | Same |
| `python3 -m unittest discover -s scripts/tests -t scripts` | PASS — resize_icon suite OK | Same |
| Carried-file integrity vs LOC-35 sha256 table | PASS with documented CRLF normalization (see below) | sha256 comparison in the evidence document |
| Diff shape vs `5b93d32` | Zero deletions; new + modified files per the approved scope (`git diff --name-status` in the evidence document) | Same |
| `git status` after runs | Clean (gate leaves no stray artifacts) | Same |
| Preservation re-check | `projects/fifecode-ios`, R2 clone, worktrees, and the foundation mirror unchanged (no writes; verified by pre/post status) | Same |

CRLF note: this clone's existing text blobs use CRLF; new files are authored
LF. Carried files were compared content-equal after line-ending
normalization; no existing blob was rewritten.
