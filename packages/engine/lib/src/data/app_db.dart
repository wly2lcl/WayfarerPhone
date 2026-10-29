import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'app_db.g.dart';

class Worlds extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get genre => text()();
  TextColumn get summary => text().nullable()();
  TextColumn get source => text()();
  BoolColumn get exportable => boolean().clientDefault(() => true)();
  TextColumn get license => text().clientDefault(() => 'all-rights-reserved')();
  TextColumn get author => text().nullable()();
  TextColumn get sourceWorldId => text().nullable()();
  IntColumn get latestVersion => integer().clientDefault(() => 0)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_wv_world_version', columns: {#worldId, #version}, unique: true)
class WorldVersions extends Table {
  TextColumn get id => text()();
  TextColumn get worldId => text()();
  IntColumn get version => integer()();
  TextColumn get bible => text()();
  TextColumn get identities => text()();
  TextColumn get seeds => text()();
  TextColumn get checksum => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_runs_world', columns: {#worldId, #status, #updatedAt})
class Runs extends Table {
  TextColumn get id => text()();
  TextColumn get worldId => text()();
  IntColumn get worldVersion => integer()();
  TextColumn get identityId => text()();
  TextColumn get status => text().clientDefault(() => 'active')();
  IntColumn get chapter => integer().clientDefault(() => 1)();
  IntColumn get turnNo => integer().clientDefault(() => 0)();
  TextColumn get headSnapshotId => text().nullable()();
  TextColumn get endingId => text().nullable()();
  // 试玩局：由草稿直接开局，不入「我的局」，删除即丢弃
  BoolColumn get isTrial => boolean().clientDefault(() => false)();
  TextColumn get draftId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_snapshots_run', columns: {#runId, #turnNo})
class RunSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get runId => text()();
  IntColumn get turnNo => integer()();
  IntColumn get chapter => integer()();
  TextColumn get parentSnapshotId => text().nullable()();
  TextColumn get parentRunId => text().nullable()();
  TextColumn get state => text()();
  TextColumn get memory => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_events_run_turn', columns: {#runId, #turnNo})
class RunEvents extends Table {
  TextColumn get runId => text()();
  IntColumn get seq => integer()();
  IntColumn get turnNo => integer()();
  TextColumn get type => text()();
  TextColumn get payload => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {runId, seq};
}

class UsageLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get runId => text().nullable()();
  IntColumn get turnNo => integer().nullable()();
  TextColumn get role => text()();
  TextColumn get model => text()();
  IntColumn get tokensIn => integer()();
  IntColumn get tokensOut => integer()();
  BoolColumn get estimated => boolean().clientDefault(() => false)();
  IntColumn get ms => integer()();
  IntColumn get firstByteMs => integer().nullable()();
  BoolColumn get ok => boolean().clientDefault(() => true)();
  IntColumn get createdAt => integer()();
}

@TableIndex(name: 'idx_drafts_status', columns: {#status, #updatedAt})
class WorldDrafts extends Table {
  TextColumn get id => text()();
  TextColumn get source => text()(); // manual | dialogue | import
  TextColumn get status => text()(); // draft | generating | review | trial | frozen
  TextColumn get interview => text().nullable()(); // InterviewState JSON
  TextColumn get bibleDraft => text().nullable()(); // WorldBible JSON
  TextColumn get identities => text().nullable()(); // List<Identity> JSON
  TextColumn get seeds => text().nullable()(); // List<EventSeed> JSON
  TextColumn get quality => text().nullable()(); // {score, issues} JSON
  TextColumn get importJobId => text().nullable()();
  TextColumn get worldId => text().nullable()(); // 冻结后指向 worlds.id
  BoolColumn get exportable => boolean().clientDefault(() => true)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class ImportJobs extends Table {
  TextColumn get id => text()();
  TextColumn get sourcePath => text()();
  TextColumn get contentHash => text()();
  TextColumn get stage => text()();
  RealColumn get progress => real().clientDefault(() => 0)();
  TextColumn get error => text().nullable()();
  // v4：断点续跑与统计（世界创造与导入 §4.5）
  TextColumn get draftId => text().nullable()();
  IntColumn get done => integer().clientDefault(() => 0)();
  IntColumn get total => integer().clientDefault(() => 0)();
  TextColumn get stats => text().nullable()(); // ImportStats JSON
  TextColumn get entities => text().nullable()(); // 归并后实体（审阅用）
  IntColumn get entitiesTotal => integer().clientDefault(() => 0)();
  // v5：合成档位（0=快速 1=标准 2=忠实，ImportFidelity.index）
  IntColumn get fidelity => integer().clientDefault(() => 0)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 每块抽取结果（断点真源：done 由本表行数推导，续跑不重抽取过的块）
@TableIndex(name: 'idx_import_chunks_job', columns: {#jobId, #idx})
class ImportChunks extends Table {
  TextColumn get jobId => text()();
  IntColumn get idx => integer()();
  TextColumn get payload => text()(); // ChunkExtraction JSON
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {jobId, idx};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@TableIndex(name: 'idx_local_events_name', columns: {#name, #createdAt})
class LocalEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get runId => text().nullable()();
  TextColumn get props => text().nullable()();
  IntColumn get createdAt => integer()();
}

/// 本地反馈/举报记录（合规与内容安全 §3.3：只写本机，不联网上报）
class FeedbackRecords extends Table {
  TextColumn get id => text()();
  TextColumn get runId => text().nullable()();
  TextColumn get category => text()();
  TextColumn get detail => text()();
  TextColumn get status => text().clientDefault(() => 'open')();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Worlds,
  WorldVersions,
  WorldDrafts,
  Runs,
  RunSnapshots,
  RunEvents,
  UsageLog,
  ImportJobs,
  ImportChunks,
  AppSettings,
  LocalEvents,
  FeedbackRecords,
])
class AppDb extends _$AppDb {
  AppDb(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await createFts(customStatement);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2：usage_log 增加首字延迟列（观测 §9 的 p50/p95 首字）
            await customStatement(
                'ALTER TABLE usage_log ADD COLUMN first_byte_ms INTEGER NULL');
          }
          if (from < 3) {
            // v3：世界工坊草稿表 + runs 试玩列
            await m.createTable(worldDrafts);
            await customStatement(
                'ALTER TABLE runs ADD COLUMN is_trial INTEGER NOT NULL DEFAULT 0');
            await customStatement(
                'ALTER TABLE runs ADD COLUMN draft_id TEXT NULL');
          }
          if (from < 4) {
            // v4：import_jobs 续跑/统计列 + 每块抽取结果表（M2）
            await customStatement(
                'ALTER TABLE import_jobs ADD COLUMN draft_id TEXT NULL');
            await customStatement(
                'ALTER TABLE import_jobs ADD COLUMN done INTEGER NOT NULL DEFAULT 0');
            await customStatement(
                'ALTER TABLE import_jobs ADD COLUMN total INTEGER NOT NULL DEFAULT 0');
            await customStatement(
                'ALTER TABLE import_jobs ADD COLUMN stats TEXT NULL');
            await customStatement(
                'ALTER TABLE import_jobs ADD COLUMN entities TEXT NULL');
            await customStatement(
                'ALTER TABLE import_jobs ADD COLUMN entities_total INTEGER NOT NULL DEFAULT 0');
            await m.createTable(importChunks);
          }
          if (from < 5) {
            // v5：导入合成档位（快速/标准/忠实）
            await customStatement(
                'ALTER TABLE import_jobs ADD COLUMN fidelity INTEGER NOT NULL DEFAULT 0');
          }
          if (from < 6) {
            // v6：本地反馈/举报记录（WF-LAUNCH-02 反馈层）
            await m.createTable(feedbackRecords);
          }
        },
        beforeOpen: (details) async {
          // FTS 表在 v1 与低版本重建时兜底创建
          final hasFts = await customSelect(
            "SELECT count(*) AS c FROM sqlite_master WHERE type='table' AND name='events_fts'",
            readsFrom: {},
          ).getSingle();
          if (hasFts.read<int>('c') == 0) {
            await createFts(customStatement);
          }
        },
      );

  // trigram：unicode61 会把整句无空格中文当成单个 token，检索形同虚设；
  // trigram 支持子串 MATCH（查询需 ≥3 字符）
  static const ftsDdl =
      "CREATE VIRTUAL TABLE IF NOT EXISTS events_fts USING fts5("
      "run_id UNINDEXED, turn_no UNINDEXED, text, tokenize = 'trigram')";

  static Future<void> createFts(Future<void> Function(String) exec) =>
      exec(ftsDdl);
}

AppDb openDbAt(String path) {
  return AppDb(LazyDatabase(() async {
    final file = File(path);
    await file.parent.create(recursive: true);
    return NativeDatabase.createInBackground(file);
  }));
}

AppDb openDbInMemory() => AppDb(NativeDatabase.memory());
