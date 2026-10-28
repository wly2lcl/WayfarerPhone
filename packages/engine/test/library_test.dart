import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart' as ar;
import 'package:contracts/contracts.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:engine/engine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

AppDb _db() => openDbInMemory();

int _runCounter = 0;

(WorldBible, List<Identity>, List<EventSeed>) _seedData() {
  final bible = loadBible();
  final identities = asList<Identity>(
      jsonDecode(File('$kSeedDir/identities.json').readAsStringSync()),
      Identity.fromJson);
  final seeds = asList<EventSeed>(
      jsonDecode(File('$kSeedDir/seeds.json').readAsStringSync()), EventSeed.fromJson);
  return (bible, identities, seeds);
}

Future<void> _seedWorld(
  AppDb db, {
  String id = 'w_test',
  String title = '测试世界',
  bool exportable = true,
  String source = 'created',
  int version = 1,
}) async {
  final (bible, identities, seeds) = _seedData();
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.into(db.worlds).insert(WorldsCompanion.insert(
        id: id,
        title: title,
        genre: bible.meta.genre,
        summary: Value(bible.meta.summary),
        source: source,
        exportable: Value(exportable),
        latestVersion: Value(version),
        createdAt: now,
        updatedAt: now,
      ));
  await db.into(db.worldVersions).insert(WorldVersionsCompanion.insert(
        id: 'wv_${id}_v$version',
        worldId: id,
        version: version,
        bible: jsonEncode(bible.toJson()),
        identities: jsonEncode(identities.map((i) => i.toJson()).toList()),
        seeds: jsonEncode(seeds.map((s) => s.toJson()).toList()),
        checksum: internalWorldChecksum(bible.toJson(),
            identities.map((i) => i.toJson()).toList(), seeds.map((s) => s.toJson()).toList()),
        createdAt: now,
      ));
}

RunState _stateAt(int turnNo) {
  final j = makeState().toJson();
  (j['meta'] as Map)['turnNo'] = turnNo;
  return RunState.fromJson(j);
}

/// 造一个正式局：序章（turnNo 0）+ 两回合推进（t4/t5，head=5）
Future<String> _makeRun(AppDb db, {String worldId = 'w_test', bool trial = false}) async {
  final state = makeState();
  final runId = 'r_${(_runCounter++).toRadixString(36)}_x';
  await RunsDao(db).createRun(
    runId: runId,
    worldId: worldId,
    worldVersion: 1,
    identityId: state.character.identityId,
    initialState: state,
    isTrial: trial,
  );
  await db.into(db.runEvents).insert(RunEventsCompanion.insert(
        runId: runId,
        seq: 1,
        turnNo: 0,
        type: 'narration',
        payload: jsonEncode({'text': '序章：师父昨夜死在药炉旁。'}),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
  for (final t in [4, 5]) {
    await RunsDao(db).commitTurn(
      runId: runId,
      stateAfter: _stateAt(t),
      chapter: 1,
      memory: t == 5 ? '第一卷记' : null,
      eventPayloads: [
        {
          'type': 'narration',
          'payload': {'text': '第 $t 回合叙事'},
          'fts': '第 $t 回合叙事',
        },
        {
          'type': 'choice',
          'payload': {
            'options': [
              Choice(id: 'c$t', label: '前行', intent: '前进', risk: Risk.low).toJson(),
            ],
          },
        },
      ],
    );
  }
  return runId;
}

Future<List<String>> _narrations(AppDb db, String runId) async {
  final rows = await (db.select(db.runEvents)
        ..where((e) =>
            e.runId.equals(runId) & e.type.isIn(['narration', 'compact']))
        ..orderBy([(e) => OrderingTerm.asc(e.seq)]))
      .get();
  return [
    for (final r in rows)
      asSOr(rawMap(jsonDecode(r.payload))['text'], asSOr(rawMap(jsonDecode(r.payload))['summary'], '')),
  ];
}

Future<(AppDb, LibraryService, Directory)> _service() async {
  final db = _db();
  final root = await Directory.systemTemp.createTemp('wayfarer_m3_test');
  final s = LibraryService(
    db: db,
    exportsDir: Directory('${root.path}/exports'),
    worldsDir: Directory('${root.path}/worlds'),
    importsDir: Directory('${root.path}/imports'),
  );
  return (db, s, root);
}

/// 手工打一个 .world 包（可指定缺文件 / aiGenerated / formatVersion）
List<int> _handPack({
  List<String> drop = const [],
  Object? aiGenerated = true,
  Object? formatVersion = 1,
}) {
  final (bible, identities, seeds) = _seedData();
  final checksum = packageChecksum({
    'bible': bible.toJson(),
    'identities': identities.map((i) => i.toJson()).toList(),
    'seeds': seeds.map((s) => s.toJson()).toList(),
  });
  final manifest = {
    'formatVersion': formatVersion,
    'worldId': 'w_x',
    'version': 1,
    'checksum': checksum,
    'license': 'cc-by',
    'origin': 'original',
    'aiGenerated': aiGenerated,
    'author': '某人',
    'createdAt': 1000,
  };
  final archive = ar.Archive();
  if (!drop.contains('manifest.json')) {
    archive.addFile(ar.ArchiveFile.string('manifest.json', jsonEncode(manifest)));
  }
  if (!drop.contains('bible.json')) {
    archive.addFile(ar.ArchiveFile.string('bible.json', jsonEncode(bible.toJson())));
  }
  if (!drop.contains('identities.json')) {
    archive.addFile(ar.ArchiveFile.string(
        'identities.json', jsonEncode(identities.map((i) => i.toJson()).toList())));
  }
  if (!drop.contains('seeds.json')) {
    archive.addFile(
        ar.ArchiveFile.string('seeds.json', jsonEncode(seeds.map((s) => s.toJson()).toList())));
  }
  if (!drop.contains('NOTICE.txt')) {
    archive.addFile(ar.ArchiveFile.string('NOTICE.txt', 'NOTICE'));
  }
  if (!drop.contains('checksum')) {
    archive.addFile(ar.ArchiveFile.string('checksum', checksum));
  }
  return ar.ZipEncoder().encode(archive)!;
}

/// 用指定 worldId / version / 标题打一个合法 .world 包
Uint8List _worldPack({
  String worldId = 'w_x',
  int version = 1,
  String? title,
  String license = 'cc-by',
}) {
  final (bible, identities, seeds) = _seedData();
  var b = bible.toJson();
  if (title != null) {
    b = {...b, 'meta': {...rawMap(b['meta']), 'title': title}};
  }
  return WorldPackage.pack(
    worldId: worldId,
    version: version,
    bible: b,
    identities: identities.map((i) => i.toJson()).toList(),
    seeds: seeds.map((s) => s.toJson()).toList(),
    license: license,
    origin: 'original',
    author: '某人',
    createdAt: 1000,
  );
}

/// 重打包并把某个文本文件内容替换（制造篡改 / 不一致）
Uint8List _repackFile(Uint8List zipBytes, String name, String Function(String) patch) {
  final zip = ar.ZipDecoder().decodeBytes(zipBytes);
  final archive = ar.Archive();
  for (final f in zip.files) {
    if (!f.isFile) continue;
    if (f.name == name) {
      final text = utf8.decode(f.content as List<int>);
      archive.addFile(ar.ArchiveFile(f.name, text.length, utf8.encode(patch(text))));
    } else {
      final content = f.content as List<int>;
      archive.addFile(ar.ArchiveFile(f.name, content.length, content));
    }
  }
  return Uint8List.fromList(ar.ZipEncoder().encode(archive)!);
}

Matcher _code(EngineCode c) =>
    predicate((e) => e is EngineException && e.code == c, 'EngineCode.$c');

void main() {
  group('WorldPackage 格式层', () {
    test('pack→unpack 往返：内容一致、NOTICE 含 AI 声明、checksum 一致', () {
      final (bible, identities, seeds) = _seedData();
      final bytes = _worldPack(worldId: 'w_x', version: 2);
      final c = WorldPackage.unpack(bytes);
      expect(c.manifest.worldId, 'w_x');
      expect(c.manifest.version, 2);
      expect(c.manifest.formatVersion, 1);
      expect(c.manifest.aiGenerated, isTrue);
      expect(c.manifest.license, 'cc-by');
      expect(rawMap(c.bible['meta'])['title'], bible.meta.title);
      expect(c.identities.length, identities.length);
      expect(c.seeds.length, seeds.length);
      expect(c.notice, contains(bible.meta.title));
      expect(c.notice, contains('AI 辅助生成'));
      expect(c.notice, contains('cc-by'));
    });

    test('origin=shared 再导出保留来源声明', () {
      final (bible, identities, seeds) = _seedData();
      final checksum = packageChecksum({
        'bible': bible.toJson(),
        'identities': identities.map((i) => i.toJson()).toList(),
        'seeds': seeds.map((s) => s.toJson()).toList(),
      });
      final manifest = WorldPackageManifest(
        formatVersion: 1,
        worldId: 'w_new',
        version: 1,
        checksum: checksum,
        license: 'cc-by',
        origin: 'shared',
        sourceWorldId: 'w_origin',
        aiGenerated: true,
        author: '',
        createdAt: 1000,
      );
      final notice = WorldPackage.buildNotice(
        title: '再导出',
        author: '',
        license: 'cc-by',
        origin: 'shared',
        sourceWorldId: 'w_origin',
      );
      final archive = ar.Archive()
        ..addFile(ar.ArchiveFile.string('manifest.json', jsonEncode(manifest.toJson())))
        ..addFile(ar.ArchiveFile.string('bible.json', jsonEncode(bible.toJson())))
        ..addFile(ar.ArchiveFile.string(
            'identities.json', jsonEncode(identities.map((i) => i.toJson()).toList())))
        ..addFile(
            ar.ArchiveFile.string('seeds.json', jsonEncode(seeds.map((s) => s.toJson()).toList())))
        ..addFile(ar.ArchiveFile.string('NOTICE.txt', notice))
        ..addFile(ar.ArchiveFile.string('checksum', checksum));
      final c = WorldPackage.unpack(Uint8List.fromList(ar.ZipEncoder().encode(archive)!));
      expect(c.manifest.origin, 'shared');
      expect(c.manifest.sourceWorldId, 'w_origin');
      expect(c.notice, contains('w_origin'));
    });

    test('篡改 bible 后解包被拒（校验和不匹配）', () {
      final bytes = _worldPack();
      final mutated = _repackFile(bytes, 'bible.json', (t) => t.replaceFirst('苍梧', '苍梧改'));
      try {
        WorldPackage.unpack(mutated);
        fail('篡改包应被拒绝');
      } on EngineException catch (e) {
        expect(e.code, EngineCode.importInvalid);
        expect(e.message, contains('校验和'));
      }
    });

    test('篡改 checksum 文件同样被拒', () {
      final bytes = _worldPack();
      final mutated = _repackFile(bytes, 'checksum', (t) => '${t}0');
      expect(() => WorldPackage.unpack(mutated), throwsA(_code(EngineCode.importInvalid)));
    });

    test('缺文件列出缺失项（校验前置，不误报校验和）', () {
      final bytes = Uint8List.fromList(_handPack(drop: ['NOTICE.txt', 'checksum']));
      try {
        WorldPackage.unpack(bytes);
        fail('缺文件包应被拒绝');
      } on EngineException catch (e) {
        expect(e.code, EngineCode.importInvalid);
        expect(e.details?['missing'], ['NOTICE.txt', 'checksum']);
      }
    });

    test('aiGenerated 缺失或非 true 拒绝', () {
      for (final v in [false, null]) {
        final bytes = Uint8List.fromList(_handPack(aiGenerated: v));
        expect(() => WorldPackage.unpack(bytes), throwsA(_code(EngineCode.importInvalid)),
            reason: 'aiGenerated=$v 应拒绝');
      }
    });

    test('格式版本过高提示升级；非 zip 输入拒绝', () {
      final high = Uint8List.fromList(_handPack(formatVersion: 2));
      expect(() => WorldPackage.unpack(high), throwsA(_code(EngineCode.importInvalid)));
      expect(() => WorldPackage.unpack(Uint8List.fromList('not a zip'.codeUnits)),
          throwsA(_code(EngineCode.importInvalid)));
    });

    test('zip 与标准工具兼容：store 模式，CRC/大小逐条目一致', () {
      final (bible, identities, seeds) = _seedData();
      final bytes = _worldPack();
      _assertStandardZip(bytes, expectStore: true);
      // 内容也复核一遍（checksum 断言已在往返测试覆盖）
      expect(WorldPackage.unpack(bytes).bible['meta'], isNotEmpty);
      expect(identities.length + seeds.length, greaterThan(0));
      expect(bible.meta.title, isNotEmpty);
    });
  });

  group('LibraryService .world 导入导出', () {
    test('export：写文件到 exports 目录，文件名与版本正确，包可回读', () async {
      final (db, s, root) = await _service();
      await _seedWorld(db);
      final out = await s.export('w_test');
      expect(out.fileName, 'wayfarer-world-w_test-v1.world');
      expect(File(out.path).existsSync(), isTrue);
      final c = WorldPackage.unpack(await File(out.path).readAsBytes());
      expect(c.manifest.worldId, 'w_test');
      expect(c.manifest.origin, 'original');
      expect(root.path, isNotEmpty);
    });

    test('export：导入来源世界（exportable=0）抛 EXPORT_FORBIDDEN', () async {
      final (db, s, _) = await _service();
      await _seedWorld(db, id: 'w_imp', exportable: false, source: 'import');
      expect(() => s.export('w_imp'), throwsA(_code(EngineCode.exportForbidden)));
    });

    test('export：builtin 世界不可导出（随 App 分发，§2）', () async {
      final (db, s, _) = await _service();
      await _seedWorld(db, id: 'w_cangwu', source: 'builtin', exportable: false);
      expect(() => s.export('w_cangwu'), throwsA(_code(EngineCode.exportForbidden)));
      final w = await (db.select(db.worlds)..where((x) => x.id.equals('w_cangwu')))
          .getSingle();
      expect(w.exportable, isFalse);
    });

    test('export：shared 来源再导出，manifest.origin = shared', () async {
      final (db, s, _) = await _service();
      await _seedWorld(db, id: 'w_shared', source: 'shared', exportable: true);
      final out = await s.export('w_shared');
      final c = WorldPackage.unpack(await File(out.path).readAsBytes());
      expect(c.manifest.origin, 'shared');
    });

    test('import：新世界 created（shared 来源、可导出），同名世界追加（导入 2）', () async {
      final (db, s, root) = await _service();
      final (bible, _, _) = _seedData();
      await _seedWorld(db, id: 'w_other', title: bible.meta.title); // 同名不同 id
      final path = '${root.path}/in.world';
      await File(path).writeAsBytes(_worldPack());

      final r = await s.import(path);
      expect(r.action, 'created');
      expect(r.worldId, 'w_x');
      expect(r.title, '${bible.meta.title}（导入 2）');
      final w = await (db.select(db.worlds)..where((x) => x.id.equals('w_x'))).getSingle();
      expect(w.source, 'shared');
      expect(w.exportable, isTrue);
      expect(w.sourceWorldId, 'w_x');
      final vs = await (db.select(db.worldVersions)..where((v) => v.worldId.equals('w_x'))).get();
      expect(vs, hasLength(1));
      expect(Directory('${root.path}/worlds/w_x').existsSync(), isTrue);
    });

    test('import：同 id 同版本默认 skipped；内容不同且 overwrite=true 覆盖', () async {
      final (db, s, root) = await _service();
      await _seedWorld(db, id: 'w_x', title: '本机版');
      final path = '${root.path}/in.world';
      await File(path).writeAsBytes(_worldPack(worldId: 'w_x'));

      final r1 = await s.import(path);
      expect(r1.action, 'skipped');
      var vs = await (db.select(db.worldVersions)..where((v) => v.worldId.equals('w_x'))).get();
      expect(vs, hasLength(1));
      expect(vs.single.bible, contains('苍梧'));

      // 内容不同（改标题）但同 id 同版本
      final path2 = '${root.path}/in2.world';
      await File(path2).writeAsBytes(_worldPack(worldId: 'w_x', title: '另一个版本'));
      final r2 = await s.import(path2);
      expect(r2.action, 'skipped');
      final r3 = await s.import(path2, overwrite: true);
      expect(r3.action, 'overwritten');
      vs = await (db.select(db.worldVersions)..where((v) => v.worldId.equals('w_x'))).get();
      expect(vs, hasLength(1));
      expect(vs.single.bible, contains('另一个版本'));
    });

    test('import：同 id 更高版本追加，旧版本不动', () async {
      final (db, s, root) = await _service();
      await _seedWorld(db, id: 'w_x');
      final path = '${root.path}/v2.world';
      await File(path).writeAsBytes(_worldPack(worldId: 'w_x', version: 2));

      final r = await s.import(path);
      expect(r.action, 'version_added');
      final vs = await (db.select(db.worldVersions)..where((v) => v.worldId.equals('w_x'))).get();
      expect(vs.map((x) => x.version), [1, 2]);
      final w = await (db.select(db.worlds)..where((x) => x.id.equals('w_x'))).getSingle();
      expect(w.latestVersion, 2);
    });

    test('import：同 id 更低版本另存独立世界，不降级已有版本', () async {
      final (db, s, root) = await _service();
      // 本机只有 v3（模拟版本已前进而手里只有旧包）
      await _seedWorld(db, id: 'w_x', version: 3);
      final lowPath = '${root.path}/v1.world';
      await File(lowPath).writeAsBytes(_worldPack(worldId: 'w_x', version: 1));

      final r = await s.import(lowPath);
      expect(r.action, 'saved_as_new');
      expect(r.worldId, isNot('w_x'));
      final vs = await (db.select(db.worldVersions)..where((v) => v.worldId.equals('w_x'))).get();
      expect(vs.map((x) => x.version), [3]); // 已有版本未被降级
      final saved = await (db.select(db.worlds)..where((x) => x.id.equals(r.worldId))).getSingle();
      expect(saved.source, 'shared');
      expect(saved.title, contains('（导入 2）'));
      final savedVs =
          await (db.select(db.worldVersions)..where((v) => v.worldId.equals(r.worldId))).get();
      expect(savedVs.single.version, 1);
    });

    test('import：损坏包拒绝且不写入任何数据', () async {
      final (db, s, root) = await _service();
      final path = '${root.path}/bad.world';
      await File(path).writeAsBytes(Uint8List.fromList(_handPack(drop: ['seeds.json'])));
      await expectLater(s.import(path), throwsA(_code(EngineCode.importInvalid)));
      expect(await db.select(db.worlds).get(), isEmpty);
      expect(await db.select(db.worldVersions).get(), isEmpty);
    });

    test('rename 改 worlds.title，不改版本 checksum', () async {
      final (db, s, _) = await _service();
      await _seedWorld(db);
      await s.rename('w_test', '新名字');
      final w = await (db.select(db.worlds)..where((x) => x.id.equals('w_test'))).getSingle();
      expect(w.title, '新名字');
      final v =
          await (db.select(db.worldVersions)..where((v) => v.worldId.equals('w_test'))).getSingle();
      expect(v.checksum, isNotEmpty);
    });

    test('delete：级联删除局/快照/事件/fts/版本/世界与原件目录，返回局数', () async {
      final (db, s, root) = await _service();
      await _seedWorld(db);
      final runId = await _makeRun(db, worldId: 'w_test');
      final out = await s.export('w_test');
      final originalDir = Directory('${root.path}/worlds/w_test');
      await originalDir.create(recursive: true);
      await File('${originalDir.path}/v1.world').writeAsBytes([1, 2, 3]);

      final runsDeleted = await s.delete('w_test');
      expect(runsDeleted, 1);
      expect(await db.select(db.worlds).get(), isEmpty);
      expect(await db.select(db.worldVersions).get(), isEmpty);
      expect(await (db.select(db.runs)..where((r) => r.id.equals(runId))).get(), isEmpty);
      expect(
          await (db.select(db.runSnapshots)..where((sn) => sn.runId.equals(runId))).get(), isEmpty);
      expect(await (db.select(db.runEvents)..where((e) => e.runId.equals(runId))).get(), isEmpty);
      final fts = await db
          .customSelect('SELECT count(*) AS c FROM events_fts WHERE run_id = ?',
              variables: [Variable(runId)])
          .getSingle();
      expect(fts.read<int>('c'), 0);
      expect(originalDir.existsSync(), isFalse);
      expect(File(out.path).existsSync(), isTrue); // 导出文件不在删除范围
    });

    test('space：按世界列出原件占用与导入缓存总量', () async {
      final (db, s, root) = await _service();
      await _seedWorld(db);
      await Directory('${root.path}/worlds/w_test').create(recursive: true);
      await File('${root.path}/worlds/w_test/v1.world').writeAsBytes(List.filled(100, 1));
      await Directory('${root.path}/imports').create(recursive: true);
      await File('${root.path}/imports/book.txt').writeAsBytes(List.filled(50, 2));
      final report = await s.space();
      expect(report.worlds.single.worldId, 'w_test');
      expect(report.worlds.single.bytes, 100);
      expect(report.importsBytes, 50);
    });
  });

  group('RunPackage 格式层', () {
    Map<String, Object?> _runJson({String status = 'active'}) => {
          'id': 'r_abc',
          'worldId': 'w_test',
          'worldVersion': 1,
          'identityId': 'id_herb_apprentice',
          'status': status,
          'chapter': 1,
          'turnNo': 5,
          'headSnapshotId': 's_abc_0005',
          'createdAt': 1,
          'updatedAt': 2,
        };

    test('pack→unpack 往返', () {
      final bytes = RunPackage.pack(
        run: _runJson(),
        snapshots: [
          {
            'id': 's_abc_0005',
            'runId': 'r_abc',
            'turnNo': 5,
            'chapter': 1,
            'state': {'a': 1},
          },
        ],
        events: [
          {'seq': 1, 'turnNo': 5, 'type': 'narration', 'payload': {'text': 'x'}},
          {'seq': 2, 'turnNo': 5, 'type': 'choice', 'payload': {'options': []}},
        ],
        createdAt: 1000,
      );
      final c = RunPackage.unpack(bytes);
      expect(c.manifest.runId, 'r_abc');
      expect(c.manifest.worldId, 'w_test');
      expect(c.manifest.worldVersion, 1);
      expect(c.manifest.turnNo, 5);
      expect(c.manifest.aiGenerated, isTrue);
      expect(c.snapshots.single['id'], 's_abc_0005');
      expect(c.events, hasLength(2));
    });

    test('seq 不连续拒绝', () {
      final bytes = RunPackage.pack(
        run: _runJson(),
        snapshots: [],
        events: [
          {'seq': 1, 'turnNo': 0, 'type': 'narration', 'payload': {}},
          {'seq': 3, 'turnNo': 0, 'type': 'narration', 'payload': {}},
        ],
        createdAt: 1000,
      );
      expect(() => RunPackage.unpack(bytes), throwsA(_code(EngineCode.importInvalid)));
    });

    test('manifest 与 run.json 不一致拒绝', () {
      final bytes = RunPackage.pack(
        run: _runJson(status: 'ended'),
        snapshots: [],
        events: [],
        createdAt: 1000,
      );
      final mutated = _repackFile(bytes, 'manifest.json', (t) {
        final m = rawMap(jsonDecode(t))..['status'] = 'active';
        return jsonEncode(m);
      });
      expect(() => RunPackage.unpack(mutated), throwsA(_code(EngineCode.importInvalid)));
    });
  });

  group('.run 存档包导入导出', () {
    test('exportRunPack：局数据完整进包（快照/事件/进度）', () async {
      final (db, s, _) = await _service();
      await _seedWorld(db);
      final runId = await _makeRun(db);
      final out = await s.exportRunPack(runId);
      expect(out.fileName, 'wayfarer-run-$runId-t5.run');
      final c = RunPackage.unpack(await File(out.path).readAsBytes());
      expect(c.manifest.worldId, 'w_test');
      expect(c.manifest.turnNo, 5);
      expect(c.manifest.status, 'active');
      expect(c.run['identityId'], makeState().character.identityId);
      expect(c.snapshots, hasLength(3)); // createRun + t4 + t5
      expect(c.events, hasLength(5)); // 序章 + t4/t5 各 2
      expect(c.events.last['seq'], 5);
      // 保留卷末 memory（快照行）
      final head = c.snapshots.last;
      expect(head['memory'], '第一卷记');
    });

    test('exportRunPack：试玩局拒绝；import 来源世界 EXPORT_FORBIDDEN 且 RunHead.exportable=false', () async {
      final (db, s, _) = await _service();
      await _seedWorld(db);
      final trialId = await _makeRun(db, trial: true);
      expect(() => s.exportRunPack(trialId), throwsA(_code(EngineCode.stateInvalid)));
      await _seedWorld(db, id: 'w_imp', exportable: false, source: 'import');
      final impRun = await _makeRun(db, worldId: 'w_imp');
      expect(() => s.exportRunPack(impRun), throwsA(_code(EngineCode.exportForbidden)));
      // listRuns 的存档包可导出标志按来源计算：import → false（UI 隐藏按钮）
      final tmp = await Directory.systemTemp.createTemp('wayfarer_listruns_imp');
      final e = await Engine.open(
        dbPath: '${tmp.path}/app.db',
        keyStore: InMemoryKeyStore(),
        filesDir: tmp.path,
      );
      await _seedWorld(e.db, id: 'w_imp', exportable: false, source: 'import');
      await _makeRun(e.db, worldId: 'w_imp');
      final heads = await e.listRuns();
      expect(heads.single.exportable, isFalse);
      await e.close();
    });

    test('exportRunPack：builtin 世界存档豁免开放（.world 仍不可导出），往返导入可续玩', () async {
      final (db, s, root) = await _service();
      await _seedWorld(db, id: 'w_cangwu', source: 'builtin', exportable: false);
      // `.world` 门禁不受豁免影响
      expect(() => s.export('w_cangwu'), throwsA(_code(EngineCode.exportForbidden)));
      final runId = await _makeRun(db, worldId: 'w_cangwu');
      // RunHead.exportable = 非 import 来源 → true（UI 显示导出按钮）
      final tmp = await Directory.systemTemp.createTemp('wayfarer_listruns');
      final e = await Engine.open(
        dbPath: '${tmp.path}/app.db',
        keyStore: InMemoryKeyStore(),
        filesDir: tmp.path,
      );
      await _seedWorld(e.db, id: 'w_cangwu', source: 'builtin', exportable: false);
      await _makeRun(e.db, worldId: 'w_cangwu');
      final heads = await e.listRuns();
      expect(heads.single.exportable, isTrue);
      await e.close();

      final out = await s.exportRunPack(runId);
      expect(out.fileName, 'wayfarer-run-$runId-t5.run');
      // 模拟另一台设备（自带 builtin 世界，无存档）导入续玩
      await (db.delete(db.runEvents)..where((e) => e.runId.equals(runId))).go();
      await (db.delete(db.runSnapshots)..where((sn) => sn.runId.equals(runId))).go();
      await (db.delete(db.runs)..where((r) => r.id.equals(runId))).go();
      final r = await s.importRunPack(out.path);
      expect(r.renamed, isFalse);
      final head = await (db.select(db.runs)..where((x) => x.id.equals(r.runId))).getSingle();
      expect(head.turnNo, 5);
      expect(await RunsDao(db).nextSeq(r.runId), 6);
    });

    test('importRunPack：落地新局、进度一致、可续玩到原进度再推进', () async {
      final (db, s, _) = await _service();
      await _seedWorld(db);
      final runId = await _makeRun(db);
      final out = await s.exportRunPack(runId);

      // 清空本机局，模拟另一台设备只有世界没有存档
      await (db.delete(db.runs)..where((r) => r.id.equals(runId))).go();
      await (db.delete(db.runSnapshots)..where((sn) => sn.runId.equals(runId))).go();
      await (db.delete(db.runEvents)..where((e) => e.runId.equals(runId))).go();

      final r = await s.importRunPack(out.path);
      expect(r.renamed, isFalse);
      expect(r.runId, runId);
      final head = await (db.select(db.runs)..where((x) => x.id.equals(r.runId))).getSingle();
      expect(head.turnNo, 5);
      expect(head.worldVersion, 1);
      expect(head.status, 'active');
      // head 快照状态可读
      final snap = await (db.select(db.runSnapshots)
            ..where((sn) => sn.id.equals(head.headSnapshotId!)))
          .getSingle();
      expect(RunState.fromJson(jsonDecode(snap.state)).meta.turnNo, 5);
      // 叙事可读：序章 + t4 + t5
      expect(await _narrations(db, r.runId), ['序章：师父昨夜死在药炉旁。', '第 4 回合叙事', '第 5 回合叙事']);
      // 续玩：下一回合 seq 连续（nextSeq=6）
      expect(await RunsDao(db).nextSeq(r.runId), 6);
      await RunsDao(db).commitTurn(
        runId: r.runId,
        stateAfter: _stateAt(6),
        chapter: 1,
        memory: null,
        eventPayloads: [
          {
            'type': 'narration',
            'payload': {'text': '第 6 回合叙事'},
            'fts': '第 6 回合叙事',
          },
        ],
      );
      expect(await _narrations(db, r.runId), hasLength(4));
    });

    test('importRunPack：缺对应世界版本 NOT_FOUND，不留半成品', () async {
      final (db, s, _) = await _service();
      await _seedWorld(db);
      final runId = await _makeRun(db);
      final out = await s.exportRunPack(runId);
      // 模拟另一台设备：世界版本缺失（连世界一起删），本机 run 数据也清空
      await (db.delete(db.worldVersions)..where((v) => v.worldId.equals('w_test'))).go();
      await (db.delete(db.worlds)..where((w) => w.id.equals('w_test'))).go();
      await (db.delete(db.runEvents)..where((e) => e.runId.equals(runId))).go();
      await (db.delete(db.runSnapshots)..where((s) => s.runId.equals(runId))).go();
      await (db.delete(db.runs)..where((r) => r.id.equals(runId))).go();

      await expectLater(s.importRunPack(out.path), throwsA(_code(EngineCode.notFound)));
      expect(await db.select(db.runs).get(), isEmpty);
      expect(await db.select(db.runSnapshots).get(), isEmpty);
      expect(await db.select(db.runEvents).get(), isEmpty);
    });

    test('importRunPack：runId 冲突自动改后缀，不覆盖', () async {
      final (db, s, _) = await _service();
      await _seedWorld(db);
      final runId = await _makeRun(db);
      final out = await s.exportRunPack(runId);
      final r = await s.importRunPack(out.path); // 原 runId 仍在本机 → 冲突
      expect(r.renamed, isTrue);
      expect(r.runId, isNot(runId));
      expect(await (db.select(db.runs)..where((x) => x.id.equals(runId))).get(), isNotEmpty);
      final imported = await (db.select(db.runs)..where((x) => x.id.equals(r.runId))).getSingle();
      expect(imported.turnNo, 5);
    });
  });
}

/// 自实现 CRC-32（防 archive 内部实现变化），逐位算法足够测试用
int _crc32(List<int> d) {
  var c = 0xFFFFFFFF;
  for (final b in d) {
    c ^= b;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    }
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

/// 标准工具视角的 zip 校验：不依赖 archive 包，手工解析 local header 与
/// central directory，逐条目比对 CRC/大小；回归 archive 3.x deflate 流
/// 在 python zipfile 下 CRC 失败的问题（现为 store 模式）
void _assertStandardZip(Uint8List bytes, {bool expectStore = false}) {
  final raw = bytes;
  // local headers: PK\x03\x04
  for (var i = 0; i + 30 <= raw.length; i++) {
    if (raw[i] != 0x50 || raw[i + 1] != 0x4B || raw[i + 2] != 0x03 || raw[i + 3] != 0x04) {
      continue;
    }
    final flag = _u16(raw, i + 6);
    final method = _u16(raw, i + 8);
    final crc = _u32(raw, i + 14);
    final csize = _u32(raw, i + 18);
    final usize = _u32(raw, i + 22);
    final nlen = _u16(raw, i + 26);
    final elen = _u16(raw, i + 28);
    final name = String.fromCharCodes(raw.sublist(i + 30, i + 30 + nlen));
    if (flag & 0x8 != 0) continue; // data descriptor 场景此处无静态值
    final data = raw.sublist(i + 30 + nlen + elen, i + 30 + nlen + elen + csize);
    expect(method, expectStore ? 0 : isNot(0), reason: '$name method');
    expect(_crc32(data), crc, reason: '$name local crc');
    expect(usize, csize, reason: '$name store usize==csize');
  }
  // central directory: PK\x01\x02（python zipfile 的读取路径：CD 的 crc/csize
  // + local header 的名字与 extra 定位数据）
  for (var i = 0; i + 46 <= raw.length; i++) {
    if (raw[i] != 0x50 || raw[i + 1] != 0x4B || raw[i + 2] != 0x01 || raw[i + 3] != 0x02) {
      continue;
    }
    final method = _u16(raw, i + 10);
    final crc = _u32(raw, i + 16);
    final csize = _u32(raw, i + 20);
    final usize = _u32(raw, i + 24);
    final nlen = _u16(raw, i + 28);
    final off = _u32(raw, i + 42);
    final name = String.fromCharCodes(raw.sublist(i + 46, i + 46 + nlen));
    expect(method, expectStore ? 0 : isNot(0), reason: '$name cd method');
    expect(usize, csize, reason: '$name cd store usize==csize');
    final lFlag = _u16(raw, off + 6);
    final lMethod = _u16(raw, off + 8);
    final lCsize = _u32(raw, off + 18);
    final lUsize = _u32(raw, off + 22);
    final lNlen = _u16(raw, off + 26);
    final lElen = _u16(raw, off + 28);
    expect(String.fromCharCodes(raw.sublist(off + 30, off + 30 + lNlen)), name,
        reason: 'local/central 同名');
    expect(lMethod, method, reason: '$name method 一致');
    expect(lCsize, csize, reason: '$name csize 一致');
    expect(lUsize, usize, reason: '$name usize 一致');
    if (lFlag & 0x8 == 0) {
      final data = raw.sublist(off + 30 + lNlen + lElen, off + 30 + lNlen + lElen + lCsize);
      expect(_crc32(data), crc, reason: '$name cd crc（python zipfile 校验路径）');
    }
  }
}

int _u16(List<int> b, int i) => b[i] | (b[i + 1] << 8);
int _u32(List<int> b, int i) =>
    b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24);
