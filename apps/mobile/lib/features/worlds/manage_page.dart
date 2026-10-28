import 'package:engine/engine.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/engine_errors.dart';
import '../../core/ui/paper.dart';
import 'worlds_provider.dart';

/// 世界库占用空间（autoDispose：进页重新统计，离页释放）
final spaceProvider = FutureProvider.autoDispose<SpaceReport>(
    (ref) => ref.watch(engineProvider).library.space());

String _bytesLabel(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(2)} MB';
}

/// 世界库管理：占用空间 / 排序 / 导入 .world 包
class ManagePage extends ConsumerStatefulWidget {
  const ManagePage({super.key});

  @override
  ConsumerState<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends ConsumerState<ManagePage> {
  bool _bySize = false;
  bool _importing = false;

  Future<void> _importWorld() async {
    if (_importing) return;
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Wayfarer 世界包', extensions: ['world']),
      ],
    );
    if (file == null || !mounted) return;
    setState(() => _importing = true);
    final engine = ref.read(engineProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await engine.library.import(file.path);
      final what = switch (r.action) {
        'version_added' => '新增版本 v${r.version}',
        'saved_as_new' => '较低版本已另存为新世界',
        'skipped' => '本机已有相同版本，已跳过',
        'overwritten' => '已覆盖本机同版本',
        _ => '导入成功',
      };
      messenger.showSnackBar(SnackBar(
          content: Text('「${r.title}」$what（v${r.version}）')));
      ref.invalidate(worldsProvider);
      ref.invalidate(spaceProvider);
    } on EngineException catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('${engineCodeLabel(e.code)}：${e.message}')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;
    final space = ref.watch(spaceProvider);
    final worlds = ref.watch(worldsProvider).value ?? const <WorldSummary>[];

    return Scaffold(
      appBar: AppBar(title: const Text('世界库管理')),
      body: space.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('载入失败：$e')),
        data: (report) {
          final titleOf = <String, String>{
            for (final w in worlds) w.id: w.title,
          };
          final entries = [...report.worlds]..sort((a, b) {
              int byTitle(String id) =>
                  (titleOf[id] ?? id).codeUnitAt(0);
              return _bySize
                  ? b.bytes.compareTo(a.bytes)
                  : byTitle(a.worldId).compareTo(byTitle(b.worldId));
            });
          final total =
              report.worlds.fold<int>(0, (s, e) => s + e.bytes) +
                  report.importsBytes;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('共 ${entries.length} 个世界 · 占用 ${_bytesLabel(total)}',
                      style: TextStyle(fontSize: 12, color: sub)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _bySize = !_bySize),
                    icon: Icon(_bySize
                        ? Icons.sort
                        : Icons.sort_by_alpha_outlined,
                        size: 18),
                    label: Text(_bySize ? '按空间' : '按名称',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PaperCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    onTap: () => context.push('/world/${e.worldId}'),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            titleOf[e.worldId] ?? e.worldId,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_bytesLabel(e.bytes),
                            style: TextStyle(fontSize: 12, color: sub)),
                      ],
                    ),
                  ),
                ),
              if (report.importsBytes > 0) ...<Widget>[
                const SizedBox(height: 8),
                PaperCard(
                  shadow: false,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text('导入原文缓存（小说 TXT，不可导出）',
                            style: TextStyle(fontSize: 13, color: sub)),
                      ),
                      Text(_bytesLabel(report.importsBytes),
                          style: TextStyle(fontSize: 12, color: sub)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _importing ? null : _importWorld,
                icon: _importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.file_download_outlined, size: 18),
                label: Text(_importing ? '正在导入……' : '导入 .world 世界包'),
              ),
              const SizedBox(height: 10),
              Text(
                '把朋友分享的 .world 文件导入后即可试玩；再导出时保留原作者声明，小说导入的世界不可导出。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.7, color: sub),
              ),
            ],
          );
        },
      ),
    );
  }
}
