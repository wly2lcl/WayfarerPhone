import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 规范化 JSON（键递归排序）后取 SHA-256 hex——.world / .run 包校验和
/// （世界分享与UGC §3：对规范化 JSON 的 SHA-256）
String packageChecksum(Object? value) {
  Object? sort(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: sort(v[k])};
    }
    if (v is List) return v.map(sort).toList();
    return v;
  }

  return sha256.convert(utf8.encode(jsonEncode(sort(value)))).toString();
}

Object? normalizeJson(Object? value) {
  Object? sort(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: sort(v[k])};
    }
    if (v is List) return v.map(sort).toList();
    return v;
  }

  return sort(value);
}

/// 库内世界版本 checksum（world_versions.checksum，freeze 幂等判断同源）：
/// 规范化 JSON 串，非 SHA-256；包文件的对外校验和用 [packageChecksum]
String internalWorldChecksum(
    Object? bible, Object? identities, Object? seeds) {
  return jsonEncode({
    'bible': normalizeJson(bible),
    'identities': normalizeJson(identities),
    'seeds': normalizeJson(seeds),
  });
}
