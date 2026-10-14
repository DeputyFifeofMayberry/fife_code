# Background Subagent Task Notification Rendering Design Draft

## Conclusion

When a background subagent completes, the server injects a **synthetic user message** into the parent session containing a `<task id=... state="completed">` XML envelope with a summary and the result body. The iOS client currently does not decode the TextPart `synthetic` field, so such messages render as raw XML inside a blue user bubble, one of the most glaring rendering flaws.

This UI element should be a **TaskNotificationCard**, the "subagent task receipt" card in the message stream: the collapsed view is a status icon + status label + task title, the result body renders as markdown inside the card, and expanding it offers one-tap opening of the subagent session to audit the whole run. It is not a user bubble (system-injected, not something the user said) and not a tool card (a tool card means "one call"; this card means "an async job delivered its result").

Recognition uses a double gate: the part carries `synthetic: true` **and** its text parses as a `<task>` envelope → render the card; parse failure safely falls back to today's rendering.

Scope is strictly task receipts. The server's other synthetic injection points (plan mode instructions, compaction continue, MCP resources, etc.) are explicitly out of scope, and the user bubble rendering logic is untouched; they are listed in the appendix as observation records only.

## Success Criteria

1. After a background task completes, a clearly-stated receipt card appears in the conversation (green completed / red failed); the collapsed view shows the task name and status and leaks no raw XML.
2. Tapping the card expands it to read the full subagent result markdown (including workspace link resolution and images); overly long results keep the existing 12k preview protection.
3. After expanding, tapping the button opens the subagent session, reusing the existing selectSession path.
4. On parse failure or an older server (payload without the `synthetic` field), behavior safely falls back to today: content is never swallowed and nothing crashes.

## Data Path (Evidence)

### How the Server Generates It

`opencode-official/packages/opencode/src/tool/task.ts`:

- `renderOutput()` generates a fixed XML envelope:
  ```
  <task id="{childSessionID}" state="completed|error|running">
  <summary>Background task completed: {description}</summary>   # failed on error
  <task_result> or <task_error>
  {markdown of the subagent's last text part}
  </task_result>
  </task>
  ```
- When a background task completes/fails, `injectBackgroundResult` injects a user message into the **parent session** via `ops.prompt`, with the text part carrying `synthetic: true`.
- When a background task starts, the parent message's `task` tool part carries `state.metadata = { parentSessionId, sessionId, model, background: true, jobId }` and the output is a `state="running"` envelope (not handled by this design, see the appendix).
- `TextPart.synthetic` is an optional boolean in the V1 API schema (`packages/schema/src/v1/session.ts:108`).

Live verification (2026-09-27, local 4096 server, `GET /session/:id/message`):

- The receipt is a **user-role** message with a single text part
- The part payload actually carries `synthetic: true`
- The body is a full `<task>` envelope; the part has no `time` field

### Current Client State

- The `Part` struct in `Models/Message.swift` does not decode `synthetic`.
- `MessageRowView.userMessageView` renders every user message's text part into the blue user bubble (`DesignColors.Brand.primary` fill + 4pt vertical bar on the left); XML text passes the `hasMarkdownSyntax` check and goes through MarkdownUI, displaying like raw HTML-ish text.
- The `task` tool part lands in the "N tool calls" collapsed row with boilerplate "Background task started..." output text (not handled by this design).

## Change List

### 1. Model layer: decode `synthetic`

Add to `Part`:

```swift
let synthetic: Bool?
```

`decodeIfPresent` semantics, defaulting to `false` when absent; a `Part.isSyntheticText` convenience property (`type == "text" && synthetic == true`). When the server omits the field, behavior is exactly the same as today.

### 2. Parsing layer: `TaskNotificationParser`

Pure functions, in the same style as `ToolCardClassifier` (unit-testable, no View dependencies):

```swift
struct TaskNotification {
    let sessionID: String        // <task id>
    let state: TaskState         // completed | error | running
    let summary: String?
    let resultText: String       // <task_result>/<task_error> body
    var isFailed: Bool { state == .error }
}

enum TaskNotificationParser {
    static func parse(_ text: String) -> TaskNotification?
}
```

Parsing rules: locate the outermost `<task ...>` opening tag (leading whitespace allowed) and the `</task>` closing tag; take `id` / `state` from the opening tag attributes and the body from the `<task_result>` or `<task_error>` range. Use range-based location throughout instead of a global regex, so nested angle brackets in the result body (such as XML fragments the subagent itself output) cannot cause a mis-slice. Return `nil` if any step is missing.

### 3. Rendering layer: `TaskNotificationCardView`

Place it in `Views/Chat/`. `MessageRowView`'s handling of user messages becomes:

- Non-synthetic text parts → the user bubble as usual (zero rendering logic changes);
- synthetic text part that `TaskNotificationParser` parses successfully → `TaskNotificationCardView`;
- everything else (including synthetic-but-unparseable and non-synthetic) → current rendering, safe fallback.

Adjust `copyableText(for:)` in step: a receipt message that parsed successfully copies the result body instead of the XML; the user bubble's copy content is unaffected (this design does not change user bubble logic).

## UI Spec (TaskNotificationCard)

### Visual

- Card background: `DesignColors.Neutral.text.opacity(DesignColors.surfaceFill(for:))`, matching ToolPartView; corner radius `DesignCorners.medium`, padding `DesignSpacing.cardPadding`.
- Header row (collapsed-view info, not foldable):
  - Status icon: completed → `checkmark.seal.fill` + `DesignColors.Semantic.success`; error → `xmark.seal.fill` + `DesignColors.Semantic.error`.
  - Status label: L10n-localized (`taskNotificationCompleted` / `taskNotificationFailed`), generated from `state`; **do not** show the English prefix "Background task completed:" from the summary as is; the description left after stripping the prefix becomes the task title.
  - Task title: single-line truncation.
  - Right side: expansion chevron (provided by DisclosureGroup, tinted brand primary).
- Expanded content: `resultText` goes through the existing `markdownText` path (workspace link resolution, image parsing, `textSelection(.enabled)`), with overly long text protected by `LargeMessagePreview` (>12k truncation + hint); an empty result shows the placeholder caption "No output".
- Default expansion state: **collapsed by default** (user decision 2026-09-27, replacing the earlier "expand at ≤500 characters" design). The main agent's following messages usually carry the digested conclusions; the card body is reference material that the user taps to expand. Applies to both iOS and Android.
- `accessibilityIdentifier("task-notification-card")`; the jump button gets `accessibilityIdentifier("task-notification-open-session")`; UI tests anchor on these two.

### Interaction

- **Primary action = expand/collapse**: tapping the whole card (header + content area) toggles expansion, consistent with ToolPartView / ThinkingCard. Tap-to-jump is not the primary action: reading the result is the high-frequency intent and expansion is reversible and zero-cost, while jumping switches the current session context and is a low-frequency audit action. Bind the high-frequency action to the primary gesture.
- **Jump = a labeled button inside the expanded area**: one button at the bottom of the expanded content, text "Open subagent session" (L10n `taskNotificationOpenSession`), brand primary color, `DesignTypography.micro`. The button's hit area takes priority over the card's toggle gesture (a SwiftUI Button naturally wins inside a tappable container, same mechanism as the file-open button inside the ToolPartView label).
- **No jump entry in the collapsed state**: jumping requires expanding first, then tapping the button, two taps. Acceptable for a low-frequency action; the header stays quiet (no unlabeled icon buttons) to preserve collapsed-view information density.
- **Jump behavior**: `selectSession(subagentSessionID)` + switching project directory when needed (same path as session_finder's "Continue in This Session"); if the target session was deleted, take the existing error path (`state.sendError`); the card itself is unaffected.
- Message row context menu: synthetic receipt messages do not show Edit-from-here (not a user turn); Fork stays.

## Edge Cases

- **Streaming truncation**: a mid-stream SSE part is incomplete XML (no `</task>`) → the parser returns nil → render as today for now; once the part updates to complete, re-render as the card. Part ids are stable, so the replacement render leaves no state behind.
- **Older server**: payload without `synthetic` → decodes to nil → non-synthetic → behavior identical to today (user bubble + raw text); content is never silently swallowed.
- **User manually pastes envelope-like text**: no `synthetic` marker → the double gate fails → rendered as a normal user message, never hijacked into a card.
- **Multiple background tasks**: each notification is its own message → its own card; supported naturally.
- **Nested XML inside the result**: range-based location of the outermost envelope (see parsing rules), covered by unit tests.
- **Error state**: `<task_error>` tag + `state="error"`, red icon, body still rendered as markdown.
- **Missing summary**: the title falls back to the short form of the task session ID.

## Implementation Scope

Single phase:

1. `Part.synthetic` decoding (`decodeIfPresent`).
2. `TaskNotificationParser` + unit tests.
3. `TaskNotificationCardView`: completed/error states, expand/collapse (collapsed by default), markdown rendering, jump button.
4. `MessageRowView` routing + `copyableText` fix.
5. L10n keys: `taskNotificationCompleted` / `taskNotificationFailed` / `taskNotificationOpenSession` / `taskNotificationNoOutput`.

Explicitly out of scope this phase: the `task` tool part's running indicator and metadata decoding, and any hiding or styling of other synthetic content inside user bubbles.

## Test Plan

- `TaskNotificationParserTests` (unit): completed / error / running / missing summary / truncated (no closing tag) / non-task text → nil / nested angle brackets in result / empty result / surrounding whitespace.
- `MessageRowView` rendering unit tests: synthetic + envelope message → card (a11y id assertion); same text without synthetic → user bubble (fallback path); `copyableText` on a receipt message returns the result body.
- UI (Tier 4): tapping the card expands and shows markdown; after expanding, tapping the jump button successfully switches to the subagent session (asserted via the child session title "…(@general subagent)" or message content).
- Build and test run serially per the AGENTS.md convention (build → test).

## Appendix: Other Observed Synthetic Injection Points (out of scope)

The remaining `synthetic: true` generation points in `packages/opencode/src`. This design does not handle them; if any becomes a rendering defect later, handle it with the same pattern (the already-decoded `synthetic` field + type-specific rendering) rather than inventing another mechanism.

| Location | Content | Shape |
|---|---|---|
| `session/reminders.ts:34/45/64` | plan mode instructions (PROMPT_PLAN / BUILD_SWITCH / PLAN_MODE) | appended to the user's last message |
| `session/compaction.ts:541` | "Continue if you have next steps..." (with `metadata.compaction_continue`) | standalone synthetic user message |
| `tool/plan.ts:68` | "The plan at X has been approved, execute the plan" | standalone synthetic user message |
| `session/prompt.ts:447` | "Summarize the task tool output above and continue" | standalone synthetic user message |
| `session/prompt.ts:485` | "The following tool was executed by the user" + tool part | boilerplate text + tool part |
| `session/prompt.ts:711+` | "Reading MCP resource: X (uri)" / resource body / omitted hint | appended to the user message |
