# Architecture

Map of the real system. The canonical end-to-end technical design lives in
[docs/OpenCode_iOS_Client_RFC.md](docs/OpenCode_iOS_Client_RFC.md); this page
is the quick map and the dependency rules. Record non-obvious structural
choices as ADRs in `docs/decisions/`.

## System map

- Entry points: `OpenCodeClient/OpenCodeClient/OpenCodeClientApp.swift` and
  `ContentView.swift` (single shipped app target; same scheme/bundle id for
  iPhone, iPad, and Apple Vision Pro).
- Application core: `AppState` plus per-domain extensions
  (`AppState+Sessions/Messages/SSE/FileTree/Models/HostProfiles/Permissions/...`)
  in `OpenCodeClient/OpenCodeClient/`; extracted state stores live in
  `Stores/` (SessionStore, MessageStore, FileStore, TodoStore), with
  `Controllers/`, `Services/` (APIClient + `APIClient+V2`, SSE connection,
  SSHTunnelManager, ServerGeneration probe), `Models/` (wire models,
  `V2Mapper`, decoders), `Views/`, `Utils/` (PathNormalizer, design tokens).
- Storage and schemas: server-authoritative sessions/messages; on-device
  persistence is `UserDefaults`-backed stores (host profiles, model shortlist,
  step timings, session stats) and a gitignored per-checkout simulator/test
  state directory (`.occlient/`). No local database.
- External APIs and trust boundaries: the OpenCode server REST + SSE API in
  two generations (v1 and v2 per `docs/v2_server_compatibility.md`), the
  optional AI Usage Dashboard quota endpoint, and outbound SSH tunnels
  (Citadel) to a user-configured gateway. The server is untrusted input:
  decoders validate and fall back (see `docs/RELIABILITY.md`).
- Deployment environments: TestFlight (manual dispatch via
  `.github/workflows/release-testflight.yml`, bundle id
  `com.deputyfife.opencode`); CI in `.github/workflows/tests.yml` (macOS
  build/unit/UI + Linux foundation gate); read-only ASC status checks in
  `check-testflight.yml`. Procedures: `docs/RUNBOOKS.md`.
- Runtime observability and logs: no telemetry; diagnosis relies on Xcode
  console output, `os_log`-style prints, and CI logs. Server-side logs belong
  to the upstream checkout (`opencode-official/`, gitignored), not this repo.

## Dependency rules

- `Views/` → `AppState`/stores → `Services/` → `Models/` (wire decoding).
  Views never call `APIClient` directly; network access is centralized so the
  v1/v2 branch has exactly one choke point per endpoint.
- Wire decoding is pure and testable: `V2Mapper` maps raw v2 rows onto the
  existing v1-era models; no view or store code parses JSON.
- `AppState` extensions may only touch their own domain slice plus the stores;
  cross-module logic consolidates into a single layer (see `docs/lessons.md`
  lesson 7).
- Server-side code never enters this repo; upstream patches belong to
  `opencode-official/` (gitignored) or upstream (`AGENTS.md` rule).
- Machine checks: the architecture verification category runs the doc/config
  layer (`scripts/checks/architecture.py`); Swift layer rules are not yet
  code-enforced — tracked in `docs/TECH_DEBT.md`.

## Change control

- Public contract changes (wire handling, host-profile persistence, API
  branching) require the v1/v2 spec table to be updated first
  (`docs/v2_server_compatibility.md` is the single source of truth), then
  code + tier-1 tests (`docs/TESTING.md`).
- New dependencies need rationale and a license/compatibility check; visionOS
  constraints currently pin forked MarkdownUI/NetworkImage packages (see
  `README.md`, "Building from Source").
- `xcodebuild build` and `xcodebuild test` must run sequentially (shared
  DerivedData build database) — `AGENTS.md` and `docs/CHECKLISTS.md` rules.
