import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:contracts/contracts.dart';

final String kSeedDir =
    '${Directory.current.path}/../../apps/mobile/assets/seed/cangwu';

WorldBible loadBible() =>
    WorldBible.fromJson(jsonDecode(File('$kSeedDir/bible.json').readAsStringSync()));

RunState makeState({
  int vitality = 80,
  int spirit = 50,
  int body = 50,
  Map<String, Object?>? flags,
}) {
  final state = RunState(
    schemaVersion: 1,
    meta: RunMeta(
      chapter: 1,
      turnNo: 3,
      gameTime: '1-03-15',
      age: 18,
      lifespan: 120,
    ),
    character: RunCharacter(
      name: '沈九',
      identityId: 'id_herb_apprentice',
      realm: Realm(stage: 1, stageName: '炼气', layer: 2, progress: 40),
      stats: Stats(vitality: vitality, spirit: spirit, body: body),
      resources: Resources(spiritStones: 20, pills: {}),
      conditions: [],
    ),
    location: LocationRef(regionId: 'reg_yunxiu', placeId: 'place_yunxiu_west_market'),
    relations: {},
    inventory: [],
    knowledge: ['师父昨夜死在药炉旁'],
    threads: [],
    flags: flags ?? {},
    reputation: {},
  );
  return state;
}

/// 顺序可控的伪随机：依次吐出 values，超出后循环。
class SeqRandom implements Random {
  final List<int> values;
  int _i = 0;
  SeqRandom(this.values);

  @override
  bool nextBool() => nextInt(2) == 1;

  @override
  double nextDouble() => nextInt(10000) / 10000;

  @override
  int nextInt(int max) => values[_i++ % values.length] % max;
}
