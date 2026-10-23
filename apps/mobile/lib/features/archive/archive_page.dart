import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/engine_errors.dart';
import '../../core/ui/paper.dart';

/// 人生档案：结局标题、盖棺定论、标签、关键选择
class ArchivePage extends ConsumerStatefulWidget {
  const ArchivePage({super.key, required this.runId});

  final String runId;

  @override
  ConsumerState<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends ConsumerState<ArchivePage> {
  late Future<Archive> _future;
  bool _branching = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(engineProvider).archive(widget.runId);
  }

  void _reload() {
    setState(() {
      _future = ref.read(engineProvider).archive(widget.runId);
    });
  }

  Future<void> _branchAndReplay() async {
    if (_branching) return;
    setState(() => _branching = true);
    final engine = ref.read(engineProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final view = await engine.getRun(widget.runId);
      final snapshotId = view.head.headSnapshotId;
      if (snapshotId == null) {
        messenger.showSnackBar(const SnackBar(content: Text('还没有可回溯的关键节点')));
        return;
      }
      final newRunId = await engine.branch(snapshotId: snapshotId);
      if (!mounted) return;
      context.pushReplacement('/play/$newRunId');
    } on EngineException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${engineCodeLabel(e.code)}：${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _branching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;
    return Scaffold(
      appBar: AppBar(title: const Text('人生档案')),
      body: FutureBuilder<Archive>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('载入失败：${snap.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  OutlinedButton(onPressed: _reload, child: const Text('重试')),
                ],
              ),
            );
          }
          final archive = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: <Widget>[
              Center(
                child: PaperBadge(label: '第 ${archive.turns} 回合 · 已盖棺'),
              ),
              const SizedBox(height: 18),
              Text(
                archive.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w600, height: 1.5),
              ),
              const SizedBox(height: 16),
              Text(
                archive.epitaph.isEmpty ? '这一程没有留下碑文。' : archive.epitaph,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.9),
              ),
              const SizedBox(height: 20),
              if (archive.tags.isNotEmpty)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final t in archive.tags)
                      if (t.isNotEmpty) PaperBadge(label: t),
                  ],
                ),
              const SizedBox(height: 28),
              PaperSectionLabel('关键选择'),
              const SizedBox(height: 10),
              if (archive.keyChoices.isEmpty)
                Text('还没有做出过选择。', style: TextStyle(fontSize: 13, color: sub))
              else
                PaperCard(
                  shadow: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (var i = 0; i < archive.keyChoices.length; i++) ...<Widget>[
                        Text(
                          '${i + 1}. ${archive.keyChoices[i]}',
                          style: const TextStyle(fontSize: 14, height: 1.8),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _branching ? null : _branchAndReplay,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text(_branching ? '正在回溯……' : '回到关键节点重开'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => context.go('/'),
                child: const Text('返回书架'),
              ),
            ],
          );
        },
      ),
    );
  }
}
