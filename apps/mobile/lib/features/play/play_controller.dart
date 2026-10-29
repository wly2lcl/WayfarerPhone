import 'dart:async';

import 'package:contracts/contracts.dart';
import 'package:engine/engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'play_state.dart';

/// 抽取后刚创建的序章结果暂存：抽取页写入，游玩页首次载入时取走。
final Map<String, StartResult> pendingStarts = <String, StartResult>{};

/// 游玩页控制器：驱动一回合的事件流，维护六态状态机。
class PlayController extends Notifier<PlayState> {
  PlayController(this.runId);

  final String runId;

  StreamSubscription<TurnEvent>? _sub;
  int _expectedTurn = 0;
  TurnInput? _lastInput;

  Engine get _engine => ref.read(engineProvider);

  @override
  PlayState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });
    Future.microtask(_initialLoad);
    return PlayState.initial();
  }

  Future<void> _initialLoad() async {
    final start = pendingStarts.remove(runId);
    try {
      final view = await _engine.getRun(runId);
      final blocks = <NarrationBlock>[];
      var choices = view.pendingChoices;
      if (start != null) {
        if (start.prologue.isNotEmpty) {
          blocks.add(NarrationBlock(turn: 0, text: start.prologue, complete: true));
        }
        if (start.choices.isNotEmpty) choices = start.choices;
      } else {
        // 重新进入（含第 0 回合的试玩局/刚开局的正式局）：加载历史正文（离线也能读回全部叙事）
        final history = await _engine.listNarration(runId);
        var lastTurn = -1;
        for (final n in history) {
          if (n.isMarker) {
            blocks.add(NarrationBlock(
              turn: n.turnNo,
              text: '—— ${n.text} ——',
              complete: true,
              hint: true,
            ));
            if (n.summary.isNotEmpty) {
              blocks.add(NarrationBlock(
                turn: n.turnNo,
                text: '卷记：${n.summary}',
                complete: true,
                hint: true,
              ));
            }
            continue;
          }
          if (n.text.isEmpty) continue;
          if (lastTurn >= 0 && n.turnNo != lastTurn) {
            blocks.add(NarrationBlock(
              turn: n.turnNo,
              text: '—— 第 ${n.turnNo} 回合 ——',
              complete: true,
              hint: true,
            ));
          }
          lastTurn = n.turnNo;
          blocks.add(NarrationBlock(turn: n.turnNo, text: n.text, complete: true));
        }
        if (view.head.turnNo > 0) {
          blocks.add(NarrationBlock(
            turn: view.head.turnNo,
            text: '—— 回到第 ${view.head.turnNo} 回合 ——',
            complete: true,
            hint: true,
          ));
        }
      }
      state = state.copyWith(
        state: view.state,
        blocks: blocks,
        choices: choices,
        turnNo: view.head.turnNo,
        ended: view.head.status == 'ended',
        phase: _phaseFor(view.head.status == 'ended', choices),
      );
      await _loadDisplayNames(view.head.worldId, view.head.worldVersion);
    } on EngineException catch (e) {
      state = state.copyWith(
        phase: PlayPhase.error,
        errorCode: e.code.wireName,
        errorMessage: e.message,
        canRetry: e.canRetry,
      );
    } catch (e) {
      state = state.copyWith(
        phase: PlayPhase.error,
        errorCode: EngineCode.stateInvalid.wireName,
        errorMessage: '载入失败：$e',
        canRetry: true,
      );
    }
  }

  PlayPhase _phaseFor(bool ended, List<Choice> choices) {
    if (ended) return PlayPhase.idle;
    if (!_engine.modelSettings.configured) return PlayPhase.blocked;
    return choices.isNotEmpty ? PlayPhase.awaitingChoice : PlayPhase.idle;
  }

  /// 状态条的关系/声望徽章存的是 id（relations key = npcId，reputation key = factionId），
  /// 展示需经圣经映射显示名；取不到圣经或条目时由 UI 回退 id
  Future<void> _loadDisplayNames(String worldId, int version) async {
    try {
      // 试玩局 worldId 形如 draft_<draftId>、版本恒 0，圣经在草稿行而非 worlds 表
      final WorldBible bible;
      if (worldId.startsWith('draft_')) {
        final detail = await _engine.drafts.detail(worldId.substring('draft_'.length));
        final b = detail.bible;
        if (b == null) return;
        bible = b;
      } else {
        bible = await _engine.loadBible(worldId, version);
      }
      state = state.copyWith(
        npcNames: <String, String>{
          for (final n in bible.npcPool) n.id: n.name,
        },
        factionNames: <String, String>{
          for (final f in bible.factions) f.id: f.name,
        },
      );
    } on EngineException {
      // 圣经取不到不阻塞游玩，徽章回退显示 id
    }
  }

  /// 推进一回合。submitting / streaming 期间忽略新提交（队列只接受一次）。
  Future<void> submit(TurnInput input) async {
    final s = state;
    if (s.busy) return;
    final current = s.state;
    if (current == null || s.ended) return;
    if (!_engine.modelSettings.configured) {
      state = s.copyWith(phase: PlayPhase.blocked);
      return;
    }
    _expectedTurn = current.meta.turnNo;
    _lastInput = input;
    await _runTurn(input, _expectedTurn);
  }

  /// 失败重试：使用与上次提交相同的 expectedTurn。
  Future<void> retry() async {
    final s = state;
    if (s.busy) return;
    if (!_engine.modelSettings.configured) {
      state = s.copyWith(phase: PlayPhase.blocked);
      return;
    }
    final input = _lastInput;
    if (input == null) {
      // 没有可重试的输入（如首次载入失败），重新走一遍载入
      await _initialLoad();
      return;
    }
    await _runTurn(input, _expectedTurn);
  }

  /// 停止当前回合的生成：断开事件流（回合引擎在下一事件点中止，不落库、
  /// turnNo 不变），保留已流出的正文并回到待选态；可重新提交或重试
  Future<void> stopGeneration() async {
    if (!state.busy) return;
    await _sub?.cancel();
    _sub = null;
    var blocks = <NarrationBlock>[...state.blocks];
    // 已流出的半截正文补完整标记，与「流中断保留正文」口径一致；
    // 纯空占位连同其回合标题一并丢弃（该回合未发生，不留空壳）
    if (blocks.isNotEmpty && !blocks.last.complete && !blocks.last.hint) {
      if (blocks.last.text.isEmpty) {
        blocks.removeLast();
        if (blocks.isNotEmpty && blocks.last.hint) {
          blocks = blocks.sublist(0, blocks.length - 1);
        }
      } else {
        blocks[blocks.length - 1] = blocks.last.completed();
      }
    }
    state = state.copyWith(
      phase: PlayPhase.idle,
      blocks: blocks,
      canRetry: false,
      errorCode: null,
      errorMessage: null,
    );
    // 上一回合若仍有等待中的选项，恢复之
    await _restorePendingChoices();
  }

  Future<void> _runTurn(TurnInput input, int expectedTurn) async {
    await _sub?.cancel();
    state = state.clearError().copyWith(phase: PlayPhase.submitting);
    _sub = _engine.turns
        .run(runId, expectedTurn: expectedTurn, input: input)
        .listen(
      _onEvent,
      onError: (Object e) {
        state = state.copyWith(
          phase: PlayPhase.error,
          errorCode: EngineCode.stateInvalid.wireName,
          errorMessage: '回合执行失败：$e',
          canRetry: true,
        );
      },
      cancelOnError: true,
    );
  }

  void _onEvent(TurnEvent event) {
    switch (event) {
      case TurnStart(:final turn):
        final blocks = <NarrationBlock>[...state.blocks];
        if (blocks.isNotEmpty && !blocks.last.complete) {
          // 上次失败尝试留下的半截正文不再保留，避免重试后重复追加
          blocks.removeLast();
        }
        // 同回合标题复用：中止/失败后重提不再叠加「第 N 回合」
        if (!blocks.any((b) => b.hint && b.turn == turn)) {
          blocks.add(NarrationBlock(
            turn: turn,
            text: '—— 第 $turn 回合 ——',
            complete: true,
            hint: true,
          ));
        }
        blocks.add(NarrationBlock(turn: turn, text: '', complete: false));
        state = state.copyWith(
          phase: PlayPhase.streaming,
          blocks: blocks,
          choices: const <Choice>[],
          turnNo: turn,
        );
      case Classification():
        break;
      case NarrationDelta(:final text):
        final blocks = <NarrationBlock>[...state.blocks];
        if (blocks.isEmpty || blocks.last.complete || blocks.last.hint) {
          blocks.add(NarrationBlock(turn: state.turnNo, text: text, complete: false));
        } else {
          blocks[blocks.length - 1] = blocks.last.appended(text);
        }
        state = state.copyWith(blocks: blocks);
      case NarrationEnd():
        final blocks = <NarrationBlock>[...state.blocks];
        for (var i = 0; i < blocks.length; i++) {
          if (!blocks[i].complete && !blocks[i].hint) {
            blocks[i] = blocks[i].completed();
          }
        }
        state = state.copyWith(blocks: blocks);
      case ChapterCompleted(:final chapter, :final summary):
        final blocks = <NarrationBlock>[...state.blocks];
        blocks.add(NarrationBlock(
          turn: state.turnNo,
          text: '—— 第 $chapter 卷 · 完 ——',
          complete: true,
          hint: true,
        ));
        if (summary.isNotEmpty) {
          blocks.add(NarrationBlock(
            turn: state.turnNo,
            text: '卷记：$summary',
            complete: true,
            hint: true,
          ));
        }
        state = state.copyWith(blocks: blocks);
      case ChoicesAvailable(:final options):
        state = state.copyWith(choices: options);
      case StatePatch():
        // 面板数据只来自 state_patch：引擎已把补丁落库，此处回读最新状态
        _applyStatePatch();
      case TurnEnd(:final turn, :final ending):
        _onTurnEnd(turn, ending);
      case TurnError(:final code, :final message, :final canRetry):
        state = state.copyWith(
          phase: PlayPhase.error,
          errorCode: code,
          errorMessage: message,
          canRetry: canRetry,
        );
    }
  }

  void _onTurnEnd(int turn, EndingRef? ending) {
    if (ending != null) {
      state = state.copyWith(
        phase: PlayPhase.idle,
        turnNo: turn,
        ended: true,
        endingReached: true,
        choices: const <Choice>[],
      );
      return;
    }
    if (state.choices.isNotEmpty) {
      state = state.copyWith(phase: PlayPhase.awaitingChoice, turnNo: turn);
    } else {
      // 叙事型回合（问询等）不产生新选项，取回仍在等待的选项
      state = state.copyWith(phase: PlayPhase.idle, turnNo: turn);
      _restorePendingChoices();
    }
  }

  Future<void> _restorePendingChoices() async {
    if (state.busy) return;
    try {
      final view = await _engine.getRun(runId);
      if (state.busy) return;
      if (view.pendingChoices.isNotEmpty) {
        state = state.copyWith(
          choices: view.pendingChoices,
          phase: PlayPhase.awaitingChoice,
        );
      }
    } on EngineException {
      // 取不到就不阻塞阅读
    }
  }

  Future<void> _applyStatePatch() async {
    try {
      final view = await _engine.getRun(runId);
      final s = view.state;
      if (s != null) {
        final turnNo =
            s.meta.turnNo > state.turnNo ? s.meta.turnNo : state.turnNo;
        state = state.copyWith(state: s, turnNo: turnNo);
      }
    } on EngineException {
      // 状态刷新失败不打断回合
    }
  }
}

final playProvider =
    NotifierProvider.family<PlayController, PlayState, String>(PlayController.new);
