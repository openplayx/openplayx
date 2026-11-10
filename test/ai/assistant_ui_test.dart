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
      final homeView = tester.widget<AssistantView>(find.byType(AssistantView));
      await tester.tap(find.byTooltip('AI 助手'));
      await tester.pumpAndSettle();
      final views = tester
          .widgetList<AssistantView>(find.byType(AssistantView))
          .toList();
      expect(views.length, 2);
      expect(identical(views.last.coordinator, homeView.coordinator), true);
      await tester.tap(find.text('设置').last);
      await tester.pumpAndSettle();
      expect(find.byType(AssistantSettingsPage), findsOneWidget);
      expect(find.text('模型设置'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
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
