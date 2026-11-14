import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/theme/app_theme.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:openplayx/ui/components/forms/settings_text_input.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Widget host(Widget child) => ShadApp.custom(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: ThemeMode.light,
  appBuilder: (context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: Theme.of(context),
    locale: const Locale('en'),
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
  test('a blank field resolves to its default', () {
    final c = DefaultTextController(defaultValue: '10');
    addTearDown(c.dispose);
    expect(c.text, '', reason: 'the default is a hint, not field content');
    expect(c.resolved, '10');
    c.text = ' 30 ';
    expect(c.resolved, '30');
    c.text = '   ';
    expect(c.resolved, '10');
  });

  testWidgets('the default is shown as the hint; otherwise the example', (
    tester,
  ) async {
    final withDefault = DefaultTextController(defaultValue: 'all');
    final plain = TextEditingController();
    addTearDown(withDefault.dispose);
    addTearDown(plain.dispose);
    await tester.pumpWidget(
      host(
        Column(
          children: [
            SettingsTextInput(controller: withDefault, example: 'ignored'),
            SettingsTextInput(controller: plain, example: 'https://a.example'),
          ],
        ),
      ),
    );
    expect(find.text('all'), findsOneWidget);
    expect(find.text('ignored'), findsNothing);
    expect(find.text('https://a.example'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('entered text is clearly darker than the hint (dark: $dark)', (
      tester,
    ) async {
      final filled = TextEditingController(text: 'typed');
      final blank = TextEditingController();
      addTearDown(filled.dispose);
      addTearDown(blank.dispose);
      await tester.pumpWidget(
        ShadApp.custom(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          appBuilder: (context) => MaterialApp(
            theme: Theme.of(context),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              GlobalShadLocalizations.delegate,
              ...AppLocalizations.localizationsDelegates,
            ],
            builder: (context, child) => ShadAppBuilder(child: child!),
            home: Scaffold(
              body: Column(
                children: [
                  SettingsTextInput(controller: filled),
                  SettingsTextInput(controller: blank, example: 'hint'),
                ],
              ),
            ),
          ),
        ),
      );
      final colors = ShadTheme.of(tester.element(find.text('hint')))
          .colorScheme;
      final text = tester
          .widget<EditableText>(find.byType(EditableText).first)
          .style
          .color;
      final hint = DefaultTextStyle.of(tester.element(find.text('hint')))
          .style
          .color;
      expect(text, colors.foreground);
      expect(
        hint,
        AppTheme.hintColor(dark ? Brightness.dark : Brightness.light),
      );
      // A hint must not read as a filled-in value.
      expect(_contrast(text!, hint!), greaterThan(7));
    });
  }
}

/// WCAG contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}
