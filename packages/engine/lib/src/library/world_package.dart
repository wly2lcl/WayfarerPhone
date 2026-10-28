import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:contracts/contracts.dart';

import '../errors.dart';
import 'checksum.dart';

/// 解包后的 `.world` 内容（校验全部通过后才返回）
class WorldPackageContents {
  final WorldPackageManifest manifest;
  final Map<String, Object?> bible;
  final List<Object?> identities;
  final List<Object?> seeds;
  final String notice;

  WorldPackageContents({
    required this.manifest,
    required this.bible,
    required this.identities,
    required this.seeds,
    required this.notice,
  });
}

/// `.world` 包格式（zip）：manifest.json + bible.json + identities.json +
/// seeds.json + NOTICE.txt + checksum（世界分享与UGC §3）
class WorldPackage {
  static const int formatVersion = 1;
  static const int maxBytes = 20 * 1024 * 1024;

  /// 打包；checksum 对 bible/identities/seeds 的规范化 JSON 取 SHA-256；
  /// manifest.aiGenerated 固定 true，导出者不可关闭
  static Uint8List pack({
    required String worldId,
    required int version,
    required Map<String, Object?> bible,
    required List<Object?> identities,
    required List<Object?> seeds,
    required String license,
    required String origin,
    String? sourceWorldId,
    required String author,
    required int createdAt,
    String? title,
  }) {
    final checksum = packageChecksum({
      'bible': bible,
      'identities': identities,
      'seeds': seeds,
    });
    final manifest = WorldPackageManifest(
      formatVersion: formatVersion,
      worldId: worldId,
      version: version,
      checksum: checksum,
      license: license,
      origin: origin,
      sourceWorldId: sourceWorldId,
      aiGenerated: true,
      author: author,
      createdAt: createdAt,
    );
    final notice = buildNotice(
      title: title ??
          asSOr(rawMap(bible['meta'])['title'], worldId),
      author: author,
      license: license,
      origin: origin,
      sourceWorldId: sourceWorldId,
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
      ..addFile(store('bible.json', jsonEncode(bible)))
      ..addFile(store('identities.json', jsonEncode(identities)))
      ..addFile(store('seeds.json', jsonEncode(seeds)))
      ..addFile(store('NOTICE.txt', notice))
      ..addFile(store('checksum', checksum));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static String buildNotice({
    required String title,
    required String author,
    required String license,
    required String origin,
    String? sourceWorldId,
  }) {
    final originLine = origin == 'shared'
        ? '来源：由他人分享的 .world 包再导出（原 worldId：$sourceWorldId）'
        : '来源：本机原创';
    return '''
「$title」 Wayfarer 世界包
作者：${author.isEmpty ? '（未署名）' : author}
许可证：$license
$originLine

本世界由 AI 辅助生成（aiGenerated = true，不可关闭）。
再导出时必须原样保留本 NOTICE.txt 与来源声明，许可证不得放宽。
导入来源（小说 TXT）的世界永不导出。
''';
  }

  /// 解包 + 全量校验（世界分享与UGC §6）；任一不满足抛 IMPORT_INVALID /
  /// IMPORT_TOO_LARGE，details 列出具体原因；不写入任何数据
  static WorldPackageContents unpack(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw EngineException(EngineCode.importTooLarge, '.world 包超过 20 MB 上限');
    }
    final Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw EngineException(EngineCode.importInvalid, '不是有效的 .world 包（zip 解析失败）');
    }
    final files = {
      for (final f in zip.files)
        if (f.isFile) f.name: f,
    };
    const required = [
      'manifest.json',
      'bible.json',
      'identities.json',
      'seeds.json',
      'NOTICE.txt',
      'checksum',
    ];
    final missing = required.where((n) => !files.containsKey(n)).toList();
    if (missing.isNotEmpty) {
      throw EngineException(EngineCode.importInvalid, '缺少包内文件',
          details: {'missing': missing});
    }
    String textOf(String name) => utf8.decode(files[name]!.content as List<int>);

    final Object? manifestRaw;
    try {
      manifestRaw = jsonDecode(textOf('manifest.json'));
    } catch (_) {
      throw EngineException(EngineCode.importInvalid, 'manifest.json 无法解析');
    }
    final manifestJson = rawMap(manifestRaw);
    if (manifestJson['formatVersion'] is! num) {
      throw EngineException(EngineCode.importInvalid, 'manifest 缺少 formatVersion',
          details: {'field': 'formatVersion'});
    }
    // aiGenerated 缺失或非 true 均拒绝（不能用 fromJson 的默认值掩盖缺失）
    if (manifestJson['aiGenerated'] != true) {
      throw EngineException(EngineCode.importInvalid, '缺少 AI 生成标识（aiGenerated）',
          details: {'field': 'aiGenerated'});
    }
    final manifest = WorldPackageManifest.fromJson(manifestJson);
    if (manifest.formatVersion > formatVersion) {
      throw EngineException(
          EngineCode.importInvalid,
          '包格式版本 ${manifest.formatVersion} 高于本机支持的 $formatVersion，请升级 App',
          details: {'field': 'formatVersion'});
    }
    if (manifest.formatVersion < formatVersion) {
      throw EngineException(EngineCode.importInvalid,
          '包格式版本 ${manifest.formatVersion} 无效（需 $formatVersion）',
          details: {'field': 'formatVersion'});
    }
    if (manifest.worldId.isEmpty || manifest.version <= 0) {
      throw EngineException(EngineCode.importInvalid, 'manifest 缺少 worldId 或 version',
          details: {'field': 'worldId/version'});
    }

    Map<String, Object?> bible;
    List<Object?> identities;
    List<Object?> seeds;
    List<Object?> listOf(Object? v) {
      if (v is List) return v.toList();
      throw const FormatException('期望数组');
    }

    try {
      bible = rawMap(jsonDecode(textOf('bible.json')));
      identities = listOf(jsonDecode(textOf('identities.json')));
      seeds = listOf(jsonDecode(textOf('seeds.json')));
    } on EngineException {
      rethrow;
    } catch (e) {
      throw EngineException(EngineCode.importInvalid, 'bible/identities/seeds 解析失败',
          details: {'error': e.toString()});
    }
    final meta = rawMap(bible['meta']);
    if (asSOr(meta['title'], '').isEmpty || asSOr(meta['genre'], '').isEmpty) {
      throw EngineException(EngineCode.importInvalid, 'bible 必填字段缺失（meta.title / meta.genre）',
          details: {'field': 'bible.meta'});
    }

    final recomputed = packageChecksum({
      'bible': bible,
      'identities': identities,
      'seeds': seeds,
    });
    if (recomputed != manifest.checksum ||
        textOf('checksum').trim() != manifest.checksum) {
      throw EngineException(EngineCode.importInvalid, '校验和不匹配（包可能被篡改或损坏）',
          details: {'field': 'checksum'});
    }
    return WorldPackageContents(
      manifest: manifest,
      bible: bible,
      identities: identities,
      seeds: seeds,
      notice: textOf('NOTICE.txt'),
    );
  }
}
