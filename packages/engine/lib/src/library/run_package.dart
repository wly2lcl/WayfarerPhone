import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:contracts/contracts.dart';

import '../errors.dart';
import 'checksum.dart';

/// 解包后的 `.run` 内容（校验全部通过后才返回）
class RunPackageContents {
  final RunPackageManifest manifest;
  final Map<String, Object?> run;
  final List<Map<String, Object?>> snapshots;
  final List<Map<String, Object?>> events;

  RunPackageContents({
    required this.manifest,
    required this.run,
    required this.snapshots,
    required this.events,
  });
}

/// `.run` 存档包格式（zip）：manifest.json + run.json + snapshots.jsonl +
/// events.jsonl + checksum（世界分享与UGC §3.1）
class RunPackage {
  static const int formatVersion = 1;
  static const int maxBytes = 20 * 1024 * 1024;

  /// 打包；checksum 对 run/snapshots/events 的规范化 JSON 取 SHA-256。
  /// snapshots/events 每条为库表行的 JSON 对象，由调用方从行组装。
  static Uint8List pack({
    required Map<String, Object?> run,
    required List<Map<String, Object?>> snapshots,
    required List<Map<String, Object?>> events,
    required int createdAt,
  }) {
    final checksum = packageChecksum({
      'run': run,
      'snapshots': snapshots,
      'events': events,
    });
    final manifest = RunPackageManifest(
      formatVersion: formatVersion,
      runId: asSOr(run['id'], ''),
      worldId: asSOr(run['worldId'], ''),
      worldVersion: asIOr(run['worldVersion'], 0),
      identityId: asSOr(run['identityId'], ''),
      turnNo: asIOr(run['turnNo'], 0),
      chapter: asIOr(run['chapter'], 0),
      status: asSOr(run['status'], 'active'),
      endingId: asSOr(run['endingId'], '') == '' ? null : asSOr(run['endingId'], ''),
      checksum: checksum,
      aiGenerated: true,
      createdAt: createdAt,
    );
    final pretty = const JsonEncoder.withIndent('  ');
    // store 模式（不压缩）：archive 3.x 的 deflate 流在部分标准校验器
    // （python zipfile）下 CRC 校验失败；且 ArchiveFile.string 会把 size
    // 记成 UTF-16 码元数（中文 ≠ UTF-8 字节数），故用 noCompress 显式传字节数
    ArchiveFile store(String name, String text) {
      final b = utf8.encode(text);
      return ArchiveFile.noCompress(name, b.length, b);
    }
    final archive = Archive()
      ..addFile(store('manifest.json', pretty.convert(manifest.toJson())))
      ..addFile(store('run.json', pretty.convert(run)))
      ..addFile(store('snapshots.jsonl', snapshots.map(jsonEncode).join('\n')))
      ..addFile(store('events.jsonl', events.map(jsonEncode).join('\n')))
      ..addFile(store('checksum', checksum));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  /// 解包 + 全量校验；不写入任何数据
  static RunPackageContents unpack(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw EngineException(EngineCode.importTooLarge, '.run 包超过 20 MB 上限');
    }
    final Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw EngineException(EngineCode.importInvalid, '不是有效的 .run 包（zip 解析失败）');
    }
    final files = {
      for (final f in zip.files)
        if (f.isFile) f.name: f,
    };
    const required = [
      'manifest.json',
      'run.json',
      'snapshots.jsonl',
      'events.jsonl',
      'checksum',
    ];
    final missing = required.where((n) => !files.containsKey(n)).toList();
    if (missing.isNotEmpty) {
      throw EngineException(EngineCode.importInvalid, '缺少包内文件',
          details: {'missing': missing});
    }
    String textOf(String name) => utf8.decode(files[name]!.content as List<int>);

    final Object? manifestRaw;
    final Object? runRaw;
    try {
      manifestRaw = jsonDecode(textOf('manifest.json'));
      runRaw = jsonDecode(textOf('run.json'));
    } catch (_) {
      throw EngineException(EngineCode.importInvalid, 'manifest.json 或 run.json 无法解析');
    }
    final manifestJson = rawMap(manifestRaw);
    if (manifestJson['formatVersion'] is! num) {
      throw EngineException(EngineCode.importInvalid, 'manifest 缺少 formatVersion',
          details: {'field': 'formatVersion'});
    }
    if (manifestJson['aiGenerated'] != true) {
      throw EngineException(EngineCode.importInvalid, '缺少 AI 生成标识（aiGenerated）',
          details: {'field': 'aiGenerated'});
    }
    final manifest = RunPackageManifest.fromJson(manifestJson);
    if (manifest.formatVersion > formatVersion) {
      throw EngineException(
          EngineCode.importInvalid,
          '包格式版本 ${manifest.formatVersion} 高于本机支持的 $formatVersion，请升级 App',
          details: {'field': 'formatVersion'});
    }
    if (manifest.formatVersion < formatVersion) {
      throw EngineException(
          EngineCode.importInvalid, '包格式版本 ${manifest.formatVersion} 无效（需 $formatVersion）',
          details: {'field': 'formatVersion'});
    }
    final run = rawMap(runRaw);
    for (final field in ['id', 'worldId', 'identityId']) {
      if (asSOr(run[field], '').isEmpty) {
        throw EngineException(EngineCode.importInvalid, 'run.json 缺少 $field',
            details: {'field': field});
      }
    }
    if (manifest.runId != asSOr(run['id'], '') ||
        manifest.worldId != asSOr(run['worldId'], '') ||
        manifest.turnNo != asIOr(run['turnNo'], -1) ||
        manifest.chapter != asIOr(run['chapter'], -1) ||
        manifest.status != asSOr(run['status'], '')) {
      throw EngineException(EngineCode.importInvalid, 'manifest 与 run.json 不一致',
          details: {'field': 'manifest/run'});
    }

    final snapshots = <Map<String, Object?>>[];
    final events = <Map<String, Object?>>[];
    void parseJsonl(String name, List<Map<String, Object?>> out) {
      final text = textOf(name);
      if (text.trim().isEmpty) return;
      var lineNo = 0;
      for (final line in text.split('\n')) {
        lineNo++;
        if (line.trim().isEmpty) continue;
        final Object? row;
        try {
          row = jsonDecode(line);
        } catch (_) {
          throw EngineException(EngineCode.importInvalid, '$name 第 $lineNo 行无法解析',
              details: {'file': name, 'line': lineNo});
        }
        if (row is! Map) {
          throw EngineException(EngineCode.importInvalid, '$name 第 $lineNo 行不是对象',
              details: {'file': name, 'line': lineNo});
        }
        out.add(rawMap(row));
      }
    }

    parseJsonl('snapshots.jsonl', snapshots);
    parseJsonl('events.jsonl', events);
    for (var i = 0; i < events.length; i++) {
      if (asIOr(events[i]['seq'], -1) != i + 1) {
        throw EngineException(EngineCode.importInvalid,
            'events.jsonl seq 不连续（第 ${i + 1} 条应为 seq=${i + 1}）',
            details: {'file': 'events.jsonl', 'index': i});
      }
    }

    final recomputed = packageChecksum({
      'run': run,
      'snapshots': snapshots,
      'events': events,
    });
    if (recomputed != manifest.checksum ||
        textOf('checksum').trim() != manifest.checksum) {
      throw EngineException(EngineCode.importInvalid, '校验和不匹配（包可能被篡改或损坏）',
          details: {'field': 'checksum'});
    }
    return RunPackageContents(
      manifest: manifest,
      run: run,
      snapshots: snapshots,
      events: events,
    );
  }
}
