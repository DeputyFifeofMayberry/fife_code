# OpenCode iOS Client Docs Index

> Last updated: 2026-10-12 (the v2 server compatibility implementation lives on the opencodev2-integration branch; the spec docs are indexed here). Consult this index first when looking up any document.

## Top-Level Main Documents (Living)

| File | Role | Status |
|---|---|---|
| `OpenCode_iOS_Client_PRD.md` | Product requirements (full client feature set) | living |
| `OpenCode_iOS_Client_RFC.md` | Technical architecture design (end-to-end client) | living |
| `WORKING.md` | Progress, troubleshooting, and decision log (changelog) | living |
| `tests.md` | Testing architecture spec (Tiers 1–4) | living |
| `design.md` | Visual design spec (Quiet Tech style) | living |
| `OpenCode_Web_API.md` | OpenCode server HTTP API reference (upstream snapshot; the official docs and the live `/doc` endpoint are authoritative) | living reference |
| `v2_server_compatibility.md` | V1/V2 server compatibility spec (the single source of truth for the wire contract; the client v2 branch implements it) | living; implemented, pending live verification |
| `lessons.md` | Engineering retrospectives and reusable lessons | living |

## features/ (Per-Feature Documents)

| Directory | Feature | Files | Status |
|---|---|---|---|
| `client_capabilities/` | Device capability extension (V0: Health export) | `prd.md` / `rfc.md` / `protocol.md` | V0 shipped; the protocol is the source of truth for the wire contract |
| `context_compaction/` | Manual context compaction | `design.md` | proposal only, not implemented |
| `session_finder/` | Session Finder, smart session retrieval | `design.md` | design draft |
| `background_task_notification/` | Background subagent task notification rendering (TaskNotificationCard + a synthetic general rule) | `design.md` | implemented |
| `push_notifications/` | Background push notification approach | `research.md` | research |
| `localization/` | en/zh-Hans bilingual localization | `research.md` | Settings already has en/zh; the research doc is somewhat outdated |
| `agent_catalog_validation/` | Agent catalog validation and visible delete failure | `notes.md` | shipped; the selected agent is checked against the current server `/agent`, and a non-2xx delete surfaces the status code and body |
| `v2_server_compatibility/` | OpenCode server v2 compatibility (detection + REST/SSE branching) | `notes.md` | implemented (`opencodev2-integration`); live verification pending |

## archive/ (One-Off Work Records and Frozen Decisions; Append Only)

| File | Content |
|---|---|
| `2026-06_markdown_web_preview_prd.md` / `_rfc.md` | Markdown Web Preview subproject design; decisions merged into the main PRD §4.3.5 / main RFC §7.5. The files stay local under `docs/archive/`, untracked + gitignored, **not distributed with the repo** |
| `2026-06_visual_writing_weapon_system.md` | Visual and writing style discussion draft |
| `2026-07_yage_fix_work.md` | opencode-official fork fix records |
| `2026-08_qwen38_rendering_fix.md` | qwen38 rendering fix record (PR #145) |

## skills/ (Repo Root, Agent-Facing Operational Skills)

| File | Role |
|---|---|
| `skills/client_capabilities.md` | The canonical agent entry point for adding a client capability |
| `skills/operate_ios_simulator.md` | iOS simulator automation operation layer |
| `skills/ui_test_tasks.md` | Tier 4 UI test task workflow |
| `skills/ui_test_prompts/` | Tier 4 test prompt collection |

## Other

- `design_images/`: mockup illustrations for `design.md` (generated with gpt-image-2; not pixel-level final implementation art)
- `logo_light.png`: the app logo icon

## Conventions

- The top level holds only living main documents; per-feature documents go under `features/<name>/`; one-off work records are archived under `archive/` (filename prefixes follow the `YYYY-MM_` convention).
- `tmp_*` files are design drafts not tracked in version control; they stay out of git and out of the archive and never serve as the source of truth; key conclusions must be distilled into the formal documents promptly.
- When adding a client capability, update the corresponding documents strictly following the "Output location" section of `skills/client_capabilities.md`.
