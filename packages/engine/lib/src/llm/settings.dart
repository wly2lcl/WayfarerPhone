enum LlmProtocol { openai_chat, openai_responses, anthropic_messages }

enum GatewayRole { classifier, director, narrator, extractor, companion, compress }

extension GatewayRoleX on GatewayRole {
  bool get wantsNarrativeModel =>
      this == GatewayRole.narrator || this == GatewayRole.companion;
}

class ModelSettings {
  LlmProtocol protocol;
  String baseUrl;
  String narrativeModel;
  String smallModel;

  ModelSettings({
    required this.protocol,
    required this.baseUrl,
    required this.narrativeModel,
    required this.smallModel,
  });

  String modelFor(GatewayRole role) =>
      role.wantsNarrativeModel ? narrativeModel : smallModel;

  Map<String, Object?> toJson() => {
        'protocol': protocol.name,
        'baseUrl': baseUrl,
        'narrativeModel': narrativeModel,
        'smallModel': smallModel,
      };

  static ModelSettings fromJson(Object? j) {
    final m = j is Map ? j : const {};
    return ModelSettings(
      protocol: LlmProtocol.values.firstWhere(
        (p) => p.name == m['protocol'],
        orElse: () => LlmProtocol.openai_chat,
      ),
      baseUrl: (m['baseUrl'] as String?) ?? '',
      narrativeModel: (m['narrativeModel'] as String?) ?? '',
      smallModel: (m['smallModel'] as String?) ?? '',
    );
  }

  bool get configured => baseUrl.isNotEmpty && narrativeModel.isNotEmpty;
}

class Preset {
  final String id;
  final String label;
  final LlmProtocol protocol;
  final String baseUrl;
  final String narrativeModel;
  final String smallModel;

  const Preset({
    required this.id,
    required this.label,
    required this.protocol,
    required this.baseUrl,
    required this.narrativeModel,
    required this.smallModel,
  });
}

const kPresets = <Preset>[
  Preset(
    id: 'deepseek',
    label: 'DeepSeek',
    protocol: LlmProtocol.openai_chat,
    baseUrl: 'https://api.deepseek.com/v1',
    narrativeModel: 'deepseek-chat',
    smallModel: 'deepseek-chat',
  ),
  Preset(
    id: 'openai_responses',
    label: 'OpenAI（Responses）',
    protocol: LlmProtocol.openai_responses,
    baseUrl: 'https://api.openai.com/v1',
    narrativeModel: 'gpt-4.1',
    smallModel: 'gpt-4.1-mini',
  ),
  Preset(
    id: 'openai_chat',
    label: 'OpenAI（Chat Completions）',
    protocol: LlmProtocol.openai_chat,
    baseUrl: 'https://api.openai.com/v1',
    narrativeModel: 'gpt-4.1',
    smallModel: 'gpt-4.1-mini',
  ),
  Preset(
    id: 'agnes',
    label: 'Agnes（agnes-3.0-flash）',
    protocol: LlmProtocol.openai_chat,
    baseUrl: 'https://apihub.agnes-ai.com/v1',
    narrativeModel: 'agnes-3.0-flash',
    smallModel: 'agnes-3.0-flash',
  ),
  Preset(
    id: 'custom',
    label: '自定义',
    protocol: LlmProtocol.openai_chat,
    baseUrl: '',
    narrativeModel: '',
    smallModel: '',
  ),
];

/// Key 只经此接口进出安全存储（Keychain / Keystore），引擎不落盘
abstract class KeyStore {
  Future<String?> read();
  Future<void> write(String key);
  Future<void> clear();
}

class InMemoryKeyStore implements KeyStore {
  String? _key;
  @override
  Future<void> clear() async => _key = null;
  @override
  Future<String?> read() async => _key;
  @override
  Future<void> write(String key) async => _key = key;
}

class UsageRecord {
  final GatewayRole role;
  final String model;
  final int tokensIn;
  final int tokensOut;
  final bool estimated;
  final int ms;
  final bool ok;

  UsageRecord({
    required this.role,
    required this.model,
    required this.tokensIn,
    required this.tokensOut,
    required this.estimated,
    required this.ms,
    required this.ok,
  });
}

/// 优先用响应 usage；缺失按 中文1token≈1.5字 / 英文4字符≈1token 估算
int estimateTokens(String text) {
  var cjk = 0;
  var other = 0;
  for (final rune in text.runes) {
    if (rune >= 0x2E80 && rune <= 0x9FFF || rune >= 0x3400 && rune <= 0x4DBF) {
      cjk++;
    } else {
      other++;
    }
  }
  return (cjk / 1.5).ceil() + (other / 4).ceil();
}
