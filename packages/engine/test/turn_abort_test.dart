// 停止生成（取消传播）单测：订阅 cancel 后引擎须中止管线——
// 不落库、turnNo 不变、同一 expectedTurn 可重新提交（不报 TURN_CONFLICT）。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '../test/helpers.dart';

void main() {
  late AppDb db;
  late SlowNarratorGateway gateway;

  setUp(() async {
    db = openDbInMemory();
    gateway = SlowNarratorGateway();
    final bible = loadBible();
    final identities = asList<Identity>(
        jsonDecode(File('$kSeedDir/identities.json').readAsStringSync()),
        Identity.fromJson);
    final seeds = asList<EventSeed>(
        jsonDecode(File('$kSeedDir/seeds.json').readAsStringSync()),
        EventSeed.fromJson);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.worlds).insert(WorldsCompanion.insert(
          id: 'w_cangwu',
          title: bible.meta.title,
          genre: bible.meta.genre,
          summary: Value(bible.meta.summary),
          source: 'builtin',
          exportable: const Value(false),
          latestVersion: const Value(1),
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.worldVersions).insert(WorldVersionsCompanion.insert(
          id: 'wv_w_cangwu_v1',
          worldId: 'w_cangwu',
          version: 1,
          bible: jsonEncode(bible.toJson()),
          identities: jsonEncode(identities.map((i) => i.toJson()).toList()),
          seeds: jsonEncode(seeds.map((x) => x.toJson()).toList()),
          checksum: internalWorldChecksum(
              bible.toJson(),
              identities.map((i) => i.toJson()).toList(),
              seeds.map((x) => x.toJson()).toList()),
          createdAt: now,
        ));
    final state = makeState();
    await RunsDao(db).createRun(
      runId: 'r_abort',
      worldId: 'w_cangwu',
      worldVersion: 1,
      identityId: state.character.identityId,
      initialState: state,
      isTrial: false,
    );
  });

  test('流式中途 cancel → 不落库、turnNo 不变', () async {
    final engine = TurnEngine(
        db: db, gateway: gateway, queue: SerialQueue(), random: SeqRandom([1]));
    final events = <TurnEvent>[];
    final firstDelta = Completer<void>();
    final sub = engine
        .run('r_abort', expectedTurn: 3, input: FreeTextInput('四处看看'))
        .listen((e) {
      events.add(e);
      if (e is NarrationDelta && !firstDelta.isCompleted) {
        firstDelta.complete();
      }
    });

    await firstDelta.future.timeout(const Duration(seconds: 5));
    await sub.cancel();

    // 管线后续检查点最多再等一个 delta 间隔（500ms），留 1s 余量收尾
    await Future<void>.delayed(const Duration(seconds: 1));

    final head = await RunsDao(db).loadHead('r_abort');
    expect(head!.turnNo, 3, reason: '中止回合不得推进 turnNo');
    final rows = await (db.select(db.runEvents)
          ..where((r) => r.runId.equals('r_abort')))
        .get();
    expect(rows, isEmpty, reason: '中止回合不得写入任何 run_events');
  });

  test('中止后同一 expectedTurn 可重新提交（不报 TURN_CONFLICT）', () async {
    final engine = TurnEngine(
        db: db, gateway: gateway, queue: SerialQueue(), random: SeqRandom([1]));
    final sub = engine
        .run('r_abort', expectedTurn: 3, input: FreeTextInput('四处看看'))
        .listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 800));

    // 换一个在 complete 阶段按剧本抛 MODEL_NETWORK 的网关：
    // 若中止失败导致 turnNo 已被推进，这里会先报 TURN_CONFLICT
    final engine2 = TurnEngine(
        db: db,
        gateway: ThrowingGateway(),
        queue: SerialQueue(),
        random: SeqRandom([1]));
    final events = await engine2
        .run('r_abort', expectedTurn: 3, input: FreeTextInput('四处看看'))
        .toList();
    final err = events.whereType<TurnError>().toList();
    expect(err, hasLength(1));
    expect(err.first.code, EngineCode.modelNetwork.wireName,
        reason: '中止后 turnNo 未变，重新提交应到达模型阶段（此处按剧本失败）');
  });
}

/// complete 一律抛 MODEL_NETWORK 的假网关：探测回合推进到哪一阶段
class ThrowingGateway implements ModelGateway {
  final List<GatewayRole> calls = [];

  @override
  GatewayConfig get config => GatewayConfig(
        settings: () => ModelSettings(
            protocol: LlmProtocol.openai_chat,
            baseUrl: 'http://127.0.0.1:9',
            narrativeModel: 'x',
            smallModel: 'x'),
        keyStore: InMemoryKeyStore(),
      );

  @override
  Future<GatewayResult> complete(GatewayRequest req) async {
    calls.add(req.role);
    throw EngineException(EngineCode.modelNetwork, '测试剧本：模型不可达');
  }

  @override
  Stream<dynamic> stream(GatewayRequest req) async* {
    calls.add(req.role);
    throw EngineException(EngineCode.modelNetwork, '测试剧本：模型不可达');
  }

  @override
  Future<ConnectionReport> testConnection() async {
    throw UnimplementedError();
  }
}

/// 分类/导演正常应答、叙事流慢速吐字的假网关：给 cancel 留出窗口
class SlowNarratorGateway implements ModelGateway {
  final List<GatewayRole> calls = [];

  @override
  GatewayConfig get config => GatewayConfig(
        settings: () => ModelSettings(
            protocol: LlmProtocol.openai_chat,
            baseUrl: 'http://127.0.0.1:9',
            narrativeModel: 'x',
            smallModel: 'x'),
        keyStore: InMemoryKeyStore(),
      );

  @override
  Future<GatewayResult> complete(GatewayRequest req) async {
    calls.add(req.role);
    final text = req.role == GatewayRole.director
        ? '{"beat":"explore","summary":"测试场景","nextChoices":[{"intent":"继续走","risk":"low"}]}'
        : '{"kind":"action","intent":"四处看看"}';
    return GatewayResult(
      text: text,
      tokensIn: 10,
      tokensOut: 10,
      estimated: true,
      ms: 1,
      model: 'fake',
    );
  }

  @override
  Stream<dynamic> stream(GatewayRequest req) async* {
    calls.add(req.role);
    yield '夜风';
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      yield '吹过山道。';
    }
  }

  @override
  Future<ConnectionReport> testConnection() async {
    throw UnimplementedError();
  }
}
