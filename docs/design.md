# OpenCode iOS Client Design Spec (Quiet Tech)

This file is the implementation spec for the OpenCode iOS client visual redesign; it is not a review record. It replaces the earlier "diagnosis + multiple direction suggestions" draft (the diagnosis conclusions still hold and are attached at the end under "Diagnosis Review"). The core goal is to converge the visual direction into a design language named **Quiet Tech** and break it down into concrete guidelines that can directly drive the SwiftUI implementation.

Design direction: align with modern developer tools such as Raycast, Vercel, and Arc. Dark first, low saturation, and a premium feel built on precise spacing and hairline strokes instead of heavy ornamentation. The overall style stays restrained; the sense of quality comes from consistent rules and a well-judged rhythm of whitespace.

This spec follows the same design methodology as the sister project VoiceFlow's `docs/design.md` (warm amber / deep ink): a single accent color, no color-based hierarchy, borderless first, and minimal motion. The two apps share a family design language; OpenCode leans colder in tone and puts more weight on the tool feel.

## Design Principles

1. **Dark is primary, light is the fallback.** OpenCode targets developers, and dark mode is the default aesthetic baseline. Polish dark mode first, then map light mode onto the same token set.
2. **A single accent color: electric blue `#3B82F6`.** The whole app uses one hue to carry the "interactive/brand" semantics, covering send, selection, links, and active states. Gold `#D9A621` is the **only secondary accent**, strictly limited to the transient "AI is working" state and absent in normal states. Everything else uses neutral grays; the built-in `.red/.green/.orange/.purple` must never be used directly.
3. **Semantics come from shape and placement, with no color stacking.** The core pain point today is "many colors applied to the same shape on one screen" (tool, patch, and permission cards are all rounded rectangles with a light background and a stroke, told apart only by color). The new design separates functional categories by **card shape**, with color used as an accent in only a few key places.
4. **Hierarchy comes from font size and whitespace; color does not build it.** With uniform text color, primary and secondary roles are expressed through font size, weight, and spacing. Secondary gray is reserved for genuinely secondary information (timestamps, file paths, placeholders).
5. **Borderless first.** Information-display containers drop their strokes and rely on a very light background fill or plain whitespace for visual grouping. Only cards that need a user response get an accent bar on the left edge as an action cue. Strokes on iOS usually suggest form input fields and should not spread through the chat message stream.
6. **Motion stays light and fast.** State transitions use spring (response 0.3–0.35, damping 0.8) or 250–300ms ease-out, preferring opacity crossfades over large translations. Motion is a light way to add polish; bouncy effects and showy splash animations are strictly out.
7. **Small screens protect function; large screens get whitespace.** See "Two Layout Strategies" below. Under the same tokens and brand language, the iPhone uses a compact single-column layout for operating efficiency, while iPad and visionOS use an airy three-column layout that lets each size class show its own sense of space.
8. **Stable buttons never move.** Users have strong muscle memory for the composer's send and microphone buttons. Send and mic must always stay fixed in the bottom slot of their vertical stacks; temporary action buttons such as stop or retry may only appear above them and must never displace the permanent primary buttons.

## Dual-Mode Color Palette

Both modes share one set of semantic token definitions; only the mapping of background and text colors changes. In code, `DesignTokens` wraps each value with `Color(light:dark:)`, and views reference the semantic names only, avoiding ad-hoc `.opacity()` calls or direct use of system grays.

### Dark Mode (Primary)

| Token | Hex | Purpose |
|---|---|---|
| `bg.primary` | `#0B0C0E` | Primary background, near black with a slight cool tint |
| `bg.secondary` | `#141619` | Secondary background: sidebar, sheets, and settings groups |
| `surface` | `#1A1D21` | Information card background (tool/patch output areas) |
| `text.primary` | `#ECEDEE` | Primary text, AI reply body |
| `text.secondary` | `#9BA1A6` | Secondary information: timestamps, status, tool names |
| `text.tertiary` | `#5A6066` | Placeholders, disabled states, code paths |
| `divider` | `#23272B` | Hairline dividers (1px, between sidebar/settings rows) |
| `accent` | `#3B82F6` | The only brand accent: send, selected state, links, user message indicator bar |
| `accent.muted` | `#3B82F614` | 8% alpha accent, user message background and selected row background |
| `gold` | `#D9A621` | The only secondary accent: the transient "AI working" state only |

### Light Mode (Fallback)

| Token | Hex | Purpose |
|---|---|---|
| `bg.primary` | `#FBFBFC` | Primary background, near white with a slight cool tint |
| `bg.secondary` | `#F4F5F6` | Secondary background |
| `surface` | `#F0F1F3` | Information card background |
| `text.primary` | `#1A1D21` | Primary text (deep ink rather than pure black) |
| `text.secondary` | `#6B7177` | Secondary text |
| `text.tertiary` | `#9BA1A6` | Placeholders, disabled states |
| `divider` | `#E6E8EA` | Hairline dividers |
| `accent` | `#2563EB` | Same hue, one step darker for contrast on the light background |
| `accent.muted` | `#2563EB14` | 8% alpha accent |
| `gold` | `#B8860B` | Darkened gold adapted for the light background |

### Status Color Semantics (Replacing "Red/Green/Orange Dots")

The current design uses red/green/orange for error/success/warning, which breaks the single-accent principle. The new design reduces the role of color and expresses status through shape, structure, and text:

| Status | Expression |
|---|---|
| AI idle / ready | No color, plain text |
| AI working | The only place `gold` may appear: a pulsing indicator dot next to the composer, plus a pulse animation on the context ring when usage runs high |
| Success / done | A `text.secondary`-style checkmark with a text label; no green |
| Error | `accent` (blue) carries the warning together with explicit text; no red background blocks (red is reserved for destructive actions such as the delete-session confirmation button) |
| Warning | `gold` text with an explanation; no orange background blocks |

At any moment, the whole screen may show at most one colored element (accent or gold); everything else stays grayscale. This is a hard constraint of the calm style.

## Typography

Use the system SF fonts throughout and set the design variant explicitly. No third-party fonts, for better CJK fallback, a smaller app bundle, and a seamless blend with system UI.

- **Display**: session titles and empty-state headlines, SF Pro Display Semibold 22pt, `text.primary`. Appears in only a few places.
- **Body**: AI reply text (where users spend 90% of their reading time), SF Pro Text Regular 16pt, 1.45 line spacing, `text.primary`.
- **Body Prominent**: user messages, SF Pro Text Medium 16pt. Distinguished from AI replies by weight, without color.
- **Meta**: timestamps, status information, tool names, and agent/model labels, SF Pro Text Regular 13pt, `text.secondary`.
- **Micro Mono**: code snippets, file paths, and tool input/output, SF Mono Regular 12pt, `text.tertiary`. Shown only in expanded detail areas.

The type scale is the main carrier of visual hierarchy: strictly limited to four well-separated sizes, 22 / 16 / 13 / 12, with no in-between sizes.

## Card Design Language

Three shapes, split by function; this is the core of fixing the earlier color clutter:

1. **Information cards** (tool input/output, patch, diff): **no stroke**, `surface` background only. Hierarchy comes from internal typography (monospace font with whitespace). Expanded detail areas have 14pt padding. Multiple information cards on one screen keep a uniform, restrained container look and stay in the background.
   - **Tappable cues**: tool/patch cards use a neutral `surface` background overall, yet they **are interactive** (tap to view input/output or jump to a file preview). The key interactive elements **inside** the card, namely the tool icon, the tool name, tappable file paths, and the expand chevron, are highlighted in `accent` electric blue to signal clickability, while the card body keeps its neutral background. Graying out the whole card made users misread it as a disabled control (confirmed in earlier iterations). Concentrating accent on local interaction hotspots rather than flooding the whole card provides enough affordance without sliding back into colorful card clutter. Purely informational, non-interactive text (such as tool reason descriptions) stays `text.secondary` gray.
2. **Action cards** (permission, question, and other components that need a user response): no outer border, with a 3pt `accent` bar on the left over a `surface` background. The bar signals that the user needs to act and reads clearly in iOS interfaces. It is one of the few places on a screen where accent is allowed.
3. **Status lines** (turn activity, "2:30 elapsed", and similar): **not rendered as cards**. They drop the background and rounded container and render as a single line of `text.secondary` meta text, with optional monospace timing.

Corner radii are globally standardized: 12pt for information/action cards, 16pt for sheets, 6pt for inline tags. No mixing.

## Message Area

- User messages: **full width, plus a 3pt `accent` bar on the left and an `accent.muted` background**, with Body Prominent weight. The shape mirrors the action cards (the left bar is a design language that runs through the whole app). Right-aligned bubbles are dropped: bubbles use the iPad's wide screen poorly, while the bar looks more modern and crisp.
- AI replies: **no container at all**, plain `text.primary` text laid directly on `bg.primary`, separated from user messages only by 20pt spacing above and below. Streaming text renders smoothly word by word with no extra entrance animations.
- Message spacing is 20pt (the old 12pt was too cramped). Treat each message as its own unit of thought and let generous whitespace provide breathing room.

## Composer

- Input field: no stroke, `bg.secondary` background with a 16pt corner radius. Strokes suggest form fields; a free-form text input should feel borderless.
- Text review field: during transcription or retry, the partially appended or replaced transcript keeps the text box auto-scrolled to the end, typewriter style, so the newest text stays visible. In manual editing and draft restoration, the system default scrolling applies so the user's cursor is not disturbed.
- Send: a separate rounded rectangle button (not a circular icon) with a solid `accent` fill and a white icon, aligned to the bottom right of the input field so it reads as part of the input area.
- Mic: moved **inside the field on the left**, presented as an in-field function icon (`text.secondary`).
- While the AI runs: the send button **always stays** (matching established product logic: new messages can be appended while a task is running, without stopping the previous task first) and remains fixed in the **bottom slot** of the right-hand vertical stack. Stop shows as an **additional** action button **above** send (a solid rounded square of equal size, arranged in a VStack with stop on top and send below) and hides again once the AI task ends. Stop does not replace send; the two are stacked together. For color, send uses `accent` blue and stop uses red, which carries interrupt/destructive semantics.
- Voice input: the mic stays fixed in the **bottom slot** of the left-hand vertical stack. While recording, only the red mic is shown; tapping it ends the recording and moves into transcription. While transcribing, the mic shows a loading state and the right side shows `Stop transcription wait` for a forced interrupt. After an explicit interrupt, the left bottom slot switches to a retry icon button and the right side shows `Discard audio`. Retry is the single primary recovery action; discard is the light action for leaving the recovery state. The two roles are distinct and must not both become retry entries. No temporary voice state may move the send button from its fixed position.

## Motion (Best Return per Effort)

- User message entrance: offset y from 16 to 0 combined with opacity from 0 to 1, ease-out over 0.28s. AI streaming text gets no entrance animation.
- Tool card expansion: a custom spring (response 0.32, damping 0.82) for a tighter, livelier expansion than the default DisclosureGroup.
- Thinking / "N tool calls" half-width process tile expansion: **no animation**; tapping the custom-drawn header toggles directly, and the tile height change reflows the grid (accepted for the first version, no expansion animation).
- Permission/Question card entrance: slide in from below (offset y from 24 to 0) with a fade-in, which guides the user's focus better than a plain fade.
- Session switching: the message list crossfades over 0.2s, removing the jarring halt of a hard cut.
- Explicitly excluded: splash launch animations, bouncy motion, and gradient backgrounds (heavy decoration reads cheap).

## Two Layout Strategies (Small Screen vs Large Screen)

Layout and whitespace strategies differ by device form while brand, tokens, color, typography, and the card design language stay **exactly the same**. This closes the main gap in the previous spec: the iPhone should not lose operating space to excessive whitespace, while large screens such as iPad and visionOS should use generous whitespace to their advantage.

### Small Screen (iPhone, Single Column, Function First)

- Single-column architecture with bottom tab navigation (Chat / Files / Settings). The session list pushes in from an entry point at the top of Chat (or drops down) and does not permanently occupy the screen.
- Restrained whitespace: 20pt message spacing, 14pt card padding, 16pt horizontal screen margins. Breathing room without wasting vertical space.
- The toolbar has four controls: session entry, configuration (model and agent combined into one sheet), the context ring (18pt), and settings. Rename is demoted to a swipe action in the session list.
- Compact composer: single-line height by default, auto-growing to a cap of about ~100pt.

```
 iPhone Chat (dark)
 ┌──────────────────────────────┐
 │ ‹  my-session      ◌  ⚙       │  ← minimal toolbar, ◌ = context ring
 ├──────────────────────────────┤
 │ ▎Refactor the auth module     │  ← user message: left accent bar + muted background
 │                               │
 │ I'll start by reading the     │  ← AI reply: no container, plain text
 │ current implementation.       │
 │                               │
 │ ┌ read  src/auth/login.ts ──┐ │  ← info card: no stroke, surface fill
 │ │ 42 lines                  │ │
 │ └───────────────────────────┘ │
 │ ▎ Allow edit to login.ts?     │  ← action card: left accent bar
 │   Allow      Deny             │
 ├──────────────────────────────┤
 │ 🎤 Message…              [ ▷ ]│  ← mic inside field left, solid send flush right
 │ ├──────────────────────────────┤
 │  Chat      Files     Settings │
 └──────────────────────────────┘
```

### Large Screen (iPad / visionOS, Three Columns, Airy Whitespace)

The original design used a `NavigationSplitView` three-column architecture (left sidebar with the file tree on top and the session list below, file preview in the middle, chat on the right). This revision makes **targeted adjustments** on that base:

- **Column roles**: the left column is the session list (a tree with parent/child indentation, leaf dot markers, and selection state; rows show only title, time, and status, with **no summary preview**); the middle column is the core chat area (the main stage); the right column is the file preview area (single-file previews triggered by tapping tool/patch cards in chat, collapsible).
- **File tree collapsed by default** (an explicit product decision): on iPad the file tree no longer permanently takes up screen width; it becomes a "Files" disclosure at the top of the left column, collapsed by default and expandable by hand. On iPhone it remains a separate tab, freeing horizontal space for chat and preview.
- Airy whitespace: 32pt horizontal screen margins, 28pt message spacing, 18pt card padding. Generous whitespace creates a refined feel.
- Content width cap: chat text is centered and capped at about 720pt instead of filling the middle column; long lines hurt readability, and a capped width gives the layout an editorial feel.
- Right column file preview: **plain-text code with line numbers in a monospaced rendering, no syntax highlighting** (current behavior; see the future notes below), with no colored tokens drawn. Markdown gets a formatted preview and images support pinch zoom.
- visionOS adaptation: reuse the large composer branch in the existing `DesignControls` (48/56pt buttons for comfortable gaze interaction), use system glass materials, and keep the color tokens fully identical.

```
 iPad, three columns (dark)
 ┌───────────────┬───────────────────────────┬──────────────┐
 │ ▸ Files       │  my-session        ◌  ⚙    │  login.ts    │
 │ Sessions   +  │                             │  ──────────  │
 │ ───────────── │   ▎Refactor the auth module │  1  import…  │
 │ ▎my-session   │                             │  2  export…  │
 │  └ sub-task   │   I'll start by reading the │  3  …        │
 │ chat-2        │   current implementation.   │              │
 │               │   ┌ read login.ts ────────┐ │ text + line# │
 │               │   │ 42 lines              │ │ no highlight │
 │               │   └───────────────────────┘ │              │
 │               │   🎤 Message…         [ ▷ ] │              │
 └───────────────┴───────────────────────────┴──────────────┘
   ↑ ▸Files collapsed by default     ↑ body capped at 720pt     ↑ single-file preview
   Session tree (no summary preview)
```

## Empty States and Onboarding

- Empty session list: show the dark version of the logo (asset still missing; only `logo_light.png` exists today) with copy that has some brand personality, for example "Start a conversation with your code", instead of a blunt "No sessions". The logo gets a very subtle breathing animation (scale 1.0 to 1.02 to 1.0 over a 3s cycle).
- Empty chat: centered, short guidance text with no icon.

## Out of Scope List

- No gradient backgrounds: solid fills with careful whitespace and subtle motion read more premium.
- No third-party fonts: system SF Pro and SF Mono fully cover the needs and give the best system consistency and the smallest footprint.
- No splash launch animation.
- No information architecture rework: the proven bottom-tab and three-column layouts stay.
- No second persistent color: gold appears only in the transient "working" state; everything else is grayscale, with at most one accent highlight per screen.

## Feature Boundaries (This Is an Implementation Draft; Three Strict Categories)

As an implementation spec meant to guide delivery directly, every visual element in this spec must map to real functionality, sorted into three strict categories:

**Existing capabilities (this design only changes visuals; no behavior changes)**: three-tab navigation (Chat/Files/Settings); the session list sheet on iPhone; the iPad three-column layout; the ten message types rendered in the chat area (user messages, AI text, tool cards, patch cards, permission cards, question cards, todo, turn activity, streaming reasoning, with step not rendered); Markdown and zoomable image preview; the file tree (expand/collapse and git status coloring); the composer (mic/send/stop plus VoiceFlowKit voice integration); toolbar interactions (session/rename/create/model-agent picker/context ring/settings); Settings entries (Server/Project/SSH Tunnel/AI Builder/Appearance/About); nested session tree hierarchy and swipe to delete; dark and light theme switching.

**Visual refinements defined by this spec (appearance only; no new features)**: converging on a single accent color (the previous green/blue/red of permission, orange of patch, and blue of tool all collapse into electric blue, with gold strictly limited to the "working" state); replacing the old "many colors, one shape" with three card shapes; a uniform left bar on user messages; moving the mic into the input field and upgrading send to a solid button; collapsing the iPad file tree by default. None of these depend on new backend capabilities; they are pure frontend visual and layout changes.

**Explicitly excluded from this design (planned as future work; not shown in the mockups)**:
- **Code syntax highlighting**: the current implementation renders plain text with line numbers (`Text(line)`) and **has no** syntax highlighting. The mockups are drawn as plain text throughout. Syntax highlighting is planned as a future enhancement; it involves choosing a tokenizer / highlighting parser library and balancing large-file performance against rendering cost, so it stays out of this iteration and the mockups do not fake it.
- Session row summary previews, a diff sidebar, message search and editing, and file uploads were all recorded as "not shipped" in earlier audits and stay out of this design.

## Implementation Notes

`OpenCodeClient/OpenCodeClient/Utils/DesignTokens.swift` already has the basic structure for Brand/Semantic/Neutral/Opacity/Typography/Spacing/Controls/Corners. This revision focuses on **tightening the spec**: land the hex values and semantic mappings from the palettes above, clean up ad-hoc system grays and redundant Semantic color definitions, constrain the Typography scale strictly to 22/16/13/12, and align spacing with the small-screen and large-screen scales. View code must stop using casual colors such as `Color.blue/.red/.gray.opacity(…)`.

## Mockups

The mockups under `docs/design_images/` were generated with the GPT image tool (gpt-image-2). They anchor the "quiet tech" visual baseline; they are not pixel-level deliverables.

### Small Screen (iPhone, Single Column)

The chat view takes up 90% of user interaction time. Key design points: the blue accent bar on the left of user messages, container-free AI replies, information cards without strokes on a dark fill only, action cards with a left bar plus text action buttons, the composer with the mic icon inside the field on the left and the solid blue send button anchored to the bottom right, and at most one blue accent per screen.

![iPhone Chat](design_images/iphone_chat_v.png)

Session list: split into two groups, Active and Archived. Active is the default working area; Archived is a collapsible panel on the same screen, with no jump to a separate page. No session search at this stage: the current mechanism is only a title filter over locally loaded rows, and surfacing it in the UI too early would suggest a full cloud history search. The Active and Archived headers are lightweight 44pt control bars: Title Case labels, 13pt medium weight, with a light chevron icon on the right, no count badges, no decorative dividers, and no uppercase tracking, so nothing wraps in the narrow sidebar. Each row shows a title, a gray summary preview, and a timestamp; the selected row is marked only by a very light blue background plus the blue left bar, with no extra checkmark. Child sessions express parent/child hierarchy through a vertical line and dot connector. Archived entries remain tappable, but their title and time use a lighter gray and show no blue indicator bar, so they do not get confused with active work items. Swipe actions follow the existing component conventions: icon on top, label below. Delete always sits on the trailing edge in red; Archive and Restore always sit on the leading edge in restrained blue-gray tones; all swipe actions disable the full-swipe shortcut and show no secondary confirmation dialog.

![iPhone Sessions](design_images/iphone_sessions.png)

Settings: a standard grouped list. The Theme segmented control is one of the few places allowed to use the accent color; everything else stays neutral gray.

![iPhone Settings](design_images/iphone_settings.png)

Host Profiles (managing multiple OpenCode environments) follows native Form and sheet conventions, with no custom card system. The design goal here is minimizing the cognitive load of network configuration rather than visual distinctiveness: the user chooses a concrete OpenCode host, and the underlying transport is just the access channel.

![iPhone Host Profiles](design_images/host_profiles_list_v1.png)

Add Host offers a two-part entry: the convenient `Import Host Config` import at the top, with the full manual configuration form below. Direct and SSH Tunnel modes switch through a segmented control. In SSH mode, `127.0.0.1:4096` is not user editable and appears only as a `Managed by SSH tunnel` note; the core parameters distributed by the administrator are grouped under `SSH Gateway`; the device public key gets its own group and must offer a tappable `Copy This Device Public Key` action rather than sitting in static explanatory text.

![iPhone Add SSH Host](design_images/host_profiles_add_v2.png)

Design review findings: the first prototype showed "copy public key" only as explanatory text with no action, which broke the SSH onboarding flow; the `opencode` configuration row also missed the `SSH Username` label. The revision moves Import to the top level, marks where each SSH parameter comes from, and turns the local OpenCode URL from an editable input into a system-managed field. The follow-up code implementation needs to support Dynamic Type: make sure `LabeledContent` wraps or vertically stacks values under large accessibility sizes, so the `Assigned Remote Port` label and its value do not crowd or overlap each other.

The later Host Profiles design review shifted the focus from onboarding to long-term operation: an imported profile must support easy inspection, correction, and connectivity diagnostics. Verification material generated by the screenshot automation harness is saved under `/tmp/opencode-host-profiles-screenshots/`, covering Settings Current Host, the Hosts list, Host Detail, Import prefill, and the form state after an SSH import. That review fixed the UI rules: both Settings and Host Detail must offer executable, interactive diagnostics; tapping a Hosts list row opens the detail page rather than switching directly; when there is no successful connection history, show `Never connected` consistently; and SSH Host Detail must show Gateway Host, SSH Port, SSH Username, Assigned Remote Port, the local URL, `Use This Host`, `Copy Host Config JSON`, and `Copy This Device Public Key` in full.

This round of screenshot testing also surfaced two design details. First, raw Swift errors must never surface in the UI directly; for example, a failed Basic Auth attempt should present text with clear troubleshooting guidance such as `OpenCode rejected Basic Auth. Check username and password.` Second, SSH list row summary text risks truncation on narrow screens, so the summary is for basic identification and jumping into details only; the full configuration fields live in the Host Detail page.

Key technical decisions: a Host entity represents a single OpenCode runtime environment, not an individual SSH host; transports split explicitly into `direct` and `sshTunnel`, with Tailscale, VPN, LAN, and HTTPS all counting as direct; the top of Settings changes from a global connection form to a Current Host status display; the Add Host flow leads with an Import Config quick import that contains no sensitive credentials while keeping the manual configuration entry; SSH private keys are generated and managed per device by default, and multiple SSH hosts on one device share the same public key; Basic Auth passwords are stored per profile in the Keychain, with profiles holding only a reference; the TOFU trusted host is bound to the SSH gateway's `host:port`; `127.0.0.1:4096` under SSH mode is an app-managed runtime URL with no user editing in the UI; switching hosts stops SSE listening, tears down the existing SSH tunnel, loads the new profile, clears the currently selected session, and refetches health, projects, and sessions data; and the first implementation keeps profiles as the persistent source of truth, projecting them back into the existing `serverURL`, Basic Auth, and `SSHTunnelManager.config` runtime fields instead of a disruptive one-shot refactor of the APIClient, SSE, and SSH tunnel architecture.

### Large Screen (iPad / visionOS, Three Columns)

Sharing the same tokens and brand rules, the large-screen layout breathes more: session list on the left, main chat area in the middle (body text width-capped and centered with editorial whitespace), file and code preview on the right. Syntax highlighting in the code preview stays within restrained neutral grays to avoid color clutter. The Files module in the iPad sidebar stays collapsed by default; the session area expands directly with separate Active and Archived sections and no preset search field. Archive, Restore, and Delete swipe directions match the iPhone exactly.

![iPad Three Columns](design_images/ipad_threecol.png)

## Diagnosis Review (From the Previous Version; Conclusions Still Hold)

The early UI showed typical engineer thinking: a flat information hierarchy (little differentiation in type sizes and spacing), missing whitespace (12pt message spacing and 8pt card padding were cramped), weak brand identity (heavy reliance on stock SF Symbols and system default colors, reading like a basic demo project), and missing micro-interactions (few of the necessary transition animations). Each principle in this spec maps directly to and resolves one of these pain points.

---

# Tool Card Rendering Rework (Implemented; Latest Evolution: Process Tiles Are Always Half Width and Share the Two-Column Grid)

**No pixel art style, explicitly.** Everything in this section stays within the Quiet Tech design language above and adds no extra visual texture; the minimal modern icons, hairline dividers, and neutral card fills are kept as is. The rework focuses on the **information structure** rather than a new visual skin: it targets separating speaker roles and presenting tool call results efficiently.

The current pain points are twofold: (a) AI replies and user messages look too similar, making the speaker hard to identify at a glance; (b) every tool call uses the same "generic expandable DisclosureGroup with a wrench icon", while patch is treated separately as a navigation card with a full blue background. Tool cards lack semantic differentiation, and the screen fills with homogeneous gray cards.

The design makes three concrete changes: (1) clearly separate the user and OpenCode speaker roles; (2) render file operations uniformly as file cards in a two-column grid; (3) merge the remaining general tool calls into an expandable "N tool calls" tile.

## 1. Who Is Speaking (No Avatars, Titles Instead)

AI replies and user messages are currently hard to tell apart, so the speaker takes a moment to identify. The refined rules:

- **User messages**: keep the existing **blue left indicator bar** (a 3pt accent bar on the left over a muted background).
- **OpenCode replies**: **no avatar or circular icon**. Instead, add an **"OpenCode" text title** at the top of the reply (styled with a subtle distinction that clearly marks the AI speaker). Also **keep the existing small model line fully intact**, meaning the secondary gray text at the bottom of each reply noting the model (for example `claude-opus-4 · 12:04`), in the same place as today with no changes. The reply body gets no background container and no left bar.

The core idea is to define the two roles through **differentiated visual styles** (a top text title plus a bottom model line versus the blue left indicator bar) instead of the usual user avatar.

## 2. File Cards (Two-Column Grid)

**File operation tools (covering patch / edit / write / read)** render uniformly as **file cards**: a clean modern **file icon** on the left, the file name or path in monospace in the middle, and a chevron on the right to trigger the jump or expansion. Each tool call gets one card, **laid out in a two-column grid** (two cards side by side per row, matching the existing iPhone two-column grid; iPad can extend to three columns). The classification rule is `part.tool ∈ {apply_patch, edit_file, write_file, read_file}` (including legacy compatibility aliases).

## 3. Merging Into "N tool calls" (Half-Width Tile)

**All other tools (bash / test / grep / glob / list / webfetch / task and so on) merge into a single "N tool calls" tile**, with the label format fixed as **"N tool calls"** (for example `3 tool calls`), a deliberate level of abstraction that hides the specific tool categories until expanded. The component starts collapsed and is a **tile that is always half width**: it joins the file cards in the two-column (iPhone) / three-column (iPad) grid, its width set by the grid columns, and it **never stretches to full width, collapsed or expanded**.

The tile uses a custom-drawn disclosure (no system DisclosureGroup): the header is plain text (no icon, matching Android) plus a chevron on the right, with font, weight, and color following the process row spec (micro / medium / accent blue). Tapping the header toggles expansion; expanded, it lists each contained tool one by one (reusing the existing ToolPartView expansion logic). **Content stays inside the half-width tile** (narrow column), the tile grows taller, and the grid reflows.

## Arrangement: Half-Width Tiles Share the Two-Column Grid

Thinking (ThinkingCard), the merged "N tool calls" tile, and file cards **all join one LazyVGrid with two columns (iPhone) / three (iPad)**, tiles ordered by the original part order: each reasoning part becomes a half-width ThinkingCard tile, each file operation becomes its own half-width file card tile, and the non-file tools merge into **one** half-width "N tool calls" tile. All process tiles are **always half width**; the grid columns set the width and expansion never stretches to full width. **Expanded content stays inside the half-width tile** (narrow column), the tile grows taller, and the grid reflows (accepted for the first version, no animation).

Text and attachment blocks stay out of the grid and **render full width after it** (reading order: grid first, full-width text after; accepted by the user). No extra grouping, and no category headers such as "Files updated" or "Actions".

File cards follow the Quiet Tech neutral card rules (neutral `surface` fill, no border stroke, 12pt corner radius); thinking / tool calls tiles keep the light process-row form (no heavy card face), with color accents limited to the file icon, header, and chevron areas, keeping at most one blue accent per screen.

![Tool cards: speaker separation, two-column file cards, N tool calls](design_images/tool_cards_chronological.png)

> This mockup fixes the final direction: user messages carry the blue left indicator bar; OpenCode replies get an "OpenCode" text title plus the bottom model line (`claude-opus-4 · 12:04`) with no avatar; file operations gather into a two-column file card grid (`client.ts` / `types.ts` / `README.md` / `utils.ts` and so on); the remaining tool calls collapse into `▸ 3 tool calls`. Typography is a clean sans-serif throughout, with no pixel texture.

## Out of Scope / Boundaries

- **No pixel art style, firmly**: the core value is the **information structure** built from "speaker separation / file cards / N tool calls", not a pixel visual texture. The design strictly keeps the minimal, restrained Quiet Tech rules.
- **No extra grouping and no category headers.**
- **File cards keep the file icon and the two-column grid**; AI replies **use no avatar** and **must show the "OpenCode" text title**; **the bottom model line stays exactly as it is**.
- **The model picker keeps its current behavior; no user avatar is added to the top right.**
- The **"AI working"** state keeps the existing subtle gold animation, with no pixelation.
- **This section is an exploratory design spec**; the underlying code changes to `ToolPartView`, `PatchPartView`, and `MessageRowView` are deferred to a follow-up implementation PR.
