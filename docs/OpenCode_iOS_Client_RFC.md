# RFC-002: OpenCode iOS Client Technical Design

> Request for Comments · Working Draft · Mar 2026

## Metadata

| Field | Value |
|------|------|
| **RFC number** | RFC-002 |
| **Title** | OpenCode iOS Client Technical Design |
| **Status** | Working Draft |
| **Created** | 2026-03 |
| **PRD reference** | [OpenCode_iOS_Client_PRD.md](OpenCode_iOS_Client_PRD.md) |
| **API reference** | [OpenCode_Web_API.md](OpenCode_Web_API.md) |

---

## Abstract

This RFC proposes the technical implementation for the OpenCode iOS Client, realizing the product goals defined in the PRD. The core of the design is a lightweight, SwiftUI-first native client on iOS 17+ that talks to the OpenCode Server over HTTP REST and SSE, providing remote monitoring, message sending, and document review. The document focuses on technology choices, architecture, and key implementation details, for review and alignment before development starts.

---

## Background

### Problem

Developers using OpenCode often have to wait at the computer while the AI finishes a long task; once they step away, they lose track of progress and cannot correct course quickly. The existing web client depends on a browser and works poorly on mobile, while the TUI is bound to a terminal and cannot run on a phone.

### Goals

Provide a native iOS client so users can do the following from a phone or tablet:
- Monitor AI work progress
- Send messages and switch models
- Review Markdown diffs with the emphasis on documents
- Abort tasks or queue new instructions when needed

### Constraints

- Minimum iOS 17 (Observation framework)
- The client itself adds no local AI inference, file system, or shell execution
- LAN direct connection, Tailscale MagicDNS, and SSH tunnel remote access are supported; public internet environments (non-Tailscale) require HTTPS or SSH forwarding. Tailscale (`*.ts.net`) gets an ATS exception and may use HTTP. In Settings, the Tailscale + HTTP protocol label appears in gray while other WAN + HTTP labels appear in red, with hover text on the info icon provided in both Chinese and English

---

## Design

### 1. Overall Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        iOS Client (SwiftUI)                       │
├─────────────────────────────────────────────────────────────────┤
│  Views                 │  State                   │  Services     │
│  ─────────             │  ─────────               │  ─────────    │
│  ChatTab (Views/Chat/) │  AppState (@Observable)   │  APIClient    │
│  FilesTab              │  SessionStore, etc.      │  SSEClient    │
│  SettingsTab           │  (single AppState)       │               │
│  MessageRow, DiffView  │                          │               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ URLSession (REST + SSE)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     OpenCode Server (Mac/Linux)                   │
│  GET /global/event  │  POST /session/:id/prompt_async  │  ...    │
└─────────────────────────────────────────────────────────────────┘
```

- **Views**: the SwiftUI view layer, organized into Chat / Files / Settings / Split View modules
- **State**: `@Observable`-based management of connection, session, message, and file state
- **Controllers / Services / Stores / Models / Utils**: decoupled layers for event handling, networking, state storage, data models, and utilities

### 2. Technology Choices

| Layer | Choice | Rationale |
|------|------|------|
| UI | SwiftUI | Native declarative framework, the best fit for iOS 17+ |
| State | Observation (@Observable) | Replaces ObservableObject and cuts boilerplate significantly |
| Networking | URLSession | A system-native capability, no Alamofire needed; SSE is built on the `URLSession` `Delegate` or `AsyncSequence` |
| SSH library | Citadel | Wraps Apple SwiftNIO SSH, supports Swift 5.10+, friendlier API design |
| Markdown | MarkdownUI + custom image provider / resolver | Full support for code blocks, links, and lists, plus workspace-relative image resolution |
| Diff | Custom view (iOS native capabilities first) | Unified diff rendering and line-level highlighting based on `before`/`after` |
| Persistence | UserDefaults + Keychain | Connection settings and model presets; sensitive passwords in the Keychain |

#### 2.1 SSH Library Choice: Citadel

Used to implement the SSH tunnel remote access capability.

| Library | Language | Maintenance | Swift version | Rating |
|----|------|----------|------------|--------|
| **Citadel** | Swift (on SwiftNIO SSH) | Active (0.12.0, 2026-01) | 5.10+ | ★★★★★ |
| SwiftNIO SSH | Swift (official Apple) | Active | 6.0+ | ★★★★ |
| NMSSH | Obj-C wrapper of libssh2 | Active | 5.0+ | ★★★ |

**Why Citadel**:

1. **No Swift 6.0 upgrade required**: supports Swift 5.10+, avoiding the breaking changes that come with Swift 6 concurrency checking
2. **Higher-level API**: wraps Apple SwiftNIO SSH, making calls simpler and more intuitive than using SwiftNIO SSH directly
3. **Complete feature set**: full support for Ed25519 key authentication, DirectTCPIP port forwarding, and SFTP
4. **Actively maintained**: 44 releases published, with stable SSH direct-tcpip port forwarding
5. **Good documentation**: clear README examples and [official docs](https://swiftpackageindex.com/orlandos-nl/Citadel/0.12.0/documentation/citadel)

**Usage example**:

```swift
import Citadel

let settings = SSHClientSettings(
    host: "your-vps.com",
    port: 22,
    authenticationMethod: .publicKey(username: "user", privateKey: ed25519Key),
    hostKeyValidator: .acceptAnything()
)
let client = try await SSHClient.connect(to: settings)

// Local port forwarding: iOS:4096 -> SSH gateway assigned port -> OpenCode
let channel = try await client.createDirectTCPIPChannel(
    using: .init(
        targetHost: "127.0.0.1",
        targetPort: 19001,
        originatorAddress: try SocketAddress(ipAddress: "127.0.0.1", port: 4096)
    )
)
```

### 3. Network Layer Design

#### 3.1 REST API

- A unified `APIClient` wrapped around `URLSession`
- Base URL format is `http://<ip>:<port>` or `https://<host>:<port>`, defaulting to `127.0.0.1:4096`, read from Settings
- With Basic Auth configured, every request automatically carries the auth header
- For sending messages, `POST /session/:id/prompt_async` is recommended; the server queues while the session is busy

#### 3.1.1 Message Pagination (Implemented)

- `GET /session/:id/message` paginates through the `limit` parameter, loading the most recent 6 messages by default (3 user/assistant rounds)
- When the user pulls down at the top of Chat to load more history, `limit` increases by 6 each time and the fetch is reissued
- The goal is to cut first-screen wait on weak networks from pulling full history to loading the most recent actionable context
- Note that `limit` counts **messages**; tool calls are not the unit of measure, and one assistant message can contain multiple tool/text/reasoning parts

#### 3.1.2 Edit from here / message revert (MVP Implemented)

The iOS client supports the message revert MVP, shared in behavior with the web client: the user can roll back to a chosen user message, with the original content refilled into the composer for editing and resending.

- Data model: the `Session` model parses the server-returned `revert` field, whose minimal core field set is `messageID`, `partID`, `snapshot`, and `diff`
- API interaction: `APIClient.revertSession(sessionID:messageID:partID:)` calls `POST /session/:id/revert` with a body of `{ messageID, partID? }` and returns the updated `Session` object
- UI entry: an `Edit from here` option in the user message menu of `MessageRowView`; the action is disabled automatically while the session is busy, avoiding conflicts with the server-side `assertNotBusy`
- State orchestration: `AppState.editFromMessage(messageID:)` handles user messages only, concatenates the associated text parts into that session's per-session draft, updates and inserts the returned session instance, and then refreshes messages, diff, and file status
- Message visibility: `AppState.visibleMessages(_:revertMessageID:)` follows the OpenCode Web display semantics, hiding reverted messages where `message.id >= revert.messageID`, while keeping the temporary optimistic message
- Non-goals: the current MVP ships no `unrevert`, restore dock, or part-level revert; these evolve as needed

#### 3.1.3 Image attachments (Phase 1/2 Implemented)

Image support on iOS is structurally identical to OpenCode Web: images are sent as a `file` part of the prompt, with the `url` field carrying `data:<mime>;base64,...` directly, so no separate file upload endpoint is needed.

- Send model: `APIClient.promptAsync` supports mixed text and image parts; plain text produces `type: "text"`, and images produce a structure with `type: "file"`, `mime`, `filename`, and `url`
- Input control (Composer): `ChatTabView` integrates `PhotosPicker` for picking images, up to 4 at a time; selected images are compressed locally into JPEG data URLs (longest edge capped at 2048 pixels, JPEG quality 0.82), with a 5MB cap per compressed image
- Failure recovery: when a send fails, the input text and pending attachments are restored automatically; the optimistic user message includes the matching text part and file part
- Render model: the `Part` model parses the `mime`, `filename`, `url`, and `source` fields; `MessageRowView` renders a thumbnail or a fallback file card for entries with `type == "file"`
- Image preview: tapping an image attachment in a historical message reuses the existing `ImageView` for zoom/pan preview
- Non-goals at this stage: picking files from the Files app, PDF/text attachments, attachment draft persistence across app restarts, and a separate server upload or chunked transfer of large payloads

#### 3.2 SSE Connection

- Connect to the server event stream endpoint `GET /global/event`
- Streamed reading via the `URLSession` `dataTask` or `URLSession.AsyncBytes`
- Parse lines starting with `data:`, splitting events on newlines or the double newline `\n\n`
- Event data format: `{ directory, payload: { type, properties } }`

**Lifecycle management**:
- Foreground: establish or resume the SSE connection
- Background: disconnect proactively to respect iOS background limits
- Recovery: on returning to the foreground, pull all latest data through the REST API first (health, sessions, messages, status), then rebuild the SSE connection

#### 3.3 Errors and Reconnection

- Network errors: show a Toast to the user; crashing the app is never acceptable
- Unexpected SSE disconnect: retry with exponential backoff, capped at a 30s interval
- Server unreachable: Settings shows a Disconnected status, and Chat and Files show placeholder messages

#### 3.4 SSE Robustness

- Parsing: the server API currently emits single-line `data:` output, which the existing parsing handles
- Headers: requests should explicitly set `Accept: text/event-stream` and `Cache-Control: no-cache`
- Reconnection: optional; the current polling and foreground recovery already cover the main cases

### 3.5 Host Profiles and the Transport Abstraction

Multi-host support exists to decouple "which OpenCode environment to connect to" from "which path reaches it". A Host is one concrete OpenCode environment, and a Transport is the underlying network path. The Direct transport covers LAN direct connection, Tailscale / VPN, and public HTTPS services; SSH Tunnel mode reaches an intranet-isolated OpenCode container through an SSH gateway and an assigned remote port.

**Data model (design draft)**:

```swift
struct HostProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var transport: HostTransport
    var serverURL: String
    var basicAuth: BasicAuthConfig?
    var ssh: SSHTunnelConfig?
    var lastUsedAt: Date?
}

enum HostTransport: String, Codable {
    case direct
    case sshTunnel
}

struct BasicAuthConfig: Codable, Equatable {
    var username: String
    var keychainPasswordID: String
}
```

**Persistence boundaries**:

- The `HostProfile` list lives in UserDefaults or a lightweight JSON store; sensitive passwords are stored only as Keychain references and are never written into the JSON data.
- The SSH private key defaults to a device-level key managed by the existing `SSHKeyManager`, with multiple SSH profiles sharing one public key. The private key is a long-lived device identity: it is generated only during first bootstrapping (when the Keychain item is genuinely missing) or on explicit user Rotate. The read path is fail-closed: when the Keychain is temporarily unreadable it errors instead of regenerating, and the public key cache is verified as derived from the private key. If stronger isolation is needed later, per-profile key overrides can be added on top.
- TOFU (Trust On First Use) known-host records stay bound strictly to the SSH gateway's `host:port`, with no binding to profile names. Multiple profiles pointing at the same gateway share the same trusted host fingerprint.

**Switch flow**:

1. Record and save the current profile's `lastUsedAt` and any necessary runtime state.
2. Stop the currently active SSE event stream.
3. If the current profile uses SSH, tear down the existing SSH tunnel.
4. Load and apply the target profile's `serverURL`, Basic Auth credentials, and transport configuration.
5. Clear the current session selection and re-fetch health, projects, and sessions for the new host.
6. If the new profile is SSH Tunnel mode, attempt to establish the tunnel automatically; on failure, enter the `.error` state while keeping Settings interactive and never blocking the user.

**Import Host Config format (no secrets)**:

```json
{
  "version": 1,
  "name": "Yage Private OpenCode",
  "transport": "sshTunnel",
  "serverURL": "127.0.0.1:4096",
  "ssh": {
    "host": "example.com",
    "port": 8006,
    "username": "opencode",
    "remotePort": 19001
  }
}
```

Direct example:

```json
{
  "version": 1,
  "name": "Home Mac via Tailscale",
  "transport": "direct",
  "serverURL": "http://macbook.ts.net:4096"
}
```

The import config contains no private key, provider token, or Basic Auth password. After an SSH config import, the user is still asked to copy this device's public key and hand it to the administrator.

**Host Config export format**:

The Host Config JSON is generated dynamically from the persisted `HostProfile`, and `HostProfile` remains the single persisted source of truth; the client never keeps the originally imported JSON as a second state copy. The exported JSON mainly helps users and administrators verify network parameters, so it must strictly exclude every sensitive key and runtime field: the Basic Auth password, Keychain password ID, SSH private key, and `SSHTunnelConfig.isEnabled` must all stay out of the export.

**Runtime connection diagnostics**:

```swift
struct ConnectionDiagnostic: Codable, Equatable {
    var hostProfileID: UUID?
    var phase: ConnectionPhase
    var message: String
    var recoveryHint: String?
    var timestamp: Date
}

enum ConnectionPhase: String, Codable {
    case idle
    case sshGateway
    case sshAuth
    case localTunnel
    case health
    case bootstrap
    case connected
    case failed
}
```

`ConnectionDiagnostic` is pure app runtime state and needs no local persistence. The state resets automatically on every host switch; the `testConnection()` flow and the overall refresh/bootstrap initialization then update the phase, message, and recovery hint. In the UI, underlying errors must be translated into user-understandable, actionable guidance; raw strings such as `APIError error 0` or `NSURLErrorDomain -1004` must never be shown. Common mappings: Basic Auth 401/403 maps to checking the username and password; connection refused / cannot connect maps to checking the server address, current network, or local tunnel state; an SSH tunnel error maps to checking the gateway status, the device public key configuration, and the assigned remote port.

**Host Detail interaction contract**:

The primary interaction for tapping a Hosts list item is entering the Host Detail page; host switching happens only through the explicit `Use This Host` button inside the detail page. Host Detail shows every key parameter of the current `HostProfile` for Direct or SSH Tunnel and provides `Copy Host Config JSON`; SSH Tunnel profiles additionally get a convenient `Copy This Device Public Key` entry.

### 3.6 SSH Tunnel Architecture

For remote access scenarios: an SSH gateway acts as an intermediate jump host that securely forwards to the user's dedicated OpenCode instance.

**Network topology**:

```
┌─────────────┐      SSH Tunnel       ┌─────────────┐      internal      ┌─────────────┐
│  iOS App    │ ───────────────────▶  │  Gateway    │ ─────────────────▶ │  OpenCode   │
│ 127.0.0.1   │   DirectTCPIP         │ 127.0.0.1   │  (pre-established) │ OpenCode    │
│   :4096     │   :4096 → :19001      │   :19001    │                    │   :4096     │
└─────────────┘                       └─────────────┘                    └─────────────┘
```

**Data model**:

```swift
struct SSHTunnelConfig: Codable {
    var isEnabled: Bool = false
    var host: String = ""           // SSH gateway address
    var port: Int = 8006            // SSH port
    var username: String = "opencode" // SSH username
    var remotePort: Int = 19001     // remote port assigned by the administrator
}

enum SSHConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error(String)
}
```

**Key management**:

```swift
enum SSHKeyManager {
    // Generate an Ed25519 key pair
    static func generateKeyPair() throws -> (privateKey: Data, publicKey: String)
    
    // Private key stored in Keychain (save and load both propagate OSStatus; loadData returns nil only on errSecItemNotFound)
    static func savePrivateKey(_ key: Data) throws
    static func loadPrivateKey() throws -> Data?
    
    // Public key for display/copy (read-only, never generated; consistency is verified first)
    static func getPublicKey() -> String?
    
    // Read-only fetch: verify the cached public key is derived from the private key, repairing the cache from the private key on mismatch
    // Keychain temporarily unreadable throws SSHError.keyUnavailable; a missing private key throws SSHError.keyNotFound
    static func getKeyPair() throws -> String

    // Bootstrap: generate a new key pair only when the private key item is genuinely missing (errSecItemNotFound)
    // Other Keychain errors throw SSHError.keyUnavailable; already-stored keys are left untouched
    static func ensureKeyPair() throws -> String

    // Key rotation (the only generation path triggered explicitly by the user)
    static func rotateKey() throws -> String  // Returns the new public key
}
```

**Security considerations**:

1. **Private key protection**: stored with the `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` policy, readable after first unlock (including while the screen is locked), supporting background connections after reboot, and never migrated to other devices via iCloud Keychain; `KeychainHelper` save/load propagates OSStatus, so write failures are no longer swallowed silently
2. **Public key transfer**: the user copies and pastes manually; the app never uploads the public key over any network interface
3. **TOFU**: the first connection trusts and saves the server fingerprint automatically (bound to host:port); a later mismatch fails immediately and prompts to reset the trusted host
4. **Timeout**: connections time out after 30 seconds, disconnecting automatically with a notice

**Error handling**:

| Error | Cause | User message |
|------|------|----------|
| Key unauthorized | The public key has not been added to the VPS | "Add the public key to the server's authorized_keys first" |
| Connection timeout | Network problem or wrong address | "Connection timed out. Check the network and server address" |
| Authentication failed | Private key mismatch | "Authentication failed. Confirm the public key was added correctly" |
| Key temporarily unavailable | Keychain temporarily unreadable (for example while the device is locked) | "The SSH key is temporarily unavailable. Unlock the device and try again" |

**SSH UX notes**:
- A setup guide inside Settings walks the user through copying the device public key to the administrator and entering the assigned remote port they return
- The public key copy entry point is always present, independent of the tunnel enable state
- An SSH Host Profile's `Test Connection` first establishes the SSH tunnel and waits for the local `127.0.0.1:4096` listener to be ready; `/global/health` is requested only once the tunnel is ready
- When tunnel establishment fails, the SSH error is written into the connection error so the UI shows more than a plain disconnected state

### 3.7 Markdown Image Resolution Contract

Images referenced in Markdown text fall into two groups:

1. **Public URLs**: starting with `https://...`, handed straight to the system's standard network image loading path
2. **Workspace-relative images**: for example `../assets/timeline_40d.png`; the client must resolve and fetch these itself

For the second group, this RFC sets the following constraints:

- Both Files preview and Chat message rendering must support repo-relative images; a split where an image shows in the file preview but not in chat is not allowed
- Resolving a relative image path must combine the current document path `markdownFilePath` with the workspace root `workspaceDirectory`
- After normalization, the final request parameter must be a **workspace-relative path**, passed to the `/file/content` API to fetch the content
- In Chat rendering, converting image content to a `data:` URI before handing it to MarkdownUI is allowed; when using that approach, the rendering side must explicitly attach an image provider that handles `data:` URLs
- If Files preview uses an `imageBaseURL`, the image provider still must normalize to workspace-relative paths so absolute paths never leak into the API layer

The goal of this contract: the same Markdown report must produce the same images whether opened from Files or output directly by the AI in Chat.

### 4. State Management

```swift
@Observable
final class AppState {
    var hostProfiles: [HostProfile]
    var currentHostProfileID: UUID
    var serverURL: String          // runtime URL expanded from the current profile
    var isConnected: Bool
    var sessions: [Session]
    var currentSessionID: String?
    var sessionStatuses: [String: SessionStatus]
    var messages: [MessageWithParts]
    var partsByMessage: [String: [Part]]
    var selectedModelIndex: Int
    
    // Agent selection (added 2026-02)
    var agents: [AgentInfo]           // fetched from GET /agent
    var selectedAgentIndex: Int       // currently selected agent
    
    // SessionStore, MessageStore, FileStore, TodoStore, etc.
}
```

- A single `AppState` holds global state, while per-domain sub-stores take over session/message/file/todo logic
- SSE events dispatch on `type` and update the related state fields in real time
- SwiftUI views access state objects through `@Environment` injection or explicit parameters

#### 4.1 Agent Data Model

```swift
struct AgentInfo: Codable, Identifiable {
    var id: String { name }
    let name: String              // agent name, e.g. "Sisyphus (Ultraworker)"
    let description: String?      // description
    let mode: String?             // "primary" or "subagent"
    let hidden: Bool?             // hidden flag (hidden agents are not shown in the UI)
}
```

#### 4.2 Agent API

| Method | Path | Description | Response |
|------|------|------|------|
| GET | `/agent` | List all agents | `AgentInfo[]` |

- The app calls this API in the background at startup to get the agent list
- Agents with `hidden != true` are filtered out before display
- The first primary agent is selected by default (usually `Sisyphus`)

#### 4.3 Project Selection (Workspace Filtering)

**Background**: the OpenCode Server supports multiple projects, and `GET /session` defaults to the server's current project. The web client can switch projects; the iOS client needs per-project filtering too, or it can only ever see the server's current project.

**API**:

| Method | Path | Description | Response |
|------|------|------|------|
| GET | `/project` | List projects known to the server | `Project[]` |
| GET | `/project/current` | Current project | `Project` |
| GET | `/session?directory=<path>&limit=<n>` | Filter sessions by worktree | `Session[]` |

**Data model**:

```swift
struct Project: Codable, Identifiable {
    let id: String           // usually a git commit hash
    let worktree: String     // absolute path, e.g. /Users/xxx/co/knowledge_working
    let vcs: String?         // "git" and similar
    let time: ProjectTime?
}

// Display name: last segment of the worktree, e.g. knowledge_working
func projectDisplayName(_ worktree: String) -> String {
    (worktree as NSString).lastPathComponent
}
```

**State**:

```swift
var projects: [Project] = []              // fetched from GET /project
var selectedProjectWorktree: String?      // nil = use the server default (no directory passed)
var customProjectPath: String = ""        // path the user types for "Custom path"
```

**Flow**:
1. After a successful connection, call `GET /project` to fill the Picker
2. User selection: picking from the list sets `selectedProjectWorktree = project.worktree`; picking "Custom path" expands a TextField and sets `selectedProjectWorktree = customProjectPath`
3. In `loadSessions()`: with `selectedProjectWorktree != nil`, request `GET /session?directory=xxx&limit=100`; otherwise issue a bare `GET /session`
4. Persistence: `selectedProjectWorktree` and `customProjectPath` are stored in UserDefaults

#### 4.3.1 Session Creation Only Under Server Default

**Background**: `POST /session` accepts no directory, and the server creates the session under its current project (determined by the startup location or the last use in Web/TUI). The iOS Project selector only affects list filtering and never changes the creation target. If creation were allowed while a specific project is selected, the new session would land in the server default, fall outside the filtered results, and appear to vanish.

**Implementation**: creation is allowed only when `effectiveProjectDirectory == nil` (the user chose Server default). With a specific project selected, the new-session button grays out with an info icon beside it; tapping the icon explains that OpenCode must be started from the command line with a different working directory, after which Server default can be selected here to create. `canCreateSession` drives button availability.

#### 4.4 Session Deep Link

**Protocol**: V1 accepts only `opencode://session/<session_id>`. `OpenCodeDeepLinkParser` is a pure function with no side effects. It requires the scheme and host to be `opencode` and `session` respectively, a path with exactly one segment, and a session ID starting with `ses_` followed only by ASCII letters, digits, underscores, or hyphens. The parser rejects userinfo, port, query, fragment, multi-segment paths, control characters, Unicode, double percent-encoding, and overlong IDs. Unknown schemes are not handled by the deep-link router.

**Implementation layering**:

- `Utils/OpenCodeDeepLink.swift` defines the URI contract and the parser.
- `AppState+DeepLinks.swift` holds `pendingDeepLink`, `deepLinkRouteState`, the global error, and the route generation token.
- `ContentView.onOpenURL` handles system cold/warm launch; the `OpenURLAction` in `MessageRowView` recognizes OpenCode links first, then falls back to the existing HTTP/workspace link resolver.
- `Info.plist` registers the `opencode` scheme through `CFBundleURLTypes`; Debug and Release share the same configuration.

**Parsing state machine**:

```text
receive URL
  -> strict parse
  -> store latest pending route
  -> wait while disconnected
  -> GET /session/:id on current Host
  -> apply target directory + upsert session
  -> select session + hydrate Chat + reload Files
```

The client must keep the original `currentSessionID` and messages until `GET /session/:id` succeeds. The target session does not need to be inside the current 100-entry list window; after verification, the client first sets the known project or custom project from `Session.directory`, then upserts and runs the existing session hydration. The session list refresh must retain the current verified session, and Files root/children requests use `effectiveProjectDirectory`.

**Lifecycle and concurrency**: during cold launch or SSH recovery, only the pending route is stored and it is consumed once the connection succeeds. Entering the background or switching Hosts bumps the generation token, invalidating in-flight responses from the old Host while keeping the last pending link for the new connection. A new link replaces the old one with no queue built up; repeated taps on the same session are idempotent. A 404 shows "unavailable on the current Host" and other network errors show a generic open failure; neither switches context.

**Security boundary**: the URL accepts no server, Host Profile, credentials, model, prompt, tool action, or arbitrary command. A deep link runs only when the user taps it or the system invokes it explicitly; it must never execute automatically from Markdown rendering. V1 does not search across Hosts, does not restore an offline archive DB, and does not support `?message=`.

**Verification**: unit tests cover the parser whitelist, 404/disconnection, project switching, list window retention, and route invalidation; fixture XCUITests cover assistant Markdown taps and the cold pending route. Full system acceptance uses the Simulator's `simctl openurl` and a separate temporary server, never touching the live `4096`. Agent search output is verified separately against a synthetic archive for source, frontmatter session ID, candidate dedup, and evidence adjacency; real Agent acceptance stays opt-in and stays out of every unit test run.

### 5. Message and Document UI

#### 5.1 Message Stream

- **Layout**: OpenCode style with no left/right bubbles; human messages on a gray background, AI messages white/transparent
- **Unit semantics**: one message can contain multiple parts (tool/reasoning/text and so on). A tool call counts as a part and is not counted as its own message
- **Part rendering**: text (Markdown), reasoning (collapsed), tool (card), patch (jump to Files). When a tool/patch contains a file path, tapping offers "Open in File Tree" preview; the `todowrite` tool renders as a Task List (todo) view and responds to the SSE `todo.updated` event. The todo shows only inside the tool card, with no persistent block at the top of Chat (option B)
- **Image tool output**: when a tool result references an image file, render an inline thumbnail in place of the raw base64; tapping opens a zoomable full-screen preview
- **iPad large-screen density**: with `horizontalSizeClass == .regular`, tool/patch/permission cards can fill the width in a three-column grid; the text part still spans the full row (keeping reading unbroken)
- **Streaming (Think Streaming)**: `message.part.updated` with a `delta` appends to the matching Part for a typewriter effect; without a delta the Part reloads fully. Tool cards: expanded while running, collapsed by default once completed
- **Auto-scroll**: follow new streaming text and card updates only while the user is near the bottom; stop following when the user scrolls up, so their reading position is never stolen
- **Activity Row convergence**: status display follows "runtime evidence first". While a running/pending tool or streaming delta is detected, the row stays running even if `session.status=idle` arrives momentarily, avoiding a premature completed
- **Theme**: follows `@Environment(\.colorScheme)`, Light/Dark

#### 5.1.1 Chat Text Selection (textSelection): Design

**Principle**: text selection is enabled for only two kinds of content and disabled everywhere else, avoiding gesture conflicts and keeping the selectable range small.

| Region | Selectable | Notes |
|------|----------|------|
| User message body | ✅ | The user's own message, copyable |
| AI final reply (text part) | ✅ | The AI's response text, copyable |
| Reasoning | ❌ | Including think content while streaming |
| Tool calls (tool cards) | ❌ | Reason, Command/Input, Output, Path, todo, and more |
| Patch cards | ❌ | Mostly buttons, no selection needed |

**Implementation**: `MessageRowView`'s `markdownText` applies `.textSelection(.enabled)` to user messages and AI text parts; the `ScrollView` sets no global textSelection; `ToolPartView`, `StreamingReasoningView`, and `TodoListInlineView` do not enable textSelection.

#### 5.1.2 Think Streaming Implementation

- **Delta handling**: when `handleSSEEvent` receives `message.part.updated` and `properties.delta` exists, it locates the Part by `messageID`/`partID` and appends the delta to the text; otherwise it runs a full `loadMessages()` refresh
- **Tool collapsing**: `ToolPartView` follows `part.state.status`: `running` sets `isExpanded = true`, `completed` sets `isExpanded = false` (the default); the user can toggle manually
- **Limitation**: real-time line-by-line streaming of tool output (terminal style) is not supported by the current API, per the PRD research

#### 5.2 Document Review

- **Markdown display**: Preview first, switchable to Markdown source
- **Diff highlighting**: highlight changes in Preview first; if that proves too hard, highlight within the Markdown source
- **Entry point**: Files Tab → pick a file → preview
- **Image preview**: file previews and tool output share the same image branch; starting at fit-to-screen, with pinch, drag, double-tap zoom, and the system share sheet

### 6. Permissions and Input

- **Session list**: lists every existing session in the workspace, serving as the verification channel for connectivity and parsing
- **Session list styling**: avoid the system default link blue; text in neutral colors and the current session highlighted with a background
- **Permissions**: on `permission.asked`, show a card for the user to approve or reject manually, calling `POST /session/:id/permissions/:permissionID`
- **Question**: on `question.asked`, show a question card; pending questions are re-fetched via `GET /question` at startup; answering and rejecting call `/question/{id}/reply` and `/question/{id}/reject` respectively
- **Composer**: the `voice rail + text review field` two-row structure. The voice rail on top carries the voice transport, waveform/status, transcription-wait recovery, and preserved-audio retry; the text review field below carries the transcript, manual corrections, fallback typing, and the fixed send button. When a voice transcription or preserved-audio retry streams a partial transcript, the text review field scrolls to the end so the newest text stays visible; ordinary manual input and draft restoration never force a scroll. While busy, send still calls `prompt_async` and the server queues the message
- **Drafts**: unsent input is persisted per sessionID, restored when switching back, and cleared after a successful send
- **Model selection**: remembered per sessionID and restored automatically when switching sessions (avoiding a global model overriding per-session choice)
- **Agent selection**: remembered per sessionID (same as model); the message body carries the `agent: string` field when sending
- **Voice input**: starting a recording creates a VoiceFlowKit realtime session, with `AVAudioEngine` producing PCM16 mono 24kHz chunks; the Kit writes each chunk into a temporary `.pcm` cache and sends it over the current WebSocket. While recording, the voice rail waveform consumes the real 0..1 smoothed mic level from `VoiceFlowMicrophone.audioLevel`. A heartbeat or send failure triggers Kit recovery: cancel the broken session, create a new one, replay the cache file sequentially from offset 0 to the current end, then resume live sending. Stopping the recording waits for recovery to finish, sends `commit` / `stop`, and appends the transcript to the text review field. While transcription waits, a processing waveform and `Stop transcription wait` are shown; tapping calls `abortPreservingAudio()`, releasing the UI immediately while keeping the cache. In the preserved-audio state, the transport on the left shows a `Retry this segment` icon button that re-recognizes the same PCM via `transcribe(preservedAudio:)`, and the action on the right shows `Discard audio` to drop the cache and exit the recovery state. After a failed retry the cache is kept, and the user can retry again or discard. The Base URL and token are configured under Settings → Speech Recognition and stored in the Keychain
- **Agent abort**: `Interrupt agent` is an item in the composer status line's `⋯` menu and calls `POST /session/:id/abort`. It is a low-frequency escape hatch and shares no transport slot or stop glyph with voice transcription recovery
- **History loading interaction**: the top of Chat shows a "pull to load more history" hint; while loading it shows "loading more history...", with Chinese and English localization. Loading more widens the `GET /session/:id/message?limit=` window, and the client records the requested limit, the returned message count, and the number of items dropped by the fallback decoder, making it easier to debug pagination stalls caused by old history message shapes. The `files` field of a message part accepts both string arrays and objects missing diff counts, so legacy patch/tool records cannot block display of earlier history.
- **Session Archive**: the Session List shows Active / Archived sections. Archiving reuses `PATCH /session/:id`: Archive writes a positive archived timestamp, and Restore writes `-1` as the legacy restore sentinel; the client treats `time.archived > 0` as archived. The client does not treat archive as a variant of delete. After Archive / Restore succeed, the returned `Session` updates the local list and the Active / Archived sections are recomputed. Archive applies recursively across the session subtree, children first and parent last, so active children are not briefly promoted to root after the parent hides; Restore runs parent first and children after, so children do not float free while the parent is still archived. The iPhone sheet and iPad sidebar share one set of rules: leading swipe for Archive/Restore, trailing swipe for Delete; every swipe action disables full swipe, and Delete shows no confirmation dialog. Session list pagination uses an explicit "Load more sessions" row instead of automatic `onAppear` loading at the bottom, avoiding large pulls of invisible historical sessions while the archived section sits collapsed by default. This round ships no session search, so a local title filter cannot be mistaken for a full history search.

#### 6.1 Fork Session

The "..." menu next to the model label at the bottom of a user message offers "Fork from here". It calls `POST /session/{id}/fork` (body: `{ "messageID": "..." }`); the server copies all history before the given message into a new session and returns it. On receiving the new `Session`, the client inserts it at the top of the list and switches to it.

**Implementation notes**:
- SwiftUI `Menu` (tap-triggered, rather than the long press of `.contextMenu`) keeps the button discoverable
- `MessageRowView` gains an `onForkFromMessage: ((String) -> Void)?` callback that passes `message.info.id` to `AppState.forkSession(messageID:)`
- `AppState.forkSession()` follows the `createSession()` pattern: guard `isConnected` + `currentSessionID`, call the API, insert the session, switch, load messages
- The forked session title is generated by the server: "{original title} (fork #N)"

### 7. Files and Diff

- **File tree**: `GET /file?path=` renders recursively; `GET /file/status` supplies git status for color marks
- **Content**: `GET /file/content?path=`; text files get a monospaced code view with line numbers; Markdown switches between Preview / source; images get interactive preview and system sharing
- **Session Diff**: not shown in the iOS client for now (the server diff API returns an empty array in some cases)

### 7.5 Markdown Web Preview Architecture Decisions

Opening an `.md` file shows cards, SVG, and dark mode support, going beyond plain text. All rendering happens locally on iOS: no network access and no execution of author code.

<style>
.rfcw-stat{display:inline-block;border-radius:999px;padding:1px 8px;font-size:.78rem;font-weight:650}
.rfcw-stat.ok{background:var(--ok-bg,#d1fae5);color:var(--ok-fg,#065f46)}
.rfcw-stat.block{background:var(--block-bg,#e5e7eb);color:var(--block-fg,#374151)}
</style>

| What the user experiences | Status |
|---|---|
| Opening a markdown file shows the Web Preview by default, with toolbar switching back to Native / source | <span class="rfcw-stat ok">Shipped</span> |
| `<style>` / `<div class="card">` / inline SVG render properly | <span class="rfcw-stat ok">Shipped</span> |
| Relative-path images load | <span class="rfcw-stat ok">Shipped</span> |
| The same file reads well in light / dark mode, with no washed-out cards | <span class="rfcw-stat ok">Shipped</span> |
| Dangerous HTML (scripts, forms, third-party iframes) is stripped and never executes | <span class="rfcw-stat ok">Shipped</span> |
| Switching files refreshes content immediately, with no manual pull needed | <span class="rfcw-stat ok">Shipped</span> |
| Very large files ask for confirmation first, avoiding hangs | <span class="rfcw-stat ok">Shipped</span> |
| Standalone `.html` artifacts, Mermaid, code highlighting, tap to zoom images | <span class="rfcw-stat block">Next round</span> |

<details>
<summary>Implementation notes (expand for engineering readers)</summary>

- **Render path**: `MarkdownWebPreviewView` (a `UIViewRepresentable` wrapping `WKWebView`) loads `preview.html` from the app bundle; Swift calls `window.renderMarkdown({markdown, theme})` through `evaluateJavaScript`, with the payload passed through `JSONSerialization` and no string-concatenated markdown.
- **JS dependencies**: `markdown-it@14.2.0` + `DOMPurify@3.4.10` + `Temml@0.13.4` are pinned into the bundle with zero CDN calls. Temml converts `$...$` / `$$...$$` to MathML at the markdown-it token stage, and the MathML then goes through the sanitizer along with the rest of the HTML. Xcode synced folders flatten subdirectories, so the vendor files sit next to `preview.html` and the src carries no `vendor/` prefix.
- **Image resolution**: `MarkdownImageResolver.resolveImages` converts relative images to `data:` URIs before handing them to the WebView, matching the semantics of the §3.7 Markdown image resolution contract.
- **Security model**: Temml runs with `trust: false` and bounded macro/size configuration; the MathML it generates does not bypass the sanitizer. DOMPurify uses an explicit HTML/SVG/MathML allowlist that bans `script` / `iframe` / `form` / `object` / `embed` / `on*` event attributes / `javascript:` URLs; the `WKNavigationDelegate` intercepts every navigation except file / fragment; external links go to system Safari while workspace-relative links route through `state.fileToOpenInFilesTab`; `WKWebsiteDataStore` is non-persistent with no persistent cookies / localStorage.
- **Theme adaptation**: the shell exposes CSS variables such as `--fg` / `--bg` / `--card-bg` / `--border` / `--link` / `--ok-*` / `--bad-*` / `--warn-*` / `--block-*`, defined for both light / dark. Author styles must use the `var(--x, fallback)` form so renderers without theme variable support (Cursor, GitHub) fall back cleanly. Dark mode chips use saturated primary colors (`--ok-bg=#10b981` and similar) so they do not sink into the card on a dark background. Chips must use the compound selector `.vx-chip.ok`; a bare `.ok` gets overridden by the card's `color:var(--fg)`.
- **Switch refresh**: `FileContentView` resets content and reloads in `.onChange(of: filePath)`, preventing stale file content when SwiftUI reuses the view instance.

</details>

The full sub-project PRD / RFC remain on disk at `docs/archive/2026-06_markdown_web_preview_prd.md` / `2026-06_markdown_web_preview_rfc.md`, removed from git tracking; the decision process is in [`WORKING.md`](WORKING.md).

### 8. iPad / Vision Pro Layout (Phase 3)

- **Condition**: enabled when `horizontalSizeClass == .regular` or `userInterfaceIdiom == .pad`
- **Layout**: no tab bar; three columns (NavigationSplitView): left Workspace (Files + Sessions), middle Preview (file preview), right Chat (message stream + input)
- **Column widths**: Workspace roughly 1/6; Preview and Chat split the remaining 5/6 (5/12 each)
- **Adjustable**: column widths can be dragged; the values above are the default ideal widths
- **File preview**: no sheets on iPad. Selecting a file in the left column, or tapping a file path in a tool/patch card in Chat, updates the middle Preview column to that file
- **Refresh**: a refresh button at the top right of the middle Preview column (reloads the file content) for manual refresh after external changes
- **Toolbar**: the first row unifies left (session list, rename, Compact, new session) and right (model dropdown, agent dropdown, Context Usage ring, **Settings button**); Settings opens as a sheet
- **Model and agent selectors**: the old horizontally scrolling chips became dropdown lists (Menu + Picker). The model list is fixed (GLM-5.1 / GPT-5.4 / GPT-5.3 Codex / DeepSeek); the agent list comes from `GET /agent` dynamically (hidden filtered out)
- **Model labels**: iPhones use short names (`GLM` / `Opus` / `GPT` / `Gemini`) to fit the narrow width; the iPad shows full names
- **Implementation**: branching on `@Environment(\.horizontalSizeClass)`: regular renders the three-column split while compact renders a `TabView`; iPad drives the middle preview with `previewFilePath`, and iPhone keeps `fileToOpenInFilesTab` for sheet / tab navigation

### 9. Context Usage

- **Display**: a ring progress at the top right of Chat (between the model switcher and the gear); a gray empty ring means no data.
- **Data**: token/cost read from the latest assistant message's `info.tokens`/`info.cost`; the context limit comes from `limit.context` in `GET /config/providers`.
- **Interaction**: tapping the ring opens a sheet with provider/model, context limit, total tokens, the token breakdown (input/output/reasoning/cache read/cache write), and total cost.
- **Always visible**: the ring stays visible in every state, including idle, busy, and streaming. `ChatTabView` injects no `ProgressView` into `.navigationBarTrailing`; the busy state is conveyed by the red stop button in the input bar, and the toolbar spinner is gone.

### 10. Car Mode Technical Design (Foreground Phase Implemented)

#### 10.1 Components and Platform Gating

Car Mode appears only on the iPhone compile path and runtime idiom. `isCarModeEnabled` is persisted in UserDefaults, defaulting to `false`; the Settings toggle and the Car Tab share the same condition. iPad, iPad compact windows, and visionOS expose no entry point.

Main components:

- `AppState+CarMode.swift`: session lifecycle, turn state, structured response, and exactly-once state.
- `Models/CarMode.swift`: the versioned response envelope and JSON Schema.
- `Views/Car/CarModeView.swift`: recording, waiting, speaking, confirmation, and failure UI.
- `CarSpeechOutputService.swift`: Apple TTS and AudioSession switching.
- `CarClientActionDispatcher.swift`: the typed Maps action allowlist; the Health action goes to a separate capability dispatcher.
- `APIClient.promptStructured(...)`: a synchronous `POST /session/:id/message` wrapper.

#### 10.2 Structured Prompt Contract

Every turn's request explicitly carries `system` and `format: json_schema`, always using the `build` agent and `openai/gpt-5.6-sol-fast`. The server validates through the StructuredOutput tool and writes the result into `assistant.structured`. The client never infers actions from natural-language text parts and never treats the structured assistant's `finish == tool-calls` as a failure.

Minimal envelope:

```json
{
  "version": 1,
  "status": "completed",
  "speech": "The garage door is closed. Status just refreshed.",
  "confirmation": null,
  "clientActions": []
}
```

When confirmation is needed, `status` is `needs_confirmation` and carries a stable confirmation ID; at navigation completion at most one typed action is returned:

```json
{
  "version": 1,
  "status": "completed",
  "speech": "Starting navigation to Bright Horizons.",
  "confirmation": null,
  "clientActions": [
    {
      "id": "route-1",
      "type": "open_navigation",
      "destination": "Bright Horizons, Bellevue",
      "waypoints": []
    }
  ]
}
```

The Schema constrains version, status, speech length, action count, and action type. The system prompt requires the speech to state the conclusion first, contain no Markdown/URLs/code, run 8-12 seconds by default with a 15-second maximum, and declares that only user messages can authorize real-world side effects.

#### 10.3 Session Lifecycle and Archive Recovery

The Car session key is `hostProfileID + effectiveProjectDirectory`, kept separate from normal Chat's `currentSessionID`. Local record:

```text
sessionID
lastHandledAssistantMessageID
pendingConfirmationID
lastUsedAt
```

Every turn calls `ensureCarSession()`:

1. With no record, create the `Car Mode` session and save it.
2. With a record, call `GET /session/:id`; a 404 clears the record and creates a new session once.
3. When the session has `time.archived > 0`, call `PATCH /session/:id` to write `{ "time": { "archived": -1 } }`, restoring the iOS Active state with the legacy restore sentinel the server already accepts, then keep using the original session.
4. No forking, no history copying, and no server changes for the Web global list. OpenCode Web may require `archived === undefined`, so cross-client visibility of `-1` is not something Car Mode guarantees.

Backgrounding, switching tabs, or opening Maps stops recording, TTS, and the current foreground request without clearing the session ID. Only an explicit New Car Session choice removes the current context mapping.

#### 10.4 Turn State and Exactly-Once

```text
idle
→ recording
→ finalizing
→ waitingReply
→ speaking / awaitingConfirmation / failed
→ idle
```

Only the VoiceFlow final transcript auto-submits. A response must simultaneously match the target session, the assistant role, `time.completed != nil`, a decodable version 1 structured envelope, and non-empty speech. The client deduplicates TTS/actions by assistant message ID and links the next turn by confirmation ID. Cancelling an active turn stops TTS and best-effort calls `POST /session/:id/abort`.

The current Foreground Phase uses a synchronous endpoint and gets the final assistant directly; normal Chat's asynchronous `prompt_async → SSE → reload` does not reuse this state machine. Any later move to async must keep the completion predicate and exactly-once IDs above, and must never trigger speech or actions on `session.status == idle` alone.

#### 10.5 Audio and Client Actions

After VoiceFlow finalization completes, the recording AudioSession is released first, and the TTS service then switches to `.playback` + `.spokenAudio`. This keeps audio from lingering on the receiver or a Bluetooth HFP route. Current playback stops when a recording starts or is cancelled.

The Maps dispatcher validates the destination/waypoints for `open_navigation` and builds the Apple Maps URL. `health_quantification.export_all` uses separate local authorization, a Pending/Outbox, and callback continuation; the formal technical contracts are in [`features/client_capabilities/rfc.md`](features/client_capabilities/rfc.md) and [`features/client_capabilities/protocol.md`](features/client_capabilities/protocol.md). Neither action accepts an arbitrary model-provided URL.

#### 10.6 Server Contract and Verification Evidence

Car Mode maintains no archive-list server patch. The only standalone server compatibility fix is the wire schema for the structured user message `info.format`, which lets `GET /session/:id/message` read persisted structured turns; that fix lives in nested checkout commit `43a4a0e53` and is unrelated to Car session active-list behavior.

The 2026-07-13 live spike verified: synchronous structured speech returns a valid object; a second turn in the same session retains the previous destination; and after tool execution the run can still finish with a structured final. It proves only the generic tool → structured path, and does not prove that Smart Home, email, iMessage, or route-duration are registered, authorized, or real-E2E complete.

Client verification covers the unit state flow, structured history fallback, the iPhone experimental toggle and Car UI, the hidden iPad entry point, and the visionOS build. Testing always uses serial `xcodebuild` with `-parallel-testing-enabled NO`.

---

## Implementation Plan

| Phase | Scope | Estimated duration |
|-------|------|----------|
| 1 | Server connection, SSE, sessions, message sending, streaming render | 2–3 weeks |
| 2 | Part rendering, manual permission approval, theming, `prompt_async` | 2 weeks |
| 3 | File tree, Markdown preview, document diff, Think Streaming delta, **iPad/Vision Pro split layout** | 2–3 weeks |
| 4 | mDNS, Widget, and more | Not implemented yet |

### Code Review Follow-ups (2026-02)

| Item | Status | Description |
|------|------|------|
| 2.1 | ✅ | Credentials persisted with UserDefaults + Keychain |
| 2.2 | ✅ | Chat text selection: only user messages and AI text parts are selectable, see RFC §5.1.1 |
| 2.3 | ✅ | ChatTabView split into Views/Chat/*.swift |
| 2.4 | ✅ | Todo option B: displayed only inside the tool card |
| 2.5 | ✅ | Debug prints removed |

---

## Rejected Alternatives

The following approaches were dropped during discussion:

1. **Using Alamofire**: `URLSession` is enough, and a new dependency is unnecessary
2. **Background-persistent SSE**: iOS disconnects it anyway and it drains the battery; the design connects in the foreground and disconnects in the background
3. **Local message queue**: the server's `prompt_async` already queues while busy, so the client needs none
4. **Auto-approving permissions**: OpenCode rarely requests permission, and a request signals something unusual; approval is manual instead

---

## Decided Items

1. **Markdown library**: MarkdownUI, with iOS native capabilities preferred
2. **Large sessions**: not a concern for now; sessions are not expected to exceed about a hundred messages
3. **Diff highlighting**: implemented with iOS native capabilities first

---

## Appendix: Mapping to the PRD

| PRD section | Corresponding RFC section |
|----------|-------------|
| 3. Technical Architecture | §1 Overall Architecture, §2 Technology Choices |
| 4.2 Chat Tab | §5 Message and Document UI, §6 Permissions and Input |
| 4.3 Files Tab | §7 Files and Diff |
| 5. Data Flow and State Management | §4 State Management, §3 Network Layer |
| 11. Getting Started Guide | §Implementation Plan |
