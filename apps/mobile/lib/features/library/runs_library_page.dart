import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/ui/paper.dart';
import '../worlds/worlds_provider.dart';

/// 「我的局」：本地局列表，可继续游玩或查看人生档案
final runsLibraryProvider =
    FutureProvider((ref) => ref.watch(engineProvider).listRuns());

class RunsLibraryPage extends ConsumerWidget {
  const RunsLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(runsLibraryProvider);
    final worlds = ref.watch(worldsProvider).value ?? const <WorldSummary>[];

    String worldTitle(String id) {
      for (final w in worlds) {
        if (w.id == id) return w.title;
      }
      return id;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('我的局')),
      body: runs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('载入失败：$e', textAlign: TextAlign.center),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => ref.invalidate(runsLibraryProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (list) => list.isEmpty
            ? Center(
                child: Text(
                  '还没有开始过一局。\n去书架选一个世界，抽一张身份吧。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.8,
                      color: Theme.of(context).colorScheme.secondary),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final run = list[i];
                  final ended = run.status == 'ended';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PaperCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        worldTitle(run.worldId),
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    PaperBadge(
                                      label: ended ? '已落幕' : '进行中',
                                      color: ended
                                          ? Theme.of(context)
                                              .colorScheme
                                              .secondary
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '第${run.chapter}卷 · 第${run.turnNo}回合 · v${run.worldVersion} 世界',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary),
                                ),
                              ],
                            ),
                          ),
                          if (!ended)
                            TextButton(
                              onPressed: () => context.push('/play/${run.id}'),
                              child: const Text('继续'),
                            ),
                          TextButton(
                            onPressed: () =>
                                context.push('/archive/${run.id}'),
                            child: const Text('档案'),
                          ),
                          if (ended)
                            TextButton(
                              onPressed: () => context.push('/play/${run.id}'),
                              child: const Text('进入'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
