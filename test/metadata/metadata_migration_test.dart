import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/services/library/library_service.dart';

void main() {
  test(
    'restart cancels interrupted jobs and retains saved candidate selections',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'openplayx-migration-',
      );
      final path = '${root.path}/library.sqlite3';
      var library = LibraryService(sqlite3.open(path));
      try {
        final media = library.register(
          const SourceEntry(
            ResourceRef('files', '/Film.mkv'),
            'Film.mkv',
            isFolder: false,
          ),
        );
        final active = library.metadata.createJob(media, {'query': 'Film'});
        library.metadata.stage(active, 'fetching');
        final waiting = library.metadata.createJob(media, {'query': 'Film'});
        library.metadata.stage(waiting, 'awaitingSelection');
        library.close();
        library = LibraryService(sqlite3.open(path));
        expect(library.metadata.job(active)['stage'], 'cancelled');
        expect(library.metadata.job(active)['error_code'], 'interrupted');
        expect(library.metadata.job(waiting)['stage'], 'awaitingSelection');
        expect(library.resources(media), hasLength(1));
      } finally {
        library.close();
        await root.delete(recursive: true);
      }
    },
  );
}
