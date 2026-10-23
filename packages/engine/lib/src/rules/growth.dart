import 'dart:math';

import 'package:contracts/contracts.dart';

class BreakthroughOutcome {
  final bool success;
  final bool criticalFail;
  final int roll;
  final int dc;
  final int successRate;
  final String realmName;
  final int newStage;
  final int newLayer;
  final int lifespanAfter;
  final int vitalityDelta;
  final int lifespanDelta;
  final int heartDemonDelta;

  BreakthroughOutcome({
    required this.success,
    required this.criticalFail,
    required this.roll,
    required this.dc,
    required this.successRate,
    required this.realmName,
    required this.newStage,
    required this.newLayer,
    required this.lifespanAfter,
    required this.vitalityDelta,
    required this.lifespanDelta,
    required this.heartDemonDelta,
  });
}

class Growth {
  final Random random;

  Growth({Random? random}) : random = random ?? Random.secure();

  /// 突破判定：DC = 基础难度 + (目标层级 - 1) × 5 + 心魔 × 8（规则与判定 §6）
  BreakthroughOutcome breakthrough(
    RunState state,
    WorldBible bible, {
    required int targetStage,
    required int targetLayer,
  }) {
    final tier = bible.tierByStage(targetStage);
    if (tier == null) {
      throw ArgumentError('unknown tier stage $targetStage');
    }
    final heartDemon = state.heartDemon;
    final dc = tier.breakthroughRisk + (targetLayer - 1) * 5 + heartDemon * 8;
    // 突破判定可高于常规 DC 上限，成功率仍 clamp 5..95
    final attrMod = ((state.character.stats.spirit - 50) / 5).floor().clamp(-10, 10);
    final rate = (50 + attrMod - 0).clamp(5, 95);
    final roll = random.nextInt(100) + 1;
    final critFail = roll >= ResolverFloor.critFailMin;
    final success = !critFail && roll <= rate;

    if (success && !critFail) {
      return BreakthroughOutcome(
        success: true,
        criticalFail: false,
        roll: roll,
        dc: dc,
        successRate: rate,
        realmName: tier.name,
        newStage: targetStage,
        newLayer: targetLayer,
        lifespanAfter: tier.lifespan,
        vitalityDelta: 0,
        lifespanDelta: tier.lifespan - state.meta.lifespan,
        heartDemonDelta: 0,
      );
    }
    if (critFail) {
      return BreakthroughOutcome(
        success: false,
        criticalFail: true,
        roll: roll,
        dc: dc,
        successRate: rate,
        realmName: tier.name,
        newStage: state.character.realm.stage,
        newLayer: state.character.realm.layer,
        lifespanAfter: state.meta.lifespan,
        vitalityDelta: -30,
        lifespanDelta: -5,
        heartDemonDelta: 2,
      );
    }
    return BreakthroughOutcome(
      success: false,
      criticalFail: false,
      roll: roll,
      dc: dc,
      successRate: rate,
      realmName: tier.name,
      newStage: state.character.realm.stage,
      newLayer: state.character.realm.layer,
      lifespanAfter: state.meta.lifespan - 5,
      vitalityDelta: -30,
      lifespanDelta: -5,
      heartDemonDelta: 1,
    );
  }

  /// 修炼进度：事件完成 +5..15，顿悟 +20..30，苦修按天折算
  int progressGain({required String grade, required double timeDays, required Random rnd}) {
    if (grade == 'critical_success') return 20 + rnd.nextInt(11);
    if (grade == 'success') return 12 + rnd.nextInt(6);
    if (grade == 'narrow') return 5 + rnd.nextInt(6);
    return (timeDays / 30 * 10).floor().clamp(0, 15);
  }
}

class ResolverFloor {
  static const int critFailMin = 96;
}
