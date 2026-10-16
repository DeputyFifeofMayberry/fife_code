# Harness maintenance and drift prevention

Once per release (or monthly while actively changing):

1. Check documentation against actual code and runtime behavior; update
   stale module links and `docs/BASELINE.md`.
2. Audit test coverage against the current most important product journeys
   (`docs/PRODUCT.md` UJ table); add tests for escaped defects.
3. Review repository checks, action versions, dependency security, and
   flaky-test trends (simulator races are the known flake source here —
   `docs/CHECKLISTS.md`).
4. Review `docs/TECH_DEBT.md` and `docs/QUALITY_SCORE.md`; retire obsolete
   exceptions or narrow debt in a focused change.
5. Test the gate itself with a deliberate failing test in a disposable
   branch (never merge it).
6. Review Paperclip adapter permissions, timeouts, pending subagents, failed
   runs, and evidence gaps.
7. Record harness changes and rationale in an ADR (`docs/decisions/`) when
   they affect the enforcement model.

Never allow the maintenance agent to bypass product-owner approval for
workflow, test, or security gate relaxation.

## Lessons process

Classify every failure or friction before any rule changes
(`docs/lessons.md` is this repo's running ledger):

- **Task-specific:** fix the task; change no harness rules.
- **Repo-specific:** fix in this repo's docs/config only.
- **Reusable:** candidate for a foundation change.

A reusable lesson becomes a foundation change only with: (1) documented
rationale naming the observed failure and the preventing rule, (2)
independent review of the change, and (3) a foundation `CHANGELOG.md`
entry. Workarounds improvised during a task are never auto-promoted to
universal rules; lessons deferred are recorded, not discarded
(`docs/lessons.md` stays the repo-side record).

## Foundation release relationship

This repository adopts tagged releases of the foundation
(`agent-project-foundation`, currently **v2.2.1**, commit `43d6a5c`); the
installed version, adaptations, and category mapping are recorded in
`docs/ADOPTION.md` and `docs/decisions/ADR-0001-fife-foundation.md`. The
canonical gate scripts (`scripts/verify.py`,
`scripts/selftest_verify.py`) are adopted verbatim and are not modified
locally — a needed gate change goes through the foundation's
improvement-to-release process (submission → evaluation → scoped
implementation → independent review → selftest + scenario evidence →
changelog + annotated tag), and this repo then upgrades per
`docs/ADOPTION.md`. Breaking foundation changes are stated in the
foundation changelog and bump its major version; this repo's local
adaptations (the `scripts/checks/` wrappers, CI split) live in this repo
and are reviewed here like any other code.
