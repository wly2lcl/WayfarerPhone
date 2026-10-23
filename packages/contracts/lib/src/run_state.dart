import 'json.dart';

class Condition {
  String id;
  String label;
  int severity;
  int? turnsLeft;

  Condition({required this.id, required this.label, required this.severity, this.turnsLeft});

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'severity': severity,
        if (turnsLeft != null) 'turnsLeft': turnsLeft,
      };

  static Condition fromJson(Object? j) {
    final m = rawMap(j);
    return Condition(
      id: asSOr(m['id'], ''),
      label: asSOr(m['label'], ''),
      severity: asIOr(m['severity'], 1).clamp(1, 5),
      turnsLeft: asI(m['turnsLeft']),
    );
  }
}

enum RelationStatus { moSheng, xiangShi, shuShi, xinRen, diYi, jueLie }

extension RelationStatusX on RelationStatus {
  String get label => switch (this) {
        RelationStatus.moSheng => '陌生',
        RelationStatus.xiangShi => '相识',
        RelationStatus.shuShi => '熟识',
        RelationStatus.xinRen => '信任',
        RelationStatus.diYi => '敌意',
        RelationStatus.jueLie => '决裂',
      };

  static RelationStatus fromLabel(Object? v) {
    final s = asS(v);
    for (final e in RelationStatus.values) {
      if (e.label == s) return e;
    }
    return enumBy(RelationStatus.values, v, RelationStatus.moSheng);
  }
}

class Relation {
  int affinity;
  int trust;
  RelationStatus status;
  int? lastSeenTurn;

  Relation({
    required this.affinity,
    required this.trust,
    required this.status,
    this.lastSeenTurn,
  });

  Map<String, Object?> toJson() => {
        'affinity': affinity,
        'trust': trust,
        'status': status.label,
        if (lastSeenTurn != null) 'lastSeenTurn': lastSeenTurn,
      };

  static Relation fromJson(Object? j) {
    final m = rawMap(j);
    return Relation(
      affinity: asIOr(m['affinity'], 0).clamp(-100, 100),
      trust: asIOr(m['trust'], 0).clamp(0, 100),
      status: RelationStatusX.fromLabel(m['status']),
      lastSeenTurn: asI(m['lastSeenTurn']),
    );
  }
}

class Item {
  String id;
  String name;
  int qty;
  List<String> tags;

  Item({required this.id, required this.name, required this.qty, List<String>? tags})
      : tags = tags ?? [];

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'qty': qty,
        if (tags.isNotEmpty) 'tags': tags,
      };

  static Item fromJson(Object? j) {
    final m = rawMap(j);
    return Item(
      id: asSOr(m['id'], ''),
      name: asSOr(m['name'], ''),
      qty: asIOr(m['qty'], 1),
      tags: asList<String>(m['tags'], (e) => asSOr(e, '')),
    );
  }
}

class Thread {
  String id;
  String desc;
  int? dueChapter;
  String status;
  int createdAtTurn;

  Thread({
    required this.id,
    required this.desc,
    this.dueChapter,
    required this.status,
    required this.createdAtTurn,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'desc': desc,
        if (dueChapter != null) 'dueChapter': dueChapter,
        'status': status,
        'createdAtTurn': createdAtTurn,
      };

  static Thread fromJson(Object? j) {
    final m = rawMap(j);
    return Thread(
      id: asSOr(m['id'], ''),
      desc: asSOr(m['desc'], ''),
      dueChapter: asI(m['dueChapter']),
      status: asSOr(m['status'], 'open'),
      createdAtTurn: asIOr(m['createdAtTurn'], 0),
    );
  }
}

class RunMeta {
  int chapter;
  int turnNo;
  String gameTime;
  int age;
  int lifespan;

  RunMeta({
    required this.chapter,
    required this.turnNo,
    required this.gameTime,
    required this.age,
    required this.lifespan,
  });

  Map<String, Object?> toJson() => {
        'chapter': chapter,
        'turnNo': turnNo,
        'gameTime': gameTime,
        'age': age,
        'lifespan': lifespan,
      };

  static RunMeta fromJson(Object? j) {
    final m = rawMap(j);
    return RunMeta(
      chapter: asIOr(m['chapter'], 1),
      turnNo: asIOr(m['turnNo'], 0),
      gameTime: asSOr(m['gameTime'], ''),
      age: asIOr(m['age'], 0),
      lifespan: asIOr(m['lifespan'], 120),
    );
  }
}

class Realm {
  int stage;
  String stageName;
  int layer;
  int progress;

  Realm({required this.stage, required this.stageName, required this.layer, required this.progress});

  Map<String, Object?> toJson() => {
        'stage': stage,
        'stageName': stageName,
        'layer': layer,
        'progress': progress,
      };

  static Realm fromJson(Object? j) {
    final m = rawMap(j);
    return Realm(
      stage: asIOr(m['stage'], 1),
      stageName: asSOr(m['stageName'], '炼气'),
      layer: asIOr(m['layer'], 1),
      progress: asIOr(m['progress'], 0).clamp(0, 100),
    );
  }
}

class Stats {
  int vitality;
  int spirit;
  int body;

  Stats({required this.vitality, required this.spirit, required this.body});

  Map<String, Object?> toJson() =>
      {'vitality': vitality, 'spirit': spirit, 'body': body};

  static Stats fromJson(Object? j) {
    final m = rawMap(j);
    return Stats(
      vitality: asIOr(m['vitality'], 50).clamp(0, 100),
      spirit: asIOr(m['spirit'], 50).clamp(0, 100),
      body: asIOr(m['body'], 50).clamp(0, 100),
    );
  }
}

class Resources {
  int spiritStones;
  Map<String, int> pills;

  Resources({required this.spiritStones, required this.pills});

  Map<String, Object?> toJson() =>
      {'spiritStones': spiritStones, 'pills': pills};

  static Resources fromJson(Object? j) {
    final m = rawMap(j);
    return Resources(
      spiritStones: asIOr(m['spiritStones'], 0),
      pills: asMap<int>(m['pills'], (e) => asIOr(e, 0)),
    );
  }
}

class RunCharacter {
  String name;
  String identityId;
  Realm realm;
  Stats stats;
  Resources resources;
  List<Condition> conditions;

  RunCharacter({
    required this.name,
    required this.identityId,
    required this.realm,
    required this.stats,
    required this.resources,
    required this.conditions,
  });

  Map<String, Object?> toJson() => {
        'name': name,
        'identityId': identityId,
        'realm': realm.toJson(),
        'stats': stats.toJson(),
        'resources': resources.toJson(),
        'conditions': conditions.map((c) => c.toJson()).toList(),
      };

  static RunCharacter fromJson(Object? j) {
    final m = rawMap(j);
    return RunCharacter(
      name: asSOr(m['name'], ''),
      identityId: asSOr(m['identityId'], ''),
      realm: Realm.fromJson(m['realm']),
      stats: Stats.fromJson(m['stats']),
      resources: Resources.fromJson(m['resources']),
      conditions: asList<Condition>(m['conditions'], Condition.fromJson),
    );
  }
}

class LocationRef {
  String regionId;
  String placeId;

  LocationRef({required this.regionId, required this.placeId});

  Map<String, Object?> toJson() => {'regionId': regionId, 'placeId': placeId};

  static LocationRef fromJson(Object? j) {
    final m = rawMap(j);
    return LocationRef(
      regionId: asSOr(m['regionId'], ''),
      placeId: asSOr(m['placeId'], ''),
    );
  }
}

class RunState {
  int schemaVersion;
  RunMeta meta;
  RunCharacter character;
  LocationRef location;
  Map<String, Relation> relations;
  List<Item> inventory;
  List<String> knowledge;
  List<Thread> threads;
  Map<String, Object?> flags;
  Map<String, int> reputation;

  RunState({
    required this.schemaVersion,
    required this.meta,
    required this.character,
    required this.location,
    required this.relations,
    required this.inventory,
    required this.knowledge,
    required this.threads,
    required this.flags,
    required this.reputation,
  });

  int get luck => asIOr(flags['luck'], 50);
  int get heartDemon => asIOr(flags['heartDemon'], 0);
  bool get pendingRepair => asBOr(flags['pendingRepair'], false);

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'meta': meta.toJson(),
        'character': character.toJson(),
        'location': location.toJson(),
        'relations': relations.map((k, v) => MapEntry(k, v.toJson())),
        'inventory': inventory.map((v) => v.toJson()).toList(),
        'knowledge': knowledge,
        'threads': threads.map((v) => v.toJson()).toList(),
        'flags': flags,
        'reputation': reputation,
      };

  static RunState fromJson(Object? j) {
    final m = rawMap(j);
    return RunState(
      schemaVersion: asIOr(m['schemaVersion'], 1),
      meta: RunMeta.fromJson(m['meta']),
      character: RunCharacter.fromJson(m['character']),
      location: LocationRef.fromJson(m['location']),
      relations: asMap<Relation>(m['relations'], Relation.fromJson),
      inventory: asList<Item>(m['inventory'], Item.fromJson),
      knowledge: asList<String>(m['knowledge'], (e) => asSOr(e, '')),
      threads: asList<Thread>(m['threads'], Thread.fromJson),
      flags: rawMap(m['flags']),
      reputation: asMap<int>(m['reputation'], (e) => asIOr(e, 0).clamp(-100, 100)),
    );
  }

  RunState deepCopy() => RunState.fromJson(toJson());
}
