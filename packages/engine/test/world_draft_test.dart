import 'dart:convert';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:engine/engine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

String _eraJson() => jsonEncode({
      'skip': false,
      'contradiction': null,
      'data': {
        'summary': '灵潮退去的末法之世。',
        'turningPoint': '主灵脉一夜枯竭。',
      },
    });

String _contradictionJson() => jsonEncode({
      'skip': false,
      'contradiction': {'with': 'era', 'reason': '前面说灵潮退去，这里又说灵气充沛'},
      'data': {'summary': '灵气充沛的盛世。', 'turningPoint': '无事'},
    });

Map<String, Object?> _defaultData(FieldKey k) => switch (k) {
      FieldKey.era => {
          'summary': '灵潮退去的末法之世。',
          'turningPoint': '主灵脉一夜枯竭。',
        },
      FieldKey.geography => {
          'regions': [
            {'name': '云岫城', 'use': '商埠', 'danger': '2'},
            {'name': '黑水泽', 'use': '猎场', 'danger': '4'},
            {'name': '山门', 'use': '宗门重地', 'danger': '1'},
          ],
        },
      FieldKey.factions => {
          'factions': [
            {
              'name': '青冥宗',
              'goal': '守灵脉',
              'relations': [
                {'name': '缇骑', 'stance': '提防'},
                {'name': '三方堂', 'stance': '结盟'},
              ],
            },
            {
              'name': '缇骑',
              'goal': '清查修士',
              'relations': [
                {'name': '青冥宗', 'stance': '提防'},
              ],
            },
            {
              'name': '三方堂',
              'goal': '倒卖灵材',
              'relations': [
                {'name': '缇骑', 'stance': '敌对'},
              ],
            },
          ],
        },
      FieldKey.power => {
          'tiers': ['炼气', '筑基', '金丹'],
          'costs': ['突破失败折寿'],
          'rules': ['灵气枯竭'],
        },
      FieldKey.taboos => {
          'items': ['不显灵力于缇骑前', '不探宗门禁地', '不以活人试药'],
        },
      FieldKey.tone => {
          'words': ['冷峻', '克制', '压抑'],
        },
      FieldKey.npcs => {
          'npcs': [
            for (var i = 1; i <= 5; i++)
              {'name': 'NPC$i', 'role': '散修', 'affiliation': '散人'},
          ],
        },
      FieldKey.events => {
          'events': [
            for (var i = 1; i <= 8; i++) {'title': '事件$i', 'trigger': '触发$i'},
          ],
        },
    };

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
  final dir = kSeedDir;
  final raw = jsonDecode(File('$dir/identities.json').readAsStringSync()) as List;
  return raw.map((e) => Identity.fromJson(e)).toList();
}

RunState _fakeState(Identity identity, WorldBible bible) {
  final tier = bible.tierByStage(1)!;
  return RunState(
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
      stats: Stats(vitality: 50, spirit: 50, body: 50),
      resources: Resources(
          spiritStones: identity.resources['spiritStones'] ?? 0, pills: {}),
      conditions: [],
    ),
    location: LocationRef(
        regionId: identity.start.regionId, placeId: identity.start.placeId),
    relations: {},
    inventory: [],
    knowledge: [identity.situation],
    threads: [],
    flags: {},
    reputation: {},
  );
}

class FakeGateway implements ModelGateway {
  final GatewayConfig config;
  final List<(GatewayRole, String)> script = [];
  final List<GatewayRole> actualCalls = [];

  FakeGateway(this.config);

  void expect(GatewayRole role, String response) => script.add((role, response));

  String _drain(GatewayRole role) {
    actualCalls.add(role);
    final (want, text) = script.removeAt(0);
    if (want != role) {
      throw StateError('期望调用 ${want.name}，实际 ${role.name}');
    }
    return text;
  }

  @override
  Future<GatewayResult> complete(GatewayRequest req) async {
    final text = _drain(req.role);
    return GatewayResult(
        text: text, tokensIn: 10, tokensOut: 10, estimated: true, ms: 1, model: 'fake');
  }

  @override
  Stream<String> stream(GatewayRequest req) async* {
    yield _drain(req.role);
  }

  @override
  Future<ConnectionReport> testConnection() async {
    throw UnimplementedError();
  }
}

void main() {
  group('草稿状态机与完整度', () {
    test('非法跳转被拒，合法链路放行', () {
      expect(canTransition(DraftStatus.draft, DraftStatus.frozen), isFalse);
      expect(canTransition(DraftStatus.draft, DraftStatus.review), isFalse);
      expect(canTransition(DraftStatus.review, DraftStatus.generating), isFalse);
      expect(canTransition(DraftStatus.frozen, DraftStatus.review), isFalse);
      expect(canTransition(DraftStatus.draft, DraftStatus.generating), isTrue);
      expect(canTransition(DraftStatus.generating, DraftStatus.review), isTrue);
      expect(canTransition(DraftStatus.generating, DraftStatus.draft), isTrue);
      expect(canTransition(DraftStatus.review, DraftStatus.trial), isTrue);
      expect(canTransition(DraftStatus.trial, DraftStatus.review), isTrue);
      expect(canTransition(DraftStatus.review, DraftStatus.frozen), isTrue);
    });

    test('八字段加权：缺失为 0，达标线逐条可打满', () {
      expect(scoreField(FieldKey.era, null), 0);
      expect(scoreField(FieldKey.era, {'summary': '一句话'}), 60);
      expect(scoreField(FieldKey.era, _defaultData(FieldKey.era)), 100);
      expect(
          scoreField(FieldKey.geography, {
            'regions': [
              {'name': '甲', 'use': 'x'},
              {'name': '乙', 'use': 'y'},
              {'name': '丙', 'use': 'z'},
            ]
          }),
          100);
      expect(
          scoreField(FieldKey.geography, {
            'regions': [
              {'name': '甲', 'use': ''},
            ]
          }),
          lessThan(50));
      expect(scoreField(FieldKey.power, {'tiers': ['a']}), 23);
      expect(
          scoreField(FieldKey.power,
              {'tiers': ['a', 'b', 'c'], 'costs': ['代价']}),
          100);
      expect(scoreField(FieldKey.taboos, {'items': ['a']}), 33);
      expect(scoreField(FieldKey.npcs, _defaultData(FieldKey.npcs)), 100);
      expect(scoreField(FieldKey.events, _defaultData(FieldKey.events)), 100);
    });

    test('八个字段全达标 → completeness 100；缺一个 → 扣该字段权重', () {
      final full = InterviewState(step: FieldKey.era);
      for (final k in FieldKey.values) {
        full.answers[k] = FieldAnswer(text: 'x', data: _defaultData(k));
      }
      expect(full.completeness, 100);
      final missing = InterviewState(step: FieldKey.era);
      for (final k in FieldKey.values) {
        if (k != FieldKey.events) {
          missing.answers[k] = FieldAnswer(text: 'x', data: _defaultData(k));
        }
      }
      expect(missing.completeness, 100 - FieldKey.events.weight);
    });

    test('InterviewState JSON 往返', () {
      final s = InterviewState(step: FieldKey.power);
      s.answers[FieldKey.era] =
          const FieldAnswer(text: '原话', data: {'summary': 'x'}, filledByAI: true);
      final back = InterviewState.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(back.step, FieldKey.power);
      expect(back.answers[FieldKey.era]!.filledByAI, isTrue);
      expect(back.answers[FieldKey.era]!.data['summary'], 'x');
    });
  });

  group('一致性检查六条', () {
    test('cangwu 全绿', () {
      final issues = checkBible(loadBible());
      expect(issues.where((i) => i.level == 'error'), isEmpty);
    });

    test('势力无据点 → FACTION_NO_BASE', () {
      final b = loadBible();
      b.regions.first.factionIds.clear();
      final codes = checkBible(b).map((i) => i.code).toSet();
      expect(codes, contains('FACTION_NO_BASE'));
    });

    test('力量无代价 → POWER_NO_COST，且分数跌破 70', () {
      final b = loadBible();
      b.powerSystem.costs.clear();
      final report = reviewBible(b);
      expect(report.issues.map((i) => i.code), contains('POWER_NO_COST'));
      expect(report.pass, isFalse);
      expect(report.score, lessThan(70));
    });

    test('NPC 无归属 → NPC_NO_FACTION', () {
      final b = loadBible();
      b.npcPool.first.factionId = null;
      b.npcPool.first.public.affiliation = '';
      expect(checkBible(b).map((i) => i.code), contains('NPC_NO_FACTION'));
    });

    test('种子引用不存在的区域 → SEED_UNREACHABLE', () {
      final b = loadBible();
      b.eventSeeds.first.regionId = 'reg_missing';
      expect(checkBible(b).map((i) => i.code), contains('SEED_UNREACHABLE'));
    });

    test('无终局 → NO_ENDING', () {
      final b = loadBible();
      b.endgame.clear();
      expect(checkBible(b).map((i) => i.code), contains('NO_ENDING'));
    });
  });

  group('WorldDraftService', () {
    late AppDb db;
    late FakeGateway fake;
    late WorldDraftService service;

    setUp(() {
      db = openDbInMemory();
      fake = FakeGateway(GatewayConfig(
        settings: () => ModelSettings(
            protocol: LlmProtocol.openai_chat,
            baseUrl: 'http://x',
            narrativeModel: 'm',
            smallModel: 's'),
        keyStore: InMemoryKeyStore(),
      ));
      service = WorldDraftService(
        db: db,
        gateway: fake,
        initialState: _fakeState,
        prologue: (b, i, s, r) async => '序章正文。',
        random: SeqRandom([1, 2, 3]),
      );
    });

    test('create：source 三选一，import 不可导出', () async {
      final manual = await service.create(DraftSource.manual);
      expect(manual.status, DraftStatus.draft);
      expect(manual.exportable, isTrue);
      expect(manual.completeness, 0);
      final imported = await service.create(DraftSource.import);
      expect(imported.exportable, isFalse);
      final dialogue = await service.create(DraftSource.dialogue);
      expect(dialogue.source, DraftSource.dialogue);
    });

    test('interview：抽取一轮推进一步', () async {
      final d = await service.create(DraftSource.dialogue);
      fake.expect(GatewayRole.interview, _eraJson());
      final r = await service.interview(d.id, '灵潮退去了，主灵脉一夜枯竭。');
      expect(r.advanced, isTrue);
      expect(r.field, FieldKey.era);
      expect(r.nextStep, FieldKey.geography);
      final detail = await service.detail(d.id);
      expect(detail.view.completeness, greaterThan(0));
      expect(detail.view.fields[FieldKey.era]!.filledByAI, isFalse);
    });

    test('interview：矛盾当场指出，不落答案', () async {
      final d = await service.create(DraftSource.dialogue);
      fake.expect(GatewayRole.interview, _contradictionJson());
      final r = await service.interview(d.id, '灵气充沛的盛世。');
      expect(r.advanced, isFalse);
      expect(r.contradiction, isNotNull);
      expect(r.contradiction!.conflictWith, 'era');
      final detail = await service.detail(d.id);
      expect(detail.view.completeness, 0);
    });

    test('interview：跳过 → AI 代填并标注', () async {
      final d = await service.create(DraftSource.dialogue);
      fake.expect(
          GatewayRole.interview,
          jsonEncode({
            'skip': false,
            'contradiction': null,
            'data': {'summary': '代填时代', 'turningPoint': '代填转折'},
          }));
      final r = await service.interview(d.id, '', skip: true);
      expect(r.advanced, isTrue);
      expect(r.filledByAI, isTrue);
      final detail = await service.detail(d.id);
      expect(detail.view.fields[FieldKey.era]!.filledByAI, isTrue);
      final interview = detail.interview!;
      expect(interview.answers[FieldKey.era]!.data['summary'], '代填时代');
    });

    test('interview：代填形状漂移（非空但缺键）→ 退回静态兜底', () async {
      final d = await service.create(DraftSource.dialogue);
      fake.expect(
          GatewayRole.interview,
          jsonEncode(
              {'skip': false, 'contradiction': null, 'data': {'note': '形状漂移'}}));
      final r = await service.interview(d.id, '', skip: true);
      expect(r.advanced, isTrue);
      expect(r.filledByAI, isTrue);
      final detail = await service.detail(d.id);
      final data = detail.interview!.answers[FieldKey.era]!.data;
      expect(asSOr(data['summary'], ''), contains('末法'));
      expect(detail.view.fields[FieldKey.era]!.score, 100);
    });

    test('八轮跳过后 completeness 100，可 generate', () async {
      final d = await service.create(DraftSource.dialogue);
      for (final k in FieldKey.values) {
        fake.expect(
            GatewayRole.interview,
            jsonEncode(
                {'skip': false, 'contradiction': null, 'data': _defaultData(k)}));
        await service.interview(d.id, '', skip: true);
      }
      final detail = await service.detail(d.id);
      expect(detail.view.completeness, 100);
      expect(detail.view.fields.values.every((f) => f.filledByAI), isTrue);
    });

    test('generate：完整度不足 → DRAFT_INCOMPLETE', () async {
      final d = await service.create(DraftSource.manual);
      await expectLater(service.generate(d.id),
          throwsA(predicate((e) => e is EngineException && e.code == EngineCode.draftIncomplete)));
    });

    test('generate：三段生成 → review，质量分落库', () async {
      final d = await service.create(DraftSource.dialogue);
      for (final k in FieldKey.values) {
        fake.expect(
            GatewayRole.interview,
            jsonEncode(
                {'skip': false, 'contradiction': null, 'data': _defaultData(k)}));
        await service.interview(d.id, '', skip: true);
      }
      final core = _cangwuCore();
      fake.expect(GatewayRole.composer, jsonEncode(core));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuContent()));
      fake.expect(
          GatewayRole.composer,
          jsonEncode({
            'identities': _cangwuIdentities().map((i) => i.toJson()).toList(),
          }));
      final view = await service.generate(d.id);
      expect(view.status, DraftStatus.review);
      expect(view.title, '苍梧');
      expect(view.qualityScore, greaterThanOrEqualTo(70));
      final detail = await service.detail(d.id);
      expect(detail.bible, isNotNull);
      expect(detail.bible!.npcPool, isNotEmpty);
      expect(detail.identities.length, greaterThanOrEqualTo(3));
    });

    test('generate：畸形内容 → modelBadOutput，状态回 draft 可重试', () async {
      final d = await service.create(DraftSource.dialogue);
      for (final k in FieldKey.values) {
        fake.expect(
            GatewayRole.interview,
            jsonEncode(
                {'skip': false, 'contradiction': null, 'data': _defaultData(k)}));
        await service.interview(d.id, '', skip: true);
      }
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuCore()));
      fake.expect(GatewayRole.composer,
          jsonEncode({..._cangwuContent(), 'npcPool': '应为数组却给了字符串'}));
      await expectLater(service.generate(d.id),
          throwsA(predicate((e) => e is EngineException && e.code == EngineCode.modelBadOutput)));
      final broken = await service.detail(d.id);
      expect(broken.view.status, DraftStatus.draft);

      // 同一草稿重试成功（generating 允许重入的恢复路径）
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuCore()));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuContent()));
      fake.expect(
          GatewayRole.composer,
          jsonEncode({
            'identities': _cangwuIdentities().map((i) => i.toJson()).toList(),
          }));
      final view = await service.generate(d.id);
      expect(view.status, DraftStatus.review);
    });

    test('generate：僵死 generating 状态可重入恢复', () async {
      final d = await service.create(DraftSource.dialogue);
      for (final k in FieldKey.values) {
        fake.expect(
            GatewayRole.interview,
            jsonEncode(
                {'skip': false, 'contradiction': null, 'data': _defaultData(k)}));
        await service.interview(d.id, '', skip: true);
      }
      await (db.update(db.worldDrafts)..where((x) => x.id.equals(d.id)))
          .write(const WorldDraftsCompanion(status: Value('generating')));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuCore()));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuContent()));
      fake.expect(
          GatewayRole.composer,
          jsonEncode({
            'identities': _cangwuIdentities().map((i) => i.toJson()).toList(),
          }));
      final view = await service.generate(d.id);
      expect(view.status, DraftStatus.review);
    });

    test('generate：势力无据点自动挂到危险度最低区域，门禁不再卡死', () async {
      final d = await service.create(DraftSource.dialogue);
      for (final k in FieldKey.values) {
        fake.expect(
            GatewayRole.interview,
            jsonEncode(
                {'skip': false, 'contradiction': null, 'data': _defaultData(k)}));
        await service.interview(d.id, '', skip: true);
      }
      final core = _cangwuCore();
      final firstRegion = (core['regions'] as List).first as Map;
      final orphanFid = (firstRegion['factionIds'] as List).first as String;
      firstRegion['factionIds'] = <String>[];
      fake.expect(GatewayRole.composer, jsonEncode(core));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuContent()));
      fake.expect(
          GatewayRole.composer,
          jsonEncode({
            'identities': _cangwuIdentities().map((i) => i.toJson()).toList(),
          }));
      final view = await service.generate(d.id);
      expect(view.issues.map((i) => i.code), isNot(contains('FACTION_NO_BASE')));
      final detail = await service.detail(d.id);
      expect(detail.bible!.regions.any((r) => r.factionIds.contains(orphanFid)),
          isTrue);
      final frozen = await service.freeze(d.id);
      expect(frozen.worldId, isNotEmpty);
      final after = await service.detail(d.id);
      expect(after.view.status, DraftStatus.frozen);
    });

    test('save：schemaVersion 不可改，标题可改并重算质量', () async {
      final d = await service.create(DraftSource.dialogue);
      for (final k in FieldKey.values) {
        fake.expect(
            GatewayRole.interview,
            jsonEncode(
                {'skip': false, 'contradiction': null, 'data': _defaultData(k)}));
        await service.interview(d.id, '', skip: true);
      }
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuCore()));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuContent()));
      fake.expect(
          GatewayRole.composer,
          jsonEncode({
            'identities': _cangwuIdentities().map((i) => i.toJson()).toList(),
          }));
      await service.generate(d.id);
      final detail = await service.detail(d.id);
      final bible = detail.bible!;
      bible.schemaVersion = 7;
      bible.meta.title = '新世界名';
      final saved = await service.save(d.id, bible: bible);
      expect(saved.title, '新世界名');
      final reread = await service.detail(d.id);
      expect(reread.bible!.schemaVersion, 1);
    });

    test('save：generating 期间锁定', () async {
      final d = await service.create(DraftSource.manual);
      await (db.update(db.worldDrafts)..where((x) => x.id.equals(d.id)))
          .write(const WorldDraftsCompanion(
              status: Value('generating')));
      await expectLater(
          service.save(d.id, bible: loadBible()),
          throwsA(predicate((e) =>
              e is EngineException && e.code == EngineCode.stateInvalid)));
    });

    test('freeze：新建世界与版本，再冻结无修改 → WORLD_FROZEN，改后 → v2', () async {
      final d = await service.create(DraftSource.dialogue);
      for (final k in FieldKey.values) {
        fake.expect(
            GatewayRole.interview,
            jsonEncode(
                {'skip': false, 'contradiction': null, 'data': _defaultData(k)}));
        await service.interview(d.id, '', skip: true);
      }
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuCore()));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuContent()));
      fake.expect(
          GatewayRole.composer,
          jsonEncode({
            'identities': _cangwuIdentities().map((i) => i.toJson()).toList(),
          }));
      await service.generate(d.id);

      final r1 = await service.freeze(d.id);
      expect(r1.version, 1);
      final worldRow = await (db.select(db.worlds)
            ..where((w) => w.id.equals(r1.worldId)))
          .getSingle();
      expect(worldRow.latestVersion, 1);
      expect(worldRow.source, 'dialogue');
      final frozen = await service.get(d.id);
      expect(frozen!.status, DraftStatus.frozen);
      expect(frozen.worldId, r1.worldId);

      await expectLater(service.freeze(d.id),
          throwsA(predicate((e) => e is EngineException && e.code == EngineCode.worldFrozen)));

      final detail = await service.detail(d.id);
      final bible = detail.bible!;
      bible.meta.title = '改后的世界';
      await service.save(d.id, bible: bible);
      final r2 = await service.freeze(d.id);
      expect(r2.worldId, r1.worldId);
      expect(r2.version, 2);
      final worldRow2 = await (db.select(db.worlds)
            ..where((w) => w.id.equals(r1.worldId)))
          .getSingle();
      expect(worldRow2.latestVersion, 2);
      final versions = await (db.select(db.worldVersions)
            ..where((v) => v.worldId.equals(r1.worldId)))
          .get();
      expect(versions.length, 2);
    });

    test('trial：草稿直接开局，不入我的局，可丢弃', () async {
      final d = await service.create(DraftSource.dialogue);
      for (final k in FieldKey.values) {
        fake.expect(
            GatewayRole.interview,
            jsonEncode(
                {'skip': false, 'contradiction': null, 'data': _defaultData(k)}));
        await service.interview(d.id, '', skip: true);
      }
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuCore()));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuContent()));
      fake.expect(
          GatewayRole.composer,
          jsonEncode({
            'identities': _cangwuIdentities().map((i) => i.toJson()).toList(),
          }));
      await service.generate(d.id);

      final start = await service.trial(d.id);
      final head = await RunsDao(db).loadHead(start.runId);
      expect(head!.isTrial, isTrue);
      expect(head.draftId, d.id);
      final view = await service.get(d.id);
      expect(view!.status, DraftStatus.trial);

      // 试玩推进一回合（草稿圣经可用；选项输入不走分类器）
      final te = TurnEngine(
          db: db,
          gateway: fake,
          queue: SerialQueue(),
          random: SeqRandom([70, 30]));
      fake.expect(
          GatewayRole.director,
          '{"beat":"daily","summary":"推进","npcActions":[],"reveals":[],"mood":"松弛","nextChoices":[{"intent":"继续","risk":"low"}],"advanceTimeDays":1}');
      fake.expect(GatewayRole.narrator, '你继续往前走。');
      fake.expect(
          GatewayRole.extractor,
          jsonEncode({
            'ops': [],
            'facts': ['你走了走'],
            'openThreads': [],
            'closeThreads': [],
            'choices': [],
          }));
      final events =
          await te.run(start.runId, expectedTurn: 0, input: ChoiceInput('t0c1')).toList();
      expect(events.whereType<TurnError>(), isEmpty);

      // 局存在但带试玩标记
      final trialRows = await (db.select(db.runs)
            ..where((r) => r.isTrial.equals(true)))
          .get();
      expect(trialRows.length, 1);

      // 一键丢弃
      await (db.delete(db.runs)..where((r) => r.id.equals(start.runId))).go();
      expect(await RunsDao(db).loadHead(start.runId), isNull);
    });

    test('trial：冻结后可重开试玩，状态保持 frozen', () async {
      final d = await service.create(DraftSource.dialogue);
      for (final k in FieldKey.values) {
        fake.expect(
            GatewayRole.interview,
            jsonEncode(
                {'skip': false, 'contradiction': null, 'data': _defaultData(k)}));
        await service.interview(d.id, '', skip: true);
      }
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuCore()));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuContent()));
      fake.expect(
          GatewayRole.composer,
          jsonEncode({
            'identities': _cangwuIdentities().map((i) => i.toJson()).toList(),
          }));
      await service.generate(d.id);
      await service.freeze(d.id);

      final start = await service.trial(d.id);
      final head = await RunsDao(db).loadHead(start.runId);
      expect(head!.isTrial, isTrue);
      expect(head.draftId, d.id);
      final view = await service.get(d.id);
      expect(view!.status, DraftStatus.frozen);

      // 重复试玩：替换旧试玩局，不堆积悬挂局
      final start2 = await service.trial(d.id);
      expect(start2.runId, isNot(start.runId));
      final heads = await (db.select(db.runs)
            ..where((r) => r.draftId.equals(d.id) & r.isTrial.equals(true)))
          .get();
      expect(heads.length, 1);
      expect(heads.single.id, start2.runId);
      final viewAfter = await service.get(d.id);
      expect(viewAfter!.status, DraftStatus.frozen);
    });
  });

  group('Engine 门面：试玩局随行助手', () {
    test('assistant：试玩局从草稿取世界包，随行可答', () async {
      final tmp = await Directory.systemTemp.createTemp('wf_assist');
      final fake = FakeGateway(GatewayConfig(
        settings: () => ModelSettings(
            protocol: LlmProtocol.openai_chat,
            baseUrl: 'http://x',
            narrativeModel: 'm',
            smallModel: 's'),
        keyStore: InMemoryKeyStore(),
      ));
      final engine = await Engine.open(
        dbPath: '${tmp.path}/app.db',
        keyStore: InMemoryKeyStore(),
        gatewayFactory: (_) => fake,
        random: SeqRandom([1, 2, 3]),
      );
      addTearDown(() async {
        await engine.close();
        tmp.delete(recursive: true);
      });

      final d = await engine.drafts.create(DraftSource.dialogue);
      for (final k in FieldKey.values) {
        fake.expect(
            GatewayRole.interview,
            jsonEncode(
                {'skip': false, 'contradiction': null, 'data': _defaultData(k)}));
        await engine.drafts.interview(d.id, '', skip: true);
      }
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuCore()));
      fake.expect(GatewayRole.composer, jsonEncode(_cangwuContent()));
      fake.expect(
          GatewayRole.composer,
          jsonEncode({
            'identities': _cangwuIdentities().map((i) => i.toJson()).toList(),
          }));
      await engine.drafts.generate(d.id);

      // 引擎级 trial 走真实序章工厂（narrator complete）
      fake.expect(GatewayRole.narrator, '雪落在山门石阶上。');
      final start = await engine.drafts.trial(d.id);
      final head = await RunsDao(engine.db).loadHead(start.runId);
      expect(head!.isTrial, isTrue);
      expect(head.draftId, d.id);
      expect(start.prologue, '雪落在山门石阶上。');

      // 随行助手：loadRunPackage 对试玩局走草稿分支，而非 world_versions
      fake.expect(GatewayRole.companion, '此地灵气稀薄，暂无大碍。');
      final events = await engine.assistant(start.runId, '这里安全吗？').toList();
      final text = events.whereType<AssistantDelta>().map((e) => e.text).join();
      expect(text, '此地灵气稀薄，暂无大碍。');
      expect(events.whereType<AssistantEnd>(), hasLength(1));
    });
  });
}
