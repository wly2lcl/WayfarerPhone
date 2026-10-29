# 世界分享与本地世界库

> 版本：v0.4（单机离线）
> 最后更新：2026-10-27
> 阶段：M3
> 上游：[世界创造与导入](./世界创造与导入.md) ｜ 相关：[合规与内容安全](./合规与内容安全.md)

分享只在设备之间发生，通过本地 `.world` 文件完成。原则只有一句：**原创可导出，导入只自用，导出即冻结。**

原 v0.1 中的 UGC 社区能力（公开可见性、社区列表、热度排序、举报入口、审核队列、运营后台、fork 谱系）**不在产品范围内**：没有自建服务端，就没有承载这些能力的载体，也没有可执行的内容审核主体。

---

## 1. 分享形态

| 形态 | 面向 | 说明 |
| --- | --- | --- |
| `.world` 包导出 | 任意 | 经系统分享面板（`share_plus`）发给他人，无公开入口、无链接 |
| `.world` 包导入 | 任意 | 从文件 App / 文件选择器导入，校验后写入本地世界库 |
| 人生卡片 | 熟人 | 只读卡片（世界名、结局标题、3 个关键选择、游玩时长），不含世界定义 |

没有社区列表、热门排序、公开链接与二维码；不提供 fork 谱系，用户可复制一个世界另存为新世界，两者之间不做关联追踪。

**人生卡片是另一条链路**：不含世界定义，不能被编辑，也不能作为世界导入。v0.4 实现为**纯文本**经系统分享面板发出（M3 任务允许「只读图片或纯文本」二选一），带「AI 生成」角标；图片形态留作后续增强。

---

## 2. 世界来源与可导出性

| 来源 | 可玩 | 可编辑 | 可导出 `.world` |
| --- | --- | --- | --- |
| builtin（随 App 分发） | 是 | 否 | 否 |
| created（对话共创 / 手动） | 是 | 是 | 是 |
| imported（小说 TXT 导入） | 是 | 是（仅本地） | 否（`exportable = 0`） |
| shared（导入的 `.world`） | 是 | 是（本地副本） | 是，须保留原 `NOTICE.txt` 与来源声明 |

「可编辑」指**冻结前**的草稿阶段；一旦冻结为 `world_versions` 的一条版本，任何来源都不可原地修改，只能「另存为新草稿 → 修改 → 冻结新版本」。已开局的老局仍绑定旧版本。

硬规则（全部在本地判定，不依赖服务端）：

1. `worlds.source = 'imported'` 的世界 `exportable` 恒为 0，App 内不存在导出入口
2. 导出即冻结：只能导出 `world_versions` 中的冻结版本，改内容必须冻结新版本
3. 已开局的老存档继续读自己绑定的 `world_version`，不随版本升级迁移
4. 单设备单写入者；同一 run 的回合由进程内串行队列保证串行，不存在跨设备并发与 HTTP 409

---

## 3. 世界包格式

```
wayfarer-world-<worldId>-v<version>.world   （zip）
├─ manifest.json        格式版本、校验和、许可证、来源、AI 标识
├─ bible.json           WorldBible
├─ identities.json      身份池
├─ seeds.json           事件种子
├─ NOTICE.txt           署名与来源声明
└─ checksum              bible / identities / seeds 的 SHA-256 文本
```

```ts
// 字段定义以 [数据契约](./数据契约.md) §10 为准
type WorldPackageManifest = {
  formatVersion: 1;
  worldId: string;
  version: number;
  checksum: string;                 // 与 checksum 文件同值，对规范化 JSON 的 SHA-256
  license: 'cc-by' | 'cc-by-nc' | 'all-rights-reserved';
  origin: 'original' | 'shared';    // shared = 导入他人包后再导出
  sourceWorldId?: string;           // 再导出时保留原始 worldId，仅作来源声明
  aiGenerated: true;                // 固定标识，不可由导出者关闭
  author: { name: string };         // 本地署名，可留空
  createdAt: number;
};
```

- 校验和覆盖 `bible / identities / seeds`，导入时先校验再写库
- 包内**不含**导入原文，也不含小说导入来源的世界（此类世界无法导出）
- 包内不含封面，导入后按题材使用 App 内置封面
- 许可证在冻结时选定；再导出必须继承原许可证或选择更严格的一种

---

## 3.1 存档包 `.run`（独立格式）

存档不塞进 `.world`：世界是「可复用的定义」，存档是「某个人的一段人生」，两者生命周期与隐私等级不同。

```
wayfarer-run-<runId>-t<turnNo>.run   （zip）
├─ manifest.json       格式版本、校验和、绑定世界、进度、隐私声明
├─ run.json            局头：身份、状态、章节、回合
├─ snapshots.jsonl     快照（含卷末 memory），一行一条
├─ events.jsonl        只追加事件流，seq 连续
└─ checksum            run / snapshots / events 的 SHA-256 文本
```

```ts
type RunPackageManifest = {
  formatVersion: 1;
  runId: string;
  worldId: string;                  // 必须与 run.json 一致
  worldVersion: number;             // 绑定版本，导入时不升级
  identityId: string;
  turnNo: number;
  chapter: number;
  status: 'active' | 'ended';
  endingId?: string;
  checksum: string;
  aiGenerated: true;
  createdAt: number;
};
```

硬规则：

- 导入前先校验 `checksum`，再校验本机是否存在 `worldId + worldVersion`；缺世界时拒绝导入，提示先导入对应 `.world`，**不允许自动升级到新版本**。
- 导入落地为新 `runId`，与本地已有局并列；`runId` 冲突时自动改后缀，不覆盖。
- `.run` 不含模型 Key、不含导入原文、不含 `usage_log` 明细。
- `.run` 可导出口径**独立于 `.world`**（2026-10-28 定案，README「已定决策」）：绑定世界非 `import` 来源即可导出。builtin 世界 `.world` 不可导出（随 App 分发无再分享意义），但其存档豁免开放——接收方装 App 自带该世界版本，`.run` 迁移即跨设备续玩；`import`（小说导入）世界的存档仍不可导出（版权硬约束，原文不出现在任何导出路径）。
- 导入后 `runs.status` 保持原值；已结束的局只可查看人生档案。

---

## 4. 数据表补充

M3 不新增表；包格式与校验规则见 §3。世界包的信息复用 `worlds` 与 `world_versions`（见[技术方案](./技术方案.md) §3）：

- `world_versions.checksum`：导入时与重算值比对
- `worlds.source`：`builtin | created | imported | shared`
- `worlds.exportable`：导入来源为 0，App 内禁止导出

包与导出文件都落在 App 沙盒，不另记库表：

```
files/worlds/<worldId>/v<version>.world    导入的原件（私有）
files/exports/wayfarer-world-<worldId>-v<version>.world   导出后交给系统分享
```

导入成功时 `worlds` 与 `world_versions` 在同一事务内写入；任何一步失败都整体回滚，不留半成品。删除世界级联删除 `world_versions` 与 `files/worlds/<worldId>/`。

---

## 5. 冻结与导出流程

```
草稿 review 通过
  → 本地检查清单
  → 生成 world_version（冻结）+ checksum
  → 进入「我的世界」
  → 用户主动导出 .world → share_plus 系统分享面板
```

检查清单：

1. 一致性评分 ≥ 70
2. 至少 1 条可触发终局
3. 身份池 ≥ 5
4. 许可证已选
5. 原创声明已勾选；导入来源不进入导出流程
6. 导出时本地生成 `NOTICE.txt` 与 `checksum`
7. `manifest.aiGenerated` 固定为 true，不可关闭

冻结不触发任何网络请求；导入来源可以冻结用于本地游玩，但始终保持不可导出。

---

## 6. 导入校验与冲突处理

| 场景 | 处理 |
| --- | --- |
| `formatVersion` 高于本机支持 | 拒绝导入，提示升级 App |
| `checksum` 与重算值不一致 | 拒绝导入，不写入任何数据 |
| 缺少 `bible / identities / seeds / manifest / NOTICE.txt` | 拒绝导入，列出缺失项 |
| 必填字段缺失或 JSON 无法解析 | 拒绝导入，展示字段错误 |
| `aiGenerated` 缺失或非 true | 拒绝导入 |
| 包内含导入原文条目 | 忽略该条目，不写入 |
| 同名世界（不同 `worldId`） | 两者都保留，新导入标题追加「（导入 2）」 |
| 同 `worldId` 同版本 | 默认跳过，可手动选择覆盖 |
| 同 `worldId` 更高版本 | 作为新版本写入，旧存档不动 |
| 同 `worldId` 更低版本 | 允许导入但另存，不降级已有版本 |

运行时内容不做服务端审核，由本地词表与系统提示词约束，见[合规与内容安全](./合规与内容安全.md)。

---

## 7. 版权与署名

- 原创世界：作者保留权利；导出后由接收方自行使用，App 不介入授权
- 再导出：必须原样保留 `NOTICE.txt` 与来源声明，许可证不得放宽
- 导入来源（小说 TXT）：永不导出，原文不入包
- 无社区、无公开分发、无举报入口：版权责任由导出者与接收者自行承担，导入向导中确认后继续
- `.world` 内的 `NOTICE.txt` 固定写入来源与许可证；离线包一旦导出，App 无法回收或修改
- 本机没有「下架」动作；发现问题的处理方式是删除本地世界

---

## 8. 本地世界库管理

| 操作 | 入口 | 行为 |
| --- | --- | --- |
| 导入 | 我的世界 → 导入；或文件 App 打开 `.world` | 校验后写入本地，规则见 §6 |
| 导出 | 世界详情 → 导出 | 仅 `exportable = 1`；打包到 `files/exports/` 后调起系统分享面板 |
| 删除 | 世界详情 / 长按 | 二次确认；存在存档时提示一并删除 |
| 重命名 | 世界详情 | 只改 `worlds.title`，不改 manifest 与 checksum |
| 占用空间 | 我的世界 → 管理 | 统计 `files/worlds/` 与 `files/imports/`，按世界列出大小 |

跨设备迁移：

- 世界：导出 `.world` 再在另一台导入，不含存档
- 存档：不随 `.world` 包迁移；人生卡片只是只读展示，不能续玩
- 完整备份：依赖系统备份（iOS 备份 / Android `allowBackup`），不提供自建云同步

---

## 9. 本机引擎动作（M3，已实现）

以下均为进程内 Dart 调用，不是 HTTP 端点（详细语义见[API 参考](./API参考.md) §3）。

| 调用 | 说明 |
| --- | --- |
| `worlds.list()` | 本地世界库列表；`WorldSummary.exportable` 随来源给出（builtin/imported 为 false） |
| `library.import(file, {overwrite})` | 选文件并校验导入，返回 `worldId / version / title / action`（§6 五分支）；`overwrite` 仅控制同版本不同内容的覆盖 |
| `library.export(worldId)` | 冻结版本打包到 `files/exports/` 并调起系统分享面板；`exportable = 0` 抛 `EXPORT_FORBIDDEN` |
| `library.rename(worldId, title)` | 重命名（只改 `worlds.title`） |
| `library.delete(worldId)` | 级联删除版本、全部存档与导入原件，返回删除局数 |
| `library.space()` | 按世界统计 `files/worlds/<id>/` 占用 + `files/imports/` 导入原文缓存 |
| `runs.exportPack(runId)` | 导出 `.run` 存档包到 `files/exports/` 并调起分享面板；试玩局拒绝、绑定世界为 `import` 来源时 `EXPORT_FORBIDDEN`（builtin 存档豁免开放，§3.1） |
| `runs.importPack(file)` | 校验并导入 `.run`，落地为本机新局；runId 冲突自动改后缀（`r_xxx_2`） |
| `WorldDraftService.freeze(draftId)` | 冻结为本地版本，见[世界创造与导入](./世界创造与导入.md) §6 |

幂等由本地事务 + UI 状态机拦截重复提交实现；单设备单写入者，同源同名操作不会产生并发冲突。

本地异常枚举（与[API 参考](./API参考.md) §1 同名同义）：

| code | 含义 |
| --- | --- |
| `IMPORT_INVALID` | 包格式版本不兼容、校验和不匹配、缺文件或 AI 标识缺失 |
| `IMPORT_TOO_LARGE` | 超过 20 MB 或解压后超限 |
| `EXPORT_FORBIDDEN` | `.world`：该世界 `exportable = 0`；`.run`：所属世界为 `import` 来源（builtin 存档已豁免） |
| `WORLD_FROZEN` | 已冻结版本不可修改 |
| `NOT_FOUND` | `.run` 绑定的 `worldId + worldVersion` 在本机不存在 |

---

## 10. 验收标准

1. 导入来源的世界在所有本地入口都没有导出按钮，`exportable` 恒为 0
2. 冻结后修改内容会生成新版本，老存档不受影响
3. 格式版本、校验和、必填字段、AI 标识任一不满足时拒绝导入，且不留下半成品
4. 同名与同 id 的世界按 §6 处理，不覆盖已有存档
5. 导出的 `.world` 可被另一台设备导入并试玩，`NOTICE.txt` 与来源声明完整
6. 飞行模式下可完成导入、导出、删除与游玩，除模型请求外无网络依赖
7. `.run` 存档包可在另一台设备导入并续玩；缺对应世界版本时拒绝导入且不留下半成品

> **复核注记（2026-10-27，M3 验收执行情况）**：条 1–4 已单测 + 真机验证通过。条 5/7 的「另一台设备」受验证环境限制（BlueStacks 无接收分享的应用）以**同机回环**替代（导出 → adb pull → 重导 → 试玩/续玩，NOTICE 与 checksum 经 python 校验完整），上真手机后需补 A→B 实测。条 6 已于 2026-10-29 以**端点不可达等价法**验证（BlueStacks eth0 不可断网，设置页 baseUrl 指向不可达地址并保存、重启后推回合：`MODEL_NETWORK·网络中断` 红条 + 重试按钮，应用不崩溃、失败计入用量；导入/导出/删除/游玩读取同批走查均本地完成；M0 另已验证飞行模式读档；真机字面飞行模式走查仍按手工回归清单执行）。builtin 世界存档 `.run` 导出豁免已于 2026-10-28 定案并落地（§3.1，单测 + 真机验证），原「是否开放豁免」待决策项移入 README「已定决策」。

---

## 变更记录

| 日期 | 版本 | 变更 |
| --- | --- | --- |
| 2026-10-29 | v0.6 | §10 条 6（飞行模式）以端点不可达等价法清零——复核注记更新（`MODEL_NETWORK·网络中断` 红条 + 重试、本地链路走查齐备；真机字面飞行模式走查留手工回归清单） |
| 2026-10-28 | v0.5 | **builtin 世界存档 `.run` 导出豁免定案落地**：§3.1 硬规则改为「`.run` 可导出口径独立于 `.world`——绑定世界非 `import` 来源即可导出」，builtin 存档开放（接收方自带该世界）、`import` 存档仍禁止；§9 `runs.exportPack` 门禁与 `EXPORT_FORBIDDEN` 错误码说明同步；§10 复核注记收口。README「尚未决定」移入「已定决策」 |
| 2026-10-27 | v0.4 | M3 分享闭环落地并真机验证：§9 引擎动作全部实现（`library.space()` 补入表格）；人生卡片实现为纯文本（§1 更新，M3 任务允许图片或纯文本二选一）；实现决策注记——①zip 条目采用 store（不压缩）模式规避 archive 3.6.1 与 python zipfile 的 CRC 兼容问题并加标准 zip 回归单测；②builtin 内置世界 `exportable` 修正为 0（§2 口径「builtin 不可导出」，含存量库幂等修正），`.run` 导出联动拒绝（§4）；③再导出 shared 包保留原 NOTICE 与 `sourceWorldId`、`origin='shared'` 真机验证通过 |
| 2026-10-23 | v0.2 | 由云架构改为单机离线，去掉账号/服务端/社区/审核后台 |
| 2026-10-23 | v0.3 | 新增 §3.1 `.run` 存档包格式与导入规则；引擎动作补 `runs.exportPack` / `runs.importPack`；验收补存档迁移 |
