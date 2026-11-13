import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/plugin_gate.dart';
import 'package:openplayx/features/settings/plugins/plugin_management_page.dart';
import 'package:openplayx/services/plugins/plugin_ai_policy.dart';
import 'package:openplayx/services/plugins/plugin_manager.dart';

import '../../services/plugins/plugin_manager_test.dart' show FakeSources;

void main() {
  tearDown(() => PluginGate.current = null);

  Future<PluginManager> pump(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    FakeSources? sources,
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
        home: PluginManagementPage(manager: manager, sources: manager.sources),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return manager;
  }

  testWidgets('lists built-in plugins with distinct states and filters', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('plugin-row-source.smb')), findsOneWidget);
    expect(find.textContaining('已启用 2/2 个实例'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('plugin-search')), 'SMB');
    await tester.pump();
    expect(find.byKey(const ValueKey('plugin-row-source.smb')), findsOneWidget);
    expect(find.byKey(const ValueKey('plugin-row-source.ftp')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('plugin-search')), '');
    await tester.pump();
    // No media service in this test build: FFmpeg is shown as needing
    // attention, without a switch that would pretend it can be enabled.
    await tester.tap(find.byKey(const ValueKey('plugin-scope-attention')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('plugin-row-media.ffmpeg')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('plugin-switch-media.ffmpeg')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('plugin-row-source.smb')), findsNothing);
  });

  testWidgets('disabling during playback asks for confirmation first', (
    tester,
  ) async {
    final manager = await pump(tester, sources: FakeSources()..playing = 1);
    await tester.tap(find.byKey(const ValueKey('plugin-switch-source.smb')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('1 个正在播放的会话'), findsOneWidget);
    expect(manager.policy.pluginEnabled('source.smb'), isTrue);
    await tester.tap(find.byKey(const ValueKey('plugin-disable-confirm')));
    await tester.runAsync(manager.refresh);
    await tester.pump(const Duration(milliseconds: 300));
    expect(manager.policy.pluginEnabled('source.smb'), isFalse);
    expect(find.text('收尾中'), findsWidgets);
  });

  testWidgets('wide windows show list and detail; AI scope is per instance', (
    tester,
  ) async {
    final manager = await pump(tester, size: const Size(1400, 1000));
    await tester.tap(find.byKey(const ValueKey('plugin-row-source.smb')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('plugin-ai')), findsOneWidget);
    final toggle = find.byKey(
      const ValueKey('plugin-ai-instance-switch-office'),
    );
    await tester.ensureVisible(toggle);
    await tester.pump();
    await tester.tap(toggle);
    await tester.runAsync(manager.refresh);
    await tester.pump(const Duration(milliseconds: 300));
    expect(manager.aiAllows('source.smb', instanceId: 'office'), isFalse);
    expect(manager.aiAllows('source.smb', instanceId: 'home'), isTrue);
  });
}
