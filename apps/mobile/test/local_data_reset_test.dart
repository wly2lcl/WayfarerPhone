import 'dart:convert';
import 'dart:io';

import 'package:engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_mobile/core/security/local_data_reset.dart';

class _TestKeyStore implements KeyStore {
  String? value = 'test-model-key';
  bool failClear = false;
  int clearCalls = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String key) async => value = key;

  @override
  Future<void> clear() async {
    clearCalls++;
    if (failClear) throw StateError('Key clear failed');
    value = null;
  }
}

class _FailAfterWriteFile implements File {
  _FailAfterWriteFile(this.delegate);

  final File delegate;

  @override
  Future<File> writeAsString(String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    await delegate.writeAsString(contents, mode: mode, encoding: encoding, flush: flush);
    throw const FileSystemException('simulated flush failure after write');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<File> _write(
  Directory directory,
  String name, [
  String content = 'data',
]) async {
  final file = File('${directory.path}/$name');
  await file.parent.create(recursive: true);
  return file.writeAsString(content, flush: true);
}

void main() {
  late Directory sandbox;
  late Directory documents;
  late Directory temporary;
  late Directory external;
  late List<Directory> dataDirectories;
  late File marker;
  late _TestKeyStore keyStore;
  late LocalDataReset reset;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('local_data_reset_test_');
    documents = await Directory('${sandbox.path}/docs').create();
    temporary = await Directory('${sandbox.path}/temp').create();
    external = await Directory('${sandbox.path}/external').create();
    dataDirectories = [documents, temporary, external];
    marker = File('${sandbox.path}/support/wayfarer_reset_pending');
    keyStore = _TestKeyStore();
    reset = LocalDataReset(
      marker: marker,
      dataDirectories: dataDirectories,
      keyStore: keyStore,
    );
  });

  tearDown(() async {
    await sandbox.delete(recursive: true);
  });

  test('without a pending marker nothing changes', () async {
    final files = [
      await _write(documents, 'app.db'),
      await _write(temporary, 'cache/item'),
      await _write(external, 'exports/world.zip'),
    ];

    expect(await reset.applyPending(), isFalse);

    for (final file in files) {
      expect(await file.readAsString(), 'data');
    }
    expect(await marker.parent.exists(), isFalse);
    expect(await keyStore.read(), 'test-model-key');
    expect(keyStore.clearCalls, 0);
  });

  test('schedule creates the marker without clearing data or keys', () async {
    final database = await _write(documents, 'app.db');
    expect(await marker.parent.exists(), isFalse);

    await reset.schedule();
    await reset.schedule();

    expect(await marker.readAsString(), 'pending');
    expect(await database.readAsString(), 'data');
    expect(await keyStore.read(), 'test-model-key');
    expect(keyStore.clearCalls, 0);
  });

  test('write failure after file creation never publishes a reset marker', () async {
    final database = await _write(documents, 'app.db');
    final temporary = File('${marker.path}.tmp');
    await expectLater(
      IOOverrides.runZoned(
        reset.schedule,
        createFile: (path) => _FailAfterWriteFile(temporary),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await temporary.exists(), isTrue);
    expect(await marker.exists(), isFalse);
    final laterData = await _write(documents, 'new.db');
    expect(await reset.applyPending(), isFalse);
    expect(await database.exists(), isTrue);
    expect(await laterData.exists(), isTrue);
    expect(keyStore.clearCalls, 0);
    await reset.schedule();
    expect(await temporary.exists(), isFalse);
    expect(await reset.applyPending(), isTrue);
  });

  test('a failed marker write is not reported as scheduled', () async {
    final database = await _write(documents, 'app.db');
    await Directory(marker.path).create(recursive: true);

    await expectLater(reset.schedule(), throwsA(isA<FileSystemException>()));

    expect(await database.readAsString(), 'data');
    expect(await keyStore.read(), 'test-model-key');
    expect(keyStore.clearCalls, 0);
    expect(await marker.exists(), isFalse);
  });

  test(
    'a failed marker parent creation is not reported as scheduled',
    () async {
      await marker.parent.parent.create(recursive: true);
      await File(marker.parent.path).writeAsString('blocked');

      await expectLater(reset.schedule(), throwsA(isA<FileSystemException>()));

      expect(await marker.exists(), isFalse);
      expect(await keyStore.read(), 'test-model-key');
      expect(keyStore.clearCalls, 0);
    },
  );

  test(
    'cold-start reset clears all sandbox data and keys, not source originals',
    () async {
      final original = await _write(
        Directory('${sandbox.path}/user-originals'),
        'world.zip',
        'user original',
      );
      final supportFile = await _write(marker.parent, 'unrelated', 'keep');
      await _write(documents, 'app.db', 'sourcePath=${original.path}');
      await _write(documents, 'app.db-wal');
      await _write(documents, 'app.db-shm');
      await _write(documents, 'imports/world.zip');
      await _write(documents, 'feedback/report.json');
      await _write(temporary, 'diagnostics/report.log');
      await _write(temporary, 'cache/nested/item');
      await _write(external, 'exports/world.zip');
      await reset.schedule();

      final coldStartReset = LocalDataReset(
        marker: marker,
        dataDirectories: dataDirectories,
        keyStore: keyStore,
      );
      expect(await coldStartReset.applyPending(), isTrue);

      for (final directory in dataDirectories) {
        expect(await directory.exists(), isTrue);
        expect(await directory.list().toList(), isEmpty);
      }
      expect(await keyStore.read(), isNull);
      expect(keyStore.clearCalls, 1);
      expect(await marker.exists(), isFalse);
      expect(await original.readAsString(), 'user original');
      expect(await supportFile.readAsString(), 'keep');
    },
  );

  test(
    'links are removed without following file, directory, or dangling targets',
    () async {
      final original = await _write(
        Directory('${sandbox.path}/user-originals'),
        'world.zip',
        'user original',
      );
      final nested = await Directory(
        '${documents.path}/imports/nested',
      ).create(recursive: true);
      final links = [
        Link('${documents.path}/directory-link'),
        Link('${nested.path}/file-link'),
        Link('${nested.path}/dangling-link'),
        Link('${documents.path}/self-link'),
      ];
      await links[0].create(original.parent.path);
      await links[1].create(original.path);
      await links[2].create('${sandbox.path}/missing-target');
      await links[3].create(documents.path);
      await reset.schedule();

      expect(await reset.applyPending(), isTrue);

      expect(await original.readAsString(), 'user original');
      expect(await original.parent.list().length, 1);
      expect(await documents.exists(), isTrue);
      expect(await documents.list().toList(), isEmpty);
      for (final link in links) {
        expect(
          await FileSystemEntity.type(link.path, followLinks: false),
          FileSystemEntityType.notFound,
        );
      }
      expect(await keyStore.read(), isNull);
      expect(await marker.exists(), isFalse);
    },
  );

  test('repeated apply is a no-op and preserves newly created data', () async {
    await _write(documents, 'app.db');
    await reset.schedule();
    expect(await reset.applyPending(), isTrue);
    final newDatabase = await _write(documents, 'app.db', 'new data');
    await keyStore.write('new-key');

    expect(await reset.applyPending(), isFalse);

    expect(await newDatabase.readAsString(), 'new data');
    expect(await keyStore.read(), 'new-key');
    expect(keyStore.clearCalls, 1);
  });

  test(
    'key failure retains marker and all data until a successful retry',
    () async {
      final files = [
        await _write(documents, 'app.db'),
        await _write(documents, 'app.db-wal'),
        await _write(temporary, 'cache/item'),
        await _write(external, 'exports/world.zip'),
      ];
      await reset.schedule();
      keyStore.failClear = true;

      await expectLater(reset.applyPending(), throwsStateError);

      expect(await marker.readAsString(), 'pending');
      expect(await keyStore.read(), 'test-model-key');
      for (final file in files) {
        expect(await file.readAsString(), 'data');
      }

      keyStore.failClear = false;
      expect(await reset.applyPending(), isTrue);
      expect(await keyStore.read(), isNull);
      expect(keyStore.clearCalls, 2);
      expect(await marker.exists(), isFalse);
      for (final directory in dataDirectories) {
        expect(await directory.list().toList(), isEmpty);
      }
    },
  );

  test(
    'duplicate, nested, and missing roots are handled without removing roots',
    () async {
      final nested = await Directory(
        '${documents.path}/imports/nested',
      ).create(recursive: true);
      final missing = Directory('${sandbox.path}/absent');
      await _write(nested, 'world.zip');
      await _write(documents, 'imports/other.zip');
      await _write(documents, 'app.db');
      final overlappingReset = LocalDataReset(
        marker: marker,
        dataDirectories: [
          nested,
          documents,
          Directory('${documents.path}/./'),
          documents,
          missing,
        ],
        keyStore: keyStore,
      );
      await overlappingReset.schedule();

      expect(await overlappingReset.applyPending(), isTrue);

      expect(await documents.exists(), isTrue);
      expect(await nested.exists(), isTrue);
      expect(await nested.list().toList(), isEmpty);
      expect(await File('${documents.path}/app.db').exists(), isFalse);
      expect(
        await File('${documents.path}/imports/other.zip').exists(),
        isFalse,
      );
      expect(await missing.exists(), isFalse);
      expect(keyStore.clearCalls, 1);
      expect(await marker.exists(), isFalse);
    },
  );

  test('invalid data roots retain the pending marker for retry', () async {
    await documents.delete();
    await File(documents.path).writeAsString('not a directory');
    await reset.schedule();

    await expectLater(
      reset.applyPending(),
      throwsA(isA<FileSystemException>()),
    );

    expect(await marker.readAsString(), 'pending');
    expect(await File(documents.path).readAsString(), 'not a directory');
    await File(documents.path).delete();
    await documents.create();
    await _write(documents, 'app.db');

    expect(await reset.applyPending(), isTrue);
    expect(await marker.exists(), isFalse);
    expect(await documents.list().toList(), isEmpty);
    expect(await keyStore.read(), isNull);
  });

  test('marker conflicts, including normalized paths, are rejected', () async {
    final database = await _write(documents, 'app.db');
    for (final path in [
      documents.path,
      '${documents.path}/pending',
      '${documents.path}/nested/pending',
      '${sandbox.path}/support/../docs/pending',
    ]) {
      expect(
        () => LocalDataReset(
          marker: File(path),
          dataDirectories: dataDirectories,
          keyStore: keyStore,
        ),
        throwsArgumentError,
      );
    }

    expect(await database.readAsString(), 'data');
    expect(keyStore.clearCalls, 0);
    expect(await marker.exists(), isFalse);
  });

  test(
    'similar directory prefixes do not cause a false marker conflict',
    () async {
      final siblingMarker = File('${documents.path}-support/pending');
      final siblingReset = LocalDataReset(
        marker: siblingMarker,
        dataDirectories: dataDirectories,
        keyStore: keyStore,
      );
      await siblingReset.schedule();

      expect(await siblingReset.applyPending(), isTrue);
      expect(await siblingMarker.exists(), isFalse);
    },
  );

  test(
    'marker conflicts through a directory alias are rejected before clearing',
    () async {
      final database = await _write(documents, 'app.db');
      final alias = await Link(
        '${sandbox.path}/docs-alias',
      ).create(documents.path);
      final aliasedMarker = File('${alias.path}/pending');
      final aliasedReset = LocalDataReset(
        marker: aliasedMarker,
        dataDirectories: dataDirectories,
        keyStore: keyStore,
      );
      await aliasedReset.schedule();

      await expectLater(aliasedReset.applyPending(), throwsArgumentError);

      expect(await aliasedMarker.readAsString(), 'pending');
      expect(await database.readAsString(), 'data');
      expect(await keyStore.read(), 'test-model-key');
      expect(keyStore.clearCalls, 0);
    },
  );
}
