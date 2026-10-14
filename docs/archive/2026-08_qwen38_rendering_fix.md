# qwen38 rendering issue investigation and fix work record

Records the investigation, root cause, and fix for the OpenCode iOS client producing large amounts of extra carriage returns in output under qwen-3.8-27b (the qwen38 preset), plus occasional `<think> / </think>` thinking tags leaking into the body text.

## Conclusion first

**The main bug is in the iOS client rendering layer; the OpenCode server is not at fault.**

With the same data returned by the server, Web and Android both render correctly (no extra carriage returns, no think tag leaks); only iOS displays the leading / trailing newlines in text parts, newline-only parts, and think tags leaked into text parts as-is. The fix direction is to have the iOS client normalize text parts the way Web / Android do: trim, skip whitespace-only parts, and remove thinking content leaked into text parts.

Two boundary notes (corrected after independent review):

- The newlines themselves are the output shape of qwen38 / SGLang. The server stores and returns them as-is, so this is iOS missing the normalization Web / Android already have rather than a server "bug".
- The think tag leak is **not** a systemic qwen38 problem: a clean qwen38 session (`ses_fcfbff756ffe`, 219 text parts) contains 0 think tags. Most think tags in the current session came from this very investigation "discussing" those tags, plus a small number of `<think> / </think>` splitting tails.

## Symptoms

- When chatting with qwen38 (`RadixArk/Qwen3.8-27B-NVFP4`, SGLang endpoint `http://none.tail63c3c5.ts.net:8002/v1`) in the iOS app, replies contained many blank lines / extra carriage returns and occasionally literal `<think> / </think>` tags.
- Other models, and qwen38 on Web / Android, showed none of this.
- The user initially suspected an iOS client bug and asked to investigate first without touching code.

## Investigation

### 1. Data layer: confirm the text parts returned by the server really carry these artifacts

Ran cross-model statistics over the `message` / `part` tables of `~/.local/share/opencode/opencode.db` (excluding the current investigation session itself to avoid self-contamination):

| Metric | qwen38 | Other models |
|---|---|---|
| text parts starting with `\n` | 99% | 0% |
| text parts ending with `\n` | 92% | ~0% |
| text parts that are newlines only (no real content) | 65% | ~0% |
| text parts containing `\n\n\n` | 24% | very few |
| average newlines per text part | 12.15 | 2.5–3.2 |

Cross-checked with the live API (`GET /session/:id/message`, Basic auth `opencode:<OPENCODE_PASSWORD>`; the credential is `OPENCODE_PASSWORD` in the workspace `.env`): the current session (`ses_fcfbd043bffe417xHHYrV0gw37`, active, so counts are a moving target) had 58 text parts containing think tags at review time. But compared against a clean qwen38 session (`ses_fcfbff756ffe`: 219 text parts, 161 whitespace-only, **0 think tags**), most think tags in the current session came from this investigation discussing the tags themselves, plus a small number of `<think> / </think>` splitting tails (SGLang streaming slicing at the wrong spot on the reasoning / content boundary). So the think tag leak is **session-specific + a few splitting tails**, and not a systemic qwen38 output problem.

The server only stores and returns model output as-is and does no normalization; normalization is the client's responsibility.

### 2. Comparison: how Web / Android render the same data correctly

- **Web** (`opencode-official/packages/session-ui`):
  - `message-part-text.ts:2` applies `.trim()` to the part text;
  - `message-part.tsx:717` and `session-turn.tsx:108,311` check with `part.text?.trim()`, and whitespace-only text parts are simply not rendered;
  - DOMPurify in `markdown-cache.tsx` does not list `think` among kept tags, so unknown tags get stripped.
  - In short, Web explicitly does trim + skip empty text parts + strip unknown tags.
- **Android** (`opencode_android_client/.../ChatMessageContent.kt`): text parts go to a CommonMark-family `Markdown` renderer (`com.mikepenz.markdown`, dispatched at `:436`, rendered at `:776`); whitespace is collapsed and empty paragraphs produce no visible blank lines, so the "pile of carriage returns" never appears.

Both ends prove this data can be rendered correctly and the problem is in the iOS rendering layer.

### 3. Locating the iOS rendering defect (`MessageRowView.swift`)

- `buildAssistantBlocks(parts:)`: `isReasoning` parts are skipped (rendered as the thinking block); `isText` parts go to `markdownText`.
- `markdownText` → `shouldRenderMarkdown` / `hasMarkdownSyntax`: returns false for whitespace-only text (empty after trimming), falling through to the native `Text(text)`.
- The native `Text` renders every `\n` as a visible blank line → the user sees a "pile of carriage returns".
- `<think> / </think>` tags leaked into text parts are rendered as literal text.

### 4. SGLang reasoning parser cross-validation (2026-08-23, SGLang source at `none:~/co/llm_serving`)

Launch parameters of the running SGLang endpoint `none.tail63c3c5.ts.net:8002` (`serve_llm.sh`, matches the live process): `--reasoning-parser qwen3 --tool-call-parser qwen3_coder --speculative-algorithm DFLASH --speculative-num-draft-tokens 8`.

In `vendor/sglang/python/sglang/srt/parser/reasoning_parser.py`, `Qwen3Detector` (:355) extends `BaseReasoningFormatDetector` (:62), and the streaming state machine is **one-shot**:

- :206-211: `stripped_think_start` is a one-shot flag; only the first `<think>` is stripped;
- :214-225: the **first** `</think>` encountered permanently closes reasoning (:220 sets `_in_reasoning = False`, and it never returns to True after that);
- :260-263: after leaving reasoning, all content is passed through as `normal_text` as-is, including literal `<think>` / `</think>`.

The OpenAI-compatible endpoint (`serving_chat.py` constructs the `ReasoningParser` at :222-238 and emits `reasoning_content` at :738 / :1923) maps `reasoning_text` to `reasoning_content` (stored by OpenCode as a reasoning part) and `normal_text` to `content` (stored by OpenCode as a text part).

Data cross-validation (189 assistant messages in the current session):

- The part sequence across all 189 messages is uniformly `step-start / reasoning / text / step-finish / tool...`; each message has exactly 1 reasoning part + 1 text part;
- 0 of the 189 reasoning parts contain a literal think tag; 62 text parts (33%) contain tags, and 61 of those contain at least one `</think>` **on its own line** (outside code fences);
- **Decisive evidence**: in messages whose text part contains a leak, the reasoning part is cut off mid-sentence and the text part continues exactly from the second half of the same sentence. Example: one reasoning part ends with "...thought output uses `" (cut mid-sentence, backtick unclosed) and the same message's text part starts with "` tags. In OpenCode, reasoning parts are separated...". SGLang split that one sentence in half.

The mechanism closes the loop: the model outputs a literal `</think>` inside its own thinking (this session was investigating the think tag bug, so the model's thinking repeatedly discussed / restated these tags); the SGLang state machine takes that literal `</think>` as the real end marker → reasoning ends early → the remaining thinking + the real `</think>` all leak into the content stream → OpenCode stores it as-is as a text part → iOS renders it as-is. A clean session (no literal `</think>` in thinking) has 0 leaks; this session leaks at 33%, directly tied to the probability of writing a literal `</think>` while thinking. SGLang's tokenizer layer cannot distinguish "the model outputting the tag as text" from "the model ending its thinking"; that ambiguity can only be absorbed in the client normalization layer, so fixing the iOS rendering layer is the right place.

Data verification of the "response starts with a code block" observation: only 1 of the 189 text parts has raw text starting with ```, and 0 after simulating the second fix batch. This is mostly a qwen38 output style preference (fond of starting with code), not a boundary bug; but leaked thinking tails often contain code snippets, which on iOS does create the impression of "a reply starting with code".

## Root cause

The iOS client does not normalize text parts the way Web / Android do. Specifically:

1. **Whitespace-only text parts fall through to the native `Text` (primary cause)**: `hasMarkdownSyntax` returns false for text that is empty after trimming, which lands in the native `Text`, rendering every `\n` as a visible blank line.
2. **Leaked thinking content rendered literally (secondary, session-specific)**: leaked thinking content and literal `<think> / </think>` in text parts are displayed without any handling (for the SGLang-side mechanism see Investigation §4).

(The server returns model output as-is and Web / Android each normalize on their side, so the problem exists only at the iOS layer.)

## Fix (branch `fix/whitespace-text-parts`)

### Batch 1: whitespace part filtering + trim (done, verified)

`MessageRowView.swift`:

- Added `isRenderableText(_:)`: returns false for whitespace-only input.
- `buildAssistantBlocks(parts:)` was extracted into a static testable function; text parts pass through `isRenderableText` first and whitespace-only parts are skipped outright (no longer producing blank lines and no longer breaking tool card merging).
- `markdownText` trims before rendering, removing leading / trailing newlines.
- `AssistantBlock` changed from private to internal for testing.

`OpenCodeClientTests.swift` (`MessageRenderingHeuristicTests`) added 4 tests:

- `renderableTextRejectsWhitespaceOnlyParts`
- `renderableTextAcceptsContentWithSurroundingWhitespace`
- `assistantBlocksSkipsWhitespaceOnlyTextParts`
- `assistantBlocksMergesToolRunAcrossWhitespaceTextPart`

Verification: simulator build passed; all 11 tests in `MessageRenderingHeuristicTests` passed. The full suite had 2 pre-existing UI test failures (`testSettingsShowsThreeSpeechStrategiesAndRealtimePrompt`, `testToolCardsFixtureRendersFileCardsAndMergedToolCalls`), unrelated to this change.

Known gaps (flagged by independent review, not fixed):

- `copyableText` only filters `isEmpty`: `"\n\n\n"` survives and then gets joined by `"\n\n"`, so copy / text selection still produces a pile of blank lines.
- `selectionText` / the text selection sheet lack the same filtering.
- The user bubble adds padding per text part: after an empty part becomes `EmptyView`, up to 20pt of blank space can remain (the assistant path already skips this; the user path does not).
- `StreamingReasoningView` still uses the raw `Text`: reasoning parts currently contain no think tags, but a future leak would land on the thinking bar.

### Batch 2: stripping leaked thinking content (done 2026-08-23, plan revised after Grok review)

Plan evolution: the original plan was "strip complete blocks + keep only content after the last `</think>`" → independent review changed it to a DOMPurify-style "strip tags only, keep inner text" → after discussing with the user on 2026-08-23 the focus was corrected again:

**What the user cares about is thinking content appearing in the reply body, rather than literal tags being visible.** Content that belonged in the thinking block leaking into a text part and being displayed as body text is the core problem. The DOMPurify-style "strip tags, keep content" leaves the leaked thinking content in the body and does not solve the core problem, while normal replies that happen to be discussing these tags are not the user's concern. So the plan changed to **deleting leaked thinking content from assistant text parts** (more than just stripping tags):

- Extracted `static func normalizedText(_:)` (unit testable), applied only to **assistant text parts**; user messages are never modified (when the user discusses the tags themselves they must be preserved as-is; the literal `</think>` in this session's user messages is a ready example):
  1. Detect code fences line by line (``` or ~~~, up to 3 leading spaces allowed; the opening fence line may carry an info string, and the closing fence line must be pure fence characters at least as long as the opening fence); tags inside a fence (including the fence lines themselves) are never touched. The server-side parser has zero awareness of code fences, so client normalization must understand fences itself;
  2. Delete the thinking tail (main rule, **run first**): if there is a </think> on its own line (outside fences), cut from the start of the text through **the last** such closing tag (inclusive). SGLang only recognizes the first close while in reasoning (`.find()`, any position, mid-line included), so a literal close in the model's thinking ends reasoning early, and the remaining thinking + the real close all land in the text part; the real close is always the last standalone-line close in the part, and the real response (if any) comes after it; if the result is empty after the cut, the part is not renderable;
  3. Delete the open tail: if the remainder still has a <think> on its own line (streaming truncation, no close after it), cut from that line to the end of the text; finally trim leading and trailing whitespace.
  4. **Ordering decision** (key finding from the Grok review): do not delete "complete open..close blocks" first and then cut tails. If the thinking tail contains a literal open example block with no literal close after it, "delete blocks first" pairs the real close with its own literal open and deletes both, leaving the earlier leaked thinking in the body. Cutting to the last close first handles both cases correctly; the cost is described under "Known trade-off".
- **Discrimination rule**: only `<think>` / `</think>` **on their own line** (outside code fences) are treated as boundary markers; tags appearing mid-line (usually inside backticks, within a discussing sentence) are untouched. Data check: of the 62 text parts with tags in the current session, 61 contain at least one standalone-line closing tag outside fences; after simulating the processing, 20 pure-thinking-tail parts became empty.
- `buildAssistantBlocks`: skip text parts that are empty after normalization (extending the existing whitespace-only skip; "pure thinking tail" parts no longer produce blank lines and no longer break tool card merging).
- `markdownText`: assistant parts render after `normalizedText` (user parts keep the batch 1 trim).
- `copyableText`: each part first goes through `normalizedText` (assistant) / trim (user), parts empty after normalization are filtered out, and the rest are joined with `"\n\n"`. This closes the gap of whitespace-only parts (such as `"\n\n\n"`) surviving and then being joined.
- `selectionText` / the selection sheet: the input is already `copyableText`, so the fix lands with the copy construction and the function itself needs no change.
- The user bubble padding gap (task item 3): the ForEach in `userMessageView` now only iterates text parts passing `isRenderableText`, so empty parts no longer produce a 20pt padding box.
- `StreamingReasoningView` (task item 4, recorded only): reasoning parts currently contain 0/189 think tags (verified); if a leak ever reaches the reasoning channel it would display on the thinking bar, which is acceptable since the thinking bar is the display slot for thinking content anyway; reuse `normalizedText` if it is ever truly needed.

Tests to add (following the `MessageRenderingHeuristicTests` style; tag constants in Swift are built with `"\u{3C}think\u{3E}"` / `"\u{3C}/think\u{3E}"`):

- Complete thinking block deletion (open line + content + close line + real response → only the response remains)
- Pure thinking tail part → empty string
- Thinking tail + trailing real response → only the response remains
- Mid-line tags (backticked / mid-sentence) untouched
- Tags inside code fences untouched
- Tail containing a literal open/close example block → still only the content after the last close remains (ordering regression)
- `copyableText` normalization (whitespace part + thinking tail part + real part → no extra blank lines, no thinking content)
- `copyableText` does not modify user messages
- `buildAssistantBlocks` skips "pure thinking tail" parts and tool merging is preserved

Known trade-off (the cost of the ordering decision): if the model cites an example thinking block with a **standalone-line** tag in an ordinary reply (and outside code fences), everything from the start of the text to that example close is cut, including the text before the example. The user confirmed this case is out of concern scope; examples inside code fences are unaffected.

One remaining case: if the literal close in the thinking is **mid-line** (not standalone) and no standalone-line close follows it (only 1 of the 62 tagged text parts in the current session is like this), the text part has no recognizable split boundary and the leaked thinking stays as-is. Web has the same limitation (behavior matches); there is no reliable signal to cut on, so this is accepted as unfixed.
### Batch 3: empirical verification of the rendering path in the simulator (paused, for this investigation only)

- Added a `render-part` debug log to `loadMessages` in `AppState+Messages.swift`: for every text / reasoning part of every assistant message it logs `type` (the server's raw type), `isReasoning` / `isText` (the app's classification), and a content preview with newlines visualized (first 160 characters).
  - Chose loadMessages over the view: the view body recomputes on every render pass (the log would flood), while loadMessages runs once per fetch and is the first place raw server data lands.
- Built + installed onto the booted simulator (iPhone 17 Pro `8625CF87-A59C-474D-9658-DDFFFA707323`, iOS 26.3).
- **This log does not go into the official PR**: the body preview is `privacy: .public`, and it covers only `loadMessages`, not the SSE streaming path. Long-term retention would require redacting the preview and covering SSE.
- Not done: seeding the simulator credentials (UserDefaults `serverURL` / `username` are written; the Keychain password is still pending because the simulator has no `security` binary and spawning a custom binary also failed, so the seeding method needs to change), then deep linking `opencode://session/ses_fcfbd043bffe417xHHYrV0gw37` and capturing os_log.

## Independent review (Grok, 2026-08-23)

- Conclusion: the extra blank line root cause holds (iOS lacks normalization; iOS is the right thing to fix), but "think tags are also a systemic iOS bug" overstates it: a clean qwen38 session has 0 think tags.
- Verdict on the batch 1 fix: correct but incomplete (gaps listed above). Trim only removes whitespace at the two ends of a part and never touches middle paragraphs, so the blast radius is tiny; Web's `.trim()` behaves the same.
- Think tag handling: recommends "strip tags only, keep inner text" (DOMPurify style), shared `normalizedText` for rendering and copy; do not do "cut to the last close tag".
- Evidence: 206 messages from the live API (185 assistant text parts: 99.5% leading `\n`, 38.9% whitespace-only, 58 with think; 185 reasoning parts with 0 think); clean session `ses_fcfbff756ffe` with 0 think; Web `message-part-text.ts:2` / `message-part.tsx:717` / `markdown-cache.tsx` DOMPurify; Android `ChatMessageContent.kt:436,776`.

## Why fix it in the client

- With the same server data, Web and Android both render correctly, which shows the data itself can be rendered correctly and the problem sits in the iOS rendering layer rather than the server / model.
- Client normalization is idempotent: no side effects for other models (which never had these newlines / tags in the first place).
- It touches neither the server nor the model, so the blast radius is minimal, and it aligns behavior with Web / Android.

## Key coordinates

- Branch: `fix/whitespace-text-parts` (`7382991` whitespace filtering + trim; `24f5c36` debug log, kept out of the PR; `fcef352` this document)
- Target session: `ses_fcfbd043bffe417xHHYrV0gw37` (active; counts are a moving target)
- API: `http://127.0.0.1:4096`, Basic auth `opencode` / `OPENCODE_PASSWORD` (workspace `.env`)
- Simulator: iPhone 17 Pro `8625CF87-A59C-474D-9658-DDFFFA707323` (iOS 26.3, booted)
- Bundle id: `com.grapeot.OpenCodeClient`
- Build constraint: `xcodebuild build` and `test` must run serially (shared build.db); a full test run takes 10–20 minutes, and targeted runs use `-only-testing:OpenCodeClientTests/MessageRenderingHeuristicTests`
