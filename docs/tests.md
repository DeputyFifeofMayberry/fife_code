# OpenCode iOS Client Testing Guide

Date: 2026-06-03

This document lays out the testing architecture of the OpenCode iOS client. For day-to-day change records see `docs/WORKING.md`; this document answers the structural questions: what each tier verifies, why it exists, how to run it, and which prerequisites it depends on.

The design aligns with the four-tier testing model already in place in the Android client, adapted and reorganized around the existing iOS architecture. The existing Swift Testing suites, the `AppState` mock flow, and fixture-driven XCUITests are all kept and assigned to their tiers, with a minimal closed loop added for real server integration and LLM-driven UI.

## Why Four Tiers

The tiers are grouped by the core question each one answers, its execution cost, and how often it runs, rather than by test tool.

First, unit/contract protects pure business logic and data contracts. It needs no app launch or server connection, runs fastest and most stably, and should run on every commit.

Second, state/component verifies the client's internal state machine and fixture UI. This is a major advantage of the iOS architecture: `AppState` accepts an injected `MockAPIClient` and `MockSSEClient`, so many state flows close to real user actions can be reproduced exactly without a real server. Fixture-driven XCUITests also belong to this tier: the real app launches, but the state is injected entirely by the test case, and fixed assertions confirm the view wiring is correct.

Third, integration-UI drops the mock dependencies and connects directly to a real OpenCode server with real sessions. Its core question: when the server produces real endpoint responses, payload data, and SSE/tool part shapes, can the client still decode, load, and render correctly? Tier 2 cannot catch protocol drift that happens on the server side; Tier 3 exists to guard exactly that boundary.

Finally, LLM-driven-UI has an agent drive the real app, read the accessibility tree and screenshots, and judge the outcome against concrete scenario goals. The first three tiers are process-deterministic tests: assertion rules are written in advance and can only cover known, expected scenarios. Tier 4 focuses on outcome determinism: given a goal and acceptance criteria, the agent performs the actions, observation, waiting, and evaluation on its own, specifically to catch UI/UX regressions that were never turned into assertions ahead of time. Tier 4 can also use curated deterministic fixtures; what places a test in a tier is not whether its data was curated in advance, but whether observable run evidence is produced on a real app/simulator and whole-screen UX evaluation is handed to an agent.

Overall, the earlier the tier (Tier 1/2), the faster and more deterministic it is, and the better it fits the daily commit pipeline; the later the tier (Tier 3/4), the more real the environment, the higher the cost, and the more likely it is to surface unknown defects. For problems found in Tier 4, whatever verification logic can be made stable should be pushed down into Tier 3 or Tier 2 over time. Stable harnesses and CLI tools written during Tier 4 exploration should be checked in promptly, while run artifacts such as screenshots, `.xcresult` bundles, and temporary configs stay strictly under gitignored paths.

## Current Test Targets

The project currently exposes two test targets:

| Target | Framework | Tier | Current status |
| --- | --- | --- | --- |
| `OpenCodeClientTests` | Swift Testing (`import Testing`) | Tier 1 + Tier 2 | Primary test layer |
| `OpenCodeClientUITests` | XCTest UI Testing | Tier 2 | fixture UI / smoke guard |

Main files:

- `OpenCodeClient/OpenCodeClientTests/OpenCodeClientTests.swift`
- `OpenCodeClient/OpenCodeClientTests/ModelsTests.swift`
- `OpenCodeClient/OpenCodeClientTests/ConnectionTests.swift`
- `OpenCodeClient/OpenCodeClientTests/SessionFlowTests.swift`
- `OpenCodeClient/OpenCodeClientTests/CarModeTests.swift`
- `OpenCodeClient/OpenCodeClientTests/AIBuilderVoiceTests.swift`
- `OpenCodeClient/OpenCodeClientTests/RenderingTests.swift`
- `OpenCodeClient/OpenCodeClientTests/TestDoubles.swift`
- `OpenCodeClient/OpenCodeClientTests/ModelShortlistTests.swift`
- `OpenCodeClient/OpenCodeClientTests/SessionScopedStateTests.swift`
- `OpenCodeClient/OpenCodeClientTests/UserDefaultsIsolationTests.swift`
- `OpenCodeClient/OpenCodeClientTests/ReadToolCardIntegrationTests.swift`
- `OpenCodeClient/OpenCodeClientTests/ToolCardClassifierTests.swift`
- `OpenCodeClient/OpenCodeClientTests/ClientCapabilityTests.swift`
- `OpenCodeClient/OpenCodeClientTests/OpenCodeDeepLinkTests.swift`
- `OpenCodeClient/OpenCodeClientUITests/OpenCodeClientUITests.swift`
- `OpenCodeClient/OpenCodeClientUITests/ToolCardsUITests.swift`
- `OpenCodeClient/OpenCodeClientUITests/ModelShortlistUITests.swift`
- `OpenCodeClient/OpenCodeClientUITests/CarModeUITests.swift`
- `OpenCodeClient/OpenCodeClientUITests/OpenCodeClientUITestsLaunchTests.swift`
- `ui_driver/`
- `skills/operate_ios_simulator.md`
- `skills/ui_test_tasks.md`
- `skills/ui_test_prompts/01_read_card_visible.md`

## Tier 1: Unit / Contract

Tier 1 focuses on pure logic and data contract tests, with no real server dependency and no UI involvement. The tests live in `OpenCodeClientTests` and use the Swift Testing framework.

This tier is relatively mature and mainly covers:

- `Session` / `SessionStatus` / `Message` / `Part` decoding.
- `SSEEvent` payload shape.
- API models such as `TodoItem`, `Project`, and `QuestionRequest`.
- URL correction, scheme completion, path normalization, and file path extraction.
- Client capability action/callback decoding, Pending/Outbox expiration and idempotency, permissions, and continuation of the original session.
- `ToolCardClassifier`: which parts enter the file-card grid and which collapse into the merged tool calls row; directory read detection and entries parsing.
- `SSHKeyManager` key lifecycle: separated read/create (`getKeyPair()` only reads and never generates), guided generation only when the entry is missing (`errSecItemNotFound`), fail-closed `keyUnavailable` instead of regeneration when the Keychain is temporarily unreadable, and consistency checks plus repair of the cached public key derived from the private key.

This tier verifies that the client handles known input formats and pure rules correctly. It cannot prove that the real server still sends data matching that contract; Tier 3 covers that.

Run:

```bash
xcodebuild test \
  -project "OpenCodeClient.xcodeproj" \
  -scheme "OpenCodeClient" \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'
```

When adding pure logic, model decoding, path/URL handling, or tool classification, add Tier 1 tests first.

## Tier 2: State Flow / Fixture UI

Tier 2 drives the real client state machine and real UI on fake data or mock dependencies. Since no real server is needed, this tier is cheap, deterministic, and highly controllable, which makes it a good fit for covering edge states and error branches.

On iOS, this tier takes two forms.

The first is `AppState` state flow testing. Because `AppState` accepts an injected `MockAPIClient` and `MockSSEClient`, test cases can precisely control API responses, error injection, and SSE event delivery, driving the real `AppState` through deterministic state transitions. Current coverage includes:

- `loadSessions()` / `loadMoreSessions()`.
- `createSession()` / `deleteSession()` / fallback selection.
- `message.updated` / `message.part.updated` / `session.updated`.
- Optimistic user row dedupe and failure rollback.
- Session tree, sidebar root-only helper, archived filtering.

The second is fixture-driven XCUITest. The app launches with deterministic state injected through launch arguments, then the UI test drives the real app to verify behavior:

- `UITEST_SESSION_TREE_FIXTURE`: verifies child/subagent sessions are visible in the session list; the current fixture also contains an active/archived session tree to cover archive section wiring.
- `UITEST_TOOL_CARDS_FIXTURE`: verifies the half-width process tile grid (file cards and the merged tool calls tile share the 2-up grid and are always half width) and the expanded content (which stays inside the half-width tile).
- `UITEST_F3_TRANSCRIBING_FIXTURE`: verifies the voice rail keeps text review/send while agent running and transcribing run in parallel, and demotes agent interrupt to the `⋯` menu.
- `UITEST_F3_RETRY_FIXTURE`: verifies the preserved-audio retry state clearly expresses "retry the same audio" and that recovery actions stay semantically separate from agent abort.
- `UITEST_CLIENT_CAPABILITY_FIXTURE`: verifies the Health export local authorization reason, the this-time-only and always-allow-later options, and the cancel entry.
- Launch/input smoke: verifies app launch, chat input reachability, and that long input stays scrollable.

Tier 2 effectively protects the client's internal state orchestration and view wiring, but it still runs in an assumed environment constructed by the tests. If the server changes its protocol while the mock still serves the old payload, Tier 2 tests can pass falsely, so it cannot replace Tier 3.

One distinction matters: fixture-driven XCUITest can serve both Tier 2 and Tier 4. When it only runs fixed code assertions, it is Tier 2. When the same fixture launches the real app, expands the target UI, and exports screenshots for an agent to review layout, hierarchy, visual density, and privacy compliance, it becomes the Tier 4 deterministic visual QA mode. That mode forgoes real server data in exchange for highly reproducible, secret-free, fast-iterating visual feedback evidence, which suits design polish and UI regression triage well.

## Tier 3: Integration

Tier 3 connects directly to a real OpenCode server, creates real sessions, receives the messages and tool parts the server actually generates, and verifies the client's contract correctness with fixed assertions. Its core goal is catching protocol drift at the client/server interface boundary early.

The current minimal implementation at this tier is `ReadToolCardIntegrationTests.swift`. It skips the live path by default and only connects to the test server when the environment variable `OPENCODE_INTEGRATION_TESTS=1` is set explicitly. The test process reads `ProcessInfo.processInfo.environment` first; for missing keys it fills in what it needs from the gitignored `.env` at the repo root, without overwriting existing environment variables.

The full flow:

1. Connect to the local test server, usually port 4097, avoiding the user's active 4096.
2. Run a health check with the real `APIClient`.
3. Create a real session.
4. Send a read-only prompt: read `AGENTS.md`, with creating, editing, and writing files explicitly forbidden.
5. Poll the real messages until a read tool part appears.
6. Use the real decode results and `ToolCardClassifier` to verify the read tool part is classified as a read/file operation.
7. Best-effort delete the created session.

The current Tier 3 guards the real server -> client decode and classification contract and does not yet include a full app-side end-to-end UI navigation path. A full UI variant can come later: launch the app, configure the server connection, send a prompt, and verify the whole-screen UI end to end.

Credentials and model/agent configuration must come from the gitignored `.env` or test run arguments, and must never be hardcoded into source code, doc examples, or the Xcode project. When merging `.env` values from the Android client, add only missing keys and leave the existing iOS configuration untouched. Also, `OPENCODE_SERVER_URL` must use a host address reachable from the iOS Simulator (such as `127.0.0.1`); the Android emulator-specific `10.0.2.2` cannot be reused directly. When configuration is missing or the server is unreachable, the test should skip or block explicitly with a concrete reason, so an environment problem is not misreported as an app defect.

Tier 3 allows only read-only safe scenarios by default. Real write/edit operations modify the current workspace directly; unless the server cwd points at a dedicated isolated sandbox, write operations must never be triggered in Tier 3.

Live run example:

```bash
xcodebuild test \
  -project "OpenCodeClient.xcodeproj" \
  -scheme "OpenCodeClient" \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' \
  -only-testing:OpenCodeClientTests/ReadToolCardIntegrationTests
```

The local `.env` needs at least `OPENCODE_INTEGRATION_TESTS=1`, `OPENCODE_SERVER_URL`, and `OPENCODE_AGENT`; if the server has authentication enabled, also provide `OPENCODE_USERNAME` / `OPENCODE_PASSWORD`. To pin the model, configure `OPENCODE_MODEL_PROVIDER` / `OPENCODE_MODEL_ID`.

## Tier 4: LLM-Driven UI

Tier 4 has an agent drive the real app, parse the UI state or screenshots returned by its tools, and judge the outcome autonomously against user scenarios and acceptance criteria. This tier does not aim for exhaustive coverage; its purpose is finding hidden problems that fixed code assertions rarely anticipate, especially UX regressions involving async timing, whole-screen readability, and degraded interaction quality.

The minimal loop currently in place on iOS:

- `ui_driver/`: a `simctl`-backed Python CLI skeleton.
- `skills/operate_ios_simulator.md`: the operation-layer skill.
- `skills/ui_test_tasks.md`: the Tier 4 test task workflow.
- `skills/ui_test_prompts/01_read_card_visible.md`: the first read-card prompt.
- `OpenCodeClientUITests/testCaptureSessionArchiveFixtureScreenshot`: a deterministic screenshot harness that skips by default. After setting `TIER4_SCREENSHOT_PATH` or `screenshot_path` in `/tmp/opencode-ios-tier4-config.json`, it launches the real app with a synthetic session tree fixture, expands the Archive section, and writes the PNG to the given path.

`ui_driver` currently supports the `devices`, `launch`, `screenshot`, `tree`, `run-xcuitest`, `configure-server`, and `send-prompt` subcommands. The `tree` command has two modes: without Xcode arguments it performs an honest screenshot-only observation, returning `observability: screenshot_only`, empty `nodes` / `compact`, and a warning; with `--project`, `--scheme`, and `--destination` it calls `Tier4DriverUITests/testAccessibilityObservationSnapshot` and returns `observability: xcuitest_accessibility_snapshot` plus the corresponding XCTest summary. This still avoids a distorted simulation of a full Android-style accessibility tree. To assert a specific UI element precisely, trigger a focused UI harness through `run-xcuitest` or the XCTest-backed `tree` command; that matches iOS platform practice better than hardcoded coordinate taps or a fabricated tree. Tier 4 combines screenshot evidence, the XCTest summary, and the agent's own reasoning into the final verdict, and reports BLOCKED explicitly when the information is insufficient.

The `configure-server` and `send-prompt` paths have been verified against a live 4097 test port. The driver passes run configuration to XCTest through the temporary file `/tmp/opencode-ios-tier4-config.json` with `0600` permissions, so no plaintext password leaks into the command line or `xcodebuild_args`; password input is always injected through paste/`Cmd+V`, and the JSON output redacts sensitive passwords from the tail of stdout/stderr logs. Xcode UI tests also pass `-parallel-testing-enabled NO` explicitly, since clone runner conflicts can fail test startup.

### Deterministic screenshot QA

For pure UI layout or visual design changes, prefer the deterministic screenshot harness over live server screenshots. Live screenshots mix server runtime state, account credentials, network timing jitter, and dynamic session data into the evaluation; fixture screenshots focus on whether the current design renders precisely on iPhone/iPad. The acceptance criterion for this flow is not simply "the test case passed"; the produced screenshots must pass human or model review of the image.

How to run:

```bash
# Write the gitignored temp config; the TIER4_SCREENSHOT_PATH environment variable works too.
printf '{"screenshot_path":"%s"}\n' \
  "$PWD/tmp/visual_qa/session_archive_fixture.png" \
  > /tmp/opencode-ios-tier4-config.json

xcodebuild test \
  -project "OpenCodeClient.xcodeproj" \
  -scheme "OpenCodeClient" \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' \
  -only-testing:OpenCodeClientUITests/OpenCodeClientUITests/testCaptureSessionArchiveFixtureScreenshot \
  -parallel-testing-enabled NO
```

The F3 voice composer deterministic fixtures run separately with the same tier of UI test:

```bash
xcodebuild test \
  -project "OpenCodeClient.xcodeproj" \
  -scheme "OpenCodeClient" \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' \
  -only-testing:OpenCodeClientUITests/OpenCodeClientUITests/testF3TranscribingComposerFixtureScreenshot \
  -only-testing:OpenCodeClientUITests/OpenCodeClientUITests/testF3RetryComposerFixtureScreenshot
```

The same harness covers iPad verification by switching only the destination. Write screenshot output under `tmp/visual_qa/` and never commit it. After the run, open the images and check each item: the screen landed on the intended page, the target section expanded properly, no unexpected system dialogs or stale UI remain, no real private data leaked, and the overall visual hierarchy matches the design intent.

In the session archive work, this workflow caught two typical problems that fixed code assertions missed: combining `DisclosureGroup` with system list rows made section headers degrade into visually heavy default-style cells, and offsetting sheet/list padding with negative top padding let the `Active` header get covered by the title bar at certain viewport sizes. Screenshot review turns such layout regressions into directly visible, deterministic evidence, which then makes it easy to fold the fixed, stable interaction behavior down into fixture UI tests.

The architecture carries over the core idea proven on Android: the CLI is the skeleton, the agent is the intelligent decision layer, and the test case is the prompt. The difference is that iOS lacks a low-cost direct export comparable to Android's `uiautomator dump`, so XCTest currently serves as the bridge for precise UI identity. `configure-server` and `send-prompt` are already wrapped as higher-level commands in `ui_driver`; once a stable, reliable iOS accessibility tree parsing capability exists, generic interaction commands such as `tap-label` can follow.

Tier 4 tests do not need to run on every commit; they usually run on demand or on a schedule. Once Tier 4 exploration clarifies an interaction behavior with stable assertion characteristics, push the stabilizable parts down into Tier 3 or Tier 2 promptly.

Code with long-term maintenance value produced during Tier 4 work belongs in version control (launch fixtures, XCTest screenshot harnesses, `ui_driver` subcommands, redaction/helper scripts, and similar); one-off artifacts from individual runs must never be committed, including real screenshots, fixture screenshots, `.xcresult` bundles, DerivedData caches, the Xcode workspace's `xcuserdata`, the temporary config file `/tmp/opencode-ios-tier4-config.json`, and credential JSON containing secrets.

## Cross-Cutting Prerequisite: UI Observability

Tiers 2, 3, and 4 all depend on a stable, semantic accessibility surface. Any UI element used by automated test assertions or agent perception must declare a clear `accessibilityIdentifier` and `accessibilityLabel`; fragile rendering details such as absolute coordinates, view colors, or layout spacing must never be relied on.

The iOS tool card components already distinguish read/write operations at the accessibility layer:

- file read: `toolcard.read.<basename>`, label `Read file <basename>`.
- write/edit/patch: `toolcard.write.<basename>`, label `Write file <basename>`.
- directory read: `toolcard.folder.<basename>`, label `Read directory <basename>`.
- merged non-file tools: `toolcard.toolcalls`. This tile is a custom-drawn button row (no system DisclosureGroup): `.isButton` trait plus an expansion value (`Expanded`/`Collapsed`), identifier unchanged.
- thinking tile: `message-thinking-card`. Also a custom-drawn button row: `.isButton` trait plus an expansion value (`Expanded`/`Collapsed`), identifier unchanged.

`ToolCardsUITests` uses `UITEST_TOOL_CARDS_FIXTURE` to make sure both read and write cards are captured correctly in XCUITest. Since running write/edit/patch operations against a real server is risky, write card rendering is verified mainly through the Tier 2 fixture, while read cards get double coverage from the Tier 2 fixture and the real-server read path in Tier 3.

The **half-width visual QA** of process tiles (thinking / merged tool calls) is carried by the `oc_toolcards_collapsed` / `oc_toolcards` screenshots produced by `ToolCardsUITests` (deterministic screenshots; image review confirms tile width equals grid column width and expanded content stays within half width). Note that the current `UITEST_TOOL_CARDS_FIXTURE` contains no reasoning part, so the thinking tile has no UI coverage yet; optionally add a reasoning part to that fixture to close the gap.

## Boundaries and Safety

A locally running OpenCode server may share the `/Users/grapeot/co/knowledge_working` working directory. Without a dedicated isolated sandbox configured, Tier 3 and Tier 4 are allowed to trigger only read tool calls. Any prompt that creates, modifies, or writes files is out of bounds and strictly forbidden.

Screenshots and UI trees produced by automated tests may contain the server URL, usernames, session details, or other sensitive private information. All Tier 4 artifacts must therefore be written to gitignored directories, and before sharing or committing anything, verify carefully that no tokens, passwords, or real private data are included.

Test command execution must strictly follow the project `AGENTS.md` rules: `xcodebuild build` and `xcodebuild test` must run sequentially, never concurrently, to avoid `build.db: database is locked` from the shared DerivedData / build database.

## Recommended Verification Commands

After everyday changes to app code or test cases, run at least the following build and test commands in order:

```bash
xcodebuild build \
  -project "OpenCodeClient.xcodeproj" \
  -scheme "OpenCodeClient" \
  -destination 'generic/platform=iOS Simulator'

xcodebuild test \
  -project "OpenCodeClient.xcodeproj" \
  -scheme "OpenCodeClient" \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'
```

Running Tier 3 additionally requires a local test server, credentials, and agent/model configuration; running Tier 4 requires the target simulator to be booted with the app preinstalled, plus the iOS `ui_driver` and its skill/prompt files ready.

Run the `ui_driver` unit tests:

```bash
cd ui_driver
.venv/bin/python -m pytest -q
```
