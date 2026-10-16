# Product judgment and scope

Prioritize clear workflows that solve real user problems over feature count;
prefer the smallest understandable change; keep visual/behavioral
consistency with the existing app (the Quiet Tech language in
[design.md](design.md)); never invent user preferences or silently decide
tradeoffs with permanent consequences.

**Project-specific principles** (from the PRD and `docs/WORKING.md`
decisions):

- Steer paradigm first: optimize for reading AI output and issuing
  corrections; de-emphasize code styling and editing affordances.
- Markdown is the core medium; rendering quality outranks syntax
  highlighting; image embedding is first-class.
- The external API surface stays stable when splitting or refactoring
  (`docs/lessons.md` lesson 5); wire changes update
  [v2_server_compatibility.md](v2_server_compatibility.md) first, then code.
- Server-derived data is normalized client-side at the decoding boundary,
  fence- and order-aware (lessons 18–19); the client fixes model/server
  quirks at that layer, not in views.
- Session/project creation only on the Server default; destructive or
  live-server-affecting actions are skipped while the owner's server is in
  use (`AGENTS.md`).
- Before a major feature ask: who needs it, which journey changes, what
  failure looks like, what must remain unchanged, and whether a simpler
  alternative suffices. Record the decision in the feature spec. Avoid
  turning the product spec into an unverifiable wish list.
