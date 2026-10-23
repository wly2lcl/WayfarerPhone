import 'json.dart';

enum Risk { low, medium, high }

enum CheckStat { body, spirit, luck }

class ChoiceRequires {
  List<String>? knowledge;
  List<String>? items;
  String? realm;

  ChoiceRequires({this.knowledge, this.items, this.realm});

  Map<String, Object?> toJson() => {
        if (knowledge != null) 'knowledge': knowledge,
        if (items != null) 'items': items,
        if (realm != null) 'realm': realm,
      };

  static ChoiceRequires fromJson(Object? j) {
    final m = rawMap(j);
    return ChoiceRequires(
      knowledge: (m['knowledge'] as List?)?.map((e) => asSOr(e, '')).toList(),
      items: (m['items'] as List?)?.map((e) => asSOr(e, '')).toList(),
      realm: asS(m['realm']),
    );
  }
}

class ChoiceCheck {
  CheckStat stat;
  int dc;

  ChoiceCheck({required this.stat, required this.dc});

  Map<String, Object?> toJson() => {'stat': stat.name, 'dc': dc};

  static ChoiceCheck fromJson(Object? j) {
    final m = rawMap(j);
    return ChoiceCheck(
      stat: enumBy(CheckStat.values, m['stat'], CheckStat.body),
      dc: asIOr(m['dc'], 50),
    );
  }
}

class Choice {
  String id;
  String label;
  String intent;
  Risk risk;
  ChoiceRequires? requires;
  bool? hidden;
  ChoiceCheck? check;

  Choice({
    required this.id,
    required this.label,
    required this.intent,
    required this.risk,
    this.requires,
    this.hidden,
    this.check,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'intent': intent,
        'risk': risk.name,
        if (requires != null) 'requires': requires!.toJson(),
        if (hidden != null) 'hidden': hidden,
        if (check != null) 'check': check!.toJson(),
      };

  static Choice fromJson(Object? j) {
    final m = rawMap(j);
    return Choice(
      id: asSOr(m['id'], ''),
      label: asSOr(m['label'], ''),
      intent: asSOr(m['intent'], ''),
      risk: enumBy(Risk.values, m['risk'], Risk.medium),
      requires:
          m['requires'] == null ? null : ChoiceRequires.fromJson(m['requires']),
      hidden: m['hidden'] is bool ? m['hidden'] as bool : null,
      check: m['check'] == null ? null : ChoiceCheck.fromJson(m['check']),
    );
  }
}
