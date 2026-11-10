import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/services/library/library_service.dart';

void main() {
  test('v1 migration locks manually corrected titles and preserves stable resources', () {
    final db = sqlite3.openInMemory();
    db.execute(
      'CREATE TABLE media(id TEXT PRIMARY KEY,title TEXT NOT NULL,favorite INTEGER NOT NULL DEFAULT 0)',
    );
    db.execute(
      'CREATE TABLE resources(id TEXT PRIMARY KEY,media_id TEXT NOT NULL REFERENCES media(id),source TEXT NOT NULL,item TEXT NOT NULL,name TEXT NOT NULL,UNIQUE(source,item))',
    );
    db.execute("INSERT INTO media VALUES ('m','My corrected title',1)");
    db.execute(
      "INSERT INTO resources VALUES ('r','m','files','/Film.mkv','Film.mkv')",
    );
    db.execute('PRAGMA user_version=1');
    final library = LibraryService(db);
    try {
      expect(db.select('PRAGMA user_version').single.values.single, 3);
      expect(library.metadata.lockedFields('m'), contains('title'));
      expect(library.metadata.fields('m')['title'], 'My corrected title');
      expect(library.resources('m').single['id'], 'r');
      expect(db.select('SELECT favorite FROM media').single['favorite'], 1);
    } finally {
      library.close();
    }
  });
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
