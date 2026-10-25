import 'package:contracts/contracts.dart';
import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/engine_errors.dart';
import '../../core/ui/paper.dart';
import '../play/play_controller.dart' show pendingStarts;
import '../worlds/worlds_provider.dart' show worldsProvider;
import 'workshop_provider.dart';

/// 编辑器页：质量检查 + 可编辑字段 + 试玩/丢弃/冻结（世界创造与导入 §5）
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key, required this.draftId});

  final String draftId;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  DraftDetail? _detail;
  WorldBible? _bible;
  bool _busy = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(engineProvider).drafts.detail(widget.draftId);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _bible = d.bible;
        _error = null;
      });
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() => _error = '${engineCodeLabel(e.code)}：${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '操作失败：$e');
    }
  }

  Future<void> _save() async {
    final bible = _bible;
    if (bible == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(engineProvider).drafts.save(widget.draftId, bible: bible);
      if (!mounted) return;
      setState(() => _dirty = false);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存，质量检查已重算')));
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() => _error = '${engineCodeLabel(e.code)}：${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mutateBible(void Function(WorldBible bible) mutate) async {
    final bible = _bible;
    if (bible == null) return;
    mutate(bible);
    setState(() => _dirty = true);
    await _save();
  }

  Future<void> _trial() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(engineProvider).drafts.trial(widget.draftId);
      if (!mounted) return;
      ref.invalidate(draftsProvider);
      pendingStarts[r.runId] = r;
      await context.push('/play/${r.runId}');
      await _load();
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() => _error = '${engineCodeLabel(e.code)}：${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discardTrial() async {
    final ok = await _confirm(context, '丢弃试玩？', '该草稿的试玩局与事件记录将被删除，草稿回到待审阅。');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(engineProvider).drafts.discardTrial(widget.draftId);
      if (!mounted) return;
      ref.invalidate(draftsProvider);
      await _load();
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() => _error = '${engineCodeLabel(e.code)}：${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _freeze() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(engineProvider).drafts.freeze(widget.draftId);
      if (!mounted) return;
      ref.invalidate(draftsProvider);
      ref.invalidate(worldsProvider);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已入书架：${r.worldId} 第 ${r.version} 版')));
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() => _error = '${engineCodeLabel(e.code)}：${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await _confirm(context, '删除草稿？', '草稿及其全部访谈记录将被删除，试玩局一并清理。');
    if (!ok) return;
    try {
      await ref.read(engineProvider).drafts.delete(widget.draftId);
      if (!mounted) return;
      ref.invalidate(draftsProvider);
      context.pop();
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() => _error = '${engineCodeLabel(e.code)}：${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '操作失败：$e');
    }
  }

  Future<void> _editText(String title, String initial,
      void Function(String) apply, {int maxLines = 1}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: maxLines,
          decoration: paperInputDecoration(context, '输入$title'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => context.pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () => context.pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty || result == initial) return;
    await _mutateBible((b) => apply(result));
  }

  Future<void> _editList(
      String title, List<String> items, void Function(List<String>) apply) async {
    final controllers = [
      for (final s in items) TextEditingController(text: s),
    ];
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (var i = 0; i < controllers.length; i++)
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: controllers[i],
                          decoration:
                              paperInputDecoration(context, '第 ${i + 1} 项'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        tooltip: '删除该项',
                        onPressed: () => setDialogState(() {
                          controllers[i].dispose();
                          controllers.removeAt(i);
                        }),
                      ),
                    ],
                  ),
                TextButton.icon(
                  onPressed: () =>
                      setDialogState(() => controllers.add(TextEditingController())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加一项'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => context.pop(), child: const Text('取消')),
            FilledButton(
              onPressed: () => context.pop(
                  controllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList()),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    for (final c in controllers) {
      c.dispose();
    }
    if (result == null) return;
    final same = result.length == items.length &&
        List.generate(result.length, (i) => result[i] == items[i]).every((e) => e);
    if (same) return;
    await _mutateBible((b) => apply(result));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;
    final detail = _detail;
    final bible = _bible;

    return Scaffold(
      appBar: AppBar(
        title: Text(bible?.meta.title ?? detail?.view.title ?? '世界编辑器'),
        actions: <Widget>[
          if (detail != null && detail.view.status != DraftStatus.generating)
            IconButton(
              icon: _dirty
                  ? const Icon(Icons.save)
                  : const Icon(Icons.save_outlined),
              tooltip: '保存',
              onPressed: _busy ? null : _save,
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除草稿',
            onPressed: _busy ? null : _delete,
          ),
        ],
      ),
      body: detail == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: sub)),
                    ),
            )
          : _Body(
              state: this,
              detail: detail,
              bible: bible,
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.detail, required this.bible});

  final _EditorPageState state;
  final DraftDetail detail;
  final WorldBible? bible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;
    final view = detail.view;
    final b = bible;
    final isGenerating = view.status == DraftStatus.generating;
    final factionNames = b == null
        ? const <String, String>{}
        : {for (final f in b.factions) f.id: f.name};

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            PaperBadge(label: draftStatusLabel(view.status)),
            PaperBadge(label: sourceLabel(view.source)),
            if (!view.exportable) const PaperBadge(label: '不可导出'),
            if (view.worldId != null) const PaperBadge(label: '已入书架'),
          ],
        ),
        const SizedBox(height: 14),

        // 八字段完整度（含 AI 代填标注）
        PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Text('访谈完整度',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${view.completeness}%',
                      style: TextStyle(fontSize: 13, color: sub)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: view.completeness / 100,
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: <Widget>[
                  for (final e in view.fields.entries)
                    _FieldChip(
                      label: e.key.label,
                      score: e.value.score,
                      filledByAI: e.value.filledByAI,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 质量检查
        if (view.qualityScore > 0 || view.issues.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _QualityCard(
                score: view.qualityScore, issues: view.issues),
          ),

        if (b == null)
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('尚未生成世界内容'),
                const SizedBox(height: 6),
                Text('先在创作对话里补足访谈，再生成世界圣经。',
                    style: TextStyle(fontSize: 13, color: sub)),
                if (view.status == DraftStatus.draft ||
                    view.status == DraftStatus.generating) ...<Widget>[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: state._busy
                        ? null
                        : () => context.push('/workshop/create/${view.id}'),
                    child: Text(view.status == DraftStatus.generating
                        ? '重新生成'
                        : '继续访谈'),
                  ),
                ],
              ],
            ),
          )
        else ...<Widget>[
          // 基本信息
          _SectionCard(
            title: '基本信息',
            children: <Widget>[
              _EditRow(
                label: '标题',
                value: b.meta.title,
                onTap: () => state._editText(
                    '标题', b.meta.title, (v) => b.meta.title = v),
              ),
              _EditRow(
                label: '简介',
                value: b.meta.summary,
                onTap: () => state._editText(
                    '简介', b.meta.summary, (v) => b.meta.summary = v,
                    maxLines: 3),
              ),
              _EditRow(
                label: '基调词',
                value: b.meta.tone,
                onTap: () => state._editList(
                  '基调词',
                  b.meta.tone
                      .split(RegExp('[、,，]'))
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList(),
                  (list) => b.meta.tone = list.join('、'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 禁忌与代价
          _SectionCard(
            title: '禁忌与代价',
            children: <Widget>[
              _EditRow(
                label: '禁忌（${b.taboos.length}）',
                value: b.taboos.join('；'),
                maxLines: 2,
                onTap: () => state._editList(
                    '禁忌', b.taboos, (list) => b.taboos..clear()..addAll(list)),
              ),
              _EditRow(
                label: '力量代价（${b.powerSystem.costs.length}）',
                value: b.powerSystem.costs.join('；'),
                maxLines: 2,
                onTap: () => state._editList('力量代价', b.powerSystem.costs,
                    (list) => b.powerSystem.costs..clear()..addAll(list)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 只读区：地区 / 势力 / NPC / 身份
          _SectionCard(
            title: '地区与势力（只读）',
            children: <Widget>[
              for (final r in b.regions)
                _ReadRow(
                    title: r.name, sub: '危险度 ${r.danger} · ${r.summary}'),
              for (final f in b.factions)
                _ReadRow(title: f.name, sub: f.goal),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'NPC 池（只读，${b.npcPool.length}）',
            children: <Widget>[
              for (final n in b.npcPool)
                _ReadRow(
                    title: n.name,
                    sub: '${n.role} · ${factionNames[n.factionId] ?? '散人'}'),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '身份池（只读，${detail.identities.length}）',
            children: <Widget>[
              for (final i in detail.identities)
                _ReadRow(
                    title: '${i.name} · ${rarityLabel(i.rarity.name)}',
                    sub: i.situation),
            ],
          ),
        ],

        const SizedBox(height: 20),
        if (_qualityFailed(view)) ...<Widget>[
          Text('一致性检查存在错误，修复后才能试玩或冻结。',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.error)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: state._busy
                ? null
                : () => context.push('/workshop/create/${view.id}'),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重新生成'),
          ),
          const SizedBox(height: 10),
        ],
        if (isGenerating)
          const Center(child: CircularProgressIndicator())
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                onPressed: state._busy || _qualityFailed(view)
                    ? null
                    : state._trial,
                icon: const Icon(Icons.play_arrow_outlined, size: 18),
                label: const Text('试玩'),
              ),
              if (view.status == DraftStatus.trial)
                OutlinedButton.icon(
                  onPressed: state._busy ? null : state._discardTrial,
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('丢弃试玩'),
                ),
              FilledButton.tonalIcon(
                onPressed: state._busy || _qualityFailed(view)
                    ? null
                    : state._freeze,
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text(view.worldId == null ? '冻结入书架' : '冻结新版本'),
              ),
            ],
          ),
        if (state._error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(state._error!,
              style:
                  TextStyle(fontSize: 12, color: theme.colorScheme.error)),
        ],
      ],
    );
  }

  bool _qualityFailed(DraftView view) =>
      view.issues.any((i) => i.level == 'error');
}

class _FieldChip extends StatelessWidget {
  const _FieldChip(
      {required this.label, required this.score, required this.filledByAI});

  final String label;
  final int score;
  final bool filledByAI;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = score >= 70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: ok ? theme.dividerColor : theme.colorScheme.error),
      ),
      child: Text(
        '${filledByAI ? 'AI·' : ''}$label $score',
        style: TextStyle(
            fontSize: 11,
            color: ok ? null : theme.colorScheme.error),
      ),
    );
  }
}

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.score, required this.issues});

  final int score;
  final List<({String level, String code, String field, String message})> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('质量检查',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$score 分',
                  style: TextStyle(
                      fontSize: 13,
                      color: score >= 70 ? sub : theme.colorScheme.error)),
            ],
          ),
          if (issues.isEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text('六项一致性检查全部通过。', style: TextStyle(fontSize: 12, color: sub)),
          ] else ...<Widget>[
            const SizedBox(height: 10),
            for (final i in issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      i.level == 'error'
                          ? Icons.error_outline
                          : Icons.warning_amber_outlined,
                      size: 16,
                      color: i.level == 'error'
                          ? theme.colorScheme.error
                          : theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${i.message}（${i.code}）',
                          style: const TextStyle(fontSize: 12, height: 1.5)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow(
      {required this.label, required this.value, required this.onTap,
      this.maxLines = 1});

  final String label;
  final String value;
  final VoidCallback onTap;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 118,
              child: Text(label,
                  style: TextStyle(fontSize: 12, color: sub)),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '（空，点击填写）' : value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: value.isEmpty ? sub : null),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: sub),
          ],
        ),
      ),
    );
  }
}

class _ReadRow extends StatelessWidget {
  const _ReadRow({required this.title, required this.sub});

  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 13)),
          Text(this.sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, height: 1.4, color: sub)),
        ],
      ),
    );
  }
}

String rarityLabel(String name) => switch (name) {
      'common' => '普通',
      'rare' => '稀有',
      'unique' => '独有',
      _ => name,
    };

Future<bool> _confirm(BuildContext context, String title, String body) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: <Widget>[
        TextButton(onPressed: () => context.pop(false), child: const Text('取消')),
        FilledButton(onPressed: () => context.pop(true), child: const Text('确定')),
      ],
    ),
  );
  return ok ?? false;
}
