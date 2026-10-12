# OpenCode server v2 compatibility — implementation notes

Status: implemented on `opencodev2-integration`；live 验证（contract script + TestFlight）待做。
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

- v2 `type:"synthetic"` 的真实字段布局未实测（spec 未写）；实现按 user 行同构（`text`/`payload.text`）。待从 live server 抓一个真实 body 后固化 fixture；若形状不符，回退为 dark 并回报。
- `scripts/v2_contract_check.py` 对 2.0.26 的实跑（需要 server 密码）。
