# SSE Event Data Path Design (SSE as the Data Path for Message State)

Status: implementation ready (step 2 investigation done, all file:line based on master `3c603dc` and opencode-official `71927c2d05`, ready to start)

## 1. Bottom Line

The iOS client currently uses SSE as a doorbell and relies on REST for all the real data: every message-related SSE event throws away the complete data in its payload and instead triggers a full REST fetch (`loadMessages` + `loadSessionDiff`), and these `await` calls queue up inside the same serial event loop. For an ordinary turn with N=3 steps and M=2 tools per step, a static count gives **42 REST pairs (84 fetches) serially blocking the event loop** (formula `N×(8+3M)`, verified line by line against source; see the end of the client inventory). The perceived result: while a tool is running, the UI waits for REST snapshots to come back before it moves.

The server puts the data in the event payload itself (verified twice: native OpenCode server source plus live measurement): `message.part.updated` carries the complete part (the tool's `state.status/input/output/time`), `message.updated` carries the complete message info, `message.part.delta` carries streaming text increments, and `server.heartbeat` sends a frame every 10s.

The design has three parts:

1. SSE as the data path: event payloads are upserted directly into MessageStore, zero RTT, rendered as soon as the event arrives. Payload completeness gate: if fields are incomplete (such as the dsh shim's thin part shape), fall back to the current REST path, so behavior matches today.
2. REST demoted to reconciliation: per-event REST drops to zero; fetch only on bootstrap (reconnect), turn end (session.status -> idle), manual refresh/switching, or watchdog trigger. Per-turn REST drops from 42 pairs to 1-2 pairs.
3. Heartbeat watchdog: server.heartbeat is a 10s frame guaranteed to exist on /global/event (sent even during long tools, verified in source). The client checks silence duration on a 5s cycle and triggers one reconciliation after >20s (two missed heartbeats). This replaces polling as the silent-death recovery; on compatible hosts without heartbeats it degrades to low-frequency 20s reconciliation, no worse than today.

* **Explicitly out of scope**: 2s busy polling (a known user pain point, not introducing it), optimistic busy on send (sub-second cosmetic, not doing it), tile visual upgrade (separate P2 item), server changes (zero).

## 2. User-Visible Problem and Root Causes

Observation: Android shows the running tool plus a timer; on iOS the UI shows no updates while a tool runs and presents everything at once when it ends.

Root cause chain (all with file:line references, master):

1. **SSE used as a doorbell**: the `message.part.updated` handler (`AppState+SSE.swift:132-155`) calls `messageStore.applyMessagePartUpdate` (`MessageStore.swift:154-169`), which only does `recordPartType` bookkeeping, **never touches the payload**, and returns `.finalized` directly → `await loadMessages() + await loadSessionDiff()` (:149-155). The complete part object is parsed and then discarded.
2. **Serial event loop with head-of-line blocking**: inside the `for try await` loop of `connectSSE` (`AppState+SSE.swift:9-39`), `await handleSSEEvent(event)` (:28), and the message event handlers internally `await` REST round trips. One slow REST call stalls every subsequent event.
3. **No silent-death recovery**: the backoff reconnect (`min(30, 2^attempt)`, 2s→4s→8s→16s→30s capped, :33-36; on successful reconnect runs `bootstrapSyncCurrentSession` :26) only handles "the connection dropped". When the connection is alive but no frames arrive (proxy buffering drops frames), the UI stays on the last state forever. (Note: iOS currently has **no** busy polling and no other recovery path.)

4. **UI layer gap** (independent of the data path): **the current UI cannot yet surface a tool's running state**. The tool is buried inside the collapsed `ToolCallsRowView` (`MessageRowView.swift:754-796`) with no per-tool running visual in the row (no header spinner, no explicit running marker); the composer status line text depends on `session.status`'s `status.message` and on ActivityTracker inference (`ActivityTracker.swift:74-97`), so its quality depends on the server's wording. The data path is therefore a **necessary precondition** for "the user can see the tool running", though not sufficient on its own: this feature fixes data timeliness, and the visual presentation of the running state is to be filled in by the P2 tile feature (5.7). Before P2 lands, the post-change experience = composer row appears promptly (busy) + collapsed tool row status updates promptly; the row still has no explicit running indicator.

* Android comparison (see the Android-side plan): same doorbell architecture + 400ms debounce + 2s busy polling + in-memory streaming text. This design switches the data source to the payload itself and replaces polling with the watchdog; the same design will be ported to Android and polling removed.

## 3. Server Event Contract (native OpenCode server)

Source: `opencode-official` (upstream dev `7945de2089` + 1 private commit `71927c2d05`; the private patch only changes the run-state runner scope and two schema definitions, **it does not affect any contract below**). Live measured timeline: from the `session_status_bar` feature probe (`tmp/status_bar_probe.py`, 4096 live server, 2026-09-30; that feature's docs live in the opencode_ios_client main checkout and did not make it into this branch; the timeline is inlined below, so this section is self-contained).

### SSE Endpoints

The server exposes `/event` (instance level, filtered by directory), `/global/event` (global, unfiltered), and `/api/event` (V2 surface, dropping queue with capacity 256) at the same time. **iOS subscribes to `/global/event`** (hardcoded at `SSEClient.swift:57-58`; `APIConstants.sseEndpoint` is a dead constant).

- `/event`, `/global/event`: one `server.heartbeat` every ~10s (an independent `Stream.tick("10 seconds")` in the handler, `handlers/event.ts:63-66` and `handlers/global.ts:35-38`; **does not depend on any session/instance state**, keeps sending when idle or during long tools); the first frame of a new connection is `server.connected` (`properties: {}`); the unbounded queue does not drop frames; events for the same session keep FIFO order (single-process serial notify + same-session events come from a single runLoop fiber).
- `/api/event`: the heartbeat is a 15s SSE comment frame (not a `server.heartbeat` event); encoding v1 live events (`session.status`/`message.part.delta`) fails (measured with a schema encoding probe); a pure `cli serve` process only exposes this endpoint. **The iOS client does not subscribe to this endpoint; it is irrelevant to this design**. If a host only has `/api/event` (pure cli serve), the current client already cannot connect, so it is out of scope.
- dsh shim host: multiple iOS hosts can connect to the shim (it works today ⇒ the shim provides a usable `/global/event`); whether the shim sends `server.heartbeat` is **unverified**. The watchdog degrades to low-frequency 20s reconciliation on hosts without heartbeats (see 5.6), which is no worse.

### Event Table (client-relevant, payload shapes verified)

| Event | properties | Key facts |
|---|---|---|
| `session.status` | `{sessionID, status: {type: busy\|idle\|retry, ...}}` | busy sends about `2N+1` frames per turn (loop head + per-step process head, `prompt.ts:1089`, `processor.ts:653`); **idle is sent only once when the whole turn ends** (Runner.onIdle, `run-state.ts:48-51`), steps do not alternate in between ⇒ `busy→idle` can serve as the turn-end signal |
| `message.updated` | `{sessionID, info: <full message info>}` | each step's new assistant message gets a new `msg_` id (`prompt.ts:1190-1201`): one frame at step start + one at step end (`processor.ts:470`, no `time.completed` at that point). Whether a turn-level final completion frame exists is unverified (pending live test; does not affect the design since reconciliation backs it up) |
| `message.part.updated` | `{sessionID, part: <full part>}` (published by `updatePart`, `session.ts:637`, full `structuredClone`) | tool state machine: `tool-input-start` creates pending → `tool-call` (arguments complete) moves to running and writes `time.start` → `tool-result` moves to completed and writes `time.end` (`processor.ts:216-253, 331-351, 160-184`). A fixed 6 frames per step + 3 frames per tool (step-start/reasoning×2/text×2/step-finish; tool pending/running/completed) |
| `message.part.delta` | `{sessionID, messageID, partID, field: "text", delta}` | emitted in only two places, text (`processor.ts:513-524`) and reasoning (`:294-306`), with field always `"text"`; **ordering is guaranteed: start (a part.updated with empty text) → delta* → end (a part.updated with full text)**; delta is a live, non-durable event; the end frame is the idempotent converging frame (lost deltas can be recovered from the end frame, but there is no explicit frame-loss signal) |
| `message.part.removed` | **only `{sessionID, messageID, partID}`, no part object** | triggers: revert cleanup (`revert.ts:101-124`, before prompt/shell/summarize) + the two `DELETE` message/part HTTP endpoints. Edit does not send removed |
| `message.removed` | `{sessionID, messageID}` | same as above |
| `session.updated` | `{sessionID, info: <full session including cumulative tokens/cost>}` | `Session.touch()` runs on every step completion; iOS already upserts locally today and does not trigger REST |
| `server.connected` / `server.heartbeat` | `properties: {}` | plain data frames on `/global/event`; the current iOS handler only handles connected (`AppState+SSE.swift:55-56`), and heartbeat falls into `default: break` (:193) and is dropped |
| subagent | — | child session events carry the **child sessionID** on the same bus as parent events (the client routes by sessionID); the parent session's task part events carry the parent sessionID, stay `running` during execution, and `state.metadata.sessionId` already points at the child session (`task.ts:185-195`). iOS today only processes currentSessionID events; keep that |

Live timeline (verified facts from session_status_bar, cited here so the probe does not need to run again):

```text
t+0.0s  session.status=busy
t+1.2s  message.part.updated tool=bash status=pending→running→completed (three frames pushed separately)
t+1.3s  step-finish part carries tokens; session.updated pushes cumulative totals
t+2.5s  session.updated; session.status=idle
```

## 4. Client Current-State Inventory (iOS, master `3c603dc`, all file:line re-verified)

| Location | Current state |
|---|---|
| `AppState+SSE.swift:9-39` | `connectSSE`: reconnect loop + backoff (2s start, 30s cap) + `bootstrapSyncCurrentSession` after reconnect; serial `for try await` + `await handleSSEEvent` |
| `AppState+SSE.swift:57-76` | `session.status` handler: busy/idle/retry only updates `sessionStatuses` + `updateSessionActivity`, **triggers no REST** (a unit test asserts `messagesCallCount == 0`) |
| `AppState+SSE.swift:107-118` | `message.updated` → `await loadMessages() + await loadSessionDiff()` |
| `AppState+SSE.swift:119-131` | `message.part.delta` → only `recordVisibleToken` (throughput), does not update text |
| `AppState+SSE.swift:132-155` | `message.part.updated` → `applyMessagePartUpdate` (always `.finalized`) → `await loadMessages() + await loadSessionDiff()` |
| `AppState+SSE.swift:193` | `default: break` (`server.heartbeat` is dropped here) |
| `AppState+SSE.swift:393-395` | `applySSEEventForTesting`: thin pass-through to `handleSSEEvent` (test entry point) |
| `MessageStore.swift:9-17` | `@Observable final class MessageStore`: `messages: [MessageWithParts]` (only a whole-array replacement path), `partsByMessage: [String: [Part]]` (**written by the app but never read**, only tests read it) |
| `MessageStore.swift:11-14, 154-169` | `MessagePartUpdateOutcome { .ignored, .finalized }`; `applyMessagePartUpdate` only does `recordPartType` bookkeeping |
| `MessageStore.swift:21` | `pendingOptimisticMessageIDs` (optimistic user row reconciliation is pure id membership) |
| `Models/Message.swift:254-264` | `MessageWithParts { info: Message, parts: [Part] }`, not Equatable, not Identifiable; `Part` is Identifiable by `id` |
| `AppState+Messages.swift:22-90` | `loadMessages`: `GET /session/{id}/message?limit=20` + stale guard + optimistic merge (id membership, keep-latest = server version overrides temp parts) + `partsByMessage` rebuild + `refreshSessionActivityText` when busy (2.5s debounce) |
| `AppState+Messages.swift:152, 209-211` | optimistic user row: deterministic `msg_<uuid>` (`makeServerID`, the reconciliation basis from commit c9c0be8) sent to the server with the prompt |
| `AppState+Messages.swift:213-269` | `appendOptimisticUserMessage`: temp text part id `temp-part-<messageID>` + temp file parts |
| `AppState+Messages.swift:119-135` | `loadSessionDiff`: `GET /session/{id}/diff` |
| `AppState.swift:878-888` | `shouldProcessMessageEvent` (event entry guard, lets through events without sessionID) / `shouldApplySessionScopedResult` (stale guard for REST results). `message.part.updated/delta` uses an inline `sessionID == currentSessionID` check (SSE:124,134) plus another layer inside `applyMessagePartUpdate` |
| `SSEClient.swift:52-137` | subscribes to `baseURL + /global/event`; byte-by-byte line parsing, `:` comment frames dropped, `data:` frames JSON-decoded into `SSEEvent{directory, payload{type, properties}}`; heartbeat/connected are plain data frames (no special handling in the parsing layer) |
| `ChatTabView.swift:563-588` | message list is not lazy (ScrollView+VStack+ForEach), identity = group id (`assistant-<joined msg ids>`); today a single part change can only propagate through whole-array replacement of `messages` |
| `SessionFlowTests.swift:1339-1697` | SSE unit tests all live in `AppStateFlowTests`; harness = `makeSSEEvent(JSON)` + `applySSEEventForTesting`; **REST count assertions already exist** (`MockAPIClient.messagesCallCount`/`sessionDiffCallCount`, TestDoubles.swift:98/116) |

Static per-turn REST count (per-event trigger points checked line by line):

```
loadMessages pairs per turn ≈ N × ( 2(message.updated) + 6(step-start + reasoning×2 + text×2 + step-finish) + 3M )
                            = N × (8 + 3M)   (the same count again for loadSessionDiff, all serially awaited)
Example: N=3, M=2 → 42 pairs (84 fetches). A dsh shim host is worse: during tool input streaming each chunk emits one part.updated frame, +1 pair each.
```

## 5. Design

### 5.1 Event-to-Apply Spec

| Event | Current | After the change |
|---|---|---|
| `message.part.updated` | full REST | decode `properties.part` → `MessageStore.upsertPart` (in place, zero RTT); **if the gate fails → fall back to the current REST path** (see 5.2). Keep the `recordVisibleToken`/`recordStepFinish`/`recordPartType` bookkeeping |
| `message.updated` | full REST | decode `properties.info` → `MessageStore.upsertMessageInfo` (upsert by id, keep local parts); keep `recordStepStart`; user message confirmation → `untrackPendingOptimisticMessage` |
| `message.part.delta` | throughput only | append to local part.text by partID (in-memory streaming); keep throughput |
| `message.part.removed` | `default: break` | delete the part by `{sessionID, messageID, partID}` |
| `message.removed` | `default: break` | delete the row by `{sessionID, messageID}` |
| `session.status` | local state update, no REST | keep; **`idle` additionally triggers one reconciliation** (`loadMessages` + `loadSessionDiff`, new behavior) |
| `session.updated` / `permission.*` / `question.*` / `todo.updated` / `session.error` | lightweight events | leave unchanged |
| `server.connected` | bootstrap poll | leave unchanged |
| `server.heartbeat` | dropped via `default: break` | explicit case, no action (timestamp refreshed uniformly at the `handleSSEEvent` entry, see 5.6) |

General rules:

- **sessionID gating unchanged**: message-level events are processed only for `currentSessionID` (the existing `shouldProcessMessageEvent` / inline comparison locations stay put).
- **Idempotent**: upsert by ID, safe against duplicates and out-of-order arrival (a part arriving before its message → shell row, see 5.3; the server keeps FIFO order for same-session events).
- **Stale guard**: events are processed synchronously (no "sent → returned" window), so the existing inline `== currentSessionID` check is the guard; nothing new is needed.

### 5.2 `MessageStore` Upsert Implementation Spec

New methods (all in `MessageStore.swift`, near `applyMessagePartUpdate`):

```swift
// Returns .applied (updated in place) / .needsReconcile (gate failed, caller falls back to REST) / .ignored (sessionID mismatch, etc.)
enum PartUpsertOutcome { case applied, needsReconcile, ignored }

func upsertPart(_ part: Part) -> PartUpsertOutcome // shell row's time uses local time (5.3)
func upsertMessageInfo(_ info: Message)            // keep local parts; create a shell row when absent
func removePart(messageID: String, partID: String)
func removeMessageRow(messageID: String)           // also clear the partsByMessage key
```

Handler-side skeleton, `message.part.updated` branch (`AppState+SSE.swift:132-155`):
The existing sessionID gating + bookkeeping block (:133-148, `recordVisibleToken`/`recordStepFinish`) is kept as is;
the `applyMessagePartUpdate` switch at :149-155 is replaced with the code below. Note that today's switch sits **outside** the gating block (`applyMessagePartUpdate` does its own sessionID check internally); the new code makes `part.sessionID == currentSessionID` an explicit gate:

```swift
if let partObj = props["part"]?.value as? [String: Any],
   let data = try? JSONSerialization.data(withJSONObject: partObj),
   let part = try? JSONDecoder().decode(Part.self, from: data),
   part.sessionID == currentSessionID {
    switch messageStore.upsertPart(part) {
    case .applied:
        break // zero REST
    case .needsReconcile:
        await loadMessages()
        await loadSessionDiff() // gate fallback = current path
    case .ignored:
        break
    }
} else {
    // part missing/decode failure: today's .finalized precondition is "partObj has messageID+id and a matching sessionID";
    // a decode failure means the id may be missing; today's behavior is .ignored (no REST), so REST here is a slightly tighter, safe direction
    await loadMessages()
    await loadSessionDiff()
}
```

**Delete at the same time** the `applyMessagePartUpdate` method and the `MessagePartUpdateOutcome` enum (`MessageStore.swift:11-14, 154-169`). Its internal `recordPartType` bookkeeping moves into the handler's bookkeeping block, calling the existing method `messageStore.recordPartType(sessionID:partID:type:)` (`MessageStore.swift:107-112`) directly; first write wins, and the delta path's partType check depends on it.

Handler-side skeleton, `message.updated` branch (rework of `AppState+SSE.swift:107-118`):

```swift
case "message.updated":
    let eventSessionID = props["sessionID"]?.value as? String
    if Self.shouldProcessMessageEvent(eventSessionID: eventSessionID, currentSessionID: currentSessionID) {
        if let infoObj = props["info"]?.value as? [String: Any],
           infoObj["role"] as? String == "assistant",
           let assistantID = infoObj["id"] as? String,
           let sessionID = eventSessionID {
            messageStore.recordStepStart(assistantID, sessionID: sessionID) // keep
        }
        if let infoObj = props["info"]?.value as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: infoObj),
           let info = try? JSONDecoder().decode(Message.self, from: data) {
            messageStore.upsertMessageInfo(info) // 5.2 semantics (includes user message untrack)
        } else {
            await loadMessages()
            await loadSessionDiff() // info missing/decode failure = current path
        }
    }
```

* `upsertPart` semantics:

1. **Gate (payload completeness)**: a tool part must carry a decodable `state` (the `PartStateBridge` dual shape already supports this); a text/reasoning part must carry a `text` field. If not (such as the dsh shim's thin part + top-level delta) → return `.needsReconcile` and the handler takes the current `await loadMessages() + await loadSessionDiff()` path. The gate makes multi-host compatibility automatic: the shim takes the old path, the native server takes the data path.
2. **Row location**: find the `messages` row by `part.messageID`.
   - Row exists: replace-or-insert by `part.id` within `parts` (replacement keeps the original position; repeated pushes of the same part id from the server are state updates, not new parts; insertion appends at the end).
   - Row missing: decide by part type (see the shell row rules in 5.3).
3. **Optimistic temp-part dedup** (critical edge case): if the row is a pending optimistic row (id ∈ `pendingOptimisticMessageIDs`) and the incoming part id has no `temp-` prefix → first remove all `temp-` prefixed parts from that row, then insert the incoming part. This avoids the server's user part event and the optimistic temp part showing side by side.
4. **Rebuild that row in `partsByMessage` in sync** (the app writes it but never reads it, yet `removeMessage`/`appendOptimisticUserMessage` both maintain it, so keep it consistent; tests read it too).

* Decoding: follow the existing example (`AppState+SSE.swift:58-61`) to convert `properties["part"]?.value` to JSON → `JSONSerialization.data(withJSONObject:)` → `JSONDecoder().decode(Part.self)`. On failure → `.needsReconcile`.

`upsertMessageInfo` means: if the message already exists, replace it with the new `info` (note: this does not update the `parts` field, because `message.updated` carries no `parts` information; `parts` come from `part` events and reconciliation); if the message does not exist, insert a shell row (empty `parts`). For a user message that is in the `pending optimistic` state, replace `info` and call `untrackPendingOptimisticMessage(id)` (consistent with the id-membership semantics in `loadMessages`: the server confirming a message with that id adds it to the `pending` set, while `parts` keep the temporary version until reconciliation completes; see the known trade-off in 5.8).

### 5.3 Shell Row Rules (a part arrives before its message)

**Note**: in the normal flow this situation does not occur: the server sends `message.updated` at each step start (creating the assistant message, `prompt.ts:1201`) before part events, and events for one session are FIFO. If it does occur, either the reconnect missed the message.updated or messages arrived out of order. Rules:

- Part types in {`tool`, `reasoning`, `step-finish`, `patch`} (assistant only) → create an empty row: `Message(id: part.messageID, sessionID, role: "assistant", time: local time, remaining fields null)`, then append the part at the end. The empty row must be naturally overwritten by a later `upsertMessageInfo` / `loadMessages`.
- Part types in {`text`, `file`} (can come from user or assistant) → **do not create an empty row; ignore this part** (wait for `message.updated` or reconciliation). Better to not show it for a while than to create an empty row with an unknown role.
- If the part of a `message.part.delta` does not exist locally → ignore (the start frame guarantees the part exists; if the start frame was lost during a reconnect, the end frame/reconciliation converges).

### 5.4 `message.part.delta` Handling

Handler (rework of `AppState+SSE.swift:119-131`). The existing guard chain is `sessionID == currentSessionID && field == "text" && delta non-empty && messageID/partID parseable && partType(for: partID) == "text"` (the last item uses the `partTypes` first-write-wins index, `MessageStore.swift:39,107-112`, written by the part.updated start frame). **Keep all of it**, and hang the new text append inside the same guard:

1. Locate the local part (partID within the current session's row) → `part.text += delta` (mutate `messages` in place). If the part does not exist → ignore (5.3).
2. **Reasoning does not stream**: the guard only lets text parts through; reasoning text lands in the local part only via the end frame (the full `part.updated`), same as today (iOS today also does not render reasoning from deltas), keeping the change surface unchanged.
3. When the end frame (a `part.updated` with full text) arrives, `upsertPart` replaces the whole part → natural convergence (delta concatenation matches the full frame; even lost deltas are overwritten by the end frame).

### 5.5 REST Demoted to Reconciliation

- Remove all per-event trigger points of `loadMessages` and `loadSessionDiff`. Remaining trigger points:

| Trigger | Current | After the change |
|---|---|---|
| SSE (re)connect bootstrap (`bootstrapSyncCurrentSession`) | yes | keep |
| `session.status → idle` | none (only updates local state; a unit test asserts 0 REST) | **New**: `await loadMessages() + await loadSessionDiff()` (turn-final-state reconciliation, includes `time.completed`/tokens; once per turn) |
| Manual refresh / session switch / loadOlder / revert / edit / abort / recover / refresh | yes | keep (the list of non-per-event `loadMessages` call sites is below; none change) |
| Watchdog trigger | none | new (5.6) |
| `session.error` | `await loadMessages` (no diff) | keep unchanged (the error path stays as is; no change-surface growth) |

* Expected: per-turn REST drops from `N×(8+3M)` pairs to 1 (idle reconciliation) + 0-1 (bootstrap, only on reconnect). The heavy message-list load fetch frequency drops significantly, satisfying the hard constraint "data-fetch actions must not grow" (background section of `session_status_bar/design.md`); this is a reduction, not an increase.

**Code location for idle reconciliation**: inside the `session.status` handler (`AppState+SSE.swift:57-76`), appended after `sessionStatuses[sessionID] = decoded`:

```swift
if decoded.type == "idle", sessionID == currentSessionID {
    await loadMessages()
    await loadSessionDiff()
}
```

* Gating note: the existing handler updates status for all sessions (no currentSession filter; `sessionStatuses` is a global map), so the idle reconciliation action must explicitly carry `sessionID == currentSessionID`. The busy/retry branches stay unchanged.

* **List of non-per-event `loadMessages` call sites** (all kept; same for `loadSessionDiff`; main items listed):

- `AppState+Sessions.swift`: `selectSession` :285, `loadSessions` restore hydrate :174, `forkSession` :364, `deleteSession` :395, `abortSession` :482, `bootstrapSyncCurrentSession` :441
- `AppState.swift`: `refresh()` :900
- `AppState+Messages.swift`: `loadOlderMessagesForCurrentSession` :111, `editFromMessage`/revert :191
- `AppState+SSE.swift`: `recoverFromMissingCurrentSessionIfNeeded` :359, `handleRemoteSessionDeleted` :380, `session.error` handler :191 (this path stays, see the table above)

### 5.6 Heartbeat Watchdog

- **Timestamp**: set `sseLastFrameAt = Date()` uniformly at the `handleSSEEvent` entry (any frame, including heartbeat).
- **Check**: a 5s periodic Task (launched when the `connectSSE` stream starts, canceled on stream end/cancel; AppState is `@MainActor`, so no race with the event loop):

```swift
func checkSSEWatchdog() {
    guard let last = sseLastFrameAt, currentSessionID != nil else { return }
    guard Date().timeIntervalSince(last) > Self.sseSilenceThreshold else { return } // 20s
    sseLastFrameAt = Date()
    Task { await loadMessages(); await loadSessionDiff(); await syncSessionStatusesFromPoll() }
}
```

- **Threshold 20s** = 2 heartbeat periods (the server hardcodes 10s). Worst-case recovery latency 25s (20s threshold + 5s check period). Constants: add `sseWatchdogCheckInterval: TimeInterval = 5` and `sseSilenceThreshold: TimeInterval = 20` to the static let constants area of `AppState` (`AppState.swift:165-186`).
- **Wiring (exact locations)**:
  - New `AppState` member (storage properties area, next to `sseTask`, near `AppState.swift:667-668`): `var sseLastFrameAt: Date?` (**internal, no `private`**; unit tests preset it directly via `@testable`; the test target's existing pattern is reading internal state directly, e.g. `state.messageStore...`); `private var sseWatchdogTask: Task<Void, Never>?` (tests never touch it).
  - `connectSSE` (`AppState+SSE.swift:9-39`): `sseWatchdogTask?.cancel()` first at function entry; after the `bootstrapSyncCurrentSession` call (between :25-26 and :26, semantically just before stream consumption) set `sseLastFrameAt = Date()` and launch the watchdog Task:

```swift
sseWatchdogTask = Task { [weak self] in
    while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(Self.sseWatchdogCheckInterval))
        await self?.checkSSEWatchdog()
    }
}
```

- `handleSSEEvent` entry (before the `switch`): `sseLastFrameAt = Date()`.
  - `checkSSEWatchdog()`: new `@MainActor` internal method, placed in `AppState+SSE.swift` (pseudocode above); `syncSessionStatusesFromPoll` already exists (`AppState+Sessions.swift:464-468`), reuse it directly.
  - Cancel the watchdog Task when AppState is torn down / `connectSSE` re-enters (same lifecycle as `sseTask`, the cancel pattern at :10-11).
- **Not polling**: no fixed-period fetching; in the normal case (a heartbeat frame every 10s + business events during a turn) the check is always a no-op.
- **Division of labor with the backoff reconnect**: reconnect handles "the connection dropped" (bootstrap reconciliation after reconnect already exists); the watchdog handles "the connection is alive but no frames". Together they cover silent death.
- **Degraded behavior on hosts without heartbeats** (dsh shim / a hypothetical compatible host): during silence one reconciliation fires every 20-25s = low-frequency polling, far below Android's current busy polling (2s), no regression. If the shim is later confirmed to have no heartbeat and users care, an adaptive option could raise the threshold to 60s after K consecutive no-heartbeat triggers; not in this round.
- **Background scenario**: the Task may suspend while the app is backgrounded; SSE (URLSession) will most likely drop in the background → the reconnect bootstrap already covers the catch-up; after returning to the foreground the first timer tick or the next frame converges. Known trade-off, no special handling.
- Unit test path: expose `sseLastFrameAt` and `checkSSEWatchdog()` as internal (or access directly via `@testable`); in tests set `sseLastFrameAt` to 30s ago → call `checkSSEWatchdog()` → assert `messagesCallCount == 1`.

### 5.7 Explicitly Out of Scope

- **2s busy polling**: not introducing it. Silent death is covered by 5.6; data timeliness is covered by 5.1's direct payload feed.
- **Optimistic busy on send**: the sub-second composer row gap between `sendMessage` and the `session.status=busy` frame is accepted.
- **tile / FileCard visual upgrade**: this goes beyond pure polish; it is the **necessary complement** for surfacing the tool running state (see the UI layer gap): the current collapsed tool row has no per-tool running indicator, and the composer row text depends on the server's `status.message`. The P2 feature must present the running tool explicitly inside the row (tool name + elapsed time), which is the experience Android already has today and the target iOS ultimately aligns with. The existing running state of `ToolPartView` (`ToolPartView.swift:31, 191-198`) takes effect directly once data arrives on time, serving as the transitional form before P2.
- **subagent event handling**: keep as is (only currentSessionID events are processed); the parent session's task part state changes flow through the normal part event path (parent sessionID) and become visible in the UI naturally.
- **`APIConstants.sseEndpoint` dead constant cleanup**: optional while passing through (ConnectionTests asserts it); not blocking.
- **Server changes**: zero.

### 5.8 Edge Cases and Consistency

- **Idempotency/out-of-order**: upsert by ID; shell rows get overwritten by later events; the end frame converges delta concatenation.
- **Optimistic user row**: the server's echoed user `message.updated` overwrites info + untracks; **at the parts level a transient display is accepted**. The server may rewrite user text (such as an analyze-mode prefix; the existing unit test `loadMessagesReplacesOptimisticRowWhenServerConfirmsSameMessageID` asserts the server text wins). On the in-place path that rewrite only converges at reconciliation (idle). Showing the original text during the turn is a cosmetic trade-off and acceptable; if the server sends part events for a user message, the temp-part dedup in 5.2-3 guarantees no duplicate display.
- **revert**: after a revert the client already forces `loadMessages` (current path kept); `message.removed`/`part.removed` events (sent by revert cleanup) now delete the local row/part directly, which is more timely than today (waiting for REST).
- **Session switching**: the inline `== currentSessionID` guard drops stale events; switching triggers a bootstrap reconciliation (current behavior).
- **Large sessions**: the upsert only affects the loaded window (limit 20 pages); no memory growth.
- **State changes bypassing the event bus**: none (all server changes go through the bus).
- **compaction**: does not delete or modify historical parts (`tail_start_id` mechanism, verified fact 6 from session_status_bar); no special handling.
- **Render granularity**: `MessageWithParts` is a struct array in a non-lazy list, so an in-place change to `messages[i].parts[j]` triggers the same Observation surface as whole-array replacement (ChatTabView body level). **This feature's benefit is eliminating per-event REST and event-queue blocking, not render granularity**; per-part observables are a later optimization (the data model is a struct array, which cannot do incremental observables; that would require reference types, out of scope here).

## 6. Relationship to the session_status_bar Feature

* **Clarification**: the naming needs disambiguation. Its "data path" refers to the source of session-level counters (rounds, tool calls, tokens); this feature's "data path" refers to reflecting chat message and message/part state in the UI in real time.

- **What it already did** (observed 2026-09-29, uncommitted in the main checkout): added `statsStore.observeUserMessage` (user role) in message.updated and `statsStore.observeToolPart` in message.part.updated, both before the await REST.
- **Compatibility commitment**: this feature only removes the per-event `await loadMessages/loadSessionDiff`; the `statsStore.observe*` call sites stay exactly as they are (they are all synchronous local bookkeeping and do not depend on REST). The window reconciliation they rely on after loadMessages completes still happens at idle/bootstrap reconciliation (frequency drops; the counters' main input is SSE increments and is unaffected).
- Shared live evidence: the event timeline cited in this document comes from its verified facts (probe `tmp/status_bar_probe.py`).
- Implementation order: independent of each other. Whichever merges first, the other builds on the master after it; the actual branch state at implementation time is what counts.

## 7. Implementation Order (verified step by step)

1. **MessageStore data layer**: add `upsertPart`/`upsertMessageInfo`/`removePart`/`removeMessageRow` + shell row/optimistic dedup logic (5.2/5.3). Pure local logic, no SSE wiring.
   - Verify: new MessageStore unit tests (upsert replace/insert, shell rows, temp dedup, gate `.needsReconcile`).
2. **SSE handler rework** (`AppState+SSE.swift`): rework event by event per the 5.1 table; explicit `server.heartbeat` case; idle triggers reconciliation.
   - Verify: SSE unit tests (see the test spec), full `SessionFlowTests` regression run.
3. **Watchdog**: `sseLastFrameAt` + timer + `checkSSEWatchdog` (5.6).
   - Verify: watchdog unit tests (time injection).
4. **Live acceptance** (scratch server, below) + UI automation screenshots.

## 8. Test Spec

**Existing test rewrites** (`SessionFlowTests.swift`, harness unchanged: `makeSSEEvent` + `applySSEEventForTesting` + `MockAPIClient` counts):

| Existing case (line) | Current assertion | After the change |
|---|---|---|
| `messagePartUpdatedReloadsCurrentSession` (:1522) | `messagesCallCount == 1` | `== 0` + local part state assertions (upsert took effect) |
| `messagePartUpdatedWithDeltaStillReloads` (:1541) | `== 1` | gate-driven scenarios: full part → 0 REST + upsert; shim thin part + top-level delta → stays at 1 REST (regression assertion) |
| `messageUpdatedForCurrentSessionReloads` (:1407) | `== 1` | `== 0` + info upsert assertions |
| `sessionStatusIdleRecordsIdleForCurrentSession` (:1574) | `messagesCallCount == 0` | `== 1` (idle reconciliation, new behavior) |

* **New cases** (same file, same harness):

- part upsert three states: the three tool frames `pending→running→completed` each change local state, with 0 REST throughout.
- delta streaming: `part.updated` (empty text start) → 3×`message.part.delta` → `part.updated` (full end): `part.text` grows segment by segment in between and equals the full text after the end frame.
- shell rows: an assistant-only part (tool) arriving first for an unknown messageID → shell row created; a text part arriving first → none created.
- out of order: a part before `message.updated` → the shell row is completed by the info.
- idempotency: replaying the same frame does not duplicate.
- removed: `message.part.removed` (`{sessionID,messageID,partID}`) deletes the part; `message.removed` deletes the row.
- optimistic: when the server part (non-temp id) arrives for a pending row → temp parts cleared, server part shown; user `message.updated` → untrack.
- non-current-session events are all ignored (0 REST, 0 state changes).
- gate: shim-shaped payload → fall back to REST (`messagesCallCount == 1`).
- watchdog: `sseLastFrameAt` set to 30s ago + `checkSSEWatchdog()` → 1 reconciliation; fresh timestamp → no-op.

## 9. Live Acceptance

- Environment: a scratch server on a temporary port (**do not reuse the 4096/4097 live server**); the prompt uses a long tool like `bash sleep 6`.
- Acceptance points:
  1. After sending, the `session.status=busy` frame arrives → composer row appears + timer starts (sub-second, event driven).
  2. The tool running frame arrives → tile status updates immediately, activity text `Running commands - <cmd>`, elapsed time ticks per second (event driven, no REST dependency). Note the boundary of the current UI form (see the UI layer gap): what is visible is the collapsed row status update + composer row text; the explicit in-row running indicator comes with the P2 tile feature and must not count as a failure in acceptance.
  3. Cut the SSE stream (or simulate silence with a proxy) → the watchdog triggers one reconciliation within ≤25s and the state recovers.
  4. REST count comparison: during a turn the network panel/log shows message fetches = 1 (idle reconciliation), versus 42 pairs today (N=3, M=2 formula).
- UI acceptance: the existing iOS UI automation (screenshots checking composer row and tool tile states).

## 10. Risks and Rollback

- **State drift** (local/server divergence from event parse failures or dropped frames): three reconciliations (bootstrap/idle/watchdog) + the gate fallback as the safety net. During debugging add diff logging: a DEBUG switch (pattern = the `isCarModeEnabled` trio, `AppState.swift:182/243/396`, wrapped in `#if DEBUG`); at reconciliation compare local vs REST and `Logger.debug`.
- **iOS endpoint assumptions**: the design depends on the heartbeat and FIFO of `/global/event` (verified in source); the shim host's heartbeat is unverified, and the degraded behavior has no regression (5.6).
- **Render performance**: in-place updates do not change the trigger surface (5.8), no new risk; streaming deltas are frequent (one frame per token), so the `messages` array changes once per delta → ChatTabView body recompute frequency goes from 0 (iOS today does not render deltas) to token level. **Need live observation of whether scrolling/input stutters**; if it does, the mitigation is to coalesce delta appends at 50-100ms (`lastDeltaAt` throttling, with lost intermediate states converged by the end frame); reserve the switch position during implementation, off by default.
- **Rollback**: no data migration, no protocol/server changes. Reverting the commit returns to today's behavior.

## 11. Effort Estimate

| Item | Estimate |
|---|---|
| MessageStore upsert layer + unit tests | 0.5 day |
| SSE handler rework + test rewrites/additions | 1 day |
| Watchdog + unit tests | 0.5 day |
| Live acceptance + UI automation | 0.5 day |

## 12. Remaining Open Items (not blocking the start)

1. **Whether a turn-level `final completion` message frame** (with `time.completed`) exists. Pending live test; if it does not exist the design is unaffected (idle reconciliation converges).
2. **Whether the dsh shim host sends `server.heartbeat`**. Unverified; the degraded behavior is designed (5.6).
3. **Whether the server sends `part.updated` events for a user message's parts**. Unverified; both cases are covered by 5.2-3 / 5.8.
4. **Whether the delta throttling switch is needed**. Decide after live acceptance (see section 10, Risks and Rollback).
