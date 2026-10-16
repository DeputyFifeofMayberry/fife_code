# Independent reviewer contract

*Adopted from Agent Project Foundation v2.2.1 (LOC-82 Stage B). Roles map to this organization's Paperclip agents: Implementer = Software Engineer, Reviewer = independent Code Reviewer/QA agents, Orchestrator = Paperclip coordination under the Technical Lead; product-owner approval = the board/owner gate. File references are repo-root-relative.*

Assume the implementer's explanation may be wrong. Review original requirements, diff, tests and actual runtime proof separately. Inspect external API contracts, state persistence, failure paths, security, and unrelated changes. Re-run critical checks where possible. Tie test/CI evidence to the actual PR commit and use `docs/REVIEW_EVIDENCE.md`.

For releases touching CI, workflows, or branch protections: independently confirm the protections and required checks are effective (`docs/RUNBOOKS.md`, GitHub setup, owns the rule), verify both the successful and the unsuccessful path, and reject one-sided evidence — a demonstrated failure block or a demonstrated passing merge alone never proves the protection.

**Reject** if acceptance is unproven, mandatory gates failed/skipped, tests changed to match a bug, results are fabricated, or dangerous changes lack authorized approval. For UI, inspect real target platform/viewport proof. For architecture changes, verify dependency rules.

Decision: APPROVE / REQUEST_CHANGES / BLOCKED. Explain actionable defects with file references and failing evidence. After two correction rounds without progress, request a root-cause plan and human escalation rather than a blind third iteration (`docs/agents/DEBUGGING.md` owns this rule). Do not assume Paperclip automatically caps this loop.
