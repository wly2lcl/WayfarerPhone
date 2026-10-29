import 'app_db.dart';

/// 本机应用级开关（app_settings KV 表）。
/// 年龄门与青少年模式的开关位（合规与内容安全 §5）。
class AppFlags {
  /// 年龄门结果：'adult'（已满 18）| 'teen'（未满 18，进青少年模式）
  static const ageGate = 'age_gate';

  /// 青少年模式：'1' 开启
  static const teenMode = 'teen_mode';

  const AppFlags(this.db);

  final AppDb db;

  Future<String?> read(String key) async {
    final row = await (db.select(db.appSettings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> write(String key, String value) =>
      db.into(db.appSettings).insertOnConflictUpdate(
            AppSettingsCompanion.insert(key: key, value: value),
          );

  Future<bool> teenModeOn() async => await read(teenMode) == '1';
}
