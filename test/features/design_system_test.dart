import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/l10n/shad_localizations_delegate.dart';
import 'package:openplayx/app/app_shell.dart';
import 'package:openplayx/app/theme/app_theme_controller.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:openplayx/features/design_system/component_gallery_page.dart';
import 'package:openplayx/features/player/player_page.dart';
import 'package:openplayx/features/sources/source_instance_form.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/ui/adaptive/app_navigation.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart';

import 'library/library_page_test.dart' show Sources;
import 'player/player_page_test.dart' show FakeBackend;

import 'package:openplayx/services/library/library_service.dart';

import 'sources/source_flow_test.dart' show MemorySources;

void main() {
  test(
    'component stock strings match the traditional Chinese app locale',
    () async {
      final strings = await const AppShadLocalizationsDelegate().load(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
      expect(strings.input.copy, '複製');
      expect(strings.input.paste, '貼上');
      expect(strings.datePicker.selectDate, '選擇日期');
    },
  );
  test('appearance persists in the existing configuration service', () async {
    final configuration = SourceConfigurationService(sqlite3.openInMemory());
    final first = AppThemeController(configuration: configuration);
    await first.load();
    expect(first.mode, ThemeMode.system);
    for (final mode in ThemeMode.values) {
      await first.setMode(mode);
      await first.setLanguage('zh-Hant');
      final restarted = AppThemeController(configuration: configuration);
      await restarted.load();
      expect(restarted.mode, mode);
      expect(restarted.locale!.scriptCode, 'Hant');
      restarted.dispose();
    }
    first.dispose();
    configuration.close();
  });

  test(
    'unreadable preferences do not block startup or hide save failure',
    () async {
      final configuration = SourceConfigurationService(sqlite3.openInMemory());
      configuration.close();
      final controller = AppThemeController(configuration: configuration);
      await controller.load();
      expect(controller.mode, ThemeMode.system);
      await controller.setMode(ThemeMode.dark);
      expect(controller.mode, ThemeMode.dark);
      expect(controller.saveError, isNotNull);
      controller.dispose();
    },
  );

  testWidgets(
    'theme and language switches preserve active playback and progress',
    (tester) async {
      final library = LibraryService(sqlite3.openInMemory());
      final configuration = SourceConfigurationService(sqlite3.openInMemory());
      final appearance = AppThemeController(
        configuration: configuration,
        initialLanguage: 'zh-Hans',
      );
      final backend = FakeBackend();
      await tester.pumpWidget(
        OpenPlayXApp(
          appearance: appearance,
          home: AppShell(
            library: library,
            sources: Sources(),
            backend: backend,
            pickMedia: () async => LocalMedia(
              Uri.parse('https://example.test/video.mp4'),
              'Video',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester
          .state<PlayerPageState>(find.byType(PlayerPage, skipOffstage: false))
          .openFile();
      await tester.pumpAndSettle();
      final state = tester.state<PlayerPageState>(find.byType(PlayerPage));
      final before = backend.value;
      await appearance.setMode(ThemeMode.dark);
      await appearance.setLanguage('en');
      await tester.pumpAndSettle();
      expect(
        identical(
          state,
          tester.state<PlayerPageState>(find.byType(PlayerPage)),
        ),
        isTrue,
      );
      expect(backend.released, isFalse);
      expect(backend.opened, hasLength(1));
      expect(backend.value.position, before.position);
      expect(backend.value.status, before.status);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Recently played'), findsOneWidget);
      final context = tester.element(find.byType(AppSidebar));
      expect(ShadTheme.of(context).brightness, Brightness.dark);
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
      configuration.close();
      library.close();
    },
  );

  testWidgets(
    'gallery and source forms fit themes, widths, RTL and large text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.devicePixelRatio = 1;
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final size in [
          const Size(320, 640),
          const Size(700, 720),
          const Size(1200, 800),
        ]) {
          for (final language in ['en', 'zh-Hans', 'zh-Hant']) {
            tester.view.physicalSize = size;
            tester.platformDispatcher.textScaleFactorTestValue = 1.7;
            final appearance = AppThemeController(
              initialMode: mode,
              initialLanguage: language,
            );
            await tester.pumpWidget(
              OpenPlayXApp(
                key: UniqueKey(),
                appearance: appearance,
                home: const Directionality(
                  textDirection: TextDirection.rtl,
                  child: ComponentGalleryPage(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$mode $size $language',
            );
            await tester.pumpWidget(const SizedBox());
            appearance.dispose();
          }
        }
      }
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 1.7;
      final appearance = AppThemeController(initialLanguage: 'en');
      await tester.pumpWidget(
        OpenPlayXApp(
          appearance: appearance,
          home: Scaffold(
            body: SourceInstanceForm(
              manager: MemorySources(),
              initial: const SourceConfig(
                id: 'test',
                kind: SourceKind.smb,
                name: 'Long source name',
                address: 'smb://host/share',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
    },
  );
}
