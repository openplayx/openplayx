import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/theme/app_theme.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:openplayx/ui/components/forms/secret_input.dart';
import 'package:openplayx/ui/icons/app_icons.dart';
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
  testWidgets('shows the saved secret masked; the eye reveals and hides it', (
    tester,
  ) async {
    final controller = SecretController();
    addTearDown(controller.dispose);
    await controller.loadStored(() async => 'sk-saved');
    await tester.pumpWidget(host(SecretInput(controller: controller)));

    EditableText field() =>
        tester.widget<EditableText>(find.byType(EditableText));
    expect(field().controller.text, 'sk-saved');
    expect(field().obscureText, isTrue);

    // Closed eye while masked; open eye while visible.
    await tester.tap(find.byIcon(AppIcons.hidePassword));
    await tester.pump();
    expect(field().obscureText, isFalse);
    expect(find.byIcon(AppIcons.showPassword), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.showPassword));
    await tester.pump();
    expect(field().obscureText, isTrue);
  });

  test('edited is empty while the saved value is unchanged', () async {
    final controller = SecretController();
    addTearDown(controller.dispose);
    await controller.loadStored(() async => 'old');
    expect(controller.hasStored, isTrue);
    expect(controller.edited, '');

    controller.text = ' new ';
    expect(controller.edited, 'new');
    controller.markSaved();
    expect(controller.edited, '');

    controller.clear();
    expect(controller.edited, '', reason: 'empty keeps what is saved');
  });

  test('a failed read leaves the field empty and typed text alone', () async {
    final failed = SecretController();
    addTearDown(failed.dispose);
    await failed.loadStored(() async => throw Exception('no keychain'));
    expect(failed.hasStored, isFalse);
    expect(failed.text, '');

    final typed = SecretController(text: 'typed');
    addTearDown(typed.dispose);
    await typed.loadStored(() async => 'saved');
    expect(typed.text, 'typed');
  });
}
