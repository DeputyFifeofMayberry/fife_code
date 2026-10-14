# Agent Catalog Validation and Delete-Failure Visibility

Date: 2026-09-27

## Background

When connecting to a host that only exposes `build`, the client may still send a prompt carrying the previous server's agent name and get a 501 back. The second issue is deletion: when the host replies 501 to `DELETE /session/:id` and the error message hides the status code and body, the user believes the deletion succeeded.

The iOS selection state is `selectedAgentIndex`, not a persisted agent name. `Message` also does not decode `info.agent`, so there is no path to infer the agent from history. The cross-host residue comes from the in-memory agent list and index: on host switch, `resetConnectionRuntimeForHostSwitch` did not clear agents. The placeholder list (`OpenCode-Builder` etc.) is also not the current server's `GET /agent` result.

The delete path already throws `APIError.httpError` in `APIClient.makeRequest` for status >= 400, `AppState.deleteSession` only deletes the local row after the request succeeds, and the list UI alerts with `error.localizedDescription`. The gap is that `APIError` does not conform to `LocalizedError`, so the alert cannot show the status code and body.

## Changes

`AgentInfo.effectiveSelectedAgent(selection:agents:)`: keep the selection if the catalog is empty; keep it if the catalog contains that name; otherwise take the first visible agent, and if none, `"build"`.

Application points:

- After `loadAgents()` succeeds, revalidate `selectedAgentName` against the returned list and sync the picker index.
- `sendMessage()` revalidates through `agentNameForPrompt()`. When the current host's catalog is not yet available, do not send the placeholder name; use `"build"`.
- `loadMessages()` revalidates the same way after success. No agent inference from messages; when the catalog is empty, the selection stays unchanged.
- On host switch, clear the agent list and catalog flag and reset the selection to `"build"`, so the previous server's list never vouches for the new host.
- The default selection is `"build"`, not index 0 of the placeholder list. When the server catalog contains `build`, it gets selected even if it is not the first item. Only without `build` does it fall back to the first visible agent.

Deletion: `APIError` now conforms to `LocalizedError`. The non-2xx description is `HTTP <status>: <body>`. The failure branches in the UI and local list need no change.

## Tests

`OpenCodeClientTests`:

- Pure function: unknown falls back, known is kept, empty catalog leaves it untouched, and no visible agent returns `"build"`.
- `loadAgents` / `sendMessage` / `loadMessages` correcting unknown names, and an empty catalog not changing the selection.
- Host switch drops the previous server's agent.
- The `APIError` message contains the status code and body; the local row survives a delete 501.

No UI test was run. The delete alert still goes through the original `actionError = error.localizedDescription`.
