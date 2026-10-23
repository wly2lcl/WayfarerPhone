import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/paper.dart';
import 'worlds_provider.dart';

/// 世界详情：基调介绍 + 「进入苍梧」
class WorldDetailPage extends ConsumerWidget {
  const WorldDetailPage({super.key, required this.worldId});

  final String worldId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worlds = ref.watch(worldsProvider);
    final world = worlds.value == null ? null : worldById(worlds.value!, worldId);
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(title: Text(world?.title ?? '世界详情')),
      body: world == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    PaperBadge(label: genreLabel(world.genre)),
                    const SizedBox(width: 8),
                    PaperBadge(label: world.source == 'builtin' ? '内置世界' : world.source),
                    const Spacer(),
                    PaperBadge(label: 'AI 生成'),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  world.title,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, height: 1.4),
                ),
                const SizedBox(height: 14),
                Text(
                  world.summary.isEmpty ? '这个世界还没有留下介绍。' : world.summary,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.9),
                ),
                const SizedBox(height: 26),
                PaperCard(
                  shadow: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _metaRow('版本', 'v${world.version}'),
                      const SizedBox(height: 8),
                      _metaRow('身份池', '${world.identityCount} 种身份'),
                      const SizedBox(height: 8),
                      _metaRow('来源', world.source == 'builtin' ? '内置' : world.source),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: theme.dividerColor),
                      const SizedBox(height: 12),
                      Text(
                        '故事由 AI 叙事生成，只发生在这台手机上。',
                        style: TextStyle(fontSize: 12, color: sub),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => context.push('/draw/${world.id}'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('进入苍梧', style: TextStyle(fontSize: 16, letterSpacing: 4)),
                ),
              ],
            ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Builder(
      builder: (context) {
        final sub = Theme.of(context).colorScheme.secondary;
        return Row(
          children: <Widget>[
            SizedBox(
              width: 64,
              child: Text(label, style: TextStyle(fontSize: 13, color: sub)),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
          ],
        );
      },
    );
  }
}
