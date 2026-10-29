import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_mobile/app/providers.dart';
import 'package:wayfarer_mobile/features/settings/data_management_page.dart';
import 'package:wayfarer_mobile/features/settings/privacy_page.dart';

Future<void> showConsent(
  WidgetTester tester, {
  required Future<void> Function() accept,
  VoidCallback? decline,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PrivacyPage(onAccept: accept, onDecline: decline),
    ),
  );
  await tester.scrollUntilVisible(find.byType(CheckboxListTile), 600);
  await tester.pumpAndSettle();
}

Future<void> showData(
  WidgetTester tester, {
  required Future<void> Function() reset,
  bool teen = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scheduleDataResetProvider.overrideWithValue(reset),
        teenModeProvider.overrideWith((ref) => teen),
      ],
      child: const MaterialApp(home: DataManagementPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> requestReset(WidgetTester tester) async {
  final button = find.widgetWithText(OutlinedButton, '清空全部数据');
  await tester.scrollUntilVisible(button, 300);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('隐私告知须显式勾选，同意才调用保存', (tester) async {
    var accepted = 0;
    await showConsent(tester, accept: () async => accepted++);
    final button = find.widgetWithText(FilledButton, '同意并继续');
    await tester.ensureVisible(button);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(accepted, 0);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(accepted, 1);
  });

  testWidgets('拒绝告知不保存同意', (tester) async {
    var accepted = 0;
    var declined = 0;
    await showConsent(
      tester,
      accept: () async => accepted++,
      decline: () => declined++,
    );
    await tester.ensureVisible(find.text('不同意，暂不使用'));
    await tester.tap(find.text('不同意，暂不使用'));
    await tester.pumpAndSettle();
    expect(accepted, 0);
    expect(declined, 1);
  });

  testWidgets('同意落盘失败可重试，不静默进入应用', (tester) async {
    var attempts = 0;
    await showConsent(
      tester,
      accept: () async {
        attempts++;
        throw StateError('storage unavailable');
      },
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('同意并继续'));
    await tester.tap(find.text('同意并继续'));
    await tester.pumpAndSettle();
    expect(find.text('无法保存确认，请重试。'), findsOneWidget);
    expect(attempts, 1);
  });

  testWidgets('设置中的隐私页只读且大字号可滚动', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const PrivacyPage(),
      ),
    );
    await tester.scrollUntilVisible(find.text('测试版说明'), 600);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('清空取消不安排清理，确认仅调用一次', (tester) async {
    var resets = 0;
    await showData(tester, reset: () async => resets++);
    await requestReset(tester);
    expect(resets, 0);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(resets, 0);
    await requestReset(tester);
    await tester.tap(find.text('确认，重启后清空'));
    await tester.pumpAndSettle();
    expect(resets, 1);
  });

  testWidgets('清理标记写入失败提示且可重新操作', (tester) async {
    await showData(tester, reset: () async => throw StateError('disk full'));
    await requestReset(tester);
    await tester.tap(find.text('确认，重启后清空'));
    await tester.pumpAndSettle();
    expect(find.text('未能安排清理，数据尚未清除，请重试。'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '清空全部数据'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('青少年模式禁导出但保留清除权', (tester) async {
    await showData(tester, reset: () async {}, teen: true);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '管理并导出世界'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '导出或删除存档'),
          )
          .onPressed,
      isNull,
    );
    await requestReset(tester);
    expect(find.text('清空全部本机数据？'), findsOneWidget);
  });
}
