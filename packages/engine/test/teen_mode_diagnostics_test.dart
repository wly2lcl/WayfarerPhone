// WF-LAUNCH-04 未成年人保护 + 诊断包单测（合规与内容安全 §5/§6）
// 覆盖：年龄门/青少年模式开关读写、青少年模式下自由输入/随行助手/导入/导出引擎级护栏、
//       local_events 7 天滚动清理、诊断包导出（含反馈记录、脱敏不含叙事正文）与诊断文件清理。
import 'dart:convert';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '../test/helpers.dart';

void main() {
  group('本机开关：AppFlags 读写往返', () {
    test('read/write 与 isTeenMode/setTeenMode', () async {
      final tmp = await Directory.systemTemp.createTemp('wf_teen_flags');
      final engine = await Engine.open(
        dbPath: '${tmp.path}/app.db',
        keyStore: InMemoryKeyStore(),
        random: SeqRandom([1, 2, 3]),
      );
      addTearDown(() async {
        await engine.close();
        await tmp.delete(recursive: true);
      });
      expect(await engine.readAppSetting(AppFlags.ageGate), isNull,
          reason: '首次启动尚未做年龄确认');
      expect(await engine.isTeenMode(), isFalse);
      await engine.writeAppSetting(AppFlags.ageGate, 'teen');
      expect(await engine.readAppSetting(AppFlags.ageGate), 'teen');
      await engine.setTeenMode(true);
      expect(await engine.isTeenMode(), isTrue);
      await engine.setTeenMode(false);
      expect(await engine.isTeenMode(), isFalse);
    });
  });

  group('青少年模式：回合管线自由输入护栏', () {
    late AppDb db;
    late RecordingGateway gateway;

    setUp(() async {
      db = openDbInMemory();
      gateway = RecordingGateway();
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
        runId: 'r_teen',
        worldId: 'w_cangwu',
        worldVersion: 1,
        identityId: state.character.identityId,
        initialState: state,
        isTrial: false,
      );
      await AppFlags(db).write(AppFlags.teenMode, '1');
    });

    test('自由输入 → STATE_INVALID，不调用网关、不推进回合', () async {
      final engine = TurnEngine(
          db: db, gateway: gateway, queue: SerialQueue(), random: SeqRandom([1]));
      final events = await engine
          .run('r_teen', expectedTurn: 3, input: FreeTextInput('四处看看'))
          .toList();
      final err = events.whereType<TurnError>().toList();
      expect(err, hasLength(1));
      expect(err.first.code, 'STATE_INVALID');
      expect(err.first.message, contains('选项推进'));
      expect(gateway.calls, isEmpty, reason: '护栏必须发生在任何模型请求之前');
      final head = await RunsDao(db).loadHead('r_teen');
      expect(head!.turnNo, 3, reason: '回合数不推进');
    });
  });

  group('青少年模式：导入/导出入口引擎级护栏（TODO WF-LAUNCH-04 验收）', () {
    late Engine engine;
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('wf_teen_gates');
      engine = await Engine.open(
        dbPath: '${tmp.path}/app.db',
        keyStore: InMemoryKeyStore(),
        random: SeqRandom([1, 2, 3]),
      );
      await engine.setTeenMode(true);
    });
    tearDown(() async {
      await engine.close();
      await tmp.delete(recursive: true);
    });

    test('library.export → STATE_INVALID', () {
      expect(
          () => engine.library.export('w_x'),
          throwsA(isA<EngineException>()
              .having((e) => e.code, 'code', EngineCode.stateInvalid)));
    });
    test('library.import → STATE_INVALID（先于文件检查）', () {
      expect(
          () => engine.library.import('/nonexistent.world'),
          throwsA(isA<EngineException>()
              .having((e) => e.code, 'code', EngineCode.stateInvalid)));
    });
    test('library.exportRunPack → STATE_INVALID', () {
      expect(
          () => engine.library.exportRunPack('r_x'),
          throwsA(isA<EngineException>()
              .having((e) => e.code, 'code', EngineCode.stateInvalid)));
    });
    test('library.importRunPack → STATE_INVALID（先于文件检查）', () {
      expect(
          () => engine.library.importRunPack('/nonexistent.run'),
          throwsA(isA<EngineException>()
              .having((e) => e.code, 'code', EngineCode.stateInvalid)));
    });
    test('imports.start（小说导入）→ STATE_INVALID', () {
      expect(
          () => engine.imports.start('/nonexistent.txt'),
          throwsA(isA<EngineException>()
              .having((e) => e.code, 'code', EngineCode.stateInvalid)));
    });
    test('关闭青少年模式后护栏解除（同输入变为 NOT_FOUND）', () async {
      await engine.setTeenMode(false);
      await expectLater(
        engine.library.import('/nonexistent.world'),
        throwsA(isA<EngineException>()
            .having((e) => e.code, 'code', EngineCode.notFound)),
      );
    });
  });

  group('青少年模式：随行助手护栏（自由问答与自由输入同口径）', () {
    late Engine engine;
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('wf_teen_assist');
      engine = await Engine.open(
        dbPath: '${tmp.path}/app.db',
        keyStore: InMemoryKeyStore(),
        random: SeqRandom([1, 2, 3]),
      );
    });
    tearDown(() async {
      await engine.close();
      await tmp.delete(recursive: true);
    });

    test('开启 → STATE_INVALID（先于任何查库与模型请求）', () async {
      await engine.setTeenMode(true);
      await expectLater(
        engine.assistant('r_none', '今晚去哪').toList(),
        throwsA(isA<EngineException>()
            .having((e) => e.code, 'code', EngineCode.stateInvalid)
            .having((e) => e.message, 'message', contains('随行助手'))),
      );
    });

    test('关闭后解除（未知局按原语义返回 NOT_FOUND）', () async {
      await expectLater(
        engine.assistant('r_none', '今晚去哪').toList(),
        throwsA(isA<EngineException>()
            .having((e) => e.code, 'code', EngineCode.notFound)),
      );
    });
  });

  group('local_events 7 天滚动（合规 §6：默认 7 天、仅排错用）', () {
    test('Engine.open 清理 7 天前旧行，保留近期行', () async {
      final tmp = await Directory.systemTemp.createTemp('wf_events_purge');
      final db = openDbAt('${tmp.path}/app.db');
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.localEvents).insert(LocalEventsCompanion.insert(
            name: 'old_event',
            createdAt: now - 8 * 86400000,
          ));
      await db.into(db.localEvents).insert(LocalEventsCompanion.insert(
            name: 'fresh_event',
            createdAt: now - 1 * 86400000,
          ));
      await db.close();

      final engine = await Engine.open(
        dbPath: '${tmp.path}/app.db',
        keyStore: InMemoryKeyStore(),
        random: SeqRandom([1, 2, 3]),
      );
      addTearDown(() async {
        await engine.close();
        await tmp.delete(recursive: true);
      });
      final rows = await engine.db.select(engine.db.localEvents).get();
      expect(rows.map((r) => r.name), ['fresh_event'],
          reason: '8 天前的旧行应在启动时被滚动清理');
      // 公开方法可重复调用（幂等）
      expect(await engine.purgeExpiredLocalEvents(), 0);
    });
  });

  group('诊断文件清理', () {
    test('导出自动保留最近 5 份；clearDiagnostics 可全清', () async {
      final tmp = await Directory.systemTemp.createTemp('wf_diag_prune');
      final engine = await Engine.open(
        dbPath: '${tmp.path}/app.db',
        keyStore: InMemoryKeyStore(),
        random: SeqRandom([1, 2, 3]),
        filesDir: '${tmp.path}/files',
      );
      addTearDown(() async {
        await engine.close();
        await tmp.delete(recursive: true);
      });
      final dir = Directory('${tmp.path}/files/diagnostics');
      for (var i = 0; i < 7; i++) {
        await engine.exportDiagnostics();
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      // 导出内置自动清理：只保留最近 5 份
      expect(dir.listSync().whereType<File>().length, 5,
          reason: '导出第 6/7 份时应顺带清理更早的文件');
      // 手动保留最近 2 份
      expect(await engine.clearDiagnostics(keep: 2), 3);
      expect(dir.listSync().whereType<File>().length, 2);
      // 全清
      expect(await engine.clearDiagnostics(), 2);
      expect(dir.listSync().whereType<File>(), isEmpty);
      // 目录已空/不存在时幂等返回 0
      expect(await engine.clearDiagnostics(), 0);
    });
  });

  group('诊断包导出', () {
    test('JSON 结构完整：反馈记录带入、叙事正文不入包、Key 不入包', () async {
      final tmp = await Directory.systemTemp.createTemp('wf_diag');
      final engine = await Engine.open(
        dbPath: '${tmp.path}/app.db',
        keyStore: InMemoryKeyStore(),
        random: SeqRandom([1, 2, 3]),
        filesDir: '${tmp.path}/files',
      );
      addTearDown(() async {
        await engine.close();
        await tmp.delete(recursive: true);
      });

      await engine.submitFeedback(category: '举报', detail: 'DIAGFB叙事越界样本');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await engine.submitFeedback(category: '反馈', detail: '希望导出更快');
      // 叙事正文：绝不能出现在诊断包里
      await engine.db.into(engine.db.runEvents).insert(RunEventsCompanion.insert(
            runId: 'r_priv',
            seq: 1,
            turnNo: 1,
            type: 'narration',
            payload: jsonEncode({'text': 'TOPSECRET_NARRATIVE_BODY'}),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ));
      // 埋点：应出现在 events7d
      await engine.db.into(engine.db.localEvents).insert(LocalEventsCompanion.insert(
            name: 'turn_send',
            props: const Value('{"source":"choice"}'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ));

      final path = await engine.exportDiagnostics();
      final f = File(path);
      expect(await f.exists(), isTrue, reason: '诊断文件应落在 files/diagnostics 下');
      final j = jsonDecode(await f.readAsString()) as Map<String, Object?>;
      final raw = await f.readAsString();

      expect(j['kind'], 'wayfarer_diagnostics');
      expect(j['version'], 1);
      expect(j['schemaVersion'], engine.db.schemaVersion);
      expect((j['settings'] as Map).isNotEmpty, isTrue);
      expect(raw.contains('apiKey'), isFalse, reason: 'Key 不得入包');
      expect(raw.contains('TOPSECRET_NARRATIVE_BODY'), isFalse,
          reason: '叙事正文不得入包');
      expect(raw.contains('DIAGFB叙事越界样本'), isTrue, reason: '反馈记录必须随诊断包带出');

      final counts = j['counts'] as Map<String, Object?>;
      expect(counts['feedbackRecords'], 2);
      expect(counts['events'], 1);
      final feedback = j['feedback'] as List;
      expect(feedback, hasLength(2));
      expect((feedback.first as Map)['detail'], '希望导出更快');
      final events7d = j['events7d'] as List;
      expect(events7d.map((e) => (e as Map)['name']), contains('turn_send'));
      expect((j['usage30d'] as Map)['requests'], 0);
      expect((j['flags'] as Map)['teenMode'], isFalse);
    });
  });
}

/// 只记录调用、不访问网络的假网关：用于断言「护栏发生在任何模型请求之前」
class RecordingGateway implements ModelGateway {
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
    throw EngineException(EngineCode.modelNetwork, '测试中不应发出请求');
  }

  @override
  Stream<dynamic> stream(GatewayRequest req) async* {
    calls.add(req.role);
    throw EngineException(EngineCode.modelNetwork, '测试中不应发出请求');
  }

  @override
  Future<ConnectionReport> testConnection() async {
    throw UnimplementedError();
  }
}
