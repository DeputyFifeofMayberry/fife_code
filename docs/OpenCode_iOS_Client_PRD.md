# OpenCode iOS Client — Product Requirements Document

> Version 0.4 · Working Draft · Jul 2026

## 1. Product Positioning

The OpenCode iOS Client is a native iOS remote-control app for the OpenCode server. It is the **mobile extension** of an OpenCode instance running on a Mac or server, letting users send instructions, monitor AI progress, review code changes, and switch models while away from the computer, such as on the couch or during a commute.

The core design principles are **lightweight, fast, and centered on reading and interaction**. All heavy configuration (provider keys, MCP services, workspace settings) happens on the computer. The iOS side only handles the necessary interactions and content consumption.

Beyond technical architecture, the app's more central goal is to close the human-AI interaction loop: **presenting the AI's key decisions fully for human review, and supporting fast voice intervention to correct course when needed**. We define this mode as **Steer**. In this mode the AI handles execution and exploration while the human handles judgment and direction. The app's value goes beyond at-a-glance status monitoring of what the AI is doing; it acts as a lightweight **terminal for reviewing decisions and controlling direction**. Each time the user opens the app, the main activity is reading Markdown reports, viewing embedded screenshots and artifacts, and issuing new directional instructions by voice. At its core it is a steering tool, with content browsing as a secondary concern.

Around the Steer paradigm, the app concentrates on three interaction surfaces: the **Markdown conversation window** (the main channel for the AI to report progress and present artifacts), **file card previews** (for quickly checking what the AI changed, mostly documents with code second), and **voice input** (so users can issue directional instructions efficiently away from a keyboard). Code syntax highlighting is not a core priority: what users review is the basis and outcomes of the AI's decisions, and the visual styling of code matters far less.

### 1.1 What This App Does Not Do

The app explicitly does not edit code on the phone, run an OpenCode server on the phone, or replace the full Web UI. Its core scenario: at any moment while the AI works, the user can pick up the phone and read a freshly generated Markdown analysis report or code change. When the direction looks wrong, the user can immediately adjust course with a voice instruction.

### 1.2 Core Interaction Paradigm

#### The Steer Paradigm

The app designs its interaction flow around the Steer cognitive loop:

1. **Surface**. The AI presents its decision process, referenced code, executed commands, analysis, and final conclusions to the human through the Markdown window. Content is expressed in natural-language Markdown, with support for embedding visual artifacts such as deployment screenshots, charts, and UI diffs alongside code. This is the primary information channel between the AI and the human.
2. **Review**. The human reads the Markdown to judge whether the conclusions are sound and the overall direction is right. Most output consists of documents, analysis, or research content that Markdown presents naturally; code diffs are available when details need checking. The human's core responsibility in this step is decision making, and writing code stays with the AI.
3. **Steer**. If execution drifts from the expected direction, the user can quickly issue a correction by voice (for example, "Stop, don't use inheritance, switch to composition") or switch the model or agent and restart. Instructions are entered in natural language, with no tedious typing.

The whole loop runs asynchronously on both ends: the AI executes on the computer and the human reviews on the phone, with no need for real-time sync between the two, which is a unique advantage of mobile over desktop. This also creates a practical pain point: when the AI pauses to wait for a human decision (for example, when the `question` tool fires), the user gets no notification after leaving the app, and both sides can end up waiting. The fundamental fix belongs to iOS systems engineering, ahead of the UX interaction layer: push notifications or Live Activities are needed for proactive alerts.

#### Markdown as the Interaction Window

Markdown is the **core information medium** for AI-human interaction in this app. The app is a steering terminal built to deliver the best possible Markdown reading and review experience, well beyond incidental Markdown support. Concretely, the design reflects this in:

- **Code syntax highlighting is de-emphasized**, and Markdown rendering quality comes first (clear heading hierarchy, lists, links, code blocks, and embedded images). The user's primary need is to review the AI's reasoning and deliverables, and code styling ranks below that.
- **Complete image embedding support**: the AI can embed deployment screenshots, generated charts, and UI comparisons directly in Markdown reports. A dedicated Skill system guides the AI in using these capabilities, and relative-path images render consistently in both Files preview and Chat.
- **Content is not limited to programming**: AI output includes code diffs as well as research articles, analysis reports, and system design documents. Markdown carries all of these content forms well.

#### File Card Preview (Not a Code Editor)

File browsing exists to **confirm the AI's changes quickly**, and writing code on the phone is out of scope. In the vast majority of cases the user jumps straight from tool/patch cards in the Chat window to the file preview. The Files Tab is a fallback entry point and never the main workflow. For example, when an `edit_file` card appears in Chat, tapping the file path on the card opens the preview directly, with no need to switch to the Files Tab and walk down the directory tree.

Document diffs carry far more review weight than code diffs: the AI already codes reasonably well, so human review focuses mostly on document-level logic and architecture decisions.

The app explicitly does not edit code on the phone, run an OpenCode server on the phone, or replace the full Web UI. Its value lies in the core scenario of checking the AI's current progress on the phone at any time and stepping in quickly to adjust direction when necessary.

## 2. Target Users and Usage Scenarios

The target users are developers who use OpenCode daily (initially the author himself). A key point to keep in mind: heavy users do not open the app for a quick status glance. Every session is a deep interaction: reading Markdown reports, talking to the AI by voice, and switching between sessions to track different tasks. The app's core value is keeping the user's judgment and control over the full AI workflow intact while away from the computer, going beyond the role of a status checker.

**Scenario A: Remote Monitoring and Review**: the user starts a long-running refactoring task on the computer and leaves the desk. On the phone, the user checks how many files the AI has processed and reads the latest Markdown analysis report, which explains the reason for each change and includes architecture diagram screenshots. The core actions are reading the report in depth, opening file cards to verify specific changes, and confirming the overall direction is correct.

**Scenario B: Quick Course Correction (Voice-Driven)**: the user notices on the phone that the AI's implementation approach has drifted and it is building the feature the wrong way. The user issues a voice instruction on the spot ("Stop, don't use inheritance, use composition instead") and puts the phone away. The key value of voice input in this scenario is avoiding the inconvenience of typing on a phone and keeping the friction of steering as low as possible.

**Scenario C: Model A/B Testing**: comparing how different models (GPT-5.3 Codex / DeepSeek / Opus / GLM and similar) perform on the same task. The user switches to another model with one tap on the phone and sends the same instruction to observe the differences. This scenario usually pairs with Fork Session, which branches trial runs with different models from the same conversation node.

**Scenario D: Document Review**: after the AI completes a round of changes, the user reviews the Markdown document diff on the phone, mainly in Preview mode, and only lets the AI proceed once the document changes look right. Code review is a secondary activity, since the AI already writes high-quality code and human review centers on document-level logic and architecture decisions. Output is not limited to programming either: it may include research reports, system design documents, and deployment result presentations, all of which Markdown presents naturally.

### 2.0 How Heavy Users Spend Their Time

Understanding how heavy users spend their time is essential for steering the product's evolution:

- **About 60% of the time goes to reading Markdown**, including AI analysis reports, research articles, design documents, and deployment results with embedded screenshots. This is the review part of the loop.
- **About 25% of the time goes to talking with the AI**: issuing new instructions by voice, correcting execution direction, or asking follow-up questions. This is the steering part of the loop.
- **About 10% of the time goes to switching between sessions**: tracking progress across projects and directions and deciding which tasks need intervention. This is the multi-thread steering part.
- **About 5% of the time goes to the Files Tab**. This entry point is fundamentally a fallback channel, since most file access happens through direct jumps from tool/patch cards in the Chat window.

Based on this time distribution, the product experience priorities are: Markdown rendering quality > voice input fluency > session recognizability > file tree features.

### 2.1 Distribution

To lower the barrier to trying the product, two distribution channels are available:

- **TestFlight**: for the vast majority of users; install and use, no Apple Developer account required
- **Source build**: for developers who need to modify code locally, debug, or sign with custom settings

The README carries the latest installation entry points. This PRD keeps only the product-level distribution policy.

## 3. Technical Architecture

### 3.1 Overall Architecture

```
┌──────────────┐         HTTP REST + SSE          ┌──────────────────┐
│              │ ◄──────────────────────────────► │                  │
│  iOS Client  │    LAN / Tailscale / etc.        │  OpenCode Server │
│  (SwiftUI)   │                                  │  (Mac/Linux)     │
│              │                                  │                  │
└──────────────┘                                  └──────────────────┘
     pure display + command sending          file system + AI compute
```

The iOS side is designed as a pure API consumer, with no local AI inference, file system access, or shell execution. All data comes from the OpenCode HTTP API, and real-time state arrives through SSE (Server-Sent Events).

### 3.2 Technology Choices

| Layer | Choice | Rationale |
|------|------|------|
| UI framework | SwiftUI | Native feel, smooth animations, full use of iOS system capabilities |
| Networking | URLSession + native SSE | No third-party HTTP library needed; the SSE protocol implementation stays lightweight and direct |
| State management | Swift Observation (@Observable) | Native on iOS 17+ and the simplest fit with SwiftUI |
| Code highlighting | Not implemented for now | Monospace font and line numbers only at this stage |
| Markdown rendering | MarkdownUI + custom image resolution | Covers document preview and code blocks, and resolves repo-relative image paths |
| Diff rendering | Custom component (based on server-provided before/after) | The server already computes diffs, so the client only renders them; document diffs need change highlighting |
| Minimum version | iOS 17.0 | Full adoption of the Observation framework, with no iOS 16 compatibility |
| Persistence | UserDefaults + Keychain | Only connection settings and model presets need storage, so no local database |

### 3.3 Communication with the OpenCode Server

Client-server communication uses two channels:

**REST API**: carries all active operations (sending messages, fetching file lists, changing configuration, and so on). The request base path comes from the `http://<ip>:<port>` the user configures in Settings.

**SSE (Server-Sent Events)**: carries real-time event pushes. The client connects to the `GET /global/event` endpoint to receive all events, with data in the `{ directory, payload: { type, properties } }` format.

SSE connection lifecycle management is one of the client's core technical concerns:
- The app establishes or resumes the SSE connection when it enters the foreground
- The app closes the SSE connection when it enters the background (avoiding long-lived connections in the iOS background)
- When returning to the foreground from the background, the client first pulls the latest state through the REST API for a full sync, then re-establishes the SSE connection

### 3.4 Authentication

The OpenCode Server supports optional Basic Auth, controlled by the server-side environment variable `OPENCODE_SERVER_PASSWORD`. The iOS side provides username and password fields in Settings and stores them securely in the Keychain. The client attaches the Basic Auth header to every REST request and SSE connection.

## 4. Feature Specification

### 4.1 Layout Structure

#### 4.1.1 iPhone: Tab Bar

The iPhone uses a bottom tab bar with three tabs:

```
┌─────────────────────────────────────┐
│                                     │
│          (Tab Content Area)         │
│                                     │
├───────────┬───────────┬─────────────┤
│   💬 Chat  │  📁 Files  │  ⚙ Settings │
└───────────┴───────────┴─────────────┘
```

#### 4.1.2 iPad / Vision Pro: Split View (No Tabs)

On iPad and Apple Vision Pro, **no tab bar is shown**; the app uses a three-column layout (Workspace / Preview / Chat):

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ [New] [Rename] [Session list]         [GPT] [Spark] [Opus] [GLM] [◔] [⚙]                     │  ← Row 1: Session actions + model + Context usage + Settings
├──────────────────────────────┬───────────────────────────────┬───────────────────────────────┤
│                              │                               │                               │
│     🧭 Workspace             │         📄 Preview             │           💬 Chat              │
│     (Files + Sessions)       │         (File preview)        │           (messages + input)  │
│                              │                               │                               │
│  File tree (top)             │File content / Markdown preview│  Message stream + input field │
│  Sessions (bottom)           │  Refresh button, top right    │                               │
│                              │                               │                               │
└──────────────────────────────┴───────────────────────────────┴───────────────────────────────┘
```

**Design notes**:
- **Left column**: Workspace (file tree and Sessions list)
- **Middle column**: Preview (file content and Markdown preview, with manual refresh)
- **Right column**: Chat (message stream and input, with the same interaction logic as iPhone)
- **Width ratio**: Workspace ≈ 1/6; Preview ≈ 5/12; Chat ≈ 5/12 (Preview and Chat stay equal width)
- **Adjustable**: the user can drag dividers to change column widths; the defaults are the ratios above
- **Settings**: a separate button in the first-row toolbar (alongside Session actions and model switching); tapping opens it as a sheet or navigation push
- **Benefit**: on large screens Chat and Preview sit side by side, so viewing a file preview needs no floating overlay; Workspace and Sessions stay pinned on the left without disturbing the main reading flow

### 4.2 Chat Tab (Primary Interface)

As the app's primary interface, the Chat Tab has model and agent selectors at the top, the message stream in the middle, and the input area (Composer) at the bottom.

#### 4.2.1 Model and Agent Selectors

These sit in the toolbar area at the top right of the Chat page, as **dropdown lists** (Menu + Picker), replacing the earlier horizontally scrolling chips.

**Model selector**: a dropdown list with the following fixed options:

| Display name | providerID | modelID |
|----------|------------|---------|
| GLM-5.1 | `zai-coding-plan` | `glm-5.1` |
| GPT-5.4 | `openai` | `gpt-5.4` |
| GPT-5.3 Codex | `openai` | `gpt-5.3-codex` |
| DeepSeek | `deepseek` | `deepseek-v4-pro` |

**Agent selector**: a dropdown list whose options come from the `GET /agent` API; the client filters out agents with `hidden != true` before displaying. Each option shows the agent name (for example `Sisyphus`), with the description available as a tooltip or subtitle.

**iPhone display policy**: narrow iPhones use short names (`DeepSeek` / `GPT` / `GLM`) to keep the layout compact; larger devices such as the iPad show full names.

**Implementation**:
- Switching the model or agent only changes local state and makes no API call to the server
- When sending a message, the body of `POST /session/:id/prompt_async` includes:
  - the `model: { providerID, modelID }` field
  - the `agent: string` field (the agent name)
- Model and agent choices are remembered per session, and switching sessions restores the corresponding selection automatically

#### 4.2.1.1 Context Usage Indicator

At the top right of Chat (between the agent selector and the Settings gear icon) a **ring progress indicator** shows how much of the context window the current session used during its most recent generation.

- **Data source**: computed from `info.tokens.total` in the assistant message returned by `GET /session/:id/message` (plus the input/output/reasoning/cache breakdown), combined with the `limit.context` of the matching `providerID/modelID` from `GET /config/providers`.
- **Provider config loading**: the `GET /config/providers` response is cached locally. If it has not loaded or is empty, tapping the ring triggers the load and shows a loading state. On failure, the sheet shows the specific error instead of only "Provider config not loaded".
- **With no data**: a gray empty ring is shown (no value), and tapping still opens the detail sheet, which reads "No usage data".
- **Color policy**: below 70% usage shows the normal color, 70-90% shows a warning color, and above 90% shows a danger color (to prevent users from blindly sending from iOS and getting truncated by the token limit).
- **Tap interaction**: tapping the ring opens a detail sheet (on both iPhone and iPad) showing the following details:
  - Session (title/id, copyable)
  - provider/model
  - context limit
  - total tokens + usage %
  - input/output/reasoning/cache read/cache write
  - total cost (shown when the server returns message cost; hidden when missing)

Note: raw messages are not shown initially. A context breakdown (the share of system/user/assistant/tool each) will be supported once the server exposes the corresponding fields or a stable derivation approach exists.

- **Visibility during AI responses**: the context ring stays permanently visible in every state (idle / busy / streaming) and is never replaced by a spinner or other temporary control. The busy state is expressed solely by the red stop button at the right of the input bar, and the toolbar no longer injects a `ProgressView`.

#### 4.2.2 Message Stream

The message list scrolls vertically and follows the OpenCode Web client style: **no left/right chat bubbles**. All messages flow in a single stream, with human messages distinguished from AI messages by a gray background, keeping the overall reading rhythm compact.

Each message contains:

**User message**: a gray-background card showing the text, with the selected model noted in small text at the bottom.

**AI message**: white or transparent background, rendered by Part type:
- `text`: full Markdown rendering (code blocks, links, lists, and other formatting)
- `reasoning`: a collapsible panel titled "Thinking..." that expands on tap to show the detailed reasoning
- `tool`: a tool call card showing the tool name and current execution state (pending → running → completed/error). It is **expanded by default while running**, with a spinner; once **completed it collapses by default**, and the user can tap to expand and view metadata details (file paths, command output, and so on)
- `tool` (todowrite): rendered as a Task List (todo) card showing the item list and completion progress (completed/total). The full todo data comes from the tool input/metadata and updates in real time through the SSE `todo.updated` event. **It is displayed only inline inside each tool card, with no persistent block at the top of Chat (option B)**
- `step-start` / `step-finish`: rendered as step dividers showing token usage and call cost
- `patch`: a file change summary card listing the modified files; tapping jumps straight to the file tree in the Files Tab and opens the matching file preview
- `tool` (write/edit/apply_patch/read_file and similar): when the part contains a file path (such as metadata.path, state.input.path, the files array, or a path parsed from patchText), tapping the card offers an "Open in File Tree" action that opens the file preview directly. If the target is an image file and the tool output can be decoded, a thumbnail is shown inline and supports tap to zoom

**Large-screen layout (iPad / Vision Pro) addition**: to use the horizontal space, `tool` / `patch` / permission cards can be arranged in a **three-column grid** (wrapping automatically when space runs out). `text` (final replies) still spans the full row so long text remains readable end to end.

**Streaming updates (Think Streaming)**: behavior matches the official web client. When SSE pushes `message.part.updated` with a `delta` field, the client appends the delta to the matching text or reasoning Part for a typewriter effect; without a delta the Part is fully reloaded. Parts are located by the `messageID` + `partID` composite key. **Note**: the server API does not yet support real-time line-level streaming of tool output (such as terminal content line by line); output data arrives in one shot only in the completed state.

**Auto-scroll rule**: incoming streaming text, tool cards, permission cards, question cards, or activity rows only keep the view auto-scrolling while the user is near the bottom of the message stream. Once the user scrolls up through history, auto-follow pauses so reading is not interrupted.

**History pagination**: to shorten first-screen loading on weak networks (such as an SSH tunnel or WAN link), the client fetches only the most recent **3 conversation rounds** (6 messages total: 3 user and 3 assistant). The top of the chat view offers a "pull down to load more history" interaction, and each pull appends 3 more rounds of history.

**Activity Row consistency rule**: observed runtime evidence takes priority over the transient flapping that `session.status=idle` can produce. As long as the client still has a running or pending tool, or is still receiving streaming deltas, the Activity Row must stay in the running state and only switches to completed once the assistant turn is confirmed fully finished.

**Session status indicator**: the top of the message stream shows the current session's run state (idle / busy / error) in real time, driven by `session.status` SSE events. A progress animation appears while busy.

#### 4.2.3 Permission Requests

OpenCode rarely asks for permission during normal execution, so a `permission.asked` event usually signals something unusual. The client therefore uses a **manual approval** model:

- Listen to the SSE `permission.asked` event in real time
- Insert a permission request card inline in the message stream that states the operation awaiting approval (for example, running `rm -rf node_modules`)
- The user taps Approve or Reject manually, and the client submits the decision via `POST /session/:id/permissions/:permissionID`
- The client offers no form of automatic approval

#### 4.2.3.1 Question Cards

When the server asks the user a question through the `question` tool, a question card is inserted directly in the Chat message stream so the session does not sit waiting unresponsively.

- Listen to the SSE events `question.asked`, `question.replied`, and `question.rejected`
- On initialization and reconnect, fetch the current session's pending questions via `GET /question`
- Support single-select or multi-select preset options, or free text typed into the input field
- Submit answers via `POST /question/{requestID}/reply`
- Reject the question via `POST /question/{requestID}/reject`

#### 4.2.4 Composer: voice rail + text review field

The fixed composer at the bottom uses two stacked rows: the voice rail on top and the text review field below. Session actions (new, rename, list, Compact) live in the Chat top toolbar and stay out of the composer area.

This structure serves the Steer product positioning directly. On mobile, users read the AI output and then quickly add directional guidance by voice; extended keyboard typing is the exception. Voice is the primary input modality, and the text field handles reviewing transcripts, light edits, and typing as a fallback. The composer therefore does not treat the microphone as a secondary button inside the text field; the voice rail takes the first row as the primary interaction panel.

**Draft persistence**: unsent input is persisted locally per sessionID. Leaving for another session and coming back restores the draft in full, and a successful send clears the local draft.

**Voice rail (Speech Recognition)**: the voice rail sits above the text field and consists of a transport button on the left, a central waveform/status display area, and a lightweight recovery action area on the right. Tapping transport starts recording: the system creates a VoiceFlowKit realtime session and captures a PCM16 mono 24kHz audio stream through `AVAudioEngine`. While recording, the central waveform consumes the smoothed mic level in the 0..1 range provided by `VoiceFlowMicrophone.audioLevel`, giving the user direct feedback on audio capture. Tapping transport again ends audio capture normally and moves into transcription, which is fully independent of aborting the agent run (agent abort).

While sending live PCM data to the remote end, VoiceFlowKit also appends the same PCM stream to a local temporary `.pcm` file. If the heartbeat check or a live send finds the WebSocket connection broken, the Kit does not terminate the recording; it rebuilds the session automatically and replays the full PCM data from the local cache, catching up to the current recording position before resuming live transmission. When the user stops recording, the system waits for recovery to finish, sends the `commit` / `stop` commands, and then appends the final transcript to the text review field below.

If transcription waits too long or stalls, the voice rail shows a processing waveform and offers a clear recovery entry point (such as `Stop transcription wait`). That action calls `abortPreservingAudio()`, which ends the current WebSocket and finalize wait while fully preserving the recorded PCM audio. The rail then enters the preserved-audio state: the transport button on the left becomes a `Retry this segment` icon that calls `transcribe(preservedAudio:)` to re-run recognition on that audio segment, and the action on the right becomes `Discard audio`, which drops the preserved audio and resets to the normal input state. This retry re-transcribes the saved audio file; it is not additional recording and requires nothing further from the user. If the retry fails again, the audio is still preserved, and the user can keep retrying or tap discard to leave the recovery flow.

**Text review field**: the text field below supports multi-line editing and receives voice transcripts, manual corrections, and pure keyboard input. While recording, the placeholder reads "transcription will appear here", avoiding visual duplication with the Listening state already shown in the voice rail and status row above. When a voice transcription or preserved-audio retry streams back a partial transcript, the field scrolls to the end so the user can watch the transcript build up; ordinary manual typing and draft restoration do not force a scroll. The send button sits at the right of the field and stays enabled even when the session is busy, because the server's `prompt_async` endpoint queues messages itself.

**Agent interrupt**: the agent's run state is indicated by a low-key status line near the composer (for example `Agent running`). `Interrupt agent` is an infrequent interrupt action tucked into the `⋯` more menu and calls `POST /session/:id/abort` when triggered. The design deliberately avoids a prominent red banner at the top and does not share the stop icon with the voice transcription recovery actions, so users can clearly separate three different kinds of state: audio capture, transcription wait, and agent run. The related token and Base URL are configured under Settings → Speech Recognition, stored in the Keychain, and never committed to git.

**Message queue**: when the session is busy, new messages the user sends go straight into a queue. The OpenCode Server's `POST /session/:id/prompt_async` has queuing built in on the server side: messages received while busy are queued automatically and processed in order once the current task finishes. The iOS side simply calls `prompt_async` and maintains no local queue logic of its own. If the server API changes in the future, the client can fall back to local queue management.

**Enter behavior research finding**: in the OpenCode web client, pressing Enter with an empty input calls abort and ends the current run, while pressing Enter with content sends the message through prompt (queued by the server). No "smart steer" mechanism exists in the system; it is simply terminate or queue. The iOS side can therefore provide an explicit manual abort button with no need for elaborate steer detection.

Additional actions (raised from buttons in the Chat top toolbar, in left-to-right order):
- Session list, rename, Compact, new session (in exactly this order)
- Compact session (calls `POST /session/:id/summarize` to compress history and reduce the risk of exceeding the token limit) (🔲 not implemented yet)

#### 4.2.5 Session Management

The Session list opens from the button at the top left of the Chat Tab (as either a slide-over or a navigation push). The page **lists every session in the current workspace** and doubles as the core verification channel for network connectivity, API parsing, and correct message and status rendering.

On iPhone, besides tapping the top `Session list` button, a swipe-right gesture from the left screen edge opens the Session List directly. The gesture reuses the existing list entry point instead of creating a new navigation branch, which makes it cheaper to reach than tapping the top-left button during one-handed use.

The Session List is a management console for the current working set, going beyond a plain history archive. Active sessions are shown by default, sorted by update time descending; archived sessions live in their own collapsible section of the list, reachable at any time without opening Settings. Both the iPhone Session sheet and the left sidebar on iPad / Vision Pro use the same two-section Active and Archived structure, and each section expands and collapses independently. This version ships no session search, so that a local title-based filter cannot be mistaken for a full history search.

Each list entry shows the session title, update time, `summary.files` (the number of files touched by that session's changes), and the current state (idle/busy/retry). Active sessions support new, switch, archive, and delete; archived sessions support open, restore, and delete. Archive / Restore / Delete are all triggered through swipe actions, following the existing button convention: SF Symbol icon on top, label below. Delete sits in the trailing swipe with a red destructive style; Archive / Restore sit in the leading swipe in a restrained electric blue or neutral color. Full swipe (dragging all the way to trigger) is disabled for every swipe action to prevent accidental triggers. Delete no longer shows a confirmation dialog: completing the swipe-and-tap sequence already expresses clear user intent.

Archive behavior: tapping Archive moves the session from the Active section to the Archived section immediately, freeing space in the main list. If the archived session has child sessions, the client must archive the whole subtree recursively, children before parents, so children do not briefly surface as Active roots after the parent is hidden. Restore behavior: tapping Restore moves the session back into the Active section; subtree restoration runs in the opposite order, parents before children, so children do not float free while the parent is still archived. If the user sends a message directly in an archived session, the client should restore that session first and then send, ensuring reactivated tasks return to the current working set. Pin is not implemented at this stage.

Visual and interaction conventions: list text defaults to a neutral gray so it does not trigger the iOS default link blue. The currently active session gets a light background highlight plus a 3pt-wide electric blue accent bar inset at the left edge (the same "left color bar" visual language used by user messages and action cards; the bar merges with the rounded selection background and is clipped fully inside the rounded corners, with no spill, and it does not conflict with the expand chevron or the indentation level). The selected state no longer shows a checkmark, which users might otherwise read as task completion or multi-select. Archived rows remain tappable for history but sit visually below Active rows: title and time use a lower-contrast neutral color, and the accent bar is not rendered, so an archived row never looks like the actively worked-on item.

#### 4.2.6 Fork Session

The user can fork the current conversation from any historical message node, producing a fresh session that contains all history up to that node. Typical use cases: dissatisfaction with the AI's current reply and a desire to redo things from a specific node, or exploring different prompt directions from the same starting conditions.

**Interaction**: each user message has a "..." more button next to the model label at its bottom (for example `anthropic/claude-opus-4-6`). Tapping it opens a menu, and choosing "Fork from here" calls `POST /session/{id}/fork`. The server creates the new session and copies all history before the selected message, after which the client switches automatically to the new session's view.

**API**: call `POST /session/{sessionID}/fork` with a body of `{ "messageID": "..." }` (optional). The endpoint returns a brand-new `Session` object.

**Implementation notes**: the feature uses SwiftUI's `Menu` component (tap-triggered) instead of `.contextMenu` (long-press) to improve discoverability. The forked session's title is generated automatically as "{original title} (fork #N)".

#### 4.2.7 Session Deep Link (Cross-Entry Session Targeting)

The client provides a standard, uniform read-only navigation link scheme:

```text
opencode://session/<session_id>
```

The link may be generated by Agent Markdown output in Chat, or it may come from Apple Notes, email, a web page, or another external app. When the user taps the link, the client verifies on the currently connected Host that the target session exists. If verification passes, the client switches project, then session, and enters the Chat page; if it fails, the current session is kept unchanged and a global error is shown in the UI. If the app is not yet running or is mid-reconnect, the navigation request is parked and resolved once the current Host becomes available again.

Global session search remains the job of the Agent and the workspace's semantic-search capability; the client adds no standalone search page, embedding index, or archive reading locally. After the Agent produces 3-5 candidate results with source evidence, it renders the explicit action as `[Open in OpenCode](opencode://session/<session_id>)`; an action link is only generated when the metadata explicitly marks the item as OpenCode and contains a valid session ID.

The V1 scope is strictly limited to the currently configured Host. The link itself carries no device-local Host Profile UUID, server URL, credentials, query parameters, or absolute file paths, and the client neither polls automatically nor switches across Hosts. A session in OpenCode's soft-archived state opens normally as long as the current server can still read it; ancient history stored only in an offline SQLite database or local Markdown archive is outside automatic recovery.

A deep link is a low-privilege, pure navigation action and is not an instruction execution channel. It cannot send prompts directly, approve permission requests, invoke tools, or delete or archive sessions, and it never auto-navigates after Markdown rendering finishes. V1 does not support message-level targeting parameters either; until Chat has stable, reliable precision scrolling and highlight anchoring, every link carrying a query, fragment, or extra path segments is rejected as invalid.

### 4.3 Files Tab (File Browsing and Diff)

> In product positioning the Files Tab is a **fallback entry point**; the main workflow lies elsewhere. The vast majority of file viewing happens through a tap on tool/patch cards in the Chat window: when an `edit_file` or `patch` card appears in the Chat message stream, tapping the file path opens the preview directly. The Files Tab exists to serve broad inspection needs: it provides reliable access when the user wants to scan all modified files at a glance or search for files not mentioned in any Chat card. It therefore does not need elaborate interface detail, but its basic capabilities must be absolutely stable.

#### 4.3.1 File Tree

On iPhone it displays full screen; on iPad it appears as the left column. Data comes from `GET /file?path=<path>`.

The file tree expands and collapses directory levels as a recursive tree. Each node shows the file/directory name and a type icon. Files with git changes carry a clear color mark (green for added, yellow for modified, red for deleted), based on `GET /file/status`.

A search box at the top supports fuzzy matching on file names (via `GET /find/file?query=...`).

#### 4.3.2 File Content Viewing

Tapping a file tree node opens the file content detail page. Data comes from `GET /file/content?path=...`.

- **iPhone**: pushes the content detail page within the Files Tab navigation stack
- **iPad three-column**: tapping a file renders it inline in the middle Preview column; tapping a file path in a tool/patch card in Chat likewise refreshes the Preview area directly (no separate sheet)

For plain text files: a monospaced code viewer shows line numbers and supports horizontal scrolling. The current version does no syntax highlighting, prioritizing rendering stability and text readability.

For Markdown files: the user can switch between Preview (rich text) and the Markdown source at any time. Preview mode renders through MarkdownUI, and very long text lines or very large files automatically fall back to raw text mode to keep the UI from stuttering.

For image references inside Markdown, the client must fully support **repo-relative path resolution**, especially the common report syntax `![x](../assets/foo.png)`. Image loading cannot rely on MarkdownUI's default network image loader alone; the client must combine the current Markdown file's path with the workspace root, resolve the reference into a proper local file request, and render it. This behaves identically for `.md` files opened directly in Files and for AI reports rendered in Chat.

For image files: base64 decoding with inline preview, initially fit-to-screen; pinch to zoom, drag to pan, double-tap to zoom in, plus the system share sheet. Where photo library permission allows, the share sheet should support `Save to Photos`.

#### 4.3.3 Diff Viewing and Document Preview

**Core positioning**: **document review** comes first. Markdown rendering, document diffs, and Preview are must-have core capabilities.

**Markdown display rules**:
- **Preview mode first**: users read documents mainly in rich text Preview; if the implementation proves too complex, a Preview / Markdown toggle may be provided
- **Change highlighting**: diffs must clearly highlight the specific changes. If rich-text inline highlighting in Preview mode proves difficult, changes can be highlighted in the Markdown source view, and the user can cross-check in Preview mode
- Minimum supported version is iOS 17, with no legacy system compatibility burden

**Two entry points**:

**Session Diff**: not currently shown directly in the iOS client (the server diff API can return an empty array in certain edge cases).

**Single-file Diff**: when a file marked with changes is tapped in the file tree and the file has uncommitted changes, the content detail page switches to diff mode automatically.

Diff rendering follows a unified diff format (GitHub style): green background for added lines, red background for deleted lines. The server returns the full `before` and `after` file contents, and the client performs the diff comparison and highlight rendering locally. Given limited phone screen width, only unified mode is offered, with no side-by-side view.

#### 4.3.5 Markdown Web Preview (HTML Cards / Enhanced SVG Reading)

Opening an `.md` document shows richly structured formatting by default: HTML status cards, inline SVG charts, and dark mode reading all render properly, and the toolbar switches back to the plain Native text view or Markdown source in one tap. Technical details are in RFC §7.5.

<style>
.wp-stat{display:inline-block;border-radius:999px;padding:1px 8px;font-size:.78rem;font-weight:650}
.wp-stat.ok{background:var(--ok-bg,#d1fae5);color:var(--ok-fg,#065f46)}
.wp-stat.block{background:var(--block-bg,#e5e7eb);color:var(--block-fg,#374151)}
</style>

| What the user experiences | Status |
|---|---|
| One-tap toolbar switch between Web / Native / source, with Web as the default | <span class="wp-stat ok">Shipped</span> |
| HTML status cards / inline SVG render properly | <span class="wp-stat ok">Shipped</span> |
| Relative images in documents load | <span class="wp-stat ok">Shipped</span> |
| The same document reads well in light / dark mode | <span class="wp-stat ok">Shipped</span> |
| Switching files refreshes content immediately, with a confirmation for large files | <span class="wp-stat ok">Shipped</span> |
| `.html` browsing / Mermaid / code highlighting / tap to zoom images | <span class="wp-stat block">Next round</span> |

Details and provenance: the decision process is in [`WORKING.md`](WORKING.md); the full sub-project PRD / RFC remain on disk at `docs/archive/2026-06_markdown_web_preview_prd.md` / `2026-06_markdown_web_preview_rfc.md` and have been removed from git tracking.

### 4.4 Settings Tab

#### 4.4.1 Host Profiles (Multiple OpenCode Environments)

The top of Settings no longer treats Server Address and SSH Tunnel as flat global settings; everything is presented through the currently active `Host`. A Host here is one self-contained OpenCode environment, either a directly reachable LAN / Tailscale / HTTPS server or an isolated OpenCode container reached through an SSH gateway. Tailscale, VPN, and the LAN are all transparent networks to the app and are grouped together as the Direct transport.

**Design goal**: within 5 seconds the user should know which OpenCode environment is connected and over which transport (Direct or SSH Tunnel), be able to switch to another host easily, and never accidentally change the underlying network configuration.

**Host list management**:

- The top of Settings shows a Current Host summary card: profile name, transport type, address summary, live connection status, and a Test button.
- The Current Host card includes lightweight connection diagnostics. It shows the current phase while the connection is being established, and on failure presents troubleshooting copy with clear next steps instead of a raw Swift error.
- Tapping the card opens the Hosts management page listing every configured profile; the active profile is highlighted on the left with an accent color bar and a checkmark.
- Each row shows the profile name, transport summary, and most recent connection status (for example `example.com:8006 -> :19001`, `Direct HTTPS + Basic Auth`, `Last used yesterday`). If the host has no successful connection on record, it says `Never connected` explicitly; epoch timestamps must never be formatted into a meaningless long relative time.
- Tapping any row opens the Host Detail page. Switching hosts is the explicit `Use This Host` primary action inside the detail page, so merely viewing the configuration never triggers a switch.
- Add Host, Host Detail, Edit, Duplicate, and Delete are all provided. Before deleting the currently active host, the app must force the user to switch to another host first or confirm in a second dialog.
- The Device Public Key, the device-wide shared credential, sits at the bottom of the Hosts page. Only SSH Tunnel hosts use it; Direct hosts do not need it.

**Host Detail page**:

- Shows the profile name, transport type, connection address summary, live connection diagnostics, and the time of the most recent connection attempt.
- A Direct profile shows the OpenCode URL and whether a Basic Auth username is configured.
- An SSH Tunnel profile shows the Gateway Host, SSH Port, SSH Username, Assigned Remote Port, the locally mapped OpenCode URL `127.0.0.1:4096`, and the trusted host fingerprint if one exists.
- When the viewed host is not the active one, the page offers `Use This Host` as the primary action; the detail page also provides `Test Connection`, `Edit`, and `Copy Host Config JSON` shortcuts.
- The SSH Tunnel profile detail page provides a `Copy This Device Public Key` entry point. The private key stays strictly in the local Keychain and cannot be exported in any form.

**Add Host flow**:

1. The recommended first choice is the `Import Host Config` entry. The user can paste the standard setup JSON distributed by the administrator, avoiding mistyped host, port, username, or remotePort during manual entry.
2. Manual creation requires choosing the `Direct` or `SSH Tunnel` transport type up front.
3. The Direct form only asks for Name, OpenCode URL, and optional Basic Auth credentials.
4. The SSH Tunnel form collects Name, SSH Gateway Host, SSH Port, SSH Username, and Assigned Remote Port. The OpenCode URL field is locked for the user; after saving, the app always connects through the local `127.0.0.1:4096` proxy tunnel.
5. The SSH Tunnel form must include an explicit `Copy This Device Public Key` button with clear security guidance: give the public key to the server administrator, and never share the private key with anyone.
6. Test Connection validates the link according to the configured transport: in Direct mode it calls `/global/health` on the remote end directly; in SSH mode it first establishes the SSH tunnel, then checks health against the local OpenCode proxy port.
7. Tapping `Save` only means the local profile was saved; only passing `Test Connection` means the network link is verified. The UI must keep "configuration saved" and "connection ready" clearly separate.

**Switching behavior**:

- When switching hosts, the app actively tears down the current SSH tunnel and SSE connection, then loads and applies the target profile.
- After the switch, the current session selection is reset. Session and project state logically belongs to a specific host; a later version may extend this to remember the last selected project/session per host.
- If the target host uses SSH Tunnel, the app may attempt to establish the tunnel automatically; on failure it only updates the connection status and never blocks the user with a modal alert.
- Basic Auth credentials are stored in the Keychain isolated per profile; the SSH private key by default is one device-wide key pair shared across profiles.

#### 4.4.2 Direct Transport

Direct mode covers network setups where the app can talk to the OpenCode instance directly: the local LAN, a Tailscale / VPN overlay, or a public HTTPS server.

**Configuration fields**:

| Field | Description | Default |
|------|------|--------|
| Name | profile name | inferred from the host or entered by the user |
| OpenCode URL | `ip:port` or `http(s)://host:port` | - |
| Username | Basic Auth username, optional | - |
| Password | Basic Auth password, optional, stored in the Keychain | - |

**Protocol security notice**: when Direct mode is configured over HTTP and the target address is not localhost, a private LAN range, or Tailscale MagicDNS (`*.ts.net`), the UI shows a non-blocking warning suggesting the user upgrade to HTTPS. The notice applies only to Direct mode; under SSH Tunnel, the local loopback address `http://127.0.0.1:4096` is by design and produces no HTTPS warning.

#### 4.4.3 SSH Tunnel Transport (Remote Access)

For reaching a managed OpenCode Server deployed on an internal network or in an isolated container through an SSH gateway. The network topology is:

```
iOS App → SSH Gateway (:8006) → Assigned Remote Port (:19001) → OpenCode (127.0.0.1:4096)
```

Prerequisites:
- The administrator has deployed a dedicated OpenCode instance server-side and assigned the corresponding remote port
- The user has given the iOS device's public key to the administrator for configuration; the private key stays strictly in the local Keychain

**Configuration fields**:

| Field | Description | Default |
|------|------|--------|
| Enable SSH Tunnel | toggle | Off |
| Gateway Host | SSH gateway address | - |
| SSH Port | SSH port | 8006 |
| Username | SSH username | opencode |
| Assigned Remote Port | remote port assigned by the administrator | 19001 |

**Key management**:

- The app generates an Ed25519 key pair automatically on first use
- The private key is stored securely in the iOS Keychain (with access control set to `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`)
- The key pair is a long-lived device identity: it is generated only on first use (when the Keychain item is genuinely missing) or on explicit user rotation. When the Keychain is temporarily unreadable (for example while the device is locked), the app errors and asks the user to unlock the device and retry, with no silent regeneration
- The public key is shown in Settings with one-tap copy to the clipboard
- A key rotation entry point is provided (regenerates a brand-new key pair)

**First-time setup flow**:

1. Open Settings → SSH Tunnel
2. The app generates the local key pair automatically
3. Copy the generated public key and send it to the OpenCode host administrator
4. After the administrator completes authorization server-side, they return the gateway host, SSH port, username, and assigned remote port
5. Enter each of those values in the app and turn on the SSH Tunnel toggle
6. Set the Server Address to `127.0.0.1:4096` (forwarded through the local tunnel) and tap `Test Connection` above to verify connectivity

**Connection status display**:

- Four states are shown in real time: Connected / Connecting / Disconnected / Error.
- SSH Tunnel diagnostics must break the link down into stages, distinguishing at least SSH gateway reachability, SSH auth, the local tunnel proxy channel, and the OpenCode health check.
- On failure the app states the cause and gives troubleshooting advice, such as prompting the user to copy the device public key for the administrator when the key is unauthorized, or to check the username and password when Basic Auth fails.

**Security requirements**:

- Only key-based SSH authentication is supported; password authentication is not offered
- The first connection uses TOFU (Trust On First Use) to trust and save the server's host fingerprint automatically, and later connections verify the fingerprint strictly; the UI provides fingerprint viewing and a reset trusted host action

#### 4.4.4 Model Presets

**Current implementation**: a built-in fixed list of preset models (GLM-5.1, GPT-5.4, GPT-5.3 Codex, DeepSeek), with no import or reordering yet. When sending a message, the request body carries the `model: { providerID, modelID }` structure.

#### 4.4.5 Project (Workspace)

Used to pick the OpenCode project context to browse. The OpenCode Server supports multiple projects natively, each with its own set of sessions. The iOS client filters sessions by project directory through `GET /session?directory=<worktree>`.

**Choosing an existing project**:
- Call `GET /project` for the list of projects known to the server
- Present projects with a Picker; each option's display name defaults to the last path segment of the worktree (such as `knowledge_working`, `agentic_trading`)
- The selected project is persisted in UserDefaults

**Custom path support**:
- A "Custom path" option lets the user type any absolute worktree path
- Covers edge directories that have session records server-side but were not picked up into the project list automatically
- If the path is wrong, `/session?directory=xxx` returns 0 sessions, which the user can see directly

**Default project behavior**: when the user has not picked a project explicitly, `GET /session` is called without the `directory` parameter, defaulting to the project currently open on the server (matching the web client's logic). Once a specific project is selected, the client calls `GET /session?directory=xxx&limit=100` for the matching data.

**Session creation restriction**: new sessions can only be created while Server default is selected. Because the server's `POST /session` endpoint takes no directory parameter, every new session is bound to the project currently open on the server. When the user has selected a specific project, the new-session button grays out automatically with an info icon explaining that OpenCode must be started from the command line with a different working directory before creating.

#### 4.4.6 Appearance

- **Theme follows system** (Light/Dark/Auto): switches presentation style automatically based on the iOS light or dark theme setting
#### 4.4.7 About

- Shows the current app version
- Shows the connected OpenCode Server version (taken from the `version` field of the `GET /global/health` response)

### 4.5 Car Mode (Experimental)

Car Mode is a foreground voice interaction mode designed for iPhone. In driving situations where reading long conversations or typing is impractical, a single tap completes the loop of "speak an instruction, submit automatically, hear a condensed conclusion". The feature is built into the OpenCode iOS Client; there is no separate car app to maintain, and it is not a standalone CarPlay app.

#### 4.5.1 Product Scope

- Car Mode is off by default and is enabled only through an explicit entry in Settings → Experimental Features.
- When enabled, the iPhone bottom tab order becomes Chat / Files / Car / Settings; disabling restores Chat / Files / Settings.
- The Car Tab and its settings toggle are not shown on iPad or Apple Vision Pro (including in iPad compact window mode).
- Tapping the large primary button starts recording; tapping again ends audio capture and triggers the send automatically, skipping the composer confirmation step of normal Chat mode entirely.
- AI replies are strictly constrained to a short, directly speakable structured speech format; after the Apple TTS engine finishes speaking, the system resets to the idle state automatically.
- The client actions that may be triggered are `open_navigation` and the V0 `health_quantification.export_all`. Maps navigation assembles the target URL locally on iOS; the Health data export goes through local permission checks, a restricted app handoff, and a callback to the original session. The product interaction contract is in [`features/client_capabilities/prd.md`](features/client_capabilities/prd.md).

Car Mode makes no promise of continued background recording, a kept-alive SSE connection, or ongoing TTS playback once the system switches to Maps or another app. As soon as the app enters the background, the current foreground interaction stops immediately, while the Car session persists; when the user returns to the app, interaction continues in the original context.

#### 4.5.2 Dedicated Session and Visibility

Car Mode does not reuse the conversation context currently selected in normal Chat. Each `(host profile, workspace)` pair maintains its own dedicated, persistent Car session, with the most recently handled assistant message ID, any pending confirmation, and the last active timestamp recorded locally.

- The first interaction creates a dedicated session titled `Car Mode` automatically.
- Every subsequent send first checks that the session is still valid; a 404 clears the old local mapping and creates a fresh session automatically.
- If the user manually archives the current Car session in the normal Session list, the client writes the compatibility restore marker `time.archived = -1` to that session before the next Car Mode request, then keeps submitting messages to the original session. Because the iOS client treats `archived > 0` as archived, the session reappears in the iOS Active list automatically.
- This recovery logic only guarantees visibility inside the iOS client. The OpenCode Web client defines active strictly as `archived === undefined`, so it may still fail to show a session marked `-1`; Car Mode deliberately introduces no non-standard server patch and neither forks nor copies the original session.
- The user can start a brand-new Car session manually. Merely switching tabs, opening external Maps, or briefly leaving the app must never trigger an automatic new session.

Once parked, the user can open the Car session from the normal Chat list at any time to see the full message history and tool call details. When a structured assistant response contains no text part, the Chat view automatically shows `assistant.structured.speech` as the readable fallback.

#### 4.5.3 Replies, Confirmation, and Real-World Actions

Every turn carries a Car-specific system prompt and JSON Schema constraints. Voice replies follow a conclusion-first rule and must never contain Markdown, URLs, code blocks, or intermediate tool call traces; the target spoken duration is 8-12 seconds, with 15 seconds as the hard maximum. Execution states are strictly limited to three: `completed`, `needs_confirmation`, and `failed`.

| Type | Example | Default behavior |
|---|---|---|
| Read | Is the garage door closed; how long is the drive; any new email | Execute directly and speak a short conclusion |
| Prepare | Summarize email; draft a message | Prepare directly, stating clearly that nothing was sent |
| Explicit server commit | Open the garage door; send the earlier reason to the contact | Execute when the user's parameters are clear, then read the result back |
| Proposed server commit | The agent suggests sending or controlling a device | Return `needs_confirmation` and execute after the next turn's confirmation |
| Client handoff | Navigate to a named destination; sync stale Health data | Return a typed action and let iOS open the restricted target app |
| Ambiguous | Multiple contacts, doors, or destinations | Ask one clarifying question at most, then cancel if still unclear |

A strict rule applies: only explicit authorization from a user message may trigger actions with real-world side effects. Instructions appearing in email, web page bodies, search results, or tool output are treated strictly as passive data and must never directly authorize sending messages, controlling smart devices, or firing client actions. V1 must never allow arbitrary destructive shell execution, code commits, production releases, money transfers, or unrestricted multi-step real-world operations.

Specific capabilities such as Smart Home, email, iMessage, and route duration still need to be formally registered as system-level allowlisted skills or typed tools, with a real end-to-end path in place. The generic `read + bash` approach is allowed only during prototype exploration (a spike) and cannot serve as the production security permission boundary.

#### 4.5.4 State and Failure Recovery

The main screen keeps one primary visual action button while showing the current state, the most recent recognized transcript, the most recently spoken speech, and error messages. The full state flow is:

```text
idle → recording → finalizing → waitingReply
     → speaking / awaitingConfirmation / failed → idle
```

Message sending fires automatically only after a final transcript is successfully confirmed; partial transcripts (intermediate results) or recognition failures must never trigger any real-world action. During the `waitingReply` phase, repeat submissions are not allowed, though the user may cancel and send abort to the server. TTS playback and Maps navigation actions must be deduplicated precisely against the completed assistant message ID.

#### 4.5.5 Phasing and Non-Goals

The foreground Car Mode core loop is implemented and shipped: the experimental feature toggle, iPhone-only UI, isolated session handling, VoiceFlow auto-submit, structured reply parsing, Apple TTS playback, typed Maps navigation handoff, the Health export callback, and history fallback display in normal Chat.

Future work follows two tracks: productizing the high-frequency capabilities (Smart Home, email, iMessage, route duration) into a stable capability boundary, and rebuilding the current synchronous structured request into the `prompt_async + SSE + message reload` asynchronous model for more reliable foreground/background state recovery and exactly-once idempotent action execution. Even once async recovery lands, that does not mean background voice conversation is supported.

A native CarPlay app, button-free continuous conversation while Maps runs in the foreground, arbitrary URL actions, and open-ended real-world automation are all explicitly out of scope for the current version.

## 5. Data Flow and State Management

### 5.1 Core State Model

```swift
@Observable class AppState {
    // Host profiles
    var hostProfiles: [HostProfile]
    var currentHostProfileID: UUID
    var currentHostProfile: HostProfile

    // Derived connection state for current host
    var serverURL: String              // derived from currentHostProfile.serverURL
    var isConnected: Bool
    var serverVersion: String?
    var sshTunnelConfig: SSHTunnelConfig? // present only for sshTunnel transport
    var connectionTransport: HostTransport
    
    // Project (workspace filter)
    var projects: [Project]
    var selectedProjectWorktree: String?   // nil = use server current
    var customProjectPath: String         // for "Custom path" option
    
    // Sessions
    var sessions: [Session]
    var currentSessionID: String?
    var sessionStatuses: [String: SessionStatus]  // sessionID → status
    
    // Messages (for current session)
    var messages: [Message]          // ordered by time
    var parts: [String: [Part]]      // messageID → parts
    
    // Models
    var modelPresets: [ModelPreset]   // user-configured
    var selectedModelIndex: Int
    
    // Files
    var fileStatuses: [FileStatus]   // git status
    var sessionDiffs: [FileDiff]     // current session's diffs
    
    // Permissions
    var recentPermissions: [PermissionLog]
}
```

Data migration strategy: the first implementation can keep the existing `serverURL`, Basic Auth, and `SSHTunnelManager.config` fields as an expanded cache of the active profile, but persistence must converge on `hostProfiles` as the single source of truth. When switching profiles, the selected profile writes its data back into these runtime fields, avoiding a single deep refactor that would risk the stability of the APIClient, SSE, and SSH tunnel modules.

### 5.2 SSE Event Handling

On receiving an SSE event, the client dispatches on its `type` field to the matching business logic:

| Event | Handling logic |
|------|----------|
| `session.created` | Append to the sessions list |
| `session.updated` | Update the matching session's properties |
| `session.status` | Update the sessionStatuses dictionary |
| `session.diff` | Update sessionDiffs (when pushed over SSE; otherwise fetched via `GET /session/:id/diff`) |
| `message.updated` | Update or insert the message |
| `message.part.updated` | Update the matching part; with a delta, append to the end of the text part |
| `message.part.removed` | Remove from parts |
| `permission.asked` | Show a permission request card and wait for manual approval |
| `file.edited` | Trigger a file status refresh |
| `session.error` | Show an error toast |

### 5.3 Connection Recovery Strategy

```
App enters foreground
  ├── Call GET /global/health to confirm the server is alive
  ├── Call GET /session to fetch the session list
  ├── Call GET /session/:id/message?limit=6 to fetch the current session's last 3 rounds of messages
  ├── Call GET /session/status to fetch all session statuses
  └── Open the SSE connection to GET /global/event
      └── Subsequent incremental updates are driven by SSE
```

The client combines a full state pull with incremental event subscription, so even if iOS tears down the SSE connection while the app is backgrounded, returning to the foreground loses no state and produces no data inconsistency.

## 6. API Dependency List

The following is the complete list of OpenCode APIs the iOS Client calls:

### 6.1 Required APIs

| Method | Path | Purpose |
|------|------|------|
| GET | `/global/health` | Connection test and server version |
| GET | `/global/event` | SSE event stream |
| GET | `/session` | Session list (supports `directory` and `limit` parameters for per-project filtering) |
| POST | `/session` | Create a session |
| GET | `/session/:id` | Session details |
| DELETE | `/session/:id` | Delete a session |
| GET | `/session/:id/message` | Message list (supports `limit`; defaults to the most recent 6) |
| POST | `/session/:id/prompt_async` | Send a message (async) |
| POST | `/session/:id/abort` | Abort the run |
| GET | `/session/:id/diff` | Session diff |
| GET | `/session/status` | Status of all sessions |
| POST | `/session/:id/permissions/:pid` | Respond to a permission request |
| GET | `/question` | Fetch pending questions |
| POST | `/question/:id/reply` | Answer a question |
| POST | `/question/:id/reject` | Reject a question |
| GET | `/file?path=...` | File list |
| GET | `/file/content?path=...` | File content |
| GET | `/file/status` | Git status of files |
| GET | `/find/file?query=...` | File search |
| GET | `/config/providers` | Available providers and models |
| GET | `/agent` | Available agents |
| GET | `/project` | Project list |
| GET | `/project/current` | Current project |

### 6.2 Optional APIs (Later Enhancements)

| Method | Path | Purpose |
|------|------|------|
| POST | `/session/:id/summarize` | Compact session (🔲 not implemented yet) |
| POST | `/session/:id/fork` | Fork a session |
| GET | `/session/:id/todo` | View the AI's todo list |
| GET | `/find?pattern=...` | Full-text search |
| GET | `/mcp` | MCP service status |
| GET | `/lsp` | LSP status |
| PATCH | `/config` | Modify configuration |

## 7. UI Wireframes

### 7.1 Chat Tab — iPhone

```
┌─────────────────────────────────┐
│ ☰ Sessions    Session Title   ⋯ │  ← Navigation bar
├─────────────────────────────────┤
│ [Claude Opus] [Sonnet 4.6] [G..│  ← Model switcher bar (horizontal scroll)
├─────────────────────────────────┤
│                                 │
│  ┌───────────────────────────┐  │
│  │ Refactor the auth module  │  │  ← user message
│  │              Claude Opus  │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │ ▸ Thinking... (collapsed) │  │  ← reasoning part
│  │                           │  │
│  │ I'll start by analyzing   │  │  ← text part (streaming)
│  │ the current auth flow...  │  │
│  │                           │  │
│  │ ┌───────────────────────┐ │  │
│  │ │ 🔧 read_file ✓        │ │  │  ← tool part
│  │ │   src/auth/handler.ts │ │  │
│  │ └───────────────────────┘ │  │
│  │                           │  │
│  │ ┌───────────────────────┐ │  │
│  │ │ 🔧 edit_file ⟳        │ │  │  ← tool running
│  │ │   src/auth/handler.ts │ │  │
│  │ └───────────────────────┘ │  │
│  │                           │  │
│  │ ⚠️ Permission required:   │  │  ← permission request (manual approval required)
│  │   shell: npm test [Approve]│  │
│  └───────────────────────────┘  │
│                                 │
├─────────────────────────────────┤
│ │ Type a message...    │ ➤ 🎤 │  ← input field (send + microphone)
└─────────────────────────────────┘
```

### 7.2 Files Tab — iPhone

```
┌─────────────────────────────────┐
│         Files                   │
├─────────────────────────────────┤
│ [File Tree]                     │
├─────────────────────────────────┤
│ 🔍 Search files...              │
├─────────────────────────────────┤
│ ▼ src/                          │
│   ▼ auth/                       │
│     ● handler.ts        +12 -5  │  ← modified (yellow dot)
│     ○ types.ts                  │
│   ▶ api/                        │
│   ▶ utils/                      │
│ ▼ tests/                        │
│   ● auth.test.ts        +45 -0  │  ← new file (green dot)
│ ○ package.json                  │
│ ○ tsconfig.json                 │
└─────────────────────────────────┘
```

Tapping a file pushes to the file detail page:

```
┌─────────────────────────────────┐
│ ◀ Files   handler.ts   [Diff]  │
├─────────────────────────────────┤
│  1 │ import { Router } from ... │
│  2 │ import { verify } from ... │
│  3 │                            │
│  4+│ export async function      │  ← added line (green background)
│  5+│   authenticateUser(        │
│  6+│   req: Request             │
│  7 │ ) {                        │
│  8-│   const token = req.head.. │  ← deleted line (red background)
│  9+│   const token = extractT.. │  ← added line
│ 10 │   ...                      │
└─────────────────────────────────┘
```

### 7.3 Settings Tab — iPhone

```
┌─────────────────────────────────┐
│         Settings                │
├─────────────────────────────────┤
│                                 │
│ SERVER CONNECTION               │
│ ┌─────────────────────────────┐ │
│ │ Address   192.168.0.80:4096   │ │
│ │ Username  opencode          │ │
│ │ Password  ••••••••          │ │
│ │ Status    🟢 Connected      │ │
│ │           [Test Connection] │ │
│ └─────────────────────────────┘ │
│                                 │
│ APPEARANCE                      │
│ ┌─────────────────────────────┐ │
│ │ Theme             [Auto   ▾]│ │
│ └─────────────────────────────┘ │
│                                 │
│ SPEECH RECOGNITION              │
│ ┌─────────────────────────────┐ │
│ │ AI Builder Base URL  (space.ai-builders.com/backend) │ │
│ │ AI Builder Token     •••••• │ │
│ │           [Test Connection] │ OK │
│ └─────────────────────────────┘ │
│                                 │
│ ABOUT                           │
│ ┌─────────────────────────────┐ │
│ │ App Version        0.1.0    │ │
│ │ Server Version     1.1.61   │ │
│ └─────────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

## 8. Development Phases

### Phase 1: Minimum Viable Product (MVP)

**Goal**: connect to the server, send messages, and receive the AI's streaming responses in real time.

| Feature | Description |
|------|------|
| Server connection | Manual IP:Port entry, Basic Auth |
| SSE event stream | Connect, disconnect, reconnect, foreground/background transitions |
| Session basics | List, create, switch (delete not yet implemented) |
| Message sending | Text input, send (using `prompt_async`), view response; messages queue automatically while busy |
| Streaming render | Real-time typewriter effect for the text part |
| Model switching | Preset model list, model specified at send time |

**Estimated effort**: 2-3 weeks (assuming SwiftUI development experience)

### Phase 2: Full Interaction

**Goal**: effective monitoring and review across the full AI execution flow.

| Feature | Description |
|------|------|
| Message Part rendering | All Part types: reasoning, tool, step, patch, and more |
| Manual permission approval | Listen for permission.asked, show the request card, user approves manually |
| Abort / Compact | Abort a run, compress a session |
| Markdown rendering | Full Markdown rendering in AI messages |
| Theme switching | Follow system Light/Dark |
| Code block highlighting | Syntax highlighting for code blocks in messages |
| **Think Streaming** | Delta incremental updates (typewriter effect), tools collapse by default after completion |

**Estimated effort**: 2 weeks

### Phase 3: File Browsing, Document Review, and iPad/Vision Pro Layout

**Goal**: complete file browsing and **document review** capabilities, plus the three-column large-screen layout for iPad and Vision Pro.

| Feature | Description |
|------|------|
| File tree | Directory expand/collapse, git status marks |
| File content | Line numbers, monospaced font (no syntax highlighting yet) |
| File search | Fuzzy file name search |
| Markdown preview | Preview mode first, with Markdown/Preview switching |
| Document diff | Highlight changes (in Preview first, otherwise in the Markdown source) |
| Session diff | Changed-file list and diff view for the current session |
| Single-file diff | A file's uncommitted changes |
| **Think Streaming** | Delta incremental updates (typewriter effect) |
| **iPad / Vision Pro layout** | No tab bar; three columns: left Workspace (Files+Sessions), middle Preview, right Chat; Settings as a first-row toolbar button |

**Estimated effort**: 2-3 weeks

### Phase 4: Polish and Enhancements (Not Implemented Yet, Ordered by Priority)

| Feature | Description |
|------|------|
| **Push notifications / Live Activity** | When the AI pauses to wait for a human decision (question / permission / run finished), proactively notify through APNs or a Live Activity to eliminate idle waiting on both sides. This is the core engineering capability for completing the Steer loop |
| **Session recognizability** | Improve the visual distinction between active and inactive sessions to reduce the effort of finding the target session in a long list |
| mDNS discovery | Discover OpenCode servers on the LAN automatically |
| Widget | An iOS home screen widget showing the current session status live |
| Haptic feedback | Tactile feedback at key interaction points |
| Spotlight integration | Find recent sessions quickly through system Spotlight |

## 9. Known Limitations and Risks

**Network dependency**: the app depends entirely on its connection to the OpenCode Server. If the server is unreachable (network down, or the server process not running), the app cannot work. Two modes are currently supported: LAN direct connection and SSH tunnel remote access. On weak networks, the pull-last-3-rounds-plus-pagination strategy keeps first-screen waiting short.

**SSE behavior on iOS**: when the app enters the background, iOS aggressively reclaims network resources and closes long-lived connections. The design therefore needs a reliable reconnect mechanism and foreground state restoration, and holding SSE open in the background is discouraged.

**Screen size**: on a narrow iPhone, laying out code and diff content horizontally poses real readability challenges. Details such as horizontal scrolling and font scaling need careful optimization. The larger iPad screen presents this content considerably better.

**Server API stability**: the OpenCode HTTP API currently offers no strict versioning commitment (there is no `/v1/` style prefix, for example). Later server versions may introduce breaking changes. The iOS client should parse API responses defensively, silently ignoring unknown fields rather than crashing.

**Security posture**: the app initially targets trusted local network environments, where overall risk is manageable. If public internet access is opened up later, hardening such as TLS encryption and token-based authentication must be added across the board. The current Basic Auth over HTTP suits LAN use only and must not be exposed directly to the public internet. **ATS exceptions**: HTTP is allowed on the LAN (private IP ranges, localhost, .local) and for Tailscale MagicDNS (`*.ts.net`); all other public WAN requests require HTTPS. The `NSExceptionDomains` entry in Info.plist already carries the `ts.net` exemption.

**Human-AI idle waiting (missing notifications)**: when the AI suspends on a `question` tool, a permission request, or a wait for human review, and the user has already left the app (iOS in the background), there is currently no way to notify them proactively. Both sides then sit waiting: the AI waits for human instruction, and the human does not know a decision is needed. The root cause is an iOS platform engineering limit rather than a UX design issue: Push Notifications (APNs) or a Live Activity are needed to break through the background restrictions and wake the user. Although Phase 4 marks this "not implemented yet", it should be treated as a high-priority engineering enhancement, since it directly determines how efficiently the Steer loop closes.

## 10. Decided Items

1. **Message sending API**: `POST /session/:id/prompt_async` was chosen. Server source review confirmed that the sync and async endpoints both call the same `SessionPrompt.prompt()` logic underneath, with async simply not blocking on the final response; message creation, task processing, and SSE event behavior are identical between them. Since the iOS client pairs with SSE for real-time results anyway, the async mode is the better fit.

2. **Large sessions**: no special handling for now. The current design assumes a single session stays under about a hundred messages.

3. **Push notifications**: not implemented at this stage, but identified as a high-priority engineering enhancement. When the AI suspends awaiting a human decision (question / permission / run finished), APNs or a Live Activity must reach the user past iOS background restrictions, eliminating the asynchronous wait between human and AI.

4. **Multi-project support**: not being built at this stage.

5. **Default server**: the default address is `127.0.0.1:4096`. Authentication is off by default, but the client fully implements Basic Auth support so it can be configured on demand.

## 11. Getting Started Guide

### 11.1 Project Setup

The repository already contains a complete Xcode project that opens directly. New developers are recommended to start one of two ways:

1. Install the prebuilt version through the TestFlight link in the README
2. Clone the repository and open `OpenCodeClient/OpenCodeClient.xcodeproj` to build and debug locally

### 11.2 Dependencies and Structure

- **Networking**: REST requests and the SSE event stream are implemented natively with `URLSession`, with no third-party networking library such as Alamofire
- **State management**: iOS 17+ native `@Observable` with SwiftUI for reactive state binding
- **Markdown**: the open-source [MarkdownUI](https://github.com/gonzalezreal/MarkdownUI) library
- **Theming**: `@Environment(\.colorScheme)` observes and follows the system theme
- **SSH Tunnel**: the Citadel library provides SSH tunneling

The client code is organized into clear layers by responsibility:

- `Views/`: UI views for the Chat, Files, Settings, and Split View modules
- `Controllers/`: logic controllers for interaction events such as permission and question
- `Services/`: core services covering API communication, SSE streams, SSH tunneling, voice recording, and transcription
- `Stores/`: core business state for Session, Message, File, Todo, and more
- `Models/`: data structures such as Session, Message, Project, Question, and ModelPreset
- `Support/`: localization and general support components
- `Utils/`: base utilities such as Keychain storage, PathNormalizer path handling, and LayoutConstants layout values

### 11.3 Recommended Implementation Order

1. **Phase 1**: get server connection, the SSE event stream, session management, message sending, and basic streaming rendering working
2. **Phase 2**: complete message Part rendering, manual permission approval, theme switching, and `prompt_async`-based message queuing
3. **Phase 3**: finish the file tree, Markdown preview, document diff comparison, and change highlight rendering

### 11.4 Connecting to the OpenCode Server

The default server address is `127.0.0.1:4096` (no authentication). If the server enables auth environment variables such as `OPENCODE_SERVER_PASSWORD`, enter the matching Username and Password in the client's Settings. For LAN direct connection, configure the server's LAN IP address directly; for remote access, forward through an SSH tunnel to the local `127.0.0.1:4096` port.

---

## Appendix A: OpenCode Server Key Data Structure Reference

### Session

```typescript
{
  id: string
  slug: string
  projectID: string
  directory: string
  parentID?: string
  title: string
  version: string
  time: { created: number, updated: number }
  share?: { url: string }
  summary?: { additions: number, deletions: number, files: number }
}
```

### Message (User)

```typescript
{
  id: string, sessionID: string, role: "user",
  model: { providerID: string, modelID: string },
  time: { created: number }
}
```

### Message (Assistant)

```typescript
{
  id: string, sessionID: string, role: "assistant",
  parentID: string,  // links to user message
  providerID: string, modelID: string,
  cost: number,
  tokens: { input: number, output: number, reasoning: number, cache: { read: number, write: number } },
  time: { created: number, completed?: number }
}
```

### Part (core types)

```typescript
// Text
{ id, type: "text", text: string }

// Reasoning
{ id, type: "reasoning", text: string }

// Tool call
{ id, type: "tool", callID: string, tool: string, state: "pending"|"running"|"completed"|"error", metadata?: any }

// Step markers
{ id, type: "step-start", snapshot?: string }
{ id, type: "step-finish", reason: string, cost: number, tokens: {...} }

// File change
{ id, type: "patch", hash: string, files: [...] }
```

### FileDiff

```typescript
{
  file: string,       // relative path
  before: string,     // full content before
  after: string,      // full content after
  additions: number,
  deletions: number,
  status?: "added" | "deleted" | "modified"
}
```

### SSE Event

```typescript
{
  directory: string,  // project path, or "global"
  payload: {
    type: string,     // e.g. "message.part.updated"
    properties: any   // event-specific data
  }
}
```
