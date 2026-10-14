# OpenCode iOS Push Notification Research

Updated: 2026-07-24

## Conclusion

We can deliver notifications without modifying the source of each OpenCode Server, but relying on iOS client changes alone cannot achieve timely and reliable background message push.

While the iOS app is in the foreground, the existing code already consumes the `/global/event` stream in real time, precisely identifies `question.asked` and `permission.asked` events, and classifies them as Needs Attention states requiring human involvement. Once the app moves to the background, the system proactively disconnects the SSE long connection and the SSH tunnel; even without an active disconnect, the OS suspends ordinary network connections within a short time. To reach the user when the app leaves the foreground, a resident peer service must keep listening to the server's event stream and wake or notify the phone through Apple's official APNs channel.

Weighing all of this, we recommend adding a standalone Notification Bridge sidecar service instead of intrusively modifying OpenCode Server's core code:

```text
Multiple OpenCode servers
        │ existing SSE / REST, protocol unchanged
        ▼
Resident notification bridge
        │ classifies question / permission / done / error
        ▼
       APNs
        ▼
OpenCode iOS, tapping the notification opens the corresponding session
```

This architecture achieves the "zero server changes" goal at the cost of one extremely lightweight resident sidecar service. If even this sidecar cannot be deployed, the system degrades to background intermittent polling constrained by system scheduling with no timeliness guarantee, which cannot serve as the shipped real-time push solution.

## The Client Already Has Half the Capabilities

First, the existing `SSEClient` already connects stably to the `GET /global/event` endpoint, so the OpenCode server needs no new notification API (see `OpenCodeClient/OpenCodeClient/Services/SSEClient.swift:51-137`).

Second, the client's business layer already identifies the two core human-blocking event types, `permission.asked` and `question.asked` (see `OpenCodeClient/OpenCodeClient/AppState+SSE.swift:125-138`), and `AppState` already aggregates Attention to-do counts per Session (see `OpenCodeClient/OpenCodeClient/AppState.swift:487-503`).

Third, the server's existing REST API supports reconciling pending Permissions and Questions after a reconnect, so neither the Bridge nor the client needs to over-rely on the fragile transient SSE stream (see `OpenCodeClient/OpenCodeClient/Services/APIClient.swift:386-423`).

Fourth, the routing and navigation basics for notification-tap wake-up are already in place. The client natively supports `opencode://session/<session_id>` deep links (see `OpenCodeClient/Info.plist:5-15`).

The genuinely missing piece is background delivery. The app proactively disconnects SSE and the SSH tunnel when backgrounded (see `OpenCodeClient/OpenCodeClient/ContentView.swift:738-746`), and the current Xcode project has no `aps-environment` entitlement configured and no Remote Notifications background mode enabled.

## Why a Client-Only Solution Does Not Work

### Local notifications only cover events received while the app is running

If a `question.asked` event arrives while the app is in the foreground, the client can naturally schedule a local notification immediately. But the core scenarios where users actually depend on push are precisely when the app is backgrounded or the phone is locked; during those periods no network event reaches the phone at all, so the client has no moment to trigger a local notification.

### Background polling can be a fallback, not the real-time channel

iOS's `BGAppRefreshTask` mechanism can wake the app intermittently in the background to call `/permission`, `/question`, and `/session/status`, but its timing is a system-policy black box, easily delayed or skipped outright, and Apple provides only a very short execution window. It suits badge calibration or fallback reconciliation and is entirely unable to carry the "AI has stopped and is waiting for user confirmation" immediacy requirement (see [Apple: Choosing Background Strategies](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)).

There is also a second obstacle in the current product architecture: SSH-connected hosts need the app to negotiate and establish the tunnel, and the current background policy closes the tunnel when backgrounded. Even if the system occasionally grants one background wake-up, having the app complete an SSH handshake in the background, fully poll multiple hosts, and then fire local notifications is engineering-wise very unstable and prone to timeouts.

### Live Activity is not a substitute for APNs

Live Activities fit continuous progress display of known long-running tasks, but once the app is suspended, updating the Dynamic Island or the lock screen widget remotely still depends on the ActivityKit push channel underneath. It is also a poor carrier for Permission or Question requests, which are discrete, occasional, and top-priority human decisions. The first phase should focus on getting standard Remote Push working; evaluate Live Activity separately later if long-task progress display is needed.

### Do not borrow PushKit or fake background modes

PushKit is Apple's channel for strong real-time scenarios such as VoIP calls. Borrowing it to keep an ordinary OpenCode event stream alive violates platform policy and carries a high App Store removal risk. Faking audio playback or background location is equally unsuitable for this product and cannot be the technical approach.

## Recommended Architecture: Zero Server Source Changes, Add a Sidecar Bridge

The Notification Bridge has four core responsibilities:

1. Maintain the APNs Device Tokens reported by iOS client installations, along with each installation's subscribed Host and Session scopes.
2. Keep long-lived listeners on the existing `/global/event` SSE stream of each configured OpenCode Host; after a disconnect, call `/permission`, `/question`, and `/session/status` to reconcile state.
3. Use centralized filtering and dedup rules to precisely decide which key events trigger a push.
4. Call APNs to deliver user-visible notifications. The push payload carries only non-sensitive Host Profile ID, Session ID, and event enum values; the notification body must never contain user prompts, source paths, or server credentials.

APNs' standard architecture itself requires the client to register its Device Token with a Provider, and the Provider then pushes messages to APNs over a bidirectional secure connection (see [Apple: Setting up a remote notification server](https://developer.apple.com/documentation/usernotifications/setting-up-a-remote-notification-server)).

### Where the bridge lives

For the lowest-change initial rollout, deploy the Bridge on an always-on machine that can reach all OpenCode Hosts directly. It can run as a standalone daemon, a Docker container, or a lightweight cloud service, with zero compile-time dependency on the OpenCode server process code.

If the Servers sit in isolated LANs with no single node that can reach every SSE stream, there is still no need to modify server source: deploy a lightweight Watcher proxy in each network domain that reports cleaned, normalized Attention events to the central APNs Gateway. The APNs push private key is held centrally by the Gateway only, never distributed to edge nodes.

Compared with intrusively writing push logic inside every Server, this deployment boundary fits the current multi-Host architecture better: routine OpenCode official upgrades cannot break the push mechanism, and the push filtering rules evolve in a single place.

## Multi-User Products Should Prefer an OpenCode Plugin

Having a central Bridge directly hold every user's Host access only fits personal private deployments. In a multi-user commercial product, the center must never collect users' OpenCode URLs, Basic Auth credentials, SSH private keys, or tunneling credentials. The saner topology is a Plugin listening to events inside the user's local OpenCode process, sending a lightweight event digest to the central APNs Gateway over outbound HTTPS only when triggered:

```text
User machine: OpenCode + notification plugin
                    │ uploads only a minimal attention envelope
                    ▼
              APNs gateway
                    ▼
                 iPhone
```

This approach needs no patches to OpenCode Core source, only one Plugin installed by the user on the host machine. OpenCode officially supports auto-loading local JS/TS plugins from `~/.config/opencode/plugins/` and supports declaring npm package dependencies in the `plugin` list of `opencode.json`, fetched and installed at server startup (see [OpenCode Plugins](https://opencode.ai/docs/plugins)).

### The current plugin API is enough for notifications

OpenCode's public `Hooks.event` API natively receives strongly typed `Event` objects (see `opencode-official/packages/plugin/src/index.ts:222-225`). The stable events declared in the official docs fully cover the core first-phase push scenarios:

- `question.asked` / `question.replied` / `question.rejected`
- `permission.asked` / `permission.replied`
- `session.error`
- `session.idle` or `session.status`

The server's `serve` command layer explicitly mounts `Plugin.node` (see `opencode-official/packages/opencode/src/server/routes/instance/httpapi/server.ts:212-225`), so this hook is by no means effective only in terminal TUI mode. A Server Plugin can also access the in-process SDK Client instance, the current working directory, and the server URL (see `opencode-official/packages/plugin/src/index.ts:56-65`).

OpenCode's underlying event dispatch currently calls plugins fire-and-forget asynchronously (see `opencode-official/packages/opencode/src/plugin/index.ts:251-257`), so push network latency can never block a session's normal inference and tool execution. The Plugin itself must carefully catch all network errors and fall back to a local outbox for retries, preventing an unhandled rejected promise from turning into an uncaught process crash.

### Difficulty Assessment

A basic plugin that POSTs to a webhook once after receiving a `question.asked` event is a very small amount of work; the core code only involves event filtering, payload trimming, and signed requests. Community notification plugins for Pushover, Discord, Slack, and others already exist, which amply confirms this extension path's maturity and feasibility.

Building a production-ready full loop is medium-sized work, with the core complexity on the platform and network sides rather than in OpenCode itself:

| Module | Difficulty | Main work |
|---|---|---|
| OpenCode plugin | small | event filtering, privacy trimming, signing, outbox |
| user pairing | medium | securely bind a host installation to an iOS device |
| APNs gateway | medium | device token lifecycle, auth, rate limiting, invalid token cleanup |
| reliability | medium | local persistence, retries, dedup, resolving event-canceled badges |
| version compatibility | small to medium | tracking version changes of public event names and payloads |

### Preconditions for Controllable Maintenance Cost

The Plugin itself should stay "lean and focused": strictly limited to consuming the public `event` hook, never calling OpenCode's internal unpublished modules, never intruding on the normal Permission or Question flow, and never synchronously blocking inside the hook callback waiting for the Gateway. Notification copy assembly, user do-not-disturb preferences, rate limiting, and APNs interaction all live on the Gateway side; the Plugin only delivers a versioned minimal envelope.

The envelope should contain only metadata such as `schema_version`, the Plugin/OpenCode versions, Installation ID, Event ID/Type, Session ID, Request ID, and timestamps. By default it must never upload the Question body, matched Permission rules, user prompt content, or concrete file paths.

For versioning, maintain a lightweight compatibility matrix covering at least the current latest and the previous official OpenCode release. OpenCode has historically had v1/v2 event name changes, so the design must not assume payload formats last forever; but since we depend on official public standardized APIs, maintenance and upgrade costs are significantly below maintaining a fork branch or intrusively parsing text logs.

### Recommended Pairing Flow

1. The iOS app registers its APNs Device Token with the central Gateway and generates a short-lived temporary pairing code.
2. The user runs the setup command from the Plugin package in the Host terminal and enters the pairing code; the command completes Plugin installation and configuration and persists a local Installation Secret.
3. The Plugin then uses only that secret to sign structured Attention events sent to the Gateway. The Gateway holds none of the user's OpenCode login credentials and has no network permission to reach back into the Host.
4. On delivery, the payload carries only Installation ID and Session ID. After receiving the push, the iOS client looks up the local Host Profile by Installation ID and reuses the existing credentials stored in Keychain to connect and open the corresponding Session.

So the precise phrasing of "zero server changes" in real product evolution is: no fork or patch of OpenCode server source, but the user installs one official standard Plugin on the host machine. If even a Plugin or companion process cannot be deployed, the only path left is pushing OpenCode official to natively support webhooks at the Core level; the iOS client alone cannot build a highly available background push system.

## First-Version Notification Rules

The first version must not push every server event indiscriminately to the phone; keep coverage strictly narrow:

| Event | Default behavior | Reason |
|---|---|---|
| `question.asked` | notify immediately | AI is explicitly blocked, waiting for input |
| `permission.asked` | notify immediately | AI is explicitly blocked, waiting for approval |
| `session.error` | notify | needs human recovery or judgment |
| busy/retry → idle | configurable notification | valuable, but high-frequency tasks easily create noise |
| message/todo updates | no notification | not attention; only updates in-app state |

Generate the dedup key from `host_id + event_type + request_id`. When the SSE connection drops and REST compensation reconciliation runs, re-scanning the same pending requests must be accurately recognized and duplicate pushes suppressed. After the user handles a Permission or Question, the client should clear the corresponding badge promptly; notification taps reuse the existing Session deep link, and after app activation the client fetches the latest request state from the server in real time, never blindly trusting the stale context carried in the push payload.

## Change Scope and Difficulty

### iOS client: small to medium

Configure the Push Notifications capability and the permission-request interaction, generate and report the APNs Device Token, define the foreground presentation policy, wire notification-tap session routing and badge clearing, and add automated tests. Since the existing deep link mechanism and Attention state model are directly reusable, the client side is not the main difficulty.

### OpenCode server: can be zero

The Bridge mode consumes the existing SSE and REST endpoints directly, requiring zero changes to OpenCode's API definitions, event schemas, or each Server node's business implementation.

### New bridge: medium

The core work concentrates on multi-Host long-connection lifecycle management, secure storage of host credentials, SSE reconnect and REST state reconciliation, event idempotent dedup, and APNs token registration and invalidation maintenance. A single-Host validation demo is very light; a highly available production service with multi-Host isolation is where this module's real engineering weight lies.

## Not Recommended

| Approach | Assessment |
|---|---|
| local notifications only in iOS | only notifies about events received in the foreground; does not solve the problem |
| iOS polls all servers with BGTaskScheduler | usable as a low-frequency fallback; not timely, execution not guaranteed, SSH hosts especially fragile |
| each OpenCode server connects to APNs directly | works, but replicates tokens, private keys, and notification rules to every server; highest upgrade and operations cost |
| modify OpenCode core to add a push endpoint | unnecessary now; the existing SSE/REST is sufficient as the event source |
| Live Activity replacing normal push | does not hold; remote updates still need push, and question/permission fit normal notifications better |

## Suggested Validation Order

Step 1: build a single-Host, single-device spike prototype first. The Bridge listens to the existing SSE stream, filters `question.asked` only, and successfully delivers one notification carrying a Session deep link to the phone via APNs. This step validates the most critical loop at the lowest cost with zero OpenCode server changes.

Step 2: on top of that, add `permission.asked`, `session.error`, task-completion, and other event notifications, refine REST compensation reconciliation and dedup logic, and gradually support multiple directly connected Host nodes.

Step 3: specifically validate SSH-tunneled or isolated private-network Host topologies. If the central Bridge cannot reach private-network nodes directly, deploy a LAN Watcher proxy and rule out the fragile approach of forcing the iOS client to establish temporary SSH tunnels in the background.

Once the step 1 prototype works, decide based on the use case whether the Bridge runs as a daemon on a user's always-on local Mac or is hosted on centralized cloud infrastructure. This decision only affects deployment topology and credential management and is fully transparent to the communication protocol design between the iOS side and APNs.

## Apple Platform References

- [Setting up a remote notification server](https://developer.apple.com/documentation/usernotifications/setting-up-a-remote-notification-server): the provider stores device tokens and sends requests to APNs.
- [Sending notification requests to APNs](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns): the provider sends payloads to `/3/device/<token>` over HTTP/2/TLS.
- [Choosing Background Strategies for Your App](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app): background tasks are system-scheduled, and the remote notification background execution window is limited and may be rate-limited.
- [Configuring background execution modes](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes): ordinary apps are usually suspended in the background; remote notifications are only one of the limited supported background entry points.
