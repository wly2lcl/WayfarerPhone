String? asS(Object? v) => v is String ? v : null;
String asSOr(Object? v, String d) => v is String ? v : d;
int? asI(Object? v) => v is num ? v.toInt() : null;
int asIOr(Object? v, int d) => v is num ? v.toInt() : d;
double? asD(Object? v) => v is num ? v.toDouble() : null;
double asDOr(Object? v, double d) => v is num ? v.toDouble() : d;
bool asBOr(Object? v, bool d) => v is bool ? v : d;

List<T> asList<T>(Object? v, T Function(Object?) f) =>
    (v as List?)?.map(f).toList() ?? <T>[];

/// 解析模型输出专用：数组里的非对象元素（模型偶发输出字符串）直接跳过
List<T> asListOfMaps<T>(Object? v, T Function(Map<String, Object?>) f) =>
    (v as List?)?.whereType<Map>().map((e) => f(rawMap(e))).toList() ?? <T>[];

Map<String, T> asMap<T>(Object? v, T Function(Object?) f) => (v as Map?)
        ?.map((k, e) => MapEntry(k, f(e))) ??
    <String, T>{};

Map<String, Object?> rawMap(Object? v) => asMap<Object?>(v, (e) => e);

T enumBy<T extends Enum>(List<T> values, Object? v, T fallback) {
  final s = asS(v);
  if (s == null) return fallback;
  for (final e in values) {
    if (e.name == s) return e;
  }
  return fallback;
}

String camel(String snake) => snake
    .split('_')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join();
