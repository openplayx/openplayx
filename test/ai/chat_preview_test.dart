import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/features/ai_assistant/ai_chat_view.dart';
import 'package:openplayx/services/ai_tools/tool_registry.dart';
import 'package:openplayx/services/conversations/assistant_store.dart';
import 'package:openplayx/services/conversations/conversation_coordinator.dart';
import 'package:sqlite3/sqlite3.dart';

import 'chat_frontend_test.dart' show host;
import 'conversation_test.dart' show FakeModel;

/// Opt-in visual review using bundled fonts and a fake model; no API requests.
void main() {
  const output = String.fromEnvironment('OPENPLAYX_CHAT_PREVIEW_DIR');
  testWidgets('export chat themes and sizes', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map<String, dynamic>>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font
          in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
        loader.addFont(
          rootBundle.load(Uri.decodeFull(font['asset'] as String)),
        );
      }
      await tester.runAsync(loader.load);
    }
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => Directory(output).create(recursive: true));
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final size in [const Size(1200, 800), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        final db = sqlite3.openInMemory(), key = GlobalKey();
        final store = AssistantStore(db);
        await store.saveConfig(const AssistantConfig(cloudAllowed: true), '');
        final registry = ToolRegistry();
        registry.register(
          RegisteredTool(
            'search_media',
            'Search your media library',
            {},
            (_) async => {
              'media': [
                {
                  'media_id': 'coast',
                  'title': 'The quiet coast',
                  'source_id': 'Living room NAS',
                },
                {
                  'media_id': 'lights',
                  'title': 'Northern lights',
                  'source_id': 'My collection',
                },
              ],
              'sources': [
                {'source_id': 'Bedroom server', 'error_code': 'unavailable'},
              ],
            },
          ),
        );
        var round = 0;
        final model = FakeModel((_) async* {
          if (round++ == 0) {
            yield const ModelToolDelta(
              ModelToolCall('search-1', 'search_media', '{}'),
            );
            yield const ModelCompleted('toolCalls');
          } else {
            yield const ModelTextDelta(
              'I found two films in your library. Choose **Play** to continue watching.',
            );
            yield const ModelCompleted('stop');
          }
        });
        final c = ConversationCoordinator(
          store: store,
          gateway: ToolGateway(registry),
          model: () async => model,
          context: () => {'page': 'library'},
        );
        await c.send(
          'Find something in my library to watch tonight.',
          toolsEnabled: true,
        );
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: host(
              AiChatView(
                coordinator: c,
                toolsEnabled: () => true,
                onSettings: () {},
                onOpenMedia: (_) async {},
                onFavorite: (_) async => true,
              ),
              mode: mode,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$output/chat-${mode.name}-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        db.close();
      }
    }
  }, skip: output.isEmpty);
}
