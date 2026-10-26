import 'dart:convert';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:engine/engine.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Map<String, Object?> _cangwuCore() {
  final b = loadBible().toJson();
  return {
    'meta': b['meta'],
    'eras': b['eras'],
    'regions': b['regions'],
    'factions': b['factions'],
    'powerSystem': b['powerSystem'],
    'taboos': b['taboos'],
  };
}

Map<String, Object?> _cangwuContent() {
  final b = loadBible().toJson();
  return {
    'npcPool': b['npcPool'],
    'eventSeeds': b['eventSeeds'],
    'endgame': b['endgame'],
  };
}

List<Identity> _cangwuIdentities() {
  final raw =
      jsonDecode(File('$kSeedDir/identities.json').readAsStringSync()) as List;
  return raw.map((e) => Identity.fromJson(e)).toList();
}

String _chunkJson({
  required List<Map<String, Object?>> entities,
  List<Map<String, Object?>> relations = const [],
  List<Map<String, Object?>> timeline = const [],
  String summary = '剧情摘要。',
}) =>
    jsonEncode({
      'entities': entities,
      'relations': relations,
      'timeline': timeline,
      'summary': summary,
    });

String _novelText(int chars) =>
    '${List.filled(chars, '雪').join()}山门石阶上有旧血。';

String _twoChunkNovel() =>
    '第一章 入山\n${_novelText(2600)}\n第二章 出山\n${_novelText(1400)}';

/// 20 章长文（分块数以任务 total 为准，>16 块触发忠实档压缩）
String _twentyChunkNovel() {
  final buf = StringBuffer();
  for (var c = 1; c <= 20; c++) {
    buf.write('第$c章 行路\n');
    buf.write(List.filled(2500, '云').join());
  }
  return buf.toString();
}

/// 轮询到终态（review / failed），返回任务视图
Future<ImportJobView> _awaitFinished(
    ImportService service, String jobId) async {
  for (var i = 0; i < 400; i++) {
    final view = (await service.progress(jobId))!;
    if (view.stage == 'review' || view.error != null) return view;
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  fail('导入任务 10 秒内未到终态');
}

class FakeGateway implements ModelGateway {
  final GatewayConfig config;

  /// 响应脚本；response 为 null 表示该次调用抛限流异常（模拟 429 风暴）
  final List<(GatewayRole, String?)> script = [];
  final List<GatewayRole> actualCalls = [];

  /// 全部请求记录（断言 digest 内容用）
  final List<GatewayRequest> seen = [];

  FakeGateway(this.config);

  void expect(GatewayRole role, String response) => script.add((role, response));

  /// 入队一次注定失败的调用
  void expectFail(GatewayRole role) => script.add((role, null));

  (GatewayRole, String?) _drain(GatewayRole role) {
    final item = script.removeAt(0);
    if (item.$1 != role) {
      throw StateError('期望调用 ${item.$1.name}，实际 ${role.name}');
    }
    return item;
  }

  @override
  Future<GatewayResult> complete(GatewayRequest req) async {
    seen.add(req);
    final item = _drain(req.role);
    actualCalls.add(req.role);
    if (item.$2 == null) {
      throw EngineException(EngineCode.modelRateLimited, 'fake 429',
          canRetry: true);
    }
    return GatewayResult(
      text: item.$2!,
      tokensIn: 10,
      tokensOut: 10,
      estimated: true,
      ms: 1,
      model: 'fake',
    );
  }

  @override
  Stream<String> stream(GatewayRequest req) async* {
    final item = _drain(req.role);
    if (item.$2 == null) {
      throw EngineException(EngineCode.modelRateLimited, 'fake 429',
          canRetry: true);
    }
    yield item.$2!;
  }

  @override
  Future<ConnectionReport> testConnection() => throw UnimplementedError();
}

ImportService _service(AppDb db, ModelGateway gateway, WorldDraftService drafts,
        {int? maxBytes}) =>
    ImportService(
      db: db,
      gateway: gateway,
      drafts: drafts,
      random: SeqRandom([1, 2, 3]),
      maxBytes: maxBytes ?? 20 * 1024 * 1024,
      backoff: (_) => const Duration(milliseconds: 1),
    );

void main() {
  group('解码与分块', () {
    test('UTF-8 直通，GBK 自动探测', () {
      final utf8Text = '第一章 雪夜\n山门外的雪下了三天。';
      final a = decodeAndChunk(utf8.encode(utf8Text));
      expect(a.chunks.single.text, contains('山门外的雪下了三天'));
      expect(a.chapters, 1);

      final gbkBytes = gbk.encode(utf8Text);
      expect(gbkBytes, isNot(utf8.encode(utf8Text)));
      final b = decodeAndChunk(gbkBytes);
      expect(b.chunks.single.text, contains('山门外的雪下了三天'));
    });

    test('分块 3000 / 重叠 400，章节序号随章节头推进', () {
      // 3 章、每章 2500 字 → 总 7510 字 → 3 块
      final buf = StringBuffer();
      for (var c = 1; c <= 3; c++) {
        buf.write('第${["一", "二", "三"][c - 1]}章 试炼\n');
        buf.write(List.filled(2500, '云').join());
      }
      final r = decodeAndChunk(utf8.encode(buf.toString()));
      expect(r.chapters, 3);
      expect(r.chunks.length, 3);
      expect(r.chunks[0].chapter, 1);
      // 步长 2600：第 2 块起点 2600 在第 2 章头之后、第 3 块起点 5200 在第 3 章头之后
      expect(r.chunks[1].chapter, 2);
      expect(r.chunks[2].chapter, 3);
      expect(r.chunks[1].text.length, 3000);
    });
  });

  group('实体归并', () {
    test('别名互认合并、频次累加、关系端点归一去重', () {
      final merged = mergeExtractions([
        ChunkExtraction(
          entities: [
            ImportEntity(
                key: '陈九',
                type: 'character',
                aliases: {'九爷'},
                frequency: 3,
                firstChapter: 1,
                attributes: {'身份': '三方堂坐商'}),
            ImportEntity(key: '云岫城', type: 'place', frequency: 2),
          ],
          relations: [
            ImportRelation(from: '九爷', to: '云岫城', kind: '据点', chapter: 1),
          ],
          timeline: const [],
          summary: 'a',
        ),
        ChunkExtraction(
          entities: [
            ImportEntity(
                key: '九爷',
                type: 'character',
                aliases: {'陈九'},
                frequency: 2,
                firstChapter: 2),
          ],
          relations: [
            ImportRelation(from: '陈九', to: '云岫城', kind: '据点', chapter: 2),
            ImportRelation(from: '陈九', to: '无名氏', kind: '敌对', chapter: 2),
          ],
          timeline: const [],
          summary: 'b',
        ),
      ]);
      expect(merged.entities, hasLength(2));
      final chen = merged.entities.firstWhere((e) => e.key == '陈九');
      expect(chen.frequency, 5);
      expect(chen.aliases, containsAll(['九爷', '陈九']));
      expect(chen.firstChapter, 1);
      expect(merged.relations, hasLength(1)); // 重复边去重；未知端点丢弃
      expect(merged.relations.single.from, '陈九');
    });
  });

  group('导入管线', () {
    late Directory tmp;
    late AppDb db;
    late FakeGateway fake;
    late WorldDraftService drafts;
    late ImportService service;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('wf_import');
      db = openDbInMemory();
      fake = FakeGateway(GatewayConfig(
        settings: () => ModelSettings(
            protocol: LlmProtocol.openai_chat,
            baseUrl: 'http://x',
            narrativeModel: 'm',
            smallModel: 's'),
        keyStore: InMemoryKeyStore(),
      ));
      drafts = WorldDraftService(
        db: db,
        gateway: fake,
        initialState: (identity, bible) => makeState(),
        prologue: (b, i, s, r) async => '序章。',
        random: SeqRandom([1, 2, 3]),
      );
      service = _service(db, fake, drafts);
    });

    tearDown(() async {
      await db.close();
      tmp.delete(recursive: true);
    });

    test('全流程：抽取→归并→合成→review，导入来源恒不可导出', () async {
      final bible = loadBible();
      final npc1 = bible.npcPool[0].name;
      final npc2 = bible.npcPool[1].name;
      final file = File('${tmp.path}/novel.txt');
      await file.writeAsString(_twoChunkNovel());

      fake.expect(GatewayRole.extractor, _chunkJson(entities: [
        {
          'key': npc1,
          'type': 'character',
          'firstSeen': {'chapter': 1, 'offset': 10},
          'frequency': 3,
          'attributes': {'身份': '散修'},
        },
        {
          'key': '云岫城',
          'type': 'place',
          'frequency': 2,
        },
      ]));
      fake.expect(GatewayRole.extractor, _chunkJson(entities: [
        {
          'key': npc2,
          'type': 'character',
          'frequency': 2,
        },
      ], relations: [
        {'from': npc1, 'to': npc2, 'kind': '同盟', 'chapter': 1},
      ], timeline: [
        {'chapter': 1, 'title': '雪夜入门', 'summary': '主角入山门'},
      ]));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuCore()));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuContent()));
      fake.expect(
          GatewayRole.composer,
          jsonEncode(
              {'identities': _cangwuIdentities().map((i) => i.toJson()).toList()}));

      final job = await service.start(file.path);
      expect(job.stage, 'extracting');
      expect(job.draftId, isNotNull);
      expect(job.total, greaterThanOrEqualTo(2));

      final done = await _awaitFinished(service, job.id);
      expect(done.error, isNull, reason: done.error);
      expect(done.stage, 'review');
      expect(done.done, done.total);
      expect(done.stats!.entities, 3); // 陈…npc1 / 云岫城 / npc2
      expect(done.stats!.relations, 1);
      expect(fake.actualCalls.where((r) => r == GatewayRole.extractor).length, 2);

      final draft = (await drafts.get(done.draftId!))!;
      expect(draft.source, DraftSource.import);
      expect(draft.status, DraftStatus.review);
      expect(draft.exportable, isFalse);
      final detail = await drafts.detail(draft.id);
      expect(detail.bible, isNotNull);
      expect(detail.identities, isNotEmpty);

      // 冻结后 worlds 行 exportable=false（M2 版权硬约束）
      final frozen = await drafts.freeze(draft.id);
      final world = await (db.select(db.worlds)
            ..where((w) => w.id.equals(frozen.worldId)))
          .getSingle();
      expect(world.exportable, isFalse);
      expect(world.source, 'import');

      // 重复导入同一文件 → 命中已有任务
      final again = await service.start(file.path);
      expect(again.id, job.id);
    });

    test('实体审阅：合并/删除/采纳率；review 状态不可再生成', () async {
      final file = File('${tmp.path}/novel3.txt');
      await file.writeAsString(_twoChunkNovel());

      fake.expect(GatewayRole.extractor, _chunkJson(entities: [
        {'key': '沈青', 'type': 'character', 'frequency': 4},
        {'key': '九爷', 'type': 'character', 'frequency': 3},
      ]));
      fake.expect(GatewayRole.extractor, _chunkJson(entities: [
        {'key': '陈九', 'type': 'character', 'frequency': 2},
      ]));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuCore()));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuContent()));
      fake.expect(
          GatewayRole.composer,
          jsonEncode(
              {'identities': _cangwuIdentities().map((i) => i.toJson()).toList()}));

      final job = await service.start(file.path);
      final done = await _awaitFinished(service, job.id);
      expect(done.error, isNull, reason: done.error);
      expect(done.entitiesTotal, 3);

      // 合并：九爷并入沈青 → 频次累加、来源变别名、按频次降序
      final afterMerge =
          await service.updateEntities(job.id, mergeInto: {'九爷': '沈青'});
      expect(afterMerge.length, 2);
      expect(afterMerge.first.key, '沈青');
      expect(afterMerge.first.frequency, 7);
      expect(afterMerge.first.aliases, contains('九爷'));
      expect(afterMerge.map((e) => e.key), isNot(contains('九爷')));

      // 删除：陈九移除；采纳率 = 1 / 3
      final afterRemove =
          await service.updateEntities(job.id, removeKeys: ['陈九']);
      expect(afterRemove.length, 1);
      expect(afterRemove.single.key, '沈青');
      expect(afterRemove.length / done.entitiesTotal, closeTo(1 / 3, 1e-9));

      // 列表已持久化，重读一致
      expect((await service.entities(job.id)).single.key, '沈青');

      // review 状态禁止 regenerate（世界已在编辑器审阅，需去编辑器改）
      await expectLater(
        service.regenerate(job.id),
        throwsA(isA<EngineException>()
            .having((e) => e.code, 'code', EngineCode.stateInvalid)),
      );
    });

    test('超限文件抛 IMPORT_TOO_LARGE', () async {
      final file = File('${tmp.path}/big.txt');
      await file.writeAsString('x' * 100);
      await expectLater(
        _service(db, fake, drafts, maxBytes: 50).start(file.path),
        throwsA(isA<EngineException>()
            .having((e) => e.code, 'code', EngineCode.importTooLarge)),
      );
    });

    test('块抽取终失败→任务 failed；resume 从已存块续跑，不重抽取完成的块', () async {
      final file = File('${tmp.path}/novel2.txt');
      await file.writeAsString(_twoChunkNovel());

      // 第 1 块成功，第 2 块连续三次失败（模拟限流风暴）
      fake.expect(GatewayRole.extractor, _chunkJson(entities: [
        {'key': '沈九', 'type': 'character', 'frequency': 2},
      ]));
      fake.expectFail(GatewayRole.extractor);
      fake.expectFail(GatewayRole.extractor);
      fake.expectFail(GatewayRole.extractor);
      final job = await service.start(file.path);
      // 等失败
      ImportJobView done = job;
      for (var i = 0; i < 400; i++) {
        done = (await service.progress(job.id))!;
        if (done.error != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      expect(done.error, isNotNull);
      final savedChunks = await (db.select(db.importChunks)
            ..where((c) => c.jobId.equals(job.id)))
          .get();
      expect(savedChunks, hasLength(1)); // 恰一块落库，断点已固化

      // 续跑：只补失败的块 + 合成三连，已完成块不再消耗模型调用
      fake.actualCalls.clear();
      fake.expect(GatewayRole.extractor, _chunkJson(entities: [
        {'key': '沈九', 'type': 'character', 'frequency': 4},
      ]));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuCore()));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuContent()));
      fake.expect(
          GatewayRole.composer,
          jsonEncode(
              {'identities': _cangwuIdentities().map((i) => i.toJson()).toList()}));
      final resumed = await service.resume(job.id);
      final fin = await _awaitFinished(service, resumed.id);
      expect(fin.error, isNull, reason: fin.error);
      expect(fin.stage, 'review');
      expect(fake.actualCalls.where((r) => r == GatewayRole.extractor).length, 1);
    });

    test('覆盖率 <80% 追加 IMPORT_COVERAGE_LOW，阻塞试玩与冻结', () async {
      final file = File('${tmp.path}/novel3.txt');
      await file.writeAsString(_twoChunkNovel());
      // 高频人物全部不在圣经里 → 覆盖率 0
      fake.expect(GatewayRole.extractor, _chunkJson(entities: [
        {'key': '王铁匠', 'type': 'character', 'frequency': 9},
      ]));
      fake.expect(GatewayRole.extractor, _chunkJson(entities: [
        {'key': '李捕头', 'type': 'character', 'frequency': 8},
      ]));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuCore()));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuContent()));
      fake.expect(
          GatewayRole.composer,
          jsonEncode(
              {'identities': _cangwuIdentities().map((i) => i.toJson()).toList()}));

      final job = await service.start(file.path);
      final fin = await _awaitFinished(service, job.id);
      expect(fin.error, isNull, reason: fin.error);
      expect(fin.stage, 'review');
      final view = (await drafts.get(fin.draftId!))!;
      final cov = view.issues.firstWhere((i) => i.code == 'IMPORT_COVERAGE_LOW');
      expect(cov.level, 'error');
      expect(view.qualityScore, lessThan(100));
      await expectLater(
        drafts.trial(fin.draftId!),
        throwsA(isA<EngineException>()
            .having((e) => e.code, 'code', EngineCode.qualityGateFailed)),
      );
      // 覆盖率门槛按 §4.4 只锁试玩；冻结闸门仍是六条一致性检查
      final fr = await drafts.freeze(fin.draftId!);
      expect(fr.version, 1);
    });

    test('原文件被改后 resume 抛 IMPORT_INVALID', () async {
      final file = File('${tmp.path}/novel4.txt');
      await file.writeAsString(_novelText(1200));
      fake.expectFail(GatewayRole.extractor);
      fake.expectFail(GatewayRole.extractor);
      fake.expectFail(GatewayRole.extractor);
      final job = await service.start(file.path);
      for (var i = 0; i < 400; i++) {
        final v = (await service.progress(job.id))!;
        if (v.error != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      await file.writeAsString('内容被换掉了');
      await expectLater(
        service.resume(job.id),
        throwsA(isA<EngineException>()
            .having((e) => e.code, 'code', EngineCode.importInvalid)),
      );
    });
  });

  group('合成档位（快速/标准/忠实）', () {
    late Directory tmp;
    late AppDb db;
    late FakeGateway fake;
    late WorldDraftService drafts;
    late ImportService service;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('wf_import_fid');
      db = openDbInMemory();
      fake = FakeGateway(GatewayConfig(
        settings: () => ModelSettings(
            protocol: LlmProtocol.openai_chat,
            baseUrl: 'http://x',
            narrativeModel: 'm',
            smallModel: 's'),
        keyStore: InMemoryKeyStore(),
      ));
      drafts = WorldDraftService(
        db: db,
        gateway: fake,
        initialState: (identity, bible) => makeState(),
        prologue: (b, i, s, r) async => '序章。',
        random: SeqRandom([1, 2, 3]),
      );
      service = _service(db, fake, drafts);
    });

    tearDown(() async {
      await db.close();
      tmp.delete(recursive: true);
    });

    void scriptChunks(int n, {String Function(int i)? summary}) {
      for (var i = 0; i < n; i++) {
        fake.expect(GatewayRole.extractor, _chunkJson(
          entities: [
            {'key': '人$i', 'type': 'character', 'frequency': 1},
          ],
          summary: summary?.call(i) ?? '第${i + 1}块剧情',
        ));
      }
    }

    void scriptCompose() {
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuCore()));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuContent()));
      fake.expect(
          GatewayRole.composer,
          jsonEncode(
              {'identities': _cangwuIdentities().map((i) => i.toJson()).toList()}));
    }

    /// 合成核心段的请求（含素材 digest），多次生成取最后一次
    String digestUser() => fake.seen
        .where((r) =>
            r.role == GatewayRole.composer &&
            r.user.contains('以下素材是从一部小说全文中按块抽取的'))
        .last
        .user;

    test('sampleEvenly：n≥长度原样返回，n<长度首尾必含且等距', () {
      final items = [for (var i = 0; i < 145; i++) i];
      expect(sampleEvenly(items, 200), hasLength(145));
      final picked = sampleEvenly(items, 60);
      expect(picked, hasLength(60));
      expect(picked.first, 0);
      expect(picked.last, 144);
      expect(picked.toSet().length, 60); // 等距无重复
      expect(sampleEvenly(items, 1), [0]);
      expect(sampleEvenly(<int>[], 5), isEmpty);
    });

    test('默认快速档：digest 截断取前 N，fidelity 记录 fast', () async {
      final file = File('${tmp.path}/novel_fast.txt');
      await file.writeAsString(_twoChunkNovel());
      scriptChunks(2);
      scriptCompose();

      final job = await service.start(file.path);
      expect(job.fidelity, ImportFidelity.fast);
      final fin = await _awaitFinished(service, job.id);
      expect(fin.error, isNull, reason: fin.error);
      final user = digestUser();
      expect(user, contains('分块剧情摘要（按顺序）'));
      // 反向断言用素材 JSON 的完整键，避免误中规则文案里的“全书脉络”字样
      expect(user, isNot(contains('全书脉络（卷级剧情摘要')));
      // 再次查询档位一致
      expect((await service.progress(job.id))!.fidelity, ImportFidelity.fast);
    });

    test('标准档：全书均匀采样（首尾必含），digest 仍用分块摘要', () async {
      final file = File('${tmp.path}/novel_std.txt');
      await file.writeAsString(_twoChunkNovel());
      scriptChunks(2);
      scriptCompose();

      final job = await service.start(file.path, fidelity: ImportFidelity.standard);
      expect(job.fidelity, ImportFidelity.standard);
      final fin = await _awaitFinished(service, job.id);
      expect(fin.error, isNull, reason: fin.error);
      final user = digestUser();
      expect(user, contains('分块剧情摘要（按顺序）'));
      expect(user, contains('第1块剧情'));
      expect(user, contains('第2块剧情')); // 首尾必含
      expect(fake.actualCalls
          .where((r) => r == GatewayRole.extractor).length, 2); // 无压缩调用
    });

    test('忠实档：全书摘要压缩为卷级脉络，结局进合成素材', () async {
      final file = File('${tmp.path}/novel_faithful.txt');
      await file.writeAsString(_twentyChunkNovel());
      scriptChunks(20);
      fake.expect(
          GatewayRole.extractor,
          jsonEncode({
            'arcs': [
              '前半：主角入山学艺，结识众人，旧血疑云渐起',
              '真实结局：主角在渡口送别众人，独自归隐雪山',
            ],
          }));
      scriptCompose();

      final job = await service.start(file.path, fidelity: ImportFidelity.faithful);
      expect(job.fidelity, ImportFidelity.faithful);
      final fin = await _awaitFinished(service, job.id);
      expect(fin.error, isNull, reason: fin.error);
      // 20 块抽取 + 1 次脉络压缩
      expect(fake.actualCalls
          .where((r) => r == GatewayRole.extractor).length, fin.total + 1);
      final user = digestUser();
      expect(user, contains('全书脉络'));
      expect(user, contains('真实结局：主角在渡口送别众人，独自归隐雪山'));
      expect(user, isNot(contains('第20块剧情'))); // 分块摘要被脉络替换
      final detail = await drafts.detail(fin.draftId!);
      expect(detail.bible, isNotNull);
    });

    test('忠实档压缩 3 次失败 → 降级标准档采样，任务不失败', () async {
      final file = File('${tmp.path}/novel_fid_fail.txt');
      await file.writeAsString(_twentyChunkNovel());
      scriptChunks(20);
      fake.expectFail(GatewayRole.extractor);
      fake.expectFail(GatewayRole.extractor);
      fake.expectFail(GatewayRole.extractor);
      scriptCompose();

      final job =
          await service.start(file.path, fidelity: ImportFidelity.faithful);
      final fin = await _awaitFinished(service, job.id);
      expect(fin.error, isNull, reason: fin.error);
      expect(fin.stage, 'review');
      final user = digestUser();
      expect(user, contains('分块剧情摘要（按顺序）')); // 降级
      expect(user, isNot(contains('全书脉络（卷级剧情摘要')));
    });

    test('regenerate 换档：compose 失败后忠实档重新生成成功', () async {
      final file = File('${tmp.path}/novel_regen.txt');
      await file.writeAsString(_twentyChunkNovel());
      scriptChunks(20);
      fake.expectFail(GatewayRole.composer); // 合成失败 → 任务 failed、草稿回 draft

      final job =
          await service.start(file.path, fidelity: ImportFidelity.standard);
      final failed = await _awaitFinished(service, job.id);
      expect(failed.error, isNotNull);
      expect(failed.entitiesTotal, 20); // 实体已先落库，可重生成

            fake.expect(
          GatewayRole.extractor,
          jsonEncode({
            'arcs': ['真实结局：主角归隐雪山'],
          }));
      scriptCompose();

      final regen = await service.regenerate(job.id,
          fidelity: ImportFidelity.faithful);
      expect(regen.fidelity, ImportFidelity.faithful);
      final fin = await _awaitFinished(service, job.id);
      expect(fin.error, isNull, reason: fin.error);
      expect(fin.stage, 'review');
      final user = digestUser();
      expect(user, contains('全书脉络'));
      expect(user, contains('真实结局：主角归隐雪山'));
      expect((await service.progress(job.id))!.fidelity,
          ImportFidelity.faithful);
    });
  });
}
