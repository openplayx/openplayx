import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/app/player_window.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/services/subtitles/recognized_subtitles.dart';

Future<void> main([List<String> args = const []]) async {
  if (await runPlayerWindowIfRequested(args)) return;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final smb in [false, true]) {
    testWidgets(
      'real desktop window plays ${smb ? 'saved SMB clip' : 'local fixture'}',
      (tester) async {
        await tester.pumpWidget(const OpenPlayXApp(home: SizedBox.shrink()));
        final sources = SourceManager();
        Directory? temp;
        String? binding;
        try {
          final SourceSelection selection;
          if (smb) {
            final library = await LibraryService.open();
            final row = library.db
                .select(
                  "SELECT source,item,name FROM resources WHERE item LIKE '%OpenPlayX/%' AND name LIKE '%.mp4' ORDER BY rowid DESC LIMIT 1",
                )
                .single;
            final ref = ResourceRef(
              row['source'] as String,
              row['item'] as String,
            );
            final name = row['name'] as String;
            binding = recognizedSubtitles(library.db, ref).first.bindingId;
            library.close();
            await sources.load();
            selection = SourceSelection(
              name,
              await sources.resolve(ref),
              ref: ref,
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
          if (binding != null) {
            snapshot = await windows.control('set_subtitle', {
              'session_id': snapshot['session_id'],
              'binding_id': binding,
            });
            for (var i = 0; i < 20; i++) {
              debugPrint('WINDOW subtitle $i: $snapshot');
              if (snapshot['status'] == 'playing') break;
              await tester.pump(const Duration(milliseconds: 250));
              snapshot = await windows.snapshot();
            }
            expect(snapshot['status'], 'playing');
            expect((snapshot['subtitle'] as Map)['binding_id'], binding);
          }
          await windows.control('stop', {'session_id': snapshot['session_id']});
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await sources.dispose();
          await temp?.delete(recursive: true);
        }
      },
      skip: smb && !const bool.fromEnvironment('LIVE_ASSISTANT_FLOW'),
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
