import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_mobile/app/providers.dart';
import 'package:wayfarer_mobile/app/router.dart';
import 'package:wayfarer_mobile/core/security/local_data_reset.dart';
import 'package:wayfarer_mobile/core/security/secure_key_store.dart';
import 'package:wayfarer_mobile/features/settings/data_management_page.dart';
import 'package:wayfarer_mobile/features/settings/privacy_page.dart';
import 'package:wayfarer_mobile/features/settings/settings_page.dart';
import 'package:wayfarer_mobile/features/worlds/worlds_page.dart';
import 'package:wayfarer_mobile/main.dart';

const _paths = MethodChannel('plugins.flutter.io/path_provider');
const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
const _agePrompt = '开始之前，请确认你的年龄';
const _locked = '等待冷启动清理';

// SQLite isolate I/O needs real async time rather than pumpAndSettle alone.
Future<void> _until(
  WidgetTester tester,
  bool Function() ready,
  String description,
) async {
  final deadline = Stopwatch()..start();
  while (!ready()) {
    if (deadline.elapsed > const Duration(seconds: 15)) {
      fail('Timed out waiting for $description');
    }
    await tester.pump(const Duration(milliseconds: 20));
    // Yield to file I/O / isolate messages, rather than advancing fake time.
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await tester.pump();
  expect(tester.takeException(), isNull);
}

Future<void> _shown(WidgetTester tester, Finder finder) async {
  await _until(tester, () => finder.evaluate().isNotEmpty, finder.toString());
  await tester.pump(const Duration(milliseconds: 350));
}

void _noBusiness() {
  expect(find.byType(WorldsPage, skipOffstage: false), findsNothing);
  expect(find.byType(SettingsPage, skipOffstage: false), findsNothing);
  expect(find.byType(DataManagementPage, skipOffstage: false), findsNothing);
  expect(find.byType(ProviderScope, skipOffstage: false), findsNothing);
}

class _Sandbox {
  _Sandbox(this.root);

  final Directory root;
  late final docs = Directory('${root.path}/docs');
  late final support = Directory('${root.path}/support');
  late final temp = Directory('${root.path}/temp');
  late final external = Directory('${root.path}/external');
  late final database = File('${docs.path}/wayfarer.db');
  late final marker = File('${support.path}/wayfarer_reset_pending');
  late final userFile = File('${docs.path}/imports/user-copy.txt');
  late final cache = File('${temp.path}/diagnostics.json');
  late final untouched = File('${support.path}/unrelated.txt');
  final engines = <Engine>[];
  final pathCalls = <String>[];
  final keyCalls = <String>[];
  final clears = <({bool pending, bool database, bool userFile})>[];
  String? key = 'synthetic-test-key-never-a-real-credential';
  bool failClear = false;
  Completer<void>? clearBarrier;

  Future<void> install() async {
    for (final directory in [docs, support, temp, external]) {
      await directory.create();
    }
    await untouched.writeAsString('keep support sibling', flush: true);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_paths, (call) async {
      pathCalls.add(call.method);
      // Unknown paths must not fall through to a host plugin.
      return switch (call.method) {
        'getApplicationDocumentsDirectory' => docs.path,
        'getApplicationSupportDirectory' => support.path,
        'getTemporaryDirectory' || 'getApplicationCacheDirectory' => temp.path,
        'getStorageDirectory' => external.path,
        _ => throw MissingPluginException(
          'Unexpected path call: ${call.method}',
        ),
      };
    });
    messenger.setMockMethodCallHandler(_secureStorage, (call) async {
      keyCalls.add(call.method);
      expect((call.arguments as Map)['key'], 'wayfarer.model_key');
      switch (call.method) {
        case 'read':
          return key;
        case 'write':
          key = (call.arguments as Map)['value'] as String;
          return null;
        case 'delete':
          clears.add((
            pending: marker.existsSync(),
            database: database.existsSync(),
            userFile: userFile.existsSync(),
          ));
          if (failClear) {
            throw PlatformException(
              code: 'test_key_clear_failed',
              message: 'Synthetic secure storage deletion failure',
            );
          }
          await clearBarrier?.future;
          key = null;
          return null;
        default:
          throw MissingPluginException('Unexpected key call: ${call.method}');
      }
    });
  }

  Future<void> boot(WidgetTester tester) async {
    appRouter.go('/');
    await tester.pumpWidget(BootstrapApp(key: UniqueKey()));
  }

  Future<Engine> enterWorlds(WidgetTester tester) async {
    await _shown(tester, find.byType(WorldsPage));
    final engine = ProviderScope.containerOf(
      tester.element(find.byType(WorldsPage)),
    ).read(engineProvider);
    if (!engines.contains(engine)) engines.add(engine);
    final worlds = await engine.listWorlds();
    expect(worlds, hasLength(1));
    await _shown(tester, find.text(worlds.single.title));
    expect(engine.filesDir, Platform.isAndroid ? external.path : docs.path);
    return engine;
  }

  Future<Engine> acceptAndEnter(WidgetTester tester) async {
    await _shown(tester, find.byType(PrivacyPage));
    _noBusiness();
    expect(find.text(_agePrompt), findsNothing);
    await tester.scrollUntilVisible(find.byType(CheckboxListTile), 500);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('同意并继续'));
    await tester.tap(find.text('同意并继续'));
    await _shown(tester, find.text(_agePrompt));
    expect(find.byType(PrivacyPage), findsNothing);
    _noBusiness();
    await tester.tap(find.text('我已满 18 周岁'));
    return enterWorlds(tester);
  }

  Future<void> coldStop(WidgetTester tester) async {
    // Explicitly close engines to model process termination after unmounting.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    for (final engine in engines) {
      await engine.close();
    }
    engines.clear();
    appRouter.go('/');
    await tester.pump();
  }

  Future<void> addOldData(Engine engine) async {
    await engine.writeAppSetting(
      'bootstrap_test_user_data',
      'old-installation',
    );
    await engine.keyStore.write('synthetic-old-installation-key');
    await userFile.parent.create(recursive: true);
    await userFile.writeAsString('old imported copy', flush: true);
    await cache.writeAsString('old diagnostic cache', flush: true);
    // Missing seed exposes an accidental Engine.open before reset succeeds.
    await engine.db.customStatement('DELETE FROM world_versions');
    await engine.db.customStatement('DELETE FROM worlds');
    expect(await engine.listWorlds(), isEmpty);
  }

  Future<void> schedule() => LocalDataReset(
    marker: marker,
    dataDirectories: [docs, temp, if (Platform.isAndroid) external],
    keyStore: SecureKeyStore(),
  ).schedule();

  Future<void> expectRestored(Engine engine) async {
    expect(await engine.readAppSetting('bootstrap_test_user_data'), isNull);
    final rows = await engine.db.select(engine.db.worldVersions).get();
    expect(rows, hasLength(1));
    final seed = rows.single;
    expect(seed.worldId, 'w_cangwu');
    // Normalize asset defaults through contracts, just as Engine import does.
    final bible = WorldBible.fromJson(
      jsonDecode(await rootBundle.loadString('assets/seed/cangwu/bible.json')),
    );
    final identities =
        (jsonDecode(
                  await rootBundle.loadString(
                    'assets/seed/cangwu/identities.json',
                  ),
                )
                as List)
            .map((value) => Identity.fromJson(value).toJson())
            .toList();
    final seeds =
        (jsonDecode(
                  await rootBundle.loadString('assets/seed/cangwu/seeds.json'),
                )
                as List)
            .map((value) => EventSeed.fromJson(value).toJson())
            .toList();
    expect(jsonDecode(seed.bible), bible.toJson());
    expect(jsonDecode(seed.identities), identities);
    expect(jsonDecode(seed.seeds), seeds);
    final world = (await engine.listWorlds()).single;
    expect(world.source, 'builtin');
    expect(world.exportable, isFalse);
    expect(await untouched.readAsString(), 'keep support sibling');
  }

  Future<void> dispose(WidgetTester tester) async {
    clearBarrier?.completeIfPending();
    await coldStop(tester);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_paths, null);
    messenger.setMockMethodCallHandler(_secureStorage, null);
    await root.delete(recursive: true);
  }
}

extension on Completer<void> {
  void completeIfPending() {
    if (!isCompleted) complete();
  }
}

Future<void> _inSandbox(
  WidgetTester tester,
  Future<void> Function(_Sandbox sandbox) test,
) async {
  await tester.runAsync(() async {
    final sandbox = _Sandbox(
      await Directory.systemTemp.createTemp('bootstrap_privacy_reset_test_'),
    );
    try {
      await sandbox.install();
      await test(sandbox);
      expect(tester.takeException(), isNull);
    } finally {
      await sandbox.dispose(tester);
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('真实首启：拒绝阻止业务，同意后年龄门，冷启动不重复告知', (tester) async {
    await _inSandbox(tester, (sandbox) async {
      await sandbox.boot(tester);
      await _shown(tester, find.byType(PrivacyPage));
      _noBusiness();
      expect(find.text(_agePrompt), findsNothing);
      await tester.scrollUntilVisible(find.byType(CheckboxListTile), 500);
      final accept = find.widgetWithText(FilledButton, '同意并继续');
      expect(tester.widget<FilledButton>(accept).onPressed, isNull);
      await tester.scrollUntilVisible(find.text('不同意，暂不使用'), 200);
      await tester.tap(find.text('不同意，暂不使用'));
      await _shown(tester, find.text('未同意数据告知，暂不进入应用。'));
      expect(find.byType(PrivacyPage), findsNothing);
      expect(find.text(_agePrompt), findsNothing);
      _noBusiness();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('未同意数据告知，暂不进入应用。'), findsOneWidget);
      _noBusiness();

      await tester.tap(find.text('重新阅读'));
      final first = await sandbox.acceptAndEnter(tester);
      expect(
        await first.readAppSetting('privacy_notice_version'),
        privacyNoticeVersion,
      );
      expect(await first.readAppSetting(AppFlags.ageGate), 'adult');
      expect(await first.isTeenMode(), isFalse);
      await sandbox.expectRestored(first);
      expect(sandbox.database.existsSync(), isTrue);
      expect(sandbox.keyCalls, ['delete']);
      final clears = sandbox.clears.length;
      await sandbox.coldStop(tester);

      await sandbox.boot(tester);
      final second = await sandbox.enterWorlds(tester);
      expect(second, isNot(same(first)));
      expect(find.byType(PrivacyPage, skipOffstage: false), findsNothing);
      expect(find.text(_agePrompt, skipOffstage: false), findsNothing);
      expect(
        await second.readAppSetting('privacy_notice_version'),
        privacyNoticeVersion,
      );
      expect(await second.readAppSetting(AppFlags.ageGate), 'adult');
      expect(sandbox.clears.length, clears);
      expect(
        sandbox.pathCalls.where(
          (call) => call == 'getApplicationDocumentsDirectory',
        ),
        hasLength(2),
      );
    });
  });

  for (final invalidDirectory in [false, true]) {
    testWidgets(
      '已安排 reset 冷启动：${invalidDirectory ? '数据目录非法' : 'Key clear 失败'}阻止启动，修复重试先清理再恢复 seed',
      (tester) async {
        await _inSandbox(tester, (sandbox) async {
          await sandbox.boot(tester);
          final old = await sandbox.acceptAndEnter(tester);
          await sandbox.addOldData(old);
          await sandbox.schedule();
          await sandbox.coldStop(tester);
          final originalDb = await sandbox.database.readAsBytes();
          final oldClears = sandbox.clears.length;
          if (invalidDirectory) {
            await sandbox.temp.delete(recursive: true);
            await File(sandbox.temp.path).writeAsString('not a directory');
          } else {
            sandbox.failClear = true;
          }

          await sandbox.boot(tester);
          await _shown(tester, find.text('启动失败'));
          expect(
            find.textContaining(
              invalidDirectory
                  ? 'Expected a data directory'
                  : 'test_key_clear_failed',
            ),
            findsOneWidget,
          );
          _noBusiness();
          expect(find.byType(PrivacyPage), findsNothing);
          expect(find.text(_agePrompt), findsNothing);
          expect(await sandbox.marker.readAsString(), 'pending');
          expect(File('${sandbox.marker.path}.tmp').existsSync(), isFalse);
          // Engine.open would reinstall the seed and change these bytes.
          expect(await sandbox.database.readAsBytes(), originalDb);
          expect(await sandbox.userFile.readAsString(), 'old imported copy');
          expect(sandbox.key, 'synthetic-old-installation-key');
          expect(sandbox.clears.length, oldClears + (invalidDirectory ? 0 : 1));
          if (invalidDirectory) {
            expect(
              await File(sandbox.temp.path).readAsString(),
              'not a directory',
            );
            await File(sandbox.temp.path).delete();
            await sandbox.temp.create();
            await sandbox.cache.writeAsString('old diagnostic cache');
          } else {
            expect(await sandbox.cache.readAsString(), 'old diagnostic cache');
          }

          sandbox.failClear = false;
          final retryClears = sandbox.clears.length;
          final barrier = Completer<void>();
          sandbox.clearBarrier = barrier;
          await tester.tap(find.text('重试'));
          await _until(
            tester,
            () => sandbox.clears.length > retryClears,
            'retry to reach secure-storage deletion',
          );
          expect(find.text('正在打开世界……'), findsOneWidget);
          expect(find.byType(PrivacyPage), findsNothing);
          _noBusiness();
          expect(await sandbox.database.readAsBytes(), originalDb);
          expect(sandbox.userFile.existsSync(), isTrue);
          expect(sandbox.marker.existsSync(), isTrue);
          expect(sandbox.clears.last, (
            pending: true,
            database: true,
            userFile: true,
          ));
          sandbox.clearBarrier = null;
          barrier.complete();

          await _shown(tester, find.byType(PrivacyPage));
          expect(find.text('启动失败'), findsNothing);
          expect(find.text(_agePrompt), findsNothing);
          _noBusiness();
          expect(sandbox.marker.existsSync(), isFalse);
          expect(sandbox.userFile.existsSync(), isFalse);
          expect(await sandbox.temp.list().toList(), isEmpty);
          expect(sandbox.key, isNull);
          // Fresh-install key cleanup precedes creation of the new SQLite.
          expect(sandbox.clears.skip(retryClears).toList(), [
            (pending: true, database: true, userFile: true),
            (pending: false, database: false, userFile: false),
          ]);
          expect(sandbox.database.existsSync(), isTrue);
          final restored = await sandbox.acceptAndEnter(tester);
          await sandbox.expectRestored(restored);
        });
      },
    );
  }

  testWidgets('真实数据管理确认 reset 锁定会话，系统返回不能恢复业务，冷启动执行清理', (tester) async {
    await _inSandbox(tester, (sandbox) async {
      await sandbox.boot(tester);
      final engine = await sandbox.acceptAndEnter(tester);
      await sandbox.addOldData(engine);
      final clearCount = sandbox.clears.length;
      await tester.tap(find.byTooltip('设置'));
      await _shown(tester, find.byType(SettingsPage));
      await tester.scrollUntilVisible(
        find.text('数据管理'),
        350,
        scrollable: find
            .descendant(
              of: find.byType(SettingsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('数据管理'));
      await _shown(tester, find.byType(DataManagementPage));
      final reset = find.widgetWithText(OutlinedButton, '清空全部数据');
      await tester.scrollUntilVisible(
        reset,
        350,
        scrollable: find.descendant(
          of: find.byType(DataManagementPage),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(reset);
      await _shown(tester, find.text('清空全部本机数据？'));
      expect(sandbox.marker.existsSync(), isFalse);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(sandbox.marker.existsSync(), isFalse);
      expect(find.byType(DataManagementPage), findsOneWidget);
      await tester.tap(reset);
      await _shown(tester, find.text('清空全部本机数据？'));
      await tester.tap(find.text('确认，重启后清空'));
      await _shown(tester, find.text(_locked));
      expect(await sandbox.marker.readAsString(), 'pending');
      expect(File('${sandbox.marker.path}.tmp').existsSync(), isFalse);
      expect(sandbox.clears.length, clearCount);
      expect(sandbox.key, 'synthetic-old-installation-key');
      expect(await sandbox.userFile.readAsString(), 'old imported copy');
      expect(await sandbox.cache.readAsString(), 'old diagnostic cache');
      expect(
        await engine.readAppSetting('bootstrap_test_user_data'),
        'old-installation',
      );
      expect(await engine.listWorlds(), isEmpty);
      _noBusiness();
      expect(
        ModalRoute.of(tester.element(find.text(_locked)))!.popDisposition,
        RoutePopDisposition.doNotPop,
      );
      for (var i = 0; i < 2; i++) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text(_locked), findsOneWidget);
        expect(find.byType(PrivacyPage), findsNothing);
        expect(find.text(_agePrompt), findsNothing);
        _noBusiness();
      }
      expect(sandbox.marker.existsSync(), isTrue);
      expect(sandbox.clears.length, clearCount);

      await sandbox.coldStop(tester);
      await sandbox.boot(tester);
      await _shown(tester, find.byType(PrivacyPage));
      expect(find.text(_locked), findsNothing);
      expect(sandbox.marker.existsSync(), isFalse);
      expect(sandbox.userFile.existsSync(), isFalse);
      expect(sandbox.cache.existsSync(), isFalse);
      expect(sandbox.key, isNull);
      final restored = await sandbox.acceptAndEnter(tester);
      await sandbox.expectRestored(restored);
    });
  });
}
