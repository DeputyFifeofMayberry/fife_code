# OpenCode iOS Client Capabilities

## Goal

Add a typed, permission-granted, resumable device capability to OpenCode iOS that can return to the original session, without opening arbitrary URLs, without copying device-domain logic into OpenCode, and without modifying the OpenCode server tool loop.

The formal wire contract is defined in [`../docs/features/client_capabilities/protocol.md`](../docs/features/client_capabilities/protocol.md). Before making changes, read that file first, plus `Models/ClientCapability.swift`, `AppState+ClientCapabilities.swift`, and the provider App's deep-link parser and result types.

## When to apply

Only device entitlements, sensors, or on-device-only data suit a client capability. When a standalone domain App with its own permission UI and long-lived state already exists, prefer a restricted deep link + callback; lightweight system pickers can integrate directly into OpenCode iOS; work the server can already do keeps using server tools/skills.

Do not move database queries, web APIs, email, or Smart Home server calls onto iOS for the sake of a uniform shape. Do not extract a standalone framework or a general workflow engine either, before a new capability has a clear second consumer.

## Hard boundaries

- Every action must be a stable typed case; the model cannot supply launch/callback URLs.
- The local dispatcher, permission keys, and provider parsers together form the allowlist; the system prompt is not a security boundary.
- Callbacks must use high-entropy single-use IDs, short-lived Pending entries, and a longer but bounded Outbox.
- Correlation must store the host, context, and session; falling back to the current selection is forbidden.
- A callback payload may contain only enums, bounded numbers, and opaque IDs, never user data, tokens, server responses, or free-text errors.
- A synthetic continuation is not user authorization; the returned envelope must not execute any client action.
- After a custom scheme callback, authoritative server data must be re-read; the callback must not be treated as domain fact.

## Acceptance criteria for a new capability

- The structured schema, Swift decoder, and unknown-action fallback all have tests; an unknown action must not cause the whole assistant speech to be lost.
- First authorization, allow once, allow always, revocation, and denial all have defined behavior, and permissions persist only by capability name.
- The launch URL is constructed fixed by the client, and the provider strictly restricts scheme/host/path/query.
- Pending entries are persisted before launch and deleted when launch fails; expired entries, duplicate callbacks, and corrupted files produce no continuation.
- An offline callback first enters the Outbox and, after reconnection, is submitted exactly once to the recorded original session.
- Deterministic message IDs and query-before-retry prevent duplicate model turns.
- Provider and consumer fixtures agree on success/partial/failed/busy, counts, categories, and error codes.
- The original Maps action, session deep link, iPhone/iPad/visionOS platform gating, and the full test suite do not regress.

## Known pitfalls

- Do not make every action a struct with many optional fields. The Health action has no `destination`, and a fixed Maps shape makes the whole structured message fail to decode.
- Do not reuse the session deep-link queue that is processed only after connecting. A callback can arrive before the App has connected; local consumption must complete first.
- Do not insert a tall section above the existing Car toggle in Settings; this once pushed the toggle out of the visible area in the fixture UI. Keep the current order of key controls or update the scrollable test in step.
- Do not delete the Outbox entry immediately upon seeing the continuation user message. It only proves server admission; wait for the corresponding assistant response, and resending is forbidden in the meantime.

## Where changes land

A new capability should update `docs/features/client_capabilities/protocol.md`, the corresponding product/RFC documents, the Swift registry/dispatcher, the provider contract, and the tests. Design drafts or one-off investigations must not become a third source of truth for the protocol.
