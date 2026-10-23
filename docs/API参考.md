# API 参考 · 本地引擎与模型网关

> 版本：v0.3（单机离线）
> 最后更新：2026-10-23
> 上游：[技术方案](./技术方案.md) ｜ 相关：[Prompt 契约](./Prompt契约.md)
>
> v0.3 变更：模型网关支持三种协议（OpenAI Chat Completions / OpenAI Responses / Anthropic Messages），内置 DeepSeek 与 OpenAI 预设；`.run` 存档包独立于 `.world`。
>
> v0.2 变更：**没有任何自建 HTTP 端点**。本文档描述 App 内两套接口：① Dart 引擎门面（进程内调用）；② 发往用户自选模型服务的请求契约。

---

## 1. 通用约定

| 项 | 约定 |
| --- | --- |
| 调用形态 | 进程内 Dart 方法，返回 `Future` 或 `Stream` |
| 数据来源 | 本地 SQLite（drift），无网络往返 |
| 时间 | 存储统一 Unix 毫秒；世界内时间用字符串 |
| 分页 | 本地列表用 `limit` / `offset`，M0 数据量小，UI 可全量读 |
| 并发 | 同一 `runId` 的回合由进程内串行队列保证串行 |
| 幂等 | 单回合写入在 SQLite 事务内完成；UI 在 `submitting` 期锁输入 |
| 日志 | 本地滚动日志，含 `runId` / `turnNo` / `role`，默认保留 7 天 |

### 错误结构

所有引擎方法抛同一个类型，UI 按 `code` 分支，不解析 `message`：

```dart
class EngineException implements Exception {
  final EngineCode code;
  final String message;      // 面向用户的中文短句
  final Map<String, Object?>? details;
  final bool canRetry;
}
```

### 错误码

| code | 含义 | 客户端处理 |
| --- | --- | --- |
| `NOT_FOUND` | 世界 / 局 / 快照不存在 | 返回世界库 |
| `TURN_CONFLICT` | `expectedTurn` 与库中不一致 | 重新读库刷新，不自动重放 |
| `RUN_ENDED` | 该局已结束 | 进入人生档案 |
| `MODEL_NOT_CONFIGURED` | 未填 Key 或 baseUrl | 引导去设置页 |
| `MODEL_AUTH_FAILED` | 401/403，Key 无效或余额不足 | 提示检查 Key，不重试 |
| `MODEL_RATE_LIMITED` | 429 | 按 `Retry-After` 退避，可重试 |
| `MODEL_TIMEOUT` | 连接 / 首字 / 空闲超时 | 可重试一次 |
| `MODEL_BAD_OUTPUT` | 结构化输出连续不可解析 | 降级场景，可重试 |
| `MODEL_NETWORK` | 无网络、DNS、TLS 失败 | 提醒检查网络，可重试 |
| `CONTENT_BLOCKED` | 输入或生成命中本地规则 | 引导换一种表达 |
| `STATE_INVALID` | 状态校验不可恢复 | 上报日志，允许回滚快照 |
| `STORAGE_FULL` | 本地磁盘不足 | 提示清理旧局或导出 |
| `IMPORT_INVALID` | `.world` / `.run` 包结构、校验和或格式版本不通过 | 展示具体原因 |
| `IMPORT_TOO_LARGE` | 超过 20 MB 或解压后超限 | 拒绝 |
| `EXPORT_FORBIDDEN` | 该世界 `exportable = 0`，或所属世界不可导出导致该局 `.run` 不可导出 | 说明为导入来源，不可导出 |
| `DRAFT_INCOMPLETE` | 草稿完整度不足，不可生成或冻结 | 展示缺失字段，回到访谈 |
| `QUALITY_GATE_FAILED` | 一致性检查存在 `error` 级问题 | 打开编辑器定位问题项 |
| `WORLD_FROZEN` | 已冻结版本不可修改 | 提示另存为新草稿 |

> 没有 `AUTH_REQUIRED`、`FORBIDDEN`、`QUOTA_EXCEEDED`、`CONFLICT`：无账号、无配额、无多端写入。

---

## 2. 引擎门面清单

| 方法 | 说明 |
| --- | --- |
| `Engine.open()` | 打开本地库、执行迁移、导入内置世界（仅首次） |
| `worlds.list()` | 本地世界库列表（内置 / 自建 / 导入 / 分享） |
| `worlds.get(worldId)` | 世界公开介绍与版本；**不返回 NPC 私密面与种子细节** |
| `runs.draw(worldId, {count})` | 抽取身份卡 |
| `runs.create({worldId, identityId, drawToken})` | 用身份开局，返回序章与首批选项 |
| `runs.list()` | 我的局列表 |
| `runs.get(runId)` | 当前局与待选状态 |
| `turns.run(runId, expectedTurn, input)` | 推进一回合，返回 `Stream<TurnEvent>` |
| `runs.branch({snapshotId})` | 从快照开新世界线 |
| `runs.archive(runId)` | 人生档案 |
| `runs.exportPack(runId)` | 导出 `.run` 存档包（当前局 + 快照 + 事件） |
| `runs.importPack(File)` | 导入 `.run` 存档包，落地为本机新局 |
| `runs.delete(runId)` | 删除一局（含快照与事件） |
| `assistant.ask(runId, text)` | 向随行助手提问，返回 `Stream<AssistantEvent>` |
| `library.import(File)` | 导入 `.world` 包 |
| `library.export(worldId)` | 导出 `.world` 包，返回文件路径 |
| `library.rename(worldId, title)` | 重命名本地世界 |
| `library.delete(worldId)` | 删除世界、版本与原件 |
| `usage.summary({from, to})` | 本地用量与成本估算 |
| `settings.testConnection()` | 用最小请求验证 baseUrl + Key + 模型名 |

---

## 3. 详细定义

### Engine.open()

```dart
final engine = await Engine.open();
```

首次启动时：建库 → 跑迁移 → 从 `assets/seed/cangwu/` 写入 `worlds` + `world_versions`（`source = 'builtin'`）。重复启动跳过种子写入。

### worlds.list()

```dart
final worlds = await engine.worlds.list();
// WorldSummary(id, title, genre, summary, source, version, identityCount, updatedAt)
```

### worlds.get(worldId)

返回世界公开介绍、当前版本号、身份数量、终局数量。**不返回 NPC 私密面与事件种子细节**；这些只留在引擎内部供导演使用。

### runs.draw()

```dart
final draw = await engine.runs.draw('w_cangwu', count: 3);
// DrawResult(drawToken, expiresAt, identities: List<Identity>)
```

`drawToken` 是进程内一次性令牌，默认 5 分钟有效，防止 UI 跨页丢失身份来源。**不扣减任何配额**（无服务端）。

### runs.create()

```dart
final start = await engine.runs.create(
  worldId: 'w_cangwu',
  identityId: 'id_herb_apprentice',
  drawToken: draw.drawToken,
);
// StartResult(run, state, prologue, choices)
```

开局序章一次性生成（非流式），保证首屏稳定。若模型未配置，返回 `MODEL_NOT_CONFIGURED`，UI 先跳设置。

### runs.get(runId)

```dart
final view = await engine.runs.get('r_2b9');
// RunView(run, state, lastTurn, pendingChoices, worldLine)
```

用于冷启动、从后台返回、`TURN_CONFLICT` 后的重新同步。

### turns.run()

```dart
final stream = engine.turns.run(
  'r_2b9',
  expectedTurn: 17,
  input: const ChoiceInput('c2'),
  // 或 const FreeTextInput('我去后山看看'),
);
await for (final event in stream) { ... }
```

事件顺序固定：`turnStart → (classification) → narrationDelta* → narrationEnd → choices → statePatch → turnEnd`；失败则最后是 `turnError`，不与 `turnEnd` 同时出现。

### runs.branch()

```dart
final branch = await engine.runs.branch(snapshotId: 's_11');
// BranchResult(runId, forksFrom, state)
```

从快照开**新的一局**，旧局原样保留。新局继承当时的身份与世界版本，不继承之后的任何事件。M0 限定每局最多 3 条世界线。

### runs.archive()

```dart
final archive = await engine.runs.archive('r_2b9');
// Archive(endingId, title, epitaph, tags, keyChoices, stats, availableBranches)
```

### assistant.ask()

```dart
await for (final e in engine.assistant.ask('r_2b9', '苏晚这个人可信吗？')) { ... }
// AssistantDelta(text) / AssistantEnd(usage)
// 失败按 Prompt 契约返回固定文案，仍以 AssistantDelta + AssistantEnd 收尾，不新增错误事件
```

`AssistantEvent` 只有两种：`AssistantDelta(text)` 与 `AssistantEnd(usage)`。

助手不写状态、不推进回合。只读 `RunState.knowledge` 与公开世界信息，不读 NPC 私密面与未回收伏笔的隐藏内容。

### library.export() / library.import()

```dart
final file = await engine.library.export('w_cangwu');   // 生成 .world 到 exports/
await engine.library.import(pickedFile);                 // 校验后写入 worlds/world_versions
```

导出前置检查 `worlds.exportable = 1`，否则 `EXPORT_FORBIDDEN`。包格式与校验规则见[世界分享与本地世界库](./世界分享与UGC.md) §4。

### usage.summary()

```dart
final s = await engine.usage.summary(from: ..., to: ...);
// UsageSummary(turns, tokensIn, tokensOut, estimatedCost, byRole, failures)
```

### settings.testConnection()

发一个 `max_tokens = 8` 的最小请求，返回 `ConnectionReport(ok, model, latencyMs, errorCode?)`。不写任何业务表。

---

## 4. TurnEvent 定义

```dart
sealed class TurnEvent {}
class TurnStart        extends TurnEvent { final int turn; }
class Classification   extends TurnEvent { final IntentKind kind; }
class NarrationDelta   extends TurnEvent { final String text; }
class NarrationEnd     extends TurnEvent {}
class ChoicesAvailable extends TurnEvent { final List<Choice> options; }
class StatePatch       extends TurnEvent { final StateDelta delta; }
class TurnEnd          extends TurnEvent { final int turn; final String? snapshotId; final Ending? ending; }  // 查询/meta 未落库时 snapshotId 为 null
class TurnError        extends TurnEvent { final EngineCode code; final String message; final bool canRetry; }
```

约定：

- `narrationDelta` 可多次，UI 增量追加，不整段替换。
- `statePatch` 只在落库成功后发出，是数值面板的唯一来源。
- `turnEnd` 之后流关闭；调用方不得继续监听。
- 同一 `runId` 并发调用会被串行队列排队，UI 侧仍必须锁按钮。

---

## 5. 模型网关契约

### 5.1 协议适配

网关支持三种协议，由设置页的 `protocol` 决定；上层业务只传 `role`，不感知协议。内置预设为 **DeepSeek**、「**OpenAI（Responses）**」「**OpenAI（Chat Completions）**」，另可自定义任意兼容端点。

| protocol | 端点 | 鉴权头 | 结构化输出 |
| --- | --- | --- | --- |
| `openai_chat` | `POST {baseUrl}/chat/completions` | `Authorization: Bearer {key}` | `response_format: json_object` |
| `openai_responses` | `POST {baseUrl}/responses` | `Authorization: Bearer {key}` | `text.format: { type: "json_object" }` |
| `anthropic_messages` | `POST {baseUrl}/v1/messages` | `x-api-key: {key}` + `anthropic-version: 2023-06-01` | 无原生 JSON 模式，走前缀约束 + 本地校验 |

预设值（模型名可在设置页改）：

| 预设 | protocol | baseUrl | 叙事模型 | 小模型 |
| --- | --- | --- | --- | --- |
| DeepSeek | `openai_chat` | `https://api.deepseek.com/v1` | `deepseek-chat` | `deepseek-chat` |
| OpenAI（Responses） | `openai_responses` | `https://api.openai.com/v1` | `gpt-4.1` | `gpt-4.1-mini` |
| OpenAI（Chat Completions） | `openai_chat` | `https://api.openai.com/v1` | `gpt-4.1` | `gpt-4.1-mini` |
| 自定义 | 三选一 | 用户填写 | 用户填写 | 用户填写 |

三种协议的请求体差异：

```jsonc
// openai_chat
{ "model": "...", "messages": [{ "role": "system", "content": "..." }, { "role": "user", "content": "..." }],
  "stream": true, "temperature": 0.8, "max_tokens": 1200,
  "stream_options": { "include_usage": true } }

// openai_responses
{ "model": "...", "instructions": "...", "input": [{ "role": "user", "content": "..." }],
  "stream": true, "temperature": 0.8, "max_output_tokens": 1200 }

// anthropic_messages
{ "model": "...", "system": "...", "messages": [{ "role": "user", "content": "..." }],
  "stream": true, "temperature": 0.8, "max_tokens": 1200 }
```

差异归一：`system` 段在 Anthropic 提到顶层，`messages` 只保留 user/assistant；Responses 把 system 放进 `instructions`。三条路径最终都产出同一份「系统段 + 用户段」结构。

### 5.2 流式解析

| protocol | 增量字段 | 结束信号 | usage |
| --- | --- | --- | --- |
| `openai_chat` | `choices[0].delta.content` | `data: [DONE]` | 末帧 `usage`（需 `stream_options`） |
| `openai_responses` | `response.output_text.delta` 的 `delta` | `response.completed` | 该事件内 `response.usage` |
| `anthropic_messages` | `content_block_delta` 的 `delta.text` | `message_stop` | `message_start` + `message_delta` |

通用规则：

- 逐行读取 SSE，单行 JSON 解析失败：记日志、跳过该帧，不中断整条流。
- 推理类字段（`reasoning_content` / `reasoning` / `thinking`）只计数，不进正文。
- 首个 token 之前断开：可重试；已输出正文后断开：保留正文，报 `MODEL_TIMEOUT`，不落库。
- 三种协议的差异只在 `llm/adapters/` 内处理，`TurnEvent` 序列与业务代码完全一致。

### 5.3 超时与重试

| 项 | 值 |
| --- | --- |
| 连接超时 | 10 s |
| 首字超时 | 30 s |
| 流空闲超时 | 30 s |
| 单次总超时 | 180 s |
| 网络错误重试 | 2 次，指数退避 1 s / 3 s |
| 超时重试 | 1 次 |
| 429 | 读 `Retry-After`，最多等 30 s，重试 1 次 |
| 4xx（401/403/400） | 不重试，直接映射错误码 |

### 5.4 Token 记账

优先读响应里的 `usage`（位置见 §5.2 表格；`openai_chat` 需请求带 `stream_options: {"include_usage": true}`）。缺失或为 0 时按估算：中文约 1 token ≈ 1.5 字，英文约 4 字符 ≈ 1 token，并标记 `estimated: true`。结果写入 `usage_log`，仅本地。

### 5.5 Key 的边界

- Key 只存在 `flutter_secure_storage`（iOS Keychain / Android Keystore），不写入 `app_settings`、不进日志、不进导出包、不随崩溃报告上报。
- Key 只发往用户填写的 `baseUrl`；App 不代理、不中转、不落盘。
- 设置页提供「清除 Key」与「重置全部设置」。

---

## 6. 版本与兼容

- 无 URL 版本化，改为 `Engine.apiVersion`（当前 `1`）。破坏性变更升主版本，并在启动时提示用户「此版本存档需要升级」。
- `.world` 与 `.run` 包内的 `manifest.formatVersion`、以及库内的 `RunState.schemaVersion` 各自独立演进；导入时向前兼容一个版本，超出范围报 `IMPORT_INVALID`。
- `.run` 包必须携带所绑定世界的 `worldId + worldVersion`；本机没有该版本时拒绝导入并提示「先导入对应世界」，不允许自动升级到新版本。
- 引擎新增字段不视为破坏性变更；删除或改名必须提供迁移函数。

---

## 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-23 | v0.1：HTTP 端点、SSE、错误码、配额 |
| 2026-10-23 | v0.2：改为本地引擎门面 + 模型网关契约；删除账号、配额、409、幂等键与服务端错误码 |
| 2026-10-23 | v0.3：新增三种模型协议适配、供应商预设、`.run` 存档包导入导出 |
