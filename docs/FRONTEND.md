# Frontend and mobile verification

Supported runtimes: iOS 17.0+, iPadOS, visionOS 26.0+ (single
`OpenCodeClient` scheme). The canonical testing architecture is
[tests.md](tests.md) (Tiers 1–4); this page is the runtime UI/device
verification contract.

## Minimum flow verification

1. Start the actual app in a pinned simulator (the `scripts/lib_simulator.sh`
   machinery: pinned UDID, 15s preflight probe, dedicated derived data) or on
   device.
2. Exercise the affected journey end to end, including restart/persistence
   where applicable (UserDefaults-backed stores require isolated suites in
   tests — `docs/CHECKLISTS.md`).
3. Check loading, empty, network failure, retry, permission denial, and error
   feedback (e.g. send-failure restores the input; local-network permission
   prompt on first connect).
4. Check keyboard, IME composition, small screens, and iPad/visionOS layout
   for affected UI.
5. Inspect console/runtime errors; treat known system-keyboard constraint
   noise and simulator SpringBoard crashes as non-app issues
   (`docs/WORKING.md` Problems 5/9).
6. Capture proof (test report, screenshot, or video) for major UI changes and
   tie it to the tested commit/environment.

## Tooling

- Tier 2 fixture UI tests run offline (`UITEST_*` fixtures; e.g.
  `SessionScrollAnchorUITests`, `ToolCardsUITests`, `TaskNotificationUITests`)
  via `./scripts/test_ui.sh`.
- Tier 3 (integration) requires a local OpenCode test server with
  credentials/agent config; never the owner's live server (`AGENTS.md`).
- Tier 4 (LLM-driven UI) uses the repo-root `skills/`:
  `operate_ios_simulator.md` (simulator operation), `ui_test_tasks.md` and
  `ui_test_prompts/` (task workflow and prompts), with the
  `Tier4DriverUITests` driver and the `ui_driver` helper (its own pytest
  suite — see `docs/tests.md`).
- Launch/perf UI tests are skipped by default;
  `OPENCODE_UI_TEST_INCLUDE_LAUNCH=1` includes them.

Browser E2E does not apply to this repo; native verification is Xcode-based.
Linux runners never verify the app (`docs/STACKS.md`).
