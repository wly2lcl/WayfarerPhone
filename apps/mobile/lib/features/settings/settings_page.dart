import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/engine_errors.dart';
import '../../core/security/secure_key_store.dart';
import '../../core/ui/paper.dart';

/// 设置页：预设 / 协议 / baseUrl / Key / 两个模型 / 测试连接 / 夜读模式
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _narrativeModel;
  late final TextEditingController _smallModel;
  late final TextEditingController _price;
  final TextEditingController _key = TextEditingController();

  late LlmProtocol _protocol;
  late String _presetId;
  bool _keySaved = false;
  bool _saving = false;
  bool _testing = false;
  String? _testResult;
  UsageStats? _stats;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(engineProvider).modelSettings;
    _protocol = settings.protocol;
    _baseUrl = TextEditingController(text: settings.baseUrl);
    _narrativeModel = TextEditingController(text: settings.narrativeModel);
    _smallModel = TextEditingController(text: settings.smallModel);
    _price = TextEditingController(
        text: settings.pricePerMillion > 0
            ? settings.pricePerMillion.toString()
            : '');
    _presetId = _matchPreset(settings).id;
    _loadKeyState();
    _loadStats();
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _narrativeModel.dispose();
    _smallModel.dispose();
    _price.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final st = await ref.read(engineProvider).usageStats();
      if (!mounted) return;
      setState(() => _stats = st);
    } catch (_) {
      // 统计仅展示用，失败不打扰
    }
  }

  Future<void> _loadKeyState() async {
    final has = await SecureKeyStore().read() != null;
    if (!mounted) return;
    setState(() => _keySaved = has);
  }

  Preset _matchPreset(ModelSettings s) {
    for (final p in kPresets) {
      if (p.id != 'custom' &&
          p.protocol == s.protocol &&
          p.baseUrl == s.baseUrl &&
          p.narrativeModel == s.narrativeModel &&
          p.smallModel == s.smallModel) {
        return p;
      }
    }
    return kPresets.last; // custom
  }

  void _applyPreset(Preset p) {
    setState(() {
      _presetId = p.id;
      _protocol = p.protocol;
      _baseUrl.text = p.baseUrl;
      _narrativeModel.text = p.narrativeModel;
      _smallModel.text = p.smallModel;
    });
  }

  ModelSettings _settingsFromFields() => ModelSettings(
        protocol: _protocol,
        baseUrl: _baseUrl.text.trim(),
        narrativeModel: _narrativeModel.text.trim(),
        smallModel: _smallModel.text.trim(),
        pricePerMillion: double.tryParse(_price.text.trim()) ?? 0,
      );

  Future<void> _persist() async {
    final engine = ref.read(engineProvider);
    await engine.saveModelSettings(_settingsFromFields());
    final key = _key.text.trim();
    if (key.isNotEmpty) {
      await SecureKeyStore().write(key);
      if (!mounted) return;
      setState(() {
        _key.clear();
        _keySaved = true;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _testResult = null;
    });
    try {
      await _persist();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 先落盘当前填写内容，再让引擎用这套配置发一次探活请求
  Future<void> _test() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      await _persist();
      final report = await ref.read(engineProvider).testConnection();
      if (!mounted) return;
      setState(() {
        _testResult = report.ok
            ? '连接成功 · ${report.latencyMs ?? '-'}ms'
                '${report.model == null ? '' : ' · ${report.model}'}'
            : '连接失败 · '
                '${report.errorCode == null ? '' : '${engineCodeLabel(report.errorCode!)}：'}'
                '${report.message ?? '未知错误'}';
      });
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() {
        _testResult =
            '连接失败 · ${engineCodeLabel(e.code)}：${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _testResult = '连接失败：$e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _clearKey() async {
    await SecureKeyStore().clear();
    if (!mounted) return;
    setState(() {
      _key.clear();
      _keySaved = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已清除本机密钥')));
  }

  /// 用量统计区（工程与开发计划 §9）：近 30 天请求、首字分位、单回合 token、估算花费
  Widget _buildUsageSection(ThemeData theme, Color sub) {
    final st = _stats;
    final price = double.tryParse(_price.text.trim()) ?? 0;
    String? cost;
    if (st != null && price > 0) {
      final total = (st.tokensIn + st.tokensOut) / 1000000 * price;
      cost = '¥${total.toStringAsFixed(2)}';
    }
    String ms(int? v) => v == null ? '—' : '${(v / 1000).toStringAsFixed(1)}s';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PaperSectionLabel('用量（近 30 天）'),
        const SizedBox(height: 8),
        if (st == null)
          Text('暂无数据', style: TextStyle(fontSize: 12, color: sub))
        else ...<Widget>[
          Text(
            '请求 ${st.requests} 次'
            '${st.failures > 0 ? '（失败 ${st.failures}）' : ''}'
            ' · 推进回合 ${st.turns} 个',
            style: TextStyle(fontSize: 13, color: sub),
          ),
          const SizedBox(height: 4),
          Text(
            '首字 p50 ${ms(st.p50Ms)} · p95 ${ms(st.p95Ms)}',
            style: TextStyle(fontSize: 13, color: sub),
          ),
          const SizedBox(height: 4),
          Text(
            '单回合平均 ${st.avgTokensPerTurn} token'
            ' · 合计输入 ${st.tokensIn} / 输出 ${st.tokensOut} token',
            style: TextStyle(fontSize: 13, color: sub),
          ),
          if (cost != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '估算花费 $cost（按 ${_price.text.trim()} 元/百万 token）',
              style: TextStyle(fontSize: 13, color: sub),
            ),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('夜读模式', style: TextStyle(fontSize: 15)),
            subtitle: Text('暖黑底、暖黄字，适合夜里阅读。',
                style: TextStyle(fontSize: 12, color: sub)),
            value: ref.watch(nightModeProvider),
            onChanged: (v) => ref.read(nightModeProvider.notifier).state = v,
          ),
          const SizedBox(height: 18),
          PaperSectionLabel('供应商预设'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _presetId,
            isExpanded: true,
            decoration: paperInputDecoration(context, '预设'),
            items: <DropdownMenuItem<String>>[
              for (final p in kPresets)
                DropdownMenuItem<String>(value: p.id, child: Text(p.label)),
            ],
            onChanged: (id) {
              if (id == null) return;
              for (final p in kPresets) {
                if (p.id == id) {
                  _applyPreset(p);
                  return;
                }
              }
            },
          ),
          const SizedBox(height: 18),
          PaperSectionLabel('协议'),
          const SizedBox(height: 8),
          SegmentedButton<LlmProtocol>(
            selected: <LlmProtocol>{_protocol},
            onSelectionChanged: (set) =>
                setState(() => _protocol = set.first),
            showSelectedIcon: false,
            segments: const <ButtonSegment<LlmProtocol>>[
              ButtonSegment<LlmProtocol>(
                  value: LlmProtocol.openai_chat, label: Text('Chat')),
              ButtonSegment<LlmProtocol>(
                  value: LlmProtocol.openai_responses,
                  label: Text('Responses')),
              ButtonSegment<LlmProtocol>(
                  value: LlmProtocol.anthropic_messages,
                  label: Text('Anthropic')),
            ],
          ),
          const SizedBox(height: 4),
          Text('决定请求格式，需与你的服务商一致。',
              style: TextStyle(fontSize: 12, color: sub)),
          const SizedBox(height: 18),
          PaperSectionLabel('服务地址'),
          const SizedBox(height: 8),
          TextField(
            controller: _baseUrl,
            keyboardType: TextInputType.url,
            style: const TextStyle(fontSize: 14),
            decoration:
                paperInputDecoration(context, 'baseUrl', hint: 'https://…/v1'),
          ),
          const SizedBox(height: 18),
          PaperSectionLabel('API Key'),
          const SizedBox(height: 8),
          TextField(
            controller: _key,
            obscureText: true,
            style: const TextStyle(fontSize: 14),
            decoration: paperInputDecoration(
              context,
              '密文，只存进系统安全区',
              hint: _keySaved ? '已保存（留空则不修改）' : 'sk-…',
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _keySaved ? _clearKey : null,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('清除 Key'),
            ),
          ),
          const SizedBox(height: 10),
          PaperSectionLabel('模型'),
          const SizedBox(height: 8),
          TextField(
            controller: _narrativeModel,
            style: const TextStyle(fontSize: 14),
            decoration: paperInputDecoration(context, '叙事模型',
                hint: '正文与助手用，如 deepseek-chat'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _smallModel,
            style: const TextStyle(fontSize: 14),
            decoration: paperInputDecoration(context, '小模型',
                hint: '分类、导演与抽取用'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 14),
            decoration: paperInputDecoration(context, '单价（元 / 百万 token）',
                hint: '用于估算花费，留空则不显示'),
          ),
          const SizedBox(height: 24),
          _buildUsageSection(theme, sub),
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '正在保存……' : '保存'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _test,
                  child: Text(_testing ? '测试中……' : '测试连接'),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              _testResult!,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color:
                    _testResult!.startsWith('连接成功') ? sub : theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
