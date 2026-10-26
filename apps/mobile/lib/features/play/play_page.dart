import 'package:contracts/contracts.dart';
import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/engine_errors.dart';
import '../../core/ui/paper.dart';
import '../companion/companion_drawer.dart';
import 'play_controller.dart';
import 'play_state.dart';

/// 游玩页：状态条 / 正文区（流式追加）/ 选项区 / 自由输入
class PlayPage extends ConsumerStatefulWidget {
  const PlayPage({super.key, required this.runId});

  final String runId;

  @override
  ConsumerState<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends ConsumerState<PlayPage> {
  final ScrollController _scroll = ScrollController();
  bool _follow = true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _onUserScroll(UserScrollNotification n) {
    if (n.direction == ScrollDirection.reverse) {
      if (_follow) setState(() => _follow = false);
    } else if (n.direction == ScrollDirection.forward) {
      final m = n.metrics;
      if (m.maxScrollExtent - m.pixels < 48 && !_follow) {
        setState(() => _follow = true);
      }
    }
    return false;
  }

  void _goLatest() {
    setState(() => _follow = true);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _submit(TurnInput input) {
    ref.read(playProvider(widget.runId).notifier).submit(input);
  }

  /// 回溯分叉（API 参考 runs.branch）：选历史回合快照，开一条新世界线，旧线原样保留
  Future<void> _showBranchSheet() async {
    final engine = ref.read(engineProvider);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: FutureBuilder<List<SnapshotBrief>>(
          future: engine.listSnapshots(widget.runId),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final snaps = snap.data!;
            return ListView(
              shrinkWrap: true,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    '回溯到哪个节点？新世界线从所选回合开始，旧线原样保留。',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                for (final s in snaps)
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(
                        s.turnNo == 0 ? '开局（序章之前）' : '第 ${s.chapter} 卷 · 回合 ${s.turnNo} 结束后'),
                    onTap: () async {
                      try {
                        final newId = await engine.branch(snapshotId: s.id);
                        if (!sheetCtx.mounted) return;
                        Navigator.of(sheetCtx).pop();
                        if (!mounted) return;
                        context.push('/play/$newId');
                      } on EngineException catch (e) {
                        if (!sheetCtx.mounted) return;
                        Navigator.of(sheetCtx).pop();
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  '${engineCodeLabel(e.code)}：${e.message}')),
                        );
                      }
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _title(PlayState play) {
    final s = play.state;
    if (s == null) return '游玩';
    return '第${s.meta.chapter}卷 · ${s.character.realm.stageName}';
  }

  @override
  Widget build(BuildContext context) {
    final play = ref.watch(playProvider(widget.runId));
    final night = ref.watch(nightModeProvider);

    ref.listen<PlayState>(playProvider(widget.runId), (prev, next) {
      if ((prev == null || !prev.endingReached) && next.endingReached) {
        context.push('/archive/${widget.runId}');
      }
      if (_follow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_follow || !_scroll.hasClients) return;
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    });

    final hasState = play.state != null;

    return Scaffold(
      endDrawer: CompanionDrawer(runId: widget.runId),
      appBar: AppBar(
        title: Text(_title(play)),
        actions: <Widget>[
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.auto_stories_outlined),
              tooltip: '随行助手',
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) {
              switch (value) {
                case 'library':
                  context.push('/library');
                case 'archive':
                  context.push('/archive/${widget.runId}');
                case 'branch':
                  _showBranchSheet();
                case 'home':
                  context.go('/');
              }
            },
            itemBuilder: (ctx) => const <PopupMenuItem<String>>[
              PopupMenuItem<String>(value: 'library', child: Text('我的局')),
              PopupMenuItem<String>(value: 'archive', child: Text('人生档案')),
              PopupMenuItem<String>(value: 'branch', child: Text('回溯分叉')),
              PopupMenuItem<String>(value: 'home', child: Text('返回书架')),
            ],
          ),
        ],
      ),
      body: !hasState && play.phase != PlayPhase.error
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                if (play.phase == PlayPhase.error)
                  _ErrorBar(
                    errorCode: play.errorCode ?? EngineCode.stateInvalid.wireName,
                    message: play.errorMessage ?? '',
                    onRetry: () =>
                        ref.read(playProvider(widget.runId).notifier).retry(),
                  ),
                if (hasState)
                  _StatusStrip(
                    state: play.state!,
                    npcNames: play.npcNames,
                    factionNames: play.factionNames,
                  ),
                Expanded(
                  child: NotificationListener<UserScrollNotification>(
                    onNotification: _onUserScroll,
                    child: Stack(
                      children: <Widget>[
                        _NarrationList(
                          play: play,
                          controller: _scroll,
                          night: night,
                          onChoice: (choice) => _submit(ChoiceInput(choice.id)),
                          onGoSettings: () => context.push('/settings'),
                          runId: widget.runId,
                        ),
                        if (!_follow)
                          Positioned(
                            right: 16,
                            bottom: 12,
                            child: FilledButton.tonalIcon(
                              onPressed: _goLatest,
                              icon: const Icon(Icons.south, size: 16),
                              label: const Text('回到最新'),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                _InputBar(
                  locked: play.busy || play.ended,
                  onSend: (text) => _submit(FreeTextInput(text)),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({
    required this.errorCode,
    required this.message,
    required this.onRetry,
  });

  final String errorCode;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      color: accent.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '$errorCode · ${turnErrorCodeLabel(errorCode)}：$message',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: accent),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

/// 状态条：气血 / 神识 / 灵石 / 声望 / 关键关系 / 寿元（只取 RunState）
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.state,
    this.npcNames = const <String, String>{},
    this.factionNames = const <String, String>{},
  });

  final RunState state;
  final Map<String, String> npcNames;
  final Map<String, String> factionNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: paperCardColor(theme.brightness),
        border: Border(
          top: BorderSide(color: theme.dividerColor),
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _stat(context, '气血', '${state.character.stats.vitality}'),
            _stat(context, '神识', '${state.character.stats.spirit}'),
            _stat(context, '灵石', '${state.character.resources.spiritStones}'),
            _stat(context, '声望', _reputation),
            _stat(context, '关系', _relation),
            _stat(context, '寿元', '${state.meta.lifespan - state.meta.age}'),
          ],
        ),
      ),
    );
  }

  String get _reputation {
    if (state.reputation.isEmpty) return '—';
    final e = state.reputation.entries.first;
    final v = e.value;
    final name = factionNames[e.key] ?? e.key;
    return '$name ${v > 0 ? '+' : ''}$v';
  }

  String get _relation {
    if (state.relations.isEmpty) return '—';
    final e = state.relations.entries.first;
    final name =
        npcNames[e.key] ?? e.key.replaceFirst(RegExp('^npc_'), '').replaceAll('_', ' ');
    return '$name · ${e.value.status.label}';
  }

  Widget _stat(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _NarrationList extends StatelessWidget {
  const _NarrationList({
    required this.play,
    required this.controller,
    required this.night,
    required this.onChoice,
    required this.onGoSettings,
    required this.runId,
  });

  final PlayState play;
  final ScrollController controller;
  final bool night;
  final ValueChanged<Choice> onChoice;
  final VoidCallback onGoSettings;
  final String runId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.colorScheme.secondary;
    final items = <Widget>[];

    for (final b in play.blocks) {
      if (b.hint) {
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Center(
            child: Text(
              b.text,
              style: TextStyle(fontSize: 12, letterSpacing: 2, color: sub),
            ),
          ),
        ));
      } else {
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Text(
            b.text.isEmpty ? '……' : b.text,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.9, fontSize: 17),
          ),
        ));
      }
    }

    if (play.phase == PlayPhase.submitting) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Center(
          child: Text('正在推进……', style: TextStyle(fontSize: 12, color: sub)),
        ),
      ));
    }

    if (play.phase == PlayPhase.blocked) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: PaperCard(
          borderColor: theme.colorScheme.primary,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('配置模型后可继续',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('生成新的正文需要先配置模型服务。',
                        style: TextStyle(fontSize: 12, color: sub)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(onPressed: onGoSettings, child: const Text('去设置')),
            ],
          ),
        ),
      ));
    }

    if (play.ended) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('这一局已经落幕',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('翻开人生档案，看看这一生留下了什么。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: sub)),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => context.push('/archive/$runId'),
                child: const Text('查看人生档案'),
              ),
            ],
          ),
        ),
      ));
    } else if (play.phase == PlayPhase.awaitingChoice) {
      if (play.choices.isEmpty) {
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Center(
            child: Text('本回合没有给出选项，可在下方自由输入。',
                style: TextStyle(fontSize: 12, color: sub)),
          ),
        ));
      }
      for (final c in play.choices) {
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ChoiceCard(
            choice: c,
            night: night,
            onTap: () => onChoice(c),
          ),
        ));
      }
    } else if (play.phase == PlayPhase.idle && items.isEmpty) {
      items.add(Center(
        child: Text('会发生什么，由你决定。', style: TextStyle(fontSize: 13, color: sub)),
      ));
    }

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
      children: items,
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.choice,
    required this.night,
    required this.onTap,
  });

  final Choice choice;
  final bool night;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).colorScheme.secondary;
    return PaperCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: PaperDot(color: riskColor(choice.risk, night: night)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(choice.label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                if (choice.intent.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(choice.intent,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: sub)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部自由输入框（≤200 字），submitting / streaming 期间锁定
class _InputBar extends StatefulWidget {
  const _InputBar({required this.locked, required this.onSend});

  final bool locked;
  final ValueChanged<String> onSend;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.locked) return;
    _controller.clear();
    _focus.unfocus();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = !widget.locked && _controller.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: paperCardColor(theme.brightness),
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: !widget.locked,
                  maxLength: 200,
                  minLines: 1,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14),
                  decoration: paperInputDecoration(
                    context,
                    '你还想做什么？',
                    hint: '自由行动，200 字以内',
                    dense: true,
                  ).copyWith(counterText: ''),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(
                onPressed: canSend ? _send : null,
                icon: Icon(
                  Icons.send_outlined,
                  color: canSend ? theme.colorScheme.primary : null,
                ),
                tooltip: '发送',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
