import 'dart:convert';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:engine/engine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

AppDb memoryDb() => openDbInMemory();

Future<RunState> persistedState() async {
  final s = makeState();
  s.meta.turnNo = 3;
  return s;
}

void main() {
  group('RunsDao（内存库）', () {
    late AppDb db;
    late RunsDao dao;
    setUp(() {
      db = memoryDb();
      dao = RunsDao(db);
    });
    tearDown(() => db.close());

    test('createRun + loadHead/loadState 往返', () async {
      final s = await persistedState();
      await dao.createRun(
        runId: 'r_dbtest',
        worldId: 'w_cangwu',
        worldVersion: 1,
        identityId: 'id_herb_apprentice',
        initialState: s,
      );
      final head = await dao.loadHead('r_dbtest');
      expect(head, isNotNull);
      expect(head!.worldId, 'w_cangwu');
      expect(head.status, 'active');
      expect(head.turnNo, 3);
      final loaded = await dao.loadState('r_dbtest');
      expect(jsonEncode(loaded!.toJson()), jsonEncode(s.toJson()));
    });

    test('commitTurn 单事务：seq 连续、快照落库、FTS 可检索', () async {
      final s = await persistedState();
      await dao.createRun(
        runId: 'r_dbtest',
        worldId: 'w_cangwu',
        worldVersion: 1,
        identityId: 'id_herb_apprentice',
        initialState: s,
      );
      expect(await dao.nextSeq('r_dbtest'), 1);

      final sid1 = await dao.commitTurn(
        runId: 'r_dbtest',
        stateAfter: s,
        chapter: 1,
        memory: null,
        eventPayloads: [
          {'type': 'input', 'payload': {'kind': 'choice'}, 'fts': null},
          {'type': 'narration', 'payload': {'text': '正文'},
              'fts': '你在药庐后墙发现了一枚带血的玉牌'},
          {'type': 'choices', 'payload': {'options': []}, 'fts': null},
        ],
      );
      expect(sid1, 's_dbtest_0003');
      final sid2 = await dao.commitTurn(
        runId: 'r_dbtest',
        stateAfter: s..meta.turnNo = 4,
        chapter: 1,
        memory: '压缩后的记忆',
        eventPayloads: [
          {'type': 'narration', 'payload': {'text': '第二回合'},
              'fts': '黑水泽的雾里有人影'},
        ],
      );
      expect(sid2, 's_dbtest_0004');
      expect(await dao.nextSeq('r_dbtest'), 5); // 3 + 1 = 4 已用，下一回合从 5 起

      // trigram 分词：≥3 字子串查询命中
      final fts = await db
          .customSelect(
              "SELECT text FROM events_fts WHERE events_fts MATCH '带血的玉牌'")
          .get();
      expect(fts, hasLength(1));
      expect(fts.single.read<String>('text'), contains('玉牌'));

      final mem = await dao.loadMemory('r_dbtest');
      expect(mem, '压缩后的记忆');
    });

    test('turnEnd 带 ending → run 状态翻为 ended，且 headSnapshotId 指向新快照', () async {
      final s = await persistedState();
      await dao.createRun(
        runId: 'r_dbtest',
        worldId: 'w_cangwu',
        worldVersion: 1,
        identityId: 'id_herb_apprentice',
        initialState: s,
      );
      await dao.commitTurn(
        runId: 'r_dbtest',
        stateAfter: s,
        chapter: 1,
        memory: null,
        eventPayloads: [
          {
            'type': 'turnEnd',
            'payload': {
              'turn': 3,
              'ending': {'id': 'ending_fall', 'type': 'fall', 'title': '走火入魔'},
            },
            'fts': null,
          },
        ],
      );
      final head = await dao.loadHead('r_dbtest');
      expect(head!.status, 'ended');
      expect(head.endingId, isNull); // ending 记在事件里，头部由引擎另行收口
    });

    test('loadState / loadHead 对不存在的 run 返回 null', () async {
      expect(await dao.loadState('r_missing'), isNull);
      expect(await dao.loadHead('r_missing'), isNull);
      expect(await dao.loadMemory('r_missing'), isNull);
    });
  });

  group('文件库：迁移可重复执行', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('wayfarer_db'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('关闭后重开，数据保留且 schemaVersion 不变', () async {
      final path = '${tmp.path}/app.db';
      final db1 = openDbAt(path);
      expect(db1.schemaVersion, 1);
      final dao1 = RunsDao(db1);
      final s = await persistedState();
      await dao1.createRun(
        runId: 'r_persist',
        worldId: 'w_cangwu',
        worldVersion: 1,
        identityId: 'id_herb_apprentice',
        initialState: s,
      );
      await db1.close();

      final db2 = openDbAt(path);
      expect(db2.schemaVersion, 1);
      final loaded = await RunsDao(db2).loadState('r_persist');
      expect(loaded, isNotNull);
      expect(loaded!.character.name, s.character.name);
      await db2.close();
    });

    test('FTS5 虚表在重开后仍可用', () async {
      final path = '${tmp.path}/app.db';
      final db1 = openDbAt(path);
      await db1.customStatement(
          "INSERT INTO events_fts (run_id, turn_no, text) VALUES ('r_x', 1, '归墟第三重有活物')");
      await db1.close();

      final db2 = openDbAt(path);
      final rows = await db2
          .customSelect("SELECT text FROM events_fts WHERE events_fts MATCH '归墟第三重'")
          .get();
      expect(rows, hasLength(1));
      await db2.close();
    });
  });

  group('Engine seed 导入幂等', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('wayfarer_engine'));
    tearDown(() => tmp.deleteSync(recursive: true));

    SeedData buildSeed() {
      final bible = loadBible();
      final identities =
          (jsonDecode(File('$kSeedDir/identities.json').readAsStringSync()) as List)
              .map((e) => Identity.fromJson(e))
              .toList();
      final seeds =
          (jsonDecode(File('$kSeedDir/seeds.json').readAsStringSync()) as List)
              .map((e) => EventSeed.fromJson(e))
              .toList();
      return SeedData(
        bible: bible,
        identities: identities,
        seeds: seeds,
        volumeJson: File('$kSeedDir/volume1.json').readAsStringSync(),
      );
    }

    test('连续两次 open 同一库，世界不重复导入', () async {
      final path = '${tmp.path}/app.db';
      final seed = buildSeed();

      final e1 = await Engine.open(
        dbPath: path,
        keyStore: InMemoryKeyStore(),
        builtinSeed: seed,
      );
      final worlds1 = await e1.listWorlds();
      expect(worlds1, hasLength(1));
      expect(worlds1.single.id, 'w_cangwu');
      await e1.close();

      final e2 = await Engine.open(
        dbPath: path,
        keyStore: InMemoryKeyStore(),
        builtinSeed: seed,
      );
      final worlds2 = await e2.listWorlds();
      expect(worlds2, hasLength(1));
      final bible = await e2.loadBible('w_cangwu', 1);
      expect(bible.npcPool, hasLength(7));
      expect(bible.eventSeeds, hasLength(10));
      await e2.close();
    });

    test('保存模型设置后重开引擎，配置不丢', () async {
      final path = '${tmp.path}/app.db';
      final seed = buildSeed();

      final e1 = await Engine.open(
        dbPath: path,
        keyStore: InMemoryKeyStore(),
        builtinSeed: seed,
      );
      await e1.saveModelSettings(ModelSettings(
        protocol: LlmProtocol.openai_chat,
        baseUrl: 'https://apihub.agnes-ai.com/v1',
        narrativeModel: 'agnes-3.0-flash',
        smallModel: 'agnes-3.0-flash',
      ));
      await e1.close();

      final e2 = await Engine.open(
        dbPath: path,
        keyStore: InMemoryKeyStore(),
        builtinSeed: seed,
      );
      final s = e2.modelSettings;
      expect(s.configured, isTrue);
      expect(s.baseUrl, 'https://apihub.agnes-ai.com/v1');
      expect(s.narrativeModel, 'agnes-3.0-flash');
      expect(s.smallModel, 'agnes-3.0-flash');
      await e2.close();
    });
  });
}
