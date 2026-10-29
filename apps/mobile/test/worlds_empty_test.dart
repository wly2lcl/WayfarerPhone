// B7 书架空状态引导 widget 测试：书架为空时显示引导卡（去工坊/导入世界包），
// 非空时仍显示世界卡。设备上验证需删光世界（破坏性），故以 widget 测试覆盖。
import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wayfarer_mobile/features/worlds/worlds_page.dart';
import 'package:wayfarer_mobile/features/worlds/worlds_provider.dart';

class _FixedWorlds extends WorldsNotifier {
  _FixedWorlds(this.list);
  final List<WorldSummary> list;
  @override
  Future<List<WorldSummary>> build() => Future.value(list);
}

WorldSummary _world(String id) => WorldSummary(
      id: id,
      title: '沧雾山界',
      genre: 'xianxia',
      summary: '内置世界',
      source: 'builtin',
      version: 1,
      identityCount: 4,
      updatedAt: 0,
      exportable: false,
    );

void main() {
  testWidgets('书架为空 → 显示空态引导卡（去工坊/导入世界包）', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [worldsProvider.overrideWith(() => _FixedWorlds(const []))],
      child: const MaterialApp(home: WorldsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('书架还是空的'), findsOneWidget);
    expect(find.text('去工坊开世界'), findsOneWidget);
    expect(find.text('导入世界包'), findsOneWidget);
    expect(find.text('下拉刷新书架'), findsOneWidget);
  });

  testWidgets('书架非空 → 正常世界卡，无引导卡', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [worldsProvider.overrideWith(() => _FixedWorlds([_world('w1')]))],
      child: const MaterialApp(home: WorldsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('书架还是空的'), findsNothing);
    expect(find.text('沧雾山界'), findsOneWidget);
    expect(find.text('内置'), findsOneWidget);
  });
}
