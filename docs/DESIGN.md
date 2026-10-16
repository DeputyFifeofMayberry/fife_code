# Design system and visual acceptance

The canonical visual specification is [design.md](design.md) ("Quiet Tech");
mockup illustrations live in `design_images/` (concept art, not pixel-final).
This page is the adapter summary and the acceptance rules.

- Design language: dark-first, low saturation, developer-tool feel
  (Raycast/Vercel/Arc reference); one accent (electric blue `#3B82F6`), gold
  `#D9A621` only for the transient "AI working" state; no stock
  `.red/.green/.orange/.purple`.
- Type scale, spacing, colors, iconography: semantic tokens in `DesignTokens`
  (`Color(light:dark:)`); views reference semantic names only; hierarchy via
  size/weight/whitespace, never color stacking.
- Component states: functional categories separated by **card shape**;
  borderless-first for information containers; accent bar only on
  action-required cards; loading/empty/error states use viewport-height
  frames where applicable (see the session-switch fix history in
  `docs/WORKING.md`).
- Interaction/navigation: stable composer buttons never move (send/mic fixed;
  temporary actions appear above); iPhone single-column, iPad/visionOS
  three-column `NavigationSplitView`; session switch rebuilds the scroll
  view identity anchored to the bottom.
- Motion: spring 0.3–0.35/0.8 or 250–300ms ease-out; opacity crossfades over
  translations; no splash/bouncy effects.
- Accessibility: reduced motion respected; contrast from the token palette;
  touch targets per iOS defaults.

For each UI task, capture and review visual evidence on the relevant target
(device or simulator) and document expected vs actual behavior; screenshots
cannot establish hidden-state correctness and must be tied to the tested
commit (`docs/REVIEW_EVIDENCE.md`).
