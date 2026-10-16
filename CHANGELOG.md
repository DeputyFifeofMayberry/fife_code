# Changelog

Release-visible change summary for the OpenCode iOS Client (FifeCode). Kept
separate from Git history; `docs/WORKING.md` remains the detailed working and
decision log and is the canonical source for the entries summarized here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

### Added

- Foundation v2.2.1 adoption (this branch): schema-v2 `.foundation/project.json`
  with all eight verification categories, the `scripts/verify.py` +
  `scripts/selftest_verify.py` gate adopted verbatim from the foundation tag,
  Linux-safe category wrappers under `scripts/checks/`, the carried
  `resize_icon` fix and its unit-test suite, and the canonical documentation
  set (`docs/INDEX.md`, `docs/CHECKLISTS.md`, `docs/RUNBOOKS.md`, and the rest
  of the inventory in `docs/COMPONENTS.md`). See `docs/ADOPTION.md` and
  `docs/decisions/ADR-0001-fife-foundation.md`.
- CI: `foundation-verify` job on ubuntu-latest (verifier self-test + the
  Linux-safe gate categories) in `.github/workflows/tests.yml`; the macOS
  `unit-tests` job remains the required app gate (`docs/STACKS.md` rule).

### Fixed (2026-10 summary, from `docs/WORKING.md`)

- Sessions rendered newest-first; transcripts are now normalized to ascending
  wire order at the decoding boundary (v1 and v2 paths), restoring correct
  reading order, bottom anchoring, and v2 `lastUserID`/`parentID` linking.
- Model shortlist left-handle reorder now commits on release (UIKit pan
  replaces an in-list drag that never reached the drop delegate).
- Grok (`xai/*`) now shows the usage quota pill (weekly window mapping with a
  fallback to an available window).
- Background subagent receipts decode from synthetic messages and render as
  TaskNotificationCard with expand/navigation, instead of raw `<task>` XML.

### Added (2026-10 summary, from `docs/WORKING.md`)

- OpenCode server v2 compatibility on the `opencodev2-integration` branch:
  generation probing, per-generation REST branching, pure v2→model mapping,
  and SSE frame translation per `docs/v2_server_compatibility.md`.
- Background subagent activity is visible while the parent session is idle
  (conversation-tree aggregated busy counts; list sorting and status-bar
  segment with jump-to-child).
