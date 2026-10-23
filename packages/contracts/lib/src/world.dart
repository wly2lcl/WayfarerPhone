import 'json.dart';

enum Terrain { mountain, plain, river, desert, forest, coast, underground }

enum PlaceKind { city, town, sect, wild, ruin, secret }

enum FactionKind { sect, clan, court, guild, cult }

enum SeedKind { encounter, disaster, opportunity, conflict, mystery }

enum Danger { low, medium, high }

enum EndingType { death, ascension, fall, legacy }

class WorldMeta {
  String title;
  String genre;
  String tone;
  String pov;
  String language;
  String contentRating;
  String summary;
  String volumeHint;

  WorldMeta({
    required this.title,
    required this.genre,
    required this.tone,
    required this.pov,
    required this.language,
    required this.contentRating,
    required this.summary,
    required this.volumeHint,
  });

  Map<String, Object?> toJson() => {
        'title': title,
        'genre': genre,
        'tone': tone,
        'pov': pov,
        'language': language,
        'contentRating': contentRating,
        'summary': summary,
        'volumeHint': volumeHint,
      };

  static WorldMeta fromJson(Object? j) {
    final m = rawMap(j);
    return WorldMeta(
      title: asSOr(m['title'], ''),
      genre: asSOr(m['genre'], 'xianxia'),
      tone: asSOr(m['tone'], ''),
      pov: asSOr(m['pov'], 'second'),
      language: asSOr(m['language'], 'zh-CN'),
      contentRating: asSOr(m['contentRating'], 'general'),
      summary: asSOr(m['summary'], ''),
      volumeHint: asSOr(m['volumeHint'], ''),
    );
  }
}

class Era {
  String id;
  String name;
  String span;
  String summary;
  List<String> turningPoints;

  Era({
    required this.id,
    required this.name,
    required this.span,
    required this.summary,
    required this.turningPoints,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'span': span,
        'summary': summary,
        'turningPoints': turningPoints,
      };

  static Era fromJson(Object? j) {
    final m = rawMap(j);
    return Era(
      id: asSOr(m['id'], ''),
      name: asSOr(m['name'], ''),
      span: asSOr(m['span'], ''),
      summary: asSOr(m['summary'], ''),
      turningPoints: asList<String>(m['turningPoints'], (e) => asSOr(e, '')),
    );
  }
}

class Place {
  String id;
  String name;
  PlaceKind kind;
  String summary;
  List<String> tags;

  Place({
    required this.id,
    required this.name,
    required this.kind,
    required this.summary,
    required this.tags,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'summary': summary,
        'tags': tags,
      };

  static Place fromJson(Object? j) {
    final m = rawMap(j);
    return Place(
      id: asSOr(m['id'], ''),
      name: asSOr(m['name'], ''),
      kind: enumBy(PlaceKind.values, m['kind'], PlaceKind.wild),
      summary: asSOr(m['summary'], ''),
      tags: asList<String>(m['tags'], (e) => asSOr(e, '')),
    );
  }
}

class Region {
  String id;
  String name;
  Terrain terrain;
  String climate;
  String summary;
  int danger;
  List<String> factionIds;
  List<Place> places;

  Region({
    required this.id,
    required this.name,
    required this.terrain,
    required this.climate,
    required this.summary,
    required this.danger,
    required this.factionIds,
    required this.places,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'terrain': terrain.name,
        'climate': climate,
        'summary': summary,
        'danger': danger,
        'factionIds': factionIds,
        'places': places.map((p) => p.toJson()).toList(),
      };

  static Region fromJson(Object? j) {
    final m = rawMap(j);
    return Region(
      id: asSOr(m['id'], ''),
      name: asSOr(m['name'], ''),
      terrain: enumBy(Terrain.values, m['terrain'], Terrain.mountain),
      climate: asSOr(m['climate'], ''),
      summary: asSOr(m['summary'], ''),
      danger: asIOr(m['danger'], 1).clamp(1, 5),
      factionIds: asList<String>(m['factionIds'], (e) => asSOr(e, '')),
      places: asList<Place>(m['places'], Place.fromJson),
    );
  }
}

class StanceTo {
  String factionId;
  String stance;

  StanceTo({required this.factionId, required this.stance});

  Map<String, Object?> toJson() => {'factionId': factionId, 'stance': stance};

  static StanceTo fromJson(Object? j) {
    final m = rawMap(j);
    return StanceTo(
      factionId: asSOr(m['factionId'], ''),
      stance: asSOr(m['stance'], 'neutral'),
    );
  }
}

class Faction {
  String id;
  String name;
  FactionKind kind;
  String summary;
  String goal;
  List<String> resources;
  List<StanceTo> stanceTo;

  Faction({
    required this.id,
    required this.name,
    required this.kind,
    required this.summary,
    required this.goal,
    required this.resources,
    required this.stanceTo,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'summary': summary,
        'goal': goal,
        'resources': resources,
        'stanceTo': stanceTo.map((s) => s.toJson()).toList(),
      };

  static Faction fromJson(Object? j) {
    final m = rawMap(j);
    return Faction(
      id: asSOr(m['id'], ''),
      name: asSOr(m['name'], ''),
      kind: enumBy(FactionKind.values, m['kind'], FactionKind.sect),
      summary: asSOr(m['summary'], ''),
      goal: asSOr(m['goal'], ''),
      resources: asList<String>(m['resources'], (e) => asSOr(e, '')),
      stanceTo: asList<StanceTo>(m['stanceTo'], StanceTo.fromJson),
    );
  }
}

class Tier {
  String name;
  int stage;
  int maxLayer;
  int lifespan;
  String requires;
  int breakthroughRisk;
  int attrBonus;

  Tier({
    required this.name,
    required this.stage,
    required this.maxLayer,
    required this.lifespan,
    required this.requires,
    required this.breakthroughRisk,
    required this.attrBonus,
  });

  Map<String, Object?> toJson() => {
        'name': name,
        'stage': stage,
        'maxLayer': maxLayer,
        'lifespan': lifespan,
        'requires': requires,
        'breakthroughRisk': breakthroughRisk,
        'attrBonus': attrBonus,
      };

  static Tier fromJson(Object? j) {
    final m = rawMap(j);
    return Tier(
      name: asSOr(m['name'], ''),
      stage: asIOr(m['stage'], 1),
      maxLayer: asIOr(m['maxLayer'], 1),
      lifespan: asIOr(m['lifespan'], 120),
      requires: asSOr(m['requires'], ''),
      breakthroughRisk: asIOr(m['breakthroughRisk'], 50),
      attrBonus: asIOr(m['attrBonus'], 2),
    );
  }
}

class PowerSystem {
  String name;
  String resource;
  List<Tier> tiers;
  List<String> rules;
  List<String> costs;

  PowerSystem({
    required this.name,
    required this.resource,
    required this.tiers,
    required this.rules,
    required this.costs,
  });

  Map<String, Object?> toJson() => {
        'name': name,
        'resource': resource,
        'tiers': tiers.map((t) => t.toJson()).toList(),
        'rules': rules,
        'costs': costs,
      };

  static PowerSystem fromJson(Object? j) {
    final m = rawMap(j);
    return PowerSystem(
      name: asSOr(m['name'], ''),
      resource: asSOr(m['resource'], ''),
      tiers: asList<Tier>(m['tiers'], Tier.fromJson)
        ..sort((a, b) => a.stage.compareTo(b.stage)),
      rules: asList<String>(m['rules'], (e) => asSOr(e, '')),
      costs: asList<String>(m['costs'], (e) => asSOr(e, '')),
    );
  }
}

class NpcPublic {
  String appearance;
  String manner;
  String affiliation;

  NpcPublic({
    required this.appearance,
    required this.manner,
    required this.affiliation,
  });

  Map<String, Object?> toJson() =>
      {'appearance': appearance, 'manner': manner, 'affiliation': affiliation};

  static NpcPublic fromJson(Object? j) {
    final m = rawMap(j);
    return NpcPublic(
      appearance: asSOr(m['appearance'], ''),
      manner: asSOr(m['manner'], ''),
      affiliation: asSOr(m['affiliation'], ''),
    );
  }
}

class NpcPrivate {
  String secret;
  String motive;
  String fear;
  List<String> leverage;

  NpcPrivate({
    required this.secret,
    required this.motive,
    required this.fear,
    required this.leverage,
  });

  Map<String, Object?> toJson() => {
        'secret': secret,
        'motive': motive,
        'fear': fear,
        'leverage': leverage,
      };

  static NpcPrivate fromJson(Object? j) {
    final m = rawMap(j);
    return NpcPrivate(
      secret: asSOr(m['secret'], ''),
      motive: asSOr(m['motive'], ''),
      fear: asSOr(m['fear'], ''),
      leverage: asList<String>(m['leverage'], (e) => asSOr(e, '')),
    );
  }
}

class NpcSeed {
  String id;
  String name;
  String role;
  String? factionId;
  String? regionId;
  String? tier;
  NpcPublic public;
  NpcPrivate private;

  NpcSeed({
    required this.id,
    required this.name,
    required this.role,
    this.factionId,
    this.regionId,
    this.tier,
    required this.public,
    required this.private,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        if (factionId != null) 'factionId': factionId,
        if (regionId != null) 'regionId': regionId,
        if (tier != null) 'tier': tier,
        'public': public.toJson(),
        'private': private.toJson(),
      };

  static NpcSeed fromJson(Object? j) {
    final m = rawMap(j);
    return NpcSeed(
      id: asSOr(m['id'], ''),
      name: asSOr(m['name'], ''),
      role: asSOr(m['role'], ''),
      factionId: asS(m['factionId']),
      regionId: asS(m['regionId']),
      tier: asS(m['tier']),
      public: NpcPublic.fromJson(m['public']),
      private: NpcPrivate.fromJson(m['private']),
    );
  }
}

class SeedCondition {
  int? chapterMin;
  int? chapterMax;
  String? realmMin;
  Map<String, Object?> flags;
  List<String> knowledge;
  String? placeId;

  SeedCondition({
    this.chapterMin,
    this.chapterMax,
    this.realmMin,
    Map<String, Object?>? flags,
    List<String>? knowledge,
    this.placeId,
  })  : flags = flags ?? {},
        knowledge = knowledge ?? [];

  Map<String, Object?> toJson() => {
        if (chapterMin != null) 'chapterMin': chapterMin,
        if (chapterMax != null) 'chapterMax': chapterMax,
        if (realmMin != null) 'realmMin': realmMin,
        if (flags.isNotEmpty) 'flags': flags,
        if (knowledge.isNotEmpty) 'knowledge': knowledge,
        if (placeId != null) 'placeId': placeId,
      };

  static SeedCondition fromJson(Object? j) {
    final m = rawMap(j);
    return SeedCondition(
      chapterMin: asI(m['chapterMin']),
      chapterMax: asI(m['chapterMax']),
      realmMin: asS(m['realmMin']),
      flags: rawMap(m['flags']),
      knowledge: asList<String>(m['knowledge'], (e) => asSOr(e, '')),
      placeId: asS(m['placeId']),
    );
  }
}

class SeedEffects {
  Danger danger;
  String? threadId;
  String hint;

  SeedEffects({required this.danger, this.threadId, required this.hint});

  Map<String, Object?> toJson() => {
        'danger': danger.name,
        if (threadId != null) 'threadId': threadId,
        'hint': hint,
      };

  static SeedEffects fromJson(Object? j) {
    final m = rawMap(j);
    return SeedEffects(
      danger: enumBy(Danger.values, m['danger'], Danger.low),
      threadId: asS(m['threadId']),
      hint: asSOr(m['hint'], ''),
    );
  }
}

class EventSeed {
  String id;
  String title;
  SeedKind kind;
  String summary;
  String? regionId;
  List<String> factionIds;
  List<String> npcIds;
  SeedCondition requires;
  SeedEffects effects;
  int weight;
  bool once;

  EventSeed({
    required this.id,
    required this.title,
    required this.kind,
    required this.summary,
    this.regionId,
    required this.factionIds,
    required this.npcIds,
    required this.requires,
    required this.effects,
    required this.weight,
    required this.once,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'kind': kind.name,
        'summary': summary,
        if (regionId != null) 'regionId': regionId,
        'factionIds': factionIds,
        'npcIds': npcIds,
        'requires': requires.toJson(),
        'effects': effects.toJson(),
        'weight': weight,
        'once': once,
      };

  static EventSeed fromJson(Object? j) {
    final m = rawMap(j);
    return EventSeed(
      id: asSOr(m['id'], ''),
      title: asSOr(m['title'], ''),
      kind: enumBy(SeedKind.values, m['kind'], SeedKind.encounter),
      summary: asSOr(m['summary'], ''),
      regionId: asS(m['regionId']),
      factionIds: asList<String>(m['factionIds'], (e) => asSOr(e, '')),
      npcIds: asList<String>(m['npcIds'], (e) => asSOr(e, '')),
      requires: SeedCondition.fromJson(m['requires']),
      effects: SeedEffects.fromJson(m['effects']),
      weight: asIOr(m['weight'], 50).clamp(0, 100),
      once: asBOr(m['once'], true),
    );
  }
}

class EndingRule {
  String id;
  EndingType type;
  String condition;
  String title;
  String? epitaphTemplate;

  EndingRule({
    required this.id,
    required this.type,
    required this.condition,
    required this.title,
    this.epitaphTemplate,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'condition': condition,
        'title': title,
        if (epitaphTemplate != null) 'epitaphTemplate': epitaphTemplate,
      };

  static EndingRule fromJson(Object? j) {
    final m = rawMap(j);
    return EndingRule(
      id: asSOr(m['id'], ''),
      type: enumBy(EndingType.values, m['type'], EndingType.death),
      condition: asSOr(m['condition'], ''),
      title: asSOr(m['title'], ''),
      epitaphTemplate: asS(m['epitaphTemplate']),
    );
  }
}

class WorldBible {
  int schemaVersion;
  WorldMeta meta;
  List<Era> eras;
  List<Region> regions;
  List<Faction> factions;
  PowerSystem powerSystem;
  List<String> taboos;
  List<NpcSeed> npcPool;
  List<EventSeed> eventSeeds;
  List<EndingRule> endgame;

  WorldBible({
    required this.schemaVersion,
    required this.meta,
    required this.eras,
    required this.regions,
    required this.factions,
    required this.powerSystem,
    required this.taboos,
    required this.npcPool,
    required this.eventSeeds,
    required this.endgame,
  });

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'meta': meta.toJson(),
        'eras': eras.map((e) => e.toJson()).toList(),
        'regions': regions.map((e) => e.toJson()).toList(),
        'factions': factions.map((e) => e.toJson()).toList(),
        'powerSystem': powerSystem.toJson(),
        'taboos': taboos,
        'npcPool': npcPool.map((e) => e.toJson()).toList(),
        'eventSeeds': eventSeeds.map((e) => e.toJson()).toList(),
        'endgame': endgame.map((e) => e.toJson()).toList(),
      };

  static WorldBible fromJson(Object? j) {
    final m = rawMap(j);
    return WorldBible(
      schemaVersion: asIOr(m['schemaVersion'], 1),
      meta: WorldMeta.fromJson(m['meta']),
      eras: asList<Era>(m['eras'], Era.fromJson),
      regions: asList<Region>(m['regions'], Region.fromJson),
      factions: asList<Faction>(m['factions'], Faction.fromJson),
      powerSystem: PowerSystem.fromJson(m['powerSystem']),
      taboos: asList<String>(m['taboos'], (e) => asSOr(e, '')),
      npcPool: asList<NpcSeed>(m['npcPool'], NpcSeed.fromJson),
      eventSeeds: asList<EventSeed>(m['eventSeeds'], EventSeed.fromJson),
      endgame: asList<EndingRule>(m['endgame'], EndingRule.fromJson),
    );
  }

  Region? regionById(String id) {
    for (final r in regions) {
      if (r.id == id) return r;
    }
    return null;
  }

  Place? placeById(String id) {
    for (final r in regions) {
      for (final p in r.places) {
        if (p.id == id) return p;
      }
    }
    return null;
  }

  Tier? tierByStage(int stage) {
    for (final t in powerSystem.tiers) {
      if (t.stage == stage) return t;
    }
    return null;
  }

  Tier? tierByName(String name) {
    for (final t in powerSystem.tiers) {
      if (t.name == name) return t;
    }
    return null;
  }
}
