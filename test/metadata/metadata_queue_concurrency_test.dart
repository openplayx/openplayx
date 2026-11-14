import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/core/plugins/metadata_capability.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/metadata/metadata_queue.dart';
import 'package:openplayx/services/library/library_service.dart';

void main() {
  test('separate database connections cannot claim one item or commit an expired lease', () async {
    final root = await Directory.systemTemp.createTemp(
      'openplayx-queue-lease-',
    );
    final path = '${root.path}/library.sqlite3';
    final first = LibraryService(
      sqlite3.open(path),
      watchExternalChanges: false,
    );
    LibraryService? second;
    try {
      final media = first.register(
        const SourceEntry(
          ResourceRef('s', '/Film.mkv'),
          'Film.mkv',
          isFolder: false,
        ),
      );
      first.addManual(media);
      second = LibraryService(
        sqlite3.open(path),
        recoverInterrupted: false,
        watchExternalChanges: false,
      );
      var time = DateTime.now();
      final a = MetadataQueue(first.db, clock: () => time),
          b = MetadataQueue(second.db, clock: () => time);
      expect(
        a.claim('first', lease: const Duration(seconds: 1))!['media_id'],
        media,
      );
      expect(b.claim('second'), isNull);
      time = time.add(const Duration(seconds: 2));
      expect(b.claim('second')!['media_id'], media);
      expect(a.finish(media, 'first', 'completed'), isFalse);
      expect(b.finish(media, 'second', 'completed'), isTrue);
      expect(a.item(media)!['state'], 'completed');
    } finally {
      second?.close();
      first.close();
      await root.delete(recursive: true);
    }
  });
  test('committed metadata from another engine becomes visible without reopening the library', () async {
    final root = await Directory.systemTemp.createTemp(
      'openplayx-queue-reactive-',
    );
    final path = '${root.path}/library.sqlite3';
    final view = LibraryService(
      sqlite3.open(path),
      watchExternalChanges: false,
    );
    LibraryService? worker;
    try {
      final media = view.register(
        const SourceEntry(
          ResourceRef('s', '/raw.mkv'),
          'raw.mkv',
          isFolder: false,
        ),
      );
      view.addManual(media);
      worker = LibraryService(
        sqlite3.open(path),
        recoverInterrupted: false,
        watchExternalChanges: false,
      );
      view.checkExternalChanges();
      final changed = view.changes.first;
      worker.transaction(
        () => worker!.metadata.apply(
          media,
          MetadataRecord(
            ref: const MetadataRef('tmdb', MediaKind.movie, '1'),
            fields: const {'title': 'Scraped title'},
            artwork: const [ArtworkDescriptor(id: 'poster', type: 'poster')],
          ),
          sourceKey: 'tmdb',
          authority: 100,
          expectedRevision: 0,
          operationId: 'background-commit',
          select: true,
        ),
      );
      view.checkExternalChanges();
      await changed;
      expect(view.query().single['title'], 'Scraped title');
      expect(view.metadata.displayArtwork(media)!.id, 'poster');
    } finally {
      worker?.close();
      view.close();
      await root.delete(recursive: true);
    }
  });
  test('rolled back metadata never emits a publication event', () async {
    final library = LibraryService(
      sqlite3.openInMemory(),
      watchExternalChanges: false,
    );
    try {
      final media = library.register(
        const SourceEntry(
          ResourceRef('s', '/raw.mkv'),
          'raw.mkv',
          isFolder: false,
        ),
      );
      var changes = 0;
      final subscription = library.changes.listen((_) => changes++);
      expect(
        () => library.transaction(() {
          library.metadata.overrideField(
            media,
            'title',
            'Rolled back',
            expectedRevision: 0,
          );
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);
      expect(changes, 0);
      expect(library.metadata.fields(media)['title'], 'raw.mkv');
      await subscription.cancel();
    } finally {
      library.close();
    }
  });
}
