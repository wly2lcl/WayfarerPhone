import 'dart:io';
import 'package:engine/engine.dart';

Future<void> main() async {
  final key = Platform.environment['LLM_KEY'] ?? '';
  final store = InMemoryKeyStore();
  await store.write(key);
  final gateway = ModelGateway(GatewayConfig(
    keyStore: store,
    settings: () => ModelSettings(
      protocol: LlmProtocol.openai_chat,
      baseUrl: 'https://apihub.agnes-ai.com/v1',
      narrativeModel: 'agnes-3.0-flash',
      smallModel: 'agnes-3.0-flash',
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
