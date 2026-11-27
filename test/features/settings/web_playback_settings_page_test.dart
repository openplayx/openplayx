import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/web_playback/web_playback_service.dart';
import 'package:openplayx/features/settings/settings_page.dart';
import 'package:openplayx/features/settings/web_playback_settings_page.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';

import '../../app_test_host.dart';
import '../../capabilities/web_playback/web_playback_service_test.dart'
    show TestCatalog;

void main() {
  for (final width in [390.0, 1100.0]) {
    testWidgets('Web service settings navigates and fits at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = WebPlaybackService(
        TestCatalog(File('test/fixtures/test_video.mp4')),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        TestApp(home: SettingsPage(webPlayback: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-web-playback')));
      await tester.pumpAndSettle();
      expect(find.byType(WebPlaybackSettingsPage), findsOneWidget);
      final l = AppLocalizations.of(
        tester.element(find.byType(WebPlaybackSettingsPage)),
      );
      expect(find.text(l.webPlaybackStopped), findsOneWidget);
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text(l.webPlaybackCode), findsNothing);
      expect(service.running, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
