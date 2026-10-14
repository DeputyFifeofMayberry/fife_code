# OpenCode iOS Client — Working Document

> A running record of progress, problems, and decisions made during implementation

## Current Status

### 2026-10-12 — OpenCode server v2 compatibility (opencodev2-integration branch)

- **Background**: The user's server was already v2.0.26 while the client only spoke v1. Implemented the dual v1/v2 protocol per `docs/v2_server_compatibility.md` (the single source of truth for the wire contract).
- **Changes**: (1) Detection: `HostProfile.apiGeneration` (missing = auto, cleared on URL change); at connect time `/global/health` → `/api/info` probing (`ServerGeneration.swift`) with the result written back to the profile. (2) REST: each APIClient method branches on generation (`APIClient+V2.swift`) with exact status codes; archive writes return 404 directly, todos come back empty with no request, and the form reply table lives in APIClient. (3) Pure mapping: `V2Mapper.swift` implements the full spec table and produces the existing models. (4) SSE: v2 frames `{id,type,data}` are normalized and then translated into the existing handlers per the spec's SSE table (the data path is shared with v1); `session.created/renamed/metadata.updated` go through GET+upsert.
- **Two approved deviations**: v2 `type:"synthetic"` messages are mapped (visible as receipt cards); `isConnected` is set as soon as probing succeeds (omitting the spec's session-list gate).
- **Tests**: four new files, `ServerGenerationTests` / `V2MapperTests` / `V2APIWireTests` / `V2SSETests` (probe with a saved body, one test per spec Unit-tests row, wire status-code assertions, SSE translation and convergence). CI run still pending (no local Xcode on Windows).
- **Open items**: the real synthetic body is untested (the fixture mirrors the user-row shape; fall back to dark if it does not match); the `v2_contract_check.py` live run and TestFlight verification remain to be done.

- **Last updated**: 2026-10-08
- **Branch**: `fix/chat-session-scroll-anchor`
- **Build/tests**: `OpenCodeClientTests` all green (569 tests, including 6 new subagent aggregation tests). UI: `SessionScrollAnchorUITests` 2/2 and `ToolCardsUITests` 1/1 pass (iPhone 16 Pro `3EB51FEF-C951-4485-AD0F-33463C66DBEB`, iOS 18.4).
- **Phase**: background subagent activity is visible on the parent row and in the chat page

### 2026-10-08 — Background subagent keeps running while the main session is idle, UI shows nothing

- **Symptom**: After handing a task to a background subagent, the parent session finishes its turn and its status becomes `idle`, while the subagent stays `busy` inside its own child session. The session list parent row shows Idle and the chat page shows no sign of ongoing work, so it looks like nothing is running.
- **Root cause**: Status is stored per session (runner) (`session/status.ts`: removed from the map on `idle`), so the parent goes idle as soon as its own runner ends; the subagent has its own runner. Both clients store `sessionStatuses` as a global map, so the child's busy data is available, but presentation only reaches the single-session level: the list parent row reads only `statuses[parent.id]`, child rows are collapsed by default and sit inside folded nesting, and the chat page's `isBusy` looks only at the current session.
- **Fix**: The client derives "conversation-tree aggregated activity" with zero server changes. `descendantBusyCountsBySession` counts busy descendants upward along `parentID` (excluding self), modeled directly on the existing attention aggregation slot. The list parent row shows a distinct secondary signal when it is not busy itself and has no attention (branch icon + neutral color + "N subagents running", distinguished from the brand blue used for its own Running), and such trees rise to the top of the list (discoverable even while collapsed). The chat page adds a separate "subagent running" segment to the status bar when it is idle and has busy descendants: the child session title when there is one, a count when there are several; tapping reuses `openReferencedSession` to jump to that child session. It does not occupy the turn stopwatch or interrupt (those belong to the child session's own clock). Copy was drafted via AGY (gemini-3.8-flash-high).
- **Tests**: six new tests in `SessionTreeTests`: `descendantBusyCountsRollUpAndExcludeSelf` / `...HandleRetryAndIgnoreIdle` / `...IgnoreBusySelfWhenNoChildren` / `descendantBusySessionsSortAheadOfNewerSessions` / `sessionDescendantBusyCountsReadGlobalStatusMap` / `runningDescendantSessions...`. The Android side has the matching 6 in `SessionTreeTest` (`./gradlew testDebugUnitTest` green).

### 2026-09-29 — Switching session away and back leaves the chat area stuck mid-conversation

- **Symptom**: After switching to another session and back, the chat area does not scroll to the bottom of the conversation. It stops at some message in the middle, and you have to scroll down manually for a long while to reach the latest message.
- **Root cause**: The chat `ScrollView` is a single SwiftUI identity reused across sessions. When `selectSession` replaces `messages`, the underlying UIScrollView keeps the old session's `contentOffset` as the starting position for the new content (when the old session's content is long, the landing point sits right in the middle of the conversation). The only path back to the bottom was the reactive chain of "`scrollAnchor` change + `isNearBottom` gate + 50ms-delayed `scrollTo`": on switching, `onChange(currentSessionID)` only optimistically sets `isNearBottom` to true and hopes the next `scrollAnchor` change carries the scroll. If the `scrollTo` after the async load lands does not actually reach the bottom (lots of content laid out in the same transaction, offset clamped to the size known at that moment), the 75ms bottom marker measurement immediately flips `isNearBottom` to false, after which all auto-scrolling is blocked by the `guard` with no retry, and the view stays pinned at the old offset.
- **Fix**: Give each session's scroll view a fresh identity: append `.defaultScrollAnchor(.bottom)` + `.id(state.currentSessionID)` at the end of the `ScrollView` chain. Switching sessions rebuilds the whole scroll view, and the initial position is pinned to the bottom by the default anchor (iOS 17+, deployment target 17.0). The existing reactive follow mechanism (`isNearBottom` + `scrollAnchor`) is kept and continues to handle "follow while the user is at the bottom" during streaming updates. A positive side effect: the identity change triggers `onDisappear`, which cancels leftover pending scroll / visibility tasks on switch, eliminating cross-session scroll task races.
- **Side effects**: (1) Content shorter than the screen is bottom-aligned; short sessions (1–2 messages) change from top-aligned to bottom-aligned (standard chat behavior), while empty states (no session / no messages / busy placeholder) use a viewport-height frame (`emptySessionStateView(viewportHeight:)`) to keep the original top-aligned look. (2) Row-level `@State` (thinking cards / tool calls expanded state) resets to collapsed after switching away and back.
- **Tests**: Added an offline fixture `UITEST_SESSION_SCROLL_FIXTURE` (`SessionScrollFixture.swift`: a 40-turn long session plus a short session, with an `APIClientProtocol` stub providing the full `selectSession` data chain, no network). `SessionScrollAnchorUITests` has 2 tests: the long session renders its first screen at the bottom (frame assertions that the last user message is on screen and the first is off screen), and after switching to the short session and back to the long session it lands at the bottom (the regression case for this symptom). The existing `ToolCardsUITests` (which rely on auto-scroll-to-bottom at launch) still pass.

### 2026-09-27 — Background subagent receipts render as TaskNotificationCard

- **Symptom**: The server injects background task completion results as a synthetic user message whose body is `<task>` XML. The client did not decode `synthetic`, so the receipt was drawn as raw XML inside a blue user bubble.
- **Fix**: `Part.synthetic` is decoded with `decodeIfPresent`. `TaskNotificationParser` uses a range to locate the outermost envelope so nested angle brackets are not mis-split. A synthetic text that parses successfully renders as a card: status icon + localized status + task title with the English prefix stripped; the result goes through the existing markdown path and is expanded by default at ≤500 characters. When expanded, the subagent session can be opened by reusing `selectSession`, switching project directory when it differs; a missing session goes through `sendError`. Copying the receipt copies the result body. These messages do not show Edit-from-here.
- **Tests**: 16 tests in `TaskNotificationParserTests` / `TaskNotificationRenderingTests`; `UITEST_TASK_NOTIFICATION_FIXTURE` covers expansion and navigation. For long results the jump button is off the first screen, so the UI test swipes up after expanding before tapping.

### 2026-09-26 — Grok does not show the quota pill

- **Symptom**: With `xai/grok-*` selected the toolbar has no quota pill, while GPT / GLM / Ollama do.
- **Root cause**: The pill shows only when `primaryQuotaKey != nil`. The mapping covered only `openai` → `codex/5h`, `zai-coding-plan` → `glm/5h`, and `ollama-cloud` → `ollama/5h`. `xai` fell through to the default case, returned nil, and the whole button was not rendered. In the Dashboard `/api/v1/quotas`, this window is `provider=grok` with `label=Weekly`.
- **Fix**: `xai` maps to `grok` / `Weekly`. When the preferred window is missing from the snapshot, fall back to a window the provider actually has. Data is fetched on entering Chat instead of waiting for a tap. With a number available it shows the percentage; with no number yet it shows only the window name and does not draw `--`. A successful fetch within the last hour is brand blue; older than an hour or a failed refresh is gray. The detail page's provider name gains Grok. The 60-second dedup for non-forced refreshes is unchanged.

### 2026-09-21 — Model shortlist left-handle reorder does not take effect on release

- **Symptom**: In Settings → Models, the `line.3.horizontal` handle on the left of each row can be picked up, but the order does not change after release.
- **Root cause**: Reordering was attached to the `List` row's `.onDrop`. A drag session internal to the same list never reaches `ShortlistDropDelegate`, so `dropEntered` never runs and `moveShortlist` is never called. The provider type (`public.utf8-plain-text`) also mismatched `UTType.plainText`.
- **Fix**: Removed `onDrag` / `onDrop`. The left handle now uses a UIKit pan: during the drag only the preview moves and data stays untouched; on release the target index is computed from displacement / row height and `moveShortlist` is called once. Swipe-to-delete is kept.
- **Tests**: `ShortlistReorderMath` covers the half-row threshold, out-of-bounds clamping, and the destination contract with `moveShortlist`. On-device drag and drop awaits manual acceptance.

### 2026-09-21 — Delete the dead hardcoded default model list `modelPresets` from production code

- **Background**: Since 2026-08-24 the chat picker reads the user-managed `modelShortlist` (persisted locally, `pickerModelPresets` = `modelShortlist.map(asPreset)`), and the settings catalog pulls live from the `/provider` registry (`catalogModelPresets`). The hardcoded default array `modelPresets` in `AppState.swift` had zero references left in production code and was used only by unit tests as a seed fixture.
- **Fix**: Deleted the `modelPresets` array from `AppState.swift` (keeping the `selectedModelIndex` default and all live logic). The test seed moved into a shared fixture `testSeedPresets` in `TestDoubles.swift` (byte-identical to the original array), and `SessionFlowTests.makeState` plus `AIUsageQuotaTests` now call `addModelsToShortlist(testSeedPresets)`.
- **Unit tests**: Deleted 3 obsolete cases testing "default preset list" behavior (`defaultSelectionUsesGemini37Flash` / `defaultPresetsIncludeDeepSeekLocal` / `defaultPresetsExcludeRemovedGPTVariants`); kept 3 aging cases (legacy GLM / GPT / Kimi mappings) with assertions changed from `state.modelPresets[...]` to `state.pickerModelPresets[...]` (bit-for-bit equivalent after seeding). Also fixed the stale test name `grok46ShortName` → `grok47ShortName` in `ModelsTests` (the case body was already 4.7).
- **Impact**: No runtime behavior change; pure dead code + test cleanup. `xcodebuild test` must run serially (shared DerivedData).

### 2026-09-21 — Grok 4.7 model preset upgrade

- xAI released Grok 4.7, handled per the 2026-08-14 4.5→4.6 upgrade precedent: the tail `Grok 4.6` / `xai/grok-4.6` preset is upgraded to `Grok 4.7` / `grok-4.7` (renamed in the `AppState.swift` model list and in `ModelPreset.suggestedShortName` in step, with no canonical legacy mapping added).
- Tests updated in step: `grok-4.6` / `Grok 4.6` in `ModelShortlistTests` / `ModelsTests` / `SessionFlowTests` all changed to 4.7, and targeted `xcodebuild test` passes for the three suites (iOS Simulator).
- Preset order, count, and other model entries are untouched.

### 2026-09-13 — Document archive placement: Markdown Web Preview sub-documents

- **Problem**: `.gitignore` (lines 67–70), the archive index in `docs/README.md`, main PRD §4.3.5, and main RFC §7.5 all point to `docs/archive/2026-06_markdown_web_preview_prd.md` / `_rfc.md`, but the two sub-documents actually still sat at the old paths `docs/Markdown_Web_Preview_PRD.md` / `_RFC.md`. The old paths do not match the ignore rules, so the files were neither tracked nor ignored and hung around untracked at the `docs/` root. The 2026-08 pass only did "merge into the main PRD/RFC + write ignore rules + document the decision"; the file move was never executed, and `docs/archive/` in fact did not contain these two files.
- **Fix**: Moved the two files to the archive paths the docs specify with zero content changes (mtime still 2026-06-14). After placement `git status` is clean and all the references above point to files that actually exist.
- **Implication**: Both files remain untracked + gitignored per the established policy and are **not distributed with the repo**. The canonical decision lives in main PRD §4.3.5 / main RFC §7.5, and the decision history is in this file's 2026-06-14 entry.

### 2026-09-12 — LLM throughput display (per-message footnote + Context sheet)

- **Motivation**: Wanted to see the real generation rate while the LLM works ("y tokens per x seconds"). Confirmed by measurement on the live server (4096): every assistant message (= one LLM step) already carries `time.created` / `time.completed` / `tokens`. Computable purely client-side with zero server changes. ~~Adjacent steps were 1–3ms apart and per-step time tracked output token count rather than tool count, suggesting the window was clean LLM generation time (tool execution falls between steps and is not counted)~~ → **That judgment was falsified on 2026-09-13, see the correction section below**.
- **Definition**: The denominator is the step's wall-clock time (`completed - created`, including prefill + generation + **tool execution**); the numerator is `output + reasoning` (tokens the model actually emitted, excluding input/prefill and also cache read/write). No number is produced when `completed` is nil (still generating), the window is 0, or tokens are 0.
- **Implementation**:
  - `Message.generatedTokens` / `Message.throughput` / `Message.throughputLabel` (`Models/Message.swift`): core computation; label "rounded at ≥10, one decimal below 10".
  - Footer on every assistant message (`MessageRowView`): appends ` | X t/s` after `provider/model`; while generating, only the model is shown (no completed timestamp).
  - New Throughput section at the top of the Context sheet (`ContextUsageView`): session-level average rate (total tokens / total LLM time), generated token count (output+reasoning), and total generation time.
  - 5 new L10n keys (en/zh).
- **Tests**: 12 new unit tests, all passing: 10 in `MessageThroughputTests` (basic / with reasoning / nil while generating / nil for zero window / nil without tokens / nil when the tokens field is missing / nil for negative window / integer label / decimal label / nil label) + 2 in `ContextUsageThroughputTests` (session aggregation excludes in-progress / nil when there is no completed step); full unit test regression 427/427 (signed build).
- **Review**: A GLM-5.3 subagent's first review was approve-with-nits with no correctness issues; two points were tightened per the review: the throughput number formatting was extracted into a single implementation, `Message.throughputText` (shared by footer and sheet to avoid drift), and the sheet's "Output tokens" label changed to "Generated tokens" (since the definition is output+reasoning, avoiding confusion with the Output row in the Tokens section).
- **SSE extension: best-effort decoding (added 2026-09-12, narrowed to decoding-only on 2026-09-13)**:
  - Background: a single general throughput mixes prefill and decode together (the denominator `created→completed` includes prefill). The goal was to split out a pure generation rate.
  - Data source: the server **does not persist first-token time** (`message-updater` writes only `created`/`completed`), so pure decode cannot be computed for historical messages; but the live SSE stream carries per-token `message.part.delta` (`field`/`messageID`, no server timestamps) and `message.part.updated` (part creation/finalization, with step-finish carrying `tokens.output`).
  - **Best-effort definition**: only "was SSE observed" matters. If observed, decoding is shown; if not (browsing history / restart / pure REST load), it is not, and the footer keeps only general.
  - **Clock**: everything uses client receive time (firstVisible = arrival of the first visible token, lastVisible = arrival of the last visible token) to avoid server/client clock skew (SSH remote scenario). decoding = `tokens.output` / (lastVisible - firstVisible); the numerator counts output only, prefill and reasoning both fall before the window and are excluded, and tool execution falls after the window and is excluded. The step-finish arrival time does **not** participate in the window (it arrives only after tools finish) and only supplies `tokens.output`; when only one visible token is observed (window width 0), no number is produced rather than inventing one.
  - Implementation: `MessageStore.StepTiming` (per assistant messageID, `firstVisibleAt`/`lastVisibleAt`/`outputTokens` + `decode`/`decodeLabel`); `handleSSEEvent` gains a `message.part.delta` case, `message.updated` creates the step entry, and `message.part.updated` collects deltas and step-finish; `stepTimings` is **not** cleared by `resetStreaming()` (that fires on every message update, including this step's own), and is instead cleared on session-scoped clears (`clearCurrentSessionViewState` / `removeTimings(forSession:)`). Footer (`MessageRowView`): `provider/model | <general> t/s | <decode> t/s decoding`, where the last segment appears only when SSE was observed.
  - **TTFT removed (2026-09-13)**: the original design put `TTFT: 3.2s` in the footer (firstVisible - stepStart). On a real run this line almost never appeared (the window between the client seeing assistant `message.updated` and the first token arriving is unreliable, and it does not affect the "real generation rate" users wanted), so it was deleted under the "keep nothing useless" rule: `StepTiming` dropped `stepStart` / `ttft` / `ttftLabel`, the footer dropped the segment, and the related unit tests were removed with it. `recordStepStart` stays, repurposed to "mark that this step was observed from the start", still a precondition for the decoding window.
  - Tests: three SessionFlow tests (SSE stream capture: reasoning deltas do not enter the visible window, tool-input deltas establish the window and step-finish does not move the window's right end, non-current sessions are ignored) + `StepTimingTests` (decode computation and label, nil boundaries for window ends / zero width / missing tokens).
  - **Known limits**: decoding is valid only within the current app session, for the step where the stream was observed; after a restart or for pure history it falls back to general only. Historical pure-decode reconstruction would require patching the server to add a first-token timestamp to assistant messages and persist it.
- **Known limits**: ~~tool time is out of scope for now (the user explicitly is not interested); live SSE carries tool timestamps, but the persisted-history V1 message list does not store tool `time`, so tool time cannot be reconstructed for history~~ → **Corrected 2026-09-13: tool part `state.time` does exist in the persisted payload (the full local DB, 20k+ tool parts, all have start/end), and it must be subtracted from the denominator, see the correction section below**.
- **Merged**: PR #165 (branch `feat/llm-throughput`).

#### 2026-09-13 correction: tool execution time falls inside the step window and must be subtracted from the denominator

- **Trigger**: a real run produced "the LLM emitted a very large write tool call, yet throughput was extremely low".
- **Conclusion: the numerator is fine; tool call tokens were being counted all along.** `output` = provider output tokens − reasoning, and the JSON arguments the model generates for a tool call count as output tokens. Cross-checked against the local OpenCode DB (`~/.local/share/opencode/opencode.db`): of 910 tool parts, 901 have a step whose `tokens.output` matches the tool input volume (the other 9 are `shell`/synthetic paths where output is always 0); the largest write sample had 5426 characters of input corresponding to 2748 output tokens. So "tool tokens were not counted" was a misdiagnosis.
- **Real cause**: the denominator `created → completed` **includes tool execution time**. Both server paths behave this way: the legacy processor executes tools inside the stream and writes `completed` only after tools finish; the V2 runner awaits `awaitToolFibers` before emitting `SessionEvent.Step.Ended`. Measured evidence: `msg_085d6384a001`'s bash tool ran 417,204ms with a step window of 419,309ms and 63 output tokens → displayed 0.1 t/s; `msg_dbd74d5d0001`'s write tool ran 48,345ms with a step window of 56,157ms and 529 tokens → displayed 9.4 t/s (67.7 t/s once tool time is removed).
- **Fix (client-side, still zero server changes)**:
  - `PartStateBridge` parses `state.time.start/end`; `Part.toolRunSeconds` / `MessageWithParts.toolRunSeconds` aggregate it; `Message.throughputExcludingToolSeconds` = `generatedTokens / (stepSeconds - toolRunSeconds)` (falls back to the original window when tool time ≥ the window, so the denominator never goes negative).
  - The general numbers in the footer and the Context sheet both switch to the tool-subtracted definition; the sheet's session average subtracts tool time per step as well.
  - The right endpoint of the SSE decoding window changed from "step-finish part arrival" to "arrival of the last visible delta" (step-finish arrives only after tools complete, so ending the window there would add tool time back into decode); tool-input deltas also count as visible tokens, so a step that emits only a tool call with no body still gets a decoding rate instead of only a general rate polluted by tool time.
  - `StepTiming.firstTextAt` renamed to `firstVisibleAt`, with `lastVisibleAt` added; the TTFT-related fields (`stepStart`/`ttft`/`ttftLabel`) were then deleted, see the section above.
- **Remaining limits**: the persisted definition still includes prefill (historical data cannot recover first-token time), and only steps observed over SSE can yield a pure decode rate; the Context sheet's session average covers only currently loaded messages (history beyond pagination is not counted); when tool time is missing (running, old payloads) it falls back to the original window.
- **Tests**: `MessageThroughputTests` +3 (tool subtracted / fallback when tool time exceeds the window / nil while running), new `MessageToolTimingTests` with 3 cases (state.time aggregation, missing timing counts as 0, running with no end not counted), `ContextUsageThroughputTests` +1 (aggregation subtracts tool), `StepTimingTests` +2 (decode ends at lastVisibleAt, tool-only step has a window), `AppStateFlowTests` +1 plus a rewrite of 1 existing case (tool-input deltas establish the window, step-finish does not move the window's right end). **All 29 tests across the 5 focused suites pass** (Xcode 27 beta + iOS 27.0 simulator, `test-without-building`).
- **Test environment pitfall**: `/Applications/Xcode.app` (26.6) was missing the iOS platform component, making every iOS simulator destination unusable; Xcode 27 beta could run, but `AIUsageQuotaTests.swift` was incompatible with the beta's default isolation (an actor cannot conform to a protocol inferred as global-actor-isolated), so the file was temporarily moved out for the test run and restored afterwards, with no content changes.

### 2026-09-10 — iPhone file preview closes with an edge swipe from the left edge

- In compact-width Chat, the docked `ChatInlineFilePreview` opened by tapping a file tool call can be closed with the standard iOS back gesture in addition to the toolbar `xmark`: start at the screen's physical left edge and drag right far enough.
- The geometry is shared with the session list open gesture via `EdgeSwipeGeometry` (left edge 32pt, horizontal ≥ 72pt, vertical drift ≤ 56pt), with two entry points, `FilePreviewEdgeSwipeBehavior` / `SessionListEdgeSwipeBehavior`; the regular/iPad middle-column preview does not enable it.
- The gesture strip overlays the preview content area (it does not cover the navigation bar xmark or the bottom composer); the strip itself uses `.ignoresSafeArea(.container, edges: .horizontal)`, intended so that in landscape the gesture also starts at the physical left edge on the notch side rather than at the content edge after safe-area insets. Confirmed on device in portrait; landscape is unverified, and if it fails there the fallback is to add a flexible leading frame before the ignoresSafeArea.
- The Markdown Web Preview's `WKWebView` swallows hit-testing for a SwiftUI `Color.clear` overlay, so the left-edge `DragGesture` never receives began. The close strip became a UIKit `UIView` that claims the left 32pt, logging `FilePreviewSwipe` (appear / touchBegan / began / changed / ended+decision / xmark). The close direction is **a rightward swipe from the left edge**; a leftward swipe logs `swipedWrongDirection`.
- On-device log: `touchBegan x=7` was already inside the 32pt strip, but the `UIPanGestureRecognizer`'s `.began` fired only after the finger had moved right to `startX=73`; using that point for the edge test yields `startTooFarFromEdge`. The fix uses the touch-down coordinate as the origin and computes displacement as the current point minus the touch-down point.
- Cost: the leftmost ~32pt is reserved for the close gesture, so horizontal code scrolling / image panning starting inside that strip is unreachable. This is intentional.
- Tests: `FilePreviewEdgeSwipeBehaviorTests` (valid right swipe, non-left-edge start, excessive vertical drift, too-short horizontal distance, wrong-direction left swipe decision).

### 2026-09-07 — SSH keys fail-closed (issue #161)

- **Background**: issue #161 reported that the device Ed25519 key pair could be silently regenerated: a transient Keychain read failure for the private key (`errSecInteractionNotAllowed` while the device is locked) made `ensureKeyPair()` fail-open, burning the old identity and overwriting the public key cache, which invalidated the server-side authorized_keys; aggravating factors included `KeychainHelper` not setting `kSecAttrAccessible` (default WhenUnlocked), save/load ignoring OSStatus, and connect and view hot paths calling a function that can generate keys.
- **Fix (read/create separation)**: added a read-only `getKeyPair()` that never generates: it first derives the public key from the private key to verify cache consistency (repairing the cache from the private key on mismatch), throws the new error `SSHError.keyUnavailable` when the Keychain is temporarily unreadable, and throws `.keyNotFound` when the private key truly does not exist. `ensureKeyPair()` was narrowed to bootstrap-only use: it generates only when the Keychain returns `errSecItemNotFound` (the entry is genuinely missing), throws `.keyUnavailable` on any other error, and never touches existing keys. `rotateKey()` keeps generation permission (explicitly user-triggered).
- **Call site rewrites**: `connect()`'s `_ = try? ensureKeyPair()` became an explicit do/catch that propagates; on key errors it disconnects and enters `.error` (fail closed). On the view side, `generateOrGetPublicKey()` was renamed `readPublicKey()` and now goes through `getKeyPair()` (Settings onAppear prefetch, the public key sheet, and three Copy public key spots); transient failures reuse the existing error UI prompting to unlock the device.
- **Keychain hardening**: Keychain entries now uniformly set `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (the private key shares the write path with passwords/tokens; readable while locked after first unlock, which supports background connections after reboot, and it does not migrate via iCloud Keychain); `KeychainHelper.save/load/delete` all propagate OSStatus, and `loadData` returns nil only on `errSecItemNotFound` (distinguishing "does not exist" from "read failed"); `save` became update-then-add and writes the UserDefaults public key cache only after the private key write verifies.
- **Rotate hardening (added after review)**: `rotateKey()` no longer deletes before generating; it generates the new key first and overwrites in place with update-then-add `savePrivateKey`, updating the public key cache only after the save succeeds, so a failed save leaves the old identity intact. Errors from the Settings Rotate callback now surface to the user via `publicKeyLoadError` instead of being silently swallowed.
- **Test isolation**: `SSHKeyManagerTests` is annotated `@Suite(.serialized)` (consistent with `HostProfileTests` in the same file) to avoid flakes from multiple tests concurrently mutating shared Keychain/UserDefaults state.
- **Verification**: build passes (xcodebuild build with a pinned simulator destination); `SSHKeyManagerTests` targeted run 7/7 pass (2 existing + 5 new: getKeyPair does not mint, bootstrap is idempotent, derivation repairs a stale cache, KeychainHelper update-in-place/delete, hasKeyPair lifecycle); the full 451-test run had 443 pass / 4 fail / 4 skip, with all failures in UI fixture tests (CarMode/AIUsageQuota/SpeechStrategies/ToolCards) that fail identically on a clean baseline, i.e. pre-existing local environment flakes unrelated to this change. Note: running Keychain-related tests on this machine requires removing `CODE_SIGNING_ALLOWED=NO` (an unsigned host app lacks the Keychain entitlement and reports -34018).

### 2026-08-24 — Local model shortlist (PR #149, related #99 / #144)

- The official picker's visibility persists on desktop, and `/provider` plus `/config/providers` are complete catalogs. iOS keeps a shortlist locally: Settings → Models searches and adds from the connected chat-capable catalog, swipe left to delete, left handle to reorder, tap a row to change the toolbar short name.
- The chat bar's Model & Agent renders only this list, in the same order. Both an empty list and "edit in Settings" jump to Settings with Models highlighted.
- Connected custom/local providers (such as `ollama`) appear in the catalog; releases no longer depend on hardcoded presets.
- The Add Models page only handles bulk adds (Cancel / Add). Deletion stays as swipe-left on the shortlist.

### 2026-08-24 — Deterministic messageID + inline send-failure banner (supersedes #89, closes #81)

- **Background**: issue #81 reported that OpenCode 1.15 `prompt_async` failed silently with `SQLITE_CONSTRAINT_NOTNULL` when `messageID` was missing. Upstream fixed that (`input.messageID ?? MessageID.ascending()`; 1.18.16 verified to accept the old payload), but two problems remained: optimistic message reconciliation across the two IDs relied on text/timestamp heuristics, and async failures (the turn dying after the 204) left the UI waiting forever with zero feedback.
- **Cherry-picked PR #89 (guyq1997) and adapted**: `promptAsync` carries `messageID` + a `directory` query; `createSession` gains `directory`; `makeServerID(prefix:)` generates `msg_<uuid>`. Deviations from the original PR: dropped `partID`, since the client does not consume part ids and the `part_` prefix does not match the current server `PartID` schema (which requires `prt`).
- **Deterministic ID reconciliation**: the optimistic row uses the real `msg_` id sent to the server; `loadMessages` dropped text normalization / plugin-prefix hasSuffix / the 60s time window / the `keepPending` busy gate (~34 lines) in favor of pure ID membership reconciliation via `MessageStore.pendingOptimisticMessageIDs`; once the server persists, pending converges automatically, and failed rows keep their text for copy-and-resend.
- **Inline failure banner (no dialog)**: synchronous failures (HTTP throws) keep the optimistic row and add an inline red banner, replacing the old `sendError` dialog path; async failures (SSE `session.error`, previously silently dropped into `default: break`) mark the pending row failed and reconcile via `loadMessages` when they hit the current session, with the reason taken from error.name plus the first non-empty line (truncated to 300 characters). Assistant row-level errors still use the existing inline banner (`errorMessageForDisplay`); the two complement each other without duplicating.
- **End-to-end verification**: measured against a temporary local origin/dev server: payloads with a deterministic messageID persist under the same id the client used; in the no-API-key scenario the server emits `session.error` (`ProviderAuthError`) and the wire shape matches decoding.
- **Tests**: 8 new tests (ID dedup/retention, deterministic ID send, synchronous failure banner, session.error hit / other-session filter / no pending row / undecodable fallback); 3 heuristic-era tests rewritten to ID semantics; the rollback test now uses "keep the row + inline failure" semantics.

### 2026-08-14 — GLM 5.3 + Gemini 3.7 Flash + Grok 4.6 model preset upgrade

- At the top of the model list, the `zai-coding-plan` GLM was upgraded from `GLM-5.2` / `glm-5.2` to `GLM-5.3` / `glm-5.3`. `models.dev` already lists `glm-5.3` for `zai-coding-plan`, so no server-side injection was needed.
- The `ollama-cloud` row `Ollama GLM 5.2` stays unchanged because the `ollama-cloud` upstream does not offer `glm-5.3` yet.
- `canonicalModelPresetID` gained entries mapping both `zai-coding-plan/glm-5.2` and `zai-coding-plan/glm-5.3` to `zai-coding-plan/glm-5.3`, so sessions with GLM-5.2 selected migrate smoothly to the new preset instead of falling back to the default. The existing `glm-5.1` / `glm-5-turbo` legacy mappings now point at `glm-5.3` too.
- The same PR also upgraded the default model `Gemini 3.6 Flash` / `google/gemini-3.6-flash` to `Gemini 3.7 Flash` / `gemini-3.7-flash` (listed on `models.dev`). Following the earlier 3.5 → 3.6 pattern, Gemini gets no canonical legacy mapping; saved `gemini-3.6-flash` values keep the current selection via default logic.
- The tail `Grok 4.5` / `xai/grok-4.5` preset was upgraded to `Grok 4.6` / `grok-4.6` (listed on `models.dev`). `ModelPreset.shortName`'s `Grok 4.5 -> Grok` changed to `Grok 4.6 -> Grok` in step, with no canonical legacy mapping.
- Removed the `GPT-5.6 Sol Fast` preset (`openai/gpt-5.6-sol-fast`) to align with the Android client. `canonicalModelPresetID` maps `openai/gpt-5.6-sol-fast` to `openai/gpt-5.6-sol` so sessions with that model selected migrate smoothly; the `GPT-F` branch in `ModelPreset.shortName` was deleted. The `gpt-5.6-sol-fast` used by the Car Mode internal protocol (`CarModeProtocol.model`) is unrelated to the selector and stays unchanged.

### 2026-07-31 — GPT Live Transcribe host integration

- New installations default to GPT Live Transcribe without overwriting a valid saved strategy. Chat now renders the Kit's accumulated GPT Live snapshots directly in the composer during recording; GPT Realtime remains finalize-only. The Kit dependency now uses exact release `0.4.0`.
- Settings now persists and displays the third `gptLiveTranscribe` strategy in a menu. Both GPT strategies use realtime transport and expose the custom prompt; existing valid saved values remain unchanged.
- Chat and Car snapshot strategy at Start and pass it into strategy-aware Kit sessions. Preserved retries route through the handle's originating strategy, while file retries keep their captured strategy.
- Realtime audio chunks now pass through one bounded ordered sender per capture; Stop/Cancel drains that worker before commit or preservation. Realtime finalization failures retain recoverable audio.
- Chat pending audio is keyed by its originating OpenCode session, and every start/finalization/retry callback is gated by attempt plus session ownership. A session switch now detaches an in-flight finalization without revoking ownership: success persists the completed transcript to the source session draft while leaving the destination composer unchanged, and failure preserves source-owned audio. The navigation snapshot is synchronous so it cannot overwrite a just-completed source transcript; background/explicit cancellation still aborts and preserves. Car uses a generation gate so New Session invalidates old permission, microphone, transcript, and request continuations without carrying old audio into the new session.
- Car retry state now distinguishes transcription retry from OpenCode request retry, so a transcription failure cannot resend the previous `carLastTranscript`.
- Validation: strict Swift 6 standalone runtime checks pass for source/destination draft routing, session-switch detach versus cancellation preservation, and ordered sender order/capacity/drain. Deterministic app tests cover switch-at-finalize completion and destination-draft isolation. The Xcode package reference now pins exact VoiceFlowKit `0.4.0`.

### 2026-07-31 — Markdown Web Preview native MathML

- Web Preview now bundles Temml 0.13.4 and converts `$...$` / `$$...$$` TeX to MathML inside markdown-it before DOMPurify. Parsing preserves escaped dollars, code spans/fences, and ordinary currency.
- DOMPurify no longer combines `ALLOWED_TAGS` with an overriding broad `USE_PROFILES`; the shell now uses one explicit HTML/SVG/MathML allowlist and sanitizes generated MathML in the same pass as the document.
- Headless verification covers inline/display math, `\\xrightarrow`, fractions, invalid TeX fallback, delimiter edge cases, and removal of undeclared profile-only tags. iOS fixtures add light/dark screenshot coverage for the arrow-heavy formula shape.

### 2026-07-30 — Pin VoiceFlowKit 0.3.0

- The SPM dependency changed from a bare revision to exact SemVer `0.3.0` (`Package.resolved` corresponds to merge commit `71b9fe6`).
- iPhone 16 simulator build passes; `SpeechRecognitionDefaultsTests` / `VoiceFlowKitIntegrationTests` / chat speech tests pass.

### 2026-07-29 — OpenAI Realtime / Grok Batch dual recording strategies

- The VoiceFlowKit pin started at `4a04d562965fe041b552570759ef6e419ab3b2d6` and later moved to exact `0.3.0`. Settings persists `OpenAI Realtime` / `Grok Batch`; Grok mode hides the OpenAI-only prompt but keeps its value.
- Chat and Car snapshot the strategy at Start. OpenAI maintains a realtime session, PCM stream, heartbeat, and recovery; Grok only starts local AAC-LC M4A recording, creating no ticket, WebSocket, or heartbeat while recording, with a single upload after Stop.
- Both Chat preserved-audio and Car failed-state retry save the strategy from when the recording was produced; changing Settings after recording does not reinterpret old files. Leaving the active recording page, backgrounding, or cancelling finalization invalidates in-flight Start/finalization/retry generations, which prevents delayed permission/session/microphone or transcript callbacks from resuming hidden recordings or writing back stale results, and cleans up temp files and the realtime session.
- VoiceFlowKit was fixed in step for the AAC/WAV finalize-error writer, buffer, temp file, and audio session cleanup; 12 package tests pass.
- Verification: iPhone 16 / iOS 18.4 build passes; 6 targeted tests pass across the new strategy persistence/transport contract and VoiceFlowKit integration; Tool Cards UI passes on isolated rerun. Voice-related tests in the full suite pass, but it still reports the pre-existing `LayoutConstantsTests.splitViewFractions` exact `CGFloat` comparison failure; the Tool Cards fixture failed its first run in the same round and passed on isolated rerun.

### 2026-07-24 — Chat text selection across Markdown blocks

- The root cause was pinned to MarkdownUI's `BlockSequence`: one Markdown message splits into multiple SwiftUI block views, and iOS `.textSelection(.enabled)` only works within a single selectable view, so selection cannot extend across paragraphs, lists, and code blocks. Chat does not use WKWebView, and this was not a streaming DOM diff problem either.
- The existing MarkdownUI reading render is kept to avoid regressing workspace images, tables, code blocks, and links; user/assistant message menus gain "Select text" and "Copy entire message".
- `Edit from here` shows only on user messages; `Fork from here` continues to support both user and assistant messages, forking from any turn.
- "Select text" uses a single read-only `UITextView` sheet that strips Markdown inline markers line by line, preserves the original line breaks of paragraphs, lists, and code blocks, and then supports native iOS drag selection across lines and paragraphs; "Copy entire message" copies the full raw text directly.
- Added a multi-text-part concatenation test ensuring multiple text parts of one message join with blank lines and are no longer affected by Markdown block boundaries.
- Verification: iPhone 16 / iOS 18.4 build passes; 7 targeted `MessageRenderingHeuristicTests` tests pass.

### 2026-07-19 — Health Quantification client capability

- Car Mode actions became a tolerant typed union, keeping Maps and adding `health_quantification.export_all`; unknown future actions no longer fail the whole structured speech decode.
- First use shows a local authorization sheet with allow-once, always-allow, and cancel; Settings can revoke the Health export authorization.
- OpenCode writes a 15-minute Pending before opening the Health App; a legitimate callback atomically converges into the 6-hour Outbox. Duplicate, expired, or corrupted callbacks never produce a second continuation.
- Callbacks are validated locally first, with no dependency on the server connection; continuations use the recorded Host, Car context, and session, plus deterministic message IDs + query-before-retry, and never read the current Chat selection.
- The formal product, implementation, and wire contract live in `docs/features/client_capabilities/prd.md`, `docs/features/client_capabilities/rfc.md`, and `docs/features/client_capabilities/protocol.md` respectively; the canonical agent entry point is `skills/client_capabilities.md`.
- Verification covers the strict parser, the canonical handoff URL, store lifecycle, allow-once, original-session continuation, callback stop semantics, and the permission fixture UI. Sequential build and full test pass on the pinned iPhone simulator `302F88CA-C2D3-4DC0-8E12-B3ED82D5A3C8`; 352 Swift Testing tests and 37 UI tests pass, with 4 opt-in UI tests skipped as expected.
- After on-device E2E acceptance, two UX points were tightened: the authorization page's three short buttons became equal-width in a row, wrapping English to at most two lines inside a button; a callback continuation enters Car Mode's existing `waitingReply` with a red "stop responding" primary button, and cancelling both aborts the session and deletes the matching Outbox, avoiding a background-committed request that looks like nothing happened in the foreground.

### 2026-07-15 — Session deep link and Agent search links

- Registered `opencode://session/<session_id>` with a strict URI parser that rejects unknown hosts, query, fragment, userinfo, port, invalid IDs, and multi-segment paths.
- Cold/warm URLs share the AppState router with Chat Markdown taps; after the connection recovers the URL is verified against the current Host via `GET /session/:id`, switching project/session on success and keeping the original context on failure.
- Backgrounding and Host switches invalidate old resolve generations, preventing lost links before an SSH reconnect or a stale Host response polluting the new Host.
- Session list refreshes keep the currently verified session so a historical target outside the 100-entry window is not overwritten; the Files tree reloads using the target project directory.
- Added parser/state tests, a Markdown tap fixture, and a cold pending fixture; also pinned the portrait precondition of UI suites to remove cross-test pollution from orientations left behind by launch tests.
- Product behavior and the technical contract were merged into main PRD §4.2.7 and RFC §4.4 respectively. The workspace private semantic-search overlay now specifies the candidate evidence and `[Open in OpenCode](opencode://session/<id>)` output contract.

### 2026-07-15 — Car session active restore and doc consolidation

- Before sending each Car turn the client checks the persisted session; if `time.archived > 0`, it writes the legacy restore sentinel `-1` and keeps using the original session. This behavior does not fork, does not copy history, and requires no archive-list server patch.
- iOS distinguishes Active / Archived by `archived > 0`, so a restored session reappears in the iOS Active list. The OpenCode Web difference (it only accepts `archived === undefined`) is not covered by this feature's guarantee.
- Car Mode product requirements merged into `OpenCode_iOS_Client_PRD.md`, with the technical contract and verification evidence merged into `OpenCode_iOS_Client_RFC.md`; the standalone `car_mode_design.md` was deleted to keep three documents from drifting apart.

### 2026-07-14 — Car Mode implementation and server history fix

- Settings gained an Experimental Features section holding the AI Usage Dashboard configuration and the Car Mode toggle. Car Mode defaults to off; when on, the iPhone tab order is Chat / Files / Car / Settings, and the Car tab is hidden when off. iPad (including compact windows) and Apple Vision Pro show neither Car Mode nor the toggle.
- Car sessions are isolated by host UUID + workspace and do not reuse normal Chat's `currentSessionID`; persisted state covers session ID, the last processed assistant message ID, and pending confirmation.
- Added a synchronous structured prompt API pinned to `openai/gpt-5.6-sol-fast` + `build`; the client consumes only schema-validated `assistant.structured`.
- Apple TTS now explicitly uses `.playback` + `.spokenAudio` and closes the recording audio session before speaking, fixing the case where the UI showed speech while audio could remain on the receiver/Bluetooth HFP route.
- The client action allowlist contains only `open_navigation`; iOS validates the typed destination/waypoints and then constructs the Apple Maps URL.
- Normal Chat shows `assistant.structured.speech` when a structured assistant message has no text part, with a new UI fixture verifying Car history visibility.
- Nested server commit `43a4a0e53` fixes the `info.format` wire schema for structured user messages; targeted schema/opencode tests and typecheck pass.
- The live 4096 server was verified to read the target Car session's full structured history; 14 messages and 3 structured assistant entries all survive.
- Verification: pinned iPhone simulator `302F88CA-C2D3-4DC0-8E12-B3ED82D5A3C8` with `-parallel-testing-enabled NO`; 327 unit tests, three iPhone Car UI tests, one iPad absence test, and the visionOS simulator build all pass. The iPad test also confirms both the Car page and the Settings toggle are absent.
- On device, TTS was confirmed audible and live structured Car history is readable. The Smart Home, email, iMessage, and route-duration skills remain unproductized without real E2E.

### 2026-07-13 — Car Mode feasibility and design

- Completed the Car Mode feasibility design, converging the driving voice entry into a standalone mode inside OpenCode iOS; conclusions are now folded into the main PRD/RFC.
- Verified against the live OpenCode API: `system + format(json_schema)` can return `assistant.structured`; a second turn in the same session can reuse the previous turn's destination; a structured final can still be returned after tool execution.
- Found a production blocker: once a structured user message persists `format`, the message list endpoint raises an `OutputFormatJsonSchema` BadRequest validating `info.format` on output. The synchronous `/message` path is enough for a UI/TTS spike, but the server schema must be fixed before history restore, Chat viewing, and async exactly-once handling.
- The live `skill` tool does not currently have the workspace's Smart Home, email, iMessage, and maps skills registered; productization needs a formally registered Car allowlist or typed tools, since generic `read + bash` cannot serve as a stable permission boundary.
- Product boundary: no promise of continued background interaction after switching to Maps or another app, but the host/workspace-isolated Car session ID is kept, and returning appends to the same session.

### 2026-06-18 — Image attachments Phase 1/2

- Scope converged per this round's decision to the first two phases: sending photo-library images + rendering historical image/file parts; no Files app integration, no PDF/text attachments, no server-side upload.
- Protocol: `Part` gains `mime` / `filename` / `url` / `source`; `APIClient.promptAsync` supports mixed text/file parts, with images using the web-isomorphic `data:image/jpeg;base64,...`.
- Composer: added a `PhotosPicker` attachment button and a horizontal thumbnail strip; selected images are converted to JPEG locally, longest edge 2048, quality 0.82, 5MB cap per compressed image; on send failure the text and attachments are restored.
- Optimistic UI: `appendOptimisticUserMessage` can produce text + file parts, so the user sees image attachments immediately after sending.
- Rendering: `MessageRowView` has display paths for `type == "file"` on both user/assistant; image parts show a thumbnail that opens `ImageView` zoom/pan on tap, and non-images show a fallback file card.
- Tests: added `filePartDecoding`, `appendOptimisticUserMessageIncludesImageAttachmentPart`, `sendMessagePassesImageAttachmentsToAPI`.
- Verification: `xcodebuild test -project "OpenCodeClient.xcodeproj" -scheme "OpenCodeClient" -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'` passes.

### 2026-06-18 — Message revert / Edit from here MVP

- The goal converged to a minimal viable version: only user-message `Edit from here`, no restore dock, no `unrevert` UI, no part-level revert.
- Data protocol: `Session` gains `revert` decoding; `APIClient` adds `POST /session/:id/revert`, handling the `Session` the current server returns.
- UI: the user message `⋯` menu gains `Edit from here`, disabled for a busy session to avoid revert failing while the server is busy.
- State flow: tapping calls `AppState.editFromMessage`; on success the original user text parts are written back to the composer draft, the returned session is upserted, and messages / diff / file status refresh.
- Rendering semantics: `ChatTabView` uses `AppState.visibleMessages`, hiding history rows with `message.id >= revert.messageID` when `currentSession.revert.messageID` exists, matching the Web rewind view.
- Tests: added `sessionDecodingWithRevert`, `visibleMessagesHidesRowsAtAndAfterRevertMessageID`, `editFromMessageCallsRevertAndStoresDraft`, `editFromMessageKeepsDraftUnchangedOnFailure`.
- Verification: `xcodebuild test -project "OpenCodeClient.xcodeproj" -scheme "OpenCodeClient" -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'` passes.

### 2026-06-14 — Markdown Web Preview device acceptance and closeout

- **Phase 0/1/2 fully complete and shipped** (see the earlier Markdown Web Preview section); `xcodebuild test` passes in full serial run (291 + 11 new = 302 passed, no regressions).
- **The default preview mode became Web** (PRD §5.1 / RFC §8.2 updated in step).
- **Chip contrast problems exposed by device dark-mode acceptance**: `<style>` cards with hardcoded light backgrounds washed out in dark mode; the shell's dark semantic variables switched to saturated primary colors (`--ok-bg=#10b981` etc., like GitHub dark issue labels); chips use the compound selector `.vx-chip.ok` instead of bare `.ok` to avoid being overridden by the card's `color:var(--fg)`.
- **Stale WebView content when switching files**: the root cause is that `.onAppear` fires only once when SwiftUI reuses the same `FileContentView` instance; the fix is `.onChange(of: filePath)` actively resetting content + reloading (`.id(filePath)` was tried but rebuilds the entire view, inelegant, and was reverted).
- **New regression tests**: the `semantic_chips.md` fixture + `testSemanticChipsDarkVisible / Light` UI tests, whose sentinel text assertions guard the two real bugs "dark chips wash out" and "bare `.ok` gets overridden".
- **Major internal-writing skill upgrade**:
  - "CSS colors use theme variables + fallback" (replacing the vaguer "theme safe")
  - "Semantic classes must use compound selectors" (specificity pitfall caught by dogfooding)
  - "**The real metric is the rate of introducing new concepts, not the word count**" (the fundamental framing of low cognitive burden)
  - "Writing status cards like encyclopedia entries" is now listed as an anti-pattern, with the boundaries of cards/tables/`<details>` clarified
- **Doc merge**: the final decision states of `Markdown_Web_Preview_PRD.md` / `Markdown_Web_Preview_RFC.md` merged into main PRD §4.3.5 / main RFC §7.5 (as visual tables + `<details>`, itself dogfooding). The two sub-documents stay on disk but were untracked with `git rm --cached` and added to `.gitignore`; the decision history is in this WORKING.md (for the archive placement date see the 2026-09-13 entry).

### 2026-06-20 — Ollama Cloud GLM 5.2 model preset

- In the model list, `Ollama Kimi K2.6` (`ollama-cloud/kimi-k2.6`) is replaced by `Ollama GLM 5.2` (`ollama-cloud/glm-5.2`). The OpenCode server's `ollama-cloud` provider registry had a `glm-5.2` entry injected via the `INJECTIONS` in `scripts/regen_models_local.py` (see `opencode-official/skills/update_models.md`); the model key is `glm-5.2`.
- `ModelPreset.shortName` changed from `Ollama Kimi K2.6 -> Kimi` to `Ollama GLM 5.2 -> OGLM-5.2` (the O prefix plus version distinguishes it from the top `GLM-5.2` preset's shortName), keeping the narrow-screen model chip short.
- `canonicalModelPresetID` gained `ollama-cloud/kimi-k2.6 -> ollama-cloud/glm-5.2` so sessions that had Kimi selected migrate smoothly to the new preset instead of falling back to the default.

### 2026-06-10 — Ollama Cloud Kimi model preset

- In the model list, `MiniMax M3` (`ollama-cloud/minimax-m3`) is replaced by `Ollama Kimi K2.6` (`ollama-cloud/kimi-k2.6`). The model key exposed by the OpenCode server's `ollama-cloud` provider registry is `kimi-k2.6`; passing the Ollama library tag `kimi-k2.6:cloud` directly makes `prompt_async` return 204 while no assistant message is generated in the background.
- `ModelPreset.shortName` gained `Ollama Kimi K2.6 -> Kimi`, keeping the narrow-screen model chip short.

### 2026-06-08 — F3 voice rail composer

- The Chat composer converged from "a microphone attached inside the input field" to `voice rail + text review field`: the voice rail carries recording transport, the real waveform, transcription waiting, stop-wait, and preserved-audio retry; the text field carries transcript review, corrections, fallback typing, and a fixed send.
- Agent running was demoted to a quiet status row near the composer, and `Interrupt agent` moved into the `⋯` menu, keeping low-frequency destructive actions out of the main voice-steer path.
- While recording, the waveform uses the real mic level from `VoiceFlowMicrophone.audioLevel`; `VoiceFlowMicrophone` is rebuilt before each new recording so the audioLevel stream does not stop producing after the second recording.
- Transcription waiting keeps an explicit exit, `Stop transcription wait`, which calls abort-preserving-audio; in the preserved-audio state the left icon button handles `Retry this segment` and the right lightweight action handles `Discard audio`, avoiding two retry entrances and giving the post-retry-failure state a clear exit.
- When a partial transcript from speech transcription or a preserved-audio retry is written into the text review field, it auto-scrolls to the end so the user can keep seeing the latest transcription; ordinary manual input and draft restoration do not force scrolling.
- Added `UITEST_F3_TRANSCRIBING_FIXTURE` / `UITEST_F3_RETRY_FIXTURE` with matching UI tests covering the two key states: transcribing + agent running, and preserved-audio retry.

### 2026-06-08 — Chat history load-more diagnostics

- After comparing with Android, fixed iOS message part `files` decoding compatibility: old history can contain `files: ["path"]` or objects missing `additions/deletions`; Android already tolerated these, iOS previously required the full object, and after raising the message limit it could silently drop old records.
- `loadMessages` / `loadOlderMessagesForCurrentSession` gained logging for limit, returned count, whether history grew, and fallback decoder dropped records, making it easier to reproduce "pull to load older finished but history did not grow".
- Device logs further confirmed: the chat history limit was already raised from 20 to 40/60, but the message request was being cancelled; meanwhile the session list's bottom `onAppear` auto-pagination loaded continuously from 6500 to 8000 on archived-heavy data. The session list's automatic sentinel became an explicit "Load more sessions" button, preventing the collapsed archived region from triggering endless pagination and starving chat history requests.
- A second log round confirmed session auto-pagination had stopped, but SSE `session.updated` still repeatedly replaced the same busy session at high frequency, along with the SwiftUI "Modifying state during view update" warning. `Session` / `SessionStatus` became `Equatable` to skip no-op upserts/status writes; `loadOlderMessagesForCurrentSession` moved the actual `loadMessages()` into an unstructured main-actor task so `.refreshable` cancellation no longer directly cancels the history message network request.
- A third on-device log round verified: with `requestedLimit=40/60` the responses returned `returned=40/60` respectively, and history message count rose from 20 to 40/60. Added a regression test covering identical `session.updated` payloads not triggering session list changes.

### 2026-05-30 — Speech abort/retry

- The VoiceFlowKit pin updated to merged revision `dbbe297ea52e3a3438d227a54001b23c138c47b7`.
- The Chat composer gained an auxiliary button on the left: during recording/transcription it shows stop, calling `abortPreservingAudio()` to release the UI immediately; once audio is preserved it shows retry, calling `transcribe(preservedAudio:)` to re-transcribe the previous PCM segment.
- `cancel()` semantics are unchanged; only the explicit abort path preserves audio. The send button is still gated by `isRecording/isTranscribing/isRetryingSpeech` to avoid concurrent writes to input.

## Default Workflow Conventions

### Default meaning of "build with the latest code"

In this project, that phrase by default does **not** mean compiling the latest remote code in place directly.

The default meaning is:

1. Enter `adhoc_jobs/opencode_ios_client/opencode-official`
2. `fetch origin` to get the latest `origin/dev`
3. Rebase the current local integration branch onto the latest `origin/dev` while **keeping the current local commits**
4. Build, test, and deploy the iOS client / server integration environment from the rebased server code

The convention exists to pin down one working semantic: **latest code = latest upstream `origin/dev` + the current local patch stack**.

"Local commits" here refers strictly to commits **already committed** on the current branch that have not yet been integrated on top of the latest `origin/dev`; **it excludes** uncommitted changes in the working tree.

Only when the request explicitly says "no local commits, build pure upstream latest code" does the rebase get skipped and work proceed directly from a clean `origin/dev`.

### Why this convention

- The currently verifiable mainline of `opencode-official` is `dev` / `origin/dev`, not `master`
- Local usually carries a set of not-yet-upstreamed patches; building pure upstream directly would drop those behavior differences
- Rebasing before building surfaces conflicts between upstream changes and local patches earlier instead of leaving the problem for later

### Execution boundaries

- This is an integration workflow that **preserves local commits**, not a "hard reset to the remote"
- If the rebase hits conflicts or fails, pause by default and confirm how to proceed before entering the build/deploy stage
- Read-only research, API comparison, or regression triage does not trigger this workflow by default

### Success criteria

- The success criteria are more than "the build produced a binary"; the **executed path must be correct** too
- When OpenCode starts under `knowledge_working`, the binary being executed must be the latest one produced by this workflow, not an older binary left over on disk
- For this workflow, closed-loop verification completes only when a command like the one below actually launches the binary just obtained from rebase + build:

```bash
OPENCODE_DB_PATH="$HOME/.local/share/opencode/opencode.db" \
OPENCODE_SERVER_PASSWORD="restart_Web@" \
/Users/grapeot/co/knowledge_working/adhoc_jobs/opencode_ios_client/opencode-official/packages/opencode/dist/opencode-darwin-arm64/bin/opencode web --hostname 0.0.0.0
```

- If that command still points at old build output, or it cannot be proven to correspond to the new binary from this round's rebase, then this "build with the latest code" run does not count as complete

### Runtime verification boundaries

- If the user is actively using OpenCode right now, especially with a server already serving on port `4096`, do **not** kill, restart, or take over that live process to verify a new binary
- In that scenario, runtime verification steps that would disturb current usage are skipped by default
- If runtime verification is still needed, do it with a separate temporary process/port, managing only the verification process you started and never touching the user's existing `4096` process

## In Progress

None. Markdown Web Preview Phase 0/1/2 has been delivered; see "Completed" below for the records.

### Markdown Web Preview (started 2026-06-14, delivered)

> Design in `docs/archive/2026-06_markdown_web_preview_prd.md` / `docs/archive/2026-06_markdown_web_preview_rfc.md`. This round delivered Phase 0/1/2.
> Decisions: images go through data URIs reusing `MarkdownImageResolver`; Web is not the default mode; orchestration in RFC §12.5.
> Build/test constraint: `xcodebuild build` and `xcodebuild test` must run serially (shared `build.db`).
> Key files: `OpenCodeClient/OpenCodeClient/Views/FileContentView.swift` (mode switching), `Utils/MarkdownImageResolver.swift` (data URI reuse).

**Parallel prep (sub-agent, merged after main-agent acceptance)** ✅
- [x] Dependency research + frontend shell: markdown-it 14.2.0 + DOMPurify 3.4.10 (CDN-free; dist pulled via npm then copied out); all 5 shell checks pass in jsdom
- [x] Fixture generation: the nine `.md` from §9.1 + `images/chart.png` (a real 6.8KB PNG) + `images/diagram.svg`; large_markdown at 70KB exceeds the 60KB threshold; the security fixture carries 4 payloads + sentinel

**Phase 0 — Spike (serial, main agent)** ✅
- [x] Added `MarkdownWebPreviewView.swift` (a `UIViewRepresentable` wrapping `WKWebView`)
- [x] Bundled `preview.html/css/js` + markdown-it + purify; **pitfall: synchronized folders flatten subdirectories**, so vendor sits next to the html and src drops the `vendor/` prefix; `loadFileURL(allowingReadAccessTo: bundleDir)`
- [x] `window.renderMarkdown(payload)` entry point; Swift injects via JSONSerialization through `evaluateJavaScript` (no string concatenation)
- [x] Rendering + DOMPurify + base CSS + light/dark all done inside the WebView
- [x] Manual simulator acceptance with `html_cards.md` / `dark_theme_cards.md`: cards form correctly and dark mode has no dark-on-dark text
- [x] `xcodebuild build` passes

**Phase 1 — Files MVP (serial, main agent)** ✅
- [x] `FileContentView`'s `showPreview: Bool` became a `MarkdownPreviewMode` enum (`native` / `web` / `source`)
- [x] The toolbar's two-state button became a Picker Menu: `Native Preview` / `Web Preview` / `Markdown Source`
- [x] `contentView(text:)` dispatches by mode; large-file protection kept (native over threshold falls back to source; web over threshold goes through an oversize gate with confirmation first)
- [x] `MarkdownWebPreviewContainer` reuses `MarkdownImageResolver.resolveImages(...)` to produce data-URI markdown before handing it to the WebView
- [x] Three states (loading / render failure / oversize) + one-tap buttons back to Native/Source
- [x] Accessibility identifiers added to the WebView root (`markdown-web-preview-webview`) and mode menu (`markdown-preview-mode-menu`)
- [x] Manual acceptance (simulator screenshots in outputs/web_preview_screenshots/): HTML card / dark / inline SVG / wide table / security filtering pass
- [x] `xcodebuild build` passes
- [x] UITEST_WEB_PREVIEW_FIXTURE + MarkdownWebPreviewUITests (all 5 tests pass, including security sentinel assertions)

**Phase 2 — Security and polish (serial, main agent)** ✅
- [x] DOMPurify allowlist blocks `script`/`iframe`/`form`/`object`/`embed`/`on*`/`javascript:` (shell config + malicious_script fixture UI assertions that the sentinel renders and script does not execute)
- [x] `WKNavigationDelegate` intercepts non-file/fragment navigation + external links to onOpenExternalURL; workspace-relative links resolve through resolveRelativeReference into fileToOpenInFilesTab
- [x] The WebView uses a non-persistent data store
- [x] Theming: input carries colorScheme; updateUIView re-renders on input diff without rebuilding the WebView (the container reads @Environment(\.colorScheme))
- [x] UI tests: mode switching web↔source↔native round trips (UITEST_WEB_PREVIEW_MODE_FIXTURE)
- [x] Unit tests: 8 image/link path preprocessing cases (same directory / subdirectory / ./ / `../` / deep / workspace absolute / external / nil mdPath)
- [x] `xcodebuild build` + `xcodebuild test` pass serially (291 passed, no regressions)

**This round's delivery complete (Phase 0/1/2)**: Web Preview is manually switchable in Files, with HTML cards/dark/
inline SVG/wide table/security filtering/relative links all verified. Screenshots in `outputs/web_preview_screenshots/`.
Not done (left for later): Phase 3 `.html` artifacts / Mermaid / code highlighting / image tap preview;
device (non-simulator) acceptance; custom URL scheme large-image optimization (the follow-up route for open question 1).
Known fixture detail: html_cards' per-status colors are not fully reproduced (cards form but the palette reads neutral);
non-blocking; the fixture CSS selectors or DOMPurify style handling can be tuned later.

- [x] **PR merged** — design-redesign / Web Preview is on master
- [x] **Model list** — no more hardcoded preset table to maintain; moved to the PR #149 shortlist

## Completed (recent)

- [x] **Composer send/stop logic regression fix (2026-05-29)**:
  - [x] Root cause: the Quiet Tech composer rework wrote the primary action as `if state.isBusy { stop } else { send }`, so while the AI ran the send button was replaced by stop and the user had to terminate first to send a new message, breaking the established product behavior of "one send + one stop, send directly while running" (WORKING recorded this early: "restore sending while the AI works: send always visible, stop/abort shown at the same time")
  - [x] Fix: the send button **always renders** (`canSendNow` has no busy check; while busy, text alone is enough to send), and stop became a button that appears **in addition** while busy instead of replacing send; the two **stack vertically** (send on top, stop below, VStack), not side by side
  - [x] Docs: design.md's composer section had described the wrong behavior as "send replaced in place by stop"; corrected to "send always kept, stop additionally present, stacked vertically"; the root was the design doc contradicting product behavior
  - [x] Verification: iPhone build passes
  - **Branch**: `fix-composer-send-while-busy` (off master)

- [x] **Quiet Tech visual design language landed (2026-05-29)**:
  - [x] Background: the "Quiet Tech calm-tech" design spec locked in `docs/design.md` (PR #62) was brought into SwiftUI code, iterating screen by screen against the four mockups in `docs/design_images/` with simulator screenshots until they matched
  - [x] `DesignTokens`: Brand primary → electric blue `#3B82F6`, with gold reserved for "AI working"; surface/composer filled with the spec's dark values. Token **names unchanged** so every View keeps referencing them, avoiding sweeping changes
  - [x] Three-state card language: info cards (tool) keep a neutral surface but **icons/tool name/file path/chevron use electric blue** as the "tappable" cue (neutral card body, accent only on interactive elements); action cards (permission) get a 3pt blue left bar + plain text buttons (dropping the green/blue/red solid buttons); patch cards dropped orange → single blue accent
  - [x] Message area: user messages keep the 3pt blue left bar + muted background (divider above removed, spacing does the separating); AI replies have no container
  - [x] Composer: collapsed into a single pill, mic moved inside on the left (no border), send as a solid blue rounded square on the right (stop replaces it while busy)
  - [x] Toolbar: plain glyphs replace filled circles; the model selector went from a solid blue capsule to an outlined chip
  - [x] Session rows: the selected state's left blue bar is baked into the rounded selection background and clipped inside the corners, so it no longer pokes out or fights the expand chevron
  - [x] Settings: Theme became a segmented control
  - [x] iPad: all three columns expanded by default (`columnVisibility = .all`); the sidebar's file tree defaults to a collapsed disclosure, with the sidebar mainly acting as session picker
  - [x] iPhone tool/patch cards in a two-column grid (information density); three columns on iPad
  - [x] Bug fix: messages now load when a session is restored after restart (`loadSessions` previously only set `currentSessionID`; `selectSession` short-circuited because the id already matched and never pulled messages, so a restart landed on the last session showing blank history until you manually switched away and back)
  - [x] Verification: iPhone 16 Pro + iPad Pro 11" builds clean; screenshots against a local server's real data compared for Chat (empty state + tool/patch/permission cards) / Settings / the iPad three columns
  - **PR**: #63 — feat(design): implement the "Quiet Tech" visual language

- [x] **Realtime speech WebSocket recovery V2 (2026-05-25)**:
  - [x] Product semantics: a WebSocket drop during a long recording does not interrupt the recording; the client recovers from a local PCM cache instead of failing only at Stop
  - [x] Technical approach: every PCM chunk is written to a temp `.pcm` file and to the live WebSocket; a heartbeat / send failure starts a new session and replays from cache offset 0 to the current file end, resuming live sends once caught up; Stop waits for recovery to finish before commit/stop
  - [x] Constraint: v1 accepts replaying from scratch on every disconnect; ten minutes of PCM16 mono 24kHz is about 30MB. Reliability comes first, with checkpoints as a later performance optimization
  - [x] Startup experience: tapping the microphone starts `AVAudioEngine` recording and local PCM cache writes immediately; the AI Builder session POST completes in the background and, once the session is ready, PCM cached during startup is replayed, avoiding a translucent recording button that is not actually capturing while the first network packet waits.

- [x] **Voiceflow-style single app target migration started (2026-05-02)**:
  - [x] Compared against the Voiceflow configuration in `adhoc_jobs/brainwave_mobile/brainwave_ios` and confirmed it is a single main app target supporting `iphoneos iphonesimulator xros xrsimulator` with `TARGETED_DEVICE_FAMILY = "1,2,7"` and one shared bundle id, rather than a separate visionOS app target
  - [x] The `OpenCodeClient` main target now supports iPhone / iPad / Apple Vision: added `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator xros xrsimulator"`, `TARGETED_DEVICE_FAMILY = "1,2,7"`, `XROS_DEPLOYMENT_TARGET = 26.0`, `SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO`
  - [x] Initially wired `OpenCodeClientVisionAssets.xcassets` into the main target's resources so the main target's visionOS build could reuse the existing layered app icon; after verification passed, work converged further onto the main asset catalog
  - [x] `Citadel` / SSH tunnel dependencies stay in the main target but are limited to iOS-only via build phase `platformFilters = (ios, )`, so native visionOS builds stop pulling in `swift-nio-ssh`; visionOS runtime still uses the existing `#if os(visionOS)` stub and Settings hides SSH Tunnel
  - [x] Verification: `xcodebuild -showdestinations -project "OpenCodeClient.xcodeproj" -scheme "OpenCodeClient"` shows native `platform:visionOS` / `platform:visionOS Simulator` destinations; `xcodebuild build -project "OpenCodeClient.xcodeproj" -scheme "OpenCodeClient" -destination 'platform=visionOS Simulator,id=FBB8C85C-5EC8-40CC-B2CF-DAEC86BA530B' CODE_SIGNING_ALLOWED=NO` passes; `xcodebuild test -project "OpenCodeClient.xcodeproj" -scheme "OpenCodeClient" -destination 'platform=iOS Simulator,id=302F88CA-C2D3-4DC0-8E12-B3ED82D5A3C8' CODE_SIGNING_ALLOWED=NO` passes

- [x] **Old `OpenCodeClientVision` target deleted (2026-05-02)**:
  - [x] Removed the standalone `OpenCodeClientVision` app target, product, build phases, build settings, and shared scheme; the project keeps a single `OpenCodeClient` app target
  - [x] Removed the standalone `OpenCodeClientVisionAssets.xcassets` and moved `AppIcon.solidimagestack` into the main `OpenCodeClient/Assets.xcassets`, so both the iOS flat icon and the visionOS layered icon belong to the same app target's asset catalog
  - [x] README build instructions now describe the single `OpenCodeClient` scheme: iPhone, iPad, and Apple Vision Pro all ship from the same scheme and bundle identifier

- [x] **Preserve partial transcript when speech recognition fails (2026-05-02)**:
  - [x] Root cause: `ChatTabView.toggleRecording()` rolled `inputText` back to the pre-recording `prefix` in the transcription catch path; when the AI Builders realtime WebSocket had already streamed a partial transcript before erroring, text the user had already seen was overwritten, and with an empty prefix the input box appeared to be cleared
  - [x] Fix: added a thread-safe `SpeechPartialTranscriptBuffer` whose partial callback synchronously records the latest transcript each time; on failure the input box is restored with `prefix + lastPartialTranscript`, and without a partial the original prefix behavior holds
  - [x] Tests: added `speechFailureInputPreservesLastPartialTranscript()` and `speechFailureInputFallsBackToPrefixWithoutPartialTranscript()`, covering failure recovery and the no-partial fallback
  - [x] Verification: `xcodebuild test -project "OpenCodeClient.xcodeproj" -scheme "OpenCodeClient" -destination 'platform=iOS Simulator,id=302F88CA-C2D3-4DC0-8E12-B3ED82D5A3C8' CODE_SIGNING_ALLOWED=NO` passes; `xcodebuild build -project "OpenCodeClient.xcodeproj" -scheme "OpenCodeClientVision" -destination 'platform=visionOS Simulator,id=FBB8C85C-5EC8-40CC-B2CF-DAEC86BA530B' CODE_SIGNING_ALLOWED=NO` passes

- [x] **visionOS layered app icon (2026-05-01)**:
  - [x] Generated the visionOS three-layer icon (background / middle / foreground) from the existing `OpenCodeClient/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
  - [x] Layering was ultimately done programmatically from the original image's colors rather than adopting the model's transparent layers directly; the composite preview then matches the original pixel for pixel, avoiding transparent backgrounds painted as checkerboards by the model or colored fringes left by green-screen keying
  - [x] Added `OpenCodeClientVisionAssets.xcassets/AppIcon.solidimagestack`, included only in the `OpenCodeClientVision` target's Resources; the shared `OpenCodeClient/Assets.xcassets` keeps only the iOS `AppIcon`
  - [x] The visionOS app icon catalog uses Xcode's generated `.solidimagestack` / `.solidimagestacklayer` structure; each layer's `Content.imageset` uses `idiom: vision` and `scale: 2x`, pointing at 1024×1024 PNGs
  - [x] Both the `OpenCodeClient` and `OpenCodeClientVision` targets use `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`; because the two targets reference different asset catalogs, iOS uses the flat `AppIcon.appiconset` and visionOS uses `AppIcon.solidimagestack`
  - [x] Verification: `OpenCodeClient` iphonesimulator build passes; `OpenCodeClientVision` xrsimulator build passes; `assetutil --info` confirms the compiled `Assets.car` contains a `SolidImageStack` named `AppIcon` with the three layers Back / Middle / Front

- [x] **visionOS input area interaction sizes and default window size (2026-05-01)**:
  - [x] The recording button's active state became a red icon + red tint background/border, avoiding visionOS glass/material compositing washing the original solid red background out to white
  - [x] The composer's right-side mic / send / stop action buttons grew from 32pt to 48pt on visionOS with vertical spacing loosened to 12pt, making gaze interaction easier; iPhone/iPad keep the original 32pt size
  - [x] The stop button while the AI is busy became a red icon + tint background/border matching the recording active state, instead of a solid red background, so the red semantics survive better under visionOS glass/material
  - [x] The composer's bottom container padding became a design token: visionOS uses 32pt horizontal / 20pt vertical, iPhone/iPad keep 16pt / 10pt, keeping the bottom-right button away from the Apple Vision Pro window resize handle
  - [x] The composer input height became a cross-platform token: visionOS 48–160pt, iPhone/iPad 32–100pt, so the input area in large windows is no longer limited to phone height
  - [x] The tool-call header's right-side open-file icon grew to a 44pt hit target + `title3` icon on visionOS, easing eye/hand opening of patch/edit detail files; iPhone/iPad keep the compact 24pt size
  - [x] The visionOS split view's left Workspace / Sessions sidebar width set to 130% of the iPad default (`1.3 / 6.0`), with the minimum width raised from 10% to 13% in step
  - [x] `OpenCodeClientVision`'s default window size set to 2304×1080, about 180% of the system default width and 150% of its height, reducing the need to manually enlarge the window after first launch
  - [x] Later, based on real-device impressions, the default window was made narrower and slightly taller: width from 2304 down to 1382 (about 60%), height from 1080 up to 1188 (about 110%); then width nudged to 1500 with height kept at 1188
  - [x] Later still the default window width went to 2000, height kept at 1188
  - [x] Verification: `OpenCodeClientVision` xrsimulator build passes; `OpenCodeClient` iphonesimulator build passes

- [x] **visionOS native target baseline (2026-04-30)**:
  - [x] Added the `OpenCodeClientVision` application target with SDK pointing at `xros`, device family set to Vision, and source reusing the existing `OpenCodeClient/` synchronized root group
  - [x] Kept the iPad three-column `NavigationSplitView` as visionOS's main layout; no tab-based top-level navigation introduced
  - [x] visionOS v1 does not support SSH tunnel: the SSH Tunnel section is hidden in `Settings`, and startup/foreground-background restore no longer attempts to auto-connect the tunnel; the underlying `SSHTunnelManager` uses a stub on visionOS to avoid linking Citadel / swift-nio-ssh
  - [x] visionOS v1 first used the system `AttributedString(markdown:)` to prove the target could compile standalone; it later switched to the locally patched MarkdownUI / NetworkImage
  - [x] visionOS API compatibility: `scrollDismissesKeyboard(.immediately)` wrapped in a platform-conditional modifier that skips the unavailable modifier on visionOS
  - [x] Verification: `xcodebuild -project "OpenCodeClient.xcodeproj" -target "OpenCodeClientVision" -configuration Debug -sdk xrsimulator CODE_SIGNING_ALLOWED=NO build` passes
  - [x] Later verification: the locally patched MarkdownUI / NetworkImage let the visionOS target use `MarkdownUI.Markdown` directly

- [x] **MarkdownUI / NetworkImage visionOS package patch (2026-05-01)**:
  - [x] Initially added `third_party/swift-markdown-ui` (2.4.1) and `third_party/NetworkImage` (6.0.1) as local package sources, replacing the remote MarkdownUI reference with an Xcode local package reference
  - [x] Later migrated to GitHub forks: `grapeot/swift-markdown-ui` tag `2.4.1-visionos.1` and `grapeot/NetworkImage` tag `6.0.1-visionos.1`, referenced by the Xcode project at exact versions, no longer vendoring `third_party/`
  - [x] `swift-markdown-ui/Package.swift` raised to Swift tools 5.9, declaring `.visionOS(.v1)`, and pointed `NetworkImage` at `https://github.com/grapeot/NetworkImage` exact `6.0.1-visionos.1`
  - [x] `NetworkImage/Package.swift` raised to Swift tools 5.9, declaring `.visionOS(.v1)`; `NetworkImage.swift` gained visionOS availability and uses a 1x1 transparent `CGImage` as the empty-image placeholder, avoiding the UIKit/AppKit-only empty image initializer
  - [x] `MessageRowView` and `FileContentView` returned to `MarkdownUI.Markdown` on visionOS, deleting the temporary native Markdown fallback
  - [x] Opened up visionOS Markdown embedded image support: `OpenCodeClientVision` explicitly links `NetworkImage`, and `FileContentView` plus `MessageRowView` reuse the iOS `WorkspaceMarkdownImageProvider` / `MarkdownImageResolver` path on visionOS
  - [x] Tapping a Markdown embedded image on visionOS opens a standalone Image Preview window; iPhone/iPad keep the original sheet preview
  - [x] Verification: `xcodebuild -project "OpenCodeClient.xcodeproj" -scheme "OpenCodeClientVision" -configuration Debug -sdk xrsimulator CODE_SIGNING_ALLOWED=NO build` passes
  - [x] Verification: `xcodebuild -project "OpenCodeClient.xcodeproj" -scheme "OpenCodeClient" -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` passes
  - [x] Later verification: after opening the visionOS Markdown image gate, both the `OpenCodeClientVision` xrsimulator build and the `OpenCodeClient` iphonesimulator build pass

- [x] **Default model switched to GPT-5.5 (2026-04-28)**:
  - [x] Default send model switched from DeepSeek to `openai/gpt-5.5`
  - [x] GPT preset display name and model ID upgraded from `GPT-5.4` / `gpt-5.4` to `GPT-5.5` / `gpt-5.5`
  - [x] Added a compatibility mapping for sessions with a saved `openai/gpt-5.4` selection so the model selector does not fall back
  - [x] Added tests for the default selection and legacy GPT selection migration

- [x] **Markdown report image rendering fix (2026-04-15)**:
  - [x] Root cause confirmed: Android could display images inside reports, so this was not a markdown content problem; Android resolves relative image paths into `data:` URIs before rendering, while the iOS chat view originally only did path resolution and never hooked up an image provider that could render `data:` URLs
  - [x] `MessageRowView`: added `WorkspaceMarkdownImageProvider` to the chat's `ResolvedMarkdownView` so `data:` URIs already converted by `MarkdownImageResolver` actually display
  - [x] `WorkspaceMarkdownImageProvider`: added `workspaceDirectory` participating in path relativization, preventing markdown images in file preview from carrying an absolute workspace prefix into the wrong `/file/content` API path
  - [x] `FileContentView`: passes `state.currentSession?.directory` into `MarkdownPreviewView` / `WorkspaceMarkdownImageProvider`, keeping file preview and chat view consistent on workspace path semantics
  - [x] Test fix: `WorkspaceMarkdownImageProviderTests.decodesBase64DataURL()` now uses the base64 of a real 1x1 PNG instead of the invalid `"hello"` payload; added absolute-workspace prefix stripping coverage
  - [x] Verification: `xcodebuild -project "OpenCodeClient.xcodeproj" -scheme "OpenCodeClient" -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' build` passes; `test` on the same destination passes
  - **Commit**: `5554fe9` — fix: render markdown report images on ios
  - **Commit**: `45044d4` — test: align markdown image provider data-url coverage

- [x] **Markdown caption image block preview fix (2026-05-03)**:
  - [x] Root cause confirmed: when `![image](url)` is immediately followed by a caption with no blank line between, MarkdownUI parses the image as an inline image inside a paragraph, bypassing `WorkspaceMarkdownImageProvider`, so remote large images displayed at original size and could not be tapped for preview.
  - [x] `MarkdownPreviewView` normalizes "an image alone on one line + non-empty text on the next" into an image block before rendering, without touching the original file content; genuine inline images stay unchanged.
  - [x] `WorkspaceMarkdownImageProvider` gained a direct URLSession download path for remote HTTP(S) images, so remote images no longer depend on the OpenCode server's base64 file endpoint.
  - [x] Added normalizer tests and HTTP(S) URL path tests; verified `xcodebuild test` passes.

- [x] **Visual redesign Phase 2 — Mic button + color unification + interaction fixes (2026-04-01)**:
  - [x] Mic button moved into a VStack above the send button, with a rounded border (1.5pt brand blue) so it reads as a tappable button
  - [x] Brand primary changed from dark blue `(0.15, 0.25, 0.55)` to system blue `(0.0, 0.478, 1.0)`, unified with the iOS accent
  - [x] All 7 `.accentColor` occurrences replaced with `DesignColors.Brand.primary` (4 in ChatToolbarView, 1 in SessionListView, 1 in ContextUsageView, 1 in ToolPartView)
  - [x] Transcribing state visible again (`surfaceLight`/`surfaceDark` backgrounds replace `Color.clear`)
  - [x] Restored sending while the AI works (send button always visible, stop/abort shown below at the same time)
  - **Commit**: `122f29c` — fix: mic button to right side with border, unify brand color to system blue
  - **Commit**: `4bf2e12` — fix: restore transcribing visual feedback and send-while-busy

- [x] **Design Token test coverage (2026-04-01)**:
  - [x] Added `DesignTokensTests` (9 tests): exact spacing values + monotonic increase, corner radii in ascending order, brand primary/gold RGB ranges, opacity valid range + dark > light, animation slots exist, semantic colors pairwise distinct
  - [x] All tests pass, `xcodebuild test` green

- [x] **Visual redesign Phase 1 (2026-04-01)**:
  - [x] `docs/design.md` — complete design doc covering 11 improvement directions
  - [x] `DesignTokens.swift` — centralized design system (Brand primary dark blue + gold, semantic colors, warm gray neutrals, seven type sizes, spacing, corner radii, animation presets, shadows)
  - [x] 17 view files redesigned: MessageRowView, ChatTabView, ChatToolbarView, ToolPartView, PatchPartView, PermissionCardView, QuestionCardView, SessionListView, ContextUsageView, StreamingReasoningView, TodoListInlineView, FileTreeView, FileContentView, SettingsTabView, SplitSidebarView, ContentView, L10n
  - [x] Message direction B (no bubbles + 4pt left color bar), AI messages as plain text with no container
  - [x] Composer redesign (mic embedded left, send/stop square buttons right, borderless input field)
  - [x] Toolbar model+agent merged into a config sheet, Rename demoted to .secondary
  - [x] Unified card language: info cards lose borders, action cards gain a left color bar
  - [x] Context ring shrunk 18pt + pulsing animation at ≥85%
  - [x] All new L10n keys (configureTitle/Model/Agent/NoAgents) carry en/zh translations
  - [x] Fixed Gemini subagent misoperations (PathNormalizer, APIConstants/StorageKeys restoration, hardcoded strings)
  - **Commit**: `b6ed2ac` — feat: redesign visual design system — design tokens, card language, composer, toolbar
  - **Advanced items not yet implemented** (P1: session summary preview, child session connector lines, session-switch crossfade, permission slide-in animation, message appearance animation; P2: tool card spring expansion, logo empty-state breathing animation, dark logo asset)

- [x] **Avoid mutating state synchronously during view updates on session switch (2026-03-30)**:
  - [x] Draft syncing and scroll state resets reacting to `currentSessionID` changes in `ChatTabView` moved into `Task { @MainActor in }`
  - [x] Lowers the odds of the runtime `Modifying state during view update` warning without changing existing session switch behavior

- [x] **GLM-5-turbo preset switched to GLM-5.1 (2026-05-03)**:
  - [x] Model preset display name updated from `GLM-5-turbo` to `GLM-5.1`, modelID from `glm-5-turbo` to `glm-5.1`
  - [x] `canonicalModelPresetID` legacy migration: both `glm-5-turbo` and `glm-5.1` map to the new `glm-5.1`
  - [x] Model references in the PRD and RFC updated in step

- [x] **GLM-5.1 preset switched back to GLM-5-turbo (2026-03-30)**:
  - [x] Model preset display name updated from `GLM-5.1` to `GLM-5-turbo`
  - [x] Underlying model ID updated from `glm-5.1` to `glm-5-turbo`
  - [x] Added a compatibility mapping for sessions with a saved `glm-5.1` selection so the selector does not fall back to another model

- [x] **Chat Composer visual compaction and Return key behavior change (2026-03-28)**:
  - [x] Visual: composer minimum height squeezed further from 44pt to 32pt, vertical padding of the input container/bottom bar tightened to 5pt/6pt, bringing the input area's height closer to the round buttons on the right and wasting less bottom space
  - [x] Behavior: `ChatComposerTextView` modified so the Return key (including Enter on an external keyboard) always inserts a newline instead of sending, and the keyboard Return key type reverted from `.send` to `.default`
  - [x] Safety: IME marked-text composition safety preserved so input method confirmations never trigger unexpected actions; sending happens only via the round arrow button on the right
  - [x] Tests/docs: `ChatComposerKeyAction` unit tests updated to match the new behavior, and the README's iPad keyboard notes updated in step

- [x] **iPad Chinese IME + physical keyboard Enter/Shift+Enter premature send fix (2026-03-28)**:
  - [x] Root cause: the Chat composer used `TextField(axis: .vertical)`'s `.onSubmit` plus the send button's `.keyboardShortcut(.return)`; with an iPad external keyboard, both Return paths fired send prematurely while the Chinese IME was still in marked text/composition
  - [x] Fix: the chat input box was replaced with a local `UITextView` bridge whose delegate distinguishes IME composition by `markedTextRange`; plain `Enter` sends, `Shift+Enter` inserts a newline, and the bare `Return` keyboard shortcut was removed
  - [x] Tests/docs: added composer key decision unit tests, updated the chat input UI smoke to the `chat-input` accessibility identifier, and recorded the iPad external keyboard Enter/Shift+Enter semantics in the README

- [x] **iPad duplicate sidebar entry after creating a session fix (2026-03-28)**:
  - [x] Root cause: the optimistic `sessions.insert(..., at: 0)` in `createSession()` / `forkSession()` and the SSE `session.updated` write path could both push the same `session.id` into local `sessions`; the iPad sidebar is permanently visible, so duplicate rows and double selection showed up immediately; after switching to another session, `refreshSessions()` overwrote everything with the server's canonical list and the local duplicates disappeared
  - [x] Fix: added a `upsertSession()` helper to `AppState` that dedups by `session.id`, used uniformly by `createSession()`, `forkSession()`, and `session.updated`, keeping local session state single-ID unique at all times
  - [x] Tests: added create/fork duplicate collapse regression tests and a state-flow test for `session.updated` converging duplicate sessions; verified `xcodebuild build -project "OpenCodeClient.xcodeproj" -scheme "OpenCodeClient" -destination 'generic/platform=iOS Simulator'` and `xcodebuild test -project "OpenCodeClient.xcodeproj" -scheme "OpenCodeClient" -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'` all pass

- [x] **GLM-5-Turbo preset switched to GLM-5.1 (2026-03-27)**:
  - [x] Model preset display name updated from `GLM-5-Turbo` to `GLM-5.1`
  - [x] Underlying model ID updated from `glm-5-turbo` to `glm-5.1`

- [x] **GLM-5 preset switched to GLM-5-Turbo (2026-03-20)**:
  - [x] Model preset display name updated from `GLM-5` to `GLM-5-Turbo`
  - [x] Underlying model ID updated from `glm-5` to `glm-5-turbo`

- [x] **Default model switched to GPT-5.4 (2026-03-19)**:
  - [x] Default send model switched from `zai-coding-plan/glm-5` to `openai/gpt-5.4`
  - [x] New sessions and the default send path with no saved model choice land directly on GPT-5.4

- [x] **oh-my-opencode default agent and Gemini model ID fix (2026-03-17)**:
  - [x] The global `oh-my-opencode.json` default agent switched from GLM-5 to sisyphus ultraworker (Claude Opus 4.6)
  - [x] Gemini model ID fix: `google/gemini-3-flash` -> `google/gemini-3-flash-preview`, `google/gemini-3-pro` -> `google/gemini-3.1-pro-preview`

- [x] **iPhone left-edge swipe to open Session List (2026-03-19)**:
  - [x] Implementation: a narrow transparent edge target added to the left of `ChatTabView`, enabled only at compact width; dragging right from the left edge past the threshold triggers the same `showSessionList = true` as the toolbar
  - [x] Constraints: the start point must hug the left edge, horizontal displacement must be sufficient, and vertical drift limited, so ordinary vertical scrolling is not misread as opening the session list
  - [x] Tests: added `SessionListEdgeSwipeBehaviorTests` covering valid left-edge right swipe, non-left-edge start, and excessive vertical drag

- [x] **Model selection showing the wrong model after switching sessions fix (2026-03-14)**:
  - [x] Root cause: `inferAndStoreModelForCurrentSessionIfMissing()` had a `guard selectedModelIDBySessionID[sessionID] == nil` precondition, so when persistence held an old value it skipped inference, leaving `selectedModelIndex` holding the previous session's value
  - [x] Fix: renamed to `syncModelFromMessageHistory()`, removed the skip-if-persistence-nonempty guard, and after every message load it infers the actual model from message history and updates the selection; `applySavedModelForCurrentSession()` stays as the synchronous fast path

- [x] **Context ring always visible + value held while the AI processes (2026-03-14)**:
  - [x] Root cause 1: `ChatTabView` injected a `ProgressView` into `.navigationBarTrailing` when `state.isBusy`, visually covering the ring → that ProgressView block was deleted
  - [x] Root cause 2: while the AI processes, the server creates a new assistant message carrying `tokens: {total: 0}`, and the old `tokens != nil` filter matched that empty message, making the ring show 0% → changed to `tokens != nil && tokens.total > 0`, skipping empty-token messages
  - [x] Caching: `AppState._cachedContextUsage` (`@ObservationIgnored`) caches the last valid snapshot; returns the cached value while messages are loading or provider config is missing (same-session only); the cache clears on session switch

- [x] **Live display of speech partial transcripts (2026-03-11)**:
  - [x] AIBuildersAudioClient: `transcribe` gained an optional `onPartialTranscript` callback; `streamPCMOverRealtimeWebSocket` accumulates and calls back on `transcript_delta`
  - [x] AppState.transcribeAudio: passes onPartialTranscript through
  - [x] ChatTabView: during transcription the partial is written live into the input box, replaced by the final on completion; on failure the prefix is restored

- [x] **Markdown large file/long line crash fix (2026-03-11)**:
  - [x] Root cause: MarkdownUI freezes/crashes on very long single lines (such as transcript paragraphs of 3000+ characters) or large files (GH #426, #396)
  - [x] Fix: FileContentView checks `maxLineLength > 1500` or `totalLength > 60KB` before rendering and uses RawTextView to skip MarkdownUI when either holds
  - [x] A second fallback kept inside MarkdownPreviewView; debug logs kept in loadContent and onAppear

- [x] **Realtime Speech transcription fix (2026-03-11)**:
  - [x] Root cause 1: API URL construction error — `URL(string: "/v1/...", relativeTo: base)` replaces the base's path, so `https://space.ai-builders.com/backend` requested `/v1/...` instead of `/backend/v1/...`
  - [x] Fix: `buildAPIURL` ensures the base path ends with `/` so relative paths append correctly; session creation and testConnection both switched to this helper
  - [x] Root cause 2: m4a to PCM conversion failed — `AVAudioConverter` has known problems with AAC/m4a and threw `nilError`
  - [x] Fix: switched to the `ExtAudioFile` API for reading and conversion, outputting 24kHz 16-bit mono PCM directly
  - [x] Added `buildAPIURLPreservesMountPath` and `buildAPIURLWithoutMountPath` unit tests
  - [x] Added SpeechProfile debug logs (session POST url, ws_url, websocket connect, per-step failure details)

- [x] **Session tree hierarchy view (2026-03-03)**:
  - [x] Background: when an agent dispatches a background sub-agent it creates a child session (`Session.parentID` pointing at the parent), and showing all sessions flat cluttered the list
  - [x] Implementation: a `SessionNode` tree structure + the `AppState.buildSessionTree(from:)` static method, building the hierarchy recursively by `parentID`; orphan sessions (parentID pointing at a nonexistent session) are automatically promoted to root nodes
  - [x] UI: child sessions indent (depth × 24pt), shrink font (`.subheadline`), fade color (`.secondary`); parent sessions show a chevron collapse/expand button on the left
  - [x] `expandedSessionIDs: Set<String>` tracks expansion state (collapsed by default), toggled by `toggleSessionExpanded()`
  - [x] iPhone (`SessionListView`) and iPad (`SplitSidebarView.SessionsSidebarList`) both updated to tree-recursive rendering
  - [x] Unit tests: 7 tests covering hierarchy building, orphan handling, sorting, multi-level nesting, empty input, archive filtering, and collapse state toggling

- [x] **Session creation restricted to Server default (2026-02-25)**:
  - [x] Root cause: `POST /session` does not accept a directory, so new sessions always land in the server's current project; the iOS project picker only filters the list and does not change the creation target
  - [x] Implementation: the create button appears only for Server default; with a specific project selected, the create button grays out + an info icon points to switching on the server side
  - [x] `canCreateSession`, `chatCreateDisabledHint`; ChatToolbarView and SessionListView gray out + info
  - [x] Docs: lessons §16, RFC §4.3.1, PRD §4.4.3
- [x] **Project selection (completed 2026-02-25)**:
  - [x] PRD/RFC update: added the Project (Workspace) design
  - [x] Implemented the `Project` data model, `APIClient.projects()`, `sessions(directory:limit:)`
  - [x] Updated `AppState`: projects, selectedProjectWorktree, customProjectPath, effectiveProjectDirectory
  - [x] Settings UI: Project Picker (Server default / project list / Custom path)
  - [x] Unit tests: Project decoding, effectiveProjectDirectory logic; fixed `SessionDeletionSelectionTests.makeSession` missing the archived parameter
  - [x] Resolved the root cause of "the phone only shows sessions from two weeks ago": web and iOS were looking at different default projects; filtering by project is now supported
- [x] **Agent selection (completed 2026-02-21)**:
  - [x] RFC/PRD update: added the Agent data model, API, and UI design (v0.2 / RFC-002)
  - [x] Implemented the `AgentInfo` data model (with mode filtering: primary/all shown, subagent hidden)
  - [x] Implemented the `APIClient.agents()` method
  - [x] Updated `AppState`: added the agents list (prefill of 5 default agents), selectedAgentIndex, loadAgents()
  - [x] Updated the model list: GLM-5 (default) / Opus 4.6 / Sonnet 4.6 / GPT-5.3 Codex / GPT-5.2 / Gemini 3.1 Pro / Gemini 3 Flash
  - [x] Updated `ChatToolbarView`: chip horizontal scroll became a dropdown list (Model + Agent)
  - [x] Updated `promptAsync`: passes the selected agent
  - [x] Unit tests: Agent API decoding + mode filtering tests
  - [x] OpenCode-Builder set as the default agent
- [x] **Rendering performance 1/3 (row-level removal of global state subscriptions)**: `MessageRowView/ToolPartView/PatchPartView` dropped the direct `@Bindable AppState` connection in favor of minimal necessary data + a file-open callback, reducing full-page recomputation triggered by unrelated state changes in long sessions
- [x] **Rendering performance 2/3 (Scroll Anchor slimming)**: `scrollAnchor` changed from "concatenating all message/streaming strings" to an O(1)/small-constant signature based on `messageCount + lastMessageSignature + streaming chars`, avoiding a full traversal on every state change in long sessions
- [x] **Rendering performance 3/3 (Markdown fast path)**: plain text messages render via `Text`, with `MarkdownUI` used only when Markdown syntax features are detected, cutting parse and layout cost for the many plain text messages in long sessions
- [x] **Message segmented loading (3 turns)**: by default only the most recent 3 turns (6 messages) are fetched; the top of the chat page shows "pull to load more history", and each pull extends by 3 turns and refetches
- [x] **SSH Tunnel remote access** (Citadel integration complete):
  - [x] SSHKeyManager: Ed25519 key generation/storage (Keychain)/public key display
  - [x] SSHTunnelManager: connect/disconnect/status
  - [x] SSHTunnelConfig data model
  - [x] Settings UI: SSH Tunnel configuration area
  - [x] AppState integration: SSH connection status
  - [x] Unit tests
  - [x] Added the Citadel dependency (SPM)
  - [x] Implemented the actual SSH connection logic (local 127.0.0.1:4096 → SSH DirectTCPIP → VPS 127.0.0.1:remotePort)
  - [x] Fixed the project deployment target (so UITests can run on the simulator)
- [x] **UI improvement** (low priority): busy state uses a spinner instead of a round button
- [x] **Permission request interaction fix**: supports Allow once / Allow always / Reject, and ensures POST `/session/:id/permissions/:permissionID` carries the body `{"response":...}`
- [x] **SSH Public Key UI**: generate/view/copy the public key should work even when not connected (avoiding an all-gray button sheet)
- [x] **Permission card placement**: the permission dialog card renders at the bottom of the message stream (scrolled to bottom by default) and above the activity/thinking rows
- [x] **Activity timing persistence**: timings derive from message `time.created/time.completed`, avoiding a reset to 0 after app restart or session switch
- [x] **Activity/Busy state flapping**: session.status poll results do not override recent SSE; activity text updates get a 2.5s debounce + debug log
- [x] **Per-turn Activity row**: each user turn keeps its completed activity row at the end (showing elapsed time); the current in-progress turn shows a running activity row at the bottom
- [x] **iPhone noticeable heat hotspot fix (scrolling)**: removed the running activity per-second timer's influence on `scrollAnchor`, avoiding a per-second `scrollTo("bottom")` animation
- [x] **Full Code Review doc rewrite (2026-02-13)**: deleted and rewrote `docs/code_review.md`, focusing on obvious architecture/performance/security issues and priorities
- [x] **SSH TOFU security baseline**: replaced `acceptAnything`; the host key is trusted on first connect, strictly verified afterwards, with support for resetting trusted hosts
- [x] **SSE main channel convergence**: removed constant busy polling, replaced by a one-shot bootstrap sync (messages + permissions) after SSE reconnect
- [x] **AppState refactor (PermissionController)**: permission event parsing/write-back and the pending map extracted from AppState, with behavior tests added
- [x] **AppState refactor (Iteration C - ActivityTracker)**: activity state derivation/debounce/duration rules extracted, with behavior tests added
- [x] **Activity Row early-completed fix**: stays running when session.status goes idle but tools are still running/pending or streaming continues, so the clock does not stop early
- [x] **SSH UX completeness**: Settings gained "Copy Public Key", a setup guide, and gray hint text (after enabling SSH you must tap Test Connection above)
- [x] **Session rapid-switch race fix (full fetch)**: added requestedSessionID validation to `loadMessages/loadSessionDiff`, discarding stale responses so A→B→A is not overwritten by old B results
- [x] **Activity Row early-completed (second) fix**: the `running/completed` decision became "current turn + busy state first", no longer relying on `completedAt == nil`, avoiding a false completed while still running
- [x] **SSH UX fix**: default Server Address changed to `127.0.0.1:4096`; config changes auto-reconnect after SSH is enabled; View Public Key no longer blank in the enabled scenario; the `Set Server Address` CTA became an explicit blue button
- [x] **Settings close button consistency**: the sheet's top-right button is now English `Close`, avoiding the former Chinese close label appearing in the English UI
- [x] **Localization planning**: added `docs/features/localization/research.md` (formerly `docs/dev_localization.md`) with an en/zh-Hans bilingual rollout route and a phased migration plan
- [x] **SSH foreground/background auto-restore fix**: SSH/SSE disconnect proactively on backgrounding; on foreground restore, if the health check fails, the SSH tunnel is forcibly rebuilt once before refresh
- [x] **SSE reconnect status compensation**: SSE bootstrap and the `server.connected` event also refetch `/session/status`, so status is backfilled along with messages
- [x] **Busy stuck / Abort feels ineffective fix**: during poll merging, sessions "missing from the poll result but still busy/retry locally" are downgraded to idle with streaming cleaned up in step; after abort, status + messages are refetched immediately
- [x] **Todo rendering compatibility fix (OpenCode upgrade)**: tolerates `TodoItem` old and new fields (`status/priority/id` and legacy `completed`), and fixes tool state `metadata.todos`/`output(JSON)` parsing; a non-string `metadata.input` no longer blanks the todo card
- [x] **SSH runtime crash protection (NIO channel state)**: fixed a concurrency problem in `SSHTunnelManager` calling channel/context close across threads (unified to hop back to the NIO eventLoop), avoiding `Sent channel window adjust on channel in invalid state` triggering a fatal
- [x] **SSH Public Key interaction hardening (second pass)**: `View Public Key` now always goes through `generateOrGetPublicKey()` (no longer reading the possibly empty cached value first), and `Copy Public Key` + `View Public Key` merged into one row of buttons, reducing Settings footprint
- [x] **Tailscale / Server Address UX (2026-03-01)**: the ATS exception adds `NSIncludesSubdomains` for `ts.net`; `correctMalformedServerURL` fixes the `host://host:port` malformed form; `ensureServerURLHasScheme` prepends `http://` when http/https is missing; correction timing changed to lose focus (`@FocusState` + `onChange`) to avoid rewriting per character; the Server Address keyboard `submitLabel(.done)` shows Done

## Completed

- [x] Session list: a list button on the left of the Chat tab showing all sessions under the workspace, with switching, creation, and pull-to-refresh
- [x] PRD update (async API, default server, removal of large sessions/push/multi-project)
- [x] RFC update (MarkdownUI, native capabilities, Phase 4 deferred)
- [x] Git init, .gitignore (including opencode-official), docs moved into docs/
- [x] Initial commit: docs, OpenCodeClient scaffold
- [x] Phase 1 basics: Models, APIClient, SSEClient, AppState
- [x] Phase 1 UI: Chat Tab, Settings Tab, Files Tab (placeholder)
- [x] Phase 1 polish: SSE event parsing, streaming updates, Part.state compatibility, Markdown rendering, full-row tool call display
- [x] Phase 2: Part rendering (reasoning collapse, step separators, patch cards), manual permission approval, theme switching
- [x] UX simplification: one toolbar row (left: new/rename/view session; right: 3 model icons), removed Compact, Import, Model Presets
- [x] Phase 3: file tree (recursive expansion, on-demand loading), file content (code line numbers, Markdown Preview switching), Files Tab (file tree only) + file search
- [x] Tool/Patch tap-through: tools carrying a path (write/edit/apply_patch etc.) open the file preview "in the File Tree" on tap (path from metadata, state.input.path/file_path/filePath, patchText parsing)
- [x] apply_patch path parsing fix: patchText starts with "*** Begin Patch\n*** Add File: "; switched to a range(of:) lookup
- [x] Tool cards gained an "open in File Tree" button (folder icon next to the label) + context menu
- [x] Markdown preview: switched to the MarkdownUI library (swift-markdown-ui 2.4.1) instead of custom rendering, with full GFM support (tables, headings, code blocks, lists, etc.)
- [x] Unit tests: defaultServerAddress, sessionDecoding, messageDecoding, sseEvent, partDecoding
- [x] UI polish: larger input box (3-8 lines, capsule shape), gradient model selector capsule, SF Symbols rendering style, message bubble refinements, softened tool/patch/permission card corners, MarkdownUI for chat message rendering
- [x] Chat: AI responses support text selection/copy (with Markdown rendering)
- [x] Chat → file navigation: switched to URLComponents for query encoding, unified file path normalization; added an empty-content warning log
- [x] Tool cards: reason/title collapsed state max two lines + ellipsis; expanded state shows the full Reason
- [x] Session Todo (task list): supports `/session/:id/todo` fetch + SSE `todo.updated` updates; renders todos inside the `todowrite` tool card (option B, no persistent top bar)
- [x] Phase 3: Think Streaming delta
- [x] Phase 3: iPad / Vision Pro layout: `horizontalSizeClass == .regular` splits left/right (Files left, Chat right), Settings as a toolbar button
- [x] iPad / Vision Pro layout upgrade: three columns (NavigationSplitView) — left Workspace (Files+Sessions) / middle Preview / right Chat
- [x] iPad three-column widths: Workspace ≈ 1/6; Preview ≈ 5/12; Chat ≈ 5/12
- [x] iPad three columns draggable: default ideal widths set, but users can drag the dividers
- [x] iPad inline file preview: selecting a file on the left or tapping a file in a Chat tool/patch updates the middle Preview (no more sheet)
- [x] iPad Preview refresh button: manual refresh at the top-right of the middle column (reloads file content)
- [x] Test coverage: SSE event structure, session filtering, PathNormalizer, path normalization
- [x] iPad message stream density: tool/patch/permission cards fill horizontally in the iPad three-column grid; text parts still take the full row
- [x] PathNormalizer hardening: percent-encoding decode, file:// compatibility, basic ../ defense, absolute path → workspace-relative resolution (fixes empty-content tool read previews)
- [x] Doc sync: PRD/RFC gained the iPad three-column grid notes; lessons.md gained the "PRD/RFC→code→test→build/test" workflow
- [x] Code review archived
- [x] Voice input (AI Builder Speech Recognition): record (mic permission) → call `/v1/audio/transcriptions` → append text to the input box
- [x] iPad external keyboard: Enter sends (submitLabel/send + keyboardShortcut Return)
- [x] Network security boundary: http:// forbidden on WAN (https:// enforced); Settings shows the scheme and a hint
- [x] 3.1 apply_patch displays as "patch" (ToolPartView.toolDisplayName)
- [x] 3.2 Settings HTTP scheme shown orange + info icon
- [x] 1.1 AppState detailed planning
- [x] Bug: tool layout — thinking merges into the last MessageRowView instead of starting a new row that breaks the grid
- [x] Bug: Diff/file preview — horizontal scrolling, minWidth fill, textSelection
- [x] Bug: Markdown source view width — after Markdown/Preview switching the source view only took the left half and wrapped early (switched to RawTextView so text fills the available width)
- [x] Todo 2.4 left unemphasized per option B
- [x] Recent commit/push: 9b4b842 (tool layout, Diff preview, Settings HTTP info, 1.1 planning, 2.4)
- [x] **GLM-4.7 → GLM5**: model updated to `zai-coding-plan` / `glm-5`
- [x] **New model**: added `openai` / `gpt-5.3-codex-spark` (GPT-5.3 Codex Spark)
- [x] **iPhone model short names**: the iPhone top bar model chip shows `GPT` / `Spark` / `Opus` / `GLM`, iPad shows full names
- [x] **Tool card color coding**: `todowrite` uses a green accent, other tools use the theme color (accentColor), for fast scanning
- [x] **Patch card style alignment**: same light background + thin border as tool cards, clearer information
- [x] **Card visual consistency**: tool/patch/permission/user message share the same light background opacity (0.07) + thin border (0.14) style
- [x] **Session title auto-update**: listens for SSE `session.updated` + polls after send, no manual rename needed
- [x] **Thinking typewriter effect fix**: on `message.part.updated` (reasoning) the `StreamingReasoningView` is pinned to the bottom of the message list, no longer depending on messages already containing a reasoning part
- [x] **AI Builder token check before recording**: prompts to configure Settings first when the token is empty / being tested / failed its test
- [x] **Test Connection spinner state**: the Settings AI Builder connection test shows "Testing..." + ProgressView
- [x] **AI Builder test state persistence**: after a successful Test Connection, the OK state survives app restarts; it invalidates only when token/baseURL changes
- [x] **Send/record buttons stacked vertically**: iPhone/iPad both use a VStack layout, send on top, mic below, abort (if present) at the bottom
- [x] **Session list sorted by update time**: `sortedSessions` orders by `time.updated` descending
- [x] **Session row time shows update time**: the session list's "xx minutes ago" now uses `time.updated`
- [x] **Session list de-blued**: list text uses neutral (gray) colors, with the current session highlighted by background
- [x] **Session action button reorder**: the Chat top toolbar's left buttons are now Session list → rename → Compact → new session
- [x] **Blank-on-session-switch bug fix**: messages/parts/streaming state clear first before the new session's data loads
- [x] **Server error message display**: an assistant message carrying `error.data.message` shows a red card in the stream
- [x] **iPad sidebar split top/bottom**: the left side is now Files (File Tree) on top and Sessions below (tapping a session switches the right Chat session)
- [x] **Workspace left column equal heights**: the iPad Workspace left column's Files/Sessions blocks are 1:1
- [x] **iPad Workspace inline file preview**: tapping a file in the Workspace's left File Tree updates the middle Preview column
- [x] **todowrite renders only todos**: tool cards no longer show todowrite's raw JSON input/output, only the rendered todo list
- [x] **Context usage ring**: a context usage ring added between the model and the gear at the top of Chat; tapping shows a token/cost breakdown (gray empty ring with no data)
- [x] **Context provider config load fix**: `GET /config/providers` decoding tolerates array/dict variants; tapping the ring triggers a load if not loaded, and shows the error on failure
- [x] **Context sheet default size**: opens as large on iPad (avoiding small-then-grow)
- [x] **Input draft persistence**: unsent input persists per sessionID and restores on session switch; cleared after a successful send
- [x] **Model selection remembered per session**: switching sessions restores that session's last chosen model (no global overwrite)
- [x] **Duplicate send fix**: busy/polling scenarios dedup the optimistic temp user message so the UI does not show two
- [x] **Busy/Retry session polling enhancement**: `retry` treated the same as `busy`; polling auto-refreshes while busy and stops when it exits
- [x] **Chat Activity message**: "current action + elapsed time" renders as the last item in the message stream (remembered per session); updates every second while running, freezes as Completed when done and stays until the next run; copy follows web: reasoning extracts `**title**` into `Thinking - title`, tools map by type to "Searching/Making edits/Running…"
- [x] **loadMessages decode fallbacks**: supports empty body / non-array payloads (`messages`/`data`/`result` wrappers, single object) so polling does not break on parse failure
- [x] **Message visibility during streaming**: poll merging keeps the temp user message and the streaming assistant draft (preventing UI flicker/loss when busy lists go empty)
- [x] **Chat empty states**: distinct hints for no session / busy(retry) / empty messages; scroll anchor includes streaming delta length to avoid stale scrolling

## Follow-ups

- [x] **Code Review 1.1**: AppState split (SessionStore/MessageStore/FileStore/TodoStore, external API unchanged)
- [x] **Code Review 1.2**: SSE research (single-line API data already suffices; RFC planning; Accept/Cache-Control headers added)
- [x] **Code Review 1.3**: SSE message.updated filtered by sessionID
- [x] **Code Review 1.4**: PathNormalizer unified path normalization (Utils/PathNormalizer.swift)
- [ ] **Phase 4: iPad / Vision Pro layout optimization**: could consider (optional) Preview column support for finer-grained controls like "pin/close current file"
- [x] **Model replacement (OpenAI)**: GPT-5.2 replaced by GPT-5.3 Codex Spark (short name `Spark`), and GPT-5.3 Codex's iPhone short name changed to `GPT`
- [ ] **iPhone heat investigation and optimization (deferred)**: paused at the current priority; Instruments re-check and further optimization come later
- [x] **Activity Row per-turn retention check (code review)**: one code-level pass done (per-turn completed + new-turn running logic); on-device interaction regression still being tracked
- [x] **Full codebase review doc rewrite**: deleted the old `docs/code_review.md` and rewrote it against the current code, focusing on architecture/refactorability/obvious performance and security issues
- [x] **SSE main channel + one-shot bootstrap**: removed constant busy polling, keeping the one full compensating sync on reconnect/session entry
- [x] **AppState Refactor Iteration B (PermissionController)**: tests added first, then the permission control logic extracted with the external interface unchanged

### Code Review improvements (from code_review.md)

- [x] **4.2 Race Condition**: session switching gained `sessionLoadingID` to prevent races during rapid switching
- [x] **3.2 Error Presentation**: unified error handling pattern
- [x] **3.3 Magic Numbers**: extracted constants (column width ratios, animation durations, etc.)
- [x] **3.4 Test Coverage**: added AppState-level tests
- [x] **3.5 View Decomposition**: split up ChatTabView
- [x] **3.1 AppState Size** (partially done - Stores extracted, full Coordinator undecided): continue extracting the Coordinator
- [x] **4.1 Memory Leaks**: SSE connection deinit handling
- [x] **4.4 Default Server**: changed the default server configuration

## Problems Encountered

1. **Local network prohibited (iOS)**: connecting to `192.168.180.128:4096` errors with `Local network prohibited`. Info.plist needs:
   - `NSLocalNetworkUsageDescription`: explains why local network access is needed; the permission dialog appears on first access
   - `NSAppTransportSecurity` → `NSAllowsLocalNetworking`: allows HTTP to local IPs
   - The user must tap "Allow" in the dialog to connect

2. **Stuck after send**: a failed send gave no feedback and the input box was already cleared, so the user never knew. Fix: restore the input on send failure, show an error alert, and show loading while sending

3. **No live updates after send**: the send succeeded and the web client already had a reply, but the iOS side needed a restart to see it. Causes:
   - SSE only connected on `willEnterForegroundNotification`, so it was never connected on first launch
   - Some events (like `server.connected`) lack a `directory` field and failed to parse
   - Fix: call `connectSSE()` after `refresh()` succeeds; `SSEEvent.directory` became optional; after a successful send a 60-second poll (loadMessages every 2 seconds) runs as a fallback

4. **loadMessages parse failure**: when the LLM streams thinking deltas, `Part.state` expected a String but the API returned an object (ToolState). Error: `Expected to decode String but found a dictionary`. Fix: added `PartStateBridge`, supporting state as String or object, extracting `status`/`title` from objects for UI display

5. **Unable to simultaneously satisfy constraints**: keyboard-related constraint conflicts (TUIKeyboardContentView, UIKeyboardImpl). These come from the system keyboard, not app code, and usually need no fix.

6. **Terminology clarification**: Think streaming actually refers to the Think (ReasoningPartView) expand/collapse behavior, not Tool.

7. **Polling messages parse noise**: during busy/retry, occasional `The data couldn’t be read because it is missing` (empty body / unstable payload shapes). Fix: APIClient gained an empty body guard + multi-shape decode fallbacks; AppState catches DecodingError and only logs, so polling is not mistaken for a connection failure.

8. **SSH runtime fatal (NIO channel state)**: occasional `Sent channel window adjust on channel in invalid state` when scrolling the Settings page and similar. Traced to `SSHTunnelManager` calling NIO `channel.close/context.close` directly from NW callback threads, racing the state machine; fixed by scheduling all closes through `eventLoop.execute`.

9. **Simulator SpringBoard crash (non-app process)**: the latest crash logs show `Process: SpringBoard`, with thread `com.apple.xpc.activity.com.apple.SplashBoard` hitting `dispatch_assert_queue`; a simulator system component anomaly, not an `OpenCodeClient` process crash. Conclusion: no direct causal link to current code changes; triage should start with the "restart/erase the simulator + reinstall the app" path.

10. **View Public Key still blank in some cases**: when SSH was enabled but the connection failed, the old logic read the cached public key first and could hit an empty string, leaving the sheet empty. Fix: opening the sheet always goes through `generateOrGetPublicKey()` with trim + empty guard, and anomalies surface the error dialog.

11. **Tailscale MagicDNS needs an ATS exception**: company policy requires ATS/HTTPS for all hosts, but servers behind Tailscale MagicDNS (`*.ts.net`) usually run HTTP. Fix: under Info.plist's `NSAppTransportSecurity` add `NSExceptionDomains` → `ts.net` → `NSExceptionAllowsInsecureHTTPLoads: true` + **`NSIncludesSubdomains: true`** (key point: without it `ts.net` does not match subdomains like `host.example.ts.net`), exempting only the Tailscale domain from the HTTPS requirement; other domains stay under ATS. **Malformed Server Address format**: iOS `.textContentType(.URL)` or pasting can produce `host://host:port`, sending requests to port 80 with ECONNREFUSED. Fix: `correctMalformedServerURL` corrects the malformed form; `ensureServerURLHasScheme` prepends `http://` when http/https is missing; correction happens on **lose focus** (`@FocusState` + `onChange`) to avoid rewriting per character; the keyboard `submitLabel(.done)` shows Done.

## Decision Records

(Technical decisions made during implementation are recorded here)

## API Verification (localhost:4096)

- **GET /project**: ✅ returns `Project[]` with id/worktree/vcs/time
- **GET /session?directory=&limit=**: ✅ filters sessions by worktree, limit defaults to 100
- **GET /global/health**: ✅ `{ healthy, version }`
- **GET /config/providers**: ✅ returns `providers: array` (not dict), each item carrying `id`, `name`, `models: { modelID: ModelInfo }`. iOS parsing fixed.
- **GET /agent**: ✅ returns `[AgentInfo]` with name/description/mode/hidden/native fields. The iOS side filters mode=subagent.
- **Import from Server**: depends on config/providers; should import fine after the parsing fix.

Current model presets (4):
| Display name | providerID | modelID |
|----------|------------|---------|
| GLM-5.1 | `zai-coding-plan` | `glm-5.1` |
| GPT-5.4 | `openai` | `gpt-5.4` |
| GPT-5.3 Codex | `openai` | `gpt-5.3-codex` |
| DeepSeek | `deepseek` | `deepseek-v4-pro` |

Agent prefill (5, OpenCode-Builder default):
- OpenCode-Builder (mode=all)
- Sisyphus (Ultraworker) (mode=primary)
- Hephaestus (Deep Agent) (mode=primary)
- Prometheus (Plan Builder) (mode=all)
- Atlas (Plan Executor) (mode=primary)

## Diff Issue

Measured against a live server, `GET /session/:id/diff` returns `[]` even for sessions with write operations. GH #10920 and others suggest this may be an OpenCode server-side session_diff tracking problem, and the official web client may hit it too. Not fixed for now, pending a server-side fix.

## Tool Card Rendering Redo (design only, not implemented)

Added a "tool card rendering redo" section at the end of design.md. **Note: a pixel-art style was explored initially and abandoned; OpenCode as a whole does not go pixelated**. What is appealing is that **way of organizing information**, not the pixel texture. **Design + mockups only, no code changes**; implementation goes to a later PR.

Three concrete changes:
1. **Distinguish who is speaking**: user messages keep the blue left bar; OpenCode replies **drop the avatar** but add an "OpenCode" text title + **keep the existing model small print** (untouched). The two are clearly separated by different visual styles.
2. **File cards in a 2-column grid**: patch/edit/write/read → file cards (file icon + file name + chevron) laid out in a 2-column grid.
3. **Merge into "N tool calls"**: other tools → `▸ 3 tool calls`, expandable to see each one inside.

Layout: layout-first near-chronological order (adjacent same-type items aggregate), with no grouping and no section headers. Boundaries: no pixel-art style, the model selector stays untouched, no user avatar in the top-right corner, and AI working keeps the existing subtle gold animation.

Mockup at `docs/design_images/tool_cards_chronological.png` (generated by gpt-image-2).
