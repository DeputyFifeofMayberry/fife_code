# Lessons — OpenCode iOS Client

> Reusable lessons distilled from implementation and code review work

## 0. Change workflow: align the docs first, then change the code

A stable, reusable engineering workflow, especially suited to this project's PRD/RFC-driven, fast-iterating collaboration style:

1. **Decide first whether the PRD is affected**: any change that touches product behavior, interaction logic, or feature scope (even a minor iPad UI tweak) starts with updating `docs/OpenCode_iOS_Client_PRD.md`.
2. **Then decide whether the RFC is affected**: if the change alters the technical approach, architecture constraints, or delivery phases, update `docs/OpenCode_iOS_Client_RFC.md` at the same time.
3. **Implement code against the docs**: code strictly according to the established documents, and write any design corrections made along the way back into the docs promptly.
4. **Fill in test coverage**: guard business logic that suits unit testing against regressions with unit tests; for UI-level changes, at least cover the key pure-logic tests and model decoding tests.
5. **Make sure build and tests are green**: finish by running `xcodebuild build` and then `xcodebuild test`, and confirm the main flows have no regressions.

Lesson: record the "why" behind decisions in the PRD/RFC, and let the code focus on the "how". This cuts communication and maintenance cost by a large margin, whether for code review, tracing problems, or later iterations.

## 1. Verify the API directly instead of writing code first and guessing

**Scenario**: while investigating the SSE event format, we needed to pin down the actual response data structure of OpenCode `/global/event`.

**Antipattern**: make subjective assumptions and write parsing code first, then run the iOS client and reverse-engineer the response format from logs.

**Correct approach**: connect straight to the server and measure with a command line tool such as `curl`. For example:

```bash
curl -s -N -H "Accept: text/event-stream" "http://192.168.180.128:4096/global/event"
```

This immediately confirms the actual output is `data: {"payload":{"type":"server.connected","properties":{}}}`, which shows directly that it is single-line JSON.

**Lesson**: when integrating or investigating an external API, always capture traffic or test from the command line first. Replacing subjective assumptions with real responses saves a large amount of wasted coding and debugging.

---

## 2. Tests first, small fast steps

**Scenario**: refactoring core logic such as splitting the AppState module, extracting PathNormalizer, and session filtering.

**Approach**:
- Before splitting, add test cases for the key paths so the core business logic is covered.
- Use tests to pin down the expected behavior first, then start adjusting the code structure.
- Commit promptly after each independent subtask and update `WORKING.md` at the same time.

**Lesson**: thorough tests are the safety net for refactoring, and small commits keep code review clearer and make rollback easier when problems appear.

---

## 3. Organize work with a task list so nothing is duplicated or dropped

**Scenario**: Code Review 1.1–1.4 involved many interleaved tasks, including adding tests, splitting modules, SSE handling, session filtering, and extracting PathNormalizer.

**Approach**: keep a structured task list to track the whole effort, and check off and archive each item as it advances, preventing omissions and duplicate work.

**Lesson**: breaking a complex multi-goal effort into a countable, trackable checklist effectively avoids the situation of dropping a key point halfway through.

---

## 4. Measured API behavior vs spec assumptions

**Scenario**: the standard SSE spec includes mechanisms such as multi-line data, `event:` fields, and comment keep-alives, and code review suggested fully supporting the standard.

**Approach**: capture traffic to measure the server's real behavior and confirm it only pushes single-line `data:`. The existing lean implementation fully satisfies the business need, so there is no reason to over-wrap it for now.

**Lesson**: theoretical specs and real system implementations often diverge. Verify the real data flow before building, spend the effort where it matters, and avoid premature over-design.

---

## 5. Keep the external API unchanged when splitting

**Scenario**: splitting the huge AppState into dedicated stores such as SessionStore, MessageStore, FileStore, and TodoStore.

**Approach**: forward through computed properties on AppState, fully preserving existing APIs such as `state.messages` and `state.sessions`, so the views above need zero changes.

**Lesson**: internal refactoring should keep the public interfaces above as stable as possible and narrow the surface of code changes, which minimizes regression risk.

---

## 6. SSE filtering with multiple sessions

**Scenario**: with multiple concurrent sessions, an incoming `message.updated` event that is not validated and filtered by sessionID pollutes data across sessions.

**Approach**: at the event dispatch layer, strictly extract the `sessionID` from the event payload for the decision, and only respond to and update data for the currently active session.

**Lesson**: in multi-session or similar multi-tenant architectures, events must carry a unique scope identifier (such as a Session or Tenant ID), and the client must filter precisely before consuming them.

---

## 7. Consolidate cross-module logic into a single layer

**Scenario**: path normalization logic used to be scattered across Message.swift and string-trimming code in various views, which easily produced diverging standards.

**Approach**: pull all path handling into the `PathNormalizer` utility, which centrally parses and handles formats such as a/b prefixes, `#` anchors, and `:line:col` line and column numbers.

**Lesson**: any cross-module general rules or data-cleaning logic should be gathered into a single-responsibility layer and maintained there, avoiding the redundancy and inconsistent behavior that scattered implementations bring.

---

## 8. @MainActor and testability

**Scenario**: `shouldProcessMessageEvent` was originally declared inside AppState, and calling it directly in unit tests triggered a main actor isolation error (main actor-isolated).

**Approach**: explicitly mark the stateless pure-logic method as `nonisolated` so it can be called synchronously and directly in a test context.

**Lesson**: pure computation or decision logic that needs unit test coverage should be extracted into nonisolated or static methods where possible, removing the unnecessary coupling to the MainActor lifecycle and concurrency environment.

---

## 9. SSE-first still needs a one-shot compensating sync alongside SSE

**Scenario**: an iOS app can lose SSE events during the gap whenever it switches between foreground and background, the network jitters, the user switches sessions, or the connection drops and reconnects.

**Approach**:
- In the normal state, rely fully on SSE pushes for increments and avoid always-on high-frequency polling that consumes resources.
- At key lifecycle points (such as a successful SSE reconnect or the user entering a session), trigger one lightweight full reconciliation (bootstrap): run `loadMessages + refreshPendingPermissions`.
- Flesh out the bootstrap trigger-context logging to record the reason, elapsed time, message count, and permission items.

**Lesson**: mobile realtime communication should combine incremental events as the main channel with full reconciliation at key points as compensation, keeping power low while preserving system stability.

---

## 10. SSH security defaults: TOFU + mismatch hard fail

**Scenario**: configuring `acceptAnything` on an SSH tunnel effectively gives up all authentication of the remote host.

**Approach**:
- On first connection: use TOFU (Trust On First Use) and persist the host key per host:port.
- On later connections: as soon as the public key fingerprint mismatches, block the connection immediately (hard fail) and clearly warn the user about a possible MITM attack or host reinstall.
- In the UI, show fingerprint details and provide an entry point for resetting the trusted host.

**Lesson**: when a remote communication feature ships, its security baseline must land with it. Getting a connection through is only the first step; a trusted channel is the delivery bar.

---

## 11. Gate-style test-first for complex refactoring

**Scenario**: deeply splitting AppState touches multiple chains, including state machine transitions, SSE dispatch, and UI refresh rules, so the regression risk is very high.

**Approach**:
- Break the work into progressive iteration rounds, Iteration A/B/C/D, each strictly following the principle of completing behavior tests first and then restructuring the code.
- Set an explicit acceptance gate for each round (a gate such as all behavior tests passing) and only advance to the next round once it is met.
- After each round, record it thoroughly in `WORKING.md`, clearly listing the new test points and the risk assessment conclusions.

**Lesson**: complex refactoring should never be one sweeping change; break it into verifiable incremental migrations. Objective test gates are far more trustworthy than subjective experience and intuition.

---

## 12. Activity text needs debounce semantics instead of blind realtime refresh

**Scenario**: during tool calls and model reasoning, high-frequency text changes make the interface jitter badly and create serious visual noise.

**Approach**:
- Pull the derivation of text state and the debounce logic together into the lower logic layer.
- Define clear refresh rules: changes within a 2.5s window update with a delayed smooth transition, and changes beyond the window take effect immediately.
- Define the calculation priority for elapsed-time data in the completed and running states, so misleading fake-precision numbers are not displayed.

**Lesson**: readability of information is also a key part of the realtime interaction experience. For users, a stable and trustworthy presentation of state is worth far more than refreshing on every tiny change.

---

## 13. SSH UX should put the user's next action on screen

**Scenario**: when configuring an SSH tunnel, users easily get stuck: the toggle is on but the connection fails, or they do not know where to go next.

**Approach**:
- Generate the full SSH command line on screen with one-tap copy, removing the mental burden of assembling the command by hand.
- Keep the public key copy entry permanently visible instead of tying it to the toggle's enabled state.
- Give explicit guidance in the SSH configuration area: after enabling the configuration, go back up and tap `Test Connection` to complete the connectivity check.

**Lesson**: for a configuration screen, complete fields are only part of the value; the screen must also guide users smoothly through the entire flow. Stating the explicit next action in the UI copy greatly reduces interaction friction.

---

## 14. For long sessions on weak networks, do message paging before redoing rendering

**Scenario**: after the view rendering optimizations, interactions were already smooth enough on a LAN, but loading the first screen of a long session over the WAN or through an SSH tunnel still showed noticeable delay.

**Approach**:
- First verify that the backend supports the `GET /session/:id/message?limit=` endpoint, then change the client's initial load strategy to fetch only the most recent 3 interaction rounds (6 messages) by default.
- Provide a clear pull-to-load-older-messages interaction that walks back through history in fixed steps (+6).
- Localize the paging hint copy and loading states so users do not misread the behavior as older data being lost.

**Lesson**: on weak, high-latency links, first-screen loading is usually bottlenecked by transfer size and network round-trip cost (RTT). Landing controlled message paging first usually brings larger, more stable performance gains than digging into fine-tuning in the view rendering layer.

---

## 15. Clarify message semantics before designing the limit strategy

**Scenario**: discussions of message truncation often hit a counting question: if one model interaction includes 10 tool calls and 1 final answer, does the whole thing count as 11 messages or 1 message?

**Approach**:
- Align strictly with the server's underlying data model: each tool call is a `part` under a message rather than an independent `message` entity.
- Make clear that the paging parameter `limit` controls the number of top-level messages, not the tool-call granularity.
- Unify this definition in the PRD, RFC, and other spec documents to remove later misreading of "3 rounds correspond to 6 messages".

**Lesson**: before designing paging and truncation strategies, clarify and unify the counting semantics of the underlying data entities first. Otherwise product and technical discussions keep burning effort on the ambiguity of one item visually versus several items in the logical data.

---

## 16. Session and Project: creation allowed only on Server default

**Scenario**: after creating a new session in the iOS client, the freshly created session would inexplicably disappear when opening the session list or when the app went to the background and came back.

**Root cause**: the server's `POST /session` endpoint does not accept a `directory` parameter, so sessions are always created under the server's current default project (decided by the CLI start path or the last action in the Web/TUI). The Project switcher on the iOS side only affects the `GET /session?directory=X` list filter and cannot change where new sessions are actually created. When the project selected in the client differs from the server's default project, the new session lands in the server's default project, cannot appear in the current filtered list, and "disappears" after a refresh.

**Attempts made**:
1. **mergeCurrentSessionIfMissing**: during `loadSessions`, if the current session is missing from the list, fetch it separately and force-prepend it to the front of the list → treated the symptom only, and `GET /session/:id` can return 404 outright when queried across projects.
2. **Filter session.updated by project**: keeps session change events from other projects out of the current list → reasonable design, kept.
3. **A Settings warning pointing users to the Web UI to switch** → did not hold up: the Web UI also cannot change the server's working directory remotely.
4. **Remove project selection (rollback)** → not adopted: keeping multi-project list filtering still has practical value.

**Final approach**: the new-session entry is available only when Server default is selected. When the user switches to a specific project, the new-session button is grayed out and an info icon appears next to it; tapping it explains that to create a session in another directory, OpenCode must be started from the terminal with the target working directory, after which switching back to Server default in the client makes creation work normally.

**Lesson**: in a multi-project system where the underlying API does not yet support specifying a working directory at creation time, constrain the creation entry at the interaction layer rather than patching things up afterwards at the data layer in fragile ways. Keep the semantic boundary between "list filtering" and "session creation" clearly decoupled, so users do not form the wrong mental model that selecting a project means sessions can be created there.

---

## 17. Relative path normalization must collapse `..` properly instead of just deleting it

**Scenario**: when viewing deep documents such as `docs/reports/*.md` in the iOS client's Markdown preview, images referenced through relative paths (for example `![x](../assets/foo.png)`) failed to load, while the text layout was completely fine.

**Root cause**: `MarkdownImageResolver` first joins the document's directory with the relative path into `docs/reports/../assets/foo.png` and hands it to `PathNormalizer.resolveWorkspaceRelativePath(...)`. The old implementation simply filtered out the `.` and `..` segments without folding the path under standard filesystem semantics, so the path was resolved incorrectly to `docs/reports/assets/foo.png` and a file path that does not exist was requested.

**Final approach**: fixed at two layers. In the first layer, `PathNormalizer.normalize()` was refactored into a stack-based path folding algorithm: normal path segments are pushed in order, `.` is skipped, and `..` pops the top of the stack when it is non-empty. This way `docs/reports/../assets/foo.png` folds accurately to `docs/assets/foo.png`, while path traversal past the workspace root is still effectively blocked. In the second layer, the Markdown preview in `FileContentView` no longer relies on `MarkdownUI`'s default network image loader to guess relative paths; it explicitly injects `imageBaseURL` and a custom `WorkspaceMarkdownImageProvider`, and reads image data inside the workspace through `state.loadFileContent` for controlled rendering.

**Lesson**: security handling for relative paths is never solved by simply "stripping dangerous characters". Crudely trimming `..` directly breaks legitimate relative path levels and easily causes hidden failures in document image rendering, patch-related jumps, and relative references inside code. In addition, third-party Markdown rendering engines usually assume their default image loading strategy receives a final usable network URL; to reliably support relative-path resources inside a project, the client must take over base URL maintenance and a custom resource loader itself and cannot rely on the implicit behavior of the default network loader.

---

## 18. A streaming reasoning parser is a one-shot state machine: a literal end tag inside thinking permanently terminates reasoning early

**Scenario**: streaming parsers such as SGLang's `--reasoning-parser qwen3` are **one-shot** state machines. During the thinking output phase, the first `</think>` detected (wherever it appears within a line) permanently turns off reasoning mode, and every streaming chunk after that is passed through as ordinary body text. If the model outputs a literal `</think>` string inside its thinking content (for example while analyzing and discussing that tag itself), the thinking stream ends early and unexpectedly, and the remaining unfinished thinking content plus the real `</think>` tag all leak into the body content stream.

**Approach**: when debugging "thinking content leaking into the body text", first read the serving layer's parser implementation source to confirm how the state machine works (whether it triggers in one direction, the exact end-tag matching rules, and so on), then cross-check with log data: whether the reasoning part is cut off mid-sentence, and whether the text part continues exactly from the second half of the same sentence.

**Lesson**: the tokenizer cannot tell "the tag discussed as ordinary text" apart from "the real end-of-thinking marker" at the bottom layer, and this kind of ambiguity usually has to be absorbed in the client's normalization layer. Before starting an investigation, understand the serving layer parser's state machine transitions first, so no effort is wasted digging through the server business layer or the model training layer.

---

## 19. Client-side normalization is the right layer to fix model output quirks, and it must be fence-aware

**Scenario**: the server usually stores and forwards the model's raw output as-is (the extra blank lines and leaked thinking tags in the output are generation traits of the model itself; the server is not at fault); the same data renders fine on both Web and Android after each side applies its own display normalization. When one client renders badly, the root cause is usually that this client lacks the targeted data normalization logic, while the server and the model are fine.

**Approach**: normalize and clean text parts uniformly in the client's view rendering layer (trimming extra leading and trailing whitespace, filtering whitespace-only chunks, removing leaked thinking tags, and so on), and the normalization must be **fence-aware**: detect code fence syntax line by line (``` and ~~~), and never clean any tags inside a fence (including the fence marker lines themselves), because the server-side parser is completely unaware of code fences. In addition, normalization applies only to text parts of the assistant role; user messages are strictly kept as-is (so content in user input that discusses these tags is unaffected).

**Lesson**: client-side normalization is naturally idempotent (no side effects for models with well-formed output), has the smallest blast radius, and keeps behavior consistent with the Web and Android clients. For the output quirks of various models, prefer defensive fixes in the client rendering layer and avoid disturbing the server and model pipeline.

---

## 20. Session-specific vs systemic: distinguish with statistics from a clean session

**Scenario**: when hunting a defect in model output, it is easy to misread an artifact that only appears in one particular session as a systemic defect of the model everywhere (the think tag leak in this investigation actually came only from that session happening to discuss the tags themselves, with a frequency of 0 in other ordinary sessions).

**Approach**: pick a **clean session** (one that never touches the particular discussion topic and has enough samples, for example an ordinary session with 219 text parts) as the baseline control, and compare statistics item by item with the problem session (extra leading and trailing newlines, whitespace-only chunks, the share of chunks containing specific tags, and so on). If the baseline session shows 0 anomalies while the current session is significantly higher, the phenomenon is purely session-specific; only when the control group shows the same high-frequency anomalies can the problem be classified as systemic.

**Lesson**: before classifying a problem as a systemic defect, bring in baseline control samples that do not contain the interfering factor and run quantitative statistics. Without a rigorous control, simply seeing "lots of samples" does not lead to a "global systemic" conclusion.
