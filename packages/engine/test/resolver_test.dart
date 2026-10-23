import 'dart:math';

import 'package:contracts/contracts.dart';
import 'package:engine/src/rules/resolver.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('successRate 公式', () {
    final base = makeState();

    int rate(RunState s, int dc, {int env = 0, int affinity = 0}) =>
        Resolver.successRate(
          state: s,
          stat: CheckStat.body,
          dc: dc,
          targetStage: s.character.realm.stage,
          environment: env,
          presentAffinity: affinity,
          conditions: s.character.conditions,
        );

    test('中性参数下成功率恰为 50', () {
      expect(rate(base, 50), 50);
    });

    test('DC 偏移对照表（规则与判定 §3）', () {
      expect(rate(base, 30), 70); // 容易 +20
      expect(rate(base, 50), 50); // 普通 0
      expect(rate(base, 65), 35); // 困难 -15
      expect(rate(base, 80), 20); // 极难 -30
    });

    test('属性修正 = (attr-50)/5 向下取整，钳 ±10', () {
      expect(
        Resolver.successRate(
          state: makeState(body: 100),
          stat: CheckStat.body,
          dc: 50,
          targetStage: 1,
        ),
        60,
      );
      expect(
        Resolver.successRate(
          state: makeState(body: 0),
          stat: CheckStat.body,
          dc: 50,
          targetStage: 1,
        ),
        40,
      );
      expect(
        Resolver.successRate(
          state: makeState(spirit: 100),
          stat: CheckStat.spirit,
          dc: 50,
          targetStage: 1,
        ),
        60,
      );
      // luck 走 flags.luck
      expect(
        Resolver.successRate(
          state: makeState(flags: {'luck': 95}),
          stat: CheckStat.luck,
          dc: 50,
          targetStage: 1,
        ),
        59,
      );
    });

    test('境界差每层 12，钳 ±30', () {
      // 目标境界比当前低 1 层（对弱敌）→ +12
      expect(
        Resolver.successRate(
          state: base,
          stat: CheckStat.body,
          dc: 50,
          targetStage: base.character.realm.stage - 1,
        ),
        62,
      );
      // 高 3 层 → -36 钳到 -30
      expect(
        Resolver.successRate(
          state: base,
          stat: CheckStat.body,
          dc: 50,
          targetStage: base.character.realm.stage + 3,
        ),
        20,
      );
    });

    test('状态修正 severity×4，钳 -30', () {
      final wounded = makeState()
        ..character.conditions.addAll([
          Condition(id: 'c1', label: '重伤', severity: 5),
          Condition(id: 'c2', label: '中毒', severity: 4),
        ]);
      expect(rate(wounded, 50), 20); // -36 钳到 -30
    });

    test('上下限 5 / 95（永不必成必败）', () {
      final doomed = makeState(body: 0)
        ..character.conditions.add(Condition(id: 'c1', label: '重伤', severity: 5));
      expect(rate(doomed, 80, env: -20), 5);

      final blessed = makeState(body: 100, flags: {'luck': 100});
      expect(
        Resolver.successRate(
          state: blessed,
          stat: CheckStat.body,
          dc: 30,
          targetStage: 1,
          environment: 20,
          presentAffinity: 100,
        ),
        95,
      );
    });
  });

  group('grade 五级边界（表驱动）', () {
    final cases = <(int, int, Grade)>[
      (1, -100, Grade.critical_success), // roll ≤ 5 无视 margin
      (5, -99, Grade.critical_success),
      (96, 99, Grade.critical_fail), // roll ≥ 96 无视 margin
      (100, 0, Grade.critical_fail),
      (25, 20, Grade.success), // margin ≥ 20
      (30, 19, Grade.narrow), // 0 ≤ margin < 20
      (50, 0, Grade.narrow),
      (51, -1, Grade.fail), // -15 ≤ margin < 0
      (65, -15, Grade.fail),
      (66, -16, Grade.critical_fail), // margin < -15
    ];
    for (final (roll, margin, expected) in cases) {
      test('roll=$roll margin=$margin → $expected', () {
        expect(Resolver.grade(roll, margin), expected);
      });
    }
  });

  group('resolve 可行性与确定性', () {
    test('缺物品 → feasible=false 且不掷骰', () {
      final r = Resolver(random: SeqRandom([50]))
          .resolve(
            ResolveRequest(
              intent: '服丹突破',
              stat: CheckStat.spirit,
              dc: 50,
              itemCosts: [ItemCost(id: 'i_pill', qty: 2)],
            ),
            makeState()
              ..inventory.add(Item(id: 'i_pill', name: '筑基丹', qty: 1)),
          );
      expect(r.feasible, isFalse);
      expect(r.blockedReason, isNotNull);
      expect(r.check, isNull);
    });

    test('神识不足 → feasible=false', () {
      final r = Resolver().resolve(
        ResolveRequest(intent: '神识探查', stat: CheckStat.spirit, dc: 50, spiritCost: 30),
        makeState(spirit: 10),
      );
      expect(r.feasible, isFalse);
      expect(r.blockedReason, contains('神识'));
    });

    test('同 seed 同输入结果完全一致（可复现）', () {
      final state = makeState();
      ResolveRequest req() => ResolveRequest(
            intent: '夜探药庐',
            stat: CheckStat.body,
            dc: 65,
            timeDays: 1,
            environment: -5,
          );
      final a = Resolver(random: Random(42)).resolve(req(), state);
      final b = Resolver(random: Random(42)).resolve(req(), state);
      expect(a.check!.roll, b.check!.roll);
      expect(a.check!.grade, b.check!.grade);
      expect(a.check!.successRate, b.check!.successRate);
      expect(a.cost.timeDays, b.cost.timeDays);
    });

    test('防刷：重复行动时间成本递增', () {
      final state = makeState();
      ResolveRequest req(int n) => ResolveRequest(
            intent: '打听消息',
            stat: CheckStat.luck,
            dc: 50,
            timeDays: 1,
            repeatCount: n,
          );
      final first = Resolver(random: Random(7)).resolve(req(1), state);
      final third = Resolver(random: Random(7)).resolve(req(3), state);
      expect(third.cost.timeDays, greaterThan(first.cost.timeDays));
    });

    test('失败不扣物品，只有成功路径返回 cost.items 原单', () {
      final state = makeState()
        ..inventory.add(Item(id: 'i_rope', name: '绳索', qty: 1));
      final r = Resolver(random: SeqRandom([96])) // 必大失败
          .resolve(
        ResolveRequest(
          intent: '攀墙',
          stat: CheckStat.body,
          dc: 65,
          itemCosts: [ItemCost(id: 'i_rope', qty: 1)],
        ),
        state,
      );
      expect(r.feasible, isTrue);
      expect(r.check!.grade, Grade.critical_fail);
      expect(r.cost.items, hasLength(1));
    });
  });

  group('clash 三段冲突', () {
    test('同 seed 结果一致且优势点守恒', () {
      final state = makeState();
      for (final seed in [1, 11, 42, 99, 12345]) {
        final a = Resolver(random: Random(seed))
            .clash(stat: CheckStat.body, opponentStage: 1, opponentSkill: 50, state: state);
        final b = Resolver(random: Random(seed))
            .clash(stat: CheckStat.body, opponentStage: 1, opponentSkill: 50, state: state);
        expect(a.won, b.won, reason: 'seed $seed');
        expect(a.myPoints, b.myPoints);
        expect(a.foePoints, b.foePoints);
        expect(a.myPoints + a.foePoints, lessThanOrEqualTo(3));
        // 先取 2 分者胜，或三段打满仍未分出
        if (a.myPoints >= 2 || a.foePoints >= 2) {
          expect(a.won, a.myPoints > a.foePoints);
        }
        expect(a.rolls.length, lessThanOrEqualTo(3));
      }
    });
  });
}
