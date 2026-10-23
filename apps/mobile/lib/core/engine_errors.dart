import 'package:engine/engine.dart';

/// EngineCode 的中文短标签（只按 code 分支展示，不解析 message 做逻辑）
String engineCodeLabel(EngineCode code) => switch (code) {
      EngineCode.notFound => '内容不存在',
      EngineCode.turnConflict => '回合冲突',
      EngineCode.runEnded => '本局已落幕',
      EngineCode.modelNotConfigured => '模型未配置',
      EngineCode.modelAuthFailed => '密钥无效',
      EngineCode.modelRateLimited => '请求过于频繁',
      EngineCode.modelTimeout => '请求超时',
      EngineCode.modelBadOutput => '模型返回异常',
      EngineCode.modelNetwork => '网络中断',
      EngineCode.contentBlocked => '内容被拦截',
      EngineCode.stateInvalid => '状态异常',
      EngineCode.storageFull => '本地存储不足',
      EngineCode.importInvalid => '导入文件无效',
      EngineCode.importTooLarge => '导入文件过大',
      EngineCode.exportForbidden => '该世界不允许导出',
      EngineCode.draftIncomplete => '草稿尚未完成',
      EngineCode.qualityGateFailed => '质量校验未通过',
      EngineCode.worldFrozen => '世界已冻结',
    };

/// 事件流里的 TurnError.code 是 wireName 字符串，转回枚举再取标签
String turnErrorCodeLabel(String wireName) =>
    engineCodeLabel(EngineCode.fromWire(wireName));
