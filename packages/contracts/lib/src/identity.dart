import 'json.dart';

enum Rarity { common, rare, unique }

class IdentityRelation {
  String npcId;
  int affinity;
  String note;

  IdentityRelation({required this.npcId, required this.affinity, required this.note});

  Map<String, Object?> toJson() =>
      {'npcId': npcId, 'affinity': affinity, 'note': note};

  static IdentityRelation fromJson(Object? j) {
    final m = rawMap(j);
    return IdentityRelation(
      npcId: asSOr(m['npcId'], ''),
      affinity: asIOr(m['affinity'], 0).clamp(-100, 100),
      note: asSOr(m['note'], ''),
    );
  }
}

class IdentityStart {
  String regionId;
  String placeId;
  String gameTime;
  int age;

  IdentityStart({
    required this.regionId,
    required this.placeId,
    required this.gameTime,
    required this.age,
  });

  Map<String, Object?> toJson() => {
        'regionId': regionId,
        'placeId': placeId,
        'gameTime': gameTime,
        'age': age,
      };

  static IdentityStart fromJson(Object? j) {
    final m = rawMap(j);
    return IdentityStart(
      regionId: asSOr(m['regionId'], ''),
      placeId: asSOr(m['placeId'], ''),
      gameTime: asSOr(m['gameTime'], ''),
      age: asIOr(m['age'], 20),
    );
  }
}

class Identity {
  String id;
  String name;
  Rarity rarity;
  int difficulty;
  String situation;
  String goal;
  List<String> shackles;
  Map<String, int> resources;
  List<IdentityRelation> relations;
  IdentityStart start;

  Identity({
    required this.id,
    required this.name,
    required this.rarity,
    required this.difficulty,
    required this.situation,
    required this.goal,
    required this.shackles,
    required this.resources,
    required this.relations,
    required this.start,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'rarity': rarity.name,
        'difficulty': difficulty,
        'situation': situation,
        'goal': goal,
        'shackles': shackles,
        'resources': resources,
        'relations': relations.map((r) => r.toJson()).toList(),
        'start': start.toJson(),
      };

  static Identity fromJson(Object? j) {
    final m = rawMap(j);
    return Identity(
      id: asSOr(m['id'], ''),
      name: asSOr(m['name'], ''),
      rarity: enumBy(Rarity.values, m['rarity'], Rarity.common),
      difficulty: asIOr(m['difficulty'], 1).clamp(1, 3),
      situation: asSOr(m['situation'], ''),
      goal: asSOr(m['goal'], ''),
      shackles: asList<String>(m['shackles'], (e) => asSOr(e, '')),
      resources: asMap<int>(m['resources'], (e) => asIOr(e, 0)),
      relations: asList<IdentityRelation>(m['relations'], IdentityRelation.fromJson),
      start: IdentityStart.fromJson(m['start']),
    );
  }
}
