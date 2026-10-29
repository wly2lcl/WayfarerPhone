import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:contracts/contracts.dart';
import 'package:drift/drift.dart';

import 'data/app_db.dart';
import 'data/flags.dart';
import 'data/runs_dao.dart';
import 'errors.dart';
import 'library/library_service.dart';
import 'llm/gateway.dart';
import 'llm/settings.dart';
import 'prompts/roles.dart';
import 'usage.dart';
import 'turn/context.dart';
import 'turn/queue.dart';
import 'turn/turn_engine.dart';
import 'world_draft/draft_package.dart';
import 'world_draft/import_service.dart';
import 'world_draft/world_draft_service.dart';

/// 内置世界种子数据（App 从 assets 读入后传入）
class SeedData {
  final WorldBible bible;
  final List<Identity> identities;
  final List<EventSeed> seeds;
  final String? volumeJson;

  SeedData({
    required this.bible,
    required this.identities,
    required this.seeds,
    this.volumeJson,
  });

  String get checksum {
    final norm = (Object? v) => jsonEncode(_sortKeys(v));
    return norm(bible.toJson());
  }

  static Object? _sortKeys(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {
        for (final k in keys) k: _sortKeys(v[k]),
      };
    }
    if (v is List) return v.map(_sortKeys).toList();
    return v;
  }
}

class WorldSummary {
  final String id;
  final String title;
  final String genre;
  final String summary;
  final String source;
  final int version;
  final int identityCount;
  final int updatedAt;

  /// 可否导出 .world（导入来源恒为 false，UI 据此隐藏导出入口）
  final bool exportable;
  WorldSummary({
    required this.id,
    required this.title,
    required this.genre,
    required this.summary,
    required this.source,
    required this.version,
    required this.identityCount,
    required this.updatedAt,
    required this.exportable,
  });
}

class DrawResult {
  final String drawToken;
  final List<Identity> identities;
  final int expiresAt;
  DrawResult({required this.drawToken, required this.identities, required this.expiresAt});
}

class StartResult {
  final String runId;
  final RunState state;
  final String prologue;
  final List<Choice> choices;
  StartResult({required this.runId, required this.state, required this.prologue, required this.choices});
}

class RunView {
  final RunHead head;
  final RunState? state;
  final List<Choice> pendingChoices;
  RunView({required this.head, this.state, required this.pendingChoices});
}

class NarrationEntry {
  final int turnNo;
  final String text;
  final bool isMarker;

  /// 仅卷末标记携带：压缩生成的卷记小结
  final String summary;
  NarrationEntry({
    required this.turnNo,
    required this.text,
    this.isMarker = false,
    this.summary = '',
  });
}

class Archive {
  final String endingId;
  final String title;
  final String epitaph;
  final List<String> tags;
  final List<String> keyChoices;
  final int turns;
  Archive({
    required this.endingId,
    required this.title,
    required this.epitaph,
    required this.tags,
    required this.keyChoices,
    required this.turns,
  });
}

class _SettingsHolder {
  ModelSettings current;
  _SettingsHolder(this.current);
}

/// 引擎门面（API 参考 §2）
class Engine {
  final AppDb db;
  final ModelGateway gateway;
  final KeyStore keyStore;
  late final TurnEngine turns;
  late final WorldDraftService drafts;
  late final ImportService imports;
  late final LibraryService library;
  final SerialQueue _queue = SerialQueue();
  final Map<String, (List<Identity>, int)> _drawTokens = {};
  final Random random;
  final _SettingsHolder _holder;

  /// 应用私有/外部文件根（exports/worlds/imports/diagnostics 的父目录）
  final String filesDir;

  Engine._(this.db, this.gateway, this.keyStore, this._holder,
      {required this.filesDir, Random? random})
      : random = random ?? Random.secure() {
    turns = TurnEngine(db: db, gateway: gateway, queue: _queue, random: random);
    drafts = WorldDraftService(
      db: db,
      gateway: gateway,
      initialState: initialStateFor,
      prologue: prologueFor,
      random: this.random,
    );
    imports = ImportService(
      db: db,
      gateway: gateway,
      drafts: drafts,
      random: this.random,
    );
    library = LibraryService(
      db: db,
      exportsDir: Directory('$filesDir/exports'),
      worldsDir: Directory('$filesDir/worlds'),
      importsDir: Directory('$filesDir/imports'),
      random: this.random,
    );
  }

  static Future<Engine> open({
    required String dbPath,
    required KeyStore keyStore,
    SeedData? builtinSeed,
    void Function(UsageRecord)? onUsage,
    Random? random,
    ModelGateway Function(GatewayConfig config)? gatewayFactory,
    String? filesDir,
  }) async {
    final db = openDbAt(dbPath);
    final rawSettings = await _readSetting(db, 'model_settings');
    final holder = _SettingsHolder(
        ModelSettings.fromJson(rawSettings == null ? null : jsonDecode(rawSettings)));
    final sink = _persistingSink(db, onUsage);
    final gateway = (gatewayFactory ?? ModelGateway.new)(GatewayConfig(
      settings: () => holder.current,
      keyStore: keyStore,
      onUsage: sink,
    ));
    final dir = filesDir ?? _dirname(dbPath);
    final engine = Engine._(db, gateway, keyStore, holder,
        filesDir: dir, random: random);
    if (builtinSeed != null) {
      await engine._installSeed(builtinSeed);
    }
    // 本地埋点 7 天滚动（合规与内容安全 §6：默认 7 天、仅用于排错）
    await engine.purgeExpiredLocalEvents();
    // usage_log 90 天滚动（每次模型请求一条、含失败重试，不治理则无限增长；
    // 设置页统计窗口为近 30 天，90 天上限不影响任何展示）
    await engine.purgeExpiredUsageLog();
    return engine;
  }

  /// 删除 7 天前的 local_events 行；启动时调用，保证表不无限增长
  Future<int> purgeExpiredLocalEvents() {
    final cutoff = DateTime.now().millisecondsSinceEpoch - 7 * 86400000;
    return (db.delete(db.localEvents)
          ..where((e) => e.createdAt.isSmallerOrEqualValue(cutoff)))
        .go();
  }

  /// 删除 [keepDays] 天前的 usage_log 行；启动时自动按 90 天滚动，亦可手动调用
  Future<int> purgeExpiredUsageLog({int keepDays = 90}) {
    final cutoff = DateTime.now().millisecondsSinceEpoch - keepDays * 86400000;
    return (db.delete(db.usageLog)
          ..where((u) => u.createdAt.isSmallerOrEqualValue(cutoff)))
        .go();
  }

  static String _dirname(String path) {
    final i = path.lastIndexOf('/');
    return i <= 0 ? '.' : path.substring(0, i);
  }

  /// 用量先落 usage_log（API 参考 §5.4，仅本地），再交给调用方回调
  static UsageSink _persistingSink(AppDb db, void Function(UsageRecord)? user) {
    return (UsageRecord r) {
      db.into(db.usageLog).insert(UsageLogCompanion.insert(
            runId: Value(r.runId),
            turnNo: Value(r.turnNo),
            role: r.role.name,
            model: r.model,
            tokensIn: r.tokensIn,
            tokensOut: r.tokensOut,
            estimated: Value(r.estimated),
            ms: r.ms,
            firstByteMs: Value(r.firstByteMs),
            ok: Value(r.ok),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ));
      user?.call(r);
    };
  }

  /// 试玩局不进「我的局」也不计入用量统计
  Future<Set<String>> _trialRunIds() async {
    final rows = await (db.select(db.runs)
          ..where((r) => r.isTrial.equals(true)))
        .get();
    return rows.map((r) => r.id).toSet();
  }

  /// 近 N 天用量汇总（观测 §9），设置页展示
  Future<UsageStats> usageStats({int days = 30}) async {
    final since =
        DateTime.now().millisecondsSinceEpoch - days * 86400000;
    final trialIds = await _trialRunIds();
    final rows = (await (db.select(db.usageLog)
              ..where((u) => u.createdAt.isBiggerOrEqualValue(since)))
            .get())
        .where((r) => r.runId == null || !trialIds.contains(r.runId))
        .toList();
    final okRows = rows.where((r) => r.ok).toList();
    final latencies =
        okRows.map((r) => r.firstByteMs ?? r.ms).toList()..sort();
    int? pct(double p) => latencies.isEmpty
        ? null
        : latencies[(p * (latencies.length - 1)).round()];
    final turnKeys = rows
        .where((r) => r.runId != null && r.turnNo != null)
        .map((r) => '${r.runId}:${r.turnNo}')
        .toSet();
    final tokensIn = okRows.fold<int>(0, (a, r) => a + r.tokensIn);
    final tokensOut = okRows.fold<int>(0, (a, r) => a + r.tokensOut);
    return UsageStats(
      days: days,
      requests: rows.length,
      failures: rows.length - okRows.length,
      p50Ms: pct(0.5),
      p95Ms: pct(0.95),
      tokensIn: tokensIn,
      tokensOut: tokensOut,
      turns: turnKeys.length,
      avgTokensPerTurn: turnKeys.isEmpty
          ? 0
          : ((tokensIn + tokensOut) / turnKeys.length).round(),
    );
  }

  ModelSettings get modelSettings => _holder.current;

  static Future<String?> _readSetting(AppDb db, String key) async {
    final row = await (db.select(db.appSettings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> saveModelSettings(ModelSettings s) async {
    _holder.current = s;
    await db.into(db.appSettings).insertOnConflictUpdate(AppSettingsCompanion.insert(
          key: 'model_settings',
          value: jsonEncode(s.toJson()),
        ));
  }

  Future<ModelSettings> loadModelSettings() async {
    final raw = await _readSetting(db, 'model_settings');
    return ModelSettings.fromJson(raw == null ? null : jsonDecode(raw));
  }

  Future<ConnectionReport> testConnection() => gateway.testConnection();

  Future<void> _installSeed(SeedData seed) async {
    final existing = await (db.select(db.worlds)
          ..where((w) => w.id.equals('w_cangwu')))
        .getSingleOrNull();
    if (existing != null) {
      // 存量修正：内置世界随 App 分发，不可导出 .world（世界分享与UGC §2）
      if (existing.source == 'builtin' && existing.exportable) {
        await (db.update(db.worlds)..where((w) => w.id.equals('w_cangwu')))
            .write(const WorldsCompanion(exportable: Value(false)));
      }
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final checksum = seed.checksum;
    await db.transaction(() async {
      await db.into(db.worlds).insert(WorldsCompanion.insert(
            id: 'w_cangwu',
            title: seed.bible.meta.title,
            genre: seed.bible.meta.genre,
            summary: Value(seed.bible.meta.summary),
            source: 'builtin',
            exportable: const Value(false),
            createdAt: now,
            updatedAt: now,
          ));
      await db.into(db.worldVersions).insert(WorldVersionsCompanion.insert(
            id: 'wv_cangwu_v1',
            worldId: 'w_cangwu',
            version: 1,
            bible: jsonEncode(seed.bible.toJson()),
            identities: jsonEncode(seed.identities.map((i) => i.toJson()).toList()),
            seeds: jsonEncode(seed.seeds.map((s) => s.toJson()).toList()),
            checksum: checksum,
            createdAt: now,
          ));
    });
  }

  // ---- worlds ----

  Future<List<WorldSummary>> listWorlds() async {
    final rows = await db.select(db.worlds).get();
    final result = <WorldSummary>[];
    for (final w in rows) {
      final versions = await (db.select(db.worldVersions)
            ..where((v) => v.worldId.equals(w.id)))
          .get();
      final latest = versions.isEmpty
          ? null
          : versions.reduce((a, b) => a.version > b.version ? a : b);
      final count = latest == null
          ? 0
          : asList<Identity>(jsonDecode(latest.identities), Identity.fromJson).length;
      result.add(WorldSummary(
        id: w.id,
        title: w.title,
        genre: w.genre,
        summary: w.summary ?? '',
        source: w.source,
        version: latest?.version ?? 0,
        identityCount: count,
        updatedAt: w.updatedAt,
        exportable: w.exportable,
      ));
    }
    return result;
  }

  Future<WorldBible> loadBible(String worldId, int version) async {
    final v = await (db.select(db.worldVersions)
          ..where((x) => x.worldId.equals(worldId) & x.version.equals(version)))
        .getSingleOrNull();
    if (v == null) throw EngineException(EngineCode.notFound, '世界版本不存在');
    return WorldBible.fromJson(jsonDecode(v.bible));
  }

  // ---- runs ----

  Future<DrawResult> draw(String worldId, {int count = 3}) async {
    final worlds = await db.select(db.worlds).get();
    final w = worlds.where((x) => x.id == worldId).firstOrNull;
    if (w == null) throw EngineException(EngineCode.notFound, '世界不存在');
    final versions = await (db.select(db.worldVersions)
          ..where((v) => v.worldId.equals(worldId)))
        .get();
    final latest = versions.reduce((a, b) => a.version > b.version ? a : b);
    final pool = asList<Identity>(jsonDecode(latest.identities), Identity.fromJson);

    final weights = {'common': 70, 'rare': 25, 'unique': 5};
    final picked = <Identity>{};
    var guard = 0;
    while (picked.length < count && guard++ < 200) {
      final total = pool.fold<int>(0, (acc, i) => acc + weights[i.rarity.name]!);
      var roll = random.nextInt(total);
      for (final i in pool) {
        roll -= weights[i.rarity.name]!;
        if (roll < 0) {
          if (!picked.contains(i)) picked.add(i);
          break;
        }
      }
    }
    final token = 'dt_${random.nextInt(0xFFFFFFFF).toRadixString(16)}';
    _drawTokens[token] = (
      picked.toList(),
      DateTime.now().millisecondsSinceEpoch + 5 * 60 * 1000,
    );
    return DrawResult(
      drawToken: token,
      identities: picked.toList(),
      expiresAt: _drawTokens[token]!.$2,
    );
  }

  Future<StartResult> create({
    required String worldId,
    required String identityId,
    required String drawToken,
  }) async {
    if (!gateway.config.settings().configured) {
      throw EngineException(EngineCode.modelNotConfigured, '先到设置页配置模型', canRetry: true);
    }
    final entry = _drawTokens[drawToken];
    if (entry == null || entry.$2 < DateTime.now().millisecondsSinceEpoch) {
      throw EngineException(EngineCode.notFound, '抽取令牌已过期，请重新抽取', canRetry: true);
    }
    final identity = entry.$1.where((i) => i.id == identityId).firstOrNull;
    if (identity == null) throw EngineException(EngineCode.notFound, '身份不在本次抽取中');

    final versions = await (db.select(db.worldVersions)
          ..where((v) => v.worldId.equals(worldId)))
        .get();
    final latest = versions.reduce((a, b) => a.version > b.version ? a : b);
    final bible = WorldBible.fromJson(jsonDecode(latest.bible));

    final state = initialStateFor(identity, bible);
    final runId = 'r_${random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0')}';
    await RunsDao(db).createRun(
      runId: runId,
      worldId: worldId,
      worldVersion: latest.version,
      identityId: identityId,
      initialState: state,
    );
    db.into(db.localEvents).insert(LocalEventsCompanion.insert(
          name: 'run_created',
          runId: Value(runId),
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));

    // 序章：一次性生成
    final prologue = await prologueFor(bible, identity, state, runId);

    final choices = [
      Choice(id: 't0c1', label: '先把眼前的事应付过去', intent: '应付眼前事务，观察环境', risk: Risk.low),
      Choice(id: 't0c2', label: '找一个能打听消息的人', intent: '寻找信息源打听处境', risk: Risk.low),
      Choice(id: 't0c3', label: '直接去查那件最要紧的事', intent: '直奔长期目标调查', risk: Risk.high),
    ];

    // 序章事件落库
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      await db.into(db.runEvents).insert(RunEventsCompanion.insert(
            runId: runId,
            seq: 1,
            turnNo: 0,
            type: 'narration',
            payload: jsonEncode({'text': prologue}),
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
    _drawTokens.remove(drawToken);
    return StartResult(runId: runId, state: state, prologue: prologue, choices: choices);
  }

  RunState initialStateFor(Identity identity, WorldBible bible) {
    final tier = bible.tierByStage(1)!;
    final statMod = -(identity.difficulty - 1) * 5;
    final state = RunState(
      schemaVersion: 1,
      meta: RunMeta(
        chapter: 1,
        turnNo: 0,
        gameTime: identity.start.gameTime,
        age: identity.start.age,
        lifespan: tier.lifespan,
      ),
      character: RunCharacter(
        name: identity.name,
        identityId: identity.id,
        realm: Realm(stage: 1, stageName: tier.name, layer: 1, progress: 0),
        stats: Stats(
          vitality: (50 + statMod).clamp(0, 100),
          spirit: (50 + statMod).clamp(0, 100),
          body: (50 + statMod).clamp(0, 100),
        ),
        resources: Resources(
          spiritStones: identity.resources['spiritStones'] ?? 0,
          pills: Map.fromEntries(
            identity.resources.entries.where((e) => e.key != 'spiritStones'),
          ),
        ),
        conditions: [],
      ),
      location: LocationRef(regionId: identity.start.regionId, placeId: identity.start.placeId),
      relations: {
        for (final r in identity.relations)
          r.npcId: Relation(
            affinity: r.affinity,
            trust: r.affinity >= 40 ? 60 : (r.affinity >= 0 ? 30 : 10),
            status: r.affinity >= 40
                ? RelationStatus.xinRen
                : r.affinity >= 0
                    ? RelationStatus.xiangShi
                    : RelationStatus.diYi,
          ),
      },
      inventory: [],
      knowledge: ['${identity.situation}'],
      threads: [],
      flags: {},
      reputation: {},
    );
    return state;
  }

  String _systemFor(WorldBible bible, Identity identity) =>
      '${ironLawSection(bible)}\n\n${worldSection(bible)}\n\n${identitySection(identity)}';

  /// 序章一次性生成（正式局与试玩局共用）
  Future<String> prologueFor(
      WorldBible bible, Identity identity, RunState state, String runId) async {
    final system = _systemFor(bible, identity);
    final prologuePrompt = '''
写本局序章。玩家身份：${identity.name}。${identity.situation}
起始地点：${state.location.placeId}，时间 ${state.meta.gameTime}。
要求：200–300 字；第二人称；交代处境、目标与枷锁；结尾不替玩家做决定；
只输出正文。''';
    final res = await gateway.complete(GatewayRequest(
      role: GatewayRole.narrator,
      system: system,
      user: assembleUser(sections: [prologuePrompt], systemTokens: estTokens(system)),
      temperature: 0.85,
      maxTokens: 700,
      runId: runId,
      turnNo: 0,
    ));
    return res.text.length > 1200 ? res.text.substring(0, 1200) : res.text;
  }

  Future<List<RunHead>> listRuns() async {
    final rows = await (db.select(db.runs)
          ..where((r) => r.isTrial.equals(false))
          ..orderBy([(r) => OrderingTerm.desc(r.updatedAt)]))
        .get();
    final sources = <String, String>{
      for (final w in await db.select(db.worlds).get()) w.id: w.source,
    };
    // 终局标题只对已落幕局解析：仅加载涉及的世界版本并各解码一次，
    // 避免为列表全表解码所有版本 bible（N+1，库越大列表越慢）
    final endingTitles = <String, String>{};
    final needed = <String, Set<int>>{};
    for (final r in rows) {
      if (r.endingId != null) {
        needed.putIfAbsent(r.worldId, () => {}).add(r.worldVersion);
      }
    }
    for (final entry in needed.entries) {
      final versionRows = await (db.select(db.worldVersions)
            ..where((v) =>
                v.worldId.equals(entry.key) & v.version.isIn(entry.value)))
          .get();
      for (final v in versionRows) {
        final bible = WorldBible.fromJson(jsonDecode(v.bible));
        for (final e in bible.endgame) {
          endingTitles['${v.worldId}@${v.version}@${e.id}'] = e.title;
        }
      }
    }

    return rows
        .map((r) => RunHead(
              id: r.id,
              worldId: r.worldId,
              worldVersion: r.worldVersion,
              identityId: r.identityId,
              status: r.status,
              chapter: r.chapter,
              turnNo: r.turnNo,
              headSnapshotId: r.headSnapshotId,
              endingId: r.endingId,
              endingTitle: r.endingId == null
                  ? null
                  : endingTitles['${r.worldId}@${r.worldVersion}@${r.endingId}'],
              // 存档包可导出 = 非 import 来源（builtin 豁免开放，世界分享与UGC §4）
              exportable: (sources[r.worldId] ?? 'created') != 'import',
            ))
        .toList();
  }

  Future<RunView> getRun(String runId) async {
    final head = await RunsDao(db).loadHead(runId);
    if (head == null) throw EngineException(EngineCode.notFound, '局不存在');
    final state = await RunsDao(db).loadState(runId);
    final choices = await _pendingChoices(runId);
    return RunView(head: head, state: state, pendingChoices: choices);
  }

  /// 历史叙事正文（序章 + 各回合 + 卷末分幅，seq 升序），离线可读
  Future<List<NarrationEntry>> listNarration(String runId) async {
    final rows = await (db.select(db.runEvents)
          ..where((e) =>
              e.runId.equals(runId) &
              e.type.isIn(['narration', 'compact']))
          ..orderBy([(e) => OrderingTerm.asc(e.seq)]))
        .get();
    return [
      for (final r in rows)
        if (r.type == 'compact')
          () {
            final payload = rawMap(jsonDecode(r.payload));
            return NarrationEntry(
              turnNo: r.turnNo,
              text: '第 ${payload['chapter'] ?? '?'} 卷 · 完',
              isMarker: true,
              summary: asSOr(payload['summary'], ''),
            );
          }()
        else
          NarrationEntry(
            turnNo: r.turnNo,
            text: rawMap(jsonDecode(r.payload))['text']?.toString() ?? '',
          ),
    ];
  }

  Future<List<Choice>> _pendingChoices(String runId) async {
    final row = await (db.select(db.runEvents)
          ..where((e) => e.runId.equals(runId) & e.type.equals('choice'))
          ..orderBy([(e) => OrderingTerm.desc(e.seq)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return [];
    final payload = jsonDecode(row.payload);
    return asList<Choice>(rawMap(payload)['options'], Choice.fromJson);
  }

  Future<Archive> archive(String runId) async {
    final head = await RunsDao(db).loadHead(runId);
    if (head == null) throw EngineException(EngineCode.notFound, '局不存在');
    final state = await RunsDao(db).loadState(runId);
    final versions = await (db.select(db.worldVersions)
          ..where((v) => v.worldId.equals(head.worldId) & v.version.equals(head.worldVersion)))
        .getSingleOrNull();
    final bible = versions == null ? null : WorldBible.fromJson(jsonDecode(versions.bible));
    final events = await (db.select(db.runEvents)
          ..where((e) => e.runId.equals(runId) & e.type.equals('choice'))
          ..orderBy([(e) => OrderingTerm.asc(e.seq)]))
        .get();
    final keyChoices = <String>[];
    for (final e in events) {
      final p = jsonDecode(e.payload);
      final options = asList<Choice>(rawMap(p)['options'], Choice.fromJson);
      if (options.isNotEmpty) keyChoices.add(options.first.label);
    }
    final ending = head.endingId == null
        ? null
        : bible?.endgame.where((e) => e.id == head.endingId).firstOrNull;
    final epitaph = (ending?.epitaphTemplate ?? '{name}，{realm}，走完了这一程。')
        .replaceAll('{name}', state?.character.name ?? '')
        .replaceAll('{age}', '${state?.meta.age ?? 0}')
        .replaceAll('{realm}', state?.character.realm.stageName ?? '');
    return Archive(
      endingId: head.endingId ?? '',
      title: ending?.title ?? '仍在路上',
      epitaph: epitaph,
      tags: [
        state?.character.realm.stageName ?? '',
        '第${head.chapter}卷',
        '${head.turnNo}回合',
      ],
      keyChoices: keyChoices.take(8).toList(),
      turns: head.turnNo,
    );
  }

  Future<String> branch({required String snapshotId}) async {
    final snap = await (db.select(db.runSnapshots)
          ..where((s) => s.id.equals(snapshotId)))
        .getSingleOrNull();
    if (snap == null) throw EngineException(EngineCode.notFound, '快照不存在');
    final sourceRun = await RunsDao(db).loadHead(snap.runId);
    if (sourceRun == null) throw EngineException(EngineCode.notFound, '局不存在');
    final total = await db.select(db.runs).get();
    if (total.length >= 20) {
      throw EngineException(EngineCode.stateInvalid, '本机世界线已达上限');
    }
    final newId = 'r_${random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0')}';
    final state = RunState.fromJson(jsonDecode(snap.state));
    await RunsDao(db).createRun(
      runId: newId,
      worldId: sourceRun.worldId,
      worldVersion: sourceRun.worldVersion,
      identityId: state.character.identityId,
      initialState: state,
      isTrial: sourceRun.isTrial,
      draftId: sourceRun.draftId,
    );
    return newId;
  }

  /// 本局最近的回合快照（分叉候选，新→旧）
  Future<List<SnapshotBrief>> listSnapshots(String runId, {int limit = 12}) =>
      RunsDao(db).listSnapshots(runId, limit: limit);

  /// 删除一局并级联清理其全部从属数据（run_events / run_snapshots / usage_log /
  /// events_fts），避免删局后孤儿行只增不减（数据卫生）
  Future<void> deleteRun(String runId) async {
    await db.transaction(() async {
      await (db.delete(db.runEvents)..where((e) => e.runId.equals(runId))).go();
      await (db.delete(db.runSnapshots)..where((s) => s.runId.equals(runId)))
          .go();
      await (db.delete(db.usageLog)..where((u) => u.runId.equals(runId))).go();
      // events_fts 是裸 SQL FTS5 虚拟表（无 drift 表对象），走 customStatement
      await db.customStatement(
          'DELETE FROM events_fts WHERE run_id = ?', [runId]);
      await (db.delete(db.runs)..where((r) => r.id.equals(runId))).go();
    });
  }

  // ---- library / 存档包（M3，世界分享与UGC §9）----

  /// `.run` 存档包导出到 files/exports/（绑定世界为 import 来源时 EXPORT_FORBIDDEN；
  /// builtin 世界存档豁免开放，世界分享与UGC §4）
  Future<ExportedFile> exportRunPack(String runId) => library.exportRunPack(runId);

  /// 导入 `.run` 存档包落地为本机新局；缺对应世界版本 NOT_FOUND，runId 冲突自动改后缀
  Future<RunImportResult> importRunPack(String path) => library.importRunPack(path);

  // ---- assistant ----

  Stream<AssistantEvent> assistant(String runId, String question) async* {
    // 青少年模式第四处引擎护栏：随行问答收自由文本，与回合自由输入同口径关闭
    if (await AppFlags(db).teenModeOn()) {
      throw EngineException(EngineCode.stateInvalid, '青少年模式下随行助手不可用');
    }
    final head = await RunsDao(db).loadHead(runId);
    if (head == null) throw EngineException(EngineCode.notFound, '局不存在');
    final state = await RunsDao(db).loadState(runId);
    if (state == null) throw EngineException(EngineCode.notFound, '状态缺失');
    final WorldBible bible;
    try {
      bible = (await loadRunPackage(db, head)).bible;
    } on EngineException {
      throw EngineException(EngineCode.notFound, '世界版本缺失');
    }
    // 随行模式：只读 knowledge，不注入 NPC 私密面与种子
    final system =
        '${ironLawSection(bible)}\n\n${buildCompanionPrompt(knowledge: state.knowledge.join('；'), stateSummary: stateSummary(state), recentTurns: '', question: question)}';
    try {
      await for (final delta in gateway.stream(GatewayRequest(
        role: GatewayRole.companion,
        system: system,
        user: question,
        temperature: 0.6,
        maxTokens: 400,
      ))) {
        yield AssistantDelta(delta);
      }
      yield AssistantEnd(0, 0);
    } on EngineException {
      yield AssistantDelta(companionFallback);
      yield AssistantEnd(0, 0);
    }
  }

  // ---- usage ----

  Future<Map<String, Object?>> usageSummary({int? from, int? to}) async {
    final query = db.select(db.usageLog);
    if (from != null) {
      query.where((u) => u.createdAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((u) => u.createdAt.isSmallerOrEqualValue(to));
    }
    final trialIds = await _trialRunIds();
    // 试玩局排除下推到 SQL（isNotIn），避免全表载入内存再过滤；
    // run_id 为 NULL 的探活行须显式保留（SQL 中 NULL NOT IN 结果为 NULL 会被滤掉）
    if (trialIds.isNotEmpty) {
      query.where((u) => u.runId.isNull() | u.runId.isNotIn(trialIds));
    }
    final rows = await query.get();
    var turns = 0, tokensIn = 0, tokensOut = 0, failures = 0;
    final byRole = <String, List<int>>{};
    for (final r in rows) {
      if (r.role == 'director' && r.ok) turns++;
      tokensIn += r.tokensIn;
      tokensOut += r.tokensOut;
      if (!r.ok) failures++;
      final agg = byRole.putIfAbsent(r.role, () => [0, 0, 0]);
      agg[0]++;
      agg[1] += r.tokensIn;
      agg[2] += r.tokensOut;
    }
    return {
      'turns': turns,
      'tokensIn': tokensIn,
      'tokensOut': tokensOut,
      'failures': failures,
      'byRole': byRole,
    };
  }

  // ---- feedback（合规与内容安全 §3.3：本地记录，不联网上报）----

  /// 写入一条本地反馈/举报记录。category 用「举报/反馈/错误报告」等短标签。
  Future<void> submitFeedback({
    String? runId,
    required String category,
    required String detail,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.feedbackRecords).insert(FeedbackRecordsCompanion.insert(
          id: 'fb_${now.toRadixString(36)}_${random.nextInt(0xFFF).toRadixString(36)}',
          category: category,
          detail: detail,
          runId: Value(runId),
          createdAt: now,
        ));
  }

  /// 读取本地反馈记录（新→旧），供设置页展示与随诊断包导出
  Future<List<FeedbackRecord>> listFeedback({int limit = 50}) async {
    return (db.select(db.feedbackRecords)
          ..orderBy([(f) => OrderingTerm.desc(f.createdAt)])
          ..limit(limit))
        .get();
  }

  // ---- 本机应用开关（年龄门 / 青少年模式，合规与内容安全 §5）----

  Future<String?> readAppSetting(String key) => AppFlags(db).read(key);

  Future<void> writeAppSetting(String key, String value) =>
      AppFlags(db).write(key, value);

  Future<bool> isTeenMode() => AppFlags(db).teenModeOn();

  Future<void> setTeenMode(bool on) =>
      AppFlags(db).write(AppFlags.teenMode, on ? '1' : '0');

  // ---- 诊断包（合规与内容安全 §6/§8：用户主动导出、本地文件、脱敏）----

  /// 导出本地诊断包（JSON）。含模型配置（不含 Key，Key 只在系统安全存储）、
  /// 开关状态、结构与计数、用量统计、反馈记录与近 7 天埋点；
  /// **不含**叙事正文（run_events payload）、状态快照与世界圣经内容。
  /// 返回文件路径，由 UI 经系统分享面板发出。
  Future<String> exportDiagnostics({String? outPath}) async {
    final now = DateTime.now();
    final flags = AppFlags(db);

    Future<int> countOf(dynamic table) async {
      final exp = countAll();
      final q = db.selectOnly(table)..addColumns([exp]);
      return q.map((row) => row.read(exp) ?? 0).getSingle();
    }

    final counts = <String, Object?>{
      'worlds': await countOf(db.worlds),
      'worldVersions': await countOf(db.worldVersions),
      'runs': await countOf(db.runs),
      'snapshots': await countOf(db.runSnapshots),
      'events': await countOf(db.runEvents),
      'usageLog': await countOf(db.usageLog),
      'drafts': await countOf(db.worldDrafts),
      'importJobs': await countOf(db.importJobs),
      'feedbackRecords': await countOf(db.feedbackRecords),
    };

    final since7d = now.millisecondsSinceEpoch - 7 * 86400000;
    final events = await (db.select(db.localEvents)
          ..where((e) => e.createdAt.isBiggerOrEqualValue(since7d))
          ..orderBy([(e) => OrderingTerm.desc(e.createdAt)])
          ..limit(200))
        .get();

    final feedback = await listFeedback(limit: 200);
    final payload = <String, Object?>{
      'kind': 'wayfarer_diagnostics',
      'version': 1,
      'generatedAt': now.toIso8601String(),
      'schemaVersion': db.schemaVersion,
      // Key 不入包：只存 iOS Keychain / Android Keystore，从不落 app_settings
      'settings': modelSettings.toJson(),
      'flags': {
        'ageGate': await flags.read(AppFlags.ageGate),
        'teenMode': await flags.read(AppFlags.teenMode) == '1',
      },
      'counts': counts,
      'usage30d': (await usageStats(days: 30)).toJson(),
      'usageSummary': await usageSummary(),
      'feedback': [
        for (final f in feedback)
          {
            'id': f.id,
            'runId': f.runId,
            'category': f.category,
            'detail': f.detail,
            'status': f.status,
            'createdAt': f.createdAt,
          },
      ],
      'events7d': [
        for (final e in events)
          {'name': e.name, 'props': e.props, 'createdAt': e.createdAt},
      ],
    };

    late final String path;
    if (outPath != null) {
      path = outPath;
    } else {
      final dir = Directory('$filesDir/diagnostics');
      await dir.create(recursive: true);
      path = '${dir.path}/wf_diagnostics_${now.millisecondsSinceEpoch}.json';
    }
    await File(path).writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    // 诊断文件默认只保留最近 5 份，更早的随手清理（文件含反馈明细，减少留存面）
    await _pruneDiagnostics(keep: 5);
    return path;
  }

  /// 清除已生成的诊断文件；`keep` 保留最近 N 份（按文件名时间戳排序），0 表示全清。
  /// 返回删除的文件数。诊断目录不存在时返回 0。
  Future<int> clearDiagnostics({int keep = 0}) => _pruneDiagnostics(keep: keep);

  Future<int> _pruneDiagnostics({required int keep}) async {
    final dir = Directory('$filesDir/diagnostics');
    if (!dir.existsSync()) return 0;
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // 文件名含毫秒时间戳，倒序即最新在前
    var removed = 0;
    for (final f in files.skip(keep)) {
      await f.delete();
      removed++;
    }
    return removed;
  }

  Future<void> close() => db.close();
}
