import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/theme/app_theme.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:openplayx/ui/components/forms/form_actions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Widget host(Widget child) => ShadApp.custom(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: ThemeMode.light,
  appBuilder: (context) => MaterialApp(
    theme: Theme.of(context),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      GlobalShadLocalizations.delegate,
      ...AppLocalizations.localizationsDelegates,
    ],
    builder: (context, child) => ShadAppBuilder(child: child!),
    home: Scaffold(body: child),
  ),
);

void main() {
  final actions = [
    FormAction.primary('保存', () {}, key: const ValueKey('save')),
    FormAction('测试连接', () {}, key: const ValueKey('test')),
    FormAction.destructive('清空', () {}, key: const ValueKey('clear')),
  ];
  Offset at(WidgetTester t, String k) => t.getCenter(find.byKey(ValueKey(k)));

  testWidgets('desktop: one right-aligned row, primary last', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(FormActions(actions)));
    expect(at(tester, 'clear').dy, at(tester, 'test').dy);
    expect(at(tester, 'clear').dx, lessThan(at(tester, 'test').dx));
    expect(at(tester, 'test').dx, lessThan(at(tester, 'save').dx));
    expect(at(tester, 'save').dx, greaterThan(1200 / 2));
    expect(find.byType(ShadButton), findsNWidgets(3));
  });

  testWidgets('phone: full-width stack, primary on top', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(FormActions(actions)));
    expect(at(tester, 'save').dy, lessThan(at(tester, 'test').dy));
    expect(at(tester, 'test').dy, lessThan(at(tester, 'clear').dy));
    expect(tester.getSize(find.byKey(const ValueKey('save'))).width, 390);
  });

  testWidgets('a null callback disables the button', (tester) async {
    await tester.pumpWidget(
      host(const FormActions([FormAction.primary('保存', null)])),
    );
    expect(tester.widget<ShadButton>(find.byType(ShadButton)).enabled, false);
  });

  for (final width in [1200.0, 390.0]) {
    testWidgets('a status never moves the buttons (width $width)', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<Offset> saveWith(FormStatus status) async {
        await tester.pumpWidget(host(FormActions(actions, status: status)));
        await tester.pump();
        return at(tester, 'save');
      }

      final idle = await saveWith(FormStatus.idle);
      expect(await saveWith(const FormStatus.busy('正在测试连接…')), idle);
      expect(find.text('正在测试连接…'), findsOneWidget);
      expect(
        await saveWith(FormStatus.error('连接失败：${'服务返回了无法识别的响应。' * 6}')),
        idle,
        reason: 'a long multi-line error grows away from the buttons',
      );
      expect(await saveWith(const FormStatus.success('连接成功')), idle);
    });
  }
}
