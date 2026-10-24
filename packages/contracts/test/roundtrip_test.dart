import 'dart:convert';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:test/test.dart';

void main() {
  group('RunState roundtrip', () {
    test('完整状态序列化无损', () {
      final state = RunState(
        schemaVersion: 1,
        meta: RunMeta(
            chapter: 2, turnNo: 17, gameTime: '1-04-02', age: 19, lifespan: 120),
        character: RunCharacter(
          name: '沈九',
          identityId: 'id_herb_apprentice',
          realm: Realm(stage: 1, stageName: '炼气', layer: 3, progress: 88),
          stats: Stats(vitality: 62, spirit: 55, body: 48),
          resources: Resources(spiritStones: 7, pills: {'p_dingxin': 2}),
          conditions: [
            Condition(id: 'c_injury', label: '臂伤', severity: 2, turnsLeft: 4),
          ],
        ),
        location: LocationRef(regionId: 'reg_yunxiu', placeId: 'place_yunxiu_herbal'),
        relations: {
          'npc_su_wan':
              Relation(affinity: 35, trust: 40, status: RelationStatus.xiangShi, lastSeenTurn: 16),
        },
        inventory: [Item(id: 'i_jade', name: '带血玉牌', qty: 1, tags: ['clue'])],
        knowledge: ['师父死于药炉旁', '玉牌上有半枚残图'],
        threads: [
          Thread(id: 't_master', desc: '查明师父死因', dueChapter: 2, status: 'open', createdAtTurn: 1),
        ],
        flags: {'luck': 55, 'heartDemon': 1, 'met_ghost_market': true},
        reputation: {'fac_qinglian': -5, 'fac_sanhetang': 10},
      );
      final back = RunState.fromJson(jsonDecode(jsonEncode(state.toJson())));
      expect(jsonEncode(back.toJson()), jsonEncode(state.toJson()));
      expect(back.luck, 55);
      expect(back.heartDemon, 1);
      expect(back.character.conditions.first.turnsLeft, 4);
      expect(back.relations['npc_su_wan']!.status, RelationStatus.xiangShi);
    });

    test('缺省字段取安全默认值', () {
      final back = RunState.fromJson({
        'meta': {'gameTime': '1-01-01'},
        'character': {},
        'location': {},
      });
      expect(back.schemaVersion, 1);
      expect(back.meta.chapter, 1);
      expect(back.meta.lifespan, 120);
      expect(back.character.stats.vitality, 50);
      expect(back.character.realm.stageName, '炼气');
      expect(back.luck, 50);
      expect(back.heartDemon, 0);
      expect(back.pendingRepair, isFalse);
    });

    test('deepCopy 隔离可变引用', () {
      final s = RunState.fromJson({
        'meta': {'gameTime': '1-01-01'},
        'character': {},
        'location': {},
        'inventory': [
          {'id': 'i1', 'name': '丹药', 'qty': 1},
        ],
      });
      final copy = s.deepCopy();
      copy.inventory.first.qty = 9;
      copy.meta.turnNo = 99;
      expect(s.inventory.first.qty, 1);
      expect(s.meta.turnNo, 0);
    });
  });

  group('Op / StateDelta roundtrip', () {
    test('四类 op 序列化无损', () {
      final delta = StateDelta(
        ops: [
          Op(op: 'inc', path: 'character.stats.vitality', by: -8, reason: '中毒'),
          Op(op: 'set', path: 'meta.gameTime', value: '1-03-20'),
          Op(op: 'push', path: 'knowledge', value: '黑市有三合堂的眼线'),
          Op(op: 'push', path: 'threads',
              value: {'id': 't_jade', 'desc': '玉牌主人是谁', 'status': 'open', 'createdAtTurn': 5}),
        ],
        facts: ['你在后墙发现玉牌'],
        openThreads: [
          Thread(id: 't_jade', desc: '玉牌主人是谁', status: 'open', createdAtTurn: 5),
        ],
        closeThreads: ['t_master'],
      );
      final back = StateDelta.fromJson(jsonDecode(jsonEncode(delta.toJson())));
      expect(jsonEncode(back.toJson()), jsonEncode(delta.toJson()));
      expect(back.ops[0].by, -8);
      expect(back.closeThreads, ['t_master']);
    });

    test('StateDelta.empty 无 ops 无 facts', () {
      final d = StateDelta.empty();
      expect(d.ops, isEmpty);
      expect(d.facts, isEmpty);
    });
  });

  group('TurnEvent 相关契约', () {
    test('ResolveCheck / ResolveResult 序列化无损', () {
      final r = ResolveResult(
        feasible: true,
        cost: ResolveCost(timeDays: 1.5, spirit: 3, items: [ItemCost(id: 'i1', qty: 2)]),
        check: ResolveCheck(
          stat: CheckStat.body,
          dc: 50,
          successRate: 62,
          roll: 37,
          margin: 25,
          grade: Grade.success,
        ),
      );
      final back = ResolveResult.fromJson(jsonDecode(jsonEncode(r.toJson())));
      expect(back.feasible, isTrue);
      expect(back.cost.items.first.id, 'i1');
      expect(back.check!.grade, Grade.success);
      expect(back.check!.stat, CheckStat.body);
    });

    test('Grade 五级全覆盖', () {
      expect(Grade.values.length, 5);
      for (final g in Grade.values) {
        final back = ResolveCheck.fromJson({
          'stat': 'body', 'dc': 50, 'successRate': 50, 'roll': 50, 'margin': 0, 'grade': g.name,
        });
        expect(back.grade, g);
      }
    });
  });

  group('cangwu 内容包可解析', () {
    final seedDir =
        '${Directory.current.path}/../../apps/mobile/assets/seed/cangwu';

    test('bible.json 解析且查询辅助正确', () {
      final bible =
          WorldBible.fromJson(jsonDecode(File('$seedDir/bible.json').readAsStringSync()));
      expect(bible.meta.title, isNotEmpty);
      expect(bible.regions, isNotEmpty);
      expect(bible.powerSystem.tiers, hasLength(4));
      expect(bible.endgame, hasLength(4));
      expect(bible.regionById('reg_yunxiu'), isNotNull);
      expect(bible.regionById('reg_nope'), isNull);
      expect(bible.placeById('place_yunxiu_west_market'), isNotNull);
      expect(bible.tierByStage(1)!.name, '炼气');
      expect(bible.tierByName('筑基')!.stage, 2);
      expect(bible.tierByStage(9), isNull);
    });

    test('identities.json 解析且稀有度合法', () {
      final list = (jsonDecode(File('$seedDir/identities.json').readAsStringSync()) as List)
          .map((e) => Identity.fromJson(e))
          .toList();
      expect(list, hasLength(10));
      for (final id in list) {
        expect(id.rarity, isIn(Rarity.values));
        expect(id.difficulty, isIn([1, 2, 3]));
        expect(id.start.regionId, isNotEmpty);
      }
    });
  });

  group('LLM 输出容错', () {
    test('delta ops 混入字符串元素：跳过不炸', () {
      final delta = StateDelta.fromJson({
        'ops': [
          '坏元素',
          {'op': 'inc', 'path': 'character.stats.vitality', 'by': -3},
          42,
        ],
        'openThreads': ['也是坏的', {'id': 't_1', 'desc': '伏笔'}],
      });
      expect(delta.ops.length, 1);
      expect(delta.ops.first.path, 'character.stats.vitality');
      expect(delta.openThreads.length, 1);
      expect(delta.openThreads.first.id, 't_1');
    });

    test('scenePlan 嵌套数组混入非对象元素：跳过不炸', () {
      final plan = ScenePlan.fromJson({
        'beat': 'daily',
        'npcActions': ['坏', {'npcId': 'n_bai', 'action': '逼近', 'hidden': false}],
        'nextChoices': ['也坏', {'intent': '周旋', 'risk': 'low'}],
        'chapterEnd': '不该是字符串',
      });
      expect(plan.npcActions.length, 1);
      expect(plan.npcActions.first.npcId, 'n_bai');
      expect(plan.nextChoices.length, 1);
      expect(plan.nextChoices.first.intent, '周旋');
      expect(plan.chapterEnd, isNull);
    });
  });
}
