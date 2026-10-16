# Task intake — CRAFT

*Adopted from Agent Project Foundation v2.2.1 (LOC-82 Stage B). Roles map to this organization's Paperclip agents: Implementer = Software Engineer, Reviewer = independent Code Reviewer/QA agents, Orchestrator = Paperclip coordination under the Technical Lead; product-owner approval = the board/owner gate. File references are repo-root-relative.*

Use this when initiating substantial work. Keep it concise; the feature spec and plan are durable outputs. Avoid telling the agent to implement until acceptance criteria and verification are defined.

## C — Context

Repo, current state, user problem, affected workflow, relevant spec and known baseline. Cite exact files and verified facts.

## R — Role / Responsibility

Act as a software engineer working within `AGENTS.md`; respect module boundaries and other agents' changes. An independent reviewer will evaluate evidence.

## A — Action

Investigate the current behavior; identify risk and dependencies; write/refine the acceptance spec; create a plan if nontrivial; implement the smallest safe change; add appropriate tests; verify actual behavior; update documentation.

## F — Format

Return: understanding, explicit assumptions, plan, files affected, evidence for every acceptance criterion, checks with results and commit SHA, unresolved issues, and PR/handoff link. Save durable materials in `docs/`.

## T — Tests / Acceptance

No completion until real configured checks pass and acceptance is evidenced. A bug fix needs regression coverage where feasible. Escalate rather than weaken quality gates. Record independent review and product-owner approval where required.
