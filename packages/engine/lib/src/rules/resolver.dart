import 'dart:math';

import 'package:contracts/contracts.dart';

/// 判定参数集中配置（规则与判定 §3/§11）。调参只改这里。
class ResolverConfig {
  static const int successFloor = 5;
  static const int successCeil = 95;
  static const int critSuccessRollMax = 5;
  static const int critFailRollMin = 96;
  static const int attrDivisor = 5;
  static const int attrCap = 10;
  static const int realmStep = 12;
  static const int realmCap = 30;
  static const int envCap = 20;
  static const int relationCap = 10;
  static const int conditionCap = 30;
  static const int dyingDc = 70;
}

/// 判定输入
class ResolveRequest {
  final String intent;
  final CheckStat stat;
  final int dc;
  final double timeDays;
  final int spiritCost;
  final List<ItemCost> itemCosts;
  final int environment;
  final int repeatCount;

  ResolveRequest({
    required this.intent,
    required this.stat,
    required this.dc,
    this.timeDays = 1,
    this.spiritCost = 0,
    List<ItemCost>? itemCosts,
    this.environment = 0,
    this.repeatCount = 0,
  }) : itemCosts = itemCosts ?? const [];
}

class Resolver {
  final Random random;

  Resolver({Random? random}) : random = random ?? Random.secure();

  /// 成功率 = clamp(5,95, 50 + attr/5 + 境界差 + 环境 + 关系 + 状态 - (dc-50))
  static int successRate({
    required RunState state,
    required CheckStat stat,
    required int dc,
    required int targetStage,
    int environment = 0,
    int presentAffinity = 0,
    List<Condition> conditions = const [],
  }) {
    final attr = switch (stat) {
      CheckStat.body => state.character.stats.body,
      CheckStat.spirit => state.character.stats.spirit,
      CheckStat.luck => state.luck,
    };
    final attrMod = ((attr - 50) / ResolverConfig.attrDivisor)
        .floor()
        .clamp(-ResolverConfig.attrCap, ResolverConfig.attrCap);
    final realmMod = ((state.character.realm.stage - targetStage) *
            ResolverConfig.realmStep)
        .clamp(-ResolverConfig.realmCap, ResolverConfig.realmCap);
    final envMod = environment.clamp(-ResolverConfig.envCap, ResolverConfig.envCap);
    final relMod =
        (presentAffinity ~/ 10).clamp(-ResolverConfig.relationCap, ResolverConfig.relationCap);
    var condMod = 0;
    for (final c in conditions) {
      condMod -= c.severity * 4;
    }
    condMod = condMod.clamp(-ResolverConfig.conditionCap, 0);
    final raw = 50 +
        attrMod +
        realmMod +
        envMod +
        relMod +
        condMod -
        (dc - 50);
    return raw.clamp(ResolverConfig.successFloor, ResolverConfig.successCeil);
  }

  static Grade grade(int roll, int margin) {
    if (roll <= ResolverConfig.critSuccessRollMax) return Grade.critical_success;
    if (roll >= ResolverConfig.critFailRollMin) return Grade.critical_fail;
    if (margin >= 20) return Grade.success;
    if (margin >= 0) return Grade.narrow;
    if (margin >= -15) return Grade.fail;
    return Grade.critical_fail;
  }

  ResolveResult resolve(ResolveRequest req, RunState state) {
    final world = state;
    // 可行性：物品
    for (final need in req.itemCosts) {
      final item = world.inventory.where((i) => i.id == need.id).toList();
      final qty = item.isEmpty ? 0 : item.first.qty;
      if (qty < need.qty) {
        return ResolveResult(
          feasible: false,
          blockedReason: '身上没有$need.qty个${item.isEmpty ? need.id : item.first.name}',
          cost: ResolveCost(timeDays: 0, spirit: 0, items: []),
        );
      }
    }
    // 可行性：神识
    if (req.spiritCost > 0 && world.character.stats.spirit < req.spiritCost) {
      return ResolveResult(
        feasible: false,
        blockedReason: '神识不济，撑不起这个打算',
        cost: ResolveCost(timeDays: 0, spirit: 0, items: []),
      );
    }

    final successRateValue = successRate(
      state: state,
      stat: req.stat,
      dc: req.dc,
      targetStage: state.character.realm.stage,
      environment: req.environment,
      conditions: state.character.conditions,
    );

    final roll = random.nextInt(100) + 1;
    final margin = successRateValue - roll;
    final gradeValue = grade(roll, margin);

    // 防刷：重复行动收益递减 → 时间成本递增
    final timeMult = 1.0 + 0.6 * max(0, req.repeatCount - 1);

    return ResolveResult(
      feasible: true,
      cost: ResolveCost(
        timeDays: req.timeDays <= 0
            ? 0.0
            : (req.timeDays * timeMult).clamp(0.5, 1095.0),
        spirit: req.spiritCost,
        items: List.of(req.itemCosts),
      ),
      check: ResolveCheck(
        stat: req.stat,
        dc: req.dc,
        successRate: successRateValue,
        roll: roll,
        margin: margin,
        grade: gradeValue,
      ),
    );
  }

  /// 冲突结算：三段（试探/交锋/决胜），先取 2 个优势点者胜（规则与判定 §5）
  ClashResult clash({
    required CheckStat stat,
    required int opponentStage,
    required int opponentSkill,
    RunState? state,
  }) {
    final s = state;
    var myPoints = 0;
    var foePoints = 0;
    final rolls = <ResolveCheck>[];
    for (var i = 0; i < 3 && myPoints < 2 && foePoints < 2; i++) {
      final rate = successRate(
        state: s!,
        stat: stat,
        dc: 50 + (i * 10),
        targetStage: opponentStage,
        conditions: s.character.conditions,
      ) + (opponentSkill - 50) ~/ 2;
      final clamped = rate.clamp(5, 95);
      final roll = random.nextInt(100) + 1;
      final margin = clamped - roll;
      final g = grade(roll, margin);
      rolls.add(ResolveCheck(
        stat: stat,
        dc: 50 + i * 10,
        successRate: clamped,
        roll: roll,
        margin: margin,
        grade: g,
      ));
      if (g == Grade.critical_success || g == Grade.success) {
        myPoints++;
      } else if (g == Grade.critical_fail || g == Grade.fail) {
        foePoints++;
      }
    }
    return ClashResult(
      won: myPoints > foePoints,
      myPoints: myPoints,
      foePoints: foePoints,
      rolls: rolls,
    );
  }
}

class ClashResult {
  final bool won;
  final int myPoints;
  final int foePoints;
  final List<ResolveCheck> rolls;

  ClashResult({
    required this.won,
    required this.myPoints,
    required this.foePoints,
    required this.rolls,
  });
}
