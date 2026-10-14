# OpenCode server v2 compatibility - implementation notes

Status: implemented on `opencodev2-integration`; live contract gate passed (45/45, 2026-10-12); TestFlight verification still pending.
Date: 2026-10-12
Spec: `docs/v2_server_compatibility.md` (the single source of truth for the wire contract)

## Background

The user's server is already v2.0.26 while the client only speaks v1 HTTP/SSE. The spec was measured against v2.0.18-2.0.20: route prefix `/api/*`, wholesale event name changes (`session.text.*`, `form.*`), and some v1 behaviors with no v2 equivalent (todo, archive write).

## Changes

- **Detection** (`Services/ServerGeneration.swift`): `HostProfile.apiGeneration` (`auto|v1|v2`, decodes to auto when missing, cleared on URL change). On connect, probe `GET /global/health` → `GET /api/info` (8KB body, JSON must parse, 401/403 and timeout stop probing the other leg). The probe result is written back to the profile and drives `APIClient.generation`.
- **REST branching** (`Services/APIClient+V2.swift` + a `generation == .v2` branch at the top of each method): implemented line by line against the spec's "Every current method" table. Exact status codes (prompt 200 or throw, agent/model switch 204, delete/reply 204); `updateSessionArchived` throws 404 without sending a request; `sessionTodos` returns `[]` directly; the form reply table (form id → session + fields + label→value) lives in `APIClient`, fed by `pendingQuestions(sessionID:)` and the SSE `form.created` event.
- **Pure mapping** (`Services/V2Mapper.swift`): session/message/form/permission/model/agent/diff/file/project/status all implemented per the spec tables; the outputs are the existing model types, with no second Session/Message type added.
- **SSE** (`Services/SSEClient.swift` + `AppState+SSE.swift`): v2 frames `{id,type,data}` normalize into the v1 event shape (`payload` is a required v1 field, so v1→v2 sequential decoding is unambiguous); `handleV2SSEEvent` translates line by line per the spec's SSE table into the properties dictionaries the existing handlers accept, and the data path (`MessageStore` upsert / completeness gate) is fully shared with v1; `session.text.started` with no text part triggers one REST fallback per the spec; `session.created/renamed/metadata.updated` go through GET + `applySessionUpdate`.
- **Two approved spec deviations**: (1) v2 `type:"synthetic"` messages are mapped (the receipt card is visible on v2); (2) `isConnected` is set as soon as probing succeeds, without a session-list gate.

## Tests

- `ServerGenerationTests`: probing against saved bodies (v1 healthy / unhealthy / HTML / empty 500 / `/api/info` v2 / 401 stops further probing / timeout / 8KB truncation) + HostProfile binding + the connect flow (mock injection).
- `V2MapperTests`: one test per row of the spec's "Unit tests" section (session map, message rows, prompt encoding, archive, permission, form, model, project, diff, file status, empty todos, delta part id, CarResponseEnvelope).
- `V2APIWireTests`: wire assertions under a URLProtocol stub (paths/queries/request bodies/exact status codes, form table 404, structured send 409 tolerance + polling, v1 paths unchanged).
- `V2SSETests`: frame discrimination + AppState-level translation (started→delta→ended convergence, execution.failed marks the send as failed, form lifecycle, permission flow).

## Open Items

- ~~`scripts/v2_contract_check.py` run against 2.0.26~~ **passed**: on 2026-10-12 against the live server (`http://127.0.0.1:4096`, `2.0.26-local.27a15e7935`), 45/45 passed, exit 0. No spec drift.
- ~~actual field layout of v2 `type:"synthetic"` unmeasured~~ **measured**: scanned all 69 sessions on the live server, 297 synthetic rows in total, only two shapes and both carry top-level `text` (the mapper's main path hits directly):
  1. `{id, time.created, text, type}` (14 rows, plan-mode system-reminder)
  2. `{id, time.created, text, description, metadata.instruction.paths, type}` (283 rows, AGENTS.md instruction loading, `description` such as "Loaded packages\cli\AGENTS.md")
  `payload.text` never appears; extra fields are unread and harmless to the mapper. The synthetic fixture in `V2MapperTests` has been replaced with the two real captured bodies (one covering the rich shape + one covering the minimal shape). No wire-side body with `<task>` receipt syntax was found. The receipt card text is synthesized by the client itself; the wire side only needs synthetic rows to arrive in user form (confirmed).
- To do: ~~TestFlight on-device verification~~ (build 18 installed, verification in progress).
- **Live finding (2026-10-12/13)**: the 2.0.26 build's `/global/health` returns 200 HTML even with bad credentials (the SPA fallback does not go through the auth challenge); 401 appears only on `/api/info`. So when the probe result was `authFailure(healthStatus: 200, infoStatus: 401)`, the user-visible connection error text used the health leg's status → showing a misleading "HTTP 200". Fixed (the authFailure branch of `applyGenerationDetection` now uses `infoStatus ?? healthStatus`, showing "Basic Auth rejected"), with the regression test `authFailureSurfacesInfoLegRejectionNotHealthStatus`. The user's actual problem at the time: in PowerShell, `set X=Y` is cmd syntax and silently has no effect → env not applied → the server printed a random password.
