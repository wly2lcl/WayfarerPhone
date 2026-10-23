import 'dart:convert';

import '../settings.dart';

class SseEvent {
  /// 增量正文；null 表示本帧不是正文
  final String? delta;

  /// 推理类内容，只计数不进正文
  final String? reasoning;

  final int? tokensIn;
  final int? tokensOut;

  /// 结束信号
  final bool done;

  const SseEvent({
    this.delta,
    this.reasoning,
    this.tokensIn,
    this.tokensOut,
    this.done = false,
  });
}

class RequestSpec {
  final String url;
  final Map<String, String> headers;
  final Map<String, Object?> body;
  RequestSpec(this.url, this.headers, this.body);
}

abstract class ProtocolAdapter {
  LlmProtocol get protocol;

  RequestSpec buildRequest({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String system,
    required String user,
    required bool jsonMode,
    required double temperature,
    required int maxTokens,
  });

  SseEvent? parseFrame(String data);
}

class OpenAiChatAdapter implements ProtocolAdapter {
  @override
  LlmProtocol get protocol => LlmProtocol.openai_chat;

  @override
  RequestSpec buildRequest({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String system,
    required String user,
    required bool jsonMode,
    required double temperature,
    required int maxTokens,
  }) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return RequestSpec(
      '$base/chat/completions',
      {
        'content-type': 'application/json',
        'authorization': 'Bearer $apiKey',
      },
      {
        'model': model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
        'stream': true,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream_options': {'include_usage': true},
        if (jsonMode) 'response_format': {'type': 'json_object'},
      },
    );
  }

  @override
  SseEvent? parseFrame(String data) {
    if (data == '[DONE]') return const SseEvent(done: true);
    final Map<String, Object?> m;
    try {
      m = jsonDecode(data) as Map<String, Object?>;
    } catch (_) {
      return null;
    }
    final usage = m['usage'];
    final choices = m['choices'] as List?;
    String? delta;
    String? reasoning;
    if (choices != null && choices.isNotEmpty) {
      final d = (choices.first as Map)['delta'];
      if (d is Map) {
        delta = d['content'] is String ? d['content'] as String : null;
        reasoning = d['reasoning_content'] is String
            ? d['reasoning_content'] as String
            : null;
      }
    }
    final done = (m['choices'] as List?)?.isEmpty ?? false;
    int? tIn;
    int? tOut;
    if (usage is Map) {
      tIn = usage['prompt_tokens'] is int ? usage['prompt_tokens'] as int : null;
      tOut = usage['completion_tokens'] is int
          ? usage['completion_tokens'] as int
          : null;
    }
    return SseEvent(delta: delta, reasoning: reasoning, tokensIn: tIn, tokensOut: tOut, done: done);
  }
}

class OpenAiResponsesAdapter implements ProtocolAdapter {
  @override
  LlmProtocol get protocol => LlmProtocol.openai_responses;

  @override
  RequestSpec buildRequest({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String system,
    required String user,
    required bool jsonMode,
    required double temperature,
    required int maxTokens,
  }) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return RequestSpec(
      '$base/responses',
      {
        'content-type': 'application/json',
        'authorization': 'Bearer $apiKey',
      },
      {
        'model': model,
        'instructions': system,
        'input': [
          {'role': 'user', 'content': user},
        ],
        'stream': true,
        'temperature': temperature,
        'max_output_tokens': maxTokens,
        if (jsonMode) 'text': {'format': {'type': 'json_object'}},
      },
    );
  }

  @override
  SseEvent? parseFrame(String data) {
    if (data == '[DONE]') return const SseEvent(done: true);
    final Map<String, Object?> m;
    try {
      m = jsonDecode(data) as Map<String, Object?>;
    } catch (_) {
      return null;
    }
    final type = m['type'] as String?;
    if (type == 'response.output_text.delta') {
      return SseEvent(delta: m['delta'] is String ? m['delta'] as String : null);
    }
    if (type == 'response.completed') {
      final resp = m['response'];
      int? tIn;
      int? tOut;
      if (resp is Map && resp['usage'] is Map) {
        final u = resp['usage'] as Map;
        tIn = u['input_tokens'] is int ? u['input_tokens'] as int : null;
        tOut = u['output_tokens'] is int ? u['output_tokens'] as int : null;
      }
      return SseEvent(done: true, tokensIn: tIn, tokensOut: tOut);
    }
    if (type == 'error' || type == 'response.failed') {
      return const SseEvent(done: true);
    }
    return null;
  }
}

class AnthropicAdapter implements ProtocolAdapter {
  @override
  LlmProtocol get protocol => LlmProtocol.anthropic_messages;

  @override
  RequestSpec buildRequest({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String system,
    required String user,
    required bool jsonMode,
    required double temperature,
    required int maxTokens,
  }) {
    var base = baseUrl;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    final path = base.endsWith('/v1') ? '$base/messages' : '$base/v1/messages';
    return RequestSpec(
      path,
      {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      {
        'model': model,
        'system': system,
        'messages': [
          {'role': 'user', 'content': user},
        ],
        'stream': true,
        'temperature': temperature,
        'max_tokens': maxTokens,
      },
    );
  }

  @override
  SseEvent? parseFrame(String data) {
    final Map<String, Object?> m;
    try {
      m = jsonDecode(data) as Map<String, Object?>;
    } catch (_) {
      return null;
    }
    final type = m['type'] as String?;
    if (type == 'content_block_delta') {
      final d = m['delta'];
      if (d is Map) {
        if (d['type'] == 'thinking') {
          return SseEvent(reasoning: d['thinking'] is String ? d['thinking'] as String : null);
        }
        return SseEvent(delta: d['text'] is String ? d['text'] as String : null);
      }
      return null;
    }
    if (type == 'message_start') {
      final msg = m['message'];
      if (msg is Map && msg['usage'] is Map) {
        final u = msg['usage'] as Map;
        return SseEvent(
          tokensIn: u['input_tokens'] is int ? u['input_tokens'] as int : null,
        );
      }
      return null;
    }
    if (type == 'message_delta') {
      final u = m['usage'];
      return SseEvent(
        tokensOut: u is Map && u['output_tokens'] is int ? u['output_tokens'] as int : null,
      );
    }
    if (type == 'message_stop') return const SseEvent(done: true);
    return null;
  }
}

ProtocolAdapter adapterFor(LlmProtocol p) => switch (p) {
      LlmProtocol.openai_chat => OpenAiChatAdapter(),
      LlmProtocol.openai_responses => OpenAiResponsesAdapter(),
      LlmProtocol.anthropic_messages => AnthropicAdapter(),
    };
