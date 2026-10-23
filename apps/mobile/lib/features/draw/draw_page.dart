import 'package:contracts/contracts.dart';
import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/engine_errors.dart';
import '../../core/ui/paper.dart';
import '../play/play_controller.dart';

/// 身份抽取页：engine.draw 出 3 张卡，选中一张创建新局。
class DrawPage extends ConsumerStatefulWidget {
  const DrawPage({super.key, required this.worldId});

  final String worldId;

  @override
  ConsumerState<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends ConsumerState<DrawPage> {
  DrawResult? _result;
  int _selected = -1;
  bool _loading = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redraw());
  }

  Future<void> _redraw() async {
    setState(() {
      _loading = true;
      _error = null;
      _selected = -1;
    });
    try {
      final result = await ref.read(engineProvider).draw(widget.worldId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${engineCodeLabel(e.code)}：${e.message}';
      });
    }
  }

  Future<void> _start(Identity identity) async {
    if (_creating || _result == null) return;
    setState(() => _creating = true);
    final engine = ref.read(engineProvider);
    try {
      final start = await engine.create(
        worldId: widget.worldId,
        identityId: identity.id,
        drawToken: _result!.drawToken,
      );
      if (!mounted) return;
      pendingStarts[start.runId] = start;
      context.pushReplacement('/play/${start.runId}');
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      final messenger = ScaffoldMessenger.of(context);
      if (e.code == EngineCode.modelNotConfigured) {
        messenger.showSnackBar(
          const SnackBar(content: Text('先到设置页配置模型，才能开始新的一生')),
        );
        context.push('/settings');
      } else if (e.code == EngineCode.notFound) {
        // 抽取令牌过期等：给出原因并自动换一批
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
        _redraw();
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('${engineCodeLabel(e.code)}：${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canStart = !_loading && !_creating && _result != null && _selected >= 0;

    return Scaffold(
      appBar: AppBar(title: const Text('身份抽取')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14, left: 4),
                        child: Text(
                          '命运抽出三张牌，选一张开始这一生。',
                          style: TextStyle(
                              fontSize: 13, color: theme.colorScheme.secondary),
                        ),
                      ),
                      if (_error != null) ...<Widget>[
                        PaperCard(
                          borderColor: theme.colorScheme.primary,
                          child: Text(_error!,
                              style: TextStyle(
                                  fontSize: 13, color: theme.colorScheme.primary)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      for (final entry in _cards()) ...<Widget>[
                        entry,
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading || _creating ? null : _redraw,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('换一批'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          canStart ? () => _start(_result!.identities[_selected]) : null,
                      child: Text(_creating ? '正在开始……' : '以此身份开始'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _cards() {
    final result = _result;
    if (result == null) return const <Widget>[];
    final context = this.context;
    final theme = Theme.of(context);
    final night = theme.brightness == Brightness.dark;
    final widgets = <Widget>[];
    for (var i = 0; i < result.identities.length; i++) {
      final identity = result.identities[i];
      final selected = _selected == i;
      final rc = rarityColor(identity.rarity, night: night);
      widgets.add(
        PaperCard(
          onTap: () => setState(() => _selected = i),
          borderColor: selected ? rc : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  PaperBadge(
                    label: _rarityLabel(identity.rarity),
                    color: rc,
                    textColor: rc,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      identity.name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '难度 ${'★' * identity.difficulty}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(context, '处境', identity.situation),
              const SizedBox(height: 8),
              _field(context, '目标', identity.goal),
              if (identity.shackles.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                _field(context, '枷锁', identity.shackles.join('；')),
              ],
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _field(BuildContext context, String label, String value) {
    final sub = Theme.of(context).colorScheme.secondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: sub, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 14, height: 1.6)),
        ),
      ],
    );
  }

  String _rarityLabel(Rarity rarity) => switch (rarity) {
        Rarity.common => '凡品',
        Rarity.rare => '稀有',
        Rarity.unique => '孤品',
      };
}
