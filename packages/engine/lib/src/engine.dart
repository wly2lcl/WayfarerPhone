import 'dart:convert';
import 'dart:math';

import 'package:contracts/contracts.dart';
import 'package:drift/drift.dart';

import 'data/app_db.dart';
import 'data/runs_dao.dart';
import 'errors.dart';
import 'llm/gateway.dart';
import 'llm/settings.dart';
import 'prompts/roles.dart';
import 'usage.dart';
import 'turn/context.dart';
import 'turn/queue.dart';
import 'turn/turn_engine.dart';

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
  WorldSummary({
    required this.id,
    required this.title,
    required this.genre,
    required this.summary,
    required this.source,
    required this.version,
    required this.identityCount,
    required this.updatedAt,
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
  final SerialQueue _queue = SerialQueue();
  final Map<String, (List<Identity>, int)> _drawTokens = {};
  final Random random;
  final _SettingsHolder _holder;

  Engine._(this.db, this.gateway, this.keyStore, this._holder,
      {Random? random})
      : random = random ?? Random.secure() {
    turns = TurnEngine(db: db, gateway: gateway, queue: _queue, random: random);
  }

  static Future<Engine> open({
    required String dbPath,
    required KeyStore keyStore,
    SeedData? builtinSeed,
    void Function(UsageRecord)? onUsage,
    Random? random,
    ModelGateway Function(GatewayConfig config)? gatewayFactory,
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
    final engine = Engine._(db, gateway, keyStore, holder, random: random);
    if (builtinSeed != null) {
      await engine._installSeed(builtinSeed);
    }
    return engine;
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

  /// 近 N 天用量汇总（观测 §9），设置页展示
  Future<UsageStats> usageStats({int days = 30}) async {
    final since =
        DateTime.now().millisecondsSinceEpoch - days * 86400000;
    final rows = await (db.select(db.usageLog)
          ..where((u) => u.createdAt.isBiggerOrEqualValue(since)))
        .get();
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
    if (existing != null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final checksum = seed.checksum;
    await db.transaction(() async {
      await db.into(db.worlds).insert(WorldsCompanion.insert(
            id: 'w_cangwu',
            title: seed.bible.meta.title,
            genre: seed.bible.meta.genre,
            summary: Value(seed.bible.meta.summary),
            source: 'builtin',
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

    final state = _initialState(identity, bible);
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
    final system = _systemFor(bible, identity);
    final prologuePrompt = '''
写本局序章。玩家身份：${identity.name}。${identity.situation}
起始地点：${state.location.placeId}，时间 ${state.meta.gameTime}。
要求：200–300 字；第二人称；交代处境、目标与枷锁；结尾不替玩家做决定；
只输出正文。''';
    var prologue = '';
    try {
      final res = await gateway.complete(GatewayRequest(
        role: GatewayRole.narrator,
        system: system,
        user: assembleUser(sections: [prologuePrompt], systemTokens: estTokens(system)),
        temperature: 0.85,
        maxTokens: 700,
      ));
      prologue = res.text.length > 1200 ? res.text.substring(0, 1200) : res.text;
    } on EngineException {
      rethrow;
    }

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

  RunState _initialState(Identity identity, WorldBible bible) {
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

  Future<List<RunHead>> listRuns() async {
    final rows = await (db.select(db.runs)
          ..orderBy([(r) => OrderingTerm.desc(r.updatedAt)]))
        .get();
    final versions = await db.select(db.worldVersions).get();
    final bibles = <String, WorldBible?>{};
    WorldBible? bibleOf(String worldId, int version) {
      final key = '$worldId@$version';
      if (!bibles.containsKey(key)) {
        WorldBible? found;
        for (final v in versions) {
          if (v.worldId == worldId && v.version == version) {
            found = WorldBible.fromJson(jsonDecode(v.bible));
            break;
          }
        }
        bibles[key] = found;
      }
      return bibles[key];
    }

    String? titleOf(String worldId, int version, String? endingId) {
      if (endingId == null) return null;
      final bible = bibleOf(worldId, version);
      if (bible == null) return null;
      for (final e in bible.endgame) {
        if (e.id == endingId) return e.title;
      }
      return null;
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
              endingTitle: titleOf(r.worldId, r.worldVersion, r.endingId),
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
    final total = await db.select(db.runs).get();
    if (total.length >= 20) {
      throw EngineException(EngineCode.stateInvalid, '本机世界线已达上限');
    }
    final newId = 'r_${random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0')}';
    final state = RunState.fromJson(jsonDecode(snap.state));
    await RunsDao(db).createRun(
      runId: newId,
      worldId: await _worldIdOf(snap.runId),
      worldVersion: await _worldVersionOf(snap.runId),
      identityId: state.character.identityId,
      initialState: state,
    );
    return newId;
  }

  /// 本局最近的回合快照（分叉候选，新→旧）
  Future<List<SnapshotBrief>> listSnapshots(String runId, {int limit = 12}) =>
      RunsDao(db).listSnapshots(runId, limit: limit);

  Future<String> _worldIdOf(String runId) async =>
      (await RunsDao(db).loadHead(runId))?.worldId ?? 'w_cangwu';

  Future<int> _worldVersionOf(String runId) async =>
      (await RunsDao(db).loadHead(runId))?.worldVersion ?? 1;

  Future<void> deleteRun(String runId) async {
    await (db.delete(db.runs)..where((r) => r.id.equals(runId))).go();
  }

  // ---- assistant ----

  Stream<AssistantEvent> assistant(String runId, String question) async* {
    final head = await RunsDao(db).loadHead(runId);
    if (head == null) throw EngineException(EngineCode.notFound, '局不存在');
    final state = await RunsDao(db).loadState(runId);
    if (state == null) throw EngineException(EngineCode.notFound, '状态缺失');
    final versions = await (db.select(db.worldVersions)
          ..where((v) => v.worldId.equals(head.worldId) & v.version.equals(head.worldVersion)))
        .getSingleOrNull();
    if (versions == null) throw EngineException(EngineCode.notFound, '世界版本缺失');
    final bible = WorldBible.fromJson(jsonDecode(versions.bible));
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

  Future<void> close() => db.close();
}
