import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/paper.dart';
import 'worlds_provider.dart';

/// 世界库（书架）：列出 engine.listWorlds()
class WorldsPage extends ConsumerWidget {
  const WorldsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worlds = ref.watch(worldsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('书架'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.handyman_outlined),
            tooltip: '世界工坊',
            onPressed: () => context.push('/workshop'),
          ),
          IconButton(
            icon: const Icon(Icons.local_library_outlined),
            tooltip: '我的局',
            onPressed: () => context.push('/library'),
          ),
          IconButton(
            icon: const Icon(Icons.folder_special_outlined),
            tooltip: '世界库管理',
            onPressed: () => context.push('/manage'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: worlds.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _LoadError(
          message: '$e',
          onRetry: () => ref.invalidate(worldsProvider),
        ),
        data: (list) => list.isEmpty
            ? const _EmptyShelf()
            : RefreshIndicator(
                onRefresh: () => ref.refresh(worldsProvider.future),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  itemCount: list.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _WorldCard(world: list[i]),
                  ),
                ),
              ),
      ),
    );
  }
}

/// 新用户第一屏（B7）：书架空态引导——去工坊开世界 / 导入世界包
class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.auto_stories_outlined,
              size: 48,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              '书架还是空的',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '去工坊用一句话开启一个世界，\n或导入别人分享的世界包。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.7, color: sub),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => context.push('/workshop'),
              icon: const Icon(Icons.handyman_outlined, size: 18),
              label: const Text('去工坊开世界'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push('/manage'),
              icon: const Icon(Icons.folder_special_outlined, size: 18),
              label: const Text('导入世界包'),
            ),
            const SizedBox(height: 18),
            Text(
              '下拉刷新书架',
              style: TextStyle(fontSize: 12, color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({required this.world});

  final WorldSummary world;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;
    return PaperCard(
      onTap: () => context.push('/world/${world.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  world.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PaperBadge(label: genreLabel(world.genre)),
            ],
          ),
          if (world.summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              world.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, height: 1.6, color: sub),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Text(
                '版本 v${world.version} · ${world.identityCount} 种身份',
                style: TextStyle(fontSize: 12, color: sub),
              ),
              const Spacer(),
              if (world.source == 'builtin') const PaperBadge(label: '内置'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).colorScheme.secondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('载入失败'),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: sub),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
