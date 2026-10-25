import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/engine_errors.dart';
import '../../core/ui/paper.dart';
import 'workshop_provider.dart';

/// 创作对话页：一次只问一个字段，可跳过（代填）、可指出矛盾（世界创造与导入 §3.3）
class CreatePage extends ConsumerStatefulWidget {
  const CreatePage({super.key, required this.draftId});

  final String draftId;

  @override
  ConsumerState<CreatePage> createState() => _CreatePageState();
}

class _Bubble {
  final String text;
  final bool fromUser;
  final bool filledByAI;
  _Bubble(this.text, {required this.fromUser, this.filledByAI = false});
}

class _CreatePageState extends ConsumerState<CreatePage> {
  DraftDetail? _detail;
  final List<_Bubble> _bubbles = [];
  final TextEditingController _input = TextEditingController();
  bool _busy = false;
  bool _generating = false;
  String? _contradiction;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  Future<void> _load({bool initial = false}) async {
    try {
      final d = await ref.read(engineProvider).drafts.detail(widget.draftId);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _error = null;
        if (initial) {
          final interview = d.interview;
          for (final k in FieldKey.values) {
            final a = interview?.answers[k];
            if (a != null) {
              _bubbles.add(_Bubble(a.text, fromUser: true, filledByAI: a.filledByAI));
            }
          }
          _bubbles.add(_Bubble(
              interview?.step.guideQuestion ??
                  FieldKey.era.guideQuestion,
              fromUser: false));
        }
      });
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() => _error = '${engineCodeLabel(e.code)}：${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '载入失败：$e');
    }
  }

  Future<void> _send(String text) async {
    if (_busy || _generating) return;
    setState(() {
      _busy = true;
      _contradiction = null;
    });
    final engine = ref.read(engineProvider);
    try {
      final r = await engine.drafts.interview(widget.draftId, text);
      if (!mounted) return;
      if (!r.advanced) {
        setState(() {
          _contradiction =
              '和「${r.field.label}」冲突：${r.contradiction!.reason}。选一个说法，或者换个讲法。';
        });
        return;
      }
      setState(() {
        _bubbles.add(_Bubble(text, fromUser: true, filledByAI: r.filledByAI));
        _bubbles.add(_Bubble(r.question, fromUser: false));
        _input.clear();
      });
      await _load();
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${engineCodeLabel(e.code)}：${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '请求失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    if (_busy || _generating) return;
    setState(() => _busy = true);
    final engine = ref.read(engineProvider);
    try {
      final r = await engine.drafts.interview(widget.draftId, '', skip: true);
      if (!mounted) return;
      setState(() {
        _bubbles.add(_Bubble('（跳过，交给你定）', fromUser: true, filledByAI: true));
        _bubbles.add(_Bubble(r.question, fromUser: false));
      });
      await _load();
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() => _error = '${engineCodeLabel(e.code)}：${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    final engine = ref.read(engineProvider);
    try {
      await engine.drafts.generate(widget.draftId);
      if (!mounted) return;
      ref.invalidate(draftsProvider);
      context.pushReplacement('/workshop/edit/${widget.draftId}');
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() => _error = '${engineCodeLabel(e.code)}：${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除草稿？'),
        content: const Text('草稿及其全部访谈记录将被删除，试玩局一并清理。'),
        actions: <Widget>[
          TextButton(
              onPressed: () => context.pop(false), child: const Text('取消')),
          FilledButton(
              onPressed: () => context.pop(true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(engineProvider).drafts.delete(widget.draftId);
      if (!mounted) return;
      ref.invalidate(draftsProvider);
      context.pop();
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() => _error = '${engineCodeLabel(e.code)}：${e.message}');
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;
    final detail = _detail;
    final completeness = detail?.view.completeness ?? 0;
    final ready = completeness >= kCompletenessGate;

    return Scaffold(
      appBar: AppBar(
        title: Text(detail?.view.title ?? '对话共创'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除草稿',
            onPressed: _busy || _generating ? null : _delete,
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
          : Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    children: <Widget>[
                      Text('世界完整度 $completeness%',
                          style: TextStyle(fontSize: 12, color: sub)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: completeness / 100,
                            minHeight: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('${detail.view.step?.label ?? ''}',
                          style: TextStyle(fontSize: 12, color: sub)),
                    ],
                  ),
                ),
                if (_contradiction != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: PaperCard(
                      borderColor: theme.colorScheme.error,
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.warning_amber_outlined,
                              size: 18, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_contradiction!,
                                style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                    itemCount: _bubbles.length,
                    itemBuilder: (context, i) {
                      final b = _bubbles[i];
                      return Align(
                        alignment: b.fromUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.78),
                          decoration: BoxDecoration(
                            color: b.fromUser
                                ? theme.colorScheme.primary
                                    .withValues(alpha: 0.12)
                                : paperCardColor(theme.brightness),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(b.text,
                                  style: const TextStyle(
                                      fontSize: 14, height: 1.5)),
                              if (b.filledByAI) ...<Widget>[
                                const SizedBox(height: 4),
                                Text('AI 代填 · 可在编辑器修改',
                                    style: TextStyle(
                                        fontSize: 11, color: sub)),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(_error!,
                        style: TextStyle(
                            fontSize: 12, color: theme.colorScheme.error)),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _input,
                            enabled: !_busy && !_generating,
                            minLines: 1,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 14),
                            decoration: paperInputDecoration(
                                    context, '说说这个字段的想法…',
                                    dense: true)
                                .copyWith(counterText: ''),
                            onSubmitted: (t) {
                              final text = t.trim();
                              if (text.isNotEmpty) _send(text);
                            },
                          ),
                        ),
                        TextButton(
                          onPressed: _busy || _generating ? null : _skip,
                          child: const Text('跳过'),
                        ),
                        IconButton(
                          onPressed: _busy || _generating
                              ? null
                              : () {
                                  final text = _input.text.trim();
                                  if (text.isNotEmpty) _send(text);
                                },
                          icon: const Icon(Icons.send_outlined),
                          tooltip: '发送',
                        ),
                      ],
                    ),
                  ),
                ),
                if (ready)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _generating ? null : _generate,
                          icon: _generating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.auto_awesome, size: 18),
                          label: Text(_generating ? '正在生成世界…' : '生成世界（约 1–2 分钟）'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
