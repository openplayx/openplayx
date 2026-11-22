import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/metadata/tmdb_credentials.dart';
import 'package:openplayx/features/settings/tmdb_settings_section.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../app_test_host.dart';

void main() {
  test('new installations use cloud; existing tokens retain local mode', () {
    final settings = <String, String>{};
    TmdbConfig config() =>
        TmdbConfig.fromSettings((key) => settings[key] ?? '');
    expect(config().usePlatform, true);
    expect(config().configured, true);
    settings[tmdbTokenKey] = 'legacy-token';
    expect(config().usePlatform, false);
    settings[tmdbModeKey] = 'cloud';
    expect(config().usePlatform, true);
    settings[tmdbModeKey] = 'local';
    settings[tmdbTokenKey] = '';
    expect(config().configured, false);
  });

  for (final width in [390.0, 1100.0]) {
    testWidgets(
      'tabs only browse; enable switches and retains token at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final library = LibraryService(sqlite3.openInMemory());
        library.metadata.setSetting(tmdbTokenKey, 'local-secret');
        await tester.pumpWidget(
          TestApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TmdbSettingsSection(library: library),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('tmdb-configure')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('tmdb-tab-cloud')));
        await tester.pumpAndSettle();
        expect(
          TmdbConfig.fromSettings(library.metadata.setting).usePlatform,
          false,
        );
        expect(find.byKey(const ValueKey('tmdb-configure')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('tmdb-enable-mode')));
        await tester.pumpAndSettle();
        expect(
          TmdbConfig.fromSettings(library.metadata.setting).usePlatform,
          true,
        );
        expect(library.metadata.setting('tmdbRevision'), isNotEmpty);
        expect(library.metadata.setting(tmdbTokenKey), 'local-secret');
        await tester.tap(find.byKey(const ValueKey('tmdb-tab-local')));
        await tester.pumpAndSettle();
        expect(
          TmdbConfig.fromSettings(library.metadata.setting).usePlatform,
          true,
        );
        await tester.tap(find.byKey(const ValueKey('tmdb-enable-mode')));
        await tester.pumpAndSettle();
        expect(
          TmdbConfig.fromSettings(library.metadata.setting).usePlatform,
          false,
        );
        expect(library.metadata.setting(tmdbTokenKey), 'local-secret');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        library.close();
      },
    );
  }

  testWidgets('cannot enable local mode without a token', (tester) async {
    final library = LibraryService(sqlite3.openInMemory());
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(body: TmdbSettingsSection(library: library)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tmdb-tab-local')));
    await tester.pumpAndSettle();
    final button = tester.widget<ShadButton>(
      find.byKey(const ValueKey('tmdb-enable-mode')),
    );
    expect(button.onPressed, isNull);
    expect(TmdbConfig.fromSettings(library.metadata.setting).usePlatform, true);
    await tester.pumpWidget(const SizedBox());
    library.close();
  });
}
