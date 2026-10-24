import 'dart:convert';

import 'package:contracts/contracts.dart';

/// 从模型输出提取第一个完整 JSON 对象；截断时做括号修复
Map<String, Object?>? extractJson(String text) {
  final start = text.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inStr = false;
  var esc = false;
  for (var i = start; i < text.length; i++) {
    final c = text[i];
    if (inStr) {
      if (esc) {
        esc = false;
      } else if (c == '\\') {
        esc = true;
      } else if (c == '"') {
        inStr = false;
      }
      continue;
    }
    if (c == '"') {
      inStr = true;
    } else if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) {
        try {
          final v = jsonDecode(text.substring(start, i + 1));
          return v is Map ? rawMap(v) : null;
        } catch (_) {
          return null;
        }
      }
    }
  }
  // 截断修复：补齐引号与括号
  var fixed = text.substring(start);
  if (inStr) fixed += '"';
  fixed += '}' * depth;
  try {
    final v = jsonDecode(fixed);
    return v is Map ? rawMap(v) : null;
  } catch (_) {
    return null;
  }
}

String buildClassifierPrompt({
  required String placeName,
  required List<String> presentNpcs,
  required List<String> knowledgeTop5,
  required String input,
}) {
  return '''
你的唯一任务是判断玩家这句话属于哪一类，并规范化意图。不要解释，不要叙事。

当前处境：地点 $placeName；在场 ${presentNpcs.isEmpty ? '无他人' : presentNpcs.join('、')}；已知信息 ${knowledgeTop5.isEmpty ? '无' : knowledgeTop5.join('；')}。

分类标准：
- action：在角色能力与已知信息范围内可以尝试的行动
- query：询问自身状态、物品、关系、已知信息
- meta：询问玩法、规则、界面操作
- rejected：越权或违背世界硬规则（如「我直接飞升」）

只输出一个 JSON 对象：{"kind":"action|query|meta|rejected","intent":"一句话规范化意图","target":null,"confidence":0.9}

玩家输入：$input''';
}

IntentKind parseKind(Object? v) {
  final s = switch (asS(v)) {
    'action' => 'action',
    'query' => 'query',
    'meta' => 'meta',
    'rejected' => 'rejected',
    _ => 'action',
  };
  return IntentKind.values.firstWhere((e) => e.name == s);
}

const _scenePlanSchema = '''
{"beat":"daily|event|turning_point|chapter_end","summary":"一句话指令(≤120字)","npcActions":[{"npcId":"npc_xxx","action":"做什么","hidden":false}],"reveals":["本回合玩家看见的信息"],"mood":"压抑","nextChoices":[{"intent":"行动意图","risk":"low|medium|high","requires":null,"hidden":false}],"advanceTimeDays":1,"chapterEnd":null}''';

String buildDirectorPrompt({
  required ResolveResult resolve,
  required String intent,
  required String pendingReveals,
  required String memoryAndState,
  required bool canTurningPoint,
  required bool canChapterEnd,
}) {
  final resolveJson = resolve.check == null
      ? '{"feasible":${resolve.feasible},"blockedReason":${jsonEncode(resolve.blockedReason)},"grade":null}'
      : '{"feasible":true,"grade":"${resolve.check!.grade.name}","stat":"${resolve.check!.stat.name}","successRate":null,"roll":null}';
  final beatNote = [
    if (!canTurningPoint) '本回合不允许 turning_point（离上个关键节点太近）',
    if (!canChapterEnd) '本回合不允许 chapter_end（未到卷末回合）',
    if (canChapterEnd)
      '已到卷末（第 32 回合起）：本回合 beat 必须为 "chapter_end"，且 chapterEnd 必须为 {"reason":"一句话收卷理由"}；收束本卷全部主线伏笔，写突破筑基的判定与本卷终局，不得再开新支线',
  ].join('；');
  return '''
你是这个世界的导演。判定结果已经由系统给出，你只能据此编排，不能反转成败。

本回合判定（已裁决，不可更改）：
$resolveJson

玩家意图：$intent

当前状态与记忆：
$memoryAndState

可释放信息池（只能从这里取，取多少由你决定）：
${pendingReveals.isEmpty ? '（暂无预埋事件，按日常推进）' : pendingReveals}

约束：$beatNote
你必须决定：这一回合发生什么、哪些信息被玩家看见、下一批选项是什么。
选项必须互斥且各有代价，3–4 条，不得出现「都可以」的伪选项。
未到期的伏笔只能轻轻触碰，不得一次揭穿。
不得在本回合直接宣告结局。

只输出一个 JSON 对象，schema：
$_scenePlanSchema''';
}

ScenePlan parseScenePlan(String text) {
  final m = extractJson(text);
  if (m == null) {
    // 降级为保守日常计划
    return ScenePlan(
      beat: Beat.daily,
      summary: '日常推进，不释放关键信息',
      npcActions: [],
      reveals: [],
      mood: '松弛',
      nextChoices: [
        PlanChoice(intent: '继续眼前的事', risk: Risk.low),
        PlanChoice(intent: '寻找一个可以打听消息的人', risk: Risk.low),
      ],
    );
  }
  final plan = ScenePlan.fromJson(m);
  final choices = plan.nextChoices
      .where((c) => c.intent.isNotEmpty)
      .take(4)
      .toList();
  return ScenePlan(
    beat: plan.beat,
    summary: plan.summary.isEmpty ? '推进场景' : plan.summary,
    npcActions: plan.npcActions.take(4).toList(),
    reveals: plan.reveals.take(3).toList(),
    mood: plan.mood,
    nextChoices: choices.isEmpty
        ? [PlanChoice(intent: '继续眼前的事', risk: Risk.low)]
        : choices,
    advanceTimeDays: plan.advanceTimeDays,
    chapterEnd: plan.chapterEnd,
  );
}

String buildNarratorPrompt({
  required ScenePlan plan,
  required ResolveResult resolve,
  required String recentTurns,
  required String gradeHint,
}) {
  return '''
你负责把场景计划写成正文。你写的是玩家看到的一切。

本回合场景计划：
${jsonEncode(plan.toJson())}

判定结果（只体现为体感，不得写出成败术语）：$gradeHint

最近三回合原文（延续语感，不重复内容）：
${recentTurns.isEmpty ? '（这是本局开头）' : recentTurns}

要求：150–300 字（关键节点可到 500 字）；第二人称「你」；不出现数值与判定术语；
只写已发生的事与玩家可见的物象动作；对话简短，不解释设定；不出现表格、标题、代码块。
直接输出正文，不要任何前后缀。''';
}

String buildExtractorPrompt({
  required String narration,
  required ScenePlan plan,
  required String stateSlice,
}) {
  return '''
你的任务是把已经写好的正文翻译成状态变更。你不创作新情节。

正文：
$narration

场景计划：
${jsonEncode(plan.toJson())}

变更前状态（节选）：
$stateSlice

允许写入的路径（白名单，其余一律不得出现）：
meta.age(set/inc)｜character.stats.vitality|spirit|body(set/inc,0..100)｜character.resources.spiritStones(set/inc,≥0)｜character.resources.pills.<id>(set/inc)｜character.conditions(push/remove)｜location.regionId|placeId(set)｜relations.<npcId>.affinity|trust(set/inc)|status(set)｜inventory(push/remove)｜knowledge(push/remove)｜threads(push)｜flags.<key>(set/inc)｜reputation.<factionId>(set/inc)

只输出一个 JSON 对象：
{"ops":[{"op":"inc","path":"character.stats.vitality","by":-3,"reason":"短原因"}],"facts":["≤80字的事实"],"openThreads":[{"id":"t_xxx","desc":"≤60字","dueChapter":3,"status":"open","createdAtTurn":0}],"closeThreads":["t_xxx"],"choices":[{"intent":"原意图","label":"8-30字文案"}]}

上限：ops ≤ 12 条；facts ≤ 6 条。facts 必须是正文中真实发生过的事；choices 只润色既有意图的文案，不得改变意图。''';
}

StateDelta parseExtractorOutput(String text) {
  final m = extractJson(text);
  if (m == null) return StateDelta.empty();
  final delta = StateDelta.fromJson(m);
  return StateDelta(
    ops: delta.ops.take(12).toList(),
    facts: delta.facts.take(6).map((f) => f.length > 80 ? f.substring(0, 80) : f).toList(),
    openThreads: delta.openThreads.take(3).toList(),
    closeThreads: delta.closeThreads.take(5).toList(),
  );
}

String buildCompanionPrompt({
  required String knowledge,
  required String stateSummary,
  required String recentTurns,
  required String question,
}) {
  return '''
你是随玩家同行的旅伴，不是旁白，也不是先知。你只知道玩家已知的信息。

你已知：${knowledge.isEmpty ? '（初来乍到，所知有限）' : knowledge}
当前状态：$stateSummary
最近五回合：${recentTurns.isEmpty ? '（尚无）' : recentTurns}

回答要求：100–200 字，第一人称「我」，像同行者说话，不推进剧情、不改变状态、不预告未来。
- 问「接下来会怎样」：只给基于已知线索的推断，不做预言
- 问他人秘密：直接说「你目前不知道」，并说明判断依据
- 问世界真相：一律不答，回「这些得靠你自己去看」

玩家的问题：$question''';
}

const companionFallback = '一时想不出该怎么答，先看看眼前吧。';

String buildCompactPrompt({
  required String volumeSummary,
  required List<String> turnFacts,
  required List<String> recentNarrations,
  required String stateSummary,
}) {
  return '''
你负责把一卷发生的事压缩成给导演用的记忆卡。不创作新情节，只整理已有内容。

本卷正文摘要：
${recentNarrations.take(20).join('\n')}

已记录事实：
${turnFacts.take(40).join('；')}

当前状态：$stateSummary

只输出一个 JSON 对象：
{"facts":["最重要的既成事实，≤12条，每条≤80字"],"relationChanges":["关系变化，≤8条，格式：npcId: 变化"],"openThreads":["仍未回收的伏笔，≤8条"],"volumeSummary":"本卷卷记，300字以内，第二人称"}''';
}
