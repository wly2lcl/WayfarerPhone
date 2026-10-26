import 'dart:async';

import 'package:engine/engine.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/engine_errors.dart';
import '../../core/ui/paper.dart';
import 'workshop_provider.dart';

/// 导入向导（世界创造与导入 §4.1）：
/// 选文件 → 版权确认 → 进度 → 实体审阅 → 去编辑器审阅/试玩
class ImportWizardPage extends ConsumerStatefulWidget {
  const ImportWizardPage({super.key});

  @override
  ConsumerState<ImportWizardPage> createState() => _ImportWizardPageState();
}

class _ImportWizardPageState extends ConsumerState<ImportWizardPage> {
  ImportJobView? job;
  List<ImportEntity> entities = const [];
  String? fatal; // start 阶段的异常（任务尚未建立）
  Timer? poll;
  bool busy = false;

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  Future<void> _pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [XTypeGroup(label: '文本文件', extensions: ['txt'])],
    );
    if (file == null || !mounted) return;
    final fidelity = await _askFidelity(file.name);
    if (fidelity == null || !mounted) return;
    await _start(file.path, fidelity);
  }

  /// 版权确认 + 合成档位选择（快速/标准/忠实）
  Future<ImportFidelity?> _askFidelity(String name) async {
    var choice = ImportFidelity.standard;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('版权确认'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                  '「$name」\n\n确认你是该作品的作者，或已获得把作品导入本应用生成个人世界的授权。'
                  '\n\n导入内容仅保存在本机、仅用于生成你自己的游玩世界，无法导出或分享。'),
              const SizedBox(height: 12),
              Text('合成档位', style: Theme.of(ctx).textTheme.labelLarge),
              RadioGroup<ImportFidelity>(
                groupValue: choice,
                onChanged: (v) => setLocal(() => choice = v!),
                child: const Column(
                  children: <Widget>[
                    RadioListTile<ImportFidelity>(
                      value: ImportFidelity.fast,
                      title: Text('快速'),
                      subtitle: Text('截断摘要，最快出世界；长篇后期剧情可能缺席',
                          style: TextStyle(fontSize: 12)),
                      dense: true,
                    ),
                    RadioListTile<ImportFidelity>(
                      value: ImportFidelity.standard,
                      title: Text('标准'),
                      subtitle: Text('全书均匀采样，首尾与结局都参与生成',
                          style: TextStyle(fontSize: 12)),
                      dense: true,
                    ),
                    RadioListTile<ImportFidelity>(
                      value: ImportFidelity.faithful,
                      title: Text('忠实'),
                      subtitle: Text('先把全书剧情压缩成卷级脉络再合成，最贴近原著走向',
                          style: TextStyle(fontSize: 12)),
                      dense: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('我确认，开始导入')),
          ],
        ),
      ),
    );
    return ok == true ? choice : null;
  }

  Future<void> _start(String path, ImportFidelity fidelity) async {
    setState(() {
      busy = true;
      fatal = null;
    });
    try {
      final engine = ref.read(engineProvider);
      final j = await engine.imports.start(path, fidelity: fidelity);
      if (!mounted) return;
      setState(() => job = j);
      _watch();
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() => fatal = '${engineCodeLabel(e.code)}：${e.message}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _watch() async {
    poll?.cancel();
    poll = Timer.periodic(const Duration(milliseconds: 800), (_) => _tick());
  }

  Future<void> _tick() async {
    final j = job;
    if (j == null) return;
    final engine = ref.read(engineProvider);
    final cur = await engine.imports.progress(j.id);
    if (cur == null || !mounted) return;
    setState(() => job = cur);
    if (cur.stage == 'review') {
      poll?.cancel();
      final list = await engine.imports.entities(cur.id);
      if (!mounted) return;
      setState(() => entities = list);
      ref.invalidate(draftsProvider);
    }
  }

  Future<void> _resume() async {
    final j = job;
    if (j == null) return;
    setState(() {
      busy = true;
    });
    try {
      final engine = ref.read(engineProvider);
      final cur = await engine.imports.resume(j.id);
      if (!mounted) return;
      setState(() => job = cur);
      _watch();
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() => fatal = '${engineCodeLabel(e.code)}：${e.message}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _regenerate() async {
    final j = job;
    if (j == null) return;
    final fidelity = await _askRegenFidelity(j.fidelity);
    if (fidelity == null) return;
    setState(() => busy = true);
    try {
      final engine = ref.read(engineProvider);
      final cur = await engine.imports.regenerate(j.id, fidelity: fidelity);
      if (!mounted) return;
      setState(() => job = cur);
      _watch();
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() => fatal = '${engineCodeLabel(e.code)}：${e.message}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// 重新生成世界时的档位选择（默认沿用任务当前档位）
  Future<ImportFidelity?> _askRegenFidelity(ImportFidelity current) async {
    var choice = current;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('重新生成世界'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('用（审阅后的）实体与全书摘要素材重新合成世界圣经。'),
              const SizedBox(height: 12),
              Text('合成档位', style: Theme.of(ctx).textTheme.labelLarge),
              RadioGroup<ImportFidelity>(
                groupValue: choice,
                onChanged: (v) => setLocal(() => choice = v!),
                child: const Column(
                  children: <Widget>[
                    RadioListTile<ImportFidelity>(
                      value: ImportFidelity.fast,
                      title: Text('快速'),
                      dense: true,
                    ),
                    RadioListTile<ImportFidelity>(
                      value: ImportFidelity.standard,
                      title: Text('标准（全书均匀采样）'),
                      dense: true,
                    ),
                    RadioListTile<ImportFidelity>(
                      value: ImportFidelity.faithful,
                      title: Text('忠实（全书脉络压缩）'),
                      dense: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('重新生成')),
          ],
        ),
      ),
    );
    return ok == true ? choice : null;
  }

  Future<void> _remove(ImportEntity e) async {
    final j = job;
    if (j == null) return;
    final list = await ref
        .read(engineProvider)
        .imports
        .updateEntities(j.id, removeKeys: [e.key]);
    if (!mounted) return;
    setState(() => entities = list);
  }

  Future<void> _merge(ImportEntity e) async {
    final j = job;
    if (j == null) return;
    final targets = entities.where((x) => x.key != e.key).toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('没有可合并的目标')));
      return;
    }
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('把「${e.key}」并入哪个实体？'),
        children: <Widget>[
          for (final t in targets)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(t.key),
              child: Text('${t.key}（频次 ${t.frequency}）'),
            ),
        ],
      ),
    );
    if (target == null) return;
    final list = await ref
        .read(engineProvider)
        .imports
        .updateEntities(j.id, mergeInto: {e.key: target});
    if (!mounted) return;
    setState(() => entities = list);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;
    final j = job;
    return Scaffold(
      appBar: AppBar(title: const Text('导入小说')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: <Widget>[
          if (fatal != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(fatal!,
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.error)),
            ),
          if (j == null) ..._intro(sub),
          if (j != null) ..._progress(j, sub),
        ],
      ),
    );
  }

  List<Widget> _intro(Color sub) => <Widget>[
        PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('把一本小说 TXT 变成你的世界',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(
                '引擎会分块读取全书，抽出人物、势力、事件与时间线，'
                '合成为一份可玩的世界圣经；你可以审阅、合并或删除抽取结果。',
                style: TextStyle(fontSize: 13, color: sub, height: 1.6),
              ),
              const SizedBox(height: 10),
              Text(
                '· 仅支持 .txt，20 MB 以内，UTF-8 / GBK 自动识别\n'
                '· 导入的世界只存在本机，永远不可导出\n'
                '· 请确认你对作品拥有版权或授权',
                style: TextStyle(fontSize: 12, color: sub, height: 1.8),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy ? null : _pick,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(busy ? '解析中…' : '选择 TXT 文件'),
        ),
      ];

  List<Widget> _progress(ImportJobView j, Color sub) {
    final stats = j.stats;
    return <Widget>[
      PaperCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                    child: Text(_stageLabel(j.stage),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600))),
                if (stats != null)
                  Text('第 ${stats.chapters} 章 · ${stats.chunks} 块 · '
                      '${_fidelityLabel(j.fidelity)}',
                      style: TextStyle(fontSize: 12, color: sub)),
              ],
            ),
            const SizedBox(height: 12),
            if (j.stage == 'review')
              ..._reviewSection(j, sub)
            else ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: j.total == 0 ? null : j.done / j.total,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                j.error != null
                    ? j.error!
                    : j.stage == 'merging'
                        ? '正在归并实体…'
                        : j.stage == 'compressing'
                            ? '正在提炼全书脉络…'
                            : '已抽取 ${j.done}/${j.total} 块（打断后会从断点续跑）',
                style: TextStyle(fontSize: 12, color: sub),
              ),
              if (j.error != null) ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    OutlinedButton(
                        onPressed: busy ? null : _resume, child: const Text('续跑')),
                    const SizedBox(width: 12),
                    if (j.entitiesTotal > 0)
                      OutlinedButton(
                          onPressed: busy ? null : _regenerate,
                          child: const Text('重新生成世界')),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _reviewSection(ImportJobView j, Color sub) {
    final kept = entities.length;
    final total = j.entitiesTotal;
    return <Widget>[
      Row(
        children: <Widget>[
          PaperBadge(label: '实体审阅'),
          const SizedBox(width: 10),
          Text('采纳率 $kept/$total',
              style: TextStyle(fontSize: 12, color: sub)),
          const Spacer(),
          if (j.draftId != null)
            FilledButton.tonal(
              onPressed: () {
                ref.invalidate(draftsProvider);
                context.push('/workshop/edit/${j.draftId}');
              },
              child: const Text('去审阅世界'),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        '以下是从正文里抽出的高频实体。世界已经生成；'
        '在这里删除噪声、把别名并成一个人，再进编辑器细修。',
        style: TextStyle(fontSize: 12, color: sub, height: 1.6),
      ),
      const SizedBox(height: 8),
      if (entities.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text('没有抽到实体。', style: TextStyle(fontSize: 12, color: sub)),
        )
      else
        for (final e in entities)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _EntityRow(
              entity: e,
              onRemove: () => _remove(e),
              onMerge: () => _merge(e),
            ),
          ),
    ];
  }
}

String _stageLabel(String stage) => switch (stage) {
      'queued' => '排队中',
      'parsing' => '解析正文',
      'extracting' => '分块抽取中',
      'merging' => '归并实体',
      'compressing' => '提炼全书脉络',
      'review' => '导入完成，世界已生成',
      'failed' => '导入失败',
      _ => stage,
    };

String _fidelityLabel(ImportFidelity f) => switch (f) {
      ImportFidelity.fast => '快速',
      ImportFidelity.standard => '标准',
      ImportFidelity.faithful => '忠实',
    };

String _entityTypeLabel(String type) => switch (type) {
      'character' => '人物',
      'place' => '地点',
      'faction' => '势力',
      'item' => '物品',
      'event' => '事件',
      _ => type,
    };

class _EntityRow extends StatelessWidget {
  const _EntityRow({
    required this.entity,
    required this.onRemove,
    required this.onMerge,
  });

  final ImportEntity entity;
  final VoidCallback onRemove;
  final VoidCallback onMerge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;
    final attrs = entity.attributes.entries
        .take(2)
        .map((a) => '${a.key}·${a.value}')
        .join('，');
    return PaperCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(entity.key,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    PaperBadge(label: _entityTypeLabel(entity.type)),
                    const SizedBox(width: 8),
                    Text('×${entity.frequency}',
                        style: TextStyle(fontSize: 12, color: sub)),
                    if (entity.firstChapter > 0) ...<Widget>[
                      const SizedBox(width: 8),
                      Text('第${entity.firstChapter}章',
                          style: TextStyle(fontSize: 12, color: sub)),
                    ],
                  ],
                ),
                if (entity.aliases.isNotEmpty || attrs.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    <String>[
                      if (entity.aliases.isNotEmpty) '别名：${entity.aliases.join('、')}',
                      if (attrs.isNotEmpty) attrs,
                    ].join(' · '),
                    style: TextStyle(fontSize: 12, color: sub),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '并入其他实体',
            onPressed: onMerge,
            icon: const Icon(Icons.merge_outlined, size: 20),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: onRemove,
            icon: Icon(Icons.delete_outline, size: 20, color: sub),
          ),
        ],
      ),
    );
  }
}
