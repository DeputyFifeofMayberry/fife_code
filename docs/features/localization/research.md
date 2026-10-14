# Localization Research and Planning (iOS Client)

Last updated: 2026-02-15

## Background

The iOS client is currently in a mixed Chinese/English state: the core navigation bar (Chat/Files/Settings) is mostly English, but many buttons, hints, and error messages are still hardcoded in Chinese. The Close button in the Settings panel is a typical example of this localized mixing.

This document does not aim to kick off a one-shot full refactor immediately; it lays out a practical, low-risk localization path that supports incremental iteration.

## Current-State Findings

- UI copy is currently hardcoded directly via SwiftUI's `Text("...")` and `Button("...")`.
- The project has no proper `Localizable.strings` or String Catalog (`.xcstrings`) resource management yet.
- There is no unified internationalization (i18n) abstraction layer (such as an `L10n.xxx` utility), which makes automated consistency checks of UI copy difficult.
- The user-facing break is: on an English system language, Chinese buttons appear jarringly, and on a Chinese system, English hints keep mixing in.

## Complexity Assessment

With the goal set as "English on English systems, Chinese on Chinese systems", there are no architecture-level difficulties from an implementation standpoint; this is essentially a mid-scale code hygiene task. Most of the work is in cleaning up scattered copy and batch-replacing it, with no changes to the core architecture.

- **Quick usable version (estimated 1-2 days)**: cover the high-frequency main-flow entry points first (Settings, core Chat interactions, error dialogs), which immediately removes the most visible language mixing.
- **Complete stable version (estimated 3-6 days)**: cover all UI views and error messages, add unit tests and UI automation regression cases, and establish a long-term maintainable localization standard.

## Recommended Implementation

1. Build the localization infrastructure
   - Prefer Xcode String Catalog (recommended) or standard `Localizable.strings` file management.
   - Initialize at least two language bundles: `en` (English) and `zh-Hans` (Simplified Chinese).
   - Establish a uniform Key naming hierarchy, e.g. `settings.close`, `ssh.status.connected`.

2. Wrap a lightweight access layer
   - Add an `L10n` helper type (an enum or struct wrapper) to avoid hardcoding raw string keys in view code.
   - Standardize parameterized interpolation templates to avoid scattered dynamic string concatenation.

3. Migrate in phases
   - P1: cover the Settings pages and the full network connection path (the configuration surface users are most sensitive to).
   - P2: cover the Chat conversation flow, Session list management, and Files browsing.
   - P3: cover error messages, debug information, and rarely visited pages.

4. Set up verification and regression guards
   - Verify both languages by switching between English and Chinese run environments in the Xcode scheme.
   - Add UI snapshot tests or minimal smoke regression cases for the core pages so the mixing problem cannot creep back in later iterations.

## Immediate Suggestion (Quick Win)

Do one lightweight UX fix first: replace the top-left "Close" text in the Settings panel with `Close` at the top-right, so the mostly-English UI is not interrupted by an isolated language outlier. Then proceed with the full localization work steadily following the phased plan above.

## Risks and Notes

- Do not focus only on translating static UI copy: business error messages contain a lot of text returned dynamically by the server. Decide up front where the boundary lies between "passing server text through as is" and "mapping to local templates".
- Freeze the Key naming convention early to prevent naming chaos and redundant definitions when multiple people develop in parallel.
- While doing the localization replacements, clean up the legacy hardcoded raw strings along the way and set up a mechanism that prevents them from flowing back.

## RFC (addendum): V1 phased plan covering P1/P2/P3 in one pass

> Background feedback: V1 can complete P1/P2/P3, but it needs milestones; the "pass-through error message policy" is low priority and not a deliverable for this round.

### 1) First correct the assessment of the current state (based on a full repo read)

A full read of the current repository shows that the project **already has the beginnings of i18n infrastructure, but adoption is not yet closed loop across the app**:

- The code already ships `OpenCodeClient/OpenCodeClient/Support/L10n.swift` with an `en/zh` bilingual dictionary and a Key enum.
- But hardcoded strings remain widespread inside view components (causing the Chinese/English mixing), concentrated in these files:
  - `OpenCodeClient/OpenCodeClient/ContentView.swift`
  - `OpenCodeClient/OpenCodeClient/Views/SettingsTabView.swift`
  - `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift`
  - `OpenCodeClient/OpenCodeClient/Views/SessionListView.swift`
  - `OpenCodeClient/OpenCodeClient/Views/Chat/ToolPartView.swift`
  - `OpenCodeClient/OpenCodeClient/Views/Chat/PatchPartView.swift`
  - `OpenCodeClient/OpenCodeClient/Views/Chat/ContextUsageView.swift`
  - `OpenCodeClient/OpenCodeClient/ContentView.swift` (sidebar portion; the former `SplitSidebarView.swift` logic has been merged in)
  - `OpenCodeClient/OpenCodeClient/Views/FilesTabView.swift`
  - `OpenCodeClient/OpenCodeClient/Views/Chat/PermissionCardView.swift`
- Error message handling currently has multiple coexisting patterns:
  - A templated localization implementation exists (based on `AppError` + `L10n.errorMessage(...)`)
  - Logic that reads `error.localizedDescription` directly also exists (scattered across `AppState`)
  - `error.data.message` inside assistant messages is displayed as a pass-through (via `Message.errorMessageForDisplay`)

Technology decision: the best evolution path for V1 is to **keep and refine the existing `L10n.swift` architecture and finish wiring all views through it**; this round does not take on the migration cost of switching to `.xcstrings`.

### 2) V1 Goals and Non-Goals

**V1 goals (must land this round)**

- Fully cover all UI copy in P1/P2/P3 so the UI renders strictly consistently after a system language switch.
- Completely eliminate same-screen Chinese/English mixing and jarring language jumps in core flows.
- Establish a durable engineering rule: new UI copy must go through `L10n` keys; raw strings must never flow into the view layer.

**V1 non-goals (explicitly out of scope)**

- No deep rework or policy layering of the "server error message pass-through policy" this round.
- Do not migrate `L10n.swift` to the Xcode String Catalog system yet (deferred to V1.1+).
- Do not adjust or modify the existing error data structures returned by the server.

### 3) Phased plan (milestones within the same V1)

#### M1 (P1) - Settings + connection path (high visibility)

Goal: first converge the configuration and connection modules that users touch most and where mixing is most exposed.

Main files to change:

- `OpenCodeClient/OpenCodeClient/Views/SettingsTabView.swift`
- `OpenCodeClient/OpenCodeClient/ContentView.swift` (Close and other entry points of the Settings and file preview panels)
- `OpenCodeClient/OpenCodeClient/AppState.swift` (the various static hint texts in the connection path)

Core changes:

- Route all section titles, configuration field names, buttons, and Alert text through `L10n.t(...)`.
- Standardize the Key references for "Close/Done/OK/Cancel" across panels and dialogs.
- Refactor the two help strings in `schemeHelpText(...)` into `L10n.helpForURLScheme(...)` to remove duplicated hardcoded text.
- Fill in the missing `L10n.Key` cases (e.g. Public Key Error, Copy Command, Command Copied, Theme, Untrusted, Rotate).

Acceptance criteria:

- Under both English and Chinese run environments, the Settings pages show no reverse single-point language islands.
- SSH and AI Builder dialogs and action buttons stay consistent in language.

#### M2 (P2) - Chat + Session + Files main flows

Goal: fully cover the paths with the highest daily interaction frequency and remove cognitive interruptions during conversations.

Main files to change:

- `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift`
- `OpenCodeClient/OpenCodeClient/Views/SessionListView.swift`
- `OpenCodeClient/OpenCodeClient/Views/FilesTabView.swift`
- `OpenCodeClient/OpenCodeClient/ContentView.swift` (Preview empty-state view)

Core changes:

- Replace all Chat module Alert dialogs, navigation titles, input placeholders, empty-state copy, and voice precheck hints with `L10n`.
- Route Session list titles, empty states, and session status descriptions (busy/retry/idle) through `L10n`.
- Change `RelativeDateTimeFormatter` from the hardcoded `zh_Hans` locale to the system-following `Locale.current`.
- Route the Files tree, Workspace hints, search prompt, and file preview copy through `L10n`.

Acceptance criteria:

- From asking in Chat, to switching via the Session list, to Files browsing and file preview, no Chinese/English mixing anywhere in the flow.
- Relative time descriptions (such as "5 minutes ago") localize dynamically and correctly with the system language.

#### M3 (P3) - Tool/Patch/Context/Permission + activity status copy cleanup

Goal: systematically clean up the high-exposure but peripheral card components and align visual style and terminology globally.

Main files to change:

- `OpenCodeClient/OpenCodeClient/Views/Chat/ToolPartView.swift`
- `OpenCodeClient/OpenCodeClient/Views/Chat/PatchPartView.swift`
- `OpenCodeClient/OpenCodeClient/Views/Chat/ContextUsageView.swift`
- `OpenCodeClient/OpenCodeClient/Views/Chat/PermissionCardView.swift`
- `OpenCodeClient/OpenCodeClient/Controllers/ActivityTracker.swift`
- `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift` (Completed/Busy/Retrying/Idle status copy)

Core changes:

- Route all strings in the Tool and Patch cards ("Reason/Command/Input/Output/Open in File Tree/Select file" and others) through standard keys.
- Key-ify all section titles, data labels, loading states, and empty states in the Context detail panel.
- Key-ify the Permission card button copy and titles.
- Introduce `L10n` keys for the ActivityTracker status mapping copy (Thinking/Planning/Running commands and so on), removing runtime-hardcoded English copy.

Acceptance criteria:

- Tool, Patch, Context, and Permission cards keep terminology aligned under both languages.
- The Activity status line's dynamic copy lays out cleanly in both Chinese and English with no mixing.

### 4) Low-priority items (explicitly postponed this round)

- The "server error message pass-through policy" is explicitly deferred to a later dedicated effort (such as V1.1 or V2); this round adds no extra policy translation layer.
- Keep the status quo: `error.localizedDescription` and the server-native `error.data.message` continue to output as is. This round focuses on localizing the client UI framework copy and does not rewrite the semantic source of error messages.

### 5) Quality bar (Definition of Done)

- Code standards:
  - All new and modified UI copy must contain no raw strings (except product brand names, model IDs, and low-level protocol constants).
  - `L10n.Key` naming strictly follows the `domain.actionOrNoun` convention (e.g. `settings.copyCommand`).
- Test coverage:
  - Add basic unit tests verifying that core `L10n` keys have mappings in both the `en` and `zh` dictionaries (guarded by bidirectional set alignment assertions).
  - Smoke coverage of key flows: Settings pages, Chat Alert dialogs, Session empty state, Tool/Patch card dialogs, and the Context detail panel.
- Regression bar:
  - At least two rounds of end-to-end manual walkthrough (one under English, one under Chinese system language).
  - No regression of fixed mixing problems (such as mixed Close button labels).

### 6) Implementation order and effort estimate

- Day 1: deliver the M1 milestone (Settings + connection path) with self-testing.
- Day 2: deliver the M2 milestone (Chat / Session / Files main flows) with self-testing.
- Day 3: deliver the M3 milestone (Tool / Patch / Context / Permission / Activity status cleanup) and run full regression acceptance.

Summary: **V1 delivers the full P1/P2/P3 rework in one overall pass, while execution strictly follows the M1 → M2 → M3 milestones so that each phase has a clear, acceptable milestone**.
