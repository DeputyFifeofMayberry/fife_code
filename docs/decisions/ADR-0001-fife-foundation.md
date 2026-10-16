# ADR-0001: Foundation v2.2.1 adoption and category mapping

- Status: Accepted (2026-10-16, Stage B of the owner-approved roadmap)
- Deciders: Technical Lead (binding category decision), Software Engineer
  (implementation), under owner continuation authority (LOC-76 roadmap)
- Supersedes: none; complements `RESEARCH_DECISION.md`

## Context

The FifeCode iOS client predates the foundation: it has strong living docs
(PRD, RFC, `docs/README.md`, `design.md`, `tests.md`, `WORKING.md`,
`lessons.md`), real app tests, and CI, but no executable verification
contract. A prior adoption of an earlier foundation revision exists in a
preserved clone (R2, commit `2f9d16c`) whose gate is macOS/Windows-bound in
places. The preserved checkouts must not be modified; this adoption happens
in a fresh writable clone (`fifecode-v22-adoption`, base `5b93d32`, branch
`foundation-v2.2.1-adoption`).

Foundation v2.2.1 requires a schema-v2 `.foundation/project.json` with all
eight categories, a 19-document gate, and its own self-tested verifier. The
development machine for this stage is Linux; the app is iOS/macOS-only.

## Decision

1. Adopt the v2.2.1 verifier verbatim (`scripts/verify.py`,
   `scripts/selftest_verify.py` byte-identical to tag `v2.2.1`); replace the
   R2-derived gate in this clone only.
2. Map the eight categories (Technical Lead's binding decision):
   - `lint` → `python3 scripts/checks/lint.py` (R2 python-compile logic,
     extended to scan `scripts/checks/`; in-memory compile, read-only-safe)
   - `typecheck` → `python3 scripts/checks/typecheck.py` (foundation-config:
     JSON + the gate's own `parse_config()` schema validation)
   - `security` → `python3 scripts/checks/security.py` (v2 contract offline
     guard: refuses to run without `V2_PASSWORD`, exit 2, no network)
   - `architecture` → `python3 scripts/checks/architecture.py` (required
     19-doc gate sourced from `verify.MANDATORY_DOCS`, script unit tests,
     workflow YAML parse when PyYAML is present)
   - `integration` → `python3 scripts/checks/integration.py` (drives the
     same offline guard with `V2_*` stripped)
   - `unit` → `./scripts/test_unit.sh` (macOS)
   - `e2e` → `./scripts/test_ui.sh` (macOS)
   - `build` → `xcodebuild build` (macOS)
   The macOS categories report honest SKIP on Linux (never success);
   `required_ci_checks` lists all eight categories (schema requirement).
3. CI split in `.github/workflows/tests.yml`: ubuntu `foundation-verify`
   job (selftest + `verify.py --ci`); the existing macOS `unit-tests` job
   remains the required app gate. GitHub-level required-check settings are
   a board decision at publication.
4. Port every R2 check so each functioning check survives verbatim; carry
   R2 `2f9d16c` content: `.gitignore` Python lines, `resize_icon.py` fix,
   `scripts/tests/{__init__,test_resize_icon}.py`.
5. Documentation is additive and adapter-style: new mandatory docs map to
   the existing canonical sources; nothing functioning is overwritten or
   deleted.
6. R2's free-form environment/paths facts move into the wrappers' doc
   strings and `docs/BASELINE.md`/`docs/STACKS.md`/`docs/TESTING.md`
   (schema v2 has no free-form section).

## Consequences

- A Linux machine can prove infrastructure health and honestly report the
  macOS trio as SKIP; app verification still requires macOS (CI job or a
  Mac). This is stated in `docs/STACKS.md` and `docs/BASELINE.md`.
- The gate is upgradeable from the foundation without local forks; local
  adaptation surface is confined to `scripts/checks/`, the config, the
  workflow, and docs.
- The wrapper hop and the dual-index docs are known trade-offs, recorded in
  `RESEARCH_DECISION.md` and `docs/COMPONENTS.md`.
- Preservation: R1/R2/worktrees/foundation mirror remain read-only; this
  ADR's implementation commits only on `foundation-v2.2.1-adoption` in the
  adoption clone.
