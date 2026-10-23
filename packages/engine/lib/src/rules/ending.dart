import 'dart:math';

import 'package:contracts/contracts.dart';
import '../errors.dart';

/// 终局评估：解析 EndingRule.condition 受限表达式（数据契约 §13.3）
/// 允许原子：vitality <= 0、age >= lifespan、heartDemon >= 5、
/// stage >= N && layer >= M && progress >= P、flag("key") == value，
/// 连接词 && / ||，比较符 >= > <= < ==。
class EndingEvaluator {
  static bool evaluate(String condition, RunState state) {
    final expr = _Expr.parse(condition);
    return expr.eval(_Env(state));
  }

  static EndingRule? findTriggered(WorldBible bible, RunState state) {
    for (final rule in bible.endgame) {
      try {
        if (evaluate(rule.condition, state)) return rule;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// 濒死判定：气血 ≤ 0 时 DC 70（根骨/气运），失败即死（规则与判定 §9）
  static bool dyingSurvives(RunState state, Random random) {
    final rate = (((state.character.stats.body + state.luck) ~/ 2) - 20)
        .clamp(5, 95);
    final roll = random.nextInt(100) + 1;
    return roll <= rate;
  }
}

class _Env {
  final RunState state;
  _Env(this.state);

  int vitality() => state.character.stats.vitality;
  int age() => state.meta.age;
  int lifespan() => state.meta.lifespan;
  int heartDemon() => state.heartDemon;
  int stage() => state.character.realm.stage;
  int layer() => state.character.realm.layer;
  int progress() => state.character.realm.progress;
  Object? flag(String key) => state.flags[key];
}

sealed class _Expr {
  bool eval(_Env env);

  static _Expr parse(String src) {
    final tokens = _tokenize(src);
    final p = _Parser(tokens);
    final e = p.parseOr();
    if (p.pos != tokens.length) throw const FormatException('trailing tokens');
    return e;
  }
}

class _Or implements _Expr {
  final List<_Expr> parts;
  _Or(this.parts);

  @override
  bool eval(_Env env) => parts.any((p) => p.eval(env));
}

class _And implements _Expr {
  final List<_Expr> parts;
  _And(this.parts);

  @override
  bool eval(_Env env) => parts.every((p) => p.eval(env));
}

class _Cmp implements _Expr {
  final int Function(_Env) left;
  final String op;
  final int Function(_Env) right;
  _Cmp(this.left, this.op, this.right);

  @override
  bool eval(_Env env) {
    final l = left(env);
    final r = right(env);
    return switch (op) {
      '>=' => l >= r,
      '>' => l > r,
      '<=' => l <= r,
      '<' => l < r,
      '==' => l == r,
      _ => throw const FormatException('bad op'),
    };
  }
}

class _FlagEq implements _Expr {
  final String key;
  final String value;
  _FlagEq(this.key, this.value);

  @override
  bool eval(_Env env) {
    final v = env.flag(key);
    if (v == null) return false;
    if (v is bool) return (value == 'true') == v;
    return v.toString() == value;
  }
}

class _Tok {
  final String t;
  _Tok(this.t);
}

List<_Tok> _tokenize(String src) {
  final re = RegExp(r'&&|\|\||>=|<=|>|<|==|[A-Za-z_][A-Za-z0-9_]*|\d+|"[^"]*"|[()]');
  return re
      .allMatches(src)
      .map((m) => _Tok(m.group(0)!))
      .toList(growable: false);
}

class _Parser {
  final List<_Tok> tokens;
  int pos = 0;
  _Parser(this.tokens);

  bool _eat(String t) {
    if (pos < tokens.length && tokens[pos].t == t) {
      pos++;
      return true;
    }
    return false;
  }

  _Expr parseOr() {
    final parts = <_Expr>[parseAnd()];
    while (_eat('||')) {
      parts.add(parseAnd());
    }
    return parts.length == 1 ? parts.first : _Or(parts);
  }

  _Expr parseAnd() {
    final parts = <_Expr>[parseAtom()];
    while (_eat('&&')) {
      parts.add(parseAtom());
    }
    return parts.length == 1 ? parts.first : _And(parts);
  }

  int Function(_Env) _value() {
    final t = tokens[pos].t;
    pos++;
    if (RegExp(r'^\d+$').hasMatch(t)) {
      final n = int.parse(t);
      return (_) => n;
    }
    switch (t) {
      case 'vitality':
        return (e) => e.vitality();
      case 'age':
        return (e) => e.age();
      case 'lifespan':
        return (e) => e.lifespan();
      case 'heartDemon':
        return (e) => e.heartDemon();
      case 'stage':
        return (e) => e.stage();
      case 'layer':
        return (e) => e.layer();
      case 'progress':
        return (e) => e.progress();
      default:
        throw FormatException('unknown atom $t');
    }
  }

  _Expr parseAtom() {
    if (tokens[pos].t == 'flag') {
      pos++;
      if (!_eat('(')) throw const FormatException('flag( expected');
      final key = tokens[pos].t.replaceAll('"', '');
      pos++;
      if (!_eat(')')) throw const FormatException(') expected');
      if (!_eat('==')) throw const FormatException('== expected');
      final value = tokens[pos].t.replaceAll('"', '');
      pos++;
      return _FlagEq(key, value);
    }
    final left = _value();
    final op = tokens[pos].t;
    if (!['>=', '>', '<=', '<', '=='].contains(op)) {
      throw FormatException('bad comparison $op');
    }
    pos++;
    final right = _value();
    return _Cmp(left, op, right);
  }
}

/// 终局执行器：把命中的 EndingRule 应用到局上
class EndingApplier {
  static EndingRef? checkAndApply({
    required WorldBible bible,
    required RunState state,
    required Random random,
  }) {
    final rule = EndingEvaluator.findTriggered(bible, state);
    if (rule == null) return null;
    // 气血归零先走濒死判定（规则与判定 §9）；寿元耗尽等无濒死余地的直接终局
    if (rule.type == EndingType.death && state.character.stats.vitality <= 0) {
      if (EndingEvaluator.dyingSurvives(state, random)) {
        return null;
      }
    }
    return EndingRef(id: rule.id, type: rule.type.name, title: rule.title);
  }
}

void assertAlive(RunState state) {
  // 由调用方在落库前检查 run 状态
  if (state.character.stats.vitality < 0) {
    throw EngineException(EngineCode.stateInvalid, 'vitality < 0');
  }
}
