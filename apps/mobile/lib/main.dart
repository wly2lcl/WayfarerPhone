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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _engine = null;
      _error = null;
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
      setState(() => _engine = engine);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
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
    return ProviderScope(
      overrides: [engineProvider.overrideWithValue(engine)],
      child: const _WayfarerApp(),
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
