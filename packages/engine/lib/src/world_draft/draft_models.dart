import 'dart:convert';

import 'package:contracts/contracts.dart';

/// 草稿来源三选一（世界创造与导入 §2）
enum DraftSource { manual, dialogue, import }

/// 草稿状态机：draft → generating → review → trial → frozen
enum DraftStatus { draft, generating, review, trial, frozen }

/// 八个访谈字段（世界创造与导入 §3.2）
enum FieldKey { era, geography, factions, power, taboos, tone, npcs, events }

typedef FieldData = Map<String, Object?>;

const Map<FieldKey, int> kFieldWeights = {
  FieldKey.era: 10,
  FieldKey.geography: 15,
  FieldKey.factions: 15,
  FieldKey.power: 15,
  FieldKey.taboos: 10,
  FieldKey.tone: 10,
  FieldKey.npcs: 15,
  FieldKey.events: 10,
};

const Map<DraftStatus, Set<DraftStatus>> kDraftTransitions = {
  DraftStatus.draft: {DraftStatus.generating},
  DraftStatus.generating: {DraftStatus.review, DraftStatus.draft},
  DraftStatus.review: {DraftStatus.trial, DraftStatus.frozen},
  DraftStatus.trial: {DraftStatus.review, DraftStatus.frozen},
  DraftStatus.frozen: {},
};

bool canTransition(DraftStatus from, DraftStatus to) =>
    kDraftTransitions[from]!.contains(to);

/// 访谈完整度 ≥ 70 才允许进入 generating（世界创造与导入 §3.2）
const int kCompletenessGate = 70;

extension FieldKeyX on FieldKey {
  String get label => switch (this) {
        FieldKey.era => '时代',
        FieldKey.geography => '地理',
        FieldKey.factions => '势力',
        FieldKey.power => '力量规则',
        FieldKey.taboos => '禁忌',
        FieldKey.tone => '基调',
        FieldKey.npcs => 'NPC 池',
        FieldKey.events => '事件种子',
      };

  /// 引导问题（每轮只问一个字段，世界创造与导入 §3.3）
  String get guideQuestion => switch (this) {
        FieldKey.era => '这是什么样的年代？灵气的丰枯如何？后来发生了什么转折？',
        FieldKey.geography => '人主要活在哪几个地方？各处靠什么过活？哪里危险？',
        FieldKey.factions => '谁在争什么？谁和谁不对付？',
        FieldKey.power => '力量从哪来？分几个层级？代价是什么？上限在哪？',
        FieldKey.taboos => '这个世界里什么事绝对不能做？',
        FieldKey.tone => '读起来应该是什么感觉？给三五个词就好。',
        FieldKey.npcs => '这个世界里最关键的几个人是谁？各自想要什么？',
        FieldKey.events => '有哪些迟早会爆发的事？由什么触发？',
      };

  int get weight => kFieldWeights[this]!;
}

/// 单字段访谈结果：用户原话 + 结构化抽取 + 是否 AI 代填
class FieldAnswer {
  final String text;
  final FieldData data;
  final bool filledByAI;

  const FieldAnswer({
    required this.text,
    this.data = const {},
    this.filledByAI = false,
  });

  Map<String, Object?> toJson() =>
      {'text': text, 'data': data, 'filledByAI': filledByAI};

  static FieldAnswer fromJson(Object? j) {
    final m = rawMap(j);
    return FieldAnswer(
      text: asSOr(m['text'], ''),
      data: rawMap(m['data']),
      filledByAI: asBOr(m['filledByAI'], false),
    );
  }
}

/// 访谈状态：当前推进到的字段 + 各字段回答
class InterviewState {
  FieldKey step;
  final Map<FieldKey, FieldAnswer> answers;

  InterviewState({required this.step, Map<FieldKey, FieldAnswer>? answers})
      : answers = answers ?? {};

  Map<String, Object?> toJson() => {
        'step': step.name,
        'answers': {
          for (final e in answers.entries) e.key.name: e.value.toJson(),
        },
      };

  static InterviewState fromJson(Object? j) {
    final m = rawMap(j);
    final raw = rawMap(m['answers']);
    return InterviewState(
      step: FieldKey.values.firstWhere(
        (k) => k.name == asS(m['step']),
        orElse: () => FieldKey.era,
      ),
      answers: {
        for (final e in raw.entries)
          if (FieldKey.values.any((k) => k.name == e.key))
            FieldKey.values.byName(e.key): FieldAnswer.fromJson(e.value),
      },
    );
  }

  /// 八字段加权完整度 0–100
  int get completeness {
    var total = 0;
    for (final k in FieldKey.values) {
      total += k.weight * scoreField(k, answers[k]?.data);
    }
    return total ~/ 100;
  }

  /// 是否还有未回答字段（step 尚未走完一轮）
  bool get allAsked {
    final asked = answers.length;
    return asked >= FieldKey.values.length;
  }
}

List<Map<String, Object?>> _listOfMaps(Object? v) =>
    asList<Object?>(v, (e) => e)
        .whereType<Map>()
        .map((e) => rawMap(e))
        .toList();

List<String> _listOfStr(Object? v) =>
    asList<Object?>(v, (e) => e).map((e) => asSOr(e, '')).toList();

/// 单字段达标打分 0–100（世界创造与导入 §3.2 达标线）
int scoreField(FieldKey k, FieldData? data) {
  if (data == null || data.isEmpty) return 0;
  switch (k) {
    case FieldKey.era:
      final s = asSOr(data['summary'], '');
      final t = asSOr(data['turningPoint'], '');
      return (s.isNotEmpty ? 60 : 0) + (t.isNotEmpty ? 40 : 0);
    case FieldKey.geography:
      final regions = _listOfMaps(data['regions'])
          .where((r) => asSOr(r['name'], '').isNotEmpty)
          .toList();
      final withUse = regions
          .where((r) => asSOr(r['use'], asSOr(r['summary'], '')).isNotEmpty)
          .length;
      if (regions.isEmpty) return 0;
      final count = (regions.length.clamp(0, 3) / 3 * 70).round();
      final used = (withUse.clamp(0, 3) / 3 * 30).round();
      return count + used;
    case FieldKey.factions:
      final factions = _listOfMaps(data['factions'])
          .where((f) => asSOr(f['name'], '').isNotEmpty)
          .toList();
      if (factions.isEmpty) return 0;
      var relations = 0;
      for (final f in factions) {
        relations += _listOfMaps(f['relations']).length;
      }
      final count = (factions.length.clamp(0, 3) / 3 * 80).round();
      final rel = (relations.clamp(0, 2) / 2 * 20).round();
      return count + rel;
    case FieldKey.power:
      final tiers = _listOfStr(data['tiers']).where((t) => t.isNotEmpty).toList();
      final costs = _listOfStr(data['costs']).where((c) => c.isNotEmpty).toList();
      if (tiers.isEmpty) return 0;
      return (tiers.length.clamp(0, 3) / 3 * 70).round() +
          (costs.isNotEmpty ? 30 : 0);
    case FieldKey.taboos:
      final items = _listOfStr(data['items']).where((t) => t.isNotEmpty).toList();
      if (items.isEmpty) return 0;
      return (items.length.clamp(0, 3) / 3 * 100).round();
    case FieldKey.tone:
      final words = _listOfStr(data['words']).where((w) => w.isNotEmpty).toList();
      if (words.isEmpty) return 0;
      return (words.length.clamp(0, 3) / 3 * 100).round();
    case FieldKey.npcs:
      final npcs = _listOfMaps(data['npcs'])
          .where((n) => asSOr(n['name'], '').isNotEmpty)
          .toList();
      if (npcs.isEmpty) return 0;
      return (npcs.length.clamp(0, 5) / 5 * 100).round();
    case FieldKey.events:
      final events = _listOfMaps(data['events'])
          .where((e) => asSOr(e['title'], '').isNotEmpty)
          .toList();
      if (events.isEmpty) return 0;
      return (events.length.clamp(0, 8) / 8 * 100).round();
  }
}

/// 发给客户端的草稿快照（门面序列化用）
class DraftView {
  final String id;
  final DraftSource source;
  final DraftStatus status;
  final String title;
  final FieldKey? step;
  final int completeness;
  final Map<FieldKey, ({bool answered, bool filledByAI, int score})> fields;
  final int qualityScore;
  final List<({String level, String code, String field, String message})> issues;
  final bool exportable;
  final String? worldId;
  final int updatedAt;

  DraftView({
    required this.id,
    required this.source,
    required this.status,
    required this.title,
    required this.step,
    required this.completeness,
    required this.fields,
    required this.qualityScore,
    required this.issues,
    required this.exportable,
    required this.worldId,
    required this.updatedAt,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'source': source.name,
        'status': status.name,
        'title': title,
        if (step != null) 'step': step!.name,
        'completeness': completeness,
        'fields': {
          for (final e in fields.entries)
            e.key.name: {
              'answered': e.value.answered,
              'filledByAI': e.value.filledByAI,
              'score': e.value.score,
            },
        },
        'quality': {
          'score': qualityScore,
          'issues': [
            for (final i in issues)
              {'level': i.level, 'code': i.code, 'field': i.field, 'message': i.message},
          ],
        },
        'exportable': exportable,
        if (worldId != null) 'worldId': worldId,
        'updatedAt': updatedAt,
      };
}

DraftStatus draftStatusByName(String s) => DraftStatus.values
    .firstWhere((v) => v.name == s, orElse: () => DraftStatus.draft);

DraftSource draftSourceByName(String s) => DraftSource.values
    .firstWhere((v) => v.name == s, orElse: () => DraftSource.manual);

WorldBible? tryParseBible(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return WorldBible.fromJson(jsonDecode(raw));
  } catch (_) {
    return null;
  }
}
