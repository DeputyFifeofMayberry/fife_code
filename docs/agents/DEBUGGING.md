# Systematic debugging protocol

*Adopted from Agent Project Foundation v2.2.1 (LOC-82 Stage B). Roles map to this organization's Paperclip agents: Implementer = Software Engineer, Reviewer = independent Code Reviewer/QA agents, Orchestrator = Paperclip coordination under the Technical Lead; product-owner approval = the board/owner gate. File references are repo-root-relative.*

1. Capture exact error and reproducible steps; preserve baseline/version and logs.
2. Narrow the failure to one boundary, state transition, or component; compare with a known working version.
3. Generate competing root-cause hypotheses. Design an experiment that could falsify the leading hypothesis.
4. Reproduce with a failing test (or document why automation is infeasible).
5. Make the smallest root-cause correction; rerun targeted and neighboring regression tests.
6. If two attempted fixes have failed: pause editing, write root-cause report in the execution plan, expand instrumentation or seek a separate reviewer. Do not stack speculative patches.
7. Confirm the exact user flow in the running app and record commit-bound evidence; see `docs/REVIEW_EVIDENCE.md`.

This document is the canonical owner of the two-attempt escalation rule (step 6); other foundation documents keep the rule but reference this file as its owner rather than restating separate policy.
