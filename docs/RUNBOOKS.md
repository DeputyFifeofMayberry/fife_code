# Runbooks

## CI (`.github/workflows/tests.yml`)

Automatic on push/PR. Two lanes (`docs/STACKS.md` rule):

- `foundation-verify` (ubuntu-latest): `python3 scripts/selftest_verify.py`,
  then `python3 scripts/verify.py --ci`. Runs the Linux-safe categories
  (lint, typecheck, integration offline guard, security, architecture incl.
  required-docs and script unit tests); the macOS unit/e2e/build categories
  report SKIP honestly and are never counted as success.
- `unit-tests` (macOS-15): the required **app** gate — build + unit tests via
  `./scripts/test_unit.sh` machinery; UI suites run through the
  `test_ui.sh` machinery on macOS runners.

Required-check policy: the intended GitHub required status checks are
`unit-tests` and `foundation-verify`. Configuring GitHub settings is a board
decision and is not performed from implementation tasks.

## TestFlight release (`.github/workflows/release-testflight.yml`, manual)

Manual `workflow_dispatch` with a marketing version input. The workflow
archives, signs, exports, and uploads to TestFlight
(bundle id `com.deputyfife.opencode`, unique build number from the run
number). Signing uses a pre-exported Apple Distribution certificate:

- Required repo secrets: `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`,
  `ASC_API_KEY_P8`, `DIST_CERT_P12`, `P12_PASSWORD`,
  `PROVISION_PROFILE_BASE64`.
- The certificate is imported into a throwaway keychain per run; **never let
  CI mint new certificates** (account cap) — create portal CSRs manually.
- Upload targets TestFlight only; no App Store submission is created.

After dispatch: watch the run, then verify processing state with the check
workflow below. TestFlight tester visibility and external testing groups are
managed in App Store Connect (human, authorized operator).

## TestFlight build status (`.github/workflows/check-testflight.yml`, manual)

Read-only ASC query (same API key) answering "is my build still processing /
VALID / INVALID?" without the web UI. If a build is INVALID, read the
processing-mail reasons, fix, and re-dispatch a release with a new build
number (the run number guarantees uniqueness).

## External controls (board-owned; setup tracked in Paperclip LOC-20)

These are governed actions, never performed from implementation tasks:

- GitHub branch protection/rulesets on the published repository, required
  checks (`unit-tests`, `foundation-verify`), force-push and deletion
  refusal, and admin enforcement — verification follows both a failing and a
  succeeding PR through the protected workflow before any protection is
  considered confirmed (`docs/CHECKLISTS.md`).
- App Store Connect API key lifecycle (issue/rotate the `.p8`, keep it only
  in repo secrets), distribution certificate and provisioning profile
  renewal before expiry, and TestFlight group/tester administration.
- Secrets rotation on any suspected leak: revoke/rotate the ASC key and
  distribution certificate with authorization, then audit access
  (`docs/SECURITY.md`).

## Release

Check clean working tree, merged verified changes, updated `CHANGELOG.md`,
green `tests.yml` on the release commit, then dispatch the release workflow.
Verify the build appears and processes in TestFlight; roll back by
expiring/disabling the build in TestFlight if key journeys regress (app
rollforward is a new upload; there is no server component).

## Incident

Stabilize (revert the offending commit on the integration branch), record
timing and symptoms in `docs/WORKING.md`, preserve logs, reproduce, find
root cause, add a regression test, update the runbook and this record. Stop
after two speculative repairs and require a reproducible failing test
(`docs/agents/DEBUGGING.md` owns this rule). If a secret may be leaked, see
External controls above.

## Adoption

Foundation content is adopted from tagged releases of the foundation
repository; the installed version and adaptations are recorded in
`docs/ADOPTION.md`. A foundation migration is never a license to rewrite a
functioning app.
