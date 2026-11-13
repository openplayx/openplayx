import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/theme/app_theme.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/features/ai_assistant/ai_chat_controller.dart';
import 'package:openplayx/features/ai_assistant/ai_chat_view.dart';
import 'package:openplayx/features/ai_assistant/adapters/flyer_chat_adapter.dart';
import 'package:openplayx/features/ai_assistant/widgets/ai_text_message.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:openplayx/services/ai_tools/tool_registry.dart';
import 'package:openplayx/services/conversations/assistant_store.dart';
import 'package:openplayx/services/conversations/conversation_coordinator.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart';

import 'conversation_test.dart' show FakeModel;

Widget host(Widget child, {ThemeMode mode = ThemeMode.light}) => ShadApp.custom(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: mode,
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
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late AssistantStore store;
  late ToolRegistry registry;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    db = sqlite3.openInMemory();
    store = AssistantStore(db);
    registry = ToolRegistry();
    await store.saveConfig(const AssistantConfig(cloudAllowed: true), '');
  });
  tearDown(() => db.close());
  ConversationCoordinator coordinator(FakeModel model) =>
      ConversationCoordinator(
        store: store,
        gateway: ToolGateway(registry, journal: store),
        model: () async => model,
        context: () => {'page': 'library'},
      );
  Widget view(
    ConversationCoordinator c, {
    AiChatController? controller,
    Future<void> Function(Map<String, dynamic>)? onOpen,
  }) => AiChatView(
    coordinator: c,
    controller: controller,
    toolsEnabled: () => true,
    onSettings: () {},
    onOpenMedia: onOpen,
  );

  test('legacy history gains persistent message IDs, pages and restores without requests', () async {
    for (var i = 0; i < 45; i++) {
      store.saveTurn('old-$i', 'completed', [
        ModelMessage('user', 'question $i'),
        ModelMessage('assistant', 'answer $i'),
      ]);
    }
    final model = FakeModel((_) async* {
      yield const ModelCompleted('stop');
    });
    final c = coordinator(model);
    expect(c.turns.length, 40);
    expect(c.hasEarlier, true);
    final adapter = FlyerChatAdapter(c);
    final ids = adapter.chat.messages.map((m) => m.id).toList();
    c.loadEarlier();
    expect(c.turns.length, 45);
    expect(c.hasEarlier, false);
    expect(adapter.chat.messages.map((m) => m.id).toList().sublist(10), ids);
    final persisted = c.turns.last.messages.last.id;
    adapter.dispose();
    c.dispose();
    final restarted = coordinator(model);
    expect(restarted.turns.last.messages.last.id, persisted);
    expect(model.requests, isEmpty);
    restarted.dispose();
  });
  test('conversation and draft history are isolated and text retry cannot replay a tool', () async {
    final model = FakeModel((_) async* {
      yield const ModelTextDelta('Done');
      yield const ModelCompleted('stop');
    });
    final c = coordinator(model);
    store.saveDraft('first draft');
    final first = c.conversationId;
    await c.send('first', toolsEnabled: false);
    c.newConversation();
    expect(c.turns, isEmpty);
    expect(store.draft, '');
    store.saveDraft('second draft');
    c.selectConversation(first);
    expect(c.turns.length, 1);
    expect(store.draft, 'first draft');
    final unsafe = ConversationTurn('unsafe', [
      const ModelMessage('user', 'change'),
      const ModelMessage(
        'assistant',
        '',
        calls: [ModelToolCall('a', 'write', '{}')],
      ),
    ], error: 'requestFailed');
    expect(c.canRetry(unsafe), false);
    await c.retry(unsafe);
    expect(model.requests.length, 1);
    c.dispose();
  });
  testWidgets(
    'stream updates one message; drafts remain editable and closing a view does not stop generation',
    (tester) async {
      final events = StreamController<ModelDelta>();
      final model = FakeModel((_) => events.stream);
      final c = coordinator(model);
      final ui = AiChatController(c);
      await tester.pumpWidget(host(view(c, controller: ui)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('ai-composer-input')),
          matching: find.byType(EditableText),
        ),
        'Find a film',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump(const Duration(milliseconds: 120));
      events.add(const ModelTextDelta('Hello'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      final id = find
          .byType(AiTextMessage)
          .evaluate()
          .map((e) => (e.widget as AiTextMessage).text)
          .toList();
      expect(id, contains('Hello'));
      final projection = FlyerChatAdapter(c);
      String streamingId() => projection.chat.messages
          .map((m) => m.id)
          .firstWhere((id) => id.contains(':response:'));
      final messageId = streamingId();
      events.add(const ModelTextDelta(' world'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(streamingId(), messageId);
      // User message, the streaming reply and the "still running" row.
      expect(projection.chat.messages.length, 3);
      expect(projection.chat.messages.last.id, endsWith(':activity'));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('ai-composer-input')),
          matching: find.byType(EditableText),
        ),
        'next draft',
      );
      expect(ui.draft.text, 'next draft');
      await tester.pumpWidget(const SizedBox());
      expect(c.busy, true);
      await tester.pumpWidget(host(view(c, controller: ui)));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('next draft'), findsOneWidget);
      c.stop();
      await tester.pumpAndSettle();
      events.add(const ModelTextDelta('late'));
      await tester.pump(const Duration(milliseconds: 120));
      expect(c.turns.single.messages.last.text, 'Hello world');
      expect(model.requests.length, 1);
      await tester.pumpWidget(const SizedBox());
      projection.dispose();
      ui.dispose();
      c.dispose();
      unawaited(events.close());
      await tester.pump();
    },
  );
  testWidgets(
    'reading history stays in place during streaming and panel expansion restores its anchor',
    (tester) async {
      for (var i = 0; i < 20; i++) {
        store.saveTurn('history-$i', 'completed', [
          ModelMessage(
            'assistant',
            'History message $i\n\nDetails about this result.',
            id: 'message-$i',
          ),
        ]);
      }
      final events = StreamController<ModelDelta>();
      final model = FakeModel((_) => events.stream);
      final c = coordinator(model);
      final ui = AiChatController(c);
      await tester.pumpWidget(
        host(
          AiChatView(
            coordinator: c,
            controller: ui,
            toolsEnabled: () => true,
            onSettings: () {},
            onExpand: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(c.send('new question', toolsEnabled: false));
      await tester.pumpAndSettle();
      final list = find.byType(CustomScrollView);
      await tester.drag(list, const Offset(0, 650));
      await tester.pumpAndSettle();
      final before = ui.anchorFor('panel');
      expect(before, isNotNull);
      expect(before!.atBottom, false);
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)).first,
          )
          .position;
      final pixels = position.pixels;
      events.add(const ModelTextDelta('A streaming answer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(pixels, 1));
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expand on Home'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(host(view(c, controller: ui)));
      await tester.pumpAndSettle();
      expect(ui.anchorFor('home')!.messageId, before.messageId);
      expect(
        find
            .byType(AiTextMessage)
            .evaluate()
            .map((e) => (e.widget as AiTextMessage).text),
        contains(startsWith('History message')),
      );
      expect(model.requests.length, 1);
      c.stop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      ui.dispose();
      c.dispose();
      unawaited(events.close());
      await tester.pump();
    },
  );
  test('reused model call IDs keep distinct host cards and confirmation identities', () async {
    var round = 0;
    registry.register(
      RegisteredTool('lookup', 'Find', {}, (_) async => {'media': []}),
    );
    final model = FakeModel((_) async* {
      if (round++ < 2) {
        yield const ModelToolDelta(ModelToolCall('same-id', 'lookup', '{}'));
        yield const ModelCompleted('toolCalls');
      } else {
        yield const ModelCompleted('stop');
      }
    });
    final c = coordinator(model);
    await c.send('search', toolsEnabled: true);
    final adapter = FlyerChatAdapter(c);
    expect(
      adapter.chat.messages.map((m) => m.id).toSet().length,
      adapter.chat.messages.length,
    );
    expect(adapter.parts.values.where((p) => p.tool == 'lookup').length, 2);
    adapter.dispose();
    c.dispose();
  });
  testWidgets(
    'IME Enter never submits; desktop Enter sends and Shift+Enter does not',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final model = FakeModel((_) async* {
        yield const ModelTextDelta('OK');
        yield const ModelCompleted('stop');
      });
      final c = coordinator(model);
      await tester.pumpWidget(host(view(c)));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('ai-composer-input')),
          matching: find.byType(EditableText),
        ),
      );
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ni',
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(model.requests, isEmpty);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(text: 'Hello'),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(model.requests, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(model.requests.length, 1);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets(
    'host media results are cards; model JSON is just text and actions use host callbacks',
    (tester) async {
      registry.register(
        RegisteredTool(
          'find_media',
          'Find media',
          {},
          (_) async => {
            'media': [
              {'media_id': 'm1', 'title': 'A real film'},
            ],
            'sources': [
              {'source_id': 'offline', 'error_code': 'unavailable'},
            ],
          },
        ),
      );
      var round = 0;
      final model = FakeModel((_) async* {
        if (round++ == 0) {
          yield const ModelToolDelta(
            ModelToolCall('lookup', 'find_media', '{}'),
          );
          yield const ModelCompleted('toolCalls');
        } else {
          yield const ModelTextDelta('**Ready**');
          yield const ModelCompleted('stop');
        }
      });
      final c = coordinator(model);
      await c.send('find', toolsEnabled: true);
      Map<String, dynamic>? opened;
      await tester.pumpWidget(
        host(
          view(
            c,
            onOpen: (row) async {
              opened = row;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A real film'), findsOneWidget);
      expect(find.textContaining('"media_id"'), findsNothing);
      expect(
        find.textContaining('Some sources are unavailable'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play'));
      await tester.pump();
      expect(opened?['media_id'], 'm1');
      expect(model.requests.length, 2);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'confirmation stays bound to its invocation and never exposes raw arguments',
    (tester) async {
      var writes = 0, round = 0;
      registry.register(
        RegisteredTool(
          'change',
          'Change selected item',
          {'secret': const ToolField('string', required: true)},
          (_) async => {'changed': ++writes},
          readOnly: false,
          confirmation: true,
        ),
      );
      final model = FakeModel((_) async* {
        if (round++ == 0) {
          yield const ModelToolDelta(
            ModelToolCall('change-1', 'change', '{"secret":"do-not-display"}'),
          );
          yield const ModelCompleted('toolCalls');
        } else {
          yield const ModelCompleted('stop');
        }
      });
      final c = coordinator(model);
      final pending = c.send('change', toolsEnabled: true);
      await tester.pumpWidget(host(view(c)));
      await tester.pumpAndSettle();
      expect(c.confirmation, isNotNull);
      expect(writes, 0);
      expect(find.textContaining('do-not-display'), findsNothing);
      await tester.ensureVisible(find.text('Approve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      await pending;
      expect(writes, 1);
      c.decide(true, confirmationId: 'old');
      expect(writes, 1);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'Markdown does not load remote images and large text fits narrow themes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 800);
      final model = FakeModel((_) async* {
        yield const ModelCompleted('stop');
      });
      final c = coordinator(model);
      c.turns.add(
        ConversationTurn('markdown', [
          const ModelMessage(
            'assistant',
            '![poster](https://invalid.example/image.png)\n\n```dart\nlong_code_without_wrapping_long_code_without_wrapping();\n```',
            id: 'md',
          ),
        ], status: 'completed'),
      );
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final direction in TextDirection.values) {
          await tester.pumpWidget(
            host(
              MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 800),
                  textScaler: TextScaler.linear(1.7),
                ),
                child: Directionality(textDirection: direction, child: view(c)),
              ),
              mode: mode,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Remote image not loaded'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
