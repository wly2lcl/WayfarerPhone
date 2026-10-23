enum EngineCode {
  notFound,
  turnConflict,
  runEnded,
  modelNotConfigured,
  modelAuthFailed,
  modelRateLimited,
  modelTimeout,
  modelBadOutput,
  modelNetwork,
  contentBlocked,
  stateInvalid,
  storageFull,
  importInvalid,
  importTooLarge,
  exportForbidden,
  draftIncomplete,
  qualityGateFailed,
  worldFrozen;

  /// 对外事件/异常码统一 SCREAMING_SNAKE（API 参考 §1 错误码表）
  String get wireName {
    final snake = name.replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m.group(1)}_${m.group(2)}');
    return snake.toUpperCase();
  }

  static EngineCode fromWire(String s) {
    for (final c in EngineCode.values) {
      if (c.wireName == s) return c;
    }
    return EngineCode.stateInvalid;
  }
}

class EngineException implements Exception {
  final EngineCode code;
  final String message;
  final Map<String, Object?>? details;
  final bool canRetry;

  EngineException(
    this.code,
    this.message, {
    this.details,
    this.canRetry = false,
  });

  @override
  String toString() => 'EngineException(${code.wireName}, $message)';
}
