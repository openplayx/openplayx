import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:openplayx/app/app_shell.dart';
import 'package:openplayx/features/ai_assistant/assistant_page.dart';
import 'package:openplayx/features/ai_assistant/assistant_settings_page.dart';
import 'package:openplayx/services/conversations/assistant_store.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:openplayx/ui/components/settings/settings_section.dart';

import '../app_test_host.dart';
import '../features/library/library_page_test.dart' show Sources;
import '../features/player/player_page_test.dart' show FakeBackend;

void main() {
  testWidgets(
    'top-right assistant button is on every page and keeps one conversation',
    (tester) async {
      final library = LibraryService(sqlite3.openInMemory());
      await tester.pumpWidget(
        TestApp(
          home: AppShell(
            library: library,
            sources: Sources(),
            backend: FakeBackend(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Home no longer embeds the assistant; the corner button opens it.
      expect(find.byType(AssistantView), findsNothing);
      await tester.tap(find.byTooltip('AI 助手'));
      await tester.pumpAndSettle();
      final first = tester.widget<AssistantView>(find.byType(AssistantView));
      expect(first.coordinator.context()['pageContext']['pageType'], 'home');
      expect(find.byTooltip('在首页展开'), findsNothing);
      final composer = find.descendant(
        of: find.byKey(const ValueKey('ai-composer-input')),
        matching: find.byType(EditableText),
      );
      await tester.enterText(composer, '保留这个草稿');
      // A full page: it hides the tab bar and closes from its close button.
      expect(find.byTooltip('来源'), findsNothing);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(AssistantView), findsNothing);
      await tester.tap(find.byTooltip('来源').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('AI 助手'));
      await tester.pumpAndSettle();
      final second = tester.widget<AssistantView>(find.byType(AssistantView));
      expect(second.coordinator.context()['pageContext']['pageType'], 'sources');
      expect(identical(second.coordinator, first.coordinator), true);
      expect(identical(second.controller, first.controller), true);
      expect(find.text('保留这个草稿'), findsOneWidget);
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('模型设置').last);
      await tester.pumpAndSettle();
      // Model settings live on the AI page's 模型 page.
      expect(find.byType(AssistantModelSettings), findsOneWidget);
      expect(
        find.byKey(const ValueKey('plugin-group-page-model')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      library.close();
    },
  );
  testWidgets('top-right button fits a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final library = LibraryService(sqlite3.openInMemory());
    await tester.pumpWidget(
      TestApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 1000),
            textScaler: TextScaler.linear(2),
          ),
          child: AppShell(
            library: library,
            sources: Sources(),
            backend: FakeBackend(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.getRect(find.byTooltip('AI 助手'));
    expect(button.right, lessThanOrEqualTo(320));
    expect(button.top, lessThan(40));
    final title = tester.getRect(find.text('首页').first);
    expect(title.overlaps(button), false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    library.close();
  });
  for (final width in [320.0, 1200.0]) {
    testWidgets(
      'model settings fit width $width and large text; secret is obscured',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = sqlite3.openInMemory();
        final store = AssistantStore(db, configuration: sqlite3.openInMemory());
        await tester.pumpWidget(
          TestApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: const TextScaler.linear(2),
              ),
              child: _form(store),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final inputs = tester
            .widgetList<EditableText>(find.byType(EditableText))
            .toList();
        expect(inputs.length, 3);
        expect(inputs[2].obscureText, true);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        db.close();
      },
    );
  }
  testWidgets(
    'settings are three fields and one test; key alone enables chat',
    (tester) async {
      final db = sqlite3.openInMemory();
      final store = AssistantStore(db, configuration: sqlite3.openInMemory());
      await tester.pumpWidget(TestApp(home: _form(store)));
      await tester.pumpAndSettle();
      expect(find.byType(ShadSwitch), findsNothing);
      expect(find.byKey(const ValueKey('ai-test')), findsOneWidget);
      final fields = find.byType(EditableText);
      expect(fields, findsNWidgets(3));
      await tester.enterText(fields.at(0), 'https://api.deepseek.com/');
      await tester.enterText(fields.at(1), 'deepseek-chat');
      // No key yet: saving asks for one and keeps nothing.
      await tester.tap(find.byKey(const ValueKey('ai-save')));
      await tester.pumpAndSettle();
      expect(store.loadConfig().configured, false);
      await tester.enterText(fields.at(2), 'sk-test');
      await tester.tap(find.byKey(const ValueKey('ai-save')));
      await tester.pumpAndSettle();
      final saved = store.loadConfig();
      expect(saved.endpoint, 'https://api.deepseek.com');
      expect(saved.configured, true);
      expect(await store.key(saved), 'sk-test');
      await tester.pumpWidget(const SizedBox());
      db.close();
    },
  );
}

Widget _form(AssistantStore store) => Scaffold(
  body: SettingsListView(children: [AssistantModelSettings(store: store)]),
);
