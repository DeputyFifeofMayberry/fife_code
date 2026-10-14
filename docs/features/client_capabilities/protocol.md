# iOS Client Capabilities Protocol

> Last verified: 2026-08-23 · against the current OpenCodeClient implementation

## Protocol Scope

This protocol defines the behavior standard for OpenCode iOS acting as a capability consumer, covering structured action parsing, cross-app handoff to Health Quantification, callback result acceptance, and the full lifecycle of continuation into the original Session. V0 registers exactly one concrete capability, `health_quantification.export_all`.

## Structured Action

In Car Mode the model returns a `CarResponseEnvelope` container (with `version`, `status`, `speech`, `confirmation`, and `clientActions` fields), where the `clientActions` array allows at most 1 action. The schema for the Health export action is:

```json
{
  "id": "health-export-1",
  "type": "health_quantification.export_all",
  "reason": "Sync last night's sleep data to complete the sleep analysis"
}
```

Field constraints (defined in `CarModeProtocol.outputFormat`, declaring `additionalProperties: false`):

- `id`: 1-100 characters, used only for link diagnostics and request dedup.
- `type`: fixed to `health_quantification.export_all`, the single key for action dispatch routing and permission checks.
- `reason`: 1-240 characters and non-empty after trimming; shown only in the client's local UI as the authorization explanation.

The model must never specify a URL or continuation text in its return value; the callback URL and its parameters are always constructed independently on-device by OpenCode iOS (the System Prompt explicitly forbids the model from inventing URLs). For unknown `type` values, the parsing layer maps them into the `unknown` enum branch, keeps the outer envelope's `speech` content, but the client never executes the action.

## Authorization and Dispatch (verified update 2026-08)

The permission state `ClientCapabilityPermission` has two values, `ask` (ask every time, the default) and `allow_always` (always allow), persisted in UserDefaults under the key `clientCapability.healthExportAll.permission.v1`; the user can reset it back to `ask` manually in Settings.

- When the model returns a Health export action, `requestClientCapability` runs the authorization logic: if the permission is `allow_always`, dispatch executes directly; otherwise it builds the `pendingClientCapabilityRequest` state and presents the `ClientCapabilityPermissionView` authorization dialog, letting the user choose among "Allow once", "Allow always", and "Cancel".
- In the `dispatchClientCapability` flow, the system first calls `createPending` to generate a `callbackID` and persist the local Pending record, then opens the target launch URL via `UIApplication.shared.open`; if the open fails, it immediately cleans up the just-created Pending record and throws `launchFailed`.
- For the same capability, if an unexpired Pending or Outbox record already exists locally, `createPending` throws `duplicateCapability` directly and the UI shows the "capability already running" hint (L10n `capabilityAlreadyRunning`), preventing concurrent duplicate requests.
- Every persisted record is strictly bound to the Host Profile context at request time: it stores `hostProfileID` and `hostConfigurationSignature` (a SHA-256 hash computed from the transport mode, server URL, Basic Auth username, and SSH configuration).

## Launch Contract

```text
healthquantification://export-all?callback=<percent-encoded-callback-url>
```

The decoded callback format is strictly fixed to:

```text
opencode://client-action-return/<callback-id>
```

The `callback-id` is 32 random bytes encoded as unpadded base64url, fixed at 43 characters in the current implementation; the receiving consumer's validation allows 43 to 128 characters drawn from ASCII letters, digits, `-`, and `_`. This ID serves as both the request identity and the one-time bearer token. OpenCode must persist the Pending record to local disk before calling `UIApplication.open` to launch the external app; if the launch fails, it rolls back by deleting the Pending record.

## Return Contract

```text
opencode://client-action-return/<callback-id>?status=success&sent=1240&upserted=1240
```

Accepted query fields (`status`, `sent`, and `upserted` are required; `failed` and `error_code` are optional):

| Field | Required | Allowed values |
|---|---|---|
| `status` | yes | `success`, `partial`, `failed`, `busy` |
| `sent` | yes | decimal integer, 0 to `Int32.max` |
| `upserted` | yes | decimal integer, 0 to `Int32.max` |
| `failed` | no | a duplicate-free comma-separated subset of `sleep,vitals,body,lifestyle,activity,workouts` |
| `error_code` | no | `category_failure`, `export_in_progress`, `invalid_server_url` |

The parser strictly rejects any request containing unknown query fields, duplicate fields, an empty query, UserInfo, a port, a fragment, extra path segments, a non-canonical callback ID (the URL-decoded string differing from the pre-decode string), or illegal enum values. The existing Session deep link (`opencode://session/<id>`) is likewise strictly forbidden from carrying any query, fragment, UserInfo, or port, and the Session ID must be prefixed with `ses_`, 5-256 characters total, drawn only from `[A-Za-z0-9_-]`.

## Local Persistence (verified update 2026-08)

```text
Application Support/ClientCapabilityCallbacks/
  Pending/<callback-id>.json
  Outbox/<callback-id>.json
```

The Pending record (data structure marked `version: 1`) fully stores `callbackID`, `capability`, `hostProfileID`, `hostConfigurationSignature`, `carContextKey`, `sessionID`, `assistantMessageID`, `actionID`, the deterministic `continuationMessageID` (fixed to `msg_client_<callback-id>`), the `createdAt` timestamp, the `expiresAt` expiry (computed as `createdAt + 15 minutes`), and the `result` (initialized to null).

On a valid callback request, the system validates the Pending record and migrates it to the Outbox directory (filling in `result` and safely deleting the original Pending file); Outbox records are kept locally for at most 6 hours (counted from the record's `createdAt`). A duplicate callback must never produce a second Continuation record (when an identically named record already exists in the Outbox, the `consume` method returns nil directly). The whole callback directory holds at most 50 records (Pending and Outbox counted together); corrupted data, unknown versions, illegal filenames, and expired records are deleted automatically during bounded cleanup, and if valid records still exceed the 50-record cap, the oldest by `createdAt` are dropped one by one. All disk writes go through "write temp file + atomic move", preventing file corruption from concurrent writes.

## Continuation Contract (verified update 2026-08)

The client sends the following structured message to the original Session recorded in the Pending entry:

```json
{
  "kind": "client_action_result",
  "capability": "health_quantification.export_all",
  "invocation_id": "<callback-id>",
  "status": "success",
  "sent": 1240,
  "upserted": 1240,
  "failed_categories": [],
  "error_code": null
}
```

The `POST /session/:id/message` request explicitly passes a `messageID` deterministically derived from the callback ID (that is, `continuationMessageID = msg_client_<callback-id>`). The request payload also carries `system` (using the preset `clientResultSystemPrompt`), `format` (matching the Car Mode json_schema constraint), `agent: "build"`, and Car Mode-specific model configuration.

Before actually submitting the network request, the client must first query the session's message history for the idempotency check:

- If no user message with `id == continuationMessageID` exists in the history yet → submit the request to the server directly.
- If the message exists but the corresponding Assistant reply has not finished → keep the local Outbox record and poll for reconciliation every 2 seconds, up to 15 attempts; if it still is not done after the timeout, mark this Continuation as failed (keeping the Outbox locally for later retry).
- If the corresponding Assistant reply has finished → validate the structured response data and, once it passes acceptance, delete the local Outbox record completely.

Network submission and result acceptance are both guarded by strict Host and route checks: all of the following must hold at once: `isConnected`, `currentHostProfileID` matching the record's Host Profile, `hostConfigurationSignature` exactly matching the current running configuration, and no `deepLinkRouteID` generation jump. If the original Host Profile was deleted by the user, silently clean up the Outbox record (no error thrown); if a configuration change is detected (signature mismatch), delete the Outbox record and surface `continuationFailed`.

A 401, 403, or 404 response is a terminal failure: the client deletes the Outbox record and marks it failed. Other network jitter or 5xx server errors keep the Outbox record for a safe retry on network reconnect or the next trigger, until the record expires.

A client-synthesized synthetic result never constitutes new user authorization. The response payload produced by the Continuation must never carry any Client Action (`clientActions` must be empty), must be a completed assistant message in the same Session, and must satisfy envelope `version == 1` with a non-empty `speech` field; the AI must use the result to re-read data freshness and sample metrics from the Health server and then deliver the final answer to the user's original question.

## Security Boundary (verified update 2026-08)

The V0 architecture explicitly accepts the residual risk that a malicious app on the same device could theoretically hijack listening on the Custom URL Scheme. The `callback-id` only proves the caller holds the one-time bearer token; by itself it is not an absolutely trusted credential proving the underlying health data actually synced. The callback URL carries only the export's summary outcome (`status`, `sent`, `upserted`, `failed`, `error_code`), never concrete health data details, and triggers no authorization-change side effects. In the Continuation phase, the System Prompt forces the AI to actively re-pull real data from the server for verification instead of unconditionally trusting the status description carried in the URL. To fully defend against same-device malicious-app spoofing later, upgrade the channel to Universal Links based on Associated Domains rather than blindly expanding the payload transported over the custom scheme.
