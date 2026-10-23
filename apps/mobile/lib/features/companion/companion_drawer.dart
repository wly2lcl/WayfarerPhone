import 'package:contracts/contracts.dart';
import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/engine_errors.dart';
import '../../core/ui/paper.dart';

/// 随行助手抽屉（游玩页右上角进入）：engine.assistant 流式回答
class CompanionDrawer extends ConsumerStatefulWidget {
  const CompanionDrawer({super.key, required this.runId});

  final String runId;

  @override
  ConsumerState<CompanionDrawer> createState() => _CompanionDrawerState();
}

class _CompanionDrawerState extends ConsumerState<CompanionDrawer> {
  final TextEditingController _question = TextEditingController();
  final List<({String question, String answer})> _history = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _question.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final q = _question.text.trim();
    if (q.isEmpty || _busy) return;
    _question.clear();
    setState(() {
      _busy = true;
      _history.add((question: q, answer: ''));
    });
    try {
      await for (final event
          in ref.read(engineProvider).assistant(widget.runId, q)) {
        if (event is AssistantDelta) {
          final last = _history.last;
          _history[_history.length - 1] =
              (question: last.question, answer: last.answer + event.text);
          if (mounted) setState(() {});
        }
      }
    } on EngineException catch (e) {
      final last = _history.last;
      _history[_history.length - 1] = (
        question: last.question,
        answer: '${engineCodeLabel(e.code)}：${e.message}',
      );
    } catch (e) {
      final last = _history.last;
      _history[_history.length - 1] = (
        question: last.question,
        answer: '随行者走神了：$e',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;
    final canSend = !_busy && _question.text.trim().isNotEmpty;
    return Drawer(
      width: 340,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('随行助手',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('只谈你已知的事，不剧透，不出主意。',
                            style: TextStyle(fontSize: 12, color: sub)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Expanded(
              child: _history.isEmpty
                  ? Center(
                      child: Text('问点什么，比如「我认得谁？」',
                          style: TextStyle(fontSize: 13, color: sub)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(18),
                      itemCount: _history.length,
                      itemBuilder: (context, i) {
                        final h = _history[i];
                        final isLast = i == _history.length - 1;
                        final answer =
                            h.answer.isEmpty && isLast && _busy ? '……' : h.answer;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('你：${h.question}',
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text('随行者：$answer',
                                  style: const TextStyle(fontSize: 14, height: 1.7)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _question,
                      enabled: !_busy,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 100,
                      style: const TextStyle(fontSize: 14),
                      decoration:
                          paperInputDecoration(context, '问点什么', dense: true)
                              .copyWith(counterText: ''),
                      onSubmitted: (_) => _ask(),
                    ),
                  ),
                  IconButton(
                    onPressed: canSend ? _ask : null,
                    icon: Icon(
                      Icons.send_outlined,
                      color: canSend ? theme.colorScheme.primary : null,
                    ),
                    tooltip: '发送',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
