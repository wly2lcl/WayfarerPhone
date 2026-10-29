import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:contracts/contracts.dart';
import 'package:drift/drift.dart';

import '../data/app_db.dart';
import '../data/flags.dart';
import '../errors.dart';
import 'checksum.dart';
import 'run_package.dart';
import 'world_package.dart';

class ExportedFile {
  final String path;
  final String fileName;
  final int bytes;
  ExportedFile({required this.path, required this.fileName, required this.bytes});
}

/// 导入落库动作（世界分享与UGC §6 冲突表）：
/// created 新世界 / version_added 追加更高版本 / saved_as_new 更低版本另存 /
/// skipped 同版本默认跳过 / overwritten 手动覆盖
class WorldImportResult {
  final String worldId;
  final int version;
  final String title;
  final String action;
  WorldImportResult({required this.worldId, required this.version, required this.title, required this.action});
}

class RunImportResult {
  final String runId;
  final bool renamed; // runId 冲突自动改后缀
  RunImportResult({required this.runId, required this.renamed});
}

class WorldSpaceEntry {
  final String worldId;
  final String title;
  final int bytes; // files/worlds/<worldId>/ 导入原件占用
  WorldSpaceEntry({required this.worldId, required this.title, required this.bytes});
}

class SpaceReport {
  final List<WorldSpaceEntry> worlds;
  final int importsBytes; // 导入原文缓存（files/imports）
  SpaceReport({required this.worlds, required this.importsBytes});
}

/// 本地世界库（世界分享与UGC §6/§8/§9；API 参考 §3 library.* / runs.exportPack/importPack）
class LibraryService {
  final AppDb db;
  final Directory exportsDir; // files/exports
  final Directory worldsDir; // files/worlds（导入原件，私有）
  final Directory? importsDir; // files/imports（M2 导入原文缓存，仅统计）
  final Random random;

  LibraryService({
    required this.db,
    required this.exportsDir,
    required this.worldsDir,
    this.importsDir,
    Random? random,
  }) : random = random ?? Random.secure();

  /// 青少年模式（合规与内容安全 §5）：导入与导出入口一律不可用（TODO WF-LAUNCH-04 验收）
  Future<void> _ensureNotTeen(String action) async {
    if (await AppFlags(db).teenModeOn()) {
      throw EngineException(EngineCode.stateInvalid, '青少年模式下不可$action');
    }
  }

  // ---- .world 导出（WF-M3-02-01）----

  Future<ExportedFile> export(String worldId) async {
    await _ensureNotTeen('导出');
    final w = await _world(worldId);
    if (!w.exportable) {
      throw EngineException(EngineCode.exportForbidden, '导入来源的世界不可导出（exportable = 0）');
    }
    final versions = await _versionsOf(worldId);
    if (versions.isEmpty) {
      throw EngineException(EngineCode.notFound, '世界尚无冻结版本');
    }
    final latest = versions.reduce((a, b) => a.version > b.version ? a : b);
    final bytes = WorldPackage.pack(
      worldId: worldId,
      version: latest.version,
      bible: rawMap(jsonDecode(latest.bible)),
      identities: _listOf(jsonDecode(latest.identities)),
      seeds: _listOf(jsonDecode(latest.seeds)),
      license: w.license,
      origin: w.source == 'shared' ? 'shared' : 'original',
      sourceWorldId: w.sourceWorldId,
      author: w.author ?? '',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      title: w.title,
    );
    return _writeExport(bytes, 'wayfarer-world-$worldId-v${latest.version}.world');
  }

  // ---- .world 导入（WF-M3-02-02，§6 校验与冲突表）----

  Future<WorldImportResult> import(String filePath, {bool overwrite = false}) async {
    await _ensureNotTeen('导入');
    final f = File(filePath);
    if (!await f.exists()) {
      throw EngineException(EngineCode.notFound, '文件不存在');
    }
    final contents = WorldPackage.unpack(await f.readAsBytes());
    final manifest = contents.manifest;
    try {
      WorldBible.fromJson(contents.bible);
      asList<Identity>(contents.identities, Identity.fromJson);
      asList<EventSeed>(contents.seeds, EventSeed.fromJson);
    } on EngineException {
      rethrow;
    } catch (e) {
      throw EngineException(EngineCode.importInvalid, '包内数据字段错误',
          details: {'error': e.toString()});
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final meta = rawMap(contents.bible['meta']);
    final packageTitle = asSOr(meta['title'], manifest.worldId);
    final internalCk = internalWorldChecksum(contents.bible, contents.identities, contents.seeds);
    final existing = await (db.select(db.worlds)
          ..where((x) => x.id.equals(manifest.worldId)))
        .getSingleOrNull();

    var worldId = manifest.worldId;
    var title = packageTitle;
    var action = 'created';

    if (existing == null) {
      title = await _dedupeTitle(packageTitle);
      await db.transaction(() async {
        await db.into(db.worlds).insert(_worldRow(
              worldId: worldId,
              title: title,
              meta: meta,
              manifest: manifest,
              latestVersion: manifest.version,
              now: now,
            ));
        await _insertVersion(worldId, manifest.version, contents, internalCk, now);
      });
    } else {
      final versions = await _versionsOf(worldId);
      final same = versions.where((v) => v.version == manifest.version).firstOrNull;
      if (same != null) {
        if (same.checksum == internalCk) {
          return WorldImportResult(
              worldId: worldId, version: manifest.version, title: existing.title, action: 'skipped');
        }
        if (!overwrite) {
          return WorldImportResult(
              worldId: worldId, version: manifest.version, title: existing.title, action: 'skipped');
        }
        action = 'overwritten';
        title = existing.title;
        await db.transaction(() async {
          await (db.delete(db.worldVersions)..where((v) => v.id.equals(same.id))).go();
          await _insertVersion(worldId, manifest.version, contents, internalCk, now);
          await (db.update(db.worlds)..where((x) => x.id.equals(worldId)))
              .write(WorldsCompanion(updatedAt: Value(now)));
        });
      } else {
        final maxLocal = versions.map((v) => v.version).reduce(max);
        if (manifest.version > maxLocal) {
          action = 'version_added';
          title = existing.title;
          await db.transaction(() async {
            await _insertVersion(worldId, manifest.version, contents, internalCk, now);
            await (db.update(db.worlds)..where((x) => x.id.equals(worldId))).write(
                WorldsCompanion(latestVersion: Value(manifest.version), updatedAt: Value(now)));
          });
        } else {
          // 同 id 更低版本：另存为独立世界，不降级已有版本
          action = 'saved_as_new';
          worldId = 'w_${now.toRadixString(36)}_${random.nextInt(0xFFF).toRadixString(36)}';
          title = await _dedupeTitle('$packageTitle（导入 2）');
          await db.transaction(() async {
            await db.into(db.worlds).insert(_worldRow(
                  worldId: worldId,
                  title: title,
                  meta: meta,
                  manifest: manifest,
                  latestVersion: manifest.version,
                  now: now,
                ));
            await _insertVersion(worldId, manifest.version, contents, internalCk, now);
          });
        }
      }
    }

    // 导入原件（私有）落 files/worlds/<worldId>/；DB 已成功，文件失败仅忽略
    try {
      final dir = Directory('${worldsDir.path}/$worldId');
      await dir.create(recursive: true);
      await File('${dir.path}/v${manifest.version}.world')
          .writeAsBytes(await f.readAsBytes(), flush: true);
    } catch (_) {}
    return WorldImportResult(worldId: worldId, version: manifest.version, title: title, action: action);
  }

  // ---- 世界库管理（WF-M3-03-01）----

  Future<void> rename(String worldId, String title) async {
    await _world(worldId);
    await (db.update(db.worlds)..where((x) => x.id.equals(worldId)))
        .write(WorldsCompanion(title: Value(title), updatedAt: Value(DateTime.now().millisecondsSinceEpoch)));
  }

  /// 级联删除世界、版本、全部存档（局/快照/事件/检索索引）与导入原件；
  /// UI 层负责有存档时的二次确认。返回删除的局数。
  Future<int> delete(String worldId) async {
    await _world(worldId);
    final runs = await (db.select(db.runs)..where((r) => r.worldId.equals(worldId))).get();
    final runIds = runs.map((r) => r.id).toList();
    await db.transaction(() async {
      if (runIds.isNotEmpty) {
        await (db.delete(db.runSnapshots)..where((s) => s.runId.isIn(runIds))).go();
        await (db.delete(db.runEvents)..where((e) => e.runId.isIn(runIds))).go();
        for (final id in runIds) {
          await db.customStatement('DELETE FROM events_fts WHERE run_id = ?', [id]);
        }
        await (db.delete(db.runs)..where((r) => r.id.isIn(runIds))).go();
      }
      await (db.delete(db.worldVersions)..where((v) => v.worldId.equals(worldId))).go();
      await (db.delete(db.worlds)..where((x) => x.id.equals(worldId))).go();
    });
    try {
      await Directory('${worldsDir.path}/$worldId').delete(recursive: true);
    } catch (_) {}
    return runIds.length;
  }

  Future<SpaceReport> space() async {
    final rows = await db.select(db.worlds).get();
    final entries = <WorldSpaceEntry>[];
    for (final w in rows) {
      entries.add(WorldSpaceEntry(
        worldId: w.id,
        title: w.title,
        bytes: await _dirSize(Directory('${worldsDir.path}/${w.id}')),
      ));
    }
    return SpaceReport(worlds: entries, importsBytes: await _dirSize(importsDir));
  }

  // ---- .run 存档包导出（WF-M3-04-01）----

  /// 存档包可导出口径：绑定世界非 import 来源（世界分享与UGC §4）。
  /// builtin 世界随 App 分发、`.world` 不可导出，但其存档 `.run` 豁免开放（跨设备续玩）；
  /// 导入来源（source = import）世界仍 EXPORT_FORBIDDEN。
  Future<ExportedFile> exportRunPack(String runId) async {
    await _ensureNotTeen('导出');
    final r = await (db.select(db.runs)..where((x) => x.id.equals(runId))).getSingleOrNull();
    if (r == null) throw EngineException(EngineCode.notFound, '局不存在');
    if (r.isTrial) {
      throw EngineException(EngineCode.stateInvalid, '试玩局不可导出');
    }
    final w = await _world(r.worldId);
    if (w.source == 'import') {
      throw EngineException(EngineCode.exportForbidden, '导入来源世界的存档不可导出（版权约束）');
    }
    final snapshots = await (db.select(db.runSnapshots)
          ..where((s) => s.runId.equals(runId))
          ..orderBy([(s) => OrderingTerm.asc(s.turnNo)]))
        .get();
    final events = await (db.select(db.runEvents)
          ..where((e) => e.runId.equals(runId))
          ..orderBy([(e) => OrderingTerm.asc(e.seq)]))
        .get();
    final run = {
      'id': r.id,
      'worldId': r.worldId,
      'worldVersion': r.worldVersion,
      'identityId': r.identityId,
      'status': r.status,
      'chapter': r.chapter,
      'turnNo': r.turnNo,
      'headSnapshotId': r.headSnapshotId,
      'endingId': r.endingId,
      'createdAt': r.createdAt,
      'updatedAt': r.updatedAt,
    };
    final snapRows = [
      for (final s in snapshots)
        {
          'id': s.id,
          'runId': s.runId,
          'turnNo': s.turnNo,
          'chapter': s.chapter,
          'parentSnapshotId': s.parentSnapshotId,
          'state': jsonDecode(s.state),
          'memory': s.memory,
          'createdAt': s.createdAt,
        },
    ];
    final eventRows = [
      for (final e in events)
        {
          'seq': e.seq,
          'turnNo': e.turnNo,
          'type': e.type,
          'payload': jsonDecode(e.payload),
          'createdAt': e.createdAt,
        },
    ];
    final bytes = RunPackage.pack(
      run: run,
      snapshots: snapRows,
      events: eventRows,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    return _writeExport(bytes, 'wayfarer-run-$runId-t${r.turnNo}.run');
  }

  // ---- .run 存档包导入（WF-M3-04-02）----

  Future<RunImportResult> importRunPack(String filePath) async {
    await _ensureNotTeen('导入');
    final f = File(filePath);
    if (!await f.exists()) {
      throw EngineException(EngineCode.notFound, '文件不存在');
    }
    final contents = RunPackage.unpack(await f.readAsBytes());
    final m = contents.manifest;

    // 先 checksum（unpack 内）再查本机世界版本；缺世界拒绝导入且不留半成品，
    // 不允许自动升级到新版本（世界分享与UGC §3.1 硬规则）
    final version = await (db.select(db.worldVersions)
          ..where((v) =>
              v.worldId.equals(m.worldId) & v.version.equals(m.worldVersion)))
        .getSingleOrNull();
    if (version == null) {
      throw EngineException(
        EngineCode.notFound,
        '本机没有该存档对应的世界版本（${m.worldId} v${m.worldVersion}），请先导入对应 .world 包',
      );
    }

    // runId 冲突自动改后缀，不覆盖（世界分享与UGC §3.1）
    var runId = m.runId;
    var renamed = false;
    var n = 2;
    while (await (db.select(db.runs)..where((r) => r.id.equals(runId))).getSingleOrNull() !=
        null) {
      runId = '${m.runId}_$n';
      renamed = true;
      n++;
    }

    // 快照 id 按新 runId 重写（commitTurn 同构）；分叉谱系引用不随迁移保留
    final newSnapshotIds = <String, String>{};
    for (final s in contents.snapshots) {
      final oldId = asSOr(s['id'], '');
      newSnapshotIds[oldId] =
          's_${runId.substring(2)}_${asIOr(s['turnNo'], 0).toString().padLeft(4, '0')}_i${newSnapshotIds.length}';
    }
    final headId = asSOr(contents.run['headSnapshotId'], '');
    final newHeadId = newSnapshotIds[headId] ??
        (contents.snapshots.isEmpty
            ? null
            : newSnapshotIds[asSOr(contents.snapshots.last['id'], '')]);
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction(() async {
      await db.into(db.runs).insert(RunsCompanion.insert(
            id: runId,
            worldId: m.worldId,
            worldVersion: m.worldVersion,
            identityId: m.identityId,
            status: Value(m.status),
            chapter: Value(m.chapter),
            turnNo: Value(m.turnNo),
            headSnapshotId: Value(newHeadId),
            endingId: Value(m.endingId),
            createdAt: now,
            updatedAt: now,
          ));
      for (final s in contents.snapshots) {
        final oldId = asSOr(s['id'], '');
        await db.into(db.runSnapshots).insert(RunSnapshotsCompanion.insert(
              id: newSnapshotIds[oldId]!,
              runId: runId,
              turnNo: asIOr(s['turnNo'], 0),
              chapter: asIOr(s['chapter'], 1),
              parentSnapshotId: const Value(null),
              state: jsonEncode(s['state']),
              memory: Value(asSOr(s['memory'], '') == '' ? null : asSOr(s['memory'], '')),
              createdAt: now,
            ));
      }
      var seq = 0;
      for (final e in contents.events) {
        seq++;
        final type = asSOr(e['type'], 'system');
        final payload = rawMap(e['payload']);
        await db.into(db.runEvents).insert(RunEventsCompanion.insert(
              runId: runId,
              seq: seq,
              turnNo: asIOr(e['turnNo'], 0),
              type: type,
              payload: jsonEncode(payload),
              createdAt: now,
            ));
        // 检索索引按原 payload 重建（narration 正文 / compact 卷记）
        final text = asSOr(payload['text'], asSOr(payload['summary'], ''));
        if (text.isNotEmpty) {
          await db.customStatement(
            'INSERT INTO events_fts (run_id, turn_no, text) VALUES (?, ?, ?)',
            [runId, asIOr(e['turnNo'], 0), text],
          );
        }
      }
    });
    return RunImportResult(runId: runId, renamed: renamed);
  }

  // ---- 内部 ----

  Future<World> _world(String worldId) async {
    final w = await (db.select(db.worlds)..where((x) => x.id.equals(worldId)))
        .getSingleOrNull();
    if (w == null) throw EngineException(EngineCode.notFound, '世界不存在');
    return w;
  }

  Future<List<WorldVersion>> _versionsOf(String worldId) =>
      (db.select(db.worldVersions)..where((v) => v.worldId.equals(worldId))).get();

  Future<void> _insertVersion(String worldId, int version,
      WorldPackageContents contents, String internalCk, int now) async {
    await db.into(db.worldVersions).insert(WorldVersionsCompanion.insert(
          id: 'wv_${worldId}_v$version',
          worldId: worldId,
          version: version,
          bible: jsonEncode(contents.bible),
          identities: jsonEncode(contents.identities),
          seeds: jsonEncode(contents.seeds),
          checksum: internalCk,
          createdAt: now,
        ));
  }

  WorldsCompanion _worldRow({
    required String worldId,
    required String title,
    required Map<String, Object?> meta,
    required WorldPackageManifest manifest,
    required int latestVersion,
    required int now,
  }) {
    return WorldsCompanion.insert(
      id: worldId,
      title: title,
      genre: asSOr(meta['genre'], '未分类'),
      summary: Value(asSOr(meta['summary'], '')),
      source: 'shared',
      license: Value(manifest.license),
      author: Value(manifest.author),
      sourceWorldId: Value(manifest.sourceWorldId ?? manifest.worldId),
      latestVersion: Value(latestVersion),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 同名世界（不同 id）追加「（导入 N）」，两者都保留
  Future<String> _dedupeTitle(String title) async {
    final titles = (await db.select(db.worlds).get()).map((w) => w.title).toSet();
    if (!titles.contains(title)) return title;
    for (var n = 2;; n++) {
      final candidate = '$title（导入 $n）';
      if (!titles.contains(candidate)) return candidate;
    }
  }

  Future<ExportedFile> _writeExport(Uint8List bytes, String fileName) async {
    await exportsDir.create(recursive: true);
    final path = '${exportsDir.path}/$fileName';
    await File(path).writeAsBytes(bytes, flush: true);
    return ExportedFile(path: path, fileName: fileName, bytes: bytes.length);
  }

  Future<int> _dirSize(Directory? dir) async {
    if (dir == null || !await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }
}

List<Object?> _listOf(Object? v) => v is List ? v.toList() : <Object?>[];
