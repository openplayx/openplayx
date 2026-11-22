import '../../app_test_host.dart';

import 'package:openplayx/app/app.dart';
import 'package:openplayx/features/settings/app_theme_controller.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:openplayx/features/assistant/view/plugins/plugin_management_page.dart';
import 'package:openplayx/features/settings/settings_page.dart';
import 'package:openplayx/assistant/plugins/external/external_service_setup.dart';
import 'package:openplayx/assistant/conversation/assistant_store.dart';
import 'package:openplayx/assistant/plugins/external/external_service_registry.dart';
import 'package:openplayx/assistant/plugins/plugin_manager.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../services/plugins/plugin_manager_test.dart' show FakeSources;

void main() {
  Future<PluginManager> pump(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    FakeSources? sources,
    AssistantStore? assistant,
    ExternalServiceRegistry? external,
    String? language,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = sources ?? FakeSources();
    // The plugins follow the capability switches of the sources.
    final manager = PluginManager(sources: fake, switches: fake.switches);
    addTearDown(manager.dispose);
    await tester.runAsync(manager.refresh);
    final setup = ExternalServiceSetup(
      registry:
          external ??
          (ExternalServiceRegistry(db: sqlite3.openInMemory())..loaded = true),
    );
    // The AI groups are rows on the Settings root itself.
    final home = SettingsPage(
      aiGroupBuilder: (group) => PluginGroupPage(
        key: ValueKey('plugin-group-page-${group.name}'),
        group: group,
        manager: manager,
        setup: setup,
        sources: manager.sources,
        assistantStore: assistant,
      ),
    );
    await tester.pumpWidget(
      language == null
          ? TestApp(home: home)
          : OpenPlayXApp(
              appearance: AppThemeController(initialLanguage: language),
              home: home,
            ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return manager;
  }

  Future<void> openGroup(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(ValueKey('plugin-group-$name')));
    await tester.pumpAndSettle();
  }

  testWidgets('Settings lists the AI groups; each opens its model form, '
      'external or built-in page', (tester) async {
    await pump(tester);
    // Settings lists LLM → Whisper → external → built-in top to bottom, styled like
    // every other category: no description or value.
    expect(find.textContaining('内置基础能力'), findsNothing);
    final rows = [
      for (final name in ['model', 'whisper', 'external', 'builtIn'])
        tester.getCenter(find.byKey(ValueKey('plugin-group-$name'))).dy,
    ];
    expect(rows, List.of(rows)..sort());
    expect(find.text('配置 Agent 使用的模型'), findsNothing);
    expect(find.byKey(const ValueKey('settings-AI')), findsNothing);
    expect(find.byKey(const ValueKey('plugin-row-model.llm')), findsNothing);
    expect(find.byKey(const ValueKey('plugin-search')), findsNothing);
    expect(find.byKey(const ValueKey('plugin-row-source.smb')), findsNothing);
    expect(find.byKey(const ValueKey('external-configure')), findsNothing);
    await openGroup(tester, 'external');
    // Empty until services are configured: one centered 配置 button.
    expect(
      find.byKey(const ValueKey('external-configure-empty')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('plugin-row-model.llm')), findsNothing);
    // HTTP recognition is part of 语音识别, not a separate service.
    expect(find.byKey(const ValueKey('plugin-row-asr.http')), findsNothing);
    // Media-server sources are built-in adapters, not external services.
    // TMDB is built-in metadata, not an external service.
    expect(
      find.byKey(const ValueKey('plugin-row-metadata.tmdb')),
      findsNothing,
    );
    for (final kind in ['plex', 'jellyfin', 'emby', 'dlna']) {
      expect(find.byKey(ValueKey('plugin-row-source.$kind')), findsNothing);
    }
    // The list never carries plugin-wide switches.
    expect(find.byType(ShadSwitch), findsNothing);
    // The header carries the plain + button, like 来源.
    expect(find.byKey(const ValueKey('external-configure')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('external-configure')));
    await tester.pumpAndSettle();
    expect(find.text('配置外部能力'), findsOneWidget);
    expect(find.byKey(const ValueKey('external-connect')), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    // No search box on any page.
    expect(find.byKey(const ValueKey('plugin-search')), findsNothing);
    // Back to Settings, then into 内部能力.
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plugin-group-builtIn')), findsOneWidget);
    await openGroup(tester, 'builtIn');
    expect(find.byKey(const ValueKey('plugin-search')), findsNothing);
    expect(find.byKey(const ValueKey('plugin-row-source.smb')), findsOneWidget);
    expect(find.textContaining(' 个实例'), findsWidgets);
  });

  testWidgets('configured external services are listed with their tools', (
    tester,
  ) async {
    final registry = ExternalServiceRegistry(db: sqlite3.openInMemory())
      ..loaded = true
      ..services = const [
        ExternalService(
          id: 'ext-1',
          name: '家里下载',
          baseUrl: 'https://bt.example.test',
          endpoint: 'https://bt.example.test/api/mcp',
          serverName: 'openplayx-bittorrent',
          serverTitle: 'OpenPlayX BitTorrent',
          tools: ['create_plan', 'start_download'],
          available: true,
        ),
      ];
    await pump(tester, size: const Size(1400, 1000), external: registry);
    await openGroup(tester, 'external');
    expect(
      find.byKey(const ValueKey('external-service-ext-1')),
      findsOneWidget,
    );
    expect(find.textContaining('2 个工具'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('external-service-ext-1')));
    await tester.pump();
    expect(find.text('工具（2 个）'), findsOneWidget);
    expect(find.text('start_download'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('external-remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('external-remove-confirm')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(registry.services, isEmpty);
    expect(
      find.byKey(const ValueKey('external-configure-empty')),
      findsOneWidget,
    );
  });

  testWidgets('内部能力 page is read-only and opens the detail', (tester) async {
    await pump(tester);
    await openGroup(tester, 'builtIn');
    expect(find.textContaining('默认全部开放'), findsOneWidget);
    expect(find.byKey(const ValueKey('plugin-row-source.smb')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plugin-row-source.plex')),
      findsOneWidget,
    );
    // Two status dimensions on every row.
    expect(
      find.byKey(const ValueKey('plugin-configured-source.smb')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plugin-available-source.smb')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('plugin-row-asr.whisper')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('语音识别'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('plugin-row-metadata.tmdb')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('plugin-row-model.llm')), findsNothing);
    expect(find.byType(ShadSwitch), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('plugin-row-source.smb')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('plugin-row-source.smb')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plugin-overview')), findsOneWidget);
    // Instances are listed with a count; nothing can be added here.
    expect(find.text('实例（2 个）'), findsOneWidget);
    expect(find.byKey(const ValueKey('plugin-add-instance')), findsNothing);
    expect(find.text('添加实例'), findsNothing);
  });

  testWidgets('status badges wrap instead of overflowing on a phone', (
    tester,
  ) async {
    // English badge labels are the longest; two of them used to overflow the
    // row's trailing slot at phone width.
    await pump(tester, size: const Size(375, 812), language: 'en');
    await openGroup(tester, 'builtIn');
    final list = find.byType(Scrollable).first;
    for (final id in ['source.local', 'source.onedrive', 'source.dropbox']) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('plugin-row-$id')),
        200,
        scrollable: list,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('source write requires an explicit per-instance opt-in', (
    tester,
  ) async {
    final manager = await pump(tester, size: const Size(1400, 1000));
    await openGroup(tester, 'builtIn');
    await tester.tap(find.byKey(const ValueKey('plugin-row-source.smb')));
    await tester.pumpAndSettle();
    const key = ValueKey('source-write-switch-home');
    await tester.scrollUntilVisible(
      find.byKey(key),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      manager.aiAllows(
        'source.smb',
        instanceId: 'home',
        capability: 'source.write',
      ),
      isFalse,
    );
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    expect(
      manager.aiAllows(
        'source.smb',
        instanceId: 'home',
        capability: 'source.write',
      ),
      isTrue,
    );
    expect(
      manager.aiAllows(
        'source.smb',
        instanceId: 'office',
        capability: 'source.write',
      ),
      isFalse,
    );
  });

  testWidgets('wide windows show list and detail without AI or permission '
      'sections', (tester) async {
    await pump(tester, size: const Size(1400, 1000));
    await openGroup(tester, 'builtIn');
    // First entry asks for a selection instead of opening an arbitrary one.
    expect(find.byKey(const ValueKey('plugin-detail-empty')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plugin-row-source.smb')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('plugin-overview')), findsOneWidget);
    expect(find.byKey(const ValueKey('plugin-ai')), findsNothing);
    expect(find.byKey(const ValueKey('plugin-permissions')), findsNothing);
    expect(find.textContaining('已配置 · 可用'), findsWidgets);
  });

  testWidgets('LLM page is the model settings form', (tester) async {
    final db = sqlite3.openInMemory();
    final configuration = sqlite3.openInMemory();
    addTearDown(db.close);
    addTearDown(configuration.close);
    await pump(
      tester,
      assistant: AssistantStore(db, configuration: configuration),
    );
    expect(find.byKey(const ValueKey('plugin-model-settings')), findsNothing);
    await openGroup(tester, 'model');
    expect(find.byKey(const ValueKey('plugin-model-settings')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ai-model-fields')),
        matching: find.byType(EditableText),
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('ai-test')), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-save')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai-tab-local')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ai-model-fields')),
        matching: find.byType(EditableText),
      ),
      findsNWidgets(3),
    );
  });
  for (final width in [390.0, 1400.0]) {
    testWidgets(
      'LLM and Whisper have separate Settings entries at width $width',
      (tester) async {
        final db = sqlite3.openInMemory();
        final configuration = sqlite3.openInMemory();
        addTearDown(db.close);
        addTearDown(configuration.close);
        final store = AssistantStore(db, configuration: configuration);
        await pump(tester, size: Size(width, 1000), assistant: store);
        expect(find.text('LLM 模型'), findsOneWidget);
        expect(find.text('Whisper 模型'), findsOneWidget);
        await openGroup(tester, 'model');
        expect(
          find.byKey(const ValueKey('plugin-model-settings')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('ai-mode-tabs')), findsOneWidget);
        expect(find.byKey(const ValueKey('voice-mode-tabs')), findsNothing);
        expect(find.byKey(const ValueKey('voice-settings-save')), findsNothing);
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        await openGroup(tester, 'whisper');
        expect(find.text('Whisper 模型'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('plugin-whisper-settings')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('voice-mode-tabs')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('voice-settings-save')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('ai-mode-tabs')), findsNothing);
        expect(find.byKey(const ValueKey('ai-save')), findsNothing);
        expect(find.byKey(const ValueKey('plugin-detail-empty')), findsNothing);
        expect(
          configuration.select(
            "SELECT * FROM settings WHERE namespace='assistant'",
          ),
          isEmpty,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
