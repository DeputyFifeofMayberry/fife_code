# Session Finder Design Draft

## Conclusion

Position this as a "smart find" mode inside the existing Sessions entry, rather than a new standalone tab or a simple fuzzy title filter over the already-fetched partial list.

The user types a vague memory-based description of a past conversation and the system returns 3-8 matching candidates with quoted evidence. After confirming the target in a preview, the user switches back to the original Session with one tap and continues typing. As an architecture trade-off, a slightly slower search response is acceptable, but the results must clearly tell the user the search scope, the basis for recall, and whether that Session is currently in a state that supports continuing.

During the prototype phase, orchestrate the existing Markdown archive and semantic search (semantic-search) through a temporary OpenCode Utility Session; the client only consumes standard, stable structured results. Once the interaction (UX) loop is validated, replace the Utility Session seamlessly with a dedicated Search Bridge service, keeping the UI presentation and the result data contract completely unchanged.

## Success Criteria

Without remembering exact session titles, creation dates, or the owning Project, the user starts from a vague memory fragment and completes three core needs in a single search:

1. Get a short list of high-confidence candidates without digging through dozens of historical titles.
2. Quickly verify and lock onto the real target Session using quoted source excerpts.
3. Know clearly whether that Session supports continuing seamlessly or only a read-only historical backup exists.

The first version's core quality metric is the target Session appearing in the Top 5 candidate list. Search latency is a secondary consideration, but the whole search must provide credible staged progress feedback; showing nothing but a blank spinner for a long time is unacceptable.

## Entry Points and Main Flow

### iPhone

Fully keep the existing Sessions switch button in the Chat toolbar and the left-edge swipe-out gesture. Add a system search field at the top of the expanded Sessions sheet with the placeholder `Describe what you remember`.

When the search field is empty, the UI continues to show the original Active / Archived session lists. When the user taps Search on the keyboard to trigger retrieval, the UI smoothly switches into smart find mode:

```text
Sessions
┌─────────────────────────────────────────┐
│ Discussed iPad Chinese input early send │
└─────────────────────────────────────────┘

Searching conversations...
Checking indexed history and live sessions

Possible matches
┌─────────────────────────────────────┐
│ iOS composer input fix              │
│ opencode_ios_client · Jun 18        │
│ You: "Chinese IME still picking..." │
│                             Preview │
└─────────────────────────────────────┘
```

Tapping any candidate card opens a detail preview page; it never bluntly replaces the Chat in progress. The preview page shows:

- One conversational turn before and after the matched message's context.
- The last turn where that Session paused.
- The owning Project, the date, and the current continue-ability state.
- A permanently pinned primary action button at the bottom: `Continue in This Session`.

If that conversation is an OpenCode soft-archived Session, the primary button text becomes `Restore and Continue`. After the user taps to confirm, call the existing `selectSession` logic, close the sheet, switch back to the main Chat UI, and focus the input field; do not auto-trigger voice recording and do not auto-submit a message.

The regular Sessions list keeps its direct tap-to-switch interaction. The extra confirmation step applies only to probabilistic semantic search results and adds no friction to everyday session switching.

### iPad

The search field lives permanently at the top of the left column of the Sessions sidebar. The left column shows only a compact candidate list; after the user selects a candidate, the middle column temporarily switches from Files to Session Preview, while the right column always keeps the Chat the user is actively working in. Only when the user explicitly taps `Continue in This Session` in the preview does the right column's active session actually switch.

iPads in Compact width mode automatically follow the iPhone's sheet interaction logic instead of forcing columns based on device model.

## Search Scope

The default search scope is strictly: the currently connected Host, covering all associated Projects, including Sessions in OpenCode's soft-archived state.

Cross-Host search is not supported by default. Different Hosts have separate connection channels, credentials, and Session namespaces; mixing results from different Hosts easily creates the false-success trap of "found a match that cannot be opened in this environment". Directly below the search field, show one visually quiet Scope line, for example:

```text
Home Mac · All Projects · Includes Archived
```

When a matched Session belongs to another Project, after the user confirms to continue, the client automatically switches the current Project to that Session's `directory`, keeping the Sessions, Files, and Chat views in one Workspace context at all times.

The design must clearly separate two kinds of archives with different properties:

- OpenCode soft archive: data remains fully in the server's Main DB and supports instant restore and continuing.
- Offline historical archive: data has been moved to a separate Archive DB or survives only as Markdown text; the currently running server cannot append to it.

Never lump the two together as Archived in the UI. Label offline history uniformly as `Read-only copy` to avoid mental-model confusion with the existing Archive/Restore states.

## Candidate Card

Candidate cards show only the key information that helps the user recognize and decide:

- Session title, at most two lines.
- Short Project name, omitting long absolute paths.
- Absolute date; for old conversations a relative time alone is not enough to establish a clear time anchor.
- 2-3 lines of the key matched source excerpt, explicitly labeled with the role `You` or `Assistant`.
- Special state tags: `Archived`, `Read-only copy`, `Child session`; the ordinary Idle state is not shown redundantly.
- An optional one-line status hint `Last stopped at`, helping the user tell apart "matched only an early related discussion" from "suitable for continuing straight from the end".

The UI never shows abstract similarity numbers such as 0.83. Such scores give the user no actionable guidance and mislead with fake precision. AI-generated summaries serve only as auxiliary reference and must never replace real quoted evidence.

Results are always aggregated at the Session level, never listed as scattered chunks. When multiple chunks hit the same Session, keep the most recognizable excerpt and use the multi-hit count as an internal confidence signal for ranking. When a child session is hit, fold it under the parent Session by default with the hit source marked as Child, so fragments of one complex workflow cannot monopolize the candidate list.

## Search and Ranking

V0's core need is semantic retrieval; expensive generative LLM reranking (rerank) is not needed yet.

Recommended lightweight ranking pipeline:

1. Recall the Top 20-30 candidate chunks from the existing Markdown semantic index.
2. Add exact session title matches and recently active Sessions retrieved from the Live DB.
3. Deduplicate and aggregate at the Session level by the `(host namespace, session_id)` tuple.
4. Rank primarily on best semantic similarity score, multi-chunk repeat hit count, and exact keyword hits, with time decay (recency) only as a weak correction factor.
5. Check whether each candidate Session currently lives in the Main DB, the Archive DB, or only as a Markdown file.
6. Output the Top 5 candidates, dynamically widened to at most 8 when overall confidence is low.

Only when later offline evaluation data clearly proves that Hybrid Retrieval's Top-3/Top-5 accuracy is insufficient should a dedicated Reranker model be considered for the top 20 candidates. The Reranker must support automatic timeout degradation, must never become a hard dependency blocking first-screen rendering, and must never alter the recalled source excerpts.

## V0 Execution Architecture

### Why start with a utility session

The existing OpenCode server `search` API can only literally filter by Session Title, and the iOS client keeps only a forward-loading partial window in memory. Neither can genuinely support deep search over full history. In contrast, the Workspace environment already has the daily-exported Markdown archive, the command-line semantic search tool (semantic-search CLI), and an OpenCode Agent with tool-calling ability.

So the prototype phase can use this lightweight execution chain:

```text
iOS query
  -> create ephemeral utility session
  -> structured prompt calls semantic-search and checks DB availability
  -> JSON result
  -> delete utility session after successful parsing
  -> render candidates
```

The Utility Session's output format is strictly constrained by a JSON Schema. The client must never guess-extract Session IDs by parsing the model's free text. If the flow fails unexpectedly, keep that Utility Session for diagnosis; the next search always starts a fresh clean session so historical multi-turn context cannot skew ranking.

The core advantage of this approach is a minimal client change, cheaply validating how often and how much users actually want to retrieve old conversations in natural language. The costs are slightly higher end-to-end latency, one Agent interaction round consumed per search, and a dependency on the server's Workspace having access to the Session archive and the semantic search tools.

### Stable result contract

```json
{
  "query": "Discussed iPad Chinese input early send",
  "scope": {
    "host_namespace": "current-host",
    "projects": "all",
    "indexed_through": "2026-07-15T04:00:00-07:00"
  },
  "results": [
    {
      "source": "opencode",
      "host_namespace": "current-host",
      "session_id": "ses_example",
      "title": "iOS composer input fix",
      "project_directory": "/workspace/project",
      "updated_at": 1784102400000,
      "matched_message_id": "msg_example",
      "matched_role": "user",
      "excerpt": "Chinese IME still picking characters...",
      "availability": "live",
      "is_soft_archived": false,
      "parent_session_id": null
    }
  ]
}
```

The `availability` field supports at least these enum states:

- `live`: the current server can load it directly and supports appending messages.
- `offline_db`: lives in the offline Archive DB; V0 supports read-only viewing only.
- `markdown_only`: only exported Markdown text remains; V0 supports read-only viewing only.
- `missing`: the index hit it but the underlying raw data can no longer be resolved; do not render it as a normal candidate card.

In the data model, the unique key must never rely on `session_id` alone; it must be the `(source, host_namespace, session_id)` triple. Otherwise, once multiple Hosts or heterogeneous Session sources are added, global unique addressing is lost.

### Production bridge

After the UX loop is validated, the Utility Session can evolve smoothly into a dedicated Companion Search endpoint:

```http
GET /session-search?q=...&host=...&project=all&limit=5
GET /session-search/opencode/{session_id}/preview
```

The Bridge server takes over index building, availability resolution, and Preview rendering; the iOS client's data contract stays at zero changes. The mobile client must never directly access the server's SQLite database files, absolute Markdown paths, or the underlying embedding cache.

## Loading, Weak Matches, and Failure

Search must be explicitly triggered by the user; an expensive semantic query must never fire on every keystroke.

- Response within 400ms: present results directly and smoothly, with no flashing loading animation.
- Over 400ms: show the `Searching conversations...` state.
- Over 2s: append the hint `Checking older indexed sessions...`.
- User edits the description and resubmits: keep the previous result list at reduced visual opacity while showing a refresh state, avoiding the screen flickering blank repeatedly.

When match confidence is low (weak match), show this friendly hint:

```text
No strong match found. These sessions may be related.
```

For a true zero-result case, the UI must clearly state the Host scope and the index time watermark, and provide three clear fallback exits: edit the search description, browse all Sessions in reverse-chronological order, or switch to another Host. Network errors, a not-yet-ready index, and genuinely no results must be presented as strictly distinct states; a generic `No results` must not paper over the difference.

## Direct Continue vs Read-Only History

V0's core goal is helping users quickly find a conversation and continue it, so `live` results always get top display priority. `offline_db` and `markdown_only` results are grouped under a separate `Older read-only matches` section, allowing history viewing only, with no misleading Continue entry point in the UI.

If reviving offline-archived conversations is needed later, a clear `Restore to OpenCode` data flow must be established: fully verify and write the complete Session Subtree with its associated Messages and Parts from the Archive DB back into the Main DB, and only allow appending after verification passes. The current data tooling only has a safe one-way Main -> Archive migration flow (plan/apply) and no ready-made reverse restore command; overwriting underlying files while OpenCode is actively running and writing the DB also easily corrupts data. So this capability is out of the first prototype's scope.

## Rejected Approaches

- No "filter only the session titles the client has already loaded". Since the list initially fetches only a limited window, such a UI easily creates the false impression that a full-history search has been done.
- No auto-opening of the single matched conversation by AI. Historical conversation retrieval is inherently ambiguous; the user must review the quoted evidence and confirm.
- No silently replacing the current Chat right after the user taps a search candidate. Search is a probabilistic decision, while the active conversation is valuable persistent working context.
- No full re-export of all conversations before every search. Reuse the daily scheduled semantic index first; offer a manual explicit refresh entry only when the index is clearly stale.
- No direct reads of the server's SQLite or Markdown files by the iOS client. The mobile side communicates strictly through the standardized Search and Preview data contracts.

## Existing Code Touch Points

- iPhone Sessions sheet and tap-to-switch: `OpenCodeClient/OpenCodeClient/Views/SessionListView.swift:25-135`.
- iPad Sessions left column: `OpenCodeClient/OpenCodeClient/ContentView.swift:890-1042`.
- Existing session switching and message loading: `OpenCodeClient/OpenCodeClient/AppState+Sessions.swift:221-257`.
- The current session list requests only by directory + limit: `OpenCodeClient/OpenCodeClient/Services/APIClient.swift:99-112`.
- `Session` currently has no excerpt or availability: `OpenCodeClient/OpenCodeClient/Models/Session.swift:8-40`.
- The existing design already explicitly rejects dressing up a local title filter as search: `docs/design.md:209-217`, `docs/OpenCode_iOS_Client_RFC.md:526-537`.

## Prototype Scope

The first prototype strictly focuses on iPhone with these boundaries:

1. Search scope limited to the current Host, covering all associated Projects and soft-archived conversations.
2. Search starts only from an explicitly submitted natural-language query.
3. Return a Top 5 candidate list with the corresponding source excerpts.
4. Support preview-then-confirm to continue; soft-archived conversations restore first, then continue.
5. Offline DB and Markdown archive results support plain-text read-only viewing only.
6. Built on a Utility Session with a structured JSON Schema; no LLM Rerank for now.

The core of this prototype is not the final form of the Semantic-Search technology choice; it is validating whether the interaction loop of "describe a vague memory -> inspect quoted evidence -> continue the original conversation in one tap" genuinely and significantly reduces the mental cost of finding and reusing past conversations.
