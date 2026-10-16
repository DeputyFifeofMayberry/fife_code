# Context-preserving handoff

*Adopted from Agent Project Foundation v2.2.1 (LOC-82 Stage B). Roles map to this organization's Paperclip agents: Implementer = Software Engineer, Reviewer = independent Code Reviewer/QA agents, Orchestrator = Paperclip coordination under the Technical Lead; product-owner approval = the board/owner gate. File references are repo-root-relative.*

A handoff must include commit-bound verification evidence (see `docs/REVIEW_EVIDENCE.md`) and: issue/spec/PR links; current branch/worktree and commit; modified files; decisions and non-goals; tests run and exact outcomes; remaining steps; blockers; logs/evidence locations; risks; rollback path; whether the branch is mergeable. Keep durable facts in repository files. Don't rely on previous agent chat history or compressed context.
