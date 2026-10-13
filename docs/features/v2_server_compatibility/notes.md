# OpenCode server v2 compatibility — implementation notes

Status: implemented on `opencodev2-integration`；live contract gate 已过（45/45，2026-10-12）；TestFlight 验证待做。
日期：2026-10-12
Spec：`docs/v2_server_compatibility.md`（wire 契约的唯一来源）

## 背景

用户的 server 已是 v2.0.26，而客户端只讲 v1 HTTP/SSE。Spec 实测于 v2.0.18–2.0.20：路由前缀 `/api/*`、事件名换血（`session.text.*`、`form.*`）、部分 v1 行为无 v2 对应（todo、archive 写）。

## 改动

- **检测**（`Services/ServerGeneration.swift`）：`HostProfile.apiGeneration`（`auto|v1|v2`，缺失解码为 auto，URL 变更即清除）。连接时探测 `GET /global/health` → `GET /api/info`（8KB body、JSON 必须可解析、401/403 与超时不再探测另一条腿）。探测结果写回 profile 并驱动 `APIClient.generation`。
- **REST 分支**（`Services/APIClient+V2.swift` + 各方法顶部 `generation == .v2` 分支）：spec「Every current method」表逐行实现。精确状态码（prompt 200 否则抛、agent/model switch 204、删除/回复 204）；`updateSessionArchived` 不发请求直接抛 404；`sessionTodos` 直接返回 `[]`；表单回复表（form id → session + 字段 + label→value）存在 `APIClient`，由 `pendingQuestions(sessionID:)` 与 SSE `form.created` 灌入。
- **纯映射**（`Services/V2Mapper.swift`）：session/message/form/permission/model/agent/diff/file/project/status 全部按 spec 表实现，产物是既有模型类型，不新增第二种 Session/Message。
- **SSE**（`Services/SSEClient.swift` + `AppState+SSE.swift`）：v2 帧 `{id,type,data}` 归一化为 v1 事件形状（`payload` 是 v1 必填字段，故 v1→v2 依次解码无歧义）；`handleV2SSEEvent` 按 spec SSE 表逐行翻译成既有 handler 接受的属性字典，数据路径（`MessageStore` upsert / completeness gate）与 v1 完全共用；`session.text.started` 的无 text part 按 spec 触发一次 REST 回退；`session.created/renamed/metadata.updated` 走 GET + `applySessionUpdate`。
- **已批准的两处 spec 偏差**：① v2 `type:"synthetic"` 消息被映射（回执卡片在 v2 可见）；② `isConnected` 在探测成功即置位，不加 session-list gate。

## 测试

- `ServerGenerationTests`：探测 saved-body（v1 healthy / unhealthy / HTML / 空 500 / `/api/info` v2 / 401 不续探 / 超时 / 8KB 截断）+ HostProfile 绑定 + 连接流（mock 注入）。
- `V2MapperTests`：spec「Unit tests」每行一条（session map、message 行、prompt 编码、archive、permission、form、model、project、diff、file status、todos 空、delta part id、CarResponseEnvelope）。
- `V2APIWireTests`：URLProtocol stub 下的 wire 断言（路径/查询/请求体/精确状态码、form 表 404、structured send 409 容忍 + 轮询、v1 路径不变）。
- `V2SSETests`：帧判别 + AppState 级翻译（started→delta→ended 收敛、execution.failed 标记发送失败、form 生命周期、permission 流）。

## 未决

- ~~`scripts/v2_contract_check.py` 对 2.0.26 的实跑~~ **已通过**：2026-10-12 对 live server（`http://127.0.0.1:4096`，`2.0.26-local.27a15e7935`）45/45 全过、exit 0。无 spec 漂移。
- ~~v2 `type:"synthetic"` 的真实字段布局未实测~~ **已实测**：扫描 live server 全部 69 个 session 共 297 条 synthetic 行，仅两种形状且都带顶层 `text`（mapper 主路径直接命中）：
  1. `{id, time.created, text, type}`（14 条，plan-mode system-reminder）
  2. `{id, time.created, text, description, metadata.instruction.paths, type}`（283 条，AGENTS.md 指令加载，`description` 如 "Loaded packages\cli\AGENTS.md"）
  `payload.text` 从未出现；额外字段 mapper 不读、无害。`V2MapperTests` 的 synthetic fixture 已替换为真实抓取的两种 body（一条覆盖富形状 + 一条覆盖最小形状）。未发现 `<task>` 回执语法的 wire 端 body——回执卡片文本由客户端自行合成，wire 侧只需 synthetic 行以 user 形态到达（已证实）。
- 待做：PR #1 合并（用户决定）→ TestFlight 真机验证（检测连版本号、流式、图片、agent/model 切换、permission/question 卡、404 archive、todos 空、Car Mode、回执卡）。
