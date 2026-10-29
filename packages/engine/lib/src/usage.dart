/// 观测统计（工程与开发计划 §9）：近 N 天本地用量汇总
class UsageStats {
  final int days;
  final int requests;
  final int failures;

  /// 首字延迟分位（毫秒）；流式请求取首字，非流式取总时长。无样本为 null
  final int? p50Ms;
  final int? p95Ms;

  final int tokensIn;
  final int tokensOut;

  /// 出现过请求的回合数（runId+turnNo 去重）
  final int turns;
  final int avgTokensPerTurn;

  const UsageStats({
    required this.days,
    required this.requests,
    required this.failures,
    this.p50Ms,
    this.p95Ms,
    required this.tokensIn,
    required this.tokensOut,
    required this.turns,
    required this.avgTokensPerTurn,
  });

  Map<String, Object?> toJson() => {
        'days': days,
        'requests': requests,
        'failures': failures,
        'p50Ms': p50Ms,
        'p95Ms': p95Ms,
        'tokensIn': tokensIn,
        'tokensOut': tokensOut,
        'turns': turns,
        'avgTokensPerTurn': avgTokensPerTurn,
      };
}
