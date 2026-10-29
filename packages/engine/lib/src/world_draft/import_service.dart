import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:contracts/contracts.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart';

import '../data/app_db.dart';
import '../data/flags.dart';
import '../errors.dart';
import '../llm/gateway.dart';
import '../llm/settings.dart';
import '../safety/content_safety.dart';
import 'checks.dart' show QualityIssue, QualityReport;
import 'draft_models.dart';
import 'import_models.dart';
import 'import_prompts.dart' as ip;
import 'world_draft_service.dart';

/// M2 小说 TXT 导入（世界创造与导入 §4）
///
/// 管线：解码分块（Isolate）→ 逐块抽取（extractor，最多 2 路并发）
/// → 归并 → 圣经合成（复用 M1 composer 管线）→ 覆盖率门槛 → review。
/// 每块抽取结果落 import_chunks，done/total 落 import_jobs；进程被杀后
/// 用 resume(jobId) 从已完成的下一块继续，不重复消耗模型调用。
class ImportService {
  final AppDb db;
  final ModelGateway gateway;
  final WorldDraftService drafts;
  final Random random;

  /// 单文件上限；测试可注入小值
  final int maxBytes;

  /// 抽取重试退避；测试注入零时长提速
  final Duration Function(int attempt) backoff;

  ImportService({
    required this.db,
    required this.gateway,
    required this.drafts,
    required this.random,
    this.maxBytes = 20 * 1024 * 1024,
    Duration Function(int attempt)? backoff,
  }) : backoff = backoff ?? ((attempt) => Duration(seconds: 5 * attempt));

  static const chunkSize = 3000;
  static const chunkOverlap = 400;

  /// 正在跑的管线任务，防止 start 去重 / resume 双入口导致重复运行
  final _activeRuns = <String>{};

  // ---- 任务生命周期 ----

  /// 客户端已把 TXT 拷入沙盒私有目录后调用；重复导入命中已有任务
  ///
  /// [fidelity] 只在首次建立任务时生效：进行中任务自动续跑沿用原档位，
  /// 终态任务原样返回——换档重合成请走 [regenerate]。
  Future<ImportJobView> start(String sourcePath,
      {ImportFidelity fidelity = ImportFidelity.fast}) async {
    // 青少年模式（合规 §5）：关闭自定义导入入口
    if (await AppFlags(db).teenModeOn()) {
      throw EngineException(EngineCode.stateInvalid, '青少年模式下不可导入');
    }
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw EngineException(EngineCode.importInvalid, '文件不存在');
    }
    // 输入层内容安全（合规 §3.1）：文件名与元数据本地拦截
    final nameVerdict = ContentSafety.screen(file.uri.pathSegments.last);
    if (nameVerdict.blocked) {
      throw ContentSafety.contentBlockedError(nameVerdict.matched);
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw EngineException(
          EngineCode.importTooLarge,
          '文件 ${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB，超过 '
          '${(maxBytes / 1024 / 1024).round()} MB 上限');
    }
    final hash = crypto.sha256.convert(bytes).toString();
    final existing = await (db.select(db.importJobs)
          ..where((j) => j.contentHash.equals(hash))
          ..orderBy([(j) => OrderingTerm.desc(j.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) {
      // 进行中但管线可能已死（如应用重启）：按续跑重启；终态直接返回
      final midFlight = existing.error == null &&
          const {'queued', 'extracting', 'merging', 'compressing'}
              .contains(existing.stage);
      return midFlight ? await resume(existing.id) : _view(existing);
    }
    final parsed = await _decodeAndChunk(bytes);
    if (parsed.chunks.isEmpty) {
      throw EngineException(EngineCode.importInvalid, '没有可解析的正文');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final draft = await drafts.create(DraftSource.import);
    final jobId =
        'ij_${now.toRadixString(36)}_${random.nextInt(0xFFF).toRadixString(36)}';
    await db.into(db.importJobs).insert(ImportJobsCompanion.insert(
          id: jobId,
          sourcePath: sourcePath,
          contentHash: hash,
          stage: 'extracting',
          draftId: Value(draft.id),
          done: const Value(0),
          total: Value(parsed.chunks.length),
          fidelity: Value(fidelity.index),
          stats: Value(ImportStats(
            chapters: parsed.chapters,
            chunks: parsed.chunks.length,
            entities: 0,
            relations: 0,
          ).encode()),
          createdAt: now,
          updatedAt: now,
        ));
    _linkDraft(draft.id, jobId);
    unawaited(_run(jobId, sourcePath, parsed.chunks));
    return _view((await _row(jobId))!);
  }

  /// 断点续跑：从 import_chunks 已有块之后继续；文件被换或丢失则任务失败
  Future<ImportJobView> resume(String jobId) async {
    final row = await _row(jobId);
    if (row == null) throw EngineException(EngineCode.notFound, '任务不存在');
    if (row.stage == 'review') return _view(row);
    final file = File(row.sourcePath);
    if (!await file.exists()) {
      await _fail(jobId, 'IMPORT_INVALID: 原文件已不存在，无法续跑');
      throw EngineException(EngineCode.importInvalid, '原文件已不存在，无法续跑');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw EngineException(EngineCode.importTooLarge, '文件超过大小上限');
    }
    final hash = crypto.sha256.convert(bytes).toString();
    if (hash != row.contentHash) {
      await _fail(jobId, 'IMPORT_INVALID: 文件内容与任务记录不一致');
      throw EngineException(EngineCode.importInvalid, '文件内容与任务记录不一致');
    }
    final parsed = await _decodeAndChunk(bytes);
    if (parsed.chunks.length != row.total) {
      await _fail(jobId, 'IMPORT_INVALID: 分块数与任务记录不一致');
      throw EngineException(EngineCode.importInvalid, '分块数与任务记录不一致');
    }
    await _patch(jobId, ImportJobsCompanion(
      stage: const Value('extracting'),
      error: const Value(null),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
    unawaited(_run(jobId, row.sourcePath, parsed.chunks));
    return _view((await _row(jobId))!);
  }

  Future<ImportJobView?> progress(String jobId) async {
    final row = await _row(jobId);
    return row == null ? null : _view(row);
  }

  /// 最近的导入任务（导入向导续跑列表用）
  Future<List<ImportJobView>> listJobs({int limit = 20}) async {
    final rows = await (db.select(db.importJobs)
          ..orderBy([(j) => OrderingTerm.desc(j.updatedAt)])
          ..limit(limit))
        .get();
    return rows.map(_view).toList();
  }

  // ---- 管线 ----

  Future<void> _run(
      String jobId, String sourcePath, List<NovelChunk> chunks) async {
    if (!_activeRuns.add(jobId)) return;
    try {
      final job = await _row(jobId);
      if (job == null || job.draftId == null) return;
      final draftId = job.draftId!;
      // ---- extract（最多 2 路并发，逐块落库；任一块终失败即全停） ----
      final have = (await (db.select(db.importChunks)
                ..where((c) => c.jobId.equals(jobId)))
              .get())
          .map((c) => c.idx)
          .toSet();
      var stop = false;
      Object? failure;
      var cursor = 0;
      Future<void> worker() async {
        while (!stop) {
          final i = cursor;
          if (i >= chunks.length) return;
          cursor = i + 1;
          if (have.contains(chunks[i].idx)) continue;
          try {
            final extraction = await _extractChunk(chunks[i]);
            await db.into(db.importChunks).insert(
                ImportChunksCompanion.insert(
                  jobId: jobId,
                  idx: chunks[i].idx,
                  payload: jsonEncode(extraction.toJson()),
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                ),
                onConflict: DoNothing());
            await _bumpDone(jobId, chunks[i].idx + 1);
          } catch (e) {
            stop = true;
            failure ??= e;
            return;
          }
        }
      }

      await Future.wait([worker(), worker()]);
      final err = failure;
      if (err != null) {
        if (err is EngineException) {
          throw err;
        }
        throw EngineException(EngineCode.modelBadOutput, '分块抽取失败：$err');
      }

      // ---- merge（纯代码） ----
      final parts = (await (db.select(db.importChunks)
                ..where((c) => c.jobId.equals(jobId))
                ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
              .get())
          .map((c) => ChunkExtraction.fromJson(jsonDecode(c.payload)))
          .toList();
      // 实体先落库：compose 失败时审阅/重新生成世界仍有数据可用
      final merged = mergeExtractions(parts);
      final summaries =
          parts.map((p) => p.summary).where((s) => s.isNotEmpty).toList();
      final entitiesJson =
          jsonEncode(merged.entities.map((e) => e.toJson()).toList());
      await _patch(jobId, ImportJobsCompanion(
        stage: const Value('merging'),
        entities: Value(entitiesJson),
        entitiesTotal: Value(merged.entities.length),
        stats: Value(ImportStats(
          chapters: ImportStats.tryDecode(job.stats)?.chapters ?? 0,
          chunks: job.total,
          entities: merged.entities.length,
          relations: merged.relations.length,
        ).encode()),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));

      // ---- compose（复用 M1 生成管线；忠实档先压缩全书脉络） ----
      final fidelity = ImportFidelity.fromIndex(job.fidelity);
      List<String>? arcs;
      if (fidelity == ImportFidelity.faithful && summaries.length > 16) {
        await _patch(jobId, ImportJobsCompanion(
          stage: const Value('compressing'),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
        // 压缩失败不失败任务：降级为标准档采样
        arcs = await _compressArcs(summaries);
      }
      final digest = _digestFor(
          fidelity, merged, summaries, arcs);
      await drafts.generateFromMaterial(
        draftId,
        ip.buildImportCoreUser(
          entities: digest.entities,
          relations: digest.relations,
          timeline: digest.timeline,
          chunkSummaries: digest.chunkSummaries,
          arcSummaries: digest.arcs,
        ),
      );
      await _applyCoverageGate(draftId, merged.entities);

      await _patch(jobId, ImportJobsCompanion(
        stage: const Value('review'),
        done: Value(job.total),
        progress: const Value(1.0),
        error: const Value(null),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));
    } on EngineException catch (e) {
      await _fail(jobId, '${e.code.wireName}: ${e.message}');
    } catch (e) {
      await _fail(jobId, 'IMPORT_FAILED: $e');
    } finally {
      _activeRuns.remove(jobId);
    }
  }

  Future<ChunkExtraction> _extractChunk(NovelChunk chunk) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(backoff(attempt));
      }
      try {
        final res = await gateway.complete(GatewayRequest(
          role: GatewayRole.extractor,
          system: ip.buildChunkSystem(),
          user: ip.buildChunkUser(chunk),
          jsonMode: true,
          temperature: 0.2,
          maxTokens: 1800,
        ));
        final parsed = ip.parseChunkExtraction(res.text);
        if (parsed != null) return parsed;
        lastError =
            EngineException(EngineCode.modelBadOutput, '分块抽取输出无法解析');
      } on EngineException catch (e) {
        if (e.code == EngineCode.contentBlocked) rethrow;
        lastError = e;
      }
    }
    throw lastError ??
        EngineException(EngineCode.modelBadOutput, '分块抽取失败');
  }

  /// 档位 → 合成素材覆盖策略（世界创造与导入 §4.6）：
  /// fast 截断取前 N；standard 全书均匀采样；faithful 用卷级脉络替换分块摘要
  /// （压缩失败 arcs=null 时降级为 standard 采样）
  ({List<ImportEntity> entities, List<ImportRelation> relations,
          List<ImportTimelinePoint> timeline, List<String> chunkSummaries,
          List<String> arcs})
      _digestFor(ImportFidelity fidelity,
          ({List<ImportEntity> entities, List<ImportRelation> relations,
              List<ImportTimelinePoint> timeline})
          merged,
          List<String> summaries,
          List<String>? arcs) {
    switch (fidelity) {
      case ImportFidelity.fast:
        return (
          entities: merged.entities.take(50).toList(),
          relations: merged.relations.take(80).toList(),
          timeline: merged.timeline.take(40).toList(),
          chunkSummaries: summaries.take(60).toList(),
          arcs: const [],
        );
      case ImportFidelity.standard:
      case ImportFidelity.faithful when arcs == null:
        // faithful 压缩失败 → 降级为标准档全书采样
        return (
          entities: merged.entities.take(80).toList(),
          relations: sampleEvenly(merged.relations, 120),
          timeline: sampleEvenly(merged.timeline, 60),
          chunkSummaries: sampleEvenly(summaries, 60),
          arcs: const [],
        );
      case ImportFidelity.faithful:
        return (
          entities: merged.entities.take(80).toList(),
          relations: sampleEvenly(merged.relations, 120),
          timeline: sampleEvenly(merged.timeline, 80),
          chunkSummaries: const [],
          arcs: arcs!,
        );
    }
  }

  /// 全书分块摘要 → 卷级脉络（extractor 小模型，3 次退避重试；
  /// 终失败返回 null，由调用方降级，不让任务失败）
  Future<List<String>?> _compressArcs(List<String> summaries) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(backoff(attempt));
      }
      try {
        final res = await gateway.complete(GatewayRequest(
          role: GatewayRole.extractor,
          system: ip.buildImportArcSystem(),
          user: ip.buildImportArcUser(summaries),
          jsonMode: true,
          temperature: 0.2,
          maxTokens: 1600,
        ));
        final arcs = ip.parseImportArcs(res.text);
        if (arcs != null) return arcs;
      } on EngineException catch (e) {
        if (e.code == EngineCode.contentBlocked) return null;
      }
    }
    return null;
  }

  /// 质量门槛 §4.4：主要人物覆盖率 < 80% 追加 error 级问题，
  /// 复用试玩/冻结的 quality.pass 闸门（用户可在编辑器补 NPC 后重试）
  Future<void> _applyCoverageGate(
      String draftId, List<ImportEntity> entities) async {
    final detail = await drafts.detail(draftId);
    if (detail.bible == null) return;
    final coverage = characterCoverage(entities, detail.bible!.toJson());
    if (coverage >= 0.8) return;
    final raw = (await (db.select(db.worldDrafts)
              ..where((d) => d.id.equals(draftId)))
            .getSingle())
        .quality;
    final report = raw == null
        ? const QualityReport(score: 100, issues: [])
        : QualityReport.fromJson(jsonDecode(raw));
    final patched = QualityReport(
      score: (report.score - 35).clamp(0, 100),
      issues: [
        ...report.issues,
        QualityIssue(
          level: 'error',
          field: 'npcPool',
          code: 'IMPORT_COVERAGE_LOW',
          message:
              '主要人物覆盖率 ${(coverage * 100).round()}%（需 ≥80%），在编辑器把高频人物补进 NPC 池后再试玩',
        ),
      ],
    );
    await (db.update(db.worldDrafts)..where((d) => d.id.equals(draftId)))
        .write(WorldDraftsCompanion(
      quality: Value(jsonEncode(patched.toJson())),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  // ---- 实体审阅（世界创造与导入 §4.3：保留 / 合并 / 删除，采纳率可统计） ----

  /// 归并后的实体列表（审阅页数据源）
  Future<List<ImportEntity>> entities(String jobId) async {
    final row = await _row(jobId);
    if (row == null) throw EngineException(EngineCode.notFound, '任务不存在');
    if (row.entities == null) return const [];
    try {
      return asListOfMaps<ImportEntity>(
          jsonDecode(row.entities!), ImportEntity.fromJson);
    } catch (_) {
      return const [];
    }
  }

  /// 审阅操作：removeKeys 删除实体；mergeInto 把来源实体并入目标（别名/属性/frequency）
  /// 返回更新后的列表。采纳率 = 现存实体数 / entitiesTotal（本地可统计）
  Future<List<ImportEntity>> updateEntities(
    String jobId, {
    List<String> removeKeys = const [],
    Map<String, String> mergeInto = const {},
  }) async {
    final row = await _row(jobId);
    if (row == null) throw EngineException(EngineCode.notFound, '任务不存在');
    if (row.stage != 'review') {
      throw EngineException(EngineCode.stateInvalid, '任务完成后才能审阅实体');
    }
    var list = await entities(jobId);
    final byKey = {for (final e in list) e.key: e};
    // 合并：来源的频次/别名/属性并入目标，来源移除
    for (final entry in mergeInto.entries) {
      final source = byKey[entry.key];
      final target = byKey[entry.value];
      if (source == null || target == null || source == target) continue;
      target.frequency += source.frequency;
      target.aliases.add(source.key);
      target.aliases.addAll(source.aliases);
      source.attributes
          .forEach((k, v) => target.attributes.putIfAbsent(k, () => v));
      byKey.remove(entry.key);
    }
    for (final k in removeKeys) {
      byKey.remove(k);
    }
    list = byKey.values.toList()
      ..sort((a, b) => b.frequency.compareTo(a.frequency));
    await _patch(jobId, ImportJobsCompanion(
      entities: Value(jsonEncode(list.map((e) => e.toJson()).toList())),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
    return list;
  }

  /// 用（审阅后的）实体重新合成圣经：仅当草稿仍在 draft 状态可用；
  /// 已在 review 的世界请走编辑器 save。
  /// [fidelity] 传入时换档重合成（标准/忠实会重建全书摘要素材，忠实档多一次压缩调用）
  Future<ImportJobView> regenerate(String jobId,
      {ImportFidelity? fidelity}) async {
    final row = await _row(jobId);
    if (row == null) throw EngineException(EngineCode.notFound, '任务不存在');
    if (row.draftId == null) {
      throw EngineException(EngineCode.stateInvalid, '任务没有关联草稿');
    }
    final draft = await drafts.get(row.draftId!);
    if (draft == null || draft.status != DraftStatus.draft) {
      throw EngineException(EngineCode.stateInvalid,
          '世界已进入审阅，请在编辑器里修改；需要重跑导入请删除草稿后重新导入');
    }
    final list = await entities(jobId);
    if (list.isEmpty) {
      throw EngineException(EngineCode.draftIncomplete, '实体列表为空');
    }
    final eff = fidelity ?? ImportFidelity.fromIndex(row.fidelity);
    await _patch(jobId, ImportJobsCompanion(
      stage: const Value('merging'),
      error: const Value(null),
      fidelity: Value(eff.index),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
    unawaited(_composeFromEntities(jobId, row.draftId!, list, eff));
    return _view((await _row(jobId))!);
  }

  Future<void> _composeFromEntities(
      String jobId, String draftId, List<ImportEntity> entities,
      ImportFidelity fidelity) async {
    try {
      // 换档/重生成需要全书素材：从 import_chunks 重建分块摘要与关系/时间线，
      // 实体用审阅后的列表；关系端点限定在现存实体内
      final parts = (await (db.select(db.importChunks)
                ..where((c) => c.jobId.equals(jobId))
                ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
              .get())
          .map((c) => ChunkExtraction.fromJson(jsonDecode(c.payload)))
          .toList();
      final fullMerge = mergeExtractions(parts);
      final keys = {for (final e in entities) e.key};
      final relations = fullMerge.relations
          .where((r) => keys.contains(r.from) && keys.contains(r.to))
          .toList();
      final summaries =
          parts.map((p) => p.summary).where((s) => s.isNotEmpty).toList();
      List<String>? arcs;
      if (fidelity == ImportFidelity.faithful && summaries.length > 16) {
        await _patch(jobId, ImportJobsCompanion(
          stage: const Value('compressing'),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
        arcs = await _compressArcs(summaries);
      }
      final digest =
          _digestFor(fidelity, (entities: entities, relations: relations, timeline: fullMerge.timeline), summaries, arcs);
      await drafts.generateFromMaterial(
        draftId,
        ip.buildImportCoreUser(
          entities: digest.entities,
          relations: digest.relations,
          timeline: digest.timeline,
          chunkSummaries: digest.chunkSummaries,
          arcSummaries: digest.arcs,
        ),
      );
      await _applyCoverageGate(draftId, entities);
      final job = await _row(jobId);
      await _patch(jobId, ImportJobsCompanion(
        stage: const Value('review'),
        error: const Value(null),
        stats: Value(ImportStats(
          chapters: ImportStats.tryDecode(job?.stats)?.chapters ?? 0,
          chunks: job?.total ?? 0,
          entities: entities.length,
          relations: relations.length,
        ).encode()),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));
    } on EngineException catch (e) {
      await _fail(jobId, '${e.code.wireName}: ${e.message}');
    } catch (e) {
      await _fail(jobId, 'IMPORT_FAILED: $e');
    }
  }

  // ---- 内部 ----

  Future<({List<NovelChunk> chunks, int chapters})> _decodeAndChunk(
          List<int> bytes) =>
      Isolate.run(() => decodeAndChunk(bytes));

  /// 逐块推进 done/progress
  Future<void> _bumpDone(String jobId, int done) async {
    final row = await _row(jobId);
    if (row == null) return;
    final newDone = done > row.done ? done : row.done;
    await _patch(jobId, ImportJobsCompanion(
      done: Value(newDone),
      progress: Value(row.total <= 0 ? 0 : newDone / row.total),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  Future<void> _fail(String jobId, String message) async {
    await _patch(jobId, ImportJobsCompanion(
      stage: const Value('failed'),
      error: Value(message),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  Future<void> _linkDraft(String draftId, String jobId) async {
    await (db.update(db.worldDrafts)..where((d) => d.id.equals(draftId)))
        .write(WorldDraftsCompanion(
      importJobId: Value(jobId),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  Future<ImportJob?> _row(String jobId) => (db.select(db.importJobs)
        ..where((j) => j.id.equals(jobId)))
      .getSingleOrNull();

  Future<void> _patch(String jobId, ImportJobsCompanion patch) =>
      (db.update(db.importJobs)..where((j) => j.id.equals(jobId))).write(patch);

  ImportJobView _view(ImportJob row) => ImportJobView(
        id: row.id,
        draftId: row.draftId,
        stage: row.stage,
        done: row.done,
        total: row.total,
        stats: ImportStats.tryDecode(row.stats),
        error: row.error,
        sourcePath: row.sourcePath,
        updatedAt: row.updatedAt,
        fidelity: ImportFidelity.fromIndex(row.fidelity),
        entitiesTotal: row.entitiesTotal,
      );
}
