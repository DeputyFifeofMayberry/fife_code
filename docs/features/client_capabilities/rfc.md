# iOS Client Capabilities RFC

## Implementation Conclusion

V0 introduces a "local-first" callback path in the client, independent of the regular Session deep link. The traditional `opencode://session/...` still waits for a server connection before resolving the target session, while `opencode://client-action-return/...` forces local consumption of the Pending record into the Outbox first and only submits to the server when the network is available. This design guarantees that even if OpenCode is suspended or terminated by the system during the Health export, the correlation context is not lost.

## Components

- `Models/CarMode.swift`: fault-tolerant Action Union decoding based on `type`; known Maps and Health actions are strongly typed, and an unknown Action still preserves the full `speech` content.
- `Models/ClientCapability.swift`: defines the permission model, the callback record, and the Health result enum.
- `Services/ClientCapabilityCallbackStore.swift`: handles Pending/Outbox management, atomic file writes, expiry checks, the single-flight limit, and bounded cleanup.
- `AppState+ClientCapabilities.swift`: carries authorization, handoff, callback consumption, query-before-retry, and Continuation result projection logic.
- `Utils/OpenCodeDeepLink.swift`: contains two mutually independent, strictly bounded parsers, one for Session links and one for Callback links.
- `APIClient.promptStructured`: accepts an optional deterministic `messageID` parameter.

## State and Relevance

Disk storage has exactly two discrete phases: Pending, waiting for the external callback to return, and Outbox, meaning the callback has passed local acceptance but the Continuation is not yet confirmed complete with the server. Every persisted record is strictly bound to `hostProfileID + carContextKey + sessionID`; callback handling never reads the volatile `currentSessionID`, and the original delivery target never changes because the user switched to another Workspace.

While the permission sheet is showing, the user may switch Hosts. The request therefore captures the current Host Profile at initiation time; if the connected Host has changed by the time the user taps allow, the client refuses to launch the external app, eliminating the risk of binding the original Session to the wrong new Host. Outbox records trigger network submission only when the record's Host exactly matches the currently active Host and that Host is connected; silent cross-Host submission is never allowed.

## Idempotency Strategy

The `callback-id` is both the unique name of the Pending file and a one-time bearer token. Callback consumption uses the transactional order "write Outbox first, then delete Pending"; if an identically named record already exists in the Outbox, the duplicate callback is ignored directly. Continuation submission uses the fixed ID `msg_client_<callback-id>` derived from the `callback-id`, and each retry first pulls the session history to check, avoiding a second round of model inference when the server already admitted the request but the HTTP response was lost in transit.

On the existing synchronous API's normal path, the server returns the assistant response directly. If the history already contains this Continuation's user message but the assistant reply is not finished, the client keeps the Outbox record and re-checks on app cold start, foregrounding, or network reconnect, never blindly re-sending.

## UI and Lifecycle

On the first Health action trigger, the system presents a non-dismissable authorization dialog (no swipe-to-dismiss), forcing an explicit choice among "Cancel", "Allow once", and "Allow always". The Settings screen reflects the current authorization state in real time and offers only revocation of an existing "Allow always" grant.

The cleanup/retry pipeline triggers on app cold start, foregrounding, network recovery, new Pending creation, and callback message receipt. Local acceptance of a callback never depends on network connectivity, while network submission waits for the corresponding Host to be connected. The Continuation's result is projected into Speech/TTS only while the user is still in the original Car context; if the user has moved to another context, the original session record is silently updated in the background, leaving the user's current task undisturbed.

## Verification

Tier 1 and Tier 2 tests fully cover fault-tolerant Action decoding, strict callback parsing, canonical launch URL construction, Pending/Outbox expiry checks and duplicate-consumption guards, the allow-once flow, Continuation recovery into the original session, and deterministic message ID generation. Fixture-based XCUITests focus on the permission reason display and the interaction branches of the three local authorization choices. Test commands are in `docs/tests.md`, and this round's verification results are fully archived in `docs/WORKING.md`.
