import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:contracts/contracts.dart';
import 'package:drift/drift.dart';

import '../data/app_db.dart';
import '../data/runs_dao.dart';
import '../errors.dart';
import '../llm/gateway.dart';
import '../llm/settings.dart';
import '../prompts/roles.dart';
import '../rules/ending.dart';
import '../rules/resolver.dart';
import 'apply.dart';
import 'context.dart';
import 'queue.dart';

class TurnEngine {
  final AppDb db;
  final ModelGateway gateway;
  final SerialQueue queue;
  final Random random;

  TurnEngine({
    required this.db,
    required this.gateway,
    required this.queue,
    Random? random,
  }) : random = random ?? Random.secure();

  Stream<TurnEvent> run(
    String runId, {
    required int expectedTurn,
    required TurnInput input,
  }) {
    final controller = StreamController<TurnEvent>();
    queue.run(runId, () => _doTurn(runId, expectedTurn, input, controller))
        .catchError((Object e, StackTrace st) {
      if (!controller.isClosed) {
        controller.add(TurnError(
          e is EngineException ? e.code.wireName : EngineCode.stateInvalid.wireName,
          e.toString(),
          true,
        ));
      }
    }).whenComplete(() => controller.close());
    return controller.stream;
  }

  Future<void> _doTurn(
    String runId,
    int expectedTurn,
    TurnInput input,
    StreamController<TurnEvent> out,
  ) async {
    void emit(TurnEvent e) {
      if (!out.isClosed) out.add(e);
    }

    final head = await RunsDao(db).loadHead(runId);
    if (head == null) {
      emit(TurnError(EngineCode.notFound.wireName, '局不存在', false));
      return;
    }
    if (head.status == 'ended') {
      emit(TurnError(EngineCode.runEnded.wireName, '这一局已经落幕', false));
      return;
    }
    if (head.turnNo != expectedTurn) {
      emit(TurnError(EngineCode.turnConflict.wireName,
          '回合冲突：本地 ${head.turnNo}，请求 $expectedTurn', false));
      return;
    }

    final version = await (db.select(db.worldVersions)
          ..where((v) =>
              v.worldId.equals(head.worldId) &
              v.version.equals(head.worldVersion)))
        .getSingleOrNull();
    if (version == null) {
      emit(TurnError(EngineCode.notFound.wireName, '世界版本缺失', false));
      return;
    }
    final bible = WorldBible.fromJson(jsonDecode(version.bible));
    final identityList =
        asList<Identity>(jsonDecode(version.identities), Identity.fromJson);
    final identity = identityList
        .where((i) => i.id == head.identityId)
        .firstOrNull;
    if (identity == null) {
      emit(TurnError(EngineCode.notFound.wireName, '身份缺失', false));
      return;
    }

    final state = (await RunsDao(db).loadState(runId))!;
    final memory = CompactMemory.fromJson(await RunsDao(db).loadMemory(runId));
    final book = EngineBookkeeping.fromMemoryJson(
        await RunsDao(db).loadMemory(runId));
    final runEvents = db.runEvents;

    final newTurnNo = head.turnNo + 1;
    emit(TurnStart(newTurnNo));

    final dao = RunsDao(db);
    final narrationHistory = await _recentNarrations(runId, 3);
    final pendingRepair = state.pendingRepair;

    // ---- 意图 ----
    var intent = '';
    var kind = IntentKind.action;
    String? choiceCheckStat;
    int? choiceCheckDc;
    if (input is ChoiceInput) {
      final lastChoices = await (db.select(runEvents)
            ..where((e) => e.runId.equals(runId) & e.type.equals('choice'))
            ..orderBy([(e) => OrderingTerm.desc(e.seq)])
            ..limit(1))
          .getSingleOrNull();
      if (lastChoices != null) {
        final payload = jsonDecode(lastChoices.payload);
        final options = asList<Choice>(
            rawMap(payload)['options'], Choice.fromJson);
        final found = options.where((c) => c.id == input.choiceId).firstOrNull;
        if (found != null) {
          intent = found.intent;
          choiceCheckStat = found.check?.stat.name;
          choiceCheckDc = found.check?.dc;
        }
      }
      intent = intent.isEmpty ? '推进这件事' : intent;
    } else if (input is FreeTextInput) {
      final classified = await _classify(bible, state, input.text);
      kind = classified.$1;
      intent = classified.$2;
      emit(Classification(kind, intent));
      if (kind == IntentKind.query || kind == IntentKind.meta) {
        await _answerQuery(bible, identity, state, input.text, narrationHistory, emit);
        return;
      }
    }

    // ---- 判定 ----
    final stat = CheckStat.values.firstWhere(
      (s) => s.name == (choiceCheckStat ?? _guessStat(intent)),
      orElse: () => CheckStat.body,
    );
    final dc = choiceCheckDc ?? 50;
    final req = ResolveRequest(
      intent: intent,
      stat: stat,
      dc: dc,
      // 越权尝试不推进时间（Prompt 契约 §2.1）
      timeDays: kind == IntentKind.rejected ? 0 : _guessTimeDays(intent),
      spiritCost: 0,
      repeatCount: book.actionCounts[intent] ?? 0,
    );
    final resolve = Resolver(random: random).resolve(req, state);
    if (resolve.check != null) {
      book.actionCounts[intent] = (book.actionCounts[intent] ?? 0) + 1;
    }

    // ---- 种子与上下文 ----
    final seeds = matchSeeds(bible, state, book);
    final pendingReveals = seeds
        .map((s) => '[${s.id}] ${s.title}：${s.effects.hint}')
        .join('\n');
    if (seeds.isNotEmpty) {
      book.firedSeeds.addAll(seeds.map((s) => s.id));
    }

    final turnsInChapter = state.meta.turnNo + 1;
    final canTurningPoint =
        newTurnNo - book.lastTurningTurn >= 5 && newTurnNo - book.lastTurningTurn <= 8;
    final canChapterEnd = turnsInChapter >= 32 && state.meta.chapter >= 1;

    final systemPrompt =
        '${ironLawSection(bible)}\n\n${worldSection(bible)}\n\n${identitySection(identity)}';
    final memoryState = [
      memorySection(memory),
      if (pendingRepair) '注意：上一回合的状态未结算，请在本回合补上最小可推断的变更。',
      stateSummary(state),
      retrievalSection(bible, state, withPrivate: true),
    ].where((s) => s.isNotEmpty).join('\n\n');

    // ---- 导演 ----
    final directorPrompt = buildDirectorPrompt(
      resolve: resolve,
      intent: kind == IntentKind.rejected ? '（越权尝试）$intent' : intent,
      pendingReveals: pendingReveals,
      memoryAndState: memoryState,
      canTurningPoint: canTurningPoint,
      canChapterEnd: canChapterEnd,
    );
    final directorRes = await gateway.complete(GatewayRequest(
      role: GatewayRole.director,
      system: systemPrompt,
      user: assembleUser(
        sections: [recentSection(narrationHistory), directorPrompt],
        systemTokens: estTokens(systemPrompt),
      ),
      jsonMode: true,
      temperature: 0.7,
      maxTokens: 800,
    ));
    final plan = parseScenePlan(directorRes.text);
    if (plan.beat == Beat.turningPoint && canTurningPoint) {
      book.lastTurningTurn = newTurnNo;
    }

    // ---- 叙事 ----
    final gradeHint = switch (resolve.check?.grade ?? Grade.success) {
      Grade.critical_success => '事情出乎意料地顺利，还多了一分意外之喜',
      Grade.success => '事情办成了',
      Grade.narrow => '事情办成了，但不干净，有代价',
      Grade.fail => '事情没办成，还露了行迹',
      Grade.critical_fail => '事情砸了，并且招来了新的麻烦',
    };
    if (kind == IntentKind.rejected || !resolve.feasible) {
      // 世界内化拒绝：导演已收到 blockedReason，重写一句约束
    }
    final narration = StringBuffer();
    try {
      await for (final delta in gateway.stream(GatewayRequest(
        role: GatewayRole.narrator,
        system: systemPrompt,
        user: assembleUser(
          sections: [
            recentSection(narrationHistory),
            buildNarratorPrompt(
              plan: plan,
              resolve: resolve,
              recentTurns: narrationHistory
                  .map((e) => (e['narration'] ?? '').toString())
                  .join('\n'),
              gradeHint: kind == IntentKind.rejected || !resolve.feasible
                  ? '玩家想做一件这个世界里做不到的事（${resolve.blockedReason ?? '越权'}），写世界自身的回应与代价，不写系统提示式的拒绝'
                  : gradeHint,
            ),
          ],
          systemTokens: estTokens(systemPrompt),
        ),
        temperature: 0.85,
        maxTokens: plan.beat == Beat.chapterEnd ? 1600 : 900,
      ))) {
        narration.write(delta);
        emit(NarrationDelta(delta));
      }
      emit(NarrationEnd());
    } on EngineException catch (e) {
      emit(TurnError(e.code.wireName, e.message, e.canRetry));
      return;
    }

    final narrationText = narration.toString();
    final trimmed = narrationText.length > 1200
        ? narrationText.substring(0, 1200)
        : narrationText;

    // ---- 提取 ----
    StateDelta delta;
    List<Choice> choices = [];
    try {
      final extractorRes = await gateway.complete(GatewayRequest(
        role: GatewayRole.extractor,
        system: systemPrompt,
        user: assembleUser(
          sections: [
            buildExtractorPrompt(
              narration: trimmed,
              plan: plan,
              stateSlice: stateSummary(state),
            )
          ],
          systemTokens: estTokens(systemPrompt),
        ),
        jsonMode: true,
        temperature: 0.2,
        maxTokens: 800,
      ));
      delta = parseExtractorOutput(extractorRes.text);
      final labeled = delta.ops.isEmpty && delta.facts.isEmpty;
      if (!labeled) {
        final choicePairs = _extractChoiceLabels(extractorRes.text);
        var i = 1;
        choices = plan.nextChoices.take(4).map((pc) {
          final label = choicePairs
                  .where((c) => c.$1 == pc.intent)
                  .map((c) => c.$2)
                  .firstOrNull ??
              pc.intent;
          final c = Choice(
            id: 't${newTurnNo}c$i',
            label: label.length > 30 ? label.substring(0, 30) : label,
            intent: pc.intent,
            risk: pc.risk,
            requires: pc.requires,
            hidden: pc.hidden,
          );
          i++;
          return c;
        }).toList();
      }
    } on EngineException catch (e) {
      emit(TurnError(e.code.wireName, e.message, e.canRetry));
      return;
    }

    // ---- 校验与应用 ----
    if (resolve.check != null && resolve.check!.grade == Grade.critical_fail) {
      // 大失败：状态惩罚由导演/提取给出，引擎只兜底
    }
    final applyResult = applyOps(state, delta.ops, bible: bible, runEnded: false);
    for (final r in applyResult.rejected) {
      book.actionCounts.remove(r.op.path);
    }
    // 消耗：时间 + 神识
    final cost = resolve.cost;
    if (cost.timeDays > 0) {
      state.meta.gameTime = advanceGameTime(state.meta.gameTime, cost.timeDays);
    }
    if (cost.spirit > 0) {
      state.character.stats.spirit =
          (state.character.stats.spirit - cost.spirit).clamp(0, 100);
    }
    if (plan.advanceTimeDays != null && plan.advanceTimeDays! > 0) {
      final extra = plan.advanceTimeDays! <= 30 ? plan.advanceTimeDays! : 30.0;
      state.meta.gameTime = advanceGameTime(state.meta.gameTime, extra);
    }
    state.meta.age = state.meta.age; // 年龄增长在 gameTime 跨年时由压缩流程处理

    // facts 入 knowledge 索引用于检索
    for (final f in delta.facts) {
      if (f.isNotEmpty && !state.knowledge.contains(f)) {
        state.knowledge.add(f);
      }
    }
    for (final t in delta.openThreads) {
      if (!state.threads.any((e) => e.id == t.id)) {
        state.threads.add(Thread(
          id: t.id,
          desc: t.desc,
          dueChapter: t.dueChapter,
          status: 'open',
          createdAtTurn: newTurnNo,
        ));
      }
    }
    for (final id in delta.closeThreads) {
      for (final t in state.threads) {
        if (t.id == id) t.status = 'closed';
      }
    }

    // ---- 终局 ----
    EndingRef? ending;
    if (kind != IntentKind.rejected) {
      ending = EndingApplier.checkAndApply(
          bible: bible, state: state, random: random);
    }

    // ---- 回合推进 ----
    state.meta.turnNo = newTurnNo;
    var chapter = state.meta.chapter;
    String? compactJson;
    var chapterEndNow = false;
    if (plan.chapterEnd != null && canChapterEnd) {
      chapterEndNow = true;
      chapter = state.meta.chapter + 1;
      compactJson = await _compact(bible, identity, state, runId);
      state.meta.chapter = chapter;
    }
    state.flags['pendingRepair'] = false;

    // ---- 落库 ----
    // state_patch 只带生效 op（API 参考 §4：数值面板唯一来源）
    final appliedPaths = applyResult.applied.toSet();
    final patchForEvent = StateDelta(
      ops: [
        for (final o in delta.ops)
          if (appliedPaths.contains(o.path)) o,
        if (cost.timeDays > 0)
          Op(op: 'set', path: 'meta.gameTime', value: state.meta.gameTime, reason: '时间流逝'),
      ],
      facts: delta.facts,
      openThreads: delta.openThreads,
      closeThreads: delta.closeThreads,
    );

    final events = <Map<String, Object?>>[
      {'type': 'input', 'payload': input.toJson()},
      if (resolve.check != null && kind != IntentKind.rejected)
        {'type': 'check', 'payload': resolve.toJson()},
      {'type': 'narration', 'payload': {'text': trimmed}, 'fts': trimmed},
      if (choices.isNotEmpty)
        {
          'type': 'choice',
          'payload': {'options': choices.map((c) => c.toJson()).toList()},
        },
      {
        'type': 'delta',
        'payload': {
          'delta': patchForEvent.toJson(),
          'rejected': applyResult.rejected.map((r) => {'path': r.op.path, 'reason': r.reason}).toList(),
        },
      },
      if (chapterEndNow && compactJson != null)
        {'type': 'compact', 'payload': {'memory': jsonDecode(compactJson)}},
      if (ending != null) {'type': 'system', 'payload': {'ending': ending.toJson()}},
      {
        'type': 'system',
        'payload': {
          'roles': ['classifier', 'director', 'narrator', 'extractor'],
          'promptVersion': 'v0',
          'turn': newTurnNo,
        },
      },
    ];

    String? snapshotId;
    try {
      snapshotId = await dao.commitTurn(
        runId: runId,
        stateAfter: state,
        chapter: chapter,
        memory: book.encode(compactJson),
        eventPayloads: events,
      );
    } catch (e) {
      emit(TurnError(EngineCode.stateInvalid.wireName, '落库失败：$e', true));
      return;
    }

    if (choices.isNotEmpty) emit(ChoicesAvailable(choices));
    emit(StatePatch(patchForEvent));
    emit(TurnEnd(newTurnNo, snapshotId, ending));
  }

  Future<(IntentKind, String)> _classify(
    WorldBible bible,
    RunState state,
    String text,
  ) async {
    try {
      final system =
          '${ironLawSection(bible)}\n\n${buildClassifierPrompt(placeName: state.location.placeId, presentNpcs: state.relations.keys.take(3).toList(), knowledgeTop5: state.knowledge.take(5).toList(), input: text)}';
      final res = await gateway.complete(GatewayRequest(
        role: GatewayRole.classifier,
        system: system,
        user: assembleUser(sections: [stateSummary(state)], systemTokens: estTokens(system)),
        jsonMode: true,
        temperature: 0.1,
        maxTokens: 120,
      ));
      final m = extractJson(res.text);
      if (m == null) return (IntentKind.action, text);
      final kind = parseKind(m['kind']);
      final intent = asSOr(m['intent'], text);
      return (kind, intent);
    } on EngineException {
      // 分类失败一律按 action 处理
      return (IntentKind.action, text);
    }
  }

  Future<void> _answerQuery(
    WorldBible bible,
    Identity identity,
    RunState state,
    String question,
    List<Map<String, Object?>> narrationHistory,
    void Function(TurnEvent) emit,
  ) async {
    final system =
        '${ironLawSection(bible)}\n\n${buildCompanionPrompt(knowledge: state.knowledge.join('；'), stateSummary: stateSummary(state), recentTurns: narrationHistory.map((e) => (e['narration'] ?? '').toString()).join('\n'), question: question)}';
    try {
      await for (final delta in gateway.stream(GatewayRequest(
        role: GatewayRole.companion,
        system: system,
        user: question,
        temperature: 0.6,
        maxTokens: 400,
      ))) {
        emit(NarrationDelta(delta));
      }
    } on EngineException {
      emit(NarrationDelta(companionFallback));
    }
    emit(NarrationEnd());
    emit(TurnEnd(state.meta.turnNo, null, null));
  }

  Future<String> _compact(
    WorldBible bible,
    Identity identity,
    RunState state,
    String runId,
  ) async {
    try {
      final rows = await (db.select(db.runEvents)
            ..where((e) => e.runId.equals(runId) & e.type.equals('narration'))
            ..orderBy([(e) => OrderingTerm.desc(e.seq)])
            ..limit(20))
          .get();
      final narrations = rows
          .map((r) => ((jsonDecode(r.payload) as Map)['text'] ?? '').toString())
          .toList();
      final facts = state.threads
          .where((t) => t.status == 'open')
          .map((t) => t.desc)
          .toList();
      final system = '你是卷末压缩器。只输出一个 JSON 对象。';
      final res = await gateway.complete(GatewayRequest(
        role: GatewayRole.compress,
        system: system,
        user: assembleUser(
          sections: [
            buildCompactPrompt(
              volumeSummary: bible.meta.volumeHint,
              turnFacts: facts,
              recentNarrations: narrations.reversed.toList(),
              stateSummary: stateSummary(state),
            )
          ],
          systemTokens: estTokens(system),
        ),
        jsonMode: true,
        temperature: 0.3,
        maxTokens: 900,
      ));
      final m = extractJson(res.text);
      if (m == null) return CompactMemory().encode();
      final mem = CompactMemory(
        facts: asList<String>(m['facts'], (e) => asSOr(e, '')).take(12).toList(),
        relationChanges:
            asList<String>(m['relationChanges'], (e) => asSOr(e, '')).take(8).toList(),
        openThreads: asList<String>(m['openThreads'], (e) => asSOr(e, '')).take(8).toList(),
        volumeSummary: asSOr(m['volumeSummary'], ''),
      );
      return mem.encode();
    } on EngineException {
      return CompactMemory().encode();
    }
  }

  Future<List<Map<String, Object?>>> _recentNarrations(
    String runId,
    int limit,
  ) async {
    final rows = await (db.select(db.runEvents)
          ..where((e) => e.runId.equals(runId) & e.type.equals('narration'))
          ..orderBy([(e) => OrderingTerm.desc(e.seq)])
          ..limit(limit))
        .get();
    return rows.reversed.map((r) {
      final p = jsonDecode(r.payload);
      return {
        'turn': r.turnNo,
        'narration': p is Map ? (p['text'] ?? '').toString() : '',
      };
    }).toList();
  }

  List<(String, String)> _extractChoiceLabels(String extractorText) {
    final m = extractJson(extractorText);
    if (m == null) return [];
    return asList<Object?>(m['choices'], (e) => e)
        .map((e) {
          if (e is Map) {
            return (asSOr(e['intent'], ''), asSOr(e['label'], ''));
          }
          return ('', '');
        })
        .where((p) => p.$1.isNotEmpty && p.$2.isNotEmpty)
        .toList();
  }
}

String _guessStat(String intent) {
  if (RegExp(r'斗|战|杀|打|躲|逃|爬|扛').hasMatch(intent)) return 'body';
  if (RegExp(r'查|探|听|观|感|悟|识|推|算|炼|画|读').hasMatch(intent)) return 'spirit';
  return 'body';
}

double _guessTimeDays(String intent) {
  if (RegExp(r'闭关|苦修|修炼').hasMatch(intent)) return 30;
  if (RegExp(r'去|探|寻|访|行|赶').hasMatch(intent)) return 2;
  return 1;
}
