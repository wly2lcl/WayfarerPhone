import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/engine_errors.dart';
import '../../core/ui/paper.dart';
import 'worlds_provider.dart';

/// 世界详情：基调介绍 + 进入开局 + 管理（导出/重命名/删除）
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
      appBar: AppBar(
        title: Text(world?.title ?? '世界详情'),
        actions: <Widget>[
          if (world != null)
            PopupMenuButton<String>(
              tooltip: '管理',
              onSelected: (action) => switch (action) {
                'export' => _export(context, ref),
                'rename' => _rename(context, ref, world),
                'delete' => _delete(context, ref, world),
                _ => null,
              },
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                if (world.exportable)
                  const PopupMenuItem(
                      value: 'export',
                      child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.ios_share_outlined),
                          title: Text('导出分享'))),
                const PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('重命名'))),
                const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline),
                        title: Text('删除'))),
              ],
            ),
        ],
      ),
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
                  child: Text('进入${world.title}',
                      style: TextStyle(fontSize: 16, letterSpacing: 4)),
                ),
              ],
            ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final engine = ref.read(engineProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final out = await engine.library.export(worldId);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(out.path, name: out.fileName)],
        title: out.fileName,
      ));
    } on EngineException catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('${engineCodeLabel(e.code)}：${e.message}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('分享失败：$e')));
    }
  }

  Future<void> _rename(
      BuildContext context, WidgetRef ref, WorldSummary world) async {
    final controller = TextEditingController(text: world.title);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名世界'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: '新名字'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    final name = controller.text.trim();
    if (ok != true || name.isEmpty || name == world.title) return;
    final engine = ref.read(engineProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await engine.library.rename(world.id, name);
      ref.invalidate(worldsProvider);
      messenger.showSnackBar(SnackBar(content: Text('已重命名为「$name」')));
    } on EngineException catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('${engineCodeLabel(e.code)}：${e.message}')));
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, WorldSummary world) async {
    final engine = ref.read(engineProvider);
    final runs = (await engine.listRuns()).where((r) => r.worldId == world.id).length;
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除世界'),
        content: Text(runs > 0
            ? '「${world.title}」下有 $runs 个存档，删除后将一并清除，不可恢复。确定删除？'
            : '确定删除「${world.title}」？此操作不可恢复。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final removed = await engine.library.delete(world.id);
      ref.invalidate(worldsProvider);
      messenger.showSnackBar(SnackBar(
          content: Text(removed > 0 ? '已删除世界与 $removed 个存档' : '已删除')));
      if (context.mounted) context.go('/');
    } on EngineException catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('${engineCodeLabel(e.code)}：${e.message}')));
    }
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
