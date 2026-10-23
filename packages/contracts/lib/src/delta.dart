import 'json.dart';
import 'run_state.dart';

class Op {
  String op;
  String path;
  Object? value;
  int? by;
  String? reason;

  Op({required this.op, required this.path, this.value, this.by, this.reason});

  Map<String, Object?> toJson() => {
        'op': op,
        'path': path,
        if (value != null) 'value': value,
        if (by != null) 'by': by,
        if (reason != null) 'reason': reason,
      };

  static Op fromJson(Object? j) {
    final m = rawMap(j);
    return Op(
      op: asSOr(m['op'], 'set'),
      path: asSOr(m['path'], ''),
      value: m['value'],
      by: asI(m['by']),
      reason: asS(m['reason']),
    );
  }
}

class StateDelta {
  List<Op> ops;
  List<String> facts;
  List<Thread> openThreads;
  List<String> closeThreads;

  StateDelta({
    required this.ops,
    required this.facts,
    List<Thread>? openThreads,
    List<String>? closeThreads,
  })  : openThreads = openThreads ?? [],
        closeThreads = closeThreads ?? [];

  Map<String, Object?> toJson() => {
        'ops': ops.map((o) => o.toJson()).toList(),
        'facts': facts,
        'openThreads': openThreads.map((t) => t.toJson()).toList(),
        'closeThreads': closeThreads,
      };

  static StateDelta fromJson(Object? j) {
    final m = rawMap(j);
    return StateDelta(
      ops: asList<Op>(m['ops'], Op.fromJson),
      facts: asList<String>(m['facts'], (e) => asSOr(e, '')),
      openThreads: asList<Thread>(m['openThreads'], Thread.fromJson),
      closeThreads: asList<String>(m['closeThreads'], (e) => asSOr(e, '')),
    );
  }

  static StateDelta empty() => StateDelta(ops: [], facts: []);
}
