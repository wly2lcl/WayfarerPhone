import 'dart:convert';

import 'package:contracts/contracts.dart';
import 'package:drift/drift.dart';

import 'app_db.dart';

class RunHead {
  final String id;
  final String worldId;
  final int worldVersion;
  final String identityId;
  final String status;
  final int chapter;
  final int turnNo;
  final String? headSnapshotId;
  final String? endingId;

  /// 仅 listRuns 填充：按世界版本 bible 解析出的终局名（展示用）
  final String? endingTitle;

  /// 该局 `.run` 存档包可导出（false 时 UI 隐藏导出入口）。
  /// 口径：绑定世界非 import 来源（世界分享与UGC §4）——builtin 世界 `.world`
  /// 不可导出但其存档豁免开放，import 来源仍禁止
  final bool exportable;
  final bool isTrial;
  final String? draftId;
  final RunState? state;

  RunHead({
    required this.id,
    required this.worldId,
    required this.worldVersion,
    required this.identityId,
    required this.status,
    required this.chapter,
    required this.turnNo,
    this.headSnapshotId,
    this.endingId,
    this.endingTitle,
    this.exportable = true,
    this.isTrial = false,
    this.draftId,
    this.state,
  });
}

/// 世界线分叉候选：一个历史回合快照（API 参考 runs.branch）
class SnapshotBrief {
  final String id;
  final int turnNo;
  final int chapter;

  SnapshotBrief({required this.id, required this.turnNo, required this.chapter});
}

class RunsDao {
  final AppDb db;
  RunsDao(this.db);

  Future<RunState?> loadState(String runId) async {
    final rows = await (db.select(db.runs)
          ..where((r) => r.id.equals(runId)))
        .getSingleOrNull();
    if (rows == null) return null;
    if (rows.headSnapshotId == null) return null;
    final snap = await (db.select(db.runSnapshots)
          ..where((s) => s.id.equals(rows.headSnapshotId!)))
        .getSingleOrNull();
    if (snap == null) return null;
    return RunState.fromJson(jsonDecode(snap.state));
  }

  Future<RunHead?> loadHead(String runId) async {
    final r = await (db.select(db.runs)..where((x) => x.id.equals(runId)))
        .getSingleOrNull();
    if (r == null) return null;
    return RunHead(
      id: r.id,
      worldId: r.worldId,
      worldVersion: r.worldVersion,
      identityId: r.identityId,
      status: r.status,
      chapter: r.chapter,
      turnNo: r.turnNo,
      headSnapshotId: r.headSnapshotId,
      endingId: r.endingId,
      isTrial: r.isTrial,
      draftId: r.draftId,
    );
  }

  Future<String?> loadMemory(String runId) async {
    final r = await (db.select(db.runs)..where((x) => x.id.equals(runId)))
        .getSingleOrNull();
    if (r == null || r.headSnapshotId == null) return null;
    final snap = await (db.select(db.runSnapshots)
          ..where((s) => s.id.equals(r.headSnapshotId!)))
        .getSingleOrNull();
    return snap?.memory;
  }

  /// 最近的回合快照（分叉候选），新→旧
  Future<List<SnapshotBrief>> listSnapshots(String runId,
      {int limit = 12}) async {
    final rows = await (db.select(db.runSnapshots)
          ..where((s) => s.runId.equals(runId))
          ..orderBy([(s) => OrderingTerm.desc(s.turnNo)])
          ..limit(limit))
        .get();
    return rows
        .map((s) =>
            SnapshotBrief(id: s.id, turnNo: s.turnNo, chapter: s.chapter))
        .toList();
  }

  Future<int> nextSeq(String runId) async {
    final row = await db.customSelect(
      'SELECT COALESCE(MAX(seq), 0) AS s FROM run_events WHERE run_id = ?',
      variables: [Variable(runId)],
    ).getSingle();
    return row.read<int>('s') + 1;
  }

  /// 单事务提交：snapshot + events + run 头（数据契约 §12.3）
  Future<String> commitTurn({
    required String runId,
    required RunState stateAfter,
    required int chapter,
    required String? memory,
    String? parentSnapshotId,
    EndingRef? ending,
    required List<Map<String, Object?>> eventPayloads,
  }) async {
    final turnNo = stateAfter.meta.turnNo;
    final snapshotId = 's_${runId.substring(2)}_${turnNo.toString().padLeft(4, '0')}';
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction(() async {
      final seqStart = await nextSeq(runId);
      for (var i = 0; i < eventPayloads.length; i++) {
        final payload = eventPayloads[i];
        await db.into(db.runEvents).insert(RunEventsCompanion.insert(
              runId: runId,
              seq: seqStart + i,
              turnNo: turnNo,
              type: asSOr(payload['type'], 'system'),
              payload: jsonEncode(payload['payload'] ?? {}),
              createdAt: now,
            ));
        final text = payload['fts'] as String?;
        if (text != null && text.isNotEmpty) {
          await db.customStatement(
            'INSERT INTO events_fts (run_id, turn_no, text) VALUES (?, ?, ?)',
            [runId, turnNo, text],
          );
        }
      }
      await db.into(db.runSnapshots).insert(RunSnapshotsCompanion.insert(
            id: snapshotId,
            runId: runId,
            turnNo: turnNo,
            chapter: chapter,
            parentSnapshotId: Value(parentSnapshotId),
            state: jsonEncode(stateAfter.toJson()),
            memory: Value(memory),
            createdAt: now,
          ));
      await (db.update(db.runs)..where((r) => r.id.equals(runId))).write(
        RunsCompanion(
          turnNo: Value(turnNo),
          chapter: Value(chapter),
          headSnapshotId: Value(snapshotId),
          status: Value(ending != null ? 'ended' : 'active'),
          endingId: ending == null ? const Value.absent() : Value(ending.id),
          updatedAt: Value(now),
        ),
      );
      return snapshotId;
    });
  }

  Future<void> createRun({
    required String runId,
    required String worldId,
    required int worldVersion,
    required String identityId,
    required RunState initialState,
    bool isTrial = false,
    String? draftId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final snapshotId = 's_${runId.substring(2)}_0000';
    await db.transaction(() async {
      await db.into(db.runs).insert(RunsCompanion.insert(
            id: runId,
            worldId: worldId,
            worldVersion: worldVersion,
            identityId: identityId,
            createdAt: now,
            updatedAt: now,
            isTrial: Value(isTrial),
            draftId: Value(draftId),
            turnNo: Value(initialState.meta.turnNo),
            chapter: Value(initialState.meta.chapter),
          ));
      await db.into(db.runSnapshots).insert(RunSnapshotsCompanion.insert(
            id: snapshotId,
            runId: runId,
            turnNo: initialState.meta.turnNo,
            chapter: initialState.meta.chapter,
            state: jsonEncode(initialState.toJson()),
            createdAt: now,
          ));
      await (db.update(db.runs)..where((r) => r.id.equals(runId)))
          .write(RunsCompanion(headSnapshotId: Value(snapshotId)));
    });
  }
}
