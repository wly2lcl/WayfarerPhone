import '../errors.dart';

/// 内容安全标签（合规与内容安全 §3：三层共用同一套标签体系）
enum SafetyLabel {
  /// 自残/自杀方法与过程
  selfHarm,

  /// 现实暴力/危险品可操作指导
  violenceTutorial,

  /// 涉未成年人性内容
  minorSexual;

  String get wireName => name;
}

/// 本地筛查结论
class SafetyVerdict {
  final bool blocked;
  final SafetyLabel? label;
  final String matched;

  const SafetyVerdict.blocked(this.label, this.matched)
      : blocked = true;
  const SafetyVerdict.clean()
      : blocked = false,
        label = null,
        matched = '';

  @override
  String toString() =>
      blocked ? 'SafetyVerdict(${label!.wireName}, "$matched")' : 'SafetyVerdict.clean';
}

/// 本地内容安全筛查（合规与内容安全 §3.1 输入层 / §3.2 流式兜底）。
///
/// 设计口径：
/// - 只拦「方法/教程/可操作指导」与露骨违法组合，不拦题材名词本身
///   （修真世界「毒药」「杀人」是世界语汇，拦了会大面积误杀）；
/// - 纯本地词表 + 正则，命中即拒，不发模型请求；
/// - 词表随 App 版本发布更新，无热更新。
class ContentSafety {
  ContentSafety._();

  /// 高危正则规则（输入层与流式兜底共用）。
  /// 顺序即优先级；`_` 为占位宽匹配，整条按「意图词 + 方法词」组合设计。
  static final List<(SafetyLabel, RegExp)> _rules = [
    // ---- 自残/自杀：方法、教程、劝诱 ----
    (
      SafetyLabel.selfHarm,
      RegExp(r'(自残|自杀|自尽|轻生|了断)[^。！？]{0,12}(方法|怎么|如何|步骤|教程|方式|办?[法決])')
    ),
    (
      SafetyLabel.selfHarm,
      RegExp(r'(怎么|如何|教我|告诉我)[^。！？]{0,8}(自杀|自残|自尽|轻生|割腕|上吊)')
    ),
    (SafetyLabel.selfHarm, RegExp(r'割腕|动脉放血|烧炭自杀|安眠药(吞|送服)?\d|百草枯')),
    // ---- 现实暴力/危险品：制造与可操作指导 ----
    (
      SafetyLabel.violenceTutorial,
      RegExp(r'(制造|制作|合成|配|提炼)[^。！？]{0,8}(炸弹|炸药|爆炸物|燃烧瓶|毒气|沙林|氰化物|枪|管制刀具)')
    ),
    (
      SafetyLabel.violenceTutorial,
      RegExp(r'(炸弹|炸药|爆炸物|燃烧瓶|毒气|沙林|氰化物)[^。！？]{0,8}(配方|制作|制造|教程|步骤|原料)')
    ),
    (
      SafetyLabel.violenceTutorial,
      RegExp(r'(怎么|如何|教我|告诉我)[^。！？]{0,8}(下毒|投毒|制炸|做炸弹|杀人分尸|埋伏?袭击)')
    ),
    (SafetyLabel.violenceTutorial, RegExp(r'下毒[^。！？]{0,10}(步骤|剂量|教程|配方)')),
    (SafetyLabel.violenceTutorial, RegExp(r'(下毒|投毒|投毒杀人)[^。！？]{0,10}(步骤|方法|教程|配方|剂量|怎么|如何)')),
    // ---- 未成年人性化：一律硬拒，不做世界内化 ----
    (
      SafetyLabel.minorSexual,
      RegExp(r'(未成年|幼女|幼童|儿童|小孩|少女|萝莉|中学生?|小学生?)[^。！？]{0,16}(性|色情|性行为|奸|床[戏上]|脱|胸|身体[^。！？]{0,4}(接触|关系))')
    ),
    (SafetyLabel.minorSexual, RegExp(r'儿童色情|恋童|幼女[^。！？]{0,6}(奸|性)|性侵(儿童|未成年|幼女)')),
  ];

  /// 输入层筛查：自由输入、世界访谈回答、导入文件名与元数据。
  /// 违规时可直接抛 [contentBlockedError]。
  static SafetyVerdict screen(String text) {
    final t = text.trim();
    if (t.isEmpty) return const SafetyVerdict.clean();
    for (final (label, re) in _rules) {
      final m = re.firstMatch(t);
      if (m != null) return SafetyVerdict.blocked(label, m.group(0)!);
    }
    return const SafetyVerdict.clean();
  }

  /// 生成层流式兜底：对累计输出逐段检查（输出文本 ≤ 2k 字，规则数有限，直接全量扫）。
  static SafetyVerdict screenStream(String accumulated) => screen(accumulated);

  /// 统一的拦截异常（UI 侧按 CONTENT_BLOCKED 映射「内容被拦截」）
  static EngineException contentBlockedError([String? matched]) =>
      EngineException(
        EngineCode.contentBlocked,
        matched == null
            ? '输入触及内容安全边界，已在本地拦截，未发起模型请求'
            : '内容触及安全边界（命中：$matched），已本地拦截',
        details: {'layer': 'local', if (matched != null) 'matched': matched},
      );
}
