import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app_shell.dart';
import 'package:openplayx/features/ai_assistant/assistant_page.dart';
import 'package:openplayx/features/ai_assistant/assistant_settings_page.dart';
import 'package:openplayx/services/conversations/assistant_store.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:sqlite3/sqlite3.dart';

import '../app_test_host.dart';
import '../features/library/library_page_test.dart' show Sources;
import '../features/player/player_page_test.dart' show FakeBackend;

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'home and floating panel use the same conversation and model settings route',
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
      expect(find.byTooltip('AI 助手'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('home-open-chat')));
      await tester.pumpAndSettle();
      final homeView = tester.widget<AssistantView>(find.byType(AssistantView));
      final composer = find.descendant(
        of: find.byKey(const ValueKey('ai-composer-input')),
        matching: find.byType(EditableText),
      );
      await tester.enterText(composer, '保留这个草稿');
      await tester.tap(find.byTooltip('媒体库').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('AI 助手'));
      await tester.pumpAndSettle();
      final panelView = tester.widget<AssistantView>(
        find.byType(AssistantView).last,
      );
      expect(identical(panelView.coordinator, homeView.coordinator), true);
      expect(identical(panelView.controller, homeView.controller), true);
      expect(find.text('保留这个草稿'), findsOneWidget);
      await tester.tap(find.byTooltip('在首页展开'));
      await tester.pumpAndSettle();
      expect(find.text('保留这个草稿'), findsOneWidget);
      expect(find.byTooltip('AI 助手'), findsNothing);
      await tester.tap(find.byTooltip('模型设置'));
      await tester.pumpAndSettle();
      expect(find.byType(AssistantSettingsPage), findsOneWidget);
      expect(find.text('模型设置'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      library.close();
    },
  );
  testWidgets(
    'home suggestions and composer fit a narrow screen with large text',
    (tester) async {
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
      await tester.ensureVisible(find.byKey(const ValueKey('home-open-chat')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      library.close();
    },
  );
  for (final width in [320.0, 1200.0]) {
    testWidgets(
      'model settings fit width $width and large text; secret is obscured',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = sqlite3.openInMemory();
        final store = AssistantStore(db);
        await tester.pumpWidget(
          TestApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: const TextScaler.linear(2),
              ),
              child: AssistantSettingsPage(store: store),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final inputs = tester
            .widgetList<EditableText>(find.byType(EditableText))
            .toList();
        expect(inputs.length, 4);
        expect(inputs[2].obscureText, true);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        db.close();
      },
    );
  }
}
