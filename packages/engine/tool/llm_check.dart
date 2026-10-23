import 'dart:io';
import 'package:engine/engine.dart';

/// 探活小工具：渠道由环境变量指定（LLM_KEY / LLM_BASE_URL / LLM_MODEL）
Future<void> main() async {
  final key = Platform.environment['LLM_KEY'] ?? '';
  final baseUrl = Platform.environment['LLM_BASE_URL'] ?? '';
  final model = Platform.environment['LLM_MODEL'] ?? '';
  if (key.isEmpty || baseUrl.isEmpty || model.isEmpty) {
    stderr.writeln('需要环境变量 LLM_KEY、LLM_BASE_URL、LLM_MODEL');
    exitCode = 2;
    return;
  }
  final store = InMemoryKeyStore();
  await store.write(key);
  final gateway = ModelGateway(GatewayConfig(
    keyStore: store,
    settings: () => ModelSettings(
      protocol: LlmProtocol.openai_chat,
      baseUrl: baseUrl,
      narrativeModel: model,
      smallModel: model,
    ),
  ));

  final report = await gateway.testConnection();
  print('testConnection ok=${report.ok} latency=${report.latencyMs}ms '
      'err=${report.errorCode?.wireName} msg=${report.message}');

  final sw = Stopwatch()..start();
  var chars = 0;
  await for (final delta in gateway.stream(GatewayRequest(
    role: GatewayRole.narrator,
    system: '你是文字冒险游戏的叙事者。第二人称，冷峻克制。',
    user: '写一段 50 字以内的开场：雨夜的药庐。',
    maxTokens: 200,
  ))) {
    chars += (delta as String).length;
  }
  print('stream done in ${sw.elapsedMilliseconds}ms, $chars chars');

  final r = await gateway.complete(GatewayRequest(
    role: GatewayRole.classifier,
    system: '只输出一个 JSON 对象：{"kind":"action|query|meta|rejected","intent":"..."}',
    user: '玩家输入：我去后山看看',
    jsonMode: true,
    maxTokens: 100,
  ));
  print('complete: ${r.text} (${r.ms}ms)');
}
