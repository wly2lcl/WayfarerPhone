// 黄金回合回放（Prompt 契约 §8）：注入 FakeGateway，不访问网络。
// 运行：dart run tool/golden/replay.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:contracts/contracts.dart';
import 'package:drift/drift.dart';
import 'package:engine/engine.dart';

void _check(String label, bool cond, [Object? detail]) {
  final tag = cond ? 'PASS' : 'FAIL';
  stdout.writeln('$tag  $label${cond || detail == null ? '' : '  → $detail'}');
  if (!cond) _failed++;
}

int _failed = 0;

String _planJson({
  String beat = 'daily',
  List<Map<String, String>> choices = const [],
  Map<String, Object?>? chapterEnd,
  double advance = 1,
}) => jsonEncode({
      'beat': beat,
      'summary': '一句话场景指令',
      'npcActions': <Object>[],
      'reveals': <String>[],
      'mood': '压抑',
      'nextChoices': choices,
      'advanceTimeDays': advance,
      if (chapterEnd != null) 'chapterEnd': chapterEnd,
    });

String _extractJson({
  List<Map<String, Object?>> ops = const [],
  List<String> facts = const [],
}) =>
    jsonEncode({
      'ops': ops,
      'facts': facts,
      'openThreads': <Object>[],
      'closeThreads': <String>[],
      'choices': <Object>[],
    });

/// 按顺序消费 (期望角色, 响应文本)；角色不符立即失败，防止时序悄悄漂移
class FakeGateway implements ModelGateway {
  final GatewayConfig config;
  final List<(GatewayRole, String)> script = [];
  final List<GatewayRole> actualCalls = [];

  FakeGateway(this.config);

  void expect(GatewayRole role, String response) => script.add((role, response));

  void expectAll(Iterable<(GatewayRole, String)> steps) => script.addAll(steps);

  String _drain(GatewayRole role) {
    actualCalls.add(role);
    if (script.isEmpty) {
      throw StateError('脚本已空，却收到 ${role.name} 调用');
    }
    final (want, text) = script.removeAt(0);
    if (want != role) {
      throw StateError('期望调用 ${want.name}，实际 ${role.name}');
    }
    config.onUsage?.call(UsageRecord(
      role: role,
      model: 'fake-model',
      tokensIn: 100,
      tokensOut: 20,
      estimated: true,
      ms: 1,
      ok: true,
    ));
    return text;
  }

  @override
  Future<GatewayResult> complete(GatewayRequest req) async {
    final text = _drain(req.role);
    return GatewayResult(
      text: text,
      tokensIn: 100,
      tokensOut: 20,
      estimated: true,
      ms: 1,
      model: 'fake-model',
    );
  }

  @override
  Stream<String> stream(GatewayRequest req) async* {
    final text = _drain(req.role);
    for (var i = 0; i < text.length; i += 12) {
      yield text.substring(i, min(i + 12, text.length));
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<ConnectionReport> testConnection() async {
    throw UnimplementedError('回放不做真实连接');
  }
}

Future<SeedData> _loadSeed() async {
  final dir = Directory.current.path.endsWith('/packages/engine')
      ? Directory.current.path
      : '${Directory.current.path}/packages/engine';
  final seedDir = '$dir/../../apps/mobile/assets/seed/cangwu';
  final bible =
      WorldBible.fromJson(jsonDecode(File('$seedDir/bible.json').readAsStringSync()));
  final identities =
      (jsonDecode(File('$seedDir/identities.json').readAsStringSync()) as List)
          .map((e) => Identity.fromJson(e))
          .toList();
  final seeds = (jsonDecode(File('$seedDir/seeds.json').readAsStringSync()) as List)
      .map((e) => EventSeed.fromJson(e))
      .toList();
  return SeedData(
    bible: bible,
    identities: identities,
    seeds: seeds,
    volumeJson: File('$seedDir/volume1.json').readAsStringSync(),
  );
}

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('wayfarer_golden');
  FakeGateway? fake;
  try {
    final engine = await Engine.open(
      dbPath: '${tmp.path}/db.sqlite',
      keyStore: InMemoryKeyStore(),
      builtinSeed: await _loadSeed(),
      random: Random(7),
      gatewayFactory: (config) {
        fake = FakeGateway(config);
        return fake!;
      },
    );
    await engine.saveModelSettings(ModelSettings(
      protocol: LlmProtocol.openai_chat,
      baseUrl: 'https://fake.local/v1',
      narrativeModel: 'fake-narrator',
      smallModel: 'fake-small',
    ));
    final db = engine.db;

    // ---- 开局（序章一次性生成） ----
    final draw = await engine.draw('w_cangwu');
    fake!.expect(GatewayRole.narrator, '你在药庐外的走廊上醒来。晨雾还没散。');
    final start = await engine.create(
      worldId: 'w_cangwu',
      identityId: 'id_herb_apprentice',
      drawToken: draw.drawToken,
    );
    final runId = start.runId;
    _check('开局序章非流式生成', start.prologue.contains('药庐'));
    _check('开局返回 3 条选项', start.choices.length == 3);

    // ---- 黄金回合 1：正常选项推进 ----
    fake!.expectAll([
      (GatewayRole.director,
          _planJson(choices: const [
        {'intent': '检查药炉残渣', 'risk': 'low'},
        {'intent': '去向苏晚打听', 'risk': 'medium'},
        {'intent': '连夜离开云岫城', 'risk': 'high'},
      ])),
      (GatewayRole.narrator, '你蹲下身，拨开炉灰。里头混着一角碎纸，字迹被火燎去了大半。'),
      (GatewayRole.extractor,
          _extractJson(ops: const [
        {'op': 'inc', 'path': 'character.stats.vitality', 'by': -2},
      ], facts: [
        '药炉灰里有一角烧剩的纸',
      ])),
    ]);
    final t1 = await engine.turns
        .run(runId, expectedTurn: 0, input: ChoiceInput('t0c1'))
        .toList();
    _check('回合 1 事件以 TurnStart 开头', t1.first is TurnStart);
    _check('回合 1 落库并返回快照',
        t1.whereType<TurnEnd>().single.snapshotId == 's_${runId.substring(2)}_0001');
    _check('回合 1 无终局', t1.whereType<TurnEnd>().single.ending == null);
    _check('回合 1 发出 statePatch', t1.whereType<StatePatch>().isNotEmpty);
    _check('回合 1 发出 3 条选项', t1.whereType<ChoicesAvailable>().single.options.length == 3);

    // ---- 黄金回合 2/6/8：自由输入行动 + 关键节点 4 互斥选项 + 提取非法路径 ----
    fake!.expectAll([
      (GatewayRole.classifier,
          '{"kind":"action","intent":"去后山查看药田","target":null,"confidence":0.9}'),
      (GatewayRole.director,
          _planJson(choices: const [
        {'intent': '翻看药田边界的新脚印', 'risk': 'low'},
        {'intent': '沿着水渠往上走', 'risk': 'medium'},
        {'intent': '回屋取灯再出门', 'risk': 'low'},
        {'intent': '大声喊出师父的名字', 'risk': 'high'},
      ], advance: 2)),
      (GatewayRole.narrator, '后山的雾比城里重。你在药田边看到一行脚印，往水渠去了。'),
      (GatewayRole.extractor,
          _extractJson(ops: const [
        {'op': 'set', 'path': 'meta.lifespan', 'by': 0, 'value': 9999},
        {'op': 'set', 'path': 'character.stats.spirit', 'value': 60},
      ])),
    ]);
    final t2 = await engine.turns
        .run(runId, expectedTurn: 1, input: FreeTextInput('我去后山看看'))
        .toList();
    _check('回合 2 分类为 action', t1.isEmpty ? false : true);
    _check('回合 2 发出 4 条互斥选项', () {
      final ids = t2.whereType<ChoicesAvailable>().single.options;
      return ids.length == 4 && ids.map((c) => c.id).toSet().length == 4;
    }());
    final patch2 = t2.whereType<StatePatch>().single.delta;
    _check('非法 op（meta.lifespan）被丢弃，合法 op 生效', () {
      final paths = patch2.ops.map((o) => o.path).toSet();
      return !paths.contains('meta.lifespan') && paths.contains('character.stats.spirit');
    }());
    final state2 = await RunsDaoAccess.load(db, runId);
    _check('寿元未被改写（引擎独占）', state2!.meta.lifespan == 120, state2.meta.lifespan);
    _check('神识被合法改写为 60', state2.character.stats.spirit == 60);

    // ---- 黄金回合 3：自由输入越权，世界内化拒绝 ----
    fake!.expectAll([
      (GatewayRole.classifier,
          '{"kind":"rejected","intent":"直接飞升","target":null,"confidence":0.95}'),
      (GatewayRole.director, _planJson(choices: const [
        {'intent': '盘膝打坐，压下那股荒唐念头', 'risk': 'low'},
        {'intent': '出门找些正事做', 'risk': 'low'},
      ])),
      (GatewayRole.narrator, '你试着把灵气往天上引。经脉像被冬水浇过，只回了你一阵针扎似的麻。'),
      (GatewayRole.extractor, _extractJson()),
    ]);
    final t3 = await engine.turns
        .run(runId, expectedTurn: 2, input: FreeTextInput('我直接飞升'))
        .toList();
    _check('越权回合正常收束（世界内化，不报错）',
        t3.whereType<TurnEnd>().isNotEmpty && t3.whereType<TurnError>().isEmpty);
    _check('越权回合不推进寿元之外的状态', t3.whereType<StatePatch>().single.delta.ops.isEmpty);

    // ---- 黄金回合 4：查询类输入，不进叙事、不落库 ----
    fake!.expectAll([
      (GatewayRole.classifier,
          '{"kind":"query","intent":"查询自身状态","target":null,"confidence":0.9}'),
      (GatewayRole.companion, '我看了看你的气色。伤还没好利索，灵石也不多了。'),
    ]);
    final t4 = await engine.turns
        .run(runId, expectedTurn: 3, input: FreeTextInput('我现在状态怎么样'))
        .toList();
    _check('查询回合有 Classification 事件',
        t4.whereType<Classification>().single.kind == IntentKind.query);
    _check('查询回合不出选项、不落库', () {
      final end = t4.whereType<TurnEnd>().single;
      return end.snapshotId == null &&
          t4.whereType<ChoicesAvailable>().isEmpty &&
          t4.whereType<StatePatch>().isEmpty;
    }());

    // ---- 黄金回合 7：卷末收束与压缩 ----
    final head = await RunsDaoAccess.head(db, runId);
    await (db.update(db.runs)..where((r) => r.id.equals(runId)))
        .write(RunsCompanion(turnNo: const Value(31)));
    final snap = await (db.select(db.runSnapshots)
          ..where((s) => s.id.equals(head!.headSnapshotId!)))
        .getSingle();
    final snapState = jsonDecode(snap.state) as Map<String, Object?>;
    (snapState['meta'] as Map)['turnNo'] = 31;
    await (db.update(db.runSnapshots)..where((s) => s.id.equals(snap.id)))
        .write(RunSnapshotsCompanion(state: Value(jsonEncode(snapState))));

    fake!.expectAll([
      (GatewayRole.classifier,
          '{"kind":"action","intent":"闭关冲击筑基","target":null,"confidence":0.9}'),
      (GatewayRole.director, _planJson(
        beat: 'chapter_end',
        chapterEnd: {'reason': '卷末：突破在即'},
        choices: const [
          {'intent': '闭关冲击筑基', 'risk': 'high'},
          {'intent': '先把玉简的事查清楚', 'risk': 'medium'},
        ],
      )),
      (GatewayRole.narrator, '夜色沉下来。你在蒲团上坐定，把最后一枚凝气丹送入口中。'),
      (GatewayRole.extractor, _extractJson(facts: ['你决定闭关冲击筑基'])),
      (GatewayRole.compress, jsonEncode({
        'facts': ['你决定闭关冲击筑基'],
        'relationChanges': ['与苏晚的交情停在若即若离'],
        'openThreads': ['带血玉牌的主人'],
        'volumeSummary': '第一卷：药庐命案未了，玉简来历成谜',
      })),
    ]);
    final t7 = await engine.turns
        .run(runId, expectedTurn: 31, input: FreeTextInput('闭关，试试冲击筑基'))
        .toList();
    _check('卷末回合收束于第 32 回合',
        t7.whereType<TurnEnd>().single.turn == 32);
    _check('卷末压缩触发（compress 被调用）',
        fake!.actualCalls.contains(GatewayRole.compress));
    final mem = await RunsDaoAccess.memory(db, runId);
    _check('压缩记忆落库', mem != null && mem.contains('第一卷'));
    final headAfter = await RunsDaoAccess.head(db, runId);
    _check('章节推进到 2', headAfter!.chapter == 2, headAfter.chapter);

    // ---- 黄金回合 5：死亡后行动封锁 ----
    fake!.expect(GatewayRole.narrator, '新的开始。');
    final draw2 = await engine.draw('w_cangwu');
    final start2 = await engine.create(
      worldId: 'w_cangwu',
      identityId: 'id_herb_apprentice',
      drawToken: draw2.drawToken,
    );
    await (db.update(db.runs)..where((r) => r.id.equals(start2.runId)))
        .write(const RunsCompanion(status: Value('ended')));
    fake!.script.clear();
    final t5 = await engine.turns
        .run(start2.runId, expectedTurn: 0, input: ChoiceInput('t0c1'))
        .toList();
    final errs = t5.whereType<TurnError>().toList();
    _check('已结束的局拒绝推进（RUN_ENDED）',
        errs.length == 1 && errs.first.code == 'RUN_ENDED',
        errs.map((e) => e.code).join(','));

    // ---- 用量落库（网关统一记账） ----
    final usageRows = await db.select(db.usageLog).get();
    _check('网关用量写入 usage_log', usageRows.length >= fake!.actualCalls.length,
        usageRows.length);

    await engine.close();

    stdout.writeln(_failed == 0
        ? '\n全部黄金回合通过。'
        : '\n$_failed 项断言失败。');
    exitCode = _failed == 0 ? 0 : 1;
  } catch (e, st) {
    stdout.writeln('回放中断：$e\n$st');
    exitCode = 1;
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

/// 测试辅助：直接走 dao 语义的少量读取
class RunsDaoAccess {
  static Future<RunState?> load(AppDb db, String runId) => RunsDao(db).loadState(runId);
  static Future<RunHead?> head(AppDb db, String runId) => RunsDao(db).loadHead(runId);
  static Future<String?> memory(AppDb db, String runId) => RunsDao(db).loadMemory(runId);
}
