import 'dart:convert';

import 'package:contracts/contracts.dart';
import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/security/secure_key_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapApp());
}

/// 启动引导：初始化期间显示纸质底色的启动页，完成后注入引擎。
class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  Engine? _engine;
  Object? _error;

  /// 年龄门（合规与内容安全 §5，TODO WF-LAUNCH-04）：
  /// null = 首次启动待确认；'adult' = 已满 18；'teen' = 未满 18，进青少年模式
  String? _ageGate;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _engine = null;
      _error = null;
      _ageGate = null;
    });
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dbPath = '${docs.path}/wayfarer.db';
      final keyStore = SecureKeyStore();

      // 导出的 .world/.run 包放应用外部专属目录：文件管理器可浏览、可分享，
      // 私有 docs 目录对文件 App 不可见
      final ext = await getExternalStorageDirectory();
      final filesDir = ext?.path ?? docs.path;

      final bibleRaw =
          await rootBundle.loadString('assets/seed/cangwu/bible.json');
      final identitiesRaw =
          await rootBundle.loadString('assets/seed/cangwu/identities.json');
      final seedsRaw =
          await rootBundle.loadString('assets/seed/cangwu/seeds.json');
      final volumeRaw =
          await rootBundle.loadString('assets/seed/cangwu/volume1.json');

      final seed = SeedData(
        bible: WorldBible.fromJson(jsonDecode(bibleRaw)),
        identities: (jsonDecode(identitiesRaw) as List<Object?>)
            .map((e) => Identity.fromJson(e))
            .toList(),
        seeds: (jsonDecode(seedsRaw) as List<Object?>)
            .map((e) => EventSeed.fromJson(e))
            .toList(),
        // 卷一剧本只存原文串，由引擎按需使用
        volumeJson: volumeRaw,
      );

      final engine = await Engine.open(
        dbPath: dbPath,
        keyStore: keyStore,
        builtinSeed: seed,
        filesDir: filesDir,
      );
      if (!mounted) return;
      final gate = await engine.readAppSetting(AppFlags.ageGate);
      final teen = await engine.isTeenMode();
      setState(() {
        _engine = engine;
        _ageGate = gate;
        _teen = teen;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  bool _teen = false;

  /// 年龄门选择：写入引擎开关后进入主界面
  Future<void> _confirmAge(bool adult) async {
    final engine = _engine;
    if (engine == null) return;
    await engine.writeAppSetting(AppFlags.ageGate, adult ? 'adult' : 'teen');
    if (!adult) {
      await engine.setTeenMode(true);
    }
    if (!mounted) return;
    setState(() {
      _ageGate = adult ? 'adult' : 'teen';
      _teen = !adult;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _PaperSplash(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('启动失败', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: PaperColors.lightSub),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _init, child: const Text('重试')),
          ],
        ),
      );
    }
    final engine = _engine;
    if (engine == null) {
      return _PaperSplash(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              '远行',
              style: TextStyle(fontSize: 44, fontWeight: FontWeight.w600, letterSpacing: 10),
            ),
            const SizedBox(height: 6),
            const Text(
              '世界人生模拟器',
              style: TextStyle(fontSize: 13, letterSpacing: 6, color: PaperColors.lightSub),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: PaperColors.lightAccent),
            ),
            const SizedBox(height: 14),
            const Text(
              '正在打开世界……',
              style: TextStyle(fontSize: 12, color: PaperColors.lightSub),
            ),
          ],
        ),
      );
    }
    // 首次启动：年龄确认门（合规与内容安全 §5）
    if (_ageGate == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        home: _AgeGatePage(onConfirm: _confirmAge),
      );
    }
    return ProviderScope(
      overrides: [
        engineProvider.overrideWithValue(engine),
        teenModeProvider.overrideWith((ref) => _teen),
      ],
      child: const _WayfarerApp(),
    );
  }
}

/// 首次启动年龄确认（合规与内容安全 §5：未满 18 岁进入青少年模式）
class _AgeGatePage extends StatelessWidget {
  const _AgeGatePage({required this.onConfirm});

  final Future<void> Function(bool adult) onConfirm;

  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).colorScheme.secondary;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                '远行',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w600, letterSpacing: 10),
              ),
              const SizedBox(height: 8),
              const Text(
                '世界人生模拟器',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, letterSpacing: 6, color: PaperColors.lightSub),
              ),
              const SizedBox(height: 40),
              Text(
                '开始之前，请确认你的年龄',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: sub),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => onConfirm(true),
                child: const Text('我已满 18 周岁'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => onConfirm(false),
                child: const Text('我未满 18 周岁'),
              ),
              const SizedBox(height: 16),
              Text(
                '未满 18 周岁将进入青少年模式：关闭导入/导出入口，游玩中只能使用选项推进。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.6, color: sub),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 启动页：米白纸底
class _PaperSplash extends StatelessWidget {
  const _PaperSplash({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      home: Scaffold(
        body: Center(child: Padding(padding: const EdgeInsets.all(32), child: child)),
      ),
    );
  }
}

class _WayfarerApp extends ConsumerWidget {
  const _WayfarerApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final night = ref.watch(nightModeProvider);
    return MaterialApp.router(
      title: '远行 · 世界人生模拟器',
      theme: buildLightTheme(),
      darkTheme: buildNightTheme(),
      themeMode: night ? ThemeMode.dark : ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
