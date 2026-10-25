// 意图分类标注集评测（TODO WF-M0-06-02）：50 条四类输入跑真实模型，准确率 ≥90% 通过。
// 凭据只走环境变量，不落盘：LLM_BASE_URL / LLM_KEY / LLM_MODEL [LLM_PROTOCOL]
// 运行：cd packages/engine && LLM_BASE_URL=... LLM_KEY=... LLM_MODEL=... dart run tool/classifier_eval.dart
import 'dart:convert';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:engine/engine.dart';
import 'package:engine/src/prompts/roles.dart'
    show buildClassifierPrompt, extractJson, parseKind;
import 'package:engine/src/turn/context.dart' show ironLawSection;

/// (期望类别, 玩家输入)
const _cases = <(String, String)>[
  // ---- action（20）----
  ('action', '去药庐帮工，换几个灵石'),
  ('action', '拦住守夜人，问他昨晚去了哪'),
  ('action', '把剩下的半块灵石换成干粮'),
  ('action', '沿着后墙小路摸到黑水泽边缘'),
  ('action', '当街拦下缇骑的马头'),
  ('action', '把那枚玉牌埋在后院老槐树下'),
  ('action', '修好柴房漏风的窗户'),
  ('action', '跟着罗沈走，看他去见谁'),
  ('action', '去坊市打听赤血参的行情'),
  ('action', '夜里翻墙进内门藏书楼'),
  ('action', '给沈缰送一壶热酒'),
  ('action', '把伤药敷在腿上，然后睡下'),
  ('action', '收拾包袱，天亮前离开青冥宗'),
  ('action', '在鬼市摆个小摊，卖我打听来的消息'),
  ('action', '试着催动体内那缕微弱的灵气'),
  ('action', '去祠堂帮执事抄写符纸'),
  ('action', '假意替掌柜跑腿，混进出货的车队'),
  ('action', '到河边把那具尸首捞上岸'),
  ('action', '把缇骑引去西边的废巷'),
  ('action', '围着药庐巡视一圈，看看有没有陌生的脚印'),
  // ---- query（12）----
  ('query', '我现在还剩多少灵石？'),
  ('query', '罗沈对我是什么态度？'),
  ('query', '我身上都有什么伤？'),
  ('query', '那枚玉牌到底是什么来历？'),
  ('query', '黑水泽离这里有多远？'),
  ('query', '关于缇骑我都知道些什么？'),
  ('query', '我的寿元还剩多少？'),
  ('query', '沈缰现在信任我吗？'),
  ('query', '我现在是什么境界？'),
  ('query', '鬼市什么时候开市？'),
  ('query', '我的行囊里还有哪些东西？'),
  ('query', '青冥宗和朝廷现在是什么关系？'),
  // ---- meta（8）----
  ('meta', '这个游戏怎么存档？'),
  ('meta', '数值面板在哪里看？'),
  ('meta', '怎么回到上一回合？'),
  ('meta', '选项旁边的红点黄点是什么意思？'),
  ('meta', '怎么换一个模型供应商？'),
  ('meta', '这局结束后能分叉重玩吗？'),
  ('meta', '自由输入有什么限制？'),
  ('meta', '怎么把我的世界导出去备份？'),
  // ---- rejected（10）----
  ('rejected', '我直接飞升成仙'),
  ('rejected', '一拳打死缇骑统领'),
  ('rejected', '让青冥宗宗主把位置让给我'),
  ('rejected', '瞬间移动到京城皇城里'),
  ('rejected', '召唤天雷把全城缇骑劈死'),
  ('rejected', '起死回生，把死去的师父救活'),
  ('rejected', '我要夺取玉玺，号令天下修士'),
  ('rejected', '变出十万灵石从天上砸下去'),
  ('rejected', '一步跨过黑水泽，直接到对岸'),
  ('rejected', '让全城的人都忘记我是谁'),
];

WorldBible _loadBible() {
  final dir = Directory.current.path.endsWith('/packages/engine')
      ? Directory.current.path
      : '${Directory.current.path}/packages/engine';
  final f = File('$dir/../../apps/mobile/assets/seed/cangwu/bible.json');
  return WorldBible.fromJson(jsonDecode(f.readAsStringSync()));
}

Future<void> main() async {
  final env = Platform.environment;
  final baseUrl = env['LLM_BASE_URL'];
  final key = env['LLM_KEY'];
  final model = env['LLM_MODEL'];
  if (baseUrl == null || key == null || model == null) {
    stderr.writeln('需要环境变量 LLM_BASE_URL / LLM_KEY / LLM_MODEL（凭据只走环境变量，不落盘）');
    exitCode = 2;
    return;
  }
  final protocol = LlmProtocol.values.firstWhere(
    (p) => p.name == (env['LLM_PROTOCOL'] ?? 'openai_chat'),
    orElse: () => LlmProtocol.openai_chat,
  );
  final keyStore = InMemoryKeyStore()..write(key);
  final gw = ModelGateway(GatewayConfig(
    settings: () => ModelSettings(
      protocol: protocol,
      baseUrl: baseUrl,
      narrativeModel: model,
      smallModel: model,
    ),
    keyStore: keyStore,
  ));
  final bible = _loadBible();
  const place = 'place_market_south';
  const npcs = ['罗沈', '沈缰'];
  const knowledge = [
    '你是外门杂役，藏着一枚来历不明的玉牌',
    '缇骑正在清查未登记的修士',
    '鬼市三日后开市',
  ];

  var correct = 0;
  final wrong = <String>[];
  final byKind = <String, List<int>>{};
  for (final (label, input) in _cases) {
    final system =
        '${ironLawSection(bible)}\n\n${buildClassifierPrompt(placeName: place, presentNpcs: npcs, knowledgeTop5: knowledge, input: input)}';
    String got;
    GatewayResult? res;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        res = await gw.complete(GatewayRequest(
          role: GatewayRole.classifier,
          system: system,
          user: '状态摘要：外门杂役；灵石紧张；左腿有轻伤。玩家输入：$input',
          jsonMode: true,
          temperature: 0.1,
          maxTokens: 120,
        ));
        break;
      } on EngineException catch (e) {
        if (attempt == 2) {
          stderr.writeln('  [网关异常×3] ${e.code.name}: ${e.message}');
        } else {
          stderr.writeln('  [网关异常，45s 后重试] ${e.code.name}');
          await Future<void>.delayed(const Duration(seconds: 45));
        }
      }
    }
    final m = res == null ? null : extractJson(res.text);
    got = m == null ? 'action' : parseKind(m['kind']).name;
    final ok = got == label;
    if (ok) correct++;
    byKind.putIfAbsent(label, () => [0, 0]);
    byKind[label]![0] += ok ? 1 : 0;
    byKind[label]![1] += 1;
    if (!ok) wrong.add('$label → $got  「$input」');
    stdout.writeln('${ok ? "✓" : "✗"} $label → $got  $input');
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  final acc = correct / _cases.length;
  stdout.writeln('\n正确 $correct / ${_cases.length} = ${(acc * 100).toStringAsFixed(1)}%');
  for (final e in byKind.entries) {
    stdout.writeln('  ${e.key}: ${e.value[0]}/${e.value[1]}');
  }
  if (wrong.isNotEmpty) stdout.writeln('\n错例：\n${wrong.join('\n')}');
  stdout.writeln(acc >= 0.9 ? '验收通过（≥90%）。' : '验收未达（<90%）。');
  exitCode = acc >= 0.9 ? 0 : 1;
}
