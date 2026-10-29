import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_mobile/core/security/secure_key_store.dart';
import 'package:wayfarer_mobile/main.dart';

const _localData = MethodChannel('wayfarer/local_data');
const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(_localData, null);
    messenger.setMockMethodCallHandler(_secureStorage, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'backup exclusion sends no paths and waits for native completion',
    () async {
      final entered = Completer<void>();
      final completed = Completer<void>();
      addTearDown(() {
        if (!completed.isCompleted) completed.complete();
      });
      messenger.setMockMethodCallHandler(_localData, (call) async {
        expect(call.method, 'excludeFromBackup');
        expect(call.arguments, isNull);
        entered.complete();
        await completed.future;
        return null;
      });

      var returned = false;
      final pending = excludeIosDataFromBackup().then((_) => returned = true);
      await entered.future;
      expect(returned, isFalse);
      completed.complete();
      await pending;
      expect(returned, isTrue);
    },
  );

  test(
    'backup exclusion propagates native failure and can be retried',
    () async {
      var attempts = 0;
      messenger.setMockMethodCallHandler(_localData, (call) async {
        if (++attempts == 1) {
          throw PlatformException(
            code: 'backup_exclusion_failed',
            message: 'Synthetic directory failure',
          );
        }
        return null;
      });

      await expectLater(
        excludeIosDataFromBackup(),
        throwsA(
          isA<PlatformException>()
              .having((error) => error.code, 'code', 'backup_exclusion_failed')
              .having(
                (error) => error.message,
                'message',
                'Synthetic directory failure',
              ),
        ),
      );
      await excludeIosDataFromBackup();
      expect(attempts, 2);
    },
  );

  test('missing native backup channel is not silently ignored', () async {
    await expectLater(
      excludeIosDataFromBackup(),
      throwsA(isA<MissingPluginException>()),
    );
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final injected in [false, true]) {
      test(
        '${platform.name} key options remain consistent (injected=$injected)',
        () async {
          debugDefaultTargetPlatformOverride = platform;
          final calls = <MethodCall>[];
          messenger.setMockMethodCallHandler(_secureStorage, (call) async {
            calls.add(call);
            return call.method == 'read' ? 'synthetic-test-key' : null;
          });
          final store = SecureKeyStore(
            storage: injected
                ? const FlutterSecureStorage(
                    iOptions: IOSOptions(synchronizable: true),
                  )
                : null,
          );

          expect(await store.read(), 'synthetic-test-key');
          await store.write('synthetic-replacement-key');
          await store.clear();

          expect(calls.map((call) => call.method), ['read', 'write', 'delete']);
          final expectedOptions = platform == TargetPlatform.iOS
              ? const IOSOptions(
                  accessibility: KeychainAccessibility.first_unlock_this_device,
                  synchronizable: false,
                ).params
              : const FlutterSecureStorage().aOptions.params;
          for (final call in calls) {
            final arguments = call.arguments as Map;
            expect(arguments['key'], 'wayfarer.model_key');
            expect(arguments['options'], expectedOptions);
          }
          expect(
            (calls[1].arguments as Map)['value'],
            'synthetic-replacement-key',
          );
        },
      );
    }
  }
}
