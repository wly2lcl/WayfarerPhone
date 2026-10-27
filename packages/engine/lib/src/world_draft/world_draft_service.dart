import 'dart:convert';
import 'dart:math';

import 'package:contracts/contracts.dart';
import 'package:drift/drift.dart';

import '../data/app_db.dart';
import '../data/runs_dao.dart';
import '../engine.dart' show StartResult;
import '../errors.dart';
import '../llm/gateway.dart';
import '../llm/settings.dart' show GatewayRole;
import '../prompts/roles.dart' show extractJson;
import 'checks.dart';
import 'draft_models.dart';
import 'import_models.dart';
import 'prompts.dart' as dp;

/// 访谈一轮的结果（API 参考 WorldDraftService.interview）
class InterviewTurnResult {
  final FieldKey field;
  final bool advanced;
  final String question;
  final FieldKey nextStep;
  final int completeness;
  final ({String conflictWith, String reason})? contradiction;
  final bool filledByAI;
  final bool allAnswered;

  InterviewTurnResult({
    required this.field,
    required this.advanced,
    required this.question,
    required this.nextStep,
    required this.completeness,
    this.contradiction,
    required this.filledByAI,
    required this.allAnswered,
  });
}

class FreezeResult {
  final String worldId;
  final int version;
  FreezeResult({required this.worldId, required this.version});
}

/// 编辑器全量数据：草稿快照 + 圣经 + 身份池 + 访谈状态
class DraftDetail {
  final DraftView view;
  final WorldBible? bible;
  final List<Identity> identities;
  final InterviewState? interview;
  DraftDetail({
    required this.view,
    required this.bible,
    required this.identities,
    required this.interview,
  });
}

typedef StateFactory = RunState Function(Identity identity, WorldBible bible);
typedef PrologueFactory = Future<String> Function(
    WorldBible bible, Identity identity, RunState state, String runId);

/// 世界工坊（世界创造与导入 §6）：进程内服务，非 HTTP
class WorldDraftService {
  final AppDb db;
  final ModelGateway gateway;
  final StateFactory initialState;
  final PrologueFactory prologue;
  final Random random;

  WorldDraftService({
    required this.db,
    required this.gateway,
    required this.initialState,
    required this.prologue,
    required this.random,
  });

  // ---- 创建 / 查询 ----

  Future<DraftView> create(DraftSource source, {String? importJobId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'd_${now.toRadixString(36)}_${random.nextInt(0xFFF).toRadixString(36)}';
    await db.into(db.worldDrafts).insert(WorldDraftsCompanion.insert(
          id: id,
          source: source.name,
          status: DraftStatus.draft.name,
          interview: Value(jsonEncode(
              InterviewState(step: FieldKey.era).toJson())),
          importJobId: importJobId == null
              ? const Value.absent()
              : Value(importJobId),
          exportable: Value(source != DraftSource.import),
          createdAt: now,
          updatedAt: now,
        ));
    return (await get(id))!;
  }

  Future<List<DraftView>> list() async {
    final rows = await (db.select(db.worldDrafts)
          ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
        .get();
    return rows.map(_viewOf).toList();
  }

  Future<DraftView?> get(String draftId) async {
    final row = await _row(draftId);
    return row == null ? null : _viewOf(row);
  }

  Future<DraftDetail> detail(String draftId) async {
    final row = await _row(draftId);
    if (row == null) throw EngineException(EngineCode.notFound, '草稿不存在');
    final bible = _bibleOf(row);
    return DraftDetail(
      view: _viewOf(row),
      bible: bible,
      identities: _identitiesOf(row),
      interview:
          row.interview == null ? null : InterviewState.fromJson(jsonDecode(row.interview!)),
    );
  }

  /// 删除草稿（试玩局随 runs 级联清理由调用方用 deleteRun 处理）。
  /// 导入草稿删除时级联清理其导入作业与分块：否则同文件重导会按
  /// content_hash 命中残留任务，draftId 指向已删草稿形成死链。
  Future<void> delete(String draftId) async {
    final row = await _row(draftId);
    if (row == null) return;
    if (row.status == DraftStatus.generating.name) {
      throw EngineException(EngineCode.stateInvalid, '生成进行中，无法删除');
    }
    final activeJob = await (db.select(db.importJobs)
          ..where((j) =>
              j.draftId.equals(draftId) &
              j.stage.isIn(const ['queued', 'extracting', 'merging', 'compressing'])))
        .getSingleOrNull();
    if (activeJob != null) {
      throw EngineException(EngineCode.stateInvalid, '导入进行中，无法删除');
    }
    final jobIds = await (db.select(db.importJobs)
          ..where((j) => j.draftId.equals(draftId)))
        .map((j) => j.id)
        .get();
    await db.transaction(() async {
      if (jobIds.isNotEmpty) {
        await (db.delete(db.importChunks)..where((c) => c.jobId.isIn(jobIds)))
            .go();
      }
      await (db.delete(db.importJobs)..where((j) => j.draftId.equals(draftId)))
          .go();
      await (db.delete(db.worldDrafts)..where((d) => d.id.equals(draftId)))
          .go();
    });
  }

  // ---- 结构化访谈 ----

  Future<InterviewTurnResult> interview(
    String draftId,
    String text, {
    bool skip = false,
  }) async {
    final row = await _row(draftId);
    if (row == null) throw EngineException(EngineCode.notFound, '草稿不存在');
    if (row.status != DraftStatus.draft.name) {
      throw EngineException(EngineCode.stateInvalid, '访谈仅在 draft 阶段可用');
    }
    final interview =
        InterviewState.fromJson(jsonDecode(row.interview ?? '{}'));
    final field = interview.step;
    final existing = {
      for (final e in interview.answers.entries) e.key: e.value.data,
    };

    FieldData data;
    var filledByAI = false;
    if (skip) {
      data = await _qualifiedFill(field, _worldHint(interview));
      filledByAI = true;
    } else {
      var parse = await _extract(field, text, existing);
      // 解析失败重试一次
      if (parse.data.isEmpty && !parse.skip) {
        parse = await _extract(field, text, existing);
      }
      if (parse.contradiction != null && !parse.skip) {
        // 矛盾当场指出，不落答案，由用户选边后重答
        return InterviewTurnResult(
          field: field,
          advanced: false,
          question: field.guideQuestion,
          nextStep: field,
          completeness: interview.completeness,
          contradiction: parse.contradiction,
          filledByAI: false,
          allAnswered: interview.answers.length >= FieldKey.values.length,
        );
      }
      if (parse.skip) {
        data = await _qualifiedFill(field, _worldHint(interview));
        filledByAI = true;
      } else if (parse.data.isNotEmpty) {
        data = parse.data;
      } else {
        data = {'raw': text.trim()};
      }
    }

    interview.answers[field] =
        FieldAnswer(text: skip ? '（跳过，AI 代填）' : text, data: data, filledByAI: filledByAI);
    final nextStep = _nextStep(interview);
    interview.step = nextStep;
    final completeness = interview.completeness;
    await _patch(draftId, WorldDraftsCompanion(
      interview: Value(jsonEncode(interview.toJson())),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
    return InterviewTurnResult(
      field: field,
      advanced: true,
      question: nextStep.guideQuestion,
      nextStep: nextStep,
      completeness: completeness,
      filledByAI: filledByAI,
      allAnswered: interview.answers.length >= FieldKey.values.length,
    );
  }

  FieldKey _nextStep(InterviewState s) {
    for (final k in FieldKey.values) {
      if (!s.answers.containsKey(k)) return k;
    }
    // 八字段都问过：指向得分最低的字段，允许重答补强
    var worst = FieldKey.era;
    var min = 101;
    for (final k in FieldKey.values) {
      final sc = scoreField(k, s.answers[k]?.data);
      if (sc < min) {
        min = sc;
        worst = k;
      }
    }
    return worst;
  }

  String _worldHint(InterviewState s) {
    final parts = <String>[];
    for (final k in FieldKey.values) {
      final a = s.answers[k];
      if (a == null) continue;
      parts.add('${k.label}：${a.text}');
    }
    final hint = parts.join('；');
    return hint.length > 400 ? hint.substring(0, 400) : hint;
  }

  Future<dp.InterviewParse> _extract(
      FieldKey field, String text, Map<FieldKey, FieldData> existing) async {
    final res = await gateway.complete(GatewayRequest(
      role: GatewayRole.interview,
      system: dp.buildInterviewSystem(),
      user: dp.buildInterviewUser(field: field, question: field.guideQuestion, reply: text, existing: existing),
      jsonMode: true,
      temperature: 0.2,
      maxTokens: 900,
    ));
    return dp.parseInterview(res.text);
  }

  Future<FieldData?> _defaultFill(FieldKey field, String hint) async {
    try {
      final res = await gateway.complete(GatewayRequest(
        role: GatewayRole.interview,
        system: dp.buildInterviewSystem(),
        user: dp.buildDefaultFillUser(field, hint),
        jsonMode: true,
        temperature: 0.5,
        maxTokens: 900,
      ));
      final m = extractJson(res.text);
      final data = rawMap(m?['data']);
      return data.isEmpty ? null : data;
    } on EngineException {
      return null;
    }
  }

  /// AI 代填 + 形状验收：代填 map 非空但缺键/空表（形状漂移）时单字段打分为 0，
  /// 此时退回静态兜底，避免「代填成功」却产出 0 分字段（真机：AI·基调 0）
  Future<FieldData> _qualifiedFill(FieldKey field, String hint) async {
    final ai = await _defaultFill(field, hint);
    if (ai != null && scoreField(field, ai) > 0) return ai;
    return _staticDefault(field);
  }

  // ---- 生成与校验 ----

  Future<DraftView> generate(String draftId) async {
    final row = await _row(draftId);
    if (row == null) throw EngineException(EngineCode.notFound, '草稿不存在');
    // generating 允许重入：单机单进程内 UI 不会并发触发生成，能再次进入
    // 只能是上一次生成异常退出（或进程重启）留下的僵死状态，重试即恢复。
    if (row.status == DraftStatus.trial.name ||
        row.status == DraftStatus.frozen.name) {
      throw EngineException(EngineCode.stateInvalid, '当前状态不可生成');
    }
    final interview =
        InterviewState.fromJson(jsonDecode(row.interview ?? '{}'));
    if (interview.completeness < kCompletenessGate) {
      throw EngineException(EngineCode.draftIncomplete,
          '完整度 ${interview.completeness}%（需 ≥$kCompletenessGate%），先补足访谈');
    }
    return _compose(draftId, dp.buildBibleCoreUser(interview));
  }

  /// M2：导入管线用抽取素材合成圣经（无访谈、不做完整度门禁，仅 draft 可进入）
  Future<DraftView> generateFromMaterial(
      String draftId, String materialUser) async {
    final row = await _row(draftId);
    if (row == null) throw EngineException(EngineCode.notFound, '草稿不存在');
    if (row.status != DraftStatus.draft.name) {
      throw EngineException(EngineCode.stateInvalid, '当前状态不可生成');
    }
    return _compose(draftId, materialUser);
  }

  Future<DraftView> _compose(String draftId, String coreUser) async {
    await _patch(draftId, WorldDraftsCompanion(
      status: Value(DraftStatus.generating.name),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
    try {
      final core = await _callJson(
        system: dp.buildBibleCoreSystem(),
        user: coreUser,
        role: GatewayRole.composer,
        maxTokens: 4000,
        temperature: 0.7,
      );
      var bible = dp.parseBibleCore(core);
      if (bible == null) {
        final retry = await _callJson(
          system: dp.buildBibleCoreSystem(),
          user: coreUser,
          role: GatewayRole.composer,
          maxTokens: 4000,
          temperature: 0.7,
        );
        bible = dp.parseBibleCore(retry);
      }
      if (bible == null) {
        throw EngineException(EngineCode.modelBadOutput, '世界生成失败，请重试',
            canRetry: true);
      }

      final content = await _callJson(
        system: dp.buildBibleCoreSystem(),
        user: dp.buildBibleContentUser(core),
        role: GatewayRole.composer,
        maxTokens: 5000,
        temperature: 0.7,
      );
      try {
        bible = _mergeContent(bible, content);
      } on EngineException {
        // 内容段一次生成失败率偏高（长 JSON 截断），自动重试一次
        final retry = await _callJson(
          system: dp.buildBibleCoreSystem(),
          user: dp.buildBibleContentUser(core),
          role: GatewayRole.composer,
          maxTokens: 5000,
          temperature: 0.7,
        );
        bible = _mergeContent(bible!, retry);
      }

      final identities = await _identities(bible, core, content);

      _ensureFactionBases(bible);
      final quality = reviewBible(bible);
      final now = DateTime.now().millisecondsSinceEpoch;
      await _patch(draftId, WorldDraftsCompanion(
        status: Value(DraftStatus.review.name),
        bibleDraft: Value(jsonEncode(bible.toJson())),
        identities: Value(jsonEncode(identities.map((i) => i.toJson()).toList())),
        seeds: Value(jsonEncode(bible.eventSeeds.map((s) => s.toJson()).toList())),
        quality: Value(jsonEncode(quality.toJson())),
        updatedAt: Value(now),
      ));
    } catch (e) {
      // 任何异常（含解析 TypeError/FormatException）都必须回滚状态，
      // 否则草稿永久卡在 generating。
      await _patch(draftId, WorldDraftsCompanion(
        status: Value(DraftStatus.draft.name),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));
      if (e is EngineException) rethrow;
      throw EngineException(EngineCode.modelBadOutput,
          '世界生成失败：$e', canRetry: true);
    }
    return (await get(draftId))!;
  }

  /// 合成器可能漏写据点（提示词约束并非保证）：无据点势力自动挂到危险度最低
  /// 的区域（最宜定居），否则 error 门禁会永久阻塞试玩/冻结，而地区只读无法自救
  void _ensureFactionBases(WorldBible bible) {
    final based = <String>{for (final r in bible.regions) ...r.factionIds};
    final unbased = bible.factions.where((f) => !based.contains(f.id)).toList();
    if (unbased.isEmpty || bible.regions.isEmpty) return;
    var host = bible.regions.first;
    for (final r in bible.regions) {
      if (r.danger < host.danger) host = r;
    }
    host.factionIds.addAll(unbased.map((f) => f.id));
  }

  WorldBible _mergeContent(WorldBible core, String contentJson) {
    final m = extractJson(contentJson);
    if (m == null) {
      throw EngineException(EngineCode.modelBadOutput, '内容生成失败，请重试',
          canRetry: true);
    }
    final full = {
      'schemaVersion': core.schemaVersion,
      'meta': core.meta.toJson(),
      'eras': core.eras.map((e) => e.toJson()).toList(),
      'regions': core.regions.map((e) => e.toJson()).toList(),
      'factions': core.factions.map((e) => e.toJson()).toList(),
      'powerSystem': core.powerSystem.toJson(),
      'taboos': core.taboos,
      'npcPool': m['npcPool'],
      'eventSeeds': m['eventSeeds'],
      'endgame': m['endgame'],
    };
    try {
      return WorldBible.fromJson(full);
    } catch (_) {
      throw EngineException(EngineCode.modelBadOutput, '内容生成失败，请重试',
          canRetry: true);
    }
  }

  Future<List<Identity>> _identities(
      WorldBible bible, String coreJson, String contentJson) async {
    final text = await _callJson(
      system: dp.buildBibleCoreSystem(),
      user: dp.buildIdentitiesUser(coreJson, contentJson),
      role: GatewayRole.composer,
      maxTokens: 1500,
      temperature: 0.8,
    );
    final m = extractJson(text);
    List<Identity> list;
    try {
      list = asListOfMaps<Identity>(m?['identities'], Identity.fromJson);
    } catch (_) {
      throw EngineException(EngineCode.modelBadOutput, '身份池生成失败，请重试',
          canRetry: true);
    }
    if (list.length < 3) {
      throw EngineException(EngineCode.modelBadOutput, '身份池生成失败，请重试',
          canRetry: true);
    }
    return list.take(5).toList();
  }

  Future<String> _callJson({
    required String system,
    required String user,
    required GatewayRole role,
    required int maxTokens,
    required double temperature,
  }) async {
    final res = await gateway.complete(GatewayRequest(
      role: role,
      system: system,
      user: user,
      jsonMode: true,
      temperature: temperature,
      maxTokens: maxTokens,
    ));
    return res.text;
  }

  // ---- 编辑器保存 ----

  Future<DraftView> save(
    String draftId, {
    WorldBible? bible,
    List<Identity>? identities,
    List<EventSeed>? seeds,
  }) async {
    final row = await _row(draftId);
    if (row == null) throw EngineException(EngineCode.notFound, '草稿不存在');
    if (row.status == DraftStatus.generating.name) {
      throw EngineException(EngineCode.stateInvalid, '生成进行中，稍候再改');
    }
    var qualityRaw = row.quality;
    WorldBible? patchedBible;
    if (bible != null) {
      // schemaVersion 与校验和不可经编辑器修改（世界创造与导入 §5）
      bible.schemaVersion = 1;
      final quality = reviewBible(bible);
      // 导入草稿：覆盖率门禁不得被编辑器保存抹掉——否则改个标题即可绕过
      // IMPORT_COVERAGE_LOW 试玩（世界创造与导入 §4.4）。用导入实体对新圣经重算。
      final covIssue = await _importCoverageIssue(draftId, bible);
      qualityRaw = jsonEncode(
        (covIssue == null
                ? quality
                : QualityReport(
                    score: (quality.score - 35).clamp(0, 100),
                    issues: [...quality.issues, covIssue],
                  ))
            .toJson(),
      );
      patchedBible = bible;
    }
    final patch = WorldDraftsCompanion(
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      bibleDraft: patchedBible == null
          ? const Value.absent()
          : Value(jsonEncode(patchedBible.toJson())),
      quality: qualityRaw == null
          ? const Value.absent()
          : Value(qualityRaw),
      identities: identities == null
          ? const Value.absent()
          : Value(jsonEncode(identities.map((i) => i.toJson()).toList())),
      seeds: seeds == null
          ? const Value.absent()
          : Value(jsonEncode(seeds.map((s) => s.toJson()).toList())),
    );
    await _patch(draftId, patch);
    return (await get(draftId))!;
  }

  /// 导入草稿的主要人物覆盖率门禁：前 20 高频人物在新圣经中的命中率 <80%
  /// 时返回错误条目（与 ImportService._ensureCoverage 同口径，世界创造与导入 §4.4）
  Future<QualityIssue?> _importCoverageIssue(
      String draftId, WorldBible bible) async {
    final jobs = await (db.select(db.importJobs)
          ..where((j) => j.draftId.equals(draftId))
          ..orderBy([(j) => OrderingTerm.desc(j.updatedAt)])
          ..limit(1))
        .get();
    if (jobs.isEmpty || jobs.first.entities == null) return null;
    try {
      final entities = asListOfMaps<ImportEntity>(
          jsonDecode(jobs.first.entities!), ImportEntity.fromJson);
      final coverage = characterCoverage(entities, bible.toJson());
      if (coverage >= 0.8) return null;
      return QualityIssue(
        level: 'error',
        field: 'npcPool',
        code: 'IMPORT_COVERAGE_LOW',
        message:
            '主要人物覆盖率 ${(coverage * 100).round()}%（需 ≥80%），在编辑器把高频人物补进 NPC 池后再试玩',
      );
    } catch (_) {
      return null;
    }
  }

  // ---- 试玩 ----

  Future<StartResult> trial(String draftId, {String? identityId}) async {
    final row = await _row(draftId);
    if (row == null) throw EngineException(EngineCode.notFound, '草稿不存在');
    final status = draftStatusByName(row.status);
    if (status != DraftStatus.review &&
        status != DraftStatus.trial &&
        status != DraftStatus.frozen) {
      throw EngineException(EngineCode.stateInvalid, '先生成并审阅后才能试玩');
    }
    final bible = _bibleOf(row);
    if (bible == null) {
      throw EngineException(EngineCode.draftIncomplete, '尚未生成世界圣经');
    }
    final quality = row.quality == null
        ? reviewBible(bible)
        : QualityReport.fromJson(jsonDecode(row.quality!));
    if (!quality.pass) {
      throw EngineException(EngineCode.qualityGateFailed, '一致性检查未通过，先在编辑器里补齐');
    }
    final pool = _identitiesOf(row);
    if (pool.isEmpty) {
      throw EngineException(EngineCode.draftIncomplete, '身份池为空');
    }
    Identity identity;
    if (identityId != null) {
      identity = pool.where((i) => i.id == identityId).firstOrNull ??
          (throw EngineException(EngineCode.notFound, '身份不存在'));
    } else {
      identity = _pickWeighted(pool);
    }

    final state = initialState(identity, bible);
    final runId = 'r_${random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0')}';
    await _deleteTrialRuns(draftId);
    await RunsDao(db).createRun(
      runId: runId,
      worldId: 'draft_$draftId',
      worldVersion: 0,
      identityId: identity.id,
      initialState: state,
      isTrial: true,
      draftId: draftId,
    );
    final prologueText = await prologue(bible, identity, state, runId);
    final choices = _defaultChoices();
    await _writePrologueEvents(runId, prologueText, choices);
    if (status == DraftStatus.review) {
      await _patch(draftId, WorldDraftsCompanion(
        status: Value(DraftStatus.trial.name),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));
    }
    return StartResult(
        runId: runId, state: state, prologue: prologueText, choices: choices);
  }

  /// 丢弃该草稿的试玩局（一键丢弃，世界创造与导入 §6）
  Future<void> discardTrial(String draftId) async {
    await _deleteTrialRuns(draftId);
    final row = await _row(draftId);
    if (row != null && row.status == DraftStatus.trial.name) {
      await _patch(draftId, WorldDraftsCompanion(
        status: const Value('review'),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));
    }
  }

  Future<void> _deleteTrialRuns(String draftId) async {
    final rows = await (db.select(db.runs)
          ..where((r) => r.draftId.equals(draftId) & r.isTrial.equals(true)))
        .get();
    for (final r in rows) {
      await (db.delete(db.runs)..where((x) => x.id.equals(r.id))).go();
      await (db.delete(db.runSnapshots)
            ..where((s) => s.runId.equals(r.id)))
          .go();
      await (db.delete(db.runEvents)..where((e) => e.runId.equals(r.id))).go();
    }
  }

  Identity _pickWeighted(List<Identity> pool) {
    const weights = {'common': 70, 'rare': 25, 'unique': 5};
    final total = pool.fold<int>(0, (acc, i) => acc + weights[i.rarity.name]!);
    var roll = random.nextInt(total);
    for (final i in pool) {
      roll -= weights[i.rarity.name]!;
      if (roll < 0) return i;
    }
    return pool.first;
  }

  List<Choice> _defaultChoices() => [
        Choice(id: 't0c1', label: '先把眼前的事应付过去', intent: '应付眼前事务，观察环境', risk: Risk.low),
        Choice(id: 't0c2', label: '找一个能打听消息的人', intent: '寻找信息源打听处境', risk: Risk.low),
        Choice(id: 't0c3', label: '直接去查那件最要紧的事', intent: '直奔长期目标调查', risk: Risk.high),
      ];

  Future<void> _writePrologueEvents(
      String runId, String prologueText, List<Choice> choices) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      await db.into(db.runEvents).insert(RunEventsCompanion.insert(
            runId: runId,
            seq: 1,
            turnNo: 0,
            type: 'narration',
            payload: jsonEncode({'text': prologueText}),
            createdAt: now,
          ));
      await db.into(db.runEvents).insert(RunEventsCompanion.insert(
            runId: runId,
            seq: 2,
            turnNo: 0,
            type: 'choice',
            payload: jsonEncode({'options': choices.map((c) => c.toJson()).toList()}),
            createdAt: now,
          ));
    });
  }

  // ---- 冻结 ----

  Future<FreezeResult> freeze(String draftId) async {
    final row = await _row(draftId);
    if (row == null) throw EngineException(EngineCode.notFound, '草稿不存在');
    final status = draftStatusByName(row.status);
    if (status != DraftStatus.review &&
        status != DraftStatus.trial &&
        status != DraftStatus.frozen) {
      throw EngineException(EngineCode.stateInvalid, '审阅通过后才能冻结');
    }
    final bible = _bibleOf(row);
    if (bible == null) {
      throw EngineException(EngineCode.draftIncomplete, '尚未生成世界圣经');
    }
    if (row.source != DraftSource.import.name) {
      final interview =
          InterviewState.fromJson(jsonDecode(row.interview ?? '{}'));
      if (interview.completeness < kCompletenessGate) {
        throw EngineException(EngineCode.draftIncomplete,
            '完整度 ${interview.completeness}%（需 ≥$kCompletenessGate%），不可冻结');
      }
    }
    final quality = reviewBible(bible);
    if (!quality.pass) {
      throw EngineException(
          EngineCode.qualityGateFailed, '一致性检查未通过：${quality.issues.where((i) => i.level == 'error').first.message}');
    }

    final identities = _identitiesOf(row);
    final seeds = bible.eventSeeds;
    final checksum = _packageChecksum(bible, identities, seeds);
    final now = DateTime.now().millisecondsSinceEpoch;

    var worldId = row.worldId;
    var latestVersion = 0;
    String? latestChecksum;
    if (worldId == null) {
      worldId = 'w_${now.toRadixString(36)}_${random.nextInt(0xFFF).toRadixString(36)}';
      await db.into(db.worlds).insert(WorldsCompanion.insert(
            id: worldId,
            title: bible.meta.title,
            genre: bible.meta.genre,
            summary: Value(bible.meta.summary),
            source: row.source,
            exportable: Value(row.exportable),
            createdAt: now,
            updatedAt: now,
          ));
    } else {
      final versions = await (db.select(db.worldVersions)
            ..where((v) => v.worldId.equals(worldId!)))
          .get();
      if (versions.isNotEmpty) {
        final latest = versions.reduce((a, b) => a.version > b.version ? a : b);
        latestVersion = latest.version;
        latestChecksum = latest.checksum;
      }
    }
    if (latestChecksum == checksum) {
      throw EngineException(EngineCode.worldFrozen, '已是最新冻结版本，没有需要冻结的新修改');
    }
    final version = latestVersion + 1;
    final wid = worldId;
    await db.transaction(() async {
      await db.into(db.worldVersions).insert(WorldVersionsCompanion.insert(
            id: 'wv_${wid}_v$version',
            worldId: wid,
            version: version,
            bible: jsonEncode(bible.toJson()),
            identities: jsonEncode(identities.map((i) => i.toJson()).toList()),
            seeds: jsonEncode(seeds.map((s) => s.toJson()).toList()),
            checksum: checksum,
            createdAt: now,
          ));
      await (db.update(db.worlds)..where((w) => w.id.equals(wid))).write(
          WorldsCompanion(
              latestVersion: Value(version), updatedAt: Value(now)));
      await _patch(draftId, WorldDraftsCompanion(
        status: Value(DraftStatus.frozen.name),
        worldId: Value(wid),
        quality: Value(jsonEncode(quality.toJson())),
        updatedAt: Value(now),
      ));
    });
    return FreezeResult(worldId: wid, version: version);
  }

  String _packageChecksum(
      WorldBible bible, List<Identity> identities, List<EventSeed> seeds) {
    Object? sortKeys(Object? v) {
      if (v is Map) {
        final keys = v.keys.map((k) => k.toString()).toList()..sort();
        return {for (final k in keys) k: sortKeys(v[k])};
      }
      if (v is List) return v.map(sortKeys).toList();
      return v;
    }

    return jsonEncode({
      'bible': sortKeys(bible.toJson()),
      'identities': sortKeys(identities.map((i) => i.toJson()).toList()),
      'seeds': sortKeys(seeds.map((s) => s.toJson()).toList()),
    });
  }

  // ---- 内部 ----

  Future<WorldDraft?> _row(String draftId) => (db.select(db.worldDrafts)
        ..where((d) => d.id.equals(draftId)))
      .getSingleOrNull();

  Future<void> _patch(String draftId, WorldDraftsCompanion patch) =>
      (db.update(db.worldDrafts)..where((d) => d.id.equals(draftId)))
          .write(patch);

  WorldBible? _bibleOf(WorldDraft row) {
    final raw = row.bibleDraft;
    if (raw == null || raw.isEmpty) return null;
    try {
      return WorldBible.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  List<Identity> _identitiesOf(WorldDraft row) => asList<Identity>(
      jsonDecode(row.identities ?? '[]'), Identity.fromJson);

  DraftView _viewOf(WorldDraft row) {
    final interview = row.interview == null
        ? null
        : InterviewState.fromJson(jsonDecode(row.interview!));
    final bible = _bibleOf(row);
    final quality = row.quality == null
        ? null
        : QualityReport.fromJson(jsonDecode(row.quality!));
    final title = (bible?.meta.title.isNotEmpty ?? false)
        ? bible!.meta.title
        : '未命名世界';
    return DraftView(
      id: row.id,
      source: draftSourceByName(row.source),
      status: draftStatusByName(row.status),
      title: title,
      step: interview?.step,
      completeness: interview?.completeness ?? 0,
      fields: {
        for (final k in FieldKey.values)
          k: (
            answered: interview?.answers.containsKey(k) ?? false,
            filledByAI: interview?.answers[k]?.filledByAI ?? false,
            score: scoreField(k, interview?.answers[k]?.data),
          ),
      },
      qualityScore: quality?.score ?? 0,
      issues: quality == null
          ? const []
          : quality.issues
              .map((i) => (
                    level: i.level,
                    code: i.code,
                    field: i.field,
                    message: i.message
                  ))
              .toList(),
      exportable: row.exportable,
      worldId: row.worldId,
      updatedAt: row.updatedAt,
    );
  }
}

// ---- 跳过时的静态兜底默认（离线可用，字段间自洽） ----

FieldData _staticDefault(FieldKey k) => switch (k) {
      FieldKey.era => const {
          'summary': '灵潮退去后的末法之世，修士在枯竭的灵脉间挣扎求生。',
          'turningPoint': '主灵脉水位一夜跌破红线，各方维持的平衡开始崩塌。',
        },
      FieldKey.geography => const {
          'regions': [
            {'name': '云岫城', 'use': '转卖灵材与消息的商埠，明市与鬼市各据一头', 'danger': '2'},
            {'name': '黑水泽', 'use': '散修搏命的猎场，雾气散开时露出一角秘境', 'danger': '4'},
            {'name': '青冥宗山门', 'use': '垄断灵脉与收徒的宗门重地', 'danger': '1'},
          ],
        },
      FieldKey.factions => const {
          'factions': [
            {
              'name': '青冥宗',
              'goal': '守住最后的灵脉，维持收徒垄断',
              'relations': [
                {'name': '缇骑', 'stance': '提防'},
                {'name': '三方堂', 'stance': '结盟'},
              ],
            },
            {
              'name': '缇骑',
              'goal': '替朝廷清查修士，收编或清除',
              'relations': [
                {'name': '青冥宗', 'stance': '提防'},
                {'name': '三方堂', 'stance': '敌对'},
              ],
            },
            {
              'name': '三方堂',
              'goal': '倒卖灵材与消息，谁给钱帮谁',
              'relations': [
                {'name': '青冥宗', 'stance': '结盟'},
                {'name': '缇骑', 'stance': '敌对'},
              ],
            },
          ],
        },
      FieldKey.power => const {
          'tiers': ['炼气', '筑基', '金丹'],
          'costs': ['寿元折损：突破失败折寿十年', '心魔暗伤：强行催境会留下终生病根'],
          'rules': ['灵气枯竭，突破全凭资源与机缘'],
        },
      FieldKey.taboos => const {
          'items': ['不得在缇骑面前显露灵力', '不得私探宗门禁地', '不得以活人试药'],
        },
      FieldKey.tone => const {
          'words': ['冷峻', '克制', '压抑', '命运感'],
        },
      FieldKey.npcs => const {
          'npcs': [
            {
              'name': '陈掌柜',
              'role': '三方堂在云岫城的坐商',
              'affiliation': '三方堂',
              'want': '把鬼市的货源攥进自己手里',
              'secret': '他替缇骑记着一份散修名单',
            },
            {
              'name': '柳师姐',
              'role': '青冥宗外门执事',
              'affiliation': '青冥宗',
              'want': '在内门考核前凑齐突破的丹资',
              'secret': '她的丹资是从死人身上收来的',
            },
            {
              'name': '周缇领',
              'role': '缇骑驻城领队',
              'affiliation': '缇骑',
              'want': '立一件像样的功劳好调回京城',
              'secret': '他自己也曾是个散修',
            },
            {
              'name': '哑叔',
              'role': '西市杂役，什么人都认识',
              'affiliation': '散人',
              'want': '安安静静活到老',
              'secret': '他听得见，只是不肯说',
            },
            {
              'name': '裴药师',
              'role': '黑水泽边缘的野郎中',
              'affiliation': '散人',
              'want': '用秘境里的东西救一个人',
              'secret': '要救的人早已不在了',
            },
          ],
        },
      FieldKey.events => const {
          'events': [
            {'title': '鬼市货源断了', 'trigger': '进入鬼市且与陈掌柜打过交道'},
            {'title': '缇骑夜查西市', 'trigger': '在西市显露过灵力'},
            {'title': '秘境雾气散开一角', 'trigger': '第 2 卷起进入黑水泽'},
            {'title': '宗门收徒大比', 'trigger': '与柳师姐相识并修为达炼气三层'},
            {'title': '黑市丹药案发', 'trigger': '从裴药师处买过丹药'},
            {'title': '名单上一个名字', 'trigger': '陈掌柜发现你在查散修名单'},
            {'title': '灵脉水位再降', 'trigger': '进入第 2 卷'},
            {'title': '旧识找上门', 'trigger': '拥有物品「旧玉牌」'},
          ],
        },
    };
