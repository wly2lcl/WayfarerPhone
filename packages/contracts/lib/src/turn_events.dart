import 'choice.dart';
import 'delta.dart';
import 'json.dart';

enum IntentKind { action, query, meta, rejected }

enum Grade { critical_success, success, narrow, fail, critical_fail }

class EndingRef {
  String id;
  String type;
  String title;

  EndingRef({required this.id, required this.type, required this.title});

  Map<String, Object?> toJson() => {'id': id, 'type': type, 'title': title};

  static EndingRef fromJson(Object? j) {
    final m = rawMap(j);
    return EndingRef(
      id: asSOr(m['id'], ''),
      type: asSOr(m['type'], 'death'),
      title: asSOr(m['title'], ''),
    );
  }
}

sealed class TurnInput {
  Map<String, Object?> toJson();
}

class ChoiceInput extends TurnInput {
  final String choiceId;
  ChoiceInput(this.choiceId);

  @override
  Map<String, Object?> toJson() => {'kind': 'choice', 'choiceId': choiceId};
}

class FreeTextInput extends TurnInput {
  final String text;
  FreeTextInput(this.text);

  @override
  Map<String, Object?> toJson() => {'kind': 'free', 'text': text};
}

TurnInput turnInputFromJson(Map<String, Object?> m) {
  if (m['kind'] == 'choice') return ChoiceInput(asSOr(m['choiceId'], ''));
  return FreeTextInput(asSOr(m['text'], ''));
}

class ResolveCost {
  double timeDays;
  int spirit;
  List<ItemCost> items;

  ResolveCost({required this.timeDays, required this.spirit, required this.items});

  Map<String, Object?> toJson() => {
        'timeDays': timeDays,
        'spirit': spirit,
        'items': items.map((i) => i.toJson()).toList(),
      };

  static ResolveCost fromJson(Object? j) {
    final m = rawMap(j);
    return ResolveCost(
      timeDays: asDOr(m['timeDays'], 0),
      spirit: asIOr(m['spirit'], 0),
      items: asList<ItemCost>(m['items'], ItemCost.fromJson),
    );
  }
}

class ItemCost {
  String id;
  int qty;

  ItemCost({required this.id, required this.qty});

  Map<String, Object?> toJson() => {'id': id, 'qty': qty};

  static ItemCost fromJson(Object? j) {
    final m = rawMap(j);
    return ItemCost(id: asSOr(m['id'], ''), qty: asIOr(m['qty'], 1));
  }
}

class ResolveCheck {
  CheckStat stat;
  int dc;
  int successRate;
  int roll;
  int margin;
  Grade grade;

  ResolveCheck({
    required this.stat,
    required this.dc,
    required this.successRate,
    required this.roll,
    required this.margin,
    required this.grade,
  });

  Map<String, Object?> toJson() => {
        'stat': stat.name,
        'dc': dc,
        'successRate': successRate,
        'roll': roll,
        'margin': margin,
        'grade': grade.name,
      };

  static ResolveCheck fromJson(Object? j) {
    final m = rawMap(j);
    return ResolveCheck(
      stat: enumBy(CheckStat.values, m['stat'], CheckStat.body),
      dc: asIOr(m['dc'], 50),
      successRate: asIOr(m['successRate'], 50),
      roll: asIOr(m['roll'], 50),
      margin: asIOr(m['margin'], 0),
      grade: enumBy(Grade.values, m['grade'], Grade.success),
    );
  }
}

class ResolveResult {
  bool feasible;
  String? blockedReason;
  ResolveCost cost;
  ResolveCheck? check;

  ResolveResult({
    required this.feasible,
    this.blockedReason,
    required this.cost,
    this.check,
  });

  Map<String, Object?> toJson() => {
        'feasible': feasible,
        if (blockedReason != null) 'blockedReason': blockedReason,
        'cost': cost.toJson(),
        if (check != null) 'check': check!.toJson(),
      };

  static ResolveResult fromJson(Object? j) {
    final m = rawMap(j);
    return ResolveResult(
      feasible: asBOr(m['feasible'], false),
      blockedReason: asS(m['blockedReason']),
      cost: ResolveCost.fromJson(m['cost']),
      check: m['check'] == null ? null : ResolveCheck.fromJson(m['check']),
    );
  }
}

sealed class TurnEvent {
  Map<String, Object?> toJson();
}

class TurnStart extends TurnEvent {
  final int turn;
  TurnStart(this.turn);

  @override
  Map<String, Object?> toJson() => {'type': 'turnStart', 'turn': turn};
}

class Classification extends TurnEvent {
  final IntentKind kind;
  final String intent;
  Classification(this.kind, this.intent);

  @override
  Map<String, Object?> toJson() =>
      {'type': 'classification', 'kind': kind.name, 'intent': intent};
}

class NarrationDelta extends TurnEvent {
  final String text;
  NarrationDelta(this.text);

  @override
  Map<String, Object?> toJson() => {'type': 'narrationDelta', 'text': text};
}

class NarrationEnd extends TurnEvent {
  @override
  Map<String, Object?> toJson() => {'type': 'narrationEnd'};
}

class ChoicesAvailable extends TurnEvent {
  final List<Choice> options;
  ChoicesAvailable(this.options);

  @override
  Map<String, Object?> toJson() => {
        'type': 'choices',
        'options': options.map((c) => c.toJson()).toList(),
      };
}

class StatePatch extends TurnEvent {
  final StateDelta delta;
  StatePatch(this.delta);

  @override
  Map<String, Object?> toJson() => {'type': 'statePatch', 'delta': delta.toJson()};
}

class TurnEnd extends TurnEvent {
  final int turn;
  final String? snapshotId;
  final EndingRef? ending;
  TurnEnd(this.turn, this.snapshotId, this.ending);

  @override
  Map<String, Object?> toJson() => {
        'type': 'turnEnd',
        'turn': turn,
        if (snapshotId != null) 'snapshotId': snapshotId,
        if (ending != null) 'ending': ending!.toJson(),
      };
}

class ChapterCompleted extends TurnEvent {
  final int chapter;
  final String reason;
  final String summary;
  ChapterCompleted(this.chapter, this.reason, {this.summary = ''});

  @override
  Map<String, Object?> toJson() => {
        'type': 'chapterCompleted',
        'chapter': chapter,
        'reason': reason,
        if (summary.isNotEmpty) 'summary': summary,
      };
}

class TurnError extends TurnEvent {
  final String code;
  final String message;
  final bool canRetry;
  TurnError(this.code, this.message, this.canRetry);

  @override
  Map<String, Object?> toJson() =>
      {'type': 'turnError', 'code': code, 'message': message, 'canRetry': canRetry};
}

sealed class AssistantEvent {
  Map<String, Object?> toJson();
}

class AssistantDelta extends AssistantEvent {
  final String text;
  AssistantDelta(this.text);

  @override
  Map<String, Object?> toJson() => {'type': 'assistantDelta', 'text': text};
}

class AssistantEnd extends AssistantEvent {
  final int tokensIn;
  final int tokensOut;
  AssistantEnd(this.tokensIn, this.tokensOut);

  @override
  Map<String, Object?> toJson() =>
      {'type': 'assistantEnd', 'tokensIn': tokensIn, 'tokensOut': tokensOut};
}
