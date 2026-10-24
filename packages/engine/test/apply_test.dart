import 'package:contracts/contracts.dart';
import 'package:engine/src/turn/apply.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final bible = loadBible();

  ApplyResult apply(RunState s, List<Op> ops, {bool runEnded = false}) =>
      applyOps(s, ops, bible: bible, runEnded: runEnded);

  group('禁止路径（数据契约 §5.2）', () {
    final forbidden = [
      Op(op: 'set', path: 'meta.chapter', value: 5),
      Op(op: 'set', path: 'meta.turnNo', value: 99),
      Op(op: 'set', path: 'meta.lifespan', value: 999),
      Op(op: 'set', path: 'character.name', value: '改名'),
      Op(op: 'set', path: 'character.identityId', value: 'id_escort_outcast'),
      Op(op: 'inc', path: 'flags.luck', by: 20),
      Op(op: 'inc', path: 'flags.heartDemon', by: 1),
      Op(op: 'set', path: 'flags.pendingRepair', value: true),
    ];
    for (final op in forbidden) {
      test('${op.path} 一律拒绝', () {
        final s = makeState();
        final r = apply(s, [op]);
        expect(r.rejected, hasLength(1));
        expect(r.applied, isEmpty);
        expect(r.rejected.first.reason, 'engine-owned path');
      });
    }

    test('runEnded 后所有 op 被拒', () {
      final s = makeState();
      final r = apply(s, [
        Op(op: 'inc', path: 'character.stats.vitality', by: 10),
        Op(op: 'push', path: 'knowledge', value: '新知'),
      ], runEnded: true);
      expect(r.rejected, hasLength(2));
      expect(s.character.stats.vitality, 80);
    });
  });

  group('属性与资源', () {
    test('inc 负值触底钳 0', () {
      final s = makeState();
      final r = apply(s, [Op(op: 'inc', path: 'character.stats.vitality', by: -200)]);
      expect(r.rejected, isEmpty);
      expect(s.character.stats.vitality, 0);
    });

    test('set 越上限钳 100', () {
      final s = makeState();
      apply(s, [Op(op: 'set', path: 'character.stats.body', value: 150)]);
      expect(s.character.stats.body, 100);
    });

    test('灵石 inc / set', () {
      final s = makeState();
      apply(s, [
        Op(op: 'inc', path: 'character.resources.spiritStones', by: -30),
        Op(op: 'set', path: 'character.resources.spiritStones', value: 88),
      ]);
      expect(s.character.resources.spiritStones, 88);
    });

    test('丹药子路径按 id 增减', () {
      final s = makeState();
      final r = apply(s, [
        Op(op: 'inc', path: 'character.resources.pills.p_dingxin', by: 2),
        Op(op: 'inc', path: 'character.resources.pills.p_dingxin', by: 1),
      ]);
      expect(r.applied, hasLength(2));
      expect(s.character.resources.pills['p_dingxin'], 3);
    });

    test('age 钳到 [0, lifespan]', () {
      final s = makeState();
      apply(s, [Op(op: 'inc', path: 'meta.age', by: 500)]);
      expect(s.meta.age, 120);
    });
  });

  group('gameTime 单调', () {
    test('只进不退', () {
      final s = makeState(); // 1-03-15
      final r = apply(s, [Op(op: 'set', path: 'meta.gameTime', value: '1-03-10')]);
      expect(r.rejected.first.reason, 'gameTime must increase');
      expect(s.meta.gameTime, '1-03-15');
    });

    test('同一天也拒绝', () {
      final s = makeState();
      final r = apply(s, [Op(op: 'set', path: 'meta.gameTime', value: '1-03-15')]);
      expect(r.rejected, hasLength(1));
    });

    test('合法前进生效，非法格式拒绝', () {
      final s = makeState();
      final r = apply(s, [Op(op: 'set', path: 'meta.gameTime', value: '1-04-01')]);
      expect(r.applied, ['meta.gameTime']);
      expect(s.meta.gameTime, '1-04-01');

      final bad = apply(s, [Op(op: 'set', path: 'meta.gameTime', value: '明天')]);
      expect(bad.rejected, hasLength(1));
    });

    test('advanceGameTime 跨月跨年', () {
      expect(advanceGameTime('1-01-30', 2), '1-02-02');
      expect(advanceGameTime('1-12-30', 3), '2-01-03'); // 30 天/月历法
      expect(advanceGameTime('1-03-15', 0.5), '1-03-15'); // 不足一天向下取整
    });
  });

  group('位置校验', () {
    test('合法 regionId 生效并落到该区第一个地点', () {
      final s = makeState();
      final r = apply(s, [Op(op: 'set', path: 'location.regionId', value: 'reg_heishui')]);
      expect(r.applied, hasLength(1));
      expect(s.location.regionId, 'reg_heishui');
      expect(s.location.placeId, 'place_heishui_market');
    });

    test('未知 regionId 拒绝', () {
      final s = makeState();
      final r = apply(s, [Op(op: 'set', path: 'location.regionId', value: 'reg_moon')]);
      expect(r.rejected.first.reason, 'unknown regionId');
    });

    test('placeId 不属于当前区域拒绝', () {
      final s = makeState(); // reg_yunxiu
      final r = apply(s, [
        Op(op: 'set', path: 'location.placeId', value: 'place_qixia_main_peak'),
      ]);
      expect(r.rejected.first.reason, 'placeId not in current region');
    });

    test('先切区域再切地点可行', () {
      final s = makeState();
      final r = apply(s, [
        Op(op: 'set', path: 'location.regionId', value: 'reg_qixia'),
        Op(op: 'set', path: 'location.placeId', value: 'place_qixia_main_peak'),
      ]);
      expect(r.rejected, isEmpty);
      expect(s.location.placeId, 'place_qixia_main_peak');
    });
  });

  group('knowledge', () {
    test('push 去重', () {
      final s = makeState(); // 已含一条师父线索
      final r = apply(s, [Op(op: 'push', path: 'knowledge', value: '师父昨夜死在药炉旁')]);
      expect(r.rejected, isEmpty);
      expect(s.knowledge, hasLength(1));
    });

    test('超 80 字截断、超 300 淘汰最旧', () {
      final s = makeState()..knowledge.addAll(List.generate(299, (i) => 'k$i'));
      apply(s, [Op(op: 'push', path: 'knowledge', value: '很' * 100)]);
      expect(s.knowledge, hasLength(300));
      expect(s.knowledge.last, '很' * 80);
      expect(s.knowledge.first, 'k0'); // 师父线索作为最旧项被淘汰
      apply(s, [Op(op: 'push', path: 'knowledge', value: '新知一条')]);
      expect(s.knowledge, hasLength(300));
      expect(s.knowledge.first, 'k1');
    });

    test('set 被拒，remove 可用', () {
      final s = makeState();
      final r1 = apply(s, [Op(op: 'set', path: 'knowledge', value: 'x')]);
      expect(r1.rejected, hasLength(1));
      final r2 = apply(s, [Op(op: 'remove', path: 'knowledge', value: '师父昨夜死在药炉旁')]);
      expect(r2.applied, ['knowledge']);
      expect(s.knowledge, isEmpty);
    });
  });

  group('relations / reputation', () {
    test('affinity 钳 ±100，首次出现自动建档', () {
      final s = makeState();
      apply(s, [Op(op: 'inc', path: 'relations.npc_su_wan.affinity', by: 250)]);
      expect(s.relations['npc_su_wan']!.affinity, 100);
      apply(s, [Op(op: 'inc', path: 'relations.npc_su_wan.affinity', by: -300)]);
      expect(s.relations['npc_su_wan']!.affinity, -100);
    });

    test('trust 钳 0..100，status 按中文标签映射', () {
      final s = makeState();
      final r = apply(s, [
        Op(op: 'inc', path: 'relations.npc_lu_xingzhou.trust', by: 30),
        Op(op: 'set', path: 'relations.npc_lu_xingzhou.status', value: '信任'),
      ]);
      expect(r.rejected, isEmpty);
      expect(s.relations['npc_lu_xingzhou']!.trust, 50); // 默认 20 + 30
      expect(s.relations['npc_lu_xingzhou']!.status, RelationStatus.xinRen);
    });

    test('reputation 需为已知势力', () {
      final s = makeState();
      final bad = apply(s, [Op(op: 'inc', path: 'reputation.fac_moon', by: 5)]);
      expect(bad.rejected.first.reason, 'unknown factionId');
      final ok = apply(s, [Op(op: 'inc', path: 'reputation.fac_qinglian', by: -150)]);
      expect(ok.rejected, isEmpty);
      expect(s.reputation['fac_qinglian'], -100);
    });
  });

  group('inventory / threads / conditions', () {
    test('push 同 id 合并数量，remove 按 id 删除', () {
      final s = makeState();
      apply(s, [
        Op(op: 'push', path: 'inventory',
            value: {'id': 'i_jade', 'name': '玉牌', 'qty': 1}),
        Op(op: 'push', path: 'inventory',
            value: {'id': 'i_jade', 'name': '玉牌', 'qty': 2}),
      ]);
      expect(s.inventory.single.qty, 3);
      apply(s, [Op(op: 'remove', path: 'inventory', value: 'i_jade')]);
      expect(s.inventory, isEmpty);
    });

    test('inventory push 缺 id 或 qty<1 拒绝', () {
      final s = makeState();
      final r = apply(s, [
        Op(op: 'push', path: 'inventory', value: {'id': '', 'name': 'x', 'qty': 1}),
        Op(op: 'push', path: 'inventory', value: {'id': 'i2', 'name': 'y', 'qty': 0}),
      ]);
      expect(r.rejected, hasLength(2));
      expect(s.inventory, isEmpty);
    });

    test('thread push 强制 open 并记 createdAtTurn，remove 收束', () {
      final s = makeState(); // turnNo 3
      apply(s, [
        Op(op: 'push', path: 'threads',
            value: {'id': 't_jade', 'desc': '玉牌主人', 'status': 'closed', 'createdAtTurn': 0}),
      ]);
      final t = s.threads.single;
      expect(t.status, 'open');
      expect(t.createdAtTurn, 3);
      apply(s, [Op(op: 'remove', path: 'threads', value: 't_jade')]);
      expect(s.threads.single.status, 'closed');
    });

    test('open 伏笔上限 50', () {
      final s = makeState();
      final ops = List.generate(52, (i) => Op(
            op: 'push',
            path: 'threads',
            value: {'id': 't_$i', 'desc': 'x', 'status': 'open', 'createdAtTurn': 0},
          ));
      final r = apply(s, ops);
      expect(r.rejected, hasLength(2));
      expect(s.threads.where((t) => t.status == 'open'), hasLength(50));
    });

    test('conditions push 同 id 覆盖，remove 删除', () {
      final s = makeState();
      apply(s, [
        Op(op: 'push', path: 'character.conditions',
            value: {'id': 'c_poi', 'label': '中毒', 'severity': 2}),
        Op(op: 'push', path: 'character.conditions',
            value: {'id': 'c_poi', 'label': '剧毒', 'severity': 4}),
      ]);
      expect(s.character.conditions.single.label, '剧毒');
      apply(s, [Op(op: 'remove', path: 'character.conditions', value: 'c_poi')]);
      expect(s.character.conditions, isEmpty);
    });

    test('模型偶发把对象 value 写成字符串：拒绝而非抛类型异常', () {
      final s = makeState();
      final r = apply(s, [
        Op(op: 'push', path: 'inventory', value: '玉牌一块'),
        Op(op: 'push', path: 'threads', value: '玉牌主人的下落'),
        Op(op: 'push', path: 'character.conditions', value: '轻伤'),
      ]);
      expect(r.rejected, hasLength(3));
      expect(s.inventory, isEmpty);
      expect(s.threads, isEmpty);
      expect(s.character.conditions, isEmpty);
    });
  });

  group('realm 只升不降', () {
    test('stage 跳级与倒退拒绝，正常升级生效', () {
      final s = makeState(); // stage 1
      expect(
        apply(s, [Op(op: 'set', path: 'character.realm.stage', value: 3)]).rejected,
        hasLength(1),
      );
      expect(
        apply(s, [Op(op: 'set', path: 'character.realm.stage', value: 0)]).rejected,
        hasLength(1),
      );
      final r = apply(s, [Op(op: 'set', path: 'character.realm.stage', value: 2)]);
      expect(r.applied, ['character.realm.stage']);
      expect(s.character.realm.stageName, '筑基');
    });

    test('layer 不可超过该境界层级上限，不可倒退', () {
      final s = makeState(); // 炼气 maxLayer 9, 当前 layer 2
      expect(
        apply(s, [Op(op: 'inc', path: 'character.realm.layer', by: 20)]).rejected,
        hasLength(1),
      );
      expect(
        apply(s, [Op(op: 'inc', path: 'character.realm.layer', by: -1)]).rejected,
        hasLength(1),
      );
      final r = apply(s, [Op(op: 'inc', path: 'character.realm.layer', by: 7)]);
      expect(r.rejected, isEmpty);
      expect(s.character.realm.layer, 9);
    });

    test('progress 钳 0..100', () {
      final s = makeState(); // 40
      apply(s, [Op(op: 'inc', path: 'character.realm.progress', by: 90)]);
      expect(s.character.realm.progress, 100);
      apply(s, [Op(op: 'set', path: 'character.realm.progress', value: -5)]);
      expect(s.character.realm.progress, 0);
    });
  });

  group('flags 容错', () {
    test('非法 key 拒绝', () {
      final s = makeState();
      final r = apply(s, [Op(op: 'set', path: 'flags.9bad', value: 1)]);
      expect(r.rejected.first.reason, 'bad flag key');
    });

    test('仅标量可写，长字符串截断', () {
      final s = makeState();
      final r = apply(s, [
        Op(op: 'set', path: 'flags.met_elder', value: '长' * 200),
        Op(op: 'set', path: 'flags.owed_debt', value: 30),
        Op(op: 'set', path: 'flags.owes', value: ['list']),
      ]);
      expect(r.rejected, hasLength(1));
      expect((s.flags['met_elder'] as String).length, 120);
      expect(s.flags['owed_debt'], 30);
      expect(s.flags['owes'], isNull);
    });
  });

  group('不在白名单的路径', () {
    test('整条拒绝且不影响后续合法 op', () {
      final s = makeState();
      final r = apply(s, [
        Op(op: 'set', path: 'character.stats', value: 1), // 非叶子路径
        Op(op: 'inc', path: 'character.stats.spirit', by: 5),
      ]);
      expect(r.rejected, hasLength(1));
      expect(s.character.stats.spirit, 55);
    });
  });
}
