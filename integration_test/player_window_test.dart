import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/app/player_window.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/data/sources/source_config.dart';

import 'support/live_services.dart';
import 'support/source_services.dart';

// Desktop only (separate OS windows). Runs with `flutter drive` so child
// engines receive their entrypoint arguments; see integration_test/README.md.
// The SMB case needs the tool/source_services stack (required, never skipped).
// Choosing a saved recognised subtitle in the child window is covered by
// assistant_movie_flow_test.dart.
final _data = Directory(
  '${Directory.systemTemp.path}/openplayx-it-player-window',
);

Future<void> main([List<String> args = const []]) async {
  // Main and child engines share one scratch data directory, not the user's.
  useAppDataDirectory(_data);
  if (await runPlayerWindowIfRequested(args)) return;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (_data.existsSync()) _data.deleteSync(recursive: true);
  _data.createSync(recursive: true);
  for (final smb in [false, true]) {
    testWidgets(
      'real desktop window plays ${smb ? 'an SMB source' : 'local fixture'}',
      (tester) async {
        if (smb) {
          requireDefines({'SOURCE_HOST': sourceHost});
          await requireReachable('SMB test service', sourceHost, 445);
        }
        await tester.pumpWidget(const OpenPlayXApp(home: SizedBox.shrink()));
        final sources = SourceManager();
        Directory? temp;
        try {
          final SourceSelection selection;
          if (smb) {
            final config = sourceServiceConfig(SourceKind.smb, sourceHost, {});
            await sources.save(
              config,
              sourceServiceSecret(SourceKind.smb, const {}),
            );
            final entry = (await sources.browse(
              config.id,
              const BrowseRequest(),
            )).entries.firstWhere((e) => e.name.endsWith('.mp4'));
            selection = SourceSelection(
              entry.name,
              await sources.resolve(entry.ref),
              ref: entry.ref,
            );
          } else {
            temp = await Directory.systemTemp.createTemp('opx-window-');
            final data = await rootBundle.load('test/fixtures/test_video.mp4');
            final file = File('${temp.path}/fixture.mp4')
              ..writeAsBytesSync(data.buffer.asUint8List());
            selection = SourceSelection(
              'Fixture',
              PlayableStream(file.uri),
              ref: ResourceRef('@local', file.path),
            );
          }
          final windows = PlayerWindows();
          expect(await windows.open(selection), true);
          var snapshot = await windows.snapshot(waitForSession: true);
          for (var i = 0; i < 40; i++) {
            debugPrint('WINDOW ${smb ? 'SMB' : 'local'} $i: $snapshot');
            if (snapshot['status'] == 'playing') break;
            await tester.pump(const Duration(milliseconds: 250));
            snapshot = await windows.snapshot();
          }
          expect(snapshot['status'], 'playing');
          expect(
            snapshot['duration_ms'] as num,
            inInclusiveRange(11000, 13000),
          );
          await windows.control('stop', {'session_id': snapshot['session_id']});
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await sources.dispose();
          await temp?.delete(recursive: true);
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
