import 'package:engine/engine.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/engine_errors.dart';
import '../../core/ui/paper.dart';
import '../worlds/worlds_provider.dart';

/// 「我的局」：本地局列表，可继续游玩、查看人生档案、导出/导入存档包
/// autoDispose：分叉/新开局后重进页面时重新查询，避免旧列表缓存
final runsLibraryProvider =
    FutureProvider.autoDispose((ref) => ref.watch(engineProvider).listRuns());

class RunsLibraryPage extends ConsumerStatefulWidget {
  const RunsLibraryPage({super.key});

  @override
  ConsumerState<RunsLibraryPage> createState() => _RunsLibraryPageState();
}

class _RunsLibraryPageState extends ConsumerState<RunsLibraryPage> {
  bool _importing = false;

  Future<void> _exportRun(RunHead run) async {
    final engine = ref.read(engineProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final out = await engine.exportRunPack(run.id);
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

  Future<void> _importRun() async {
    if (_importing) return;
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Wayfarer 存档包', extensions: ['run']),
      ],
    );
    if (file == null || !mounted) return;
    setState(() => _importing = true);
    final engine = ref.read(engineProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await engine.importRunPack(file.path);
      messenger.showSnackBar(SnackBar(
          content: Text(r.renamed
              ? '导入成功（本机已有同编号存档，已保存为 ${r.runId}）'
              : '导入成功')));
      ref.invalidate(runsLibraryProvider);
    } on EngineException catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('${engineCodeLabel(e.code)}：${e.message}')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final runs = ref.watch(runsLibraryProvider);
    final worlds = ref.watch(worldsProvider).value ?? const <WorldSummary>[];

    String worldTitle(String id) {
      for (final w in worlds) {
        if (w.id == id) return w.title;
      }
      return id;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的局'),
        actions: <Widget>[
          IconButton(
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_download_outlined),
            tooltip: '导入存档包',
            onPressed: _importing ? null : _importRun,
          ),
        ],
      ),
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
                                  '${run.endingTitle != null ? '${run.endingTitle} · ' : ''}'
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
                          if (!run.isTrial && run.exportable)
                            TextButton(
                              onPressed: () => _exportRun(run),
                              child: const Text('导出'),
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
