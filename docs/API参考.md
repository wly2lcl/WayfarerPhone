# API 参考 · 本地引擎与模型网关

> 版本：v1.3（单机离线）
> 最后更新：2026-10-29
> 上游：[技术方案](./技术方案.md) ｜ 相关：[Prompt 契约](./Prompt契约.md)
>
> v1.3 变更：`turns.run` 新增**中止语义**（停止生成，B6）——订阅 cancel 即向引擎传播中止，引擎在关键检查点（含 `commitTurn` 前最后防线）静默终止本回合；中止回合不落库、`turnNo` 不变、同一 `expectedTurn` 可重提，已发出请求的用量行保留（详见 §turns.run）。
>
> v1.2 变更：数据卫生与重试修复——`runs.delete` 级联清理扩至 `usage_log` 与 `events_fts`（原只删局行，孤儿数据只增不减）；`library.delete` 同口径补 `usage_log`；新增 `settings.purgeExpiredUsageLog()`（90 天滚动，`Engine.open()` 自动执行）；`usageSummary` 试玩排除下推 SQL；`listRuns` 终局标题仅解析已落幕局涉及的世界版本（消除全表解码 bible 的 N+1）；网关重试计时按单次尝试重置（修复第二次尝试被累计耗时误判首字超时），429 `Retry-After` 真正用于退避。
>
> v0.7 变更：M3 分享闭环落地——§3 `library.*()`（export/import/rename/delete/space）与 `runs.exportPack/importPack` 由「未实现」改为已实现语义：可导出性门禁（builtin/imported 世界 `exportable=0` → `EXPORT_FORBIDDEN`，试玩局不可导出）、`WorldSummary`/`RunHead` 增 `exportable`（客户端据此隐藏导出入口）、`formatVersion` 兼容检查、runId 冲突自动改后缀、导入五分支。
>
> v0.8 变更：builtin 世界存档 `.run` 导出豁免定案——`runs.exportPack` 门禁改为「绑定世界非 `import` 来源即可导出」（builtin 豁免、`import` 仍拒），`RunHead.exportable` 语义改为「该局 `.run` 存档包可导出」；`library.export`（`.world`）门禁不变。
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
| `CONTENT_BLOCKED` | 输入或生成命中本地规则；触发点：自由输入、访谈问答、导入文件名（本地拦截，不发起模型请求）；生成层命中时流中断走兜底，不落库 | 引导换一种表达 |
| `STATE_INVALID` | 状态校验不可恢复 | 上报日志，允许回滚快照 |
| `STORAGE_FULL` | 本地磁盘不足 | 提示清理旧局或导出 |
| `IMPORT_INVALID` | `.world` / `.run` 包结构、校验和或格式版本不通过；TXT 导入中文件不存在 / 编码无法识别 / 内容与任务记录不一致 | 展示具体原因 |
| `IMPORT_TOO_LARGE` | 超过 20 MB 或解压后超限（TXT 导入与包导入同一上限） | 拒绝 |
| `EXPORT_FORBIDDEN` | `.world`：该世界 `exportable = 0`；`.run`：所属世界为 `import` 来源（builtin 存档豁免开放） | 说明为导入来源，`.world` 不可导出 |
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
| `runs.delete(runId)` | 删除一局并**级联清理全部从属数据**：快照、事件、用量行、检索索引（2026-10-29 起，原只删局行致孤儿数据残留）；「我的局」卡片删除按钮触发，二次确认 |
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
| `library.import(File)` | 导入 `.world` 包（五分支冲突处理，见 §3） |
| `library.export(worldId)` | 导出 `.world` 包到 `files/exports/` 并返回路径；`exportable = 0` 抛 `EXPORT_FORBIDDEN` |
| `library.rename(worldId, title)` | 重命名本地世界 |
| `library.delete(worldId)` | 删除世界、版本与原件 |
| `library.space()` | 各世界占用（`files/worlds/<id>/` 导入原件）+ 导入原文缓存字节 |
| `usage.summary({from, to})` | 本地用量与成本估算 |
| `settings.testConnection()` | 用最小请求验证 baseUrl + Key + 模型名 |
| `settings.readAppSetting(key)` | 读功能开关（`AppFlags.ageGate` / `AppFlags.teenMode`） |
| `settings.writeAppSetting(key, value)` | 写功能开关 |
| `settings.isTeenMode()` | 青少年模式是否开启（读 `teen_mode == '1'`） |
| `settings.setTeenMode(on)` | 开/关青少年模式（写 `teen_mode`） |
| `settings.exportDiagnostics({outPath})` | 导出脱敏诊断 JSON 到 `files/diagnostics/`（默认，自动保留最近 5 份）或指定路径，返回文件路径（2026-10-29 新增） |
| `settings.clearDiagnostics({keep})` | 清除已生成的诊断文件，保留最近 `keep` 份（默认 0 = 全清），返回删除数（2026-10-29 新增） |
| `settings.purgeExpiredLocalEvents()` | 删除 7 天前的 `local_events` 行并返回删除数；`Engine.open()` 时自动执行（2026-10-29 新增） |
| `settings.purgeExpiredUsageLog({keepDays})` | 删除 `keepDays`（默认 90）天前的 `usage_log` 行并返回删除数；`Engine.open()` 时自动按 90 天滚动，设置页统计窗口为近 30 天不受影响（2026-10-29 新增） |

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
// WorldSummary(id, title, genre, summary, source, version, identityCount, updatedAt, exportable)
// exportable：builtin/imported 为 false（不可导出），created/shared 为 true；客户端据此隐藏导出入口
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
// RunHead 含 id/status/chapter/turnNo/headSnapshotId/endingId/exportable；
// exportable 取所属世界 worlds.exportable（缺失按 true），客户端据此隐藏 `.run` 导出按钮；
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

**中止（停止生成）**：订阅方 `cancel()` 订阅即向引擎传播中止信号——引擎在关键检查点（分类前、导演前、旁白 delta 循环内、提取前、**`commitTurn` 之前**（最后防线）、随行问答 delta 循环内）检测并抛内部中止信号，静默终止本回合（不外发 `TurnError`）。中止语义：**本回合不落库**（`turnNo` 不变、无状态补丁、无快照），同一 `expectedTurn` 可直接重新提交（不报 `TURN_CONFLICT`）；**已发出的模型请求不追回**（`usage_log` 用量行保留，属已知取舍）。UI 侧「停止生成」按钮（B6）在 `submitting/streaming` 阶段显示，点击即 `cancel()` 订阅：已流出的半截正文保留（补完整标记），纯空占位连同其回合标题一并丢弃，上一回合的待选选项恢复。

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

### library.*() / runs.exportPack() / runs.importPack()（M3 分享闭环，已实现）

```dart
final out = await engine.library.export('w_e811');
// ExportedFile(path, fileName, bytes)；写入 files/exports/wayfarer-world-<id>-v<N>.world
final r = await engine.library.import(file.path);
// WorldImportResult(worldId, version, title, action)
// action 五分支：created / version_added / saved_as_new / skipped / overwritten
await engine.library.rename('w_e811', '末法残卷新名');
await engine.library.delete('w_e811');                    // 级联删版本、种子与导入原件
final report = await engine.library.space();              // SpaceReport(worlds[], importsBytes)
final pack = await engine.exportRunPack('r_e811');        // .run 存档包导出
final imp = await engine.importRunPack(path);             // RunImportResult(runId, renamed)
```

- **可导出性门禁**：`library.export`（`.world`）校验 `worlds.exportable`，`exportable = 0`（builtin 内置 / imported 小说导入世界）抛 `EXPORT_FORBIDDEN`。`runs.exportPack`（`.run`）口径独立：绑定世界为 `import` 来源时 `EXPORT_FORBIDDEN`，**builtin 世界存档豁免开放**（2026-10-28 定案，接收方装 App 自带该世界版本；世界分享与UGC §3.1）。试玩局（`is_trial = 1`）导出存档包抛 `STATE_INVALID`（「试玩局不可导出」）
- **导出入口**：客户端据 `WorldSummary.exportable` 隐藏 `.world` 导出菜单；`RunHead.exportable` 语义为「该局 `.run` 存档包可导出」（按世界来源非 `import` 计算），「我的局」据此显示/隐藏导出按钮；导出文件经系统分享面板发出
- **导入校验**（`WorldPackage.unpack` / `RunPackage.unpack`）：20 MB 上限（`IMPORT_TOO_LARGE`）、zip 解析失败与缺文件（`IMPORT_INVALID` 具体到字段）、`formatVersion` 高于/低于本机支持值均拒绝、`manifest.aiGenerated != true` 拒绝（AI 生成标识不可关闭）、checksum 不匹配拒绝（`CHECKSUM_MISMATCH`，篡改任意字节后导入被拒）
- **世界导入冲突处理**（世界分享与UGC §6）：同 worldId 同版本 checksum 相同 → `skipped`；同版本 checksum 不同 → 默认 `skipped`，`overwrite: true` 时 `overwritten`（删除旧版本行后重插）；更高版本 → `version_added`（追加并推进 latestVersion）；更低版本 → `saved_as_new`（新 worldId 另存，不降级已有版本）；无同名世界 → `created`。标题与已有世界同名时追加「（导入 N）」去重（`_dedupeTitle`）
- **存档包导入**：缺对应 `worldId + worldVersion` 时 `NOT_FOUND` 拒收，不留半成品；runId 冲突自动改后缀（`r_e811` → `r_e811_2`，`renamed = true`）；导入后从原 `turnNo` 与最新快照续玩
- **删除**：`library.delete` 级联删除版本、全部存档（局/快照/事件/检索索引/用量行）与导入原件，返回删除的局数；UI 在有存档时二次确认并说明影响（世界分享与UGC §8）。单局删除走 `runs.delete`（同口径级联，含 `usage_log`）
- **来源与再导出**：导入的 `.world` 落 `source = 'shared'` 且 `exportable = 1`，再导出时 `manifest.origin = 'shared'`、`sourceWorldId` 保留原 worldId、NOTICE.txt 保留原作者声明（世界分享与UGC §7）；导入原件存私有 `files/worlds/<worldId>/v<N>.world`（仅占用统计，不进导出路径）

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

### feedback（反馈与举报，2026-10-29 新增）

```dart
await engine.submitFeedback(runId: ..., category: '反馈', detail: '...'); // 写入 feedback_records，返回 void
final list = await engine.listFeedback(limit: 50);                        // List<FeedbackRecord>，按 createdAt 倒序
```

- 只落本机 `feedback_records` 表（runId 可空），**不联网上报**；合规与内容安全 §3.3。
- UI 入口在设置页「反馈与举报」，提交成功提示「仅保存在本机，可随诊断包发出」。

### settings.*（功能开关与诊断包，2026-10-29 新增）

```dart
final teen = await engine.isTeenMode();                    // bool，读 app_settings.teen_mode == '1'
await engine.setTeenMode(true);                            // 写 teen_mode（App 内经设置页开关调用）
final v = await engine.readAppSetting(AppFlags.ageGate);   // String?，'adult' | 'teen' | null（未确认）
await engine.writeAppSetting(AppFlags.teenMode, '1');      // 通用开关写入
final path = await engine.exportDiagnostics();             // → files/diagnostics/wf_diagnostics_<ts>.json
final path = await engine.exportDiagnostics(outPath: ...); // 或指定输出路径
```

- 功能开关经 `AppFlags`（`AppFlags.ageGate = 'age_gate'`、`AppFlags.teenMode = 'teen_mode'`）落 `app_settings` 表；首启年龄门选择「未满 18 周岁」时 App 层自动 `setTeenMode(true)`。
- **青少年模式护栏**（引擎层，全部在访问文件/网络之前抛 `STATE_INVALID`）：`turns.run` 拒绝 `FreeTextInput`（仅选项可推进，不发起模型请求）；`assistant` 随行问答拒绝自由提问（2026-10-29 起，与自由输入同口径）；`library.export / import / runs.exportPack / runs.importPack` 与 `imports.start` 拒绝调用。UI 侧同步隐藏对应入口（工坊 TXT、管理页导入、我的局导入/导出、世界详情导出、人生卡片、游玩页随行助手图标）。
- **诊断包**（`exportDiagnostics`）脱敏清单——**不含**：模型 Key、`run_events` 叙事正文、快照、圣经、导入原文；**包含**：`kind/version/generatedAt/schemaVersion`、设置项（不含 Key 字段）、功能开关、9 张业务表行数计数、近 30 天用量聚合（请求数/失败/p50/p95/token/回合）、反馈记录 ≤200 条、近 7 天本地事件 ≤200 条（仅类型与回合号）。UI 入口在设置页「诊断」节「导出诊断数据」。

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
| 429 | 读 `Retry-After` 并真正用于退避（0 表示立即重试，最多等 30 s；2026-10-29 起原实现固定 1s/3s 未消费该头），重试 1 次 |
| 4xx（401/403/400） | 不重试，直接映射错误码 |

重试计时按「单次尝试」重置（2026-10-29 修复：原计时器跨重试累计，第二次尝试即使首字秒回也会被累计耗时误判「首字超时」）。

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
| 2026-10-29 | v1.3：`turns.run` 中止语义（停止生成，B6）——订阅 cancel 向引擎传播中止（分类/导演/旁白 delta/提取/commitTurn 前/随行问答 delta 六个检查点，`_TurnAborted` 静默终止不外发 `TurnError`）；中止回合不落库、`turnNo` 不变、同一 `expectedTurn` 可重提；UI「停止生成」按钮（submitting/streaming 显示，半截正文保留、空占位连同回合标题丢弃、恢复待选选项） |
| 2026-10-29 | v1.2：数据卫生与重试修复——`runs.delete` 级联清理扩至 `usage_log`/`events_fts`，`library.delete` 同口径补 `usage_log`；门面清单新增 `settings.purgeExpiredUsageLog`（90 天滚动）；`listRuns` 终局标题仅解析落幕局涉及版本（消除 N+1）；§5.3 重试计时按单次尝试重置、429 `Retry-After` 用于退避；「我的局」新增单局删除按钮（二次确认） |
| 2026-10-29 | v1.1：AI 标识收口与诊断/护栏补强——门面清单新增 `settings.clearDiagnostics` / `settings.purgeExpiredLocalEvents`，`exportDiagnostics` 注明自动保留最近 5 份；青少年模式护栏补第④项（`assistant` 自由问答拒绝）；游玩页页脚 AI 生成角标（WF-LAUNCH-03 四处齐备） |
| 2026-10-29 | v1.0：诊断包与未成年人保护——门面清单与新增 §3 节：`settings.readAppSetting/writeAppSetting/isTeenMode/setTeenMode/exportDiagnostics`、`AppFlags` 开关键、青少年模式护栏清单（turns.run 自由输入 / library 四入口 / imports.start 抛 `STATE_INVALID`）、诊断包脱敏清单 |
| 2026-10-29 | v0.9：内容安全与反馈——新增 `feedback` 节（`Engine.submitFeedback` / `listFeedback`，落本机 `feedback_records` 表不联网）；`CONTENT_BLOCKED` 错误码补触发点（自由输入/访谈/导入文件名本地拦截、生成层流中断兜底不落库） |
| 2026-10-23 | v0.1：HTTP 端点、SSE、错误码、配额 |
| 2026-10-23 | v0.2：改为本地引擎门面 + 模型网关契约；删除账号、配额、409、幂等键与服务端错误码 |
| 2026-10-23 | v0.3：新增三种模型协议适配、供应商预设、`.run` 存档包导入导出 |
| 2026-10-24 | v0.4：M1 世界工坊接口——§2/§3 新增 `drafts.*()`（create/interview/generate/detail/save/trial/discardTrial/freeze/delete），`DraftView` 与质量门语义；`runs.list()` 标注不含试玩局；`WORLD_FROZEN` 对齐实现（重复冻结同码） |
| 2026-10-27 | v0.7：M3 分享闭环——§3 `library.*()`（export/import/rename/delete/space）与 `runs.exportPack/importPack` 已实现语义：exportable 门禁（builtin/imported 世界 `EXPORT_FORBIDDEN`、试玩局 `STATE_INVALID`）、`WorldSummary`/`RunHead` 增 `exportable`、`formatVersion`/`aiGenerated`/checksum 导入校验、世界导入五分支与 `.run` runId 冲突改后缀；`runs.exportPack/importPack` 门面方法为 `Engine.exportRunPack/importRunPack` |
| 2026-10-28 | v0.8：builtin 世界存档 `.run` 导出豁免定案——`runs.exportPack` 门禁改为「绑定世界非 `import` 来源即可导出」（builtin 豁免、`import` 仍 `EXPORT_FORBIDDEN`），`RunHead.exportable` 语义改为「该局 `.run` 存档包可导出」（`listRuns` 按世界来源计算）；`library.export`（`.world`）门禁不变；`EXPORT_FORBIDDEN` 错误码说明分流 `.world`/`.run` 两个口径 |
| 2026-10-25 | v0.5：M2 小说导入接口——§2/§3 新增 `imports.*()`（start/resume/progress/listJobs/entities/updateEntities/regenerate），ImportJobView 阶段机、start 去重续跑、覆盖率闸门与实体审阅边界；`IMPORT_INVALID`/`IMPORT_TOO_LARGE` 错误码含义扩展到 TXT 导入；library.export/import 标注 M3 |
| 2026-10-26 | v0.6：合成档位——`imports.start(path, {fidelity})` / `imports.regenerate(jobId, {fidelity})` 带 `ImportFidelity`（fast/standard/faithful，默认 fast）；阶段机加忠实档 `compressing`（压缩失败自动降级标准采样）；start 去重进行中集合加 compressing；ImportJobView 增 `fidelity` 字段 |
