# Research decisions — foundation v2.2.1 adoption (FifeCode)

Evidence and caveats behind the design decisions made while adopting the
foundation into this repository. The foundation's own design research lives
in its home repository; this page records the adoption-specific decisions
and supersedes the older D7 stage-sequencing note (superseded by the C4
resolution in the roadmap: Stage A verify, then Stage B implement, were
split into LOC-81/LOC-82 with Stage B blocked on Stage A's VERIFIED
verdict).

1. **Verbatim gate, adapted categories.** `scripts/verify.py` and
   `scripts/selftest_verify.py` are adopted byte-identical from tag v2.2.1
   rather than forked. Rationale: the gate is foundation content with its
   own self-test and release path; local forks would silently drift and
   lose selftest coverage. All project specificity lives in
   `.foundation/project.json` (schema v2) and the category wrappers.

2. **Wrapper scripts instead of direct argv.** The R2 gate (LOC-13,
   commit `2f9d16c`) proved macOS-only commands cannot be referenced
   directly from a config that Linux CI must also execute. Decision:
   `scripts/checks/<category>.py` wrappers port the R2 check logic
   verbatim, keep the SKIP-not-pass convention, and exec the real
   `test_unit.sh`/`test_ui.sh`/`xcodebuild` only where the toolchain
   exists. Caveat: a wrapper is one more hop; integrity is protected by the
   carried R2 test suite and the architecture category's script unit tests.

3. **Linux/macOS split with honest SKIP.** A green Linux gate must never be
   readable as app verification. The macOS categories report SKIP (never
   success) on Linux; CI keeps the macOS `unit-tests` job as the required
   app gate. Caveat recorded in `docs/BASELINE.md`: until the board's
   publication step, hosted enforcement is unconfirmed.

4. **Adapters, not overwrites.** Pre-existing functioning docs
   (`docs/README.md`, `design.md`, `tests.md`, PRD, RFC, `WORKING.md`) stay
   canonical; the new mandatory docs are thin adapters that map to them.
   Caveat: two indexes now exist; `docs/INDEX.md` defers feature/archive
   detail to `docs/README.md` to avoid divergence.

5. **Line endings.** The clone's legacy blobs are CRLF; new files are LF;
   carried files were verified content-equal after normalization rather
   than rewriting existing blobs (avoids huge spurious diffs in preserved
   content).

Each decision's operational detail: `docs/decisions/ADR-0001-fife-foundation.md`,
`docs/ADOPTION.md`, `docs/COMPONENTS.md`.
