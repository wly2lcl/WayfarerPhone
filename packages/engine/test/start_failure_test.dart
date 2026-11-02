// 开局失败清理单测：序章生成失败时不得留下 turn 0 空局（我的局列表不可见）。
import 'dart:convert';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '../test/helpers.dart';

class FailingPrologueGateway implements ModelGateway {
  int calls = 0;

  @override
  GatewayConfig get config => GatewayConfig(
        settings: () => ModelSettings(
          protocol: LlmProtocol.openai_chat,
          baseUrl: 'https://fake.local/v1',
          narrativeModel: 'fake-narrator',
          smallModel: 'fake-small',
        ),
        keyStore: InMemoryKeyStore(),
      );

  @override
  Future<GatewayResult> complete(GatewayRequest req) async {
    calls++;
    if (calls == 1) {
      throw EngineException(EngineCode.modelNetwork, '序章生成失败');
    }
    return GatewayResult(
      text: '你在药庐外的走廊上醒来。晨雾还没散。',
      tokensIn: 10,
      tokensOut: 10,
      estimated: true,
      ms: 1,
      model: 'fake-model',
    );
  }

  @override
  Stream<dynamic> stream(GatewayRequest req) async* {
    throw EngineException(EngineCode.modelNetwork, '序章生成失败');
  }

  @override
  Future<ConnectionReport> testConnection() async =>
      throw UnimplementedError('测试不做真实连接');
}

void main() {
  test('序章生成失败不残留 turn 0 空局', () async {
    final tmp = await Directory.systemTemp.createTemp('wf_start_failure');
    final seedDir = '$kSeedDir';
    final bible = loadBible();
    final identities = asList<Identity>(
        jsonDecode(File('$seedDir/identities.json').readAsStringSync()),
        Identity.fromJson);
    final seeds = asList<EventSeed>(
        jsonDecode(File('$seedDir/seeds.json').readAsStringSync()),
        EventSeed.fromJson);

    final engine = await Engine.open(
      dbPath: '${tmp.path}/app.db',
      keyStore: InMemoryKeyStore(),
      builtinSeed: SeedData(
        bible: bible,
        identities: identities,
        seeds: seeds,
        volumeJson: File('$seedDir/volume1.json').readAsStringSync(),
      ),
      random: SeqRandom([1, 2, 3]),
      gatewayFactory: (_) => FailingPrologueGateway(),
    );
    addTearDown(() async {
      await engine.close();
      await tmp.delete(recursive: true);
    });

    final draw = await engine.draw('w_cangwu');
    await expectLater(
      engine.create(
        worldId: 'w_cangwu',
        identityId: draw.identities.first.id,
        drawToken: draw.drawToken,
      ),
      throwsA(isA<EngineException>()),
    );

    expect(await engine.listRuns(), isEmpty, reason: '失败开局不得出现在我的局');
    expect(await engine.db.select(engine.db.runEvents).get(), isEmpty,
        reason: '失败开局不得留下事件');
    expect(await engine.db.select(engine.db.runSnapshots).get(), isEmpty,
        reason: '失败开局不得留下快照');
    expect(
        (await engine.db.select(engine.db.localEvents).get())
            .where((e) => e.runId != null),
        isEmpty,
        reason: '失败开局不得留下本地诊断事件');

    // 同一 drawToken 可原地重试，第二次成功且只留一局
    final retry = await engine.create(
      worldId: 'w_cangwu',
      identityId: draw.identities.first.id,
      drawToken: draw.drawToken,
    );
    expect(retry.prologue, contains('药庐'));
    expect(await engine.listRuns(), hasLength(1));
  });
}
