import 'package:engine/engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// 引擎门面。必须在应用启动（main.dart 的 BootstrapApp）时用
/// ProviderScope overrides 注入实例，之后全 app 只读它。
final engineProvider = Provider<Engine>((ref) {
  throw UnimplementedError('engineProvider 必须在启动时以 override 注入');
});

/// 夜读模式开关（true = 深棕黑底暖黄字）
final nightModeProvider = StateProvider<bool>((ref) => false);
