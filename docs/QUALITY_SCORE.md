# Quality scorecard

Review after each release; consult `docs/HARNESS_MAINTENANCE.md`. Use
observed evidence, not agent confidence. Current evidence base: the 2026-10
adoption baseline (`docs/BASELINE.md`, `docs/WORKING.md`).

| Area | Grade | Evidence | Biggest gap | Action |
| --- | --- | --- | --- | --- |
| Core flows | B | 807 unit tests / 92 suites green at the 2026-10-13 baseline; Tier 2 fixture suites pin scroll/tool-card/task-notification behavior; journeys mapped in `docs/PRODUCT.md` | Live v2 verification and on-device confirmations pending (TD-4/TD-5) | Run the human-invoked live contract check at the next TestFlight build |
| Architecture | B− | Store extraction done; single APIClient choke point; pure wire mapping (`V2Mapper`) | AppState Coordinator undecided; no machine-enforced Swift layer rules (TD-2, TD-8) | Scoped refactor decision, then an import-rule check |
| Security | B | SSH TOFU + hard-fail defaults; offline-guarded live contract gate; secrets only in repo secrets/device storage | No automated dependency/secret scanner configured | Add a scanner as a scoped task (`docs/SECURITY.md`) |
| UX/accessibility | B− | Quiet Tech token system applied; localization en/zh; IME and hardware-keyboard behavior pinned by tests | On-device visual regression is manual; no screenshot-diff harness | Consider a screenshot-diff Tier 2 extension |
| Reliability | B | SSE reconnect + compensating sync; recovery test anchors (`docs/RELIABILITY.md`); honest SKIP semantics in the gate | SLOs are placeholders; live reconnect behavior under weak networks not measured | Define SLOs with the owner; measure at Tier 3 |

Suggested measures: first-pass task acceptance, post-merge regression rate,
reopened defects, time to resolution, human rework minutes, cost per accepted
change, flaky-check rate (simulator races are the known flake source —
`docs/CHECKLISTS.md`). Review trends over multiple tasks; a sample of one is
not proof.
