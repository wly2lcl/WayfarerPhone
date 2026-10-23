import 'dart:convert';

import 'package:contracts/contracts.dart';

/// 七段上下文装配（Prompt 契约 §3）+ 8k 预算裁剪
class ContextBudget {
  static const int totalTokens = 8000;
  static const int stablePrefixTokens = 1800;
}

int estTokens(String s) {
  var cjk = 0;
  var other = 0;
  for (final rune in s.runes) {
    if ((rune >= 0x2E80 && rune <= 0x9FFF) || (rune >= 0x3400 && rune <= 0x4DBF)) {
      cjk++;
    } else {
      other++;
    }
  }
  return (cjk / 1.5).ceil() + (other / 4).ceil();
}

class EngineBookkeeping {
  List<String> firedSeeds;
  int lastTurningTurn;
  Map<String, int> actionCounts;

  EngineBookkeeping({
    List<String>? firedSeeds,
    int? lastTurningTurn,
    Map<String, int>? actionCounts,
  })  : firedSeeds = firedSeeds ?? [],
        lastTurningTurn = lastTurningTurn ?? -99,
        actionCounts = actionCounts ?? {};

  static EngineBookkeeping fromMemoryJson(String? memory) {
    if (memory == null || memory.isEmpty) return EngineBookkeeping();
    try {
      final m = jsonDecode(memory);
      if (m is Map) {
        final eng = m['engine'];
        if (eng is Map) {
          return EngineBookkeeping(
            firedSeeds:
                (eng['firedSeeds'] as List?)?.map((e) => e.toString()).toList(),
            lastTurningTurn: eng['lastTurningTurn'] is int
                ? eng['lastTurningTurn'] as int
                : -99,
            actionCounts: (eng['actionCounts'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v is int ? v : 0),
            ),
          );
        }
      }
    } catch (_) {}
    return EngineBookkeeping();
  }

  String encode(String? compactJson) {
    return jsonEncode({
      if (compactJson != null) 'compact': jsonDecode(compactJson),
      'engine': {
        'firedSeeds': firedSeeds,
        'lastTurningTurn': lastTurningTurn,
        'actionCounts': actionCounts,
      },
    });
  }
}

class CompactMemory {
  List<String> facts;
  List<String> relationChanges;
  List<String> openThreads;
  String volumeSummary;

  CompactMemory({
    List<String>? facts,
    List<String>? relationChanges,
    List<String>? openThreads,
    this.volumeSummary = '',
  })  : facts = facts ?? [],
        relationChanges = relationChanges ?? [],
        openThreads = openThreads ?? [];

  String encode() => jsonEncode({
        'facts': facts,
        'relationChanges': relationChanges,
        'openThreads': openThreads,
        'volumeSummary': volumeSummary,
      });

  static CompactMemory fromJson(String? json) {
    if (json == null || json.isEmpty) return CompactMemory();
    try {
      final m = jsonDecode(json);
      if (m is Map && m['compact'] is Map) {
        final c = m['compact'] as Map;
        return CompactMemory(
          facts: (c['facts'] as List?)?.map((e) => e.toString()).toList(),
          relationChanges: (c['relationChanges'] as List?)
              ?.map((e) => e.toString())
              .toList(),
          openThreads:
              (c['openThreads'] as List?)?.map((e) => e.toString()).toList(),
          volumeSummary: (c['volumeSummary'] ?? '').toString(),
        );
      }
      if (m is Map && m['facts'] is List) {
        return CompactMemory(
          facts: (m['facts'] as List?)?.map((e) => e.toString()).toList(),
          relationChanges: (m['relationChanges'] as List?)
              ?.map((e) => e.toString())
              .toList(),
          openThreads:
              (m['openThreads'] as List?)?.map((e) => e.toString()).toList(),
          volumeSummary: (m['volumeSummary'] ?? '').toString(),
        );
      }
    } catch (_) {}
    return CompactMemory();
  }
}

String stateSummary(RunState s) {
  final rels = s.relations.entries
      .take(6)
      .map((e) => '${e.key}: ${e.value.status.label}(${e.value.affinity})')
      .join('；');
  return '第${s.meta.turnNo}回合，${s.meta.gameTime}，${s.meta.age}岁，寿元余${s.meta.lifespan - s.meta.age}，'
      '${s.character.realm.stageName} ${s.character.realm.layer}层(进度${s.character.realm.progress})，'
      '气血${s.character.stats.vitality} 神识${s.character.stats.spirit}，灵石${s.character.resources.spiritStones}。'
      '地点 ${s.location.regionId}/${s.location.placeId}。关系：$rels。'
      '随身：${s.inventory.map((i) => '${i.name}×${i.qty}').take(5).join('、')}';
}

/// 命中条件的事件种子（引擎触发，AI 无权自造）
List<EventSeed> matchSeeds(WorldBible bible, RunState state, EngineBookkeeping book) {
  final fired = book.firedSeeds.toSet();
  return bible.eventSeeds.where((seed) {
    if (fired.contains(seed.id)) return false;
    final r = seed.requires;
    if (r.chapterMin != null && state.meta.chapter < r.chapterMin!) return false;
    if (r.chapterMax != null && state.meta.chapter > r.chapterMax!) return false;
    if (r.placeId != null && state.location.placeId != r.placeId) return false;
    for (final e in r.knowledge) {
      if (!state.knowledge.any((k) => k.contains(e))) return false;
    }
    for (final entry in r.flags.entries) {
      final v = state.flags[entry.key];
      if (v == null || v.toString() != entry.value.toString()) return false;
    }
    if (r.realmMin != null) {
      final tier = bible.tierByName(r.realmMin!);
      if (tier != null && state.character.realm.stage < tier.stage) return false;
    }
    return true;
  }).toList();
}

class AssembledContext {
  final String system;
  final String user;

  /// 各段 token 估算合计
  final int tokens;
  AssembledContext(this.system, this.user, this.tokens);
}

/// 公共铁律段（Prompt 契约 §9.1）
String ironLawSection(WorldBible bible) {
  return '''
你是《${bible.meta.title}》这款文字人生模拟的幕后引擎。
世界的基调：${bible.meta.tone}。叙事人称：第二人称「你」。

铁律（任何情况下不得违反）：
1. 叙事是表现，状态是唯一真相；你只能提议变更，由代码裁决。
2. 不替玩家做决定，不写玩家未选择的行为，不写玩家的内心独白。
3. 不输出任何数值、成功率、判定术语、规则名词。
4. 不引入未在以下世界设定中登记的新势力、新地名、新境界、新物品。
5. 角色死亡即永久，不得复活，不得以回忆/幻象形式让其继续行动。
6. 违反世界硬规则与禁忌的内容一律不写。

世界硬规则：
${bible.powerSystem.rules.map((r) => '- $r').join('\n')}

禁忌：
${bible.taboos.map((r) => '- $r').join('\n')}''';
}

/// 世界段 + 身份段（稳定前缀 [2][3]）
String worldSection(WorldBible bible) {
  final regions = bible.regions
      .map((r) =>
          '${r.name}（${r.terrain.name}，危险度${r.danger}）：${r.summary} 场所：${r.places.map((p) => p.name).join('、')}')
      .join('\n');
  final factions = bible.factions
      .map((f) => '${f.name}（${f.kind.name}）：${f.summary} 目标：${f.goal}')
      .join('\n');
  return '''
时代：${bible.eras.isNotEmpty ? bible.eras.first.name : ''} ${bible.eras.isNotEmpty ? bible.eras.first.summary : ''}
$regions

势力：
$factions

力量体系：${bible.powerSystem.name}（资源：${bible.powerSystem.resource}），境界：${bible.powerSystem.tiers.map((t) => '${t.name}(寿元${t.lifespan})').join(' → ')}
第一卷骨架：${bible.meta.volumeHint}''';
}

String identitySection(Identity identity) {
  return '''
身份：${identity.name}（${identity.situation}）
长期目标：${identity.goal}
枷锁：${identity.shackles.join('；')}''';
}

/// 记忆段 [4]：卷末压缩产物
String memorySection(CompactMemory memory) {
  if (memory.facts.isEmpty && memory.volumeSummary.isEmpty) return '';
  return '''
此前卷记：${memory.volumeSummary}
既成事实：
${memory.facts.take(12).map((f) => '- $f').join('\n')}
关系变化：
${memory.relationChanges.take(8).map((f) => '- $f').join('\n')}''';
}

/// 检索段 [5]：相关 NPC（私密面 hidden 标记只进导演）
String retrievalSection(WorldBible bible, RunState state, {bool withPrivate = false}) {
  final near = state.relations.keys.take(4).toList();
  final lines = <String>[];
  for (final npc in bible.npcPool) {
    if (!near.contains(npc.id)) continue;
    final rel = state.relations[npc.id]!;
    var line = '${npc.name}（${npc.role}，关系${rel.status.label}/好感${rel.affinity}）：${npc.public.manner}';
    if (withPrivate) {
      line += '｜私密：${npc.private.secret} 动机：${npc.private.motive}';
    }
    lines.add(line);
  }
  return lines.isEmpty ? '' : '在场相关人物：\n${lines.join('\n')}';
}

/// 近况段 [6]：最近 N 回合原文
String recentSection(List<Map<String, Object?>> recentTurns, {int limit = 3}) {
  if (recentTurns.isEmpty) return '';
  final parts = recentTurns.take(limit).map((t) {
    final turn = t['turn'];
    return '【回合$turn】${(t['narration'] ?? '').toString()}';
  });
  return '最近几回合：\n${parts.join('\n')}';
}

/// 近期正文只留最近 3 回合；超出预算时裁剪近况段
String assembleUser({
  required List<String> sections,
  required int systemTokens,
  int budget = ContextBudget.totalTokens,
}) {
  var out = sections.where((s) => s.trim().isNotEmpty).join('\n\n');
  var used = systemTokens + estTokens(out);
  if (used <= budget) return out;
  // 逐段从近况开始裁剪
  for (var i = sections.length - 1; i >= 0; i--) {
    final s = sections[i];
    if (!s.startsWith('最近') && !s.startsWith('在场') && !s.startsWith('此前')) continue;
    final shortened = s.length > 400 ? '${s.substring(0, 400)}……' : s;
    final candidate = sections
        .map((e) => identical(e, s) ? shortened : e)
        .where((e) => e.trim().isNotEmpty)
        .join('\n\n');
    out = candidate;
    used = systemTokens + estTokens(out);
    if (used <= budget) return out;
  }
  return out;
}
