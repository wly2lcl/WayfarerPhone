import 'choice.dart';
import 'json.dart';

enum Beat { daily, event, turningPoint, chapterEnd }

extension BeatX on Beat {
  String get jsonName => switch (this) {
        Beat.turningPoint => 'turning_point',
        Beat.chapterEnd => 'chapter_end',
        _ => name,
      };

  static Beat fromName(Object? v) {
    final s = asS(v);
    if (s == 'turning_point') return Beat.turningPoint;
    if (s == 'chapter_end') return Beat.chapterEnd;
    return enumBy(Beat.values, s, Beat.daily);
  }
}

class NpcAction {
  String npcId;
  String action;
  bool hidden;

  NpcAction({required this.npcId, required this.action, required this.hidden});

  Map<String, Object?> toJson() =>
      {'npcId': npcId, 'action': action, 'hidden': hidden};

  static NpcAction fromJson(Object? j) {
    final m = rawMap(j);
    return NpcAction(
      npcId: asSOr(m['npcId'], ''),
      action: asSOr(m['action'], ''),
      hidden: asBOr(m['hidden'], false),
    );
  }
}

class PlanChoice {
  String intent;
  Risk risk;
  ChoiceRequires? requires;
  bool? hidden;

  PlanChoice({required this.intent, required this.risk, this.requires, this.hidden});

  Map<String, Object?> toJson() => {
        'intent': intent,
        'risk': risk.name,
        if (requires != null) 'requires': requires!.toJson(),
        if (hidden != null) 'hidden': hidden,
      };

  static PlanChoice fromJson(Object? j) {
    final m = rawMap(j);
    return PlanChoice(
      intent: asSOr(m['intent'], ''),
      risk: enumBy(Risk.values, m['risk'], Risk.medium),
      requires:
          m['requires'] is Map ? ChoiceRequires.fromJson(m['requires']) : null,
      hidden: m['hidden'] is bool ? m['hidden'] as bool : null,
    );
  }
}

class ChapterEnd {
  String reason;

  ChapterEnd({required this.reason});

  Map<String, Object?> toJson() => {'reason': reason};

  static ChapterEnd fromJson(Object? j) {
    final m = rawMap(j);
    return ChapterEnd(reason: asSOr(m['reason'], ''));
  }
}

class ScenePlan {
  Beat beat;
  String summary;
  List<NpcAction> npcActions;
  List<String> reveals;
  String mood;
  List<PlanChoice> nextChoices;
  double? advanceTimeDays;
  ChapterEnd? chapterEnd;

  ScenePlan({
    required this.beat,
    required this.summary,
    required this.npcActions,
    required this.reveals,
    required this.mood,
    required this.nextChoices,
    this.advanceTimeDays,
    this.chapterEnd,
  });

  Map<String, Object?> toJson() => {
        'beat': beat.jsonName,
        'summary': summary,
        'npcActions': npcActions.map((n) => n.toJson()).toList(),
        'reveals': reveals,
        'mood': mood,
        'nextChoices': nextChoices.map((c) => c.toJson()).toList(),
        if (advanceTimeDays != null) 'advanceTimeDays': advanceTimeDays,
        if (chapterEnd != null) 'chapterEnd': chapterEnd!.toJson(),
      };

  static ScenePlan fromJson(Object? j) {
    final m = rawMap(j);
    return ScenePlan(
      beat: BeatX.fromName(m['beat']),
      summary: asSOr(m['summary'], ''),
      npcActions: asListOfMaps<NpcAction>(m['npcActions'], NpcAction.fromJson),
      reveals: asList<String>(m['reveals'], (e) => asSOr(e, '')),
      mood: asSOr(m['mood'], ''),
      nextChoices: asListOfMaps<PlanChoice>(m['nextChoices'], PlanChoice.fromJson),
      advanceTimeDays: asD(m['advanceTimeDays']),
      chapterEnd: m['chapterEnd'] is Map ? ChapterEnd.fromJson(m['chapterEnd']) : null,
    );
  }
}
