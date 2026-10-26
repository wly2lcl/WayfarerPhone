# API 参考 · 本地引擎与模型网关

> 版本：v0.4（单机离线）
> 最后更新：2026-10-24
> 上游：[技术方案](./技术方案.md) ｜ 相关：[Prompt 契约](./Prompt契约.md)
>
> v0.4 变更：M1 世界工坊接口落地——新增 `drafts.*()` 门面定义与错误码语义；`runs.list()` 标注不含试玩局。
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
| `IMPORT_INVALID` | `.world` / `.run` 包结构、校验和或格式版本不通过；TXT 导入中文件不存在 / 编码无法识别 / 内容与任务记录不一致 | 展示具体原因 |
| `IMPORT_TOO_LARGE` | 超过 20 MB 或解压后超限（TXT 导入与包导入同一上限） | 拒绝 |
| `EXPORT_FORBIDDEN` | 该世界 `exportable = 0`，或所属世界不可导出导致该局 `.run` 不可导出 | 说明为导入来源，不可导出 |
| `DRAFT_INCOMPLETE` | 草稿完整度不足，不可生成或冻结 | 展示缺失字段，回到访谈 |
| `QUALITY_GATE_FAILED` | 一致性检查存在 `error` 级问题 | 打开编辑器定位问题项 |
| `WORLD_FROZEN` | 已冻结版本不可修改；内容未变时重复冻结同样报此码 | 提示已是最新冻结版本；修改内容后再冻结出新版本 |

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
| `runs.list()` | 我的局列表（不含试玩局） |
| `runs.get(runId)` | 当前局与待选状态 |
| `turns.run(runId, expectedTurn, input)` | 推进一回合，返回 `Stream<TurnEvent>` |
| `runs.branch({snapshotId})` | 从快照开新世界线 |
| `runs.archive(runId)` | 人生档案 |
| `runs.exportPack(runId)` | 导出 `.run` 存档包（当前局 + 快照 + 事件） |
| `runs.importPack(File)` | 导入 `.run` 存档包，落地为本机新局 |
| `runs.delete(runId)` | 删除一局（含快照与事件） |
| `assistant.ask(runId, text)` | 向随行助手提问，返回 `Stream<AssistantEvent>` |
| `drafts.create(source)` | 创建世界草稿（`manual / dialogue / import`） |
| `drafts.interview(draftId, text, {skip})` | 结构化访谈一轮：抽取 / 跳过代填 / 矛盾检出 |
| `drafts.generate(draftId)` | 生成圣经 + 身份池 + 种子，跑六条一致性检查 |
| `drafts.detail(draftId)` | 草稿完整视图：字段得分、问题列表、圣经 |
| `drafts.save(draftId, patch)` | 编辑器保存（运行时字段拒改） |
| `drafts.trial(draftId, {identityId})` | 开试玩局（`is_trial=1`，不进「我的局」），返回序章与首批选项；`review`/`trial`/`frozen` 均可进入（`frozen` 试玩后状态保持不变）；重复试玩自动替换旧试玩局 |
| `drafts.discardTrial(draftId)` | 丢弃试玩局，草稿状态回 `review` |
| `drafts.freeze(draftId)` | 冻结为本地版本（`world_versions` 版本 +1） |
| `drafts.delete(draftId)` | 删除草稿、访谈记录与试玩局 |
| `imports.start(path, {fidelity})` | 导入 TXT（已拷入沙盒后调用）：解码分块 → 逐块抽取 → 归并 → 生成圣经，返回任务视图；`fidelity` 选合成档位（§4.6）；同 `content_hash` 重复导入命中已有任务（进行中自动续跑） |
| `imports.resume(jobId)` | 断点续跑：跳过 `import_chunks` 已完成块继续抽取 |
| `imports.progress(jobId)` | 任务进度视图（stage / done / total / stats） |
| `imports.listJobs({limit})` | 最近导入任务列表 |
| `imports.entities(jobId)` | 归并后的实体列表（审阅用） |
| `imports.updateEntities(jobId, {removeKeys, mergeInto})` | 实体审阅：删除 / 合并（频次、别名、属性并入目标），采纳率 = 现存 / entitiesTotal |
| `imports.regenerate(jobId, {fidelity})` | 用审阅后的实体重新生成世界（仅 draft 状态可重跑），可换合成档位 |
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
final worlds = await engine.listWorlds();
// WorldSummary(id, title, genre, summary, source, version, identityCount, updatedAt)
```

### worlds.get(worldId)

返回世界公开介绍、当前版本号、身份数量、终局数量。**不返回 NPC 私密面与事件种子细节**；这些只留在引擎内部供导演使用。

### draw(worldId)

```dart
final draw = await engine.draw('w_cangwu', count: 3);
// DrawResult(drawToken, expiresAt, identities: List<Identity>)
```

`drawToken` 是进程内一次性令牌，默认 5 分钟有效，防止 UI 跨页丢失身份来源。**不扣减任何配额**（无服务端）。

### create()

```dart
final start = await engine.create(
  worldId: 'w_cangwu',
  identityId: 'id_herb_apprentice',
  drawToken: draw.drawToken,
);
// StartResult(runId, state, prologue, choices)
```

开局序章一次性生成（非流式），保证首屏稳定。若模型未配置，返回 `MODEL_NOT_CONFIGURED`，UI 先跳设置。

### getRun(runId)

```dart
final view = await engine.getRun('r_2b9');
// RunView(head: RunHead, state, pendingChoices)
// RunHead 含 id/status/chapter/turnNo/headSnapshotId/endingId；
// listRuns() 额外解析 endingTitle（终局名，展示用）
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

事件顺序固定：`turnStart → (classification) → narrationDelta* → narrationEnd → (chapterCompleted) → choices → statePatch → turnEnd`；失败则最后是 `turnError`，不与 `turnEnd` 同时出现。`chapterCompleted(chapter, reason, summary)` 仅在卷末收卷回合出现，`summary` 为压缩生成的卷记（可能为空）。

### branch()

```dart
final branch = await engine.branch(snapshotId: 's_11');
// 返回新局 runId（String）
```

从快照开**新的一局**，旧局原样保留。新局继承当时的身份与世界版本，不继承之后的任何事件。M0 限定每局最多 3 条世界线。

### archive()

```dart
final archive = await engine.archive('r_2b9');
// Archive(endingId, title, epitaph, tags, keyChoices, turns)
// tags = [境界, 第N卷, N回合]；endingId 为空字符串时 title 兜底「仍在路上」
```

### assistant()

```dart
await for (final e in engine.assistant('r_2b9', '苏晚这个人可信吗？')) { ... }
// AssistantDelta(text) / AssistantEnd(tokensIn, tokensOut)
// 失败按 Prompt 契约返回固定文案，仍以 AssistantDelta + AssistantEnd 收尾，不新增错误事件
```

`AssistantEvent` 只有两种：`AssistantDelta(text)` 与 `AssistantEnd(tokensIn, tokensOut)`。

试玩局同样可用：`loadRunPackage` 对 `is_trial=1` 的局从其来源草稿行取圣经与身份池（`world_draft/draft_package.dart`），随行助手在试玩页与其他局行为一致；草稿被删则返回 `NOT_FOUND`。

助手不写状态、不推进回合。只读 `RunState.knowledge` 与公开世界信息，不读 NPC 私密面与未回收伏笔的隐藏内容。

### listRuns() / listNarration(runId)

```dart
final runs = await engine.listRuns();      // List<RunHead>，updatedAt 新→旧
final narration = await engine.listNarration('r_2b9'); // List<NarrationEntry>
// NarrationEntry(turnNo, text, isMarker, summary)
// 卷末收卷以 isMarker=true 条目出现：text='第 N 卷 · 完'，summary=卷记小结
// 已落幕局也走本接口重读正文；档案页另有 archive()
```

### drafts.*()（M1 世界工坊，已实现）

```dart
final view = await engine.drafts.create(DraftSource.dialogue);
final turn = await engine.drafts.interview(view.id, '末法时代，灵气枯竭', skip: false);
// InterviewTurnResult：下一问、字段得分、矛盾反问（代填字段标 filledByAI）
final done = await engine.drafts.generate(view.id);   // 完整度 ≥70 才可生成
final detail = await engine.drafts.detail(view.id);   // DraftDetail：字段得分 + 问题列表 + 圣经
await engine.drafts.save(view.id, bible: ..., title: '末法残卷');
final start = await engine.drafts.trial(view.id);     // StartResult：试玩局（is_trial=1）
await engine.drafts.discardTrial(view.id);            // 状态回 review，试玩局与事件删除
final r = await engine.drafts.freeze(view.id);        // FreezeResult(worldId, version)
```

- `DraftView(id, source, status, title, step, completeness, fields, qualityScore, issues, exportable, worldId, updatedAt)`；`issues` 元素为 `{level, code, field, message}`，`error` 级问题同时阻塞客户端的试玩与冻结按钮
- `trial` 返回的局不进 `runs.list()`；序章事件与正式局同构（`narration` + `choice`）
- `freeze` 幂等规则：内容 checksum 未变时抛 `WORLD_FROZEN`；已冻结草稿继续修改可再冻结出 v2、v3…

### imports.*()（M2 小说导入，已实现）

```dart
final job = await engine.imports.start(
    path, fidelity: ImportFidelity.standard); // TXT 已由客户端经 SAF 拷入沙盒私有目录
// ImportJobView(id, stage, error, draftId, stats{chunks,chapters}, done, total,
//               entitiesTotal, fidelity)   // 档位见[世界创造与导入](./世界创造与导入.md) §4.6
final cur = await engine.imports.progress(job.id);
final list = await engine.imports.entities(job.id);      // List<ImportEntity>
await engine.imports.updateEntities(job.id,
    removeKeys: ['路人甲'], mergeInto: {'九爷': '沈青'});   // 删除 / 合并别名
final again = await engine.imports.regenerate(job.id,
    fidelity: ImportFidelity.faithful);                  // 生成失败回滚后重跑，可换档
await engine.imports.resume(job.id);                     // 杀进程后断点续跑（沿用原档位）
```

- 阶段机：`queued → parsing → extracting → merging →（忠实档 compressing）→ review`；任一块抽取终失败 → `failed`（已完成块保留在 `import_chunks`，`resume` 从断点继续）
- 合成档位（`ImportFidelity.fast/standard/faithful`，默认 fast 兼容旧行为）：`start` 时选择；忠实档在合成前把全书分块摘要压缩为卷级脉络（`compressing` 阶段），压缩失败自动降级标准采样、任务不失败
- `start()` 去重：同 `content_hash` 已有任务时，进行中（queued/extracting/merging/compressing）自动转 `resume`，终态直接返回原任务视图
- 覆盖率闸门（§4.4）：覆盖率 < 0.8 时在草稿 `quality.issues` 追加 `IMPORT_COVERAGE_LOW`（error 级，阻塞试玩不阻塞冻结重跑）；在导入向导展示并可 `regenerate` 重跑
- 实体审阅边界：`updateEntities` 仅 `stage == 'review'` 可用（否则 `STATE_INVALID`）；`regenerate` 仅草稿 `status == 'draft'`（即上次生成失败回滚后）可调用，已进入审阅的世界请在编辑器修改
- 采纳率 = 审阅后现存实体数 / `entitiesTotal`（归并基准，客户端向导展示）
- `source=import` 的草稿与冻结世界 `exportable=false`（数据层固化，见[世界创造与导入](./世界创造与导入.md) §4.7）；导入原文只存沙盒 `files/imports/`，不进任何导出路径

### library.export() / library.import()（未实现，M3）

> 规划接口，当前引擎与客户端均未提供。目标语义：导出前置检查 `worlds.exportable = 1`，否则 `EXPORT_FORBIDDEN`；包格式与校验规则见[世界分享与本地世界库](./世界分享与UGC.md) §4。实现排期见 TODO 的 M1/M2 条目。

### usage.summary()

```dart
final s = await engine.usageSummary(from: ..., to: ...);
// Map：{turns, tokensIn, tokensOut, failures, byRole: {role: [req, tokensIn, tokensOut]}}
// 花费估算与 p50/p95 延迟见 usageStats()（设置页用量统计）
```

### settings.testConnection()

```dart
final report = await engine.testConnection();
```

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
| 首字超时 | 60 s（原 30 s；M0 实测部分供应商首字延迟可达 40 s+，放宽并保留重试） |
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
| 2026-10-24 | v0.4：M1 世界工坊接口——§2/§3 新增 `drafts.*()`（create/interview/generate/detail/save/trial/discardTrial/freeze/delete），`DraftView` 与质量门语义；`runs.list()` 标注不含试玩局；`WORLD_FROZEN` 对齐实现（重复冻结同码） |
| 2026-10-25 | v0.5：M2 小说导入接口——§2/§3 新增 `imports.*()`（start/resume/progress/listJobs/entities/updateEntities/regenerate），ImportJobView 阶段机、start 去重续跑、覆盖率闸门与实体审阅边界；`IMPORT_INVALID`/`IMPORT_TOO_LARGE` 错误码含义扩展到 TXT 导入；library.export/import 标注 M3 |
| 2026-10-26 | v0.6：合成档位——`imports.start(path, {fidelity})` / `imports.regenerate(jobId, {fidelity})` 带 `ImportFidelity`（fast/standard/faithful，默认 fast）；阶段机加忠实档 `compressing`（压缩失败自动降级标准采样）；start 去重进行中集合加 compressing；ImportJobView 增 `fidelity` 字段 |
