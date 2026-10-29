// 数据卫生 + 网关重试单测（2026-10-29 引擎收尾）
// 覆盖：deleteRun 级联清理孤儿数据（run_events/run_snapshots/usage_log/events_fts）、
//       usage_log 90 天滚动（手动 + Engine.open 自动）、usageSummary 试玩排除下推 SQL
//       （含 run_id 为 NULL 的探活行保留）、429 Retry-After 退避与流式重试。
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '../test/helpers.dart';

void main() {
  group('数据卫生：deleteRun 级联清理', () {
    late Engine engine;
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('wf_hygiene_del');
      engine = await Engine.open(
        dbPath: '${tmp.path}/app.db',
        keyStore: InMemoryKeyStore(),
        random: SeqRandom([1, 2, 3]),
      );
      for (final runId in ['r_x', 'r_keep']) {
        await RunsDao(engine.db).createRun(
          runId: runId,
          worldId: 'w_any',
          worldVersion: 1,
          identityId: 'id_x',
          initialState: makeState(),
          isTrial: false,
        );
        await engine.db.into(engine.db.runEvents).insert(
              RunEventsCompanion.insert(
                runId: runId,
                seq: 0,
                turnNo: 1,
                type: 'narration',
                payload: jsonEncode({'text': '正文'}),
                createdAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
        await engine.db.into(engine.db.runSnapshots).insert(
              RunSnapshotsCompanion.insert(
                id: 's_${runId}_1',
                runId: runId,
                turnNo: 1,
                chapter: 1,
                state: '{}',
                createdAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
        await engine.db.into(engine.db.usageLog).insert(
              UsageLogCompanion.insert(
                runId: Value(runId),
                role: 'narrator',
                model: 'm',
                tokensIn: 1,
                tokensOut: 1,
                ms: 1,
                createdAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
        await engine.db.customStatement(
            'INSERT INTO events_fts (run_id, turn_no, text) VALUES (?, ?, ?)',
            [runId, 1, '检索正文']);
      }
    });

    tearDown(() async {
      await engine.close();
      await tmp.delete(recursive: true);
    });

    test('删除一局后四张从属表无孤儿行，他局数据不受影响', () async {
      await engine.deleteRun('r_x');

      Future<int> count(String sql, String runId) async {
        final rows =
            await engine.db.customSelect(sql, variables: [Variable(runId)]).get();
        return rows.first.data['c'] as int;
      }

      expect(await count('SELECT count(*) AS c FROM runs WHERE id = ?', 'r_x'), 0);
      expect(
          await count('SELECT count(*) AS c FROM run_events WHERE run_id = ?', 'r_x'),
          0,
          reason: 'run_events 必须级联清理');
      expect(
          await count(
              'SELECT count(*) AS c FROM run_snapshots WHERE run_id = ?', 'r_x'),
          0,
          reason: 'run_snapshots 必须级联清理');
      expect(
          await count('SELECT count(*) AS c FROM usage_log WHERE run_id = ?', 'r_x'),
          0,
          reason: 'usage_log 必须级联清理');
      expect(
          await count('SELECT count(*) AS c FROM events_fts WHERE run_id = ?', 'r_x'),
          0,
          reason: 'events_fts 必须级联清理');

      // 他局数据完好
      expect(await count('SELECT count(*) AS c FROM runs WHERE id = ?', 'r_keep'), 1);
      expect(
          await count('SELECT count(*) AS c FROM run_events WHERE run_id = ?', 'r_keep'),
          1);
      expect(
          await count('SELECT count(*) AS c FROM events_fts WHERE run_id = ?', 'r_keep'),
          1);
    });
  });

  group('数据卫生：usage_log 90 天滚动', () {
    test('purgeExpiredUsageLog 删旧行留新行，幂等返回 0', () async {
      final tmp = await Directory.systemTemp.createTemp('wf_hygiene_usage');
      final engine = await Engine.open(
        dbPath: '${tmp.path}/app.db',
        keyStore: InMemoryKeyStore(),
        random: SeqRandom([1]),
      );
      addTearDown(() async {
        await engine.close();
        await tmp.delete(recursive: true);
      });
      final now = DateTime.now().millisecondsSinceEpoch;
      Future<void> insertAt(int createdAt) =>
          engine.db.into(engine.db.usageLog).insert(
                UsageLogCompanion.insert(
                  runId: const Value(null),
                  role: 'narrator',
                  model: 'm',
                  tokensIn: 1,
                  tokensOut: 1,
                  ms: 1,
                  createdAt: createdAt,
                ),
              );
      await insertAt(now - 91 * 86400000);
      await insertAt(now - 1 * 86400000);

      expect(await engine.purgeExpiredUsageLog(), 1);
      final left = await engine.db.select(engine.db.usageLog).get();
      expect(left, hasLength(1));
      expect(left.first.createdAt, (now - 1 * 86400000));
      expect(await engine.purgeExpiredUsageLog(), 0, reason: '幂等');
    });

    test('Engine.open 自动执行滚动：旧行被清、新行保留', () async {
      final tmp = await Directory.systemTemp.createTemp('wf_hygiene_open');
      final now = DateTime.now().millisecondsSinceEpoch;
      final engine1 = await Engine.open(
        dbPath: '${tmp.path}/app.db',
        keyStore: InMemoryKeyStore(),
        random: SeqRandom([1]),
      );
      await engine1.db.into(engine1.db.usageLog).insert(
            UsageLogCompanion.insert(
              runId: const Value(null),
              role: 'narrator',
              model: 'm',
              tokensIn: 1,
              tokensOut: 1,
              ms: 1,
              createdAt: now - 120 * 86400000,
            ),
          );
      await engine1.db.into(engine1.db.usageLog).insert(
            UsageLogCompanion.insert(
              runId: const Value(null),
              role: 'narrator',
              model: 'm',
              tokensIn: 1,
              tokensOut: 1,
              ms: 1,
              createdAt: now,
            ),
          );
      await engine1.close();

      final engine2 = await Engine.open(
        dbPath: '${tmp.path}/app.db',
        keyStore: InMemoryKeyStore(),
        random: SeqRandom([1]),
      );
      addTearDown(() async {
        await engine2.close();
        await tmp.delete(recursive: true);
      });
      final rows = await engine2.db.select(engine2.db.usageLog).get();
      expect(rows, hasLength(1), reason: '重启后 90 天前的用量行应被自动清理');
      expect(rows.first.createdAt, now);
    });
  });

  group('数据卫生：usageSummary 试玩排除下推 SQL', () {
    late Engine engine;
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('wf_hygiene_summary');
      engine = await Engine.open(
        dbPath: '${tmp.path}/app.db',
        keyStore: InMemoryKeyStore(),
        random: SeqRandom([1]),
      );
      Future<void> usage(String? runId, {String role = 'narrator', int tokens = 10}) =>
          engine.db.into(engine.db.usageLog).insert(
                UsageLogCompanion.insert(
                  runId: Value(runId),
                  role: role,
                  model: 'm',
                  tokensIn: tokens,
                  tokensOut: 0,
                  ms: 1,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                ),
              );
      await RunsDao(engine.db).createRun(
        runId: 'r_trial',
        worldId: 'w_any',
        worldVersion: 1,
        identityId: 'id_x',
        initialState: makeState(),
        isTrial: true,
      );
      await RunsDao(engine.db).createRun(
        runId: 'r_normal',
        worldId: 'w_any',
        worldVersion: 1,
        identityId: 'id_x',
        initialState: makeState(),
        isTrial: false,
      );
      await usage('r_trial');
      await usage('r_normal');
      await usage(null, tokens: 5); // 探活请求：run_id 为 NULL
    });

    tearDown(() async {
      await engine.close();
      await tmp.delete(recursive: true);
    });

    test('试玩局被排除；NULL run_id 的探活行保留（SQL NULL NOT IN 陷阱）', () async {
      final s = await engine.usageSummary();
      final byRole = s['byRole'] as Map<String, List<int>>;
      // narrator：r_normal(10) + NULL(5) = 2 条 / tokensIn 15；试玩 r_trial 不计入
      expect(byRole['narrator']![0], 2);
      expect(byRole['narrator']![1], 15);
    });
  });

  group('usageStats：正式局叙事请求首字耗时（非点击到首字 E2E）', () {
    late Engine engine;
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('wf_hygiene_stats');
      engine = await Engine.open(
        dbPath: '${tmp.path}/app.db',
        keyStore: InMemoryKeyStore(),
        random: SeqRandom([1]),
      );
      for (final isTrial in [false, true]) {
        await RunsDao(engine.db).createRun(
          runId: isTrial ? 'r_trial' : 'r_normal',
          worldId: 'w_any',
          worldVersion: 1,
          identityId: 'id_x',
          initialState: makeState(),
          isTrial: isTrial,
        );
      }
    });

    tearDown(() async {
      await engine.close();
      await tmp.delete(recursive: true);
    });

    Future<void> usage({
      String? runId = 'r_normal',
      int? turnNo = 1,
      String role = 'narrator',
      int? firstByteMs,
      bool ok = true,
      int daysAgo = 0,
    }) async {
      await engine.db.into(engine.db.usageLog).insert(
            UsageLogCompanion.insert(
              runId: Value(runId),
              turnNo: Value(turnNo),
              role: role,
              model: 'm',
              tokensIn: 10,
              tokensOut: 5,
              ms: 100000,
              firstByteMs: Value(firstByteMs),
              ok: Value(ok),
              createdAt:
                  DateTime.now().millisecondsSinceEpoch - daysAgo * 86400000,
            ),
          );
    }

    Future<void> insertExcludedLatencies() async {
      for (final role in ['classifier', 'director', 'extractor', 'companion']) {
        await usage(role: role, firstByteMs: 1);
      }
      // 即便探活使用 narrator 且有首字，也不能算作正式叙事。
      await usage(runId: null, turnNo: null, firstByteMs: 90000);
      await usage(turnNo: 5, ok: false, firstByteMs: 80000);
      await usage(turnNo: 6); // 无首字，不能用总耗时 ms 回填。
      await usage(runId: 'r_trial', firstByteMs: 70000);
      await usage(firstByteMs: 60000, daysAgo: 31);
    }

    test('混合请求不污染首字分位数，其他统计保留原口径', () async {
      // 故意乱序，确保按首字耗时排序；ms 与 firstByteMs 明显不同。
      final firstBytes = [500, 100, 300, 200, 400];
      for (var i = 0; i < firstBytes.length; i++) {
        await usage(turnNo: i, firstByteMs: firstBytes[i]);
      }
      await insertExcludedLatencies();

      final s = await engine.usageStats();
      expect(s.p50Ms, 300);
      expect(s.p95Ms, 500);
      expect(s.days, 30);
      // 五条正式叙事 + 四种其他角色 + 探活 + 失败 + 无首字。
      expect(s.requests, 12);
      expect(s.failures, 1);
      expect(s.tokensIn, 110, reason: '仅成功请求计入 tokens，仍包含其他角色和探活');
      expect(s.tokensOut, 55);
      expect(s.turns, 7, reason: '按 runId/turnNo 去重，失败和无首字回合仍计入');
      expect(s.avgTokensPerTurn, 24);
    });

    test('有请求但无有效叙事首字样本时分位数为 null', () async {
      await insertExcludedLatencies();

      final s = await engine.usageStats();
      expect(s.requests, 7);
      expect(s.failures, 1);
      expect(s.p50Ms, isNull);
      expect(s.p95Ms, isNull);
    });

    test('无请求时分位数为 null', () async {
      final s = await engine.usageStats();
      expect(s.requests, 0);
      expect(s.p50Ms, isNull);
      expect(s.p95Ms, isNull);
      expect(s.tokensIn, 0);
      expect(s.tokensOut, 0);
      expect(s.turns, 0);
      expect(s.avgTokensPerTurn, 0);
    });
  });

  group('数据卫生：世界级联删除也清理 usage_log', () {
    test('library.delete(worldId) 后该世界各局的用量行清零', () async {
      final tmp = await Directory.systemTemp.createTemp('wf_hygiene_world');
      final engine = await Engine.open(
        dbPath: '${tmp.path}/app.db',
        keyStore: InMemoryKeyStore(),
        random: SeqRandom([1]),
      );
      addTearDown(() async {
        await engine.close();
        await tmp.delete(recursive: true);
      });
      final now = DateTime.now().millisecondsSinceEpoch;
      await engine.db.into(engine.db.worlds).insert(WorldsCompanion.insert(
            id: 'w_x',
            title: '测试世界',
            genre: 'g',
            source: 'created',
            latestVersion: const Value(1),
            createdAt: now,
            updatedAt: now,
          ));
      await RunsDao(engine.db).createRun(
        runId: 'r_in_world',
        worldId: 'w_x',
        worldVersion: 1,
        identityId: 'id_x',
        initialState: makeState(),
        isTrial: false,
      );
      await engine.db.into(engine.db.usageLog).insert(
            UsageLogCompanion.insert(
              runId: const Value('r_in_world'),
              role: 'narrator',
              model: 'm',
              tokensIn: 1,
              tokensOut: 1,
              ms: 1,
              createdAt: now,
            ),
          );

      await engine.library.delete('w_x');

      final usage = await engine.db.select(engine.db.usageLog).get();
      expect(usage, isEmpty, reason: '世界删除后其各局的用量行不应残留');
      expect(await engine.db.select(engine.db.runs).get(), isEmpty);
    });
  });

  group('Gateway：429 Retry-After 退避', () {
    test('429+Retry-After:0 后按指示立即重试成功（非固定 1s）', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestTimes = <DateTime>[];
      addTearDown(() => server.close(force: true));
      server.listen((req) async {
        requestTimes.add(DateTime.now());
        await req.drain<void>();
        if (requestTimes.length == 1) {
          req.response.statusCode = 429;
          req.response.headers.set('retry-after', '0');
          await req.response.close();
        } else {
          req.response.headers.contentType =
              ContentType('text', 'event-stream', charset: 'utf-8');
          req.response.add(utf8.encode(
              'data: {"choices":[{"delta":{"content":"好"}}]}\n\n'));
          req.response.add(utf8.encode('data: [DONE]\n\n'));
          await req.response.close();
        }
      });

      final ks = InMemoryKeyStore();
      await ks.write('sk-test');
      final gateway = ModelGateway(GatewayConfig(
        settings: () => ModelSettings(
          protocol: LlmProtocol.openai_chat,
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          narrativeModel: 'm',
          smallModel: 'm',
        ),
        keyStore: ks,
      ));

      final res = await gateway.complete(GatewayRequest(
        role: GatewayRole.classifier,
        system: 's',
        user: 'u',
        maxTokens: 8,
      ));
      expect(res.text, '好');
      expect(requestTimes, hasLength(2));
      final gap = requestTimes[1].difference(requestTimes[0]).inMilliseconds;
      expect(gap, lessThan(800),
          reason: '应按 Retry-After:0 立即重试，固定 1s 退避会超此界');
    });

    test('流式请求 429 后重试成功，增量完整送达', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var hits = 0;
      addTearDown(() => server.close(force: true));
      server.listen((req) async {
        hits++;
        await req.drain<void>();
        if (hits == 1) {
          req.response.statusCode = 429;
          req.response.headers.set('retry-after', '0');
          await req.response.close();
        } else {
          req.response.headers.contentType =
              ContentType('text', 'event-stream', charset: 'utf-8');
          req.response.add(utf8.encode(
              'data: {"choices":[{"delta":{"content":"夜风"}}]}\n\n'));
          req.response.add(utf8.encode(
              'data: {"choices":[{"delta":{"content":"很凉"}}]}\n\n'));
          req.response.add(utf8.encode('data: [DONE]\n\n'));
          await req.response.close();
        }
      });

      final ks = InMemoryKeyStore();
      await ks.write('sk-test');
      final gateway = ModelGateway(GatewayConfig(
        settings: () => ModelSettings(
          protocol: LlmProtocol.openai_chat,
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          narrativeModel: 'm',
          smallModel: 'm',
        ),
        keyStore: ks,
      ));

      final chunks = await gateway
          .stream(GatewayRequest(role: GatewayRole.narrator, system: 's', user: 'u'))
          .toList();
      expect(chunks.join(), '夜风很凉');
      expect(hits, 2, reason: '429 后应重试一次');
    });
  });
}
