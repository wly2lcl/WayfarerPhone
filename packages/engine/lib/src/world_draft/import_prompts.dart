import 'dart:convert';

import 'package:contracts/contracts.dart';

import '../prompts/roles.dart' show extractJson;
import 'import_models.dart';
import 'prompts.dart' show kBibleCoreCounts, kBibleCoreSchema;

/// 分块实体抽取（小模型，extractor 角色）
String buildChunkSystem() => '''
你是小说文本的结构化抽取器。给定一段小说正文（约 3000 字，可能与前后块有少量重叠），
抽取其中出现的人物、地点、势力、物品、事件，以及人物/势力之间的关系和重要剧情节点。

铁律：
1. 只依据正文出现的内容，不脑补；名字原样保留（含称号），不要翻译或改写。
2. type 只能是 character | place | faction | item | event；拿不准归 character。
3. 频次 frequency = 该名称在这段正文里出现的次数（估个数即可）。
4. attributes 挑最有信息量的 1-3 个键（如 身份/图谋/秘密/据点/特产），没有就空对象。
5. relations 的 from/to 用原文里的名字；kind 用两三字的关系词（敌对/从属/师徒/同盟/血亲/知情/买卖）。
6. timeline 只记重大事件（有人物命运或势力格局改变的），一段正文最多 2 条。
7. summary 用 80 字内概括这段正文的剧情，客观陈述，不评论。
8. 除 kind 值外，所有输出一律简体中文汉字。
9. 只输出一个 JSON 对象，不要任何解释。''';

String buildChunkUser(NovelChunk chunk) => '''
正文（第 ${chunk.idx + 1} 块，所属章节序号 ${chunk.chapter}）：
${chunk.text}

只输出一个 JSON 对象，schema：
{"entities":[{"key":"名称","type":"character|place|faction|item|event","aliases":["别名"],"firstSeen":{"chapter":0,"offset":0},"frequency":1,"attributes":{"身份":"..."}}],"relations":[{"from":"名称","to":"名称","kind":"敌对","chapter":0}],"timeline":[{"chapter":0,"title":"事件名","summary":"40字内"}],"summary":"80字内剧情摘要"}

firstSeen 的 chapter 填上面的章节序号，offset 填该名称在本块正文中的大致字符位置（估即可）。''';

ChunkExtraction? parseChunkExtraction(String text) {
  final m = extractJson(text);
  if (m == null) return null;
  try {
    final entities = asListOfMaps<ImportEntity>(m['entities'], ImportEntity.fromJson);
    if (entities.isEmpty && asSOr(m['summary'], '').isEmpty) return null;
    return ChunkExtraction(
      entities: entities,
      relations:
          asListOfMaps<ImportRelation>(m['relations'], ImportRelation.fromJson),
      timeline: asListOfMaps<ImportTimelinePoint>(
          m['timeline'], ImportTimelinePoint.fromJson),
      summary: asSOr(m['summary'], ''),
    );
  } catch (_) {
    return null;
  }
}

/// 素材摘要 → 圣经骨架生成（composer 角色，复用 M1 内容段/身份段提示词）
///
/// 截断/采样由服务层按档位预处理好；arcSummaries 非空时（忠实档）
/// 用卷级脉络替换分块摘要，保证结局与后期剧情参与合成。
String buildImportCoreUser({
  required List<ImportEntity> entities,
  required List<ImportRelation> relations,
  required List<ImportTimelinePoint> timeline,
  required List<String> chunkSummaries,
  List<String> arcSummaries = const [],
}) {
  final top = entities.map((e) => {
        'key': e.key,
        'type': e.type,
        if (e.aliases.isNotEmpty) 'aliases': e.aliases.toList(),
        'frequency': e.frequency,
        if (e.attributes.isNotEmpty) 'attributes': e.attributes,
      }).toList();
  final rels = relations
      .map((r) => {'from': r.from, 'to': r.to, 'kind': r.kind})
      .toList();
  final tl = timeline.map((t) => {
        'chapter': t.chapter,
        'title': t.title,
        if (t.summary.isNotEmpty) 'summary': t.summary,
      }).toList();
  final digest = {
    '高频实体（按出现频次排序）': top,
    '关系边': rels,
    '时间线': tl,
    if (arcSummaries.isNotEmpty)
      '全书脉络（卷级剧情摘要，按时间顺序，必须忠于真实结局）': arcSummaries
    else
      '分块剧情摘要（按顺序）': chunkSummaries,
  };
  return '''
以下素材是从一部小说全文中按块抽取的（实体 / 关系 / 时间线 / 分块摘要）。
请把这些素材整理成一份可玩的世界圣经骨架。

铁律：
1. 忠于素材：素材里明确出现的人名、地名、势力名、关系一律保留原样，不得替换或发明新的主名；
   素材没有的部分（境界数值、代价、禁忌、终局等）由你补全，但要克制、与素材气质一致；
   若给出全书脉络，事件走向与终局必须与脉络一致，不得另编结局。
2. 实体里 type=character 的高频人物优先进入后续 NPC 设计素材；type=faction 映射为势力；
   type=place 映射为区域/地点。
3. 除 id（era_/reg_/place_/fac_）外，所有输出一律简体中文汉字；人名、地名、势力名不得使用拼音或英文单词。
4. 只输出一个 JSON 对象。

素材：
${jsonEncode(digest)}

只输出一个 JSON 对象，schema：
$kBibleCoreSchema

$kBibleCoreCounts''';
}

/// 全书分块摘要 → 卷级脉络压缩（忠实档专用，extractor 小模型一次调用）
String buildImportArcSystem() => '''
你是小说剧情脉络的压缩器。给定按时间顺序排列的分块剧情摘要（可能上百条，每条约 80 字），
把它们压缩为不超过 16 条的「卷级剧情摘要」，按时间顺序覆盖全书。

铁律：
1. 必须覆盖到全书结尾：最后一条必须是真实结局，不得在中途截断。
2. 主线走向、主要人物的命运、势力格局的重大变化必须保留。
3. 每条 ≤120 字，客观陈述，不评论，不得发明素材里没有的剧情。
4. 除 id 外所有输出一律简体中文汉字。
5. 只输出一个 JSON 对象，不要任何解释。''';

String buildImportArcUser(List<String> summaries) => '''
以下是按时间顺序排列的分块剧情摘要（共 ${summaries.length} 条）：

${[for (var i = 0; i < summaries.length; i++) '${i + 1}. ${summaries[i]}'].join('\n')}

请压缩为不超过 16 条的卷级剧情摘要，覆盖全书直到真实结局。
只输出一个 JSON 对象：{"arcs":["卷级摘要1","卷级摘要2"]}''';

/// 解析压缩输出；无法解析或为空返回 null（调用方降级为标准档采样）
List<String>? parseImportArcs(String text) {
  final m = extractJson(text);
  if (m == null) return null;
  try {
    final arcs = asList<String>(m['arcs'], (e) => e?.toString() ?? '')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
    if (arcs.isEmpty) return null;
    return arcs.take(16).toList();
  } catch (_) {
    return null;
  }
}
