import 'package:contracts/contracts.dart';

/// 游玩页状态机：idle → streaming → awaitingChoice → submitting → idle，
/// 出错进 error（可重试），未配置模型进 blocked。
enum PlayPhase { idle, streaming, awaitingChoice, submitting, error, blocked }

/// 一段正文。hint 为分隔提示（回合标记 / 回到提示），不参与失败清理。
class NarrationBlock {
  NarrationBlock({
    required this.turn,
    required this.text,
    required this.complete,
    this.hint = false,
  });

  final int turn;
  final String text;
  final bool complete;
  final bool hint;

  NarrationBlock appended(String more) => NarrationBlock(
        turn: turn,
        text: text + more,
        complete: complete,
        hint: hint,
      );

  NarrationBlock completed() =>
      NarrationBlock(turn: turn, text: text, complete: true, hint: hint);
}

class PlayState {
  PlayState({
    required this.phase,
    required this.blocks,
    required this.choices,
    required this.turnNo,
    required this.ended,
    required this.endingReached,
    required this.canRetry,
    this.state,
    this.npcNames = const <String, String>{},
    this.factionNames = const <String, String>{},
    this.errorCode,
    this.errorMessage,
  });

  PlayState.initial() : this(
          phase: PlayPhase.idle,
          blocks: const <NarrationBlock>[],
          choices: const <Choice>[],
          turnNo: 0,
          ended: false,
          endingReached: false,
          canRetry: false,
        );

  final PlayPhase phase;
  final List<NarrationBlock> blocks;

  /// 最近一次 statePatch 后的 RunState（状态条唯一数据来源）
  final RunState? state;

  /// NPC/势力 id → 显示名（状态条关系/声望徽章用；取不到时回退 id）
  final Map<String, String> npcNames;
  final Map<String, String> factionNames;
  final List<Choice> choices;
  final int turnNo;
  final bool ended;

  /// 本局终局事件已触发（页面据此跳转档案页）
  final bool endingReached;
  final String? errorCode;
  final String? errorMessage;
  final bool canRetry;

  bool get busy => phase == PlayPhase.streaming || phase == PlayPhase.submitting;

  PlayState copyWith({
    PlayPhase? phase,
    List<NarrationBlock>? blocks,
    RunState? state,
    Map<String, String>? npcNames,
    Map<String, String>? factionNames,
    List<Choice>? choices,
    int? turnNo,
    bool? ended,
    bool? endingReached,
    bool? canRetry,
    String? errorCode,
    String? errorMessage,
  }) =>
      PlayState(
        phase: phase ?? this.phase,
        blocks: blocks ?? this.blocks,
        state: state ?? this.state,
        npcNames: npcNames ?? this.npcNames,
        factionNames: factionNames ?? this.factionNames,
        choices: choices ?? this.choices,
        turnNo: turnNo ?? this.turnNo,
        ended: ended ?? this.ended,
        endingReached: endingReached ?? this.endingReached,
        canRetry: canRetry ?? this.canRetry,
        errorCode: errorCode ?? this.errorCode,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  PlayState clearError() => PlayState(
        phase: phase,
        blocks: blocks,
        state: state,
        npcNames: npcNames,
        factionNames: factionNames,
        choices: choices,
        turnNo: turnNo,
        ended: ended,
        endingReached: endingReached,
        canRetry: false,
        errorCode: null,
        errorMessage: null,
      );
}
