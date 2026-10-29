import 'dart:io';

import 'package:engine/engine.dart';

class LocalDataReset {
  LocalDataReset({
    required File marker,
    required List<Directory> dataDirectories,
    required KeyStore keyStore,
  }) : _marker = marker.absolute,
       _dataDirectories = List.unmodifiable(
         dataDirectories.map((directory) => directory.absolute),
       ),
       _keyStore = keyStore {
    _checkMarker(
      _marker.path,
      _dataDirectories.map((directory) => directory.path),
    );
  }

  final File _marker;
  final List<Directory> _dataDirectories;
  final KeyStore _keyStore;

  Future<void> schedule() async {
    await _marker.parent.create(recursive: true);
    final temporary = File('${_marker.path}.tmp');
    await temporary.writeAsString('pending', flush: true);
    // 写入失败最多留下临时文件，不能让下次启动误执行未成功安排的清理。
    await temporary.rename(_marker.path);
  }

  Future<bool> applyPending() async {
    if (!await _marker.exists()) return false;

    final directories = <Uri, Directory>{};
    for (final directory in _dataDirectories) {
      final type = await FileSystemEntity.type(directory.path);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.directory) {
        throw FileSystemException('Expected a data directory', directory.path);
      }
      final path = await directory.resolveSymbolicLinks();
      directories[_directoryUri(path)] = Directory(path);
    }
    _checkMarker(
      await _marker.resolveSymbolicLinks(),
      directories.values.map((directory) => directory.path),
    );

    await _keyStore.clear();
    for (final directory in directories.values) {
      await _clearDirectory(directory, directories.keys);
    }
    await _marker.delete();
    return true;
  }

  Future<void> _clearDirectory(Directory directory, Iterable<Uri> roots) async {
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is Directory &&
          roots.any(
            (root) => root.toString().startsWith(
              _directoryUri(entity.path).toString(),
            ),
          )) {
        await _clearDirectory(entity, roots);
      } else {
        await entity.delete(recursive: true);
      }
    }
  }

  void _checkMarker(String markerPath, Iterable<String> directoryPaths) {
    final markerUri = _directoryUri(markerPath).toString();
    for (final path in directoryPaths) {
      if (markerUri.startsWith(_directoryUri(path).toString())) {
        throw ArgumentError.value(
          _marker.path,
          'marker',
          'Must be outside all data directories',
        );
      }
    }
  }

  static Uri _directoryUri(String path) =>
      Directory(path).absolute.uri.normalizePath();
}
