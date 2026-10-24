import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'adapters/adapters.dart';
import 'settings.dart';
import '../errors.dart';

class GatewayRequest {
  final GatewayRole role;
  final String system;
  final String user;
  final bool jsonMode;
  final double temperature;
  final int maxTokens;

  /// 归属回合（观测 §9 的 usage_log.run_id / turn_no）；探活等无归属请求为 null
  final String? runId;
  final int? turnNo;

  GatewayRequest({
    required this.role,
    required this.system,
    required this.user,
    this.jsonMode = false,
    this.temperature = 0.8,
    this.maxTokens = 1200,
    this.runId,
    this.turnNo,
  });
}

class GatewayResult {
  final String text;
  final int tokensIn;
  final int tokensOut;
  final bool estimated;
  final int ms;
  final String model;
  GatewayResult({
    required this.text,
    required this.tokensIn,
    required this.tokensOut,
    required this.estimated,
    required this.ms,
    required this.model,
  });
}

typedef UsageSink = void Function(UsageRecord record);

class GatewayConfig {
  final ModelSettings Function() settings;
  final KeyStore keyStore;
  final UsageSink? onUsage;

  GatewayConfig({required this.settings, required this.keyStore, this.onUsage});
}

/// App 内唯一模型出口（API 参考 §5）
class ModelGateway {
  final GatewayConfig config;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  ModelGateway(this.config);

  ModelSettings get _settings {
    final s = config.settings();
    if (!s.configured) {
      throw EngineException(EngineCode.modelNotConfigured, '模型未配置，请先到设置页填写');
    }
    return s;
  }

  void _record(GatewayRole role, String model, int tIn, int tOut, bool est, int ms, bool ok,
      {int? firstByteMs, String? runId, int? turnNo}) {
    config.onUsage?.call(UsageRecord(
      role: role,
      model: model,
      tokensIn: tIn,
      tokensOut: tOut,
      estimated: est,
      ms: ms,
      ok: ok,
      firstByteMs: firstByteMs,
      runId: runId,
      turnNo: turnNo,
    ));
  }

  /// 非流式整段返回（分类 / 导演 / 提取 / 压缩）
  Future<GatewayResult> complete(GatewayRequest req) async {
    final settings = _settings;
    final model = settings.modelFor(req.role);
    final sw = Stopwatch()..start();
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        final (text, firstByteMs) = await _runOnce(settings, model, req);
        sw.stop();
        final tOut = estimateTokens(text);
        final result = GatewayResult(
          text: text,
          tokensIn: 0,
          tokensOut: tOut,
          estimated: true,
          ms: sw.elapsedMilliseconds,
          model: model,
        );
        _record(req.role, model, result.tokensIn, result.tokensOut, true,
            result.ms, true,
            firstByteMs: firstByteMs, runId: req.runId, turnNo: req.turnNo);
        return result;
      } on EngineException catch (e) {
        _record(req.role, model, 0, 0, false, sw.elapsedMilliseconds, false,
            runId: req.runId, turnNo: req.turnNo);
        if (!e.canRetry || attempt > _maxAttempts(e)) rethrow;
        await Future<void>.delayed(_backoff(attempt));
      }
    }
  }

  /// 流式返回正文增量（叙事 / 助手）。结束后发一次完整结果。
  Stream<dynamic> stream(GatewayRequest req) async* {
    final sw = Stopwatch()..start();
    final settings = _settings;
    final model = settings.modelFor(req.role);
    var attempt = 0;
    var buffer = StringBuffer();
    var usageIn = 0;
    var usageOut = 0;
    var firstDelta = true;
    int? firstByteMs;
    while (true) {
      attempt++;
      firstDelta = true;
      buffer = StringBuffer();
      try {
        await for (final chunk in _runStream(settings, model, req)) {
          if (chunk is String) {
            if (firstDelta && sw.elapsedMilliseconds > 60000) {
              throw EngineException(EngineCode.modelTimeout, '首字超时', canRetry: true);
            }
            if (firstDelta) firstByteMs = sw.elapsedMilliseconds;
            firstDelta = false;
            buffer.write(chunk);
            yield chunk;
          } else if (chunk is SseEvent) {
            if (chunk.tokensIn != null) usageIn = chunk.tokensIn!;
            if (chunk.tokensOut != null) usageOut = chunk.tokensOut!;
          }
        }
        sw.stop();
        final full = buffer.toString();
        final estimated = usageIn == 0 && usageOut == 0;
        final tIn = usageIn == 0 ? 0 : usageIn;
        final tOut = usageOut == 0 ? estimateTokens(full) : usageOut;
        _record(req.role, model, tIn, tOut, estimated, sw.elapsedMilliseconds, true,
            firstByteMs: firstByteMs, runId: req.runId, turnNo: req.turnNo);
        return;
      } on EngineException catch (e) {
        _record(req.role, model, 0, 0, false, sw.elapsedMilliseconds, false,
            runId: req.runId, turnNo: req.turnNo);
        if (buffer.isNotEmpty) {
          // 已输出正文后断开：保留正文，不落库（API 参考 §5.2）
          throw EngineException(EngineCode.modelTimeout, '流式中断，已保留正文', canRetry: true);
        }
        if (!e.canRetry || attempt > _maxAttempts(e)) rethrow;
        await Future<void>.delayed(_backoff(attempt));
      }
    }
  }

  /// 最小请求验证 baseUrl + Key + 模型名（API 参考 settings.testConnection）
  Future<ConnectionReport> testConnection() async {
    final sw = Stopwatch()..start();
    try {
      final settings = _settings;
      final model = settings.narrativeModel;
      final (text, _) = await _runOnce(
        settings,
        model,
        GatewayRequest(
          role: GatewayRole.classifier,
          system: 'ping',
          user: '回复 ok',
          maxTokens: 8,
        ),
      );
      return ConnectionReport(
        ok: true,
        model: model,
        latencyMs: sw.elapsedMilliseconds,
        message: text,
      );
    } on EngineException catch (e) {
      return ConnectionReport(
        ok: false,
        errorCode: e.code,
        message: e.message,
      );
    }
  }

  int _maxAttempts(EngineException e) => switch (e.code) {
        EngineCode.modelNetwork => 2,
        EngineCode.modelTimeout => 1,
        EngineCode.modelRateLimited => 1,
        _ => 0,
      };

  Duration _backoff(int attempt) =>
      Duration(seconds: attempt == 1 ? 1 : 3);

  Future<(String, int?)> _runOnce(
    ModelSettings settings,
    String model,
    GatewayRequest req,
  ) async {
    final sw = Stopwatch()..start();
    final buffer = StringBuffer();
    int? firstByteMs;
    await for (final chunk in _runStream(settings, model, req)) {
      if (chunk is String) {
        firstByteMs ??= sw.elapsedMilliseconds;
        buffer.write(chunk);
      }
    }
    return (buffer.toString(), firstByteMs);
  }

  Stream<Object> _runStream(
    ModelSettings settings,
    String model,
    GatewayRequest req,
  ) async* {
    final adapter = adapterFor(settings.protocol);
    final key = await config.keyStore.read() ?? '';
    if (key.isEmpty) {
      throw EngineException(EngineCode.modelNotConfigured, '未填写 Key');
    }
    final spec = adapter.buildRequest(
      baseUrl: settings.baseUrl,
      apiKey: key,
      model: model,
      system: req.system,
      user: req.user,
      jsonMode: req.jsonMode,
      temperature: req.temperature,
      maxTokens: req.maxTokens,
    );

    HttpClientRequest request;
    try {
      request = await _client.postUrl(Uri.parse(spec.url));
    } catch (e) {
      throw EngineException(EngineCode.modelNetwork, '无法连接模型服务：$e', canRetry: true);
    }
    spec.headers.forEach(request.headers.set);
    request.add(utf8.encode(jsonEncode(spec.body)));

    HttpClientResponse response;
    try {
      // API参考 §5.3：首字超时放宽到 60s —— 实测部分供应商首字延迟可达 40s
      response = await request.close().timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw EngineException(EngineCode.modelTimeout, '首字超时', canRetry: true);
    } catch (e) {
      throw EngineException(EngineCode.modelNetwork, '网络错误：$e', canRetry: true);
    }

    if (response.statusCode != 200) {
      final body = await response.transform(utf8.decoder).join();
      final retryAfter = response.headers.value('retry-after');
      throw _mapHttpError(response.statusCode, body, retryAfter);
    }

    final started = Stopwatch()..start();
    try {
      final lines = response
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      // 契约 §5.3：帧间隔 30s 无数据判空闲超时；单次请求总时长 180s 封顶
      await for (final raw
          in lines.timeout(const Duration(seconds: 30))) {
        if (started.elapsed > const Duration(seconds: 180)) {
          throw EngineException(EngineCode.modelTimeout, '单次请求超时',
              canRetry: true);
        }
        final l = raw.trim();
        if (l.isEmpty || l.startsWith(':') || !l.startsWith('data:')) {
          continue;
        }
        final ev = adapter.parseFrame(l.substring(5).trim());
        if (ev == null) continue;
        if (ev.delta != null && ev.delta!.isNotEmpty) yield ev.delta!;
        if (ev.done) break;
      }
    } on EngineException {
      rethrow;
    } catch (e) {
      throw EngineException(EngineCode.modelNetwork, '流读取失败：$e', canRetry: true);
    }
  }

  EngineException _mapHttpError(int status, String body, String? retryAfter) {
    switch (status) {
      case 401:
      case 403:
        return EngineException(EngineCode.modelAuthFailed,
            'Key 无效或余额不足（$status）');
      case 429:
        var waitSec = 5;
        if (retryAfter != null) {
          waitSec = int.tryParse(retryAfter) ?? 5;
        }
        return EngineException(EngineCode.modelRateLimited,
            '限流，$waitSec 秒后重试', canRetry: true,
            details: {'retryAfterSec': waitSec.clamp(0, 30)});
      case 400:
        return EngineException(EngineCode.modelBadOutput, '请求被拒绝（400）：$body');
      default:
        return EngineException(EngineCode.modelNetwork, '模型服务错误 $status',
            canRetry: status >= 500);
    }
  }
}

class ConnectionReport {
  final bool ok;
  final String? model;
  final int? latencyMs;
  final EngineCode? errorCode;
  final String? message;

  ConnectionReport({
    required this.ok,
    this.model,
    this.latencyMs,
    this.errorCode,
    this.message,
  });
}
