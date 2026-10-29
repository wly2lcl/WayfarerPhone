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
    // 计时按「单次尝试」重置：重试后累计耗时不得影响本次判定与用量记录
    final sw = Stopwatch();
    var attempt = 0;
    while (true) {
      attempt++;
      sw..reset()..start();
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
        await Future<void>.delayed(_backoff(attempt, e));
      }
    }
  }

  /// 流式返回正文增量（叙事 / 助手）。结束后发一次完整结果。
  Stream<dynamic> stream(GatewayRequest req) async* {
    // 计时按「单次尝试」重置：修复重试间不重置导致第二次尝试即使首字秒回
    // 也被累计耗时误判「首字超时」的 bug
    final sw = Stopwatch();
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
      sw..reset()..start();
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
        await Future<void>.delayed(_backoff(attempt, e));
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

  /// 退避：429 时优先用供应商返回的 Retry-After（_mapHttpError 已解析并 clamp 0..30，
  /// 0 表示立即重试；限流最多重试 1 次不会成风暴），其余按固定 1s/3s
  Duration _backoff(int attempt, EngineException e) {
    final retryAfter = e.details?['retryAfterSec'];
    if (retryAfter is int) {
      return Duration(seconds: retryAfter);
    }
    return Duration(seconds: attempt == 1 ? 1 : 3);
  }

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
    final baseUrl = ModelSettings.validateEndpointUrl(settings.baseUrl).toString();
    final adapter = adapterFor(settings.protocol);
    final key = await config.keyStore.read() ?? '';
    if (key.isEmpty) {
      throw EngineException(EngineCode.modelNotConfigured, '未填写 Key');
    }
    final spec = adapter.buildRequest(
      baseUrl: baseUrl,
      apiKey: key,
      model: model,
      system: req.system,
      user: req.user,
      jsonMode: req.jsonMode,
      temperature: req.temperature,
      maxTokens: req.maxTokens,
    );
    final uri = ModelSettings.validateEndpointUrl(spec.url);

    HttpClientRequest request;
    try {
      request = await _client.postUrl(uri);
    } catch (_) {
      throw EngineException(EngineCode.modelNetwork, '无法连接模型服务', canRetry: true);
    }
    request.followRedirects = false;
    spec.headers.forEach(request.headers.set);
    request.add(utf8.encode(jsonEncode(spec.body)));

    HttpClientResponse response;
    try {
      // API参考 §5.3：首字超时放宽到 60s —— 实测部分供应商首字延迟可达 40s
      response = await request.close().timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw EngineException(EngineCode.modelTimeout, '首字超时', canRetry: true);
    } catch (_) {
      throw EngineException(EngineCode.modelNetwork, '网络错误', canRetry: true);
    }

    if (response.statusCode >= 300 && response.statusCode < 400) {
      await response.drain<void>();
      throw EngineException(EngineCode.modelNotConfigured,
          '已阻止模型服务重定向，请在设置页填写最终 HTTPS 地址（本机 loopback 可用 HTTP）');
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
    } catch (_) {
      throw EngineException(EngineCode.modelNetwork, '流读取失败', canRetry: true);
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
