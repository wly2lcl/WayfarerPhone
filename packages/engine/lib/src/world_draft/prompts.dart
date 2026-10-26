import 'dart:convert';

import 'package:contracts/contracts.dart';

import '../prompts/roles.dart' show extractJson;
import 'draft_models.dart';

/// 访谈抽取提示词：把用户对一个字段的自由回答解析成结构化数据，
/// 同时检出与已有回答的矛盾（世界创造与导入 §3.3）
String buildInterviewSystem() => '''
你是修仙世界工坊的访谈助手。用户正在逐字段构建一个世界，你只负责把TA对当前字段的回答整理成结构化 JSON，并检查是否与已有回答矛盾。

规则：
1. 只整理用户说过的话，不替用户发明设定；用户说得含糊就照原意收窄成一句话，不扩写。名称一律保留为中文汉字，不得写成拼音或英文。
2. 用户若表示「跳过」「随便你」「你定」，把 skip 设为 true，data 留空对象。
3. 若回答与已有字段明显冲突（如既要灵气充沛又要末法），contradiction 填 {"with":"字段名","reason":"一句话"}，data 仍照常输出。
4. 只输出一个 JSON 对象，不要解释。''';

String buildInterviewUser({
  required FieldKey field,
  required String question,
  required String reply,
  required Map<FieldKey, FieldData> existing,
}) {
  final existingJson = existing.isEmpty
      ? '（尚无其他字段回答）'
      : jsonEncode({
          for (final e in existing.entries) e.key.name: e.value,
        });
  final schema = switch (field) {
    FieldKey.era =>
      '"data":{"summary":"一句话时代","turningPoint":"一个转折事件"}',
    FieldKey.geography =>
      '"data":{"regions":[{"name":"区名","use":"靠什么过活","danger":"1-5"}]}， regions 至少 3 个',
    FieldKey.factions =>
      '"data":{"factions":[{"name":"势力名","goal":"在争什么","relations":[{"name":"另一势力名","stance":"敌对/提防/结盟"}]}]}， factions 至少 3 个且两两有态度',
    FieldKey.power =>
      '"data":{"tiers":["层级名从低到高"],"costs":["代价"],"rules":["硬规则"]}}， tiers 至少 3 个、costs 至少 1 条',
    FieldKey.taboos => '"data":{"items":["禁忌"]}， items 至少 3 条',
    FieldKey.tone => '"data":{"words":["基调词 3-5 个"]}',
    FieldKey.npcs =>
      '"data":{"npcs":[{"name":"姓名","role":"身份","affiliation":"所属势力或散人","want":"想要什么","secret":"不为人知的一面"}]}， npcs 至少 5 个',
    FieldKey.events =>
      '"data":{"events":[{"title":"事件名","trigger":"触发条件"}]}， events 至少 8 个',
  };
  return '''
当前字段：${field.label}（${field.name}）
引导问题：$question

已有其他字段回答（用于矛盾检查，不要改动它们）：
$existingJson

用户回答：
$reply

只输出一个 JSON 对象：{"skip":false,"contradiction":null,"data":{...}}
本字段 data 的 schema：$schema''';
}

/// 用户跳过时让模型补一套安全默认（filledByAI: true）
String buildDefaultFillUser(FieldKey field, String worldHint) {
  return '''
用户跳过了「${field.label}」这个字段，请给一套安全、自洽、克制的默认设定。
世界已有信息：${worldHint.isEmpty ? '（用户还没说太多，按经典冷峻修仙世界处理）' : worldHint}

只输出一个 JSON 对象：{"data":{...}}，schema 与字段含义：
- era: {"summary":"一句话时代","turningPoint":"一个转折事件"}
- geography: {"regions":[{"name":"区名","use":"靠什么过活","danger":"1-5"}]}，恰好 3 个
- factions: {"factions":[{"name":"势力名","goal":"在争什么","relations":[{"name":"另一势力名","stance":"敌对/提防/结盟"}]}]}，恰好 3 个
- power: {"tiers":["层级名从低到高"],"costs":["代价"],"rules":["硬规则"]}，3 层 + 至少 1 条代价
- taboos: {"items":["禁忌"]}，恰好 3 条
- tone: {"words":["基调词"]}，3-5 个
- npcs: {"npcs":[{"name":"姓名","role":"身份","affiliation":"所属势力或散人","want":"想要什么","secret":"不为人知的一面"}]}，恰好 5 个
- events: {"events":[{"title":"事件名","trigger":"触发条件"}]}，恰好 8 个

所有名称与文案用简体中文汉字，不得用拼音或英文单词。''';
}

/// 访谈抽取结果解析
class InterviewParse {
  final FieldData data;
  final bool skip;
  final ({String conflictWith, String reason})? contradiction;

  const InterviewParse({
    required this.data,
    required this.skip,
    this.contradiction,
  });
}

InterviewParse parseInterview(String text) {
  final m = extractJson(text);
  if (m == null) return const InterviewParse(data: {}, skip: false);
  final c = rawMap(m['contradiction']);
  return InterviewParse(
    data: rawMap(m['data']),
    skip: asBOr(m['skip'], false),
    contradiction: c.isEmpty
        ? null
        : (
            conflictWith: asSOr(c['with'], ''),
            reason: asSOr(c['reason'], ''),
          ),
  );
}

/// 圣经骨架生成（meta/eras/regions/factions/powerSystem/taboos）
String buildBibleCoreSystem() => '''
你是修仙文字人生模拟的世界构建者。根据用户的访谈回答，产出一份可玩的世界圣经骨架。

铁律：
1. 忠于用户回答：用户明确给出的名字、关系、代价一律保留，不得替换；用户没说的细节由你补全，但要克制、自洽。
2. 所有 id 用英文蛇形命名并加类型前缀（era_/reg_/place_/fac_）。
3. 势力必须有据点（region.factionIds 里要写势力 id）；力量体系必须有代价；两两势力关系明确。
4. 冷峻克制，不堆华丽辞藻；地名要像真的，不要玄幻味过重的词。
5. 除 id（era_/reg_/place_/fac_）外，所有输出（名称、摘要、提示、代价、禁忌）一律用简体中文汉字；人名、地名、势力名不得使用拼音或英文单词。
6. 只输出一个 JSON 对象。''';

/// 圣经骨架 schema（访谈与导入管线共用，M2 import_prompts.dart 引用）
const String kBibleCoreSchema =
    '{"meta":{"title":"世界名（2-4 字）","genre":"xianxia","tone":"基调词顿号相连","pov":"second","language":"zh-CN","contentRating":"general","summary":"两句话世界梗概，第二人称视角的钩子","volumeHint":"第一卷一句主线提示，60 字内"},"eras":[{"id":"era_x","name":"时代名","span":"跨度","summary":"60 字内","turningPoints":["转折"]}],"regions":[{"id":"reg_x","name":"区名","terrain":"plain|mountain|forest|water|desert|city","climate":"气候一句","summary":"60 字内","danger":2,"factionIds":["fac_x"],"places":[{"id":"place_x","name":"地名","kind":"city|town|sect|wild|ruin|secret","summary":"40 字内","tags":["标签"]}]}],"factions":[{"id":"fac_x","name":"势力名","kind":"sect|clan|court|guild|cult","summary":"40 字内","goal":"在争什么","resources":["掌控的资源"],"stanceTo":[{"factionId":"fac_y","stance":"敌对|提防|结盟|依附"}]}],"powerSystem":{"name":"体系名","resource":"修炼资源","tiers":[{"name":"境界名","stage":1,"maxLayer":3,"lifespan":120,"requires":"突破条件一句","breakthroughRisk":30,"attrBonus":2}],"rules":["硬规则"],"costs":["代价"]},"taboos":["禁忌"]}';

const String kBibleCoreCounts =
    '数量硬性要求：eras 2 个；regions ≥3 个（每个至少 2 个 places，danger 1-5）；factions ≥3 个（每个至少一条 stanceTo，region.factionIds 覆盖所有势力）；powerSystem.tiers ≥3 层且 costs ≥1 条；taboos ≥3 条。';

String buildBibleCoreUser(InterviewState interview) {
  final answers = <String, Object?>{};
  for (final k in FieldKey.values) {
    final a = interview.answers[k];
    if (a == null) continue;
    answers[k.name] = {
      'text': a.text,
      if (a.filledByAI) 'filledByAI': true,
      'data': a.data,
    };
  }
  return '''
访谈回答（filledByAI 的字段是 AI 代填的默认值，可调整但保持风格一致）：
${jsonEncode(answers)}

只输出一个 JSON 对象，schema：
$kBibleCoreSchema

$kBibleCoreCounts''';
}

/// 圣经内容生成（npcPool/eventSeeds/endgame）
String buildBibleContentUser(Object coreJson) {
  return '''
世界骨架已定：
${jsonEncode(coreJson)}

基于这份骨架，只输出一个 JSON 对象：
{"npcPool":[{"id":"npc_x","name":"姓名","role":"身份一句","factionId":"fac_x 或省略（散人）","regionId":"reg_x","tier":"境界名","public":{"appearance":"外貌一句","manner":"做派一句","affiliation":"所属势力名或散人"},"private":{"secret":"秘密","motive":"图什么","fear":"怕什么","leverage":["可被拿捏的点"]}}],"eventSeeds":[{"id":"ev_x","title":"事件名","kind":"encounter|intrigue|danger|windfall|revelation","summary":"40 字内","regionId":"reg_x","factionIds":["fac_x"],"npcIds":["npc_x"],"requires":{"chapterMin":1},"effects":{"danger":"low|medium|high","hint":"触发时给玩家的钩子一句"},"weight":50,"once":true}],"endgame":[{"id":"ending_x","type":"death|ascension|fall|legacy","condition":"代码可判定的条件一句话","title":"终局名","epitaphTemplate":"墓志铭，含{name}占位"}]}

数量硬性要求：npcPool 至少 4 个（public/private 全部非空，affiliation 必须是骨架中势力名或「散人」）；eventSeeds 至少 6 个（引用的 regionId/factionId/npcId 必须来自骨架，不得发明新 id；requires 里可加 flags/knowledge 触发条件）；endgame 至少 3 条且必须含一条 death。字段值尽量精炼，一句话说完。
姓名、事件名、摘要、终局名、墓志铭等所有文案一律简体中文汉字，不得用拼音或英文单词（id 除外）。''';
}

/// 身份池生成：3 个可玩身份
String buildIdentitiesUser(Object coreJson, Object contentJson) {
  return '''
世界圣经已定：
${jsonEncode(coreJson)}
${jsonEncode(contentJson)}

设计 3 个玩家身份（抽卡池：1 common + 1 rare + 1 unique），只输出一个 JSON 对象：
{"identities":[{"id":"id_x","name":"身份名","rarity":"common|rare|unique","difficulty":1,"situation":"开局处境 60 字内，第二人称","goal":"长期目标一句","shackles":["开局枷锁 1-2 条"],"resources":{"spiritStones":20,"可选物品id":2},"relations":[{"npcId":"npc_x","affinity":-100到100,"note":"关系一句话"}],"start":{"regionId":"reg_x","placeId":"place_x","gameTime":"1-03-15","age":16-30}}]}

硬性要求：situation 交代为什么开局难；goal 与某个 npcPool 的 private.motive 或 eventSeeds 呼应；relations 引用骨架里的 npcId；placeId 必须属于 regionId；resources 只用 spiritStones 键加至多 2 个自定物品键；3 个身份 difficulty 分别为 1、2、3。
身份名、处境、目标、枷锁、关系备注、物品名一律简体中文汉字，不得用拼音或英文单词（id 除外）。''';
}

/// 解析生成结果；schema 缺口由调用方兜底
WorldBible? parseBibleCore(String text) {
  final m = extractJson(text);
  if (m == null) return null;
  final core = {
    'schemaVersion': 1,
    'meta': m['meta'],
    'eras': m['eras'],
    'regions': m['regions'],
    'factions': m['factions'],
    'powerSystem': m['powerSystem'],
    'taboos': m['taboos'],
  };
  try {
    return WorldBible.fromJson(core);
  } catch (_) {
    return null;
  }
}
