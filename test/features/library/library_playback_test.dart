import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:openplayx/features/player/player_page.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx_playback/playback.dart';
import 'package:sqlite3/sqlite3.dart';

import '../player/player_page_test.dart' show FakeBackend;

class ResumeBackend extends FakeBackend {
  final resumed = Completer<void>();
  @override
  Future<void> seek(Duration position) async {
    await super.seek(position);
    value = PlayerSnapshot(
      status: PlaybackStatus.playing,
      position: position,
      duration: const Duration(seconds: 60),
      canSeek: true,
    );
    if (!resumed.isCompleted) resumed.complete();
  }
}

void main() {
  testWidgets(
    'direct playback resumes its exact resource and stores a backward seek without joining a library',
    (tester) async {
      final service = LibraryService(sqlite3.openInMemory());
      final backend = ResumeBackend();
      const ref = ResourceRef('@local', '/demo.mp4');
      final media = service.register(
        const SourceEntry(ref, 'Demo', isFolder: false),
        localPath: '/demo.mp4',
      );
      final resource = service.resourceFor(ref)!['id'] as String;
      service.saveProgress(
        resource,
        service.beginSession(resource),
        const Duration(seconds: 30),
        const Duration(seconds: 60),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerPage(
            backend: backend,
            libraryService: service,
            pickMedia: () async => LocalMedia(Uri.file('/demo.mp4'), 'Demo'),
          ),
        ),
      );
      await tester.state<PlayerPageState>(find.byType(PlayerPage)).openFile();
      await tester.pump();
      for (var i = 0; i < 20 && !backend.resumed.isCompleted; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(backend.seeks, [const Duration(seconds: 30)]);
      backend.value = const PlayerSnapshot(
        status: PlaybackStatus.paused,
        position: Duration(seconds: 10),
        duration: Duration(seconds: 60),
        canSeek: true,
      );
      await tester.pump();
      expect(service.checkpoint(resource)!['position'], 10000);
      expect(service.libraries, isEmpty);
      expect(service.continueWatching().single['id'], media);
      await tester.pumpWidget(const SizedBox());
      service.close();
    },
  );
}
