# Product specification

Adapter for agents; the canonical product source is
[OpenCode_iOS_Client_PRD.md](OpenCode_iOS_Client_PRD.md) (v0.4). If this page
and the PRD disagree, the PRD wins and this page gets fixed.

- Project: OpenCode iOS Client ("FifeCode"), a native iOS/iPadOS/visionOS
  client for the OpenCode coding-agent server.
- Target users: the owner of a running OpenCode server (developer or
  knowledge worker) who wants to read AI output and steer work away from the
  keyboard.
- Problem and intended outcome: close the human-AI loop — present the AI's
  key decisions fully for review ("Surface → Review → Steer"), with fast
  voice intervention to correct course; a steering terminal first, content
  browsing second.
- Non-goals (PRD §1.1): no code editing on the phone, no OpenCode server on
  the phone, no replacement for the full Web UI; heavy configuration stays
  on the computer.
- Platforms: iOS 17.0+ and visionOS 26.0+ (single app target; iPad-style
  three-column layout on visionOS; SSH tunnel hidden on visionOS).

## Critical user journeys

| ID | User flow | Expected result | Failure/empty state | Test path |
| --- | --- | --- | --- | --- |
| UJ-1 | Connect to a server (Settings) | Connection test passes; profile saved | Clear error; malformed URL auto-corrected on focus loss | `ConnectionTests`, `HostLifecycleTests` |
| UJ-2 | Read a streaming conversation | Messages ascending, autoscroll follows while at bottom; reasoning/tool cards render | Offline fixture UI tests pin layout | `SessionScrollAnchorUITests`, `ToolCardsUITests`, `RenderingTests` |
| UJ-3 | Send a message and steer | Send works; on failure the input is restored with an error alert | Send-failure path covered in unit tests | `MessageReconciliationTests` |
| UJ-4 | Monitor background subagents | Parent row/status bar shows running descendants; tap jumps to child | Aggregation excludes self/idle | `SessionTreeTests`, `TaskNotificationUITests` |
| UJ-5 | Review file changes | File tree + diffs + previews render; images zoom/pan | Stale content resets on switch | `FileFlowTests`, `FileSearchUITests` |
| UJ-6 | Switch models / check quota | Shortlist reorders (handle commits on release); quota pill shows the provider window | Missing window → window name only, no `--` | `ModelShortlistTests`, `ModelShortlistUITests`, `AIUsageQuotaTests` |
| UJ-7 | v1/v2 server compatibility | Correct REST/SSE behavior per detected generation | Probe failure → honest error | `ServerGenerationTests`, `V2MapperTests`, `V2APIWireTests`, `V2SSETests` |
| UJ-8 | Background/relaunch | SSE reconnect + one-shot compensating sync; state consistent | Polling parse noise logged, not fatal | `SSELifecycleTests`, `SessionDeletionRecoveryTests` |

## Functional contract

Significant features get a spec under `features/` (per the house convention)
or `specs/` before implementation; authorization, persistence, offline/
restart effects, edge cases, and observable acceptance conditions come
first. The wire contract is specified in
[v2_server_compatibility.md](v2_server_compatibility.md) before code.

## Constraints

- Privacy/data retention: credentials (server Basic Auth, SSH keys) stay
  on-device; no telemetry; chat content lives on the server, not synced
  locally beyond caches.
- Devices/input: iPhone compact single-column; iPad/visionOS three-column;
  hardware keyboard `Enter` inserts a newline (send is the dedicated button);
  voice transcription in the composer.
- Accessibility/behavioral: en/zh-Hans localization in Settings; IME
  composition must commit marked text normally.
- Performance: streaming chat stays responsive on long sessions; message
  paging before rendering rework (`docs/lessons.md` lesson 14).

## Acceptance principle

Passing tests alone do not establish that the product meets the owner's
intent. Significant changes get a separate product-acceptance decision;
on-device (TestFlight) confirmation is required where the change is
device-visible (see `docs/TECH_DEBT.md` TD-4/TD-5).
