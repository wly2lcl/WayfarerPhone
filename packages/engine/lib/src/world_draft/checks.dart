import 'package:contracts/contracts.dart';

/// 一致性问题（世界创造与导入 §3.4）：error 阻塞冻结，warn 只提示
class QualityIssue {
  final String level; // error | warn
  final String field;
  final String code;
  final String message;

  const QualityIssue({
    required this.level,
    required this.field,
    required this.code,
    required this.message,
  });

  Map<String, Object?> toJson() =>
      {'level': level, 'field': field, 'code': code, 'message': message};
}

class QualityReport {
  final int score;
  final List<QualityIssue> issues;

  const QualityReport({required this.score, required this.issues});

  bool get pass => issues.every((i) => i.level != 'error');

  Map<String, Object?> toJson() => {
        'score': score,
        'issues': issues.map((i) => i.toJson()).toList(),
      };

  static QualityReport fromJson(Object? j) {
    final m = rawMap(j);
    return QualityReport(
      score: asIOr(m['score'], 0),
      issues: asList<QualityIssue>(m['issues'], (e) {
        final im = rawMap(e);
        return QualityIssue(
          level: asSOr(im['level'], 'warn'),
          field: asSOr(im['field'], ''),
          code: asSOr(im['code'], ''),
          message: asSOr(im['message'], ''),
        );
      }),
    );
  }
}

/// 六条一致性检查（纯代码，世界创造与导入 §3.4）
List<QualityIssue> checkBible(WorldBible bible) {
  final issues = <QualityIssue>[];

  // 1. 势力—地理绑定：每个势力至少有一个据点
  final regionFactions = <String>{};
  for (final r in bible.regions) {
    regionFactions.addAll(r.factionIds);
  }
  for (final f in bible.factions) {
    if (!regionFactions.contains(f.id)) {
      issues.add(QualityIssue(
        level: 'error',
        field: 'factions',
        code: 'FACTION_NO_BASE',
        message: '势力「${f.name}」没有任何区域据点',
      ));
    }
  }

  // 2. 力量有代价
  if (bible.powerSystem.costs.isEmpty) {
    issues.add(const QualityIssue(
      level: 'error',
      field: 'power',
      code: 'POWER_NO_COST',
      message: '力量体系没有任何代价',
    ));
  }

  // 3. 禁忌不自相矛盾（代码级代理：去重 + 数量下限；语义矛盾由生成提示词约束）
  final seen = <String>{};
  for (final t in bible.taboos) {
    final key = t.trim();
    if (key.isEmpty) continue;
    if (!seen.add(key)) {
      issues.add(QualityIssue(
        level: 'warn',
        field: 'taboos',
        code: 'TABOO_DUPLICATED',
        message: '禁忌重复：「$key」',
      ));
    }
  }
  if (seen.length < 3) {
    issues.add(const QualityIssue(
      level: 'warn',
      field: 'taboos',
      code: 'TABOO_TOO_FEW',
      message: '禁忌少于 3 条，世界的约束感会偏弱',
    ));
  }

  // 4. NPC 归属：每个 NPC 至少属于一个势力或明确为散人
  for (final n in bible.npcPool) {
    if ((n.factionId == null || n.factionId!.isEmpty) &&
        n.public.affiliation.trim().isEmpty) {
      issues.add(QualityIssue(
        level: 'error',
        field: 'npcs',
        code: 'NPC_NO_FACTION',
        message: 'NPC「${n.name}」未归属势力也未标记散人',
      ));
    }
  }

  // 5. 种子可达：引用的区域、势力、NPC 必须存在
  final regionIds = bible.regions.map((r) => r.id).toSet();
  final factionIds = bible.factions.map((f) => f.id).toSet();
  final npcIds = bible.npcPool.map((n) => n.id).toSet();
  for (final s in bible.eventSeeds) {
    if (s.regionId != null && s.regionId!.isNotEmpty && !regionIds.contains(s.regionId)) {
      issues.add(QualityIssue(
        level: 'error',
        field: 'events',
        code: 'SEED_UNREACHABLE',
        message: '事件「${s.title}」引用了不存在的区域 ${s.regionId}',
      ));
    }
    for (final fid in s.factionIds) {
      if (!factionIds.contains(fid)) {
        issues.add(QualityIssue(
          level: 'error',
          field: 'events',
          code: 'SEED_UNREACHABLE',
          message: '事件「${s.title}」引用了不存在的势力 $fid',
        ));
      }
    }
    for (final nid in s.npcIds) {
      if (!npcIds.contains(nid)) {
        issues.add(QualityIssue(
          level: 'error',
          field: 'events',
          code: 'SEED_UNREACHABLE',
          message: '事件「${s.title}」引用了不存在的 NPC $nid',
        ));
      }
    }
  }

  // 6. 终局存在且可触发
  if (bible.endgame.isEmpty) {
    issues.add(const QualityIssue(
      level: 'error',
      field: 'endgame',
      code: 'NO_ENDING',
      message: '没有任何终局规则，这一局无法收束',
    ));
  } else {
    for (final e in bible.endgame) {
      if (e.condition.trim().isEmpty) {
        issues.add(QualityIssue(
          level: 'error',
          field: 'endgame',
          code: 'ENDING_NO_CONDITION',
          message: '终局「${e.title}」没有可判定的条件',
        ));
      }
    }
    if (!bible.endgame.any((e) => e.type == EndingType.death)) {
      issues.add(const QualityIssue(
        level: 'warn',
        field: 'endgame',
        code: 'NO_DEATH_ENDING',
        message: '没有 death 类终局，正常 playthrough 可能无法收束',
      ));
    }
  }

  return issues;
}

/// score：0–100，error -35、warn -5；质量门槛 <70 不可冻结（1 条 error 即跌破）
int qualityScoreOf(List<QualityIssue> issues) {
  var score = 100;
  for (final i in issues) {
    score -= i.level == 'error' ? 35 : 5;
  }
  return score.clamp(0, 100);
}

QualityReport reviewBible(WorldBible bible) {
  final issues = checkBible(bible);
  return QualityReport(score: qualityScoreOf(issues), issues: issues);
}
