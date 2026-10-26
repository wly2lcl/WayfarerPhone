import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/engine_errors.dart';
import '../../core/ui/paper.dart';
import 'workshop_provider.dart';

/// 世界工坊：草稿列表 + 两条创建入口（世界创造与导入 §1）
class WorkshopPage extends ConsumerWidget {
  const WorkshopPage({super.key});

  Future<void> _createDialogue(BuildContext context, WidgetRef ref) async {
    final engine = ref.read(engineProvider);
    try {
      final draft = await engine.drafts.create(DraftSource.dialogue);
      if (!context.mounted) return;
      ref.invalidate(draftsProvider);
      context.push('/workshop/create/${draft.id}');
    } on EngineException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${engineCodeLabel(e.code)}：${e.message}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(draftsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('世界工坊')),
      body: drafts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('$e'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(draftsProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          children: <Widget>[
            _EntryCard(
              icon: Icons.forum_outlined,
              title: '对话共创',
              desc: '一问一答八个字段，AI 帮你把灵感整理成可玩的世界',
              onTap: () => _createDialogue(context, ref),
            ),
            const SizedBox(height: 12),
            _EntryCard(
              icon: Icons.upload_file_outlined,
              title: '导入小说 TXT',
              desc: '把一本小说变成世界：抽取实体、生成圣经、审阅后开玩',
              onTap: () => context.push('/workshop/import'),
            ),
            const SizedBox(height: 22),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    '还没有草稿。从对话共创开始。',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.secondary),
                  ),
                ),
              )
            else
              PaperSectionLabel('我的草稿'),
            for (final d in list)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _DraftCard(draft: d),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;
    return PaperCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 28, color: sub),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(desc,
                    style: TextStyle(fontSize: 12, color: sub)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftCard extends ConsumerWidget {
  const _DraftCard({required this.draft});

  final DraftView draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;
    final route = draft.status == DraftStatus.draft
        ? '/workshop/create/${draft.id}'
        : '/workshop/edit/${draft.id}';
    return PaperCard(
      onTap: () => context.push(route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(draft.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              PaperBadge(label: draftStatusLabel(draft.status)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Text('完整度 ${draft.completeness}%',
                  style: TextStyle(fontSize: 12, color: sub)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: draft.completeness / 100,
                    minHeight: 4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Text(
                '${sourceLabel(draft.source)}'
                '${draft.worldId != null ? ' · 已入书架' : ''}'
                '${draft.issues.any((i) => i.level == 'error') ? ' · 有待修复问题' : ''}',
                style: TextStyle(fontSize: 12, color: sub),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _confirmDelete(context, ref),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child:
                      Icon(Icons.delete_outline, size: 18, color: sub),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final engine = ref.read(engineProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除草稿'),
        content: Text('「${draft.title}」及其访谈记录将一并删除，无法恢复。'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await engine.drafts.delete(draft.id);
      ref.invalidate(draftsProvider);
    } on EngineException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${engineCodeLabel(e.code)}：${e.message}')));
    }
  }
}
