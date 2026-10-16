# Stack-specific minimum verification sets

Practical **minimums** for configuring `.foundation/project.json` checks;
riskier changes require more (`docs/TESTING.md`). Infrastructure checks
(verifier self-tests, config validation) never substitute for the
application checks below — a green gate is infrastructure health, not app
acceptance (`docs/CHECKLISTS.md`). Every check must be read-only-safe (no
files written into the checkout). Headless projects may declare
`docs/DESIGN.md`/`docs/FRONTEND.md` NA via the fail-closed `not_applicable`
mechanism (`docs/COMPONENTS.md`); declaring NA never substitutes for a check
on this page.

## Native iOS / macOS (this project)

**Linux-runnable checks alone NEVER verify the app.** Build, test, and UI
verification must run on macOS with the project's Xcode toolchain; Linux
runners may validate infrastructure only (verifier self-tests, config and
doc checks). Missing macOS execution is **BLOCKED**, never a pass. This is
why the CI split in `.github/workflows/tests.yml` keeps the macOS
`unit-tests` job as the required app gate while the ubuntu
`foundation-verify` job runs the Linux-safe categories only, and why the
macOS categories (unit/e2e/build) report SKIP honestly on Linux instead of
pretending to pass.

Minimum app set (all wired into `.foundation/project.json`):

- Build: `xcodebuild build` of the `OpenCodeClient` scheme (the build
  category probe runs `xcodebuild -version` first; absent toolchain = SKIP).
- Unit: `./scripts/test_unit.sh` (pinned simulator, preflight probe,
  dedicated derived data — see `scripts/lib_simulator.sh`).
- UI/E2E: `./scripts/test_ui.sh` (Tier 2/4 XCUITest suites; launch/perf
  tests opt-in via `OPENCODE_UI_TEST_INCLUDE_LAUNCH=1`).
- Architecture (minimum): the doc/config layer — required-docs (the 19-doc
  gate), schema-v2 config validation, workflow YAML parse (PyYAML
  conditional), plus the script unit tests (`scripts/tests/`). Swift
  layer-import rules are not yet automated (`docs/TECH_DEBT.md` TD-8).
- `xcodebuild build` and `xcodebuild test` run sequentially, never in
  parallel (shared build database; `docs/CHECKLISTS.md`).

## Web apps (generic)

- Lint + typecheck (if typed); unit tests; production build; served smoke
  check; one E2E happy-path of the top journey.
- Architecture (minimum): dependency-cruiser (or ESLint import rules) failing
  on layer-violating imports, read-only (stdout only).

## React / Next.js

- `eslint`; typecheck; unit/component tests; production build; one E2E run
  against the production build covering the top journey; a route-level
  failure-state check.
- Architecture (minimum): ESLint `import/no-restricted-paths` or
  dependency-cruiser as above.

## Node backends

- Lint + typecheck; unit tests; integration tests against a real datastore;
  boot/health check in production mode with env validation failing closed;
  contract tests for the public API schema.
- Architecture (minimum): ESLint import constraints forbidding cross-layer
  imports.

## Electron

- Renderer web checks; packaged-build smoke test (the packaged artifact
  actually launches) on the target OS; at least one scripted main-process
  test.
- Architecture (minimum): renderer import rules plus a renderer→main
  boundary check (read-only).

## Python

- Lint (`ruff`/`flake8`); typecheck if typed; `pytest` unit + integration;
  package build; clean-venv install + CLI smoke test. Pin the interpreter.
- Architecture (minimum): `lint-imports` with cross-module contracts (cache
  routed outside the checkout).

## API / database-backed

- The backend checks above, plus: migrations applied **and reversed**
  against a disposable database; seed/rollback reproducibility; contract
  tests for every public endpoint including authorization cases. Never run
  destructive migrations against shared data without explicit human
  approval.
