import 'dart:math';

import 'package:contracts/contracts.dart';
import 'package:engine/src/rules/ending.dart';
import 'package:engine/src/rules/growth.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final bible = loadBible();

  group('突破 DC 与三分支', () {
    test('DC = 基础难度 + (目标层级-1)×5 + 心魔×8', () {
      final s = makeState(flags: {'heartDemon': 2});
      final out = Growth(random: Random(1)).breakthrough(s, bible,
          targetStage: 2, targetLayer: 3);
      expect(out.dc, 65 + (3 - 1) * 5 + 2 * 8); // 91，仅作记录，不参与成功率;
    });

    test('成功：境界/寿元上调（roll ≤ rate）', () {
      final s = makeState(spirit: 60); // rate = 50 + 2 = 52
      final out = Growth(random: SeqRandom([10])) // roll = 11
          .breakthrough(s, bible, targetStage: 2, targetLayer: 1);
      expect(out.success, isTrue);
      expect(out.criticalFail, isFalse);
      expect(out.newStage, 2);
      expect(out.newLayer, 1);
      expect(out.realmName, '筑基');
      expect(out.lifespanAfter, 200);
      expect(out.lifespanDelta, 80);
      expect(out.vitalityDelta, 0);
      expect(out.heartDemonDelta, 0);
    });

    test('失败：气血-30 寿元-5 心魔+1（roll > rate 且 < 96）', () {
      final s = makeState(spirit: 50); // rate = 50
      final out = Growth(random: SeqRandom([60])) // roll = 61
          .breakthrough(s, bible, targetStage: 2, targetLayer: 1);
      expect(out.success, isFalse);
      expect(out.criticalFail, isFalse);
      expect(out.newStage, 1);
      expect(out.lifespanDelta, -5);
      expect(out.vitalityDelta, -30);
      expect(out.heartDemonDelta, 1);
    });

    test('大失败（roll ≥ 96）：走火入魔，心魔+2', () {
      final s = makeState(spirit: 100); // rate = 60，roll 96 依然大失败
      final out = Growth(random: SeqRandom([95])) // roll = 96
          .breakthrough(s, bible, targetStage: 2, targetLayer: 1);
      expect(out.success, isFalse);
      expect(out.criticalFail, isTrue);
      expect(out.heartDemonDelta, 2);
      expect(out.lifespanDelta, -5);
      expect(out.vitalityDelta, -30);
    });

    test('心魔推高 DC 但不改成功率上限（5..95 钳制）', () {
      final s = makeState(spirit: 0, flags: {'heartDemon': 9});
      final out = Growth(random: SeqRandom([94])) // roll = 95
          .breakthrough(s, bible, targetStage: 2, targetLayer: 1);
      expect(out.successRate, 40); // 50 - 10
      expect(out.success, isFalse);
    });

    test('progressGain 按结果分级', () {
      final g = Growth();
      expect(g.progressGain(grade: 'critical_success', timeDays: 0, rnd: SeqRandom([5])), 25);
      expect(g.progressGain(grade: 'success', timeDays: 0, rnd: SeqRandom([3])), 15);
      expect(g.progressGain(grade: 'narrow', timeDays: 0, rnd: SeqRandom([0])), 5);
      expect(
        g.progressGain(grade: 'fail', timeDays: 90, rnd: SeqRandom([0])),
        30.clamp(0, 15),
      );
    });
  });

  group('终局表达式', () {
    test('原子条件', () {
      final s = makeState(vitality: 0);
      expect(EndingEvaluator.evaluate('vitality <= 0', s), isTrue);
      expect(EndingEvaluator.evaluate('vitality < 0', s), isFalse);
      expect(EndingEvaluator.evaluate('age >= lifespan', s), isFalse);
    });

    test('心魔终局（M0 必达 ending_fall）', () {
      final calm = makeState(flags: {'heartDemon': 4});
      final fallen = makeState(flags: {'heartDemon': 5});
      expect(EndingEvaluator.evaluate('heartDemon >= 5', calm), isFalse);
      expect(EndingEvaluator.evaluate('heartDemon >= 5', fallen), isTrue);
    });

    test('&& / || 组合与 flag 比较', () {
      final s = makeState(flags: {'guixu_truth': true});
      expect(
        EndingEvaluator.evaluate(
            'stage >= 4 && layer >= 3 && progress >= 100 && flag("guixu_truth") == true',
            s),
        isFalse, // stage 不够
      );
      expect(EndingEvaluator.evaluate('flag("guixu_truth") == true', s), isTrue);
      expect(EndingEvaluator.evaluate('flag("missing") == true', s), isFalse);
      expect(
        EndingEvaluator.evaluate('heartDemon >= 5 || vitality <= 0',
            makeState(vitality: 0)),
        isTrue,
      );
      expect(
        EndingEvaluator.evaluate(
            'flag("left_the_path") == true && flag("truth_left") == true',
            makeState(flags: {'left_the_path': true, 'truth_left': true})),
        isTrue,
      );
    });

    test('未知原子抛 FormatException，findTriggered 跳过坏规则', () {
      expect(
        () => EndingEvaluator.evaluate('mana >= 5', makeState()),
        throwsFormatException,
      );
      // 坏规则 + 一条命中的规则 → 返回命中项
      final broken = EndingRule(
        id: 'ending_bad',
        type: EndingType.death,
        condition: 'mana >= 5',
        title: 'x',
      );
      final real = bible.endgame.firstWhere((e) => e.id == 'ending_fall');
      final hit = EndingEvaluator.findTriggered(
          bible, makeState(flags: {'heartDemon': 9}));
      expect(hit!.id, 'ending_fall');
      final none = EndingEvaluator.findTriggered(
          WorldBible.fromJson(bible.toJson()..['endgame'] = [broken.toJson()]),
          makeState());
      expect(none, isNull);
      expect(real.id, 'ending_fall');
    });
  });

  group('濒死判定与终局执行', () {
    test('气血归零：判定失败触发 ending_death，判定成功可存活', () {
      final s = makeState(vitality: 0);
      // 掷出 100（DC 由 body+luck 决定，rate ≤ 95 → 必失败）
      expect(
        EndingApplier.checkAndApply(bible: bible, state: s, random: SeqRandom([99])),
        isNotNull,
      );
      // 掷出 1 → 必存活
      expect(
        EndingApplier.checkAndApply(bible: bible, state: s, random: SeqRandom([0])),
        isNull,
      );
    });

    test('寿元耗尽不走濒死判定，直接终局', () {
      final s = makeState();
      s.meta.age = s.meta.lifespan;
      expect(
        EndingApplier.checkAndApply(bible: bible, state: s, random: SeqRandom([0])),
        isNotNull,
      );
    });

    test('正常状态不触发任何终局', () {
      expect(
        EndingApplier.checkAndApply(bible: bible, state: makeState(), random: Random(1)),
        isNull,
      );
    });

    test('dyingSurvives 速率受根骨与气运影响', () {
      final strong = makeState(body: 100, flags: {'luck': 100}); // rate = 95
      final weak = makeState(body: 0, flags: {'luck': 0}); // rate = 5
      expect(EndingEvaluator.dyingSurvives(strong, SeqRandom([0])), isTrue);
      expect(EndingEvaluator.dyingSurvives(weak, SeqRandom([90])), isFalse);
    });
  });
}
