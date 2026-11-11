// TEMPORARY: screenshot driver for the dialog→page change. Delete after use.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/app/app_shell.dart';
import 'package:openplayx/app/theme/app_theme_controller.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/remote_access/remote_access_service.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/settings/remote_access_settings_page.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart';

import '../test/features/player/player_page_test.dart' show FakeBackend;
import '../test/features/sources/source_flow_test.dart' show MemorySources;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final out = '${Directory.systemTemp.path}/openplayx-form-pages';
  final l = lookupAppLocalizations(const Locale('zh'));

  Future<void> shot(WidgetTester tester, GlobalKey key, String name) =>
      tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        await File('$out/$name.png').writeAsBytes(bytes);
        image.dispose();
      });

  testWidgets('form pages', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.runAsync(() => Directory(out).create(recursive: true));
    debugPrint('FORM_PAGES_DIR=$out');
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final size in [const Size(1200, 800), const Size(390, 844)]) {
        final tag = '${mode.name}-${size.width.toInt()}';
        tester.view.physicalSize = size;
        final appearance = AppThemeController(
          initialMode: mode,
          initialLanguage: 'zh-Hans',
        );
        final library = LibraryService(sqlite3.openInMemory());
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: OpenPlayXApp(
              appearance: appearance,
              home: AppShell(
                library: library,
                sources: MemorySources(),
                backend: FakeBackend(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('nav-sources')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.addSourceShort).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await shot(tester, key, '$tag-add-source');
        // SMB shows the longest field set.
        await tester.tap(find.byType(ShadSelect<SourceKind>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('SMB').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await shot(tester, key, '$tag-add-source-smb');

        // Remote connection editor.
        final config = SourceConfigurationService(sqlite3.openInMemory());
        final manager = SourceManager(
          configuration: config,
          remoteAccess: RemoteAccessService.memory(),
          remoteCoreValidator: (_) async {},
        );
        await manager.save(
          const SourceConfig(
            id: 'nas',
            kind: SourceKind.jellyfin,
            name: 'Home NAS',
            address: 'http://nas.invalid:8096',
            userId: 'user',
          ),
          'fixture-token',
        );
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: OpenPlayXApp(
              appearance: appearance,
              home: RemoteAccessSettingsPage(sources: manager),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -1500));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ShadButton, '配置家庭远程访问'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await shot(tester, key, '$tag-remote-editor');
        await tester.drag(
          find.byType(SingleChildScrollView).last,
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        await shot(tester, key, '$tag-remote-editor-bottom');

        await tester.pumpWidget(const SizedBox());
        await manager.dispose();
        config.close();
        appearance.dispose();
        library.close();
      }
    }
  });
}
