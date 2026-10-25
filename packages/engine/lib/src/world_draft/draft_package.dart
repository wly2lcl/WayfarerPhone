import 'dart:convert';

import 'package:contracts/contracts.dart';
import 'package:drift/drift.dart';

import '../data/app_db.dart';
import '../data/runs_dao.dart';
import '../errors.dart';

/// 一个局使用的完整世界包
typedef RunPackage = ({WorldBible bible, List<Identity> identities});

/// 正式局从 world_versions 取包；试玩局从其来源草稿取包
Future<RunPackage> loadRunPackage(AppDb db, RunHead head) async {
  if (head.isTrial) {
    final draftId = head.draftId;
    if (draftId == null) {
      throw EngineException(EngineCode.notFound, '试玩局缺少来源草稿');
    }
    final d = await (db.select(db.worldDrafts)
          ..where((x) => x.id.equals(draftId)))
        .getSingleOrNull();
    if (d == null || d.bibleDraft == null) {
      throw EngineException(EngineCode.notFound, '草稿不存在或尚未生成圣经');
    }
    return (
      bible: WorldBible.fromJson(jsonDecode(d.bibleDraft!)),
      identities: asList<Identity>(
          jsonDecode(d.identities ?? '[]'), Identity.fromJson),
    );
  }
  final version = await (db.select(db.worldVersions)
        ..where((v) =>
            v.worldId.equals(head.worldId) &
            v.version.equals(head.worldVersion)))
      .getSingleOrNull();
  if (version == null) {
    throw EngineException(EngineCode.notFound, '世界版本缺失');
  }
  return (
    bible: WorldBible.fromJson(jsonDecode(version.bible)),
    identities:
        asList<Identity>(jsonDecode(version.identities), Identity.fromJson),
  );
}
