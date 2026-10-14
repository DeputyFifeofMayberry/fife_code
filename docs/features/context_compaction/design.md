# OpenCode iOS Manual Context Compaction Design

Status: proposal only, no implementation

## Bottom Line

`/compact` is a pure client-side command, never a prompt sent to the model. The web client recognizes the command in the composer and calls the session compaction API, and it never submits the literal command text as an ordinary user message.

The iOS client has no equivalent command parsing layer yet. `sendMessage` forwards all composer text indiscriminately to `/session/:id/prompt_async`, so typing `/compact` sends that string straight to the model. This is the expected behavior of the current client implementation, not a server defect.

The recommended product interaction is a single session-level Action with two entry points:

1. An intuitive `Compact Context` action in the Session action menu (`...`) and in the context-usage UI.
2. A `/compact` slash-command shortcut in the composer for keyboard users.

Both entry points call the same strongly typed client Action underneath, and neither produces an ordinary user text message.

## Current Mechanism

### Web Client

The web client registers a built-in command defined as:

- command ID: `session.compact`
- slash trigger: `compact`
- action: calls `client.session.summarize(...)`

When the user picks this built-in command in the slash command selector, the composer clears the command text and dispatches through the command registry. Custom slash commands take a different path and stay as editable prompt text.

Related source references:

- `opencode-official/packages/app/src/pages/session/use-session-commands.tsx`
- `opencode-official/packages/app/src/components/prompt-input.tsx`

This explains the previously observed Tab key behavior: Tab selects a local autocomplete candidate, and selecting it triggers the `session.compact` dispatch, rather than the model semantically understanding `/compact`.

### Current iOS Client

The iOS client's current execution path is:

```text
composer text
  -> AppState.sendMessage(...)
  -> APIClient.promptAsync(...)
  -> POST /session/:id/prompt_async
  -> normal user message
```

There is currently no built-in command registry or pre-send interception layer. Although `Part.type` can decode unknown part types into strings, the iOS side has no dedicated Compaction state machine transitions or completion UI yet.

Related source references:

- `OpenCodeClient/OpenCodeClient/AppState+Messages.swift`
- `OpenCodeClient/OpenCodeClient/Services/APIClient.swift`
- `OpenCodeClient/OpenCodeClient/Models/Message.swift`

## Backend Contract

The OpenCode server currently has two generations of API specs, which the design must not conflate.

### Legacy API Used By The Current Web Client

```http
POST /session/:sessionID/summarize
Content-Type: application/json

{
  "providerID": "openai",
  "modelID": "gpt-5.6-sol",
  "auto": false
}
```

Endpoint processing logic:

1. Clear any currently active Revert state.
2. Infer the currently active Agent from recent history messages.
3. Build and append a synthetic user message containing a `compaction` part.
4. Run the normal session inference loop with the currently selected model.
5. Generate a structured summary of the older history, optionally merging with an existing summary.
6. Later turns proceed based on that compacted representation.

This operation genuinely consumes one model call; it is not a local string truncation algorithm.

### V2 API Direction

The published V2 design spec defines:

```http
POST /api/session/:sessionID/compact
Content-Type: application/json

{}
```

The current V2 docs describe it as an asynchronous admission mechanism: after receiving the compaction request, the server performs compaction at a safe turn boundary and pushes progress and completion notices through the Session event stream. An optional Request ID supports idempotent retries.

The local July 14 checkout is in a transitional state: the route exists but its core implementation still returns `OperationUnavailableError` directly. So the iOS client should not switch to V2 merely because the route is declared; it should stay on the Legacy protocol of currently deployed servers and migrate later once a capability check exists or the server is upgraded in coordination.

### What Compaction Changes

Compaction changes the model-visible representation of session history; it does not physically delete the original persisted messages from storage.

Conceptually:

```text
Durable session history
  = original messages remain available to clients and export

Next model context
  = system context
  + generated checkpoint/summary of older history
  + retained recent turns
  + messages created after compaction
```

The summarization is lossy. Although the original messages remain fully stored in the session database, exact details from older conversation can disappear from later model-visible context.

Automatic compaction is a separate trigger policy over the same underlying mechanism. The existing Legacy configuration uses `compaction.auto`, `compaction.prune`, and `compaction.reserved`; V2 is evolving toward model-aware headroom and retained-tail configuration. Manual compaction must be independently triggerable, unaffected by the automatic compaction switches.

## Recommended UX

### Primary Entry Point

Add a `Compact Context` item to the Session `...` menu, alongside session-level actions like `Interrupt Agent` and rename.

Show a concise explanation in the action row or a first-run sheet:

> Summarize older conversation to free context space. Full history remains visible, but the agent may lose exact older details.

This is far more discoverable than forcing users to memorize a terminal-style command.

### Context Usage Entry Point

Tapping the existing Context ring opens a lightweight detail panel:

```text
Context used                 78%
Older turns can be summarized to free space.

[Compact Context]
```

Above a product-defined usage threshold the button can be visually emphasized, while users can still trigger it manually at lower levels. Merely opening the detail panel must not trigger compaction.

### Slash Command Entry Point

When the composer text starts with `/`, show a native command selector containing:

```text
/compact       Compact context
/summarize     Alias for /compact
```

After choosing either command, either trigger the strongly typed Action immediately or replace the composer text with an Action Chip the user sends via Send. Immediate triggering matches the web client and keeps the overall interaction lighter.

Safe parsing rules:

- Intercept only commands explicitly picked from the selector, or `/compact` and `/summarize` typed manually that match exactly after trimming whitespace with no attachments.
- Never misread `/compact please`, a `/compact` in the middle of a sentence, or a `/compact` carrying attachments as a compaction command.
- If the text starts with a reserved built-in command but is syntactically invalid, show a local syntax error hint; never silently send it to the model.
- Draft content already in the composer before the slash selector appears must be properly preserved.

### Progress And Completion

UI state stays strictly scoped to the session:

```text
idle -> requesting -> compacting -> completed
                          |
                          -> failed
```

Recommended visual presentation:

- requesting/compacting: the Context ring indicator shows a calm loading animation and the menu item text becomes `Compacting Context...`.
- completed: insert or fade in a restrained divider marker `Context compacted` in the timeline, then refresh the context usage data.
- failed: show a retryable error hint without modifying or discarding the composer draft.
- Show no cancel button unless the backend explicitly supports a compaction cancel protocol.

For Legacy `summarize`, an HTTP success response can indicate completion, after which the session history refreshes via SSE message and part updates; for V2, HTTP acceptance only means admitted, and the client must wait for the Compaction event notice or for the session to reach a stable state.

### Busy Session Behavior

In the Legacy MVP, disable manual compaction while the session is busy. This avoids concurrency races with the existing prompt loop and gives users predictable behavior.

Once the V2 safe-boundary admission mechanism is deployed, allow triggering while busy with the copy `Compact after current step`. The server handles queueing compaction requests against prompts and merging duplicates; the iOS client does not take on that scheduling duty.

### Confirmation Policy

No confirmation dialog on every trigger. Although the operation is lossy for the model's later attention, it does not physically delete persisted history, and the official client already exposes it as a direct command.

A one-time educational sheet or a clear action subtitle is enough. Frequent modal confirmations add serious interaction friction.

## Client Architecture

Keep the command parsing layer strictly decoupled from the API transport layer:

```text
Composer / Session Menu / Context Sheet
                 |
                 v
       AppState.compactCurrentSession()
                 |
                 v
       SessionCompactionClient
          |              |
          v              v
 legacy summarize     V2 compact
```

`AppState.compactCurrentSession()` owns availability validation, session-scoped progress state, error handling, post-completion state refresh, and double-tap suppression; UI entry points only trigger it.

The transport adapter layer should distinguish API generations explicitly. Avoid blindly retrying V2-then-Legacy on any error, since a timeout may mean the first request was already admitted by the server and a retry would trigger a duplicate model call. Choose the protocol generation from version/capability metadata returned by the server or from a fixed Host Profile setting.

## Delivery Slices

### Slice 1: Current Server MVP

- Wire the Legacy `summarize` API request.
- Add a single Compaction Action and its state to AppState.
- Add the `Compact Context` item to the Session menu.
- Intercept `/compact` and `/summarize` precisely on the client.
- Disable (grayed out) while the session is busy or has no user messages yet.
- Auto-refresh the message list and context usage after success.
- Add unit tests verifying command text can never leak through to `prompt_async`.

This slice needs no server changes; it is a small-to-medium iOS feature. The main risk lies in state transition and interaction correctness, not backend complexity.

### Slice 2: Discoverability

- Add the detail sheet for the Context ring indicator.
- Add an autocomplete selector for slash commands, replacing the send-time exact-match interception.
- Add the timeline divider indicator with localized copy.

### Slice 3: V2 Migration

- Auto-select the V2 protocol via explicit capability contract negotiation.
- Submit Compact requests with idempotency guarantees.
- Listen for and transition through Admitted, Running, Completed, and Failed events.
- Support queueing behind a busy turn.
- Remove the Legacy transport only after every supported host has V2 capability.

## Acceptance Criteria

1. Selecting `/compact` never produces an ordinary user text message.
2. The menu entry, the Context detail panel, and the slash command all call the same AppState Action.
3. On request failure, session state and the composer draft stay intact.
4. Repeated taps cannot trigger duplicate compaction model calls.
5. After compaction completes, the message stream and context usage refresh automatically.
6. After compaction completes, previously persisted history messages remain fully visible.
7. UI copy clearly states that older conversation details are subject to summarization loss.
8. Legacy and V2 completion semantics each have independent test coverage.
9. After an ambiguous timeout error, the client does not blindly retry through the second-generation API.

## Recommendation

Once implementation is approved, deliver Slice 1 first. It fixes the surprising command pass-through behavior on iOS with no server changes and provides a highly discoverable session-level action. Treat the V2 API as later protocol evolution, not a prerequisite for shipping this feature.
