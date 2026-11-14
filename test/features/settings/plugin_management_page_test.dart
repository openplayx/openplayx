import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:openplayx/core/plugins/plugin_gate.dart';
import 'package:openplayx/features/settings/plugins/plugin_management_page.dart';
import 'package:openplayx/services/plugins/plugin_ai_policy.dart';
import 'package:openplayx/services/conversations/assistant_store.dart';
import 'package:openplayx/services/external/external_service_registry.dart';
import 'package:openplayx/services/plugins/plugin_manager.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../services/plugins/plugin_manager_test.dart' show FakeSources;

void main() {
  tearDown(() => PluginGate.current = null);

  Future<PluginManager> pump(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    FakeSources? sources,
    AssistantStore? assistant,
    ExternalServiceRegistry? external,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final manager = PluginManager(
      sources: sources ?? FakeSources(),
      store: MemoryPolicyStore(),
    )..install();
    addTearDown(manager.dispose);
    await tester.runAsync(manager.refresh);
    await tester.pumpWidget(
      TestApp(
        home: PluginManagementPage(
          manager: manager,
          sources: manager.sources,
          assistantStore: assistant,
          externalServices:
              external ??
              (ExternalServiceRegistry(db: sqlite3.openInMemory())
                ..loaded = true),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return manager;
  }

  Future<void> openGroup(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(ValueKey('plugin-group-$name')));
    await tester.pumpAndSettle();
  }

  testWidgets('two levels: group list, then model form, external and '
      'built-in pages', (tester) async {
    await pump(tester);
    // Root lists 模型 → 外部能力 → 内部能力 top to bottom, nothing else.
    expect(find.textContaining('内置基础能力'), findsNothing);
    final rows = [
      for (final name in ['model', 'external', 'builtIn'])
        tester.getCenter(find.byKey(ValueKey('plugin-group-$name'))).dy,
    ];
    expect(rows, List.of(rows)..sort());
    expect(find.byKey(const ValueKey('plugin-row-model.llm')), findsNothing);
    expect(find.byKey(const ValueKey('plugin-search')), findsNothing);
    expect(find.byKey(const ValueKey('plugin-row-source.smb')), findsNothing);
    expect(find.byKey(const ValueKey('external-configure')), findsNothing);
    await openGroup(tester, 'external');
    // Empty until services are configured.
    expect(find.text('还没有配置外部服务'), findsOneWidget);
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
    // 外部能力 has one 配置 button.
    expect(find.byKey(const ValueKey('external-configure')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('external-configure')));
    await tester.pumpAndSettle();
    expect(find.text('配置外部能力'), findsOneWidget);
    expect(find.byKey(const ValueKey('external-connect')), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    // No search box on any page.
    expect(find.byKey(const ValueKey('plugin-search')), findsNothing);
    // Back to the root, then into 内部能力.
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
    expect(find.text('还没有配置外部服务'), findsOneWidget);
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

  testWidgets('disabling during playback asks for confirmation first', (
    tester,
  ) async {
    final manager = await pump(tester, sources: FakeSources()..playing = 1);
    await openGroup(tester, 'builtIn');
    await tester.tap(find.byKey(const ValueKey('plugin-row-source.smb')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plugin-detail-switch')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('1 个正在播放的会话'), findsOneWidget);
    expect(manager.policy.pluginEnabled('source.smb'), isTrue);
    await tester.tap(find.byKey(const ValueKey('plugin-disable-confirm')));
    await tester.runAsync(manager.refresh);
    await tester.pump(const Duration(milliseconds: 300));
    expect(manager.policy.pluginEnabled('source.smb'), isFalse);
    expect(find.textContaining('正在等待播放'), findsWidgets);
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

  testWidgets('模型 page is the model settings form', (tester) async {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    await pump(
      tester,
      assistant: AssistantStore(db, configuration: sqlite3.openInMemory()),
    );
    // The root shows the model state before opening it.
    expect(find.text('未配置'), findsOneWidget);
    expect(find.byKey(const ValueKey('plugin-model-settings')), findsNothing);
    await openGroup(tester, 'model');
    expect(find.byKey(const ValueKey('plugin-model-settings')), findsOneWidget);
    expect(find.byType(EditableText), findsNWidgets(3));
    expect(find.byKey(const ValueKey('ai-test')), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-save')), findsOneWidget);
  });
}
