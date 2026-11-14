import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/library/library_database.dart';
import 'package:openplayx/data/library/library_repository.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('repository can initialize and roll back without a service', () {
    final repository = LibraryRepository(sqlite3.openInMemory());
    addTearDown(repository.close);
    expect(
      () => repository.transaction(() {
        repository.insertMedia('m', 'Movie');
        throw StateError('abort');
      }),
      throwsStateError,
    );
    expect(repository.db.select('SELECT * FROM media'), isEmpty);
    repository.transaction(() => repository.insertMedia('n', 'TV'));
    expect(repository.db.select('SELECT id FROM media').single['id'], 'n');
  });

  test('repository recovery preserves resumable scans and observations', () {
    final db = sqlite3.openInMemory(), configuration = sqlite3.openInMemory();
    final first = LibraryRepository(db, configuration: configuration);
    addTearDown(db.close);
    addTearDown(configuration.close);
    first.insertFileSource('b', 's', null, null);
    first.insertMedia('m', 'Movie');
    first.insertResource('r', 'm', 's', 'movie', 'movie.mp4');
    first.insertScanTask('b', 'batch', 1);
    first.insertScanRoot('b', '');
    first.observeResource('b', 'r', 'batch');
    first.markScanRunning('b');
    final background = LibraryRepository(
      db,
      configuration: configuration,
      recoverInterrupted: false,
    );
    expect(background.fileSource('b')!['status'], '扫描中');
    final recovered = LibraryRepository(db, configuration: configuration);
    expect(recovered.fileSource('b')!['status'], '扫描中断');
    expect(recovered.scanTask('b').single['batch'], 'batch');
    expect(recovered.resourceObservations('r').single['available'], 1);
    expect(
      db.select('PRAGMA user_version').single.values.single,
      LibraryDatabase.version,
    );
  });

  test('file sources are configuration; their scan state is library data', () {
    final db = sqlite3.openInMemory(), configuration = sqlite3.openInMemory();
    final repository = LibraryRepository(db, configuration: configuration);
    addTearDown(repository.close);
    repository.insertFileSource('f', 's', '/movies', 'Movies');
    repository.markScanFailed('offline', 'f');
    expect(
      configuration
          .select('SELECT source_id, root, name FROM file_sources')
          .single,
      {'source_id': 's', 'root': '/movies', 'name': 'Movies'},
    );
    expect(db.select('SELECT status, error FROM file_source_state').single, {
      'status': '扫描失败',
      'error': 'offline',
    });
    expect(repository.fileSources().single, {
      'id': 'f',
      'source': 's',
      'root': '/movies',
      'name': 'Movies',
      'enabled': 1,
      'status': '扫描失败',
      'error': 'offline',
    });
    for (final table in ['libraries', 'bindings', 'metadata_settings']) {
      expect(
        db.select("SELECT 1 FROM sqlite_master WHERE name=?", [table]),
        isEmpty,
        reason: table,
      );
    }
  });

  test('an older library file is emptied and rebuilt, not migrated', () {
    final db = sqlite3.openInMemory();
    db.execute('CREATE TABLE libraries (id TEXT PRIMARY KEY)');
    db.execute("INSERT INTO libraries VALUES ('default')");
    db.execute('PRAGMA user_version=4');
    final repository = LibraryRepository(db);
    addTearDown(repository.close);
    expect(
      db.select("SELECT 1 FROM sqlite_master WHERE name='libraries'"),
      isEmpty,
    );
    expect(
      db.select('PRAGMA user_version').single.values.single,
      LibraryDatabase.version,
    );
    repository.insertMedia('m', 'Movie');
    repository.observeMembership('m', 1);
    expect(
      db.select('SELECT media_id FROM memberships').single['media_id'],
      'm',
    );
  });

  test('newer schemas are rejected before any library tables are created', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute('PRAGMA user_version=99');
    expect(() => LibraryRepository(db), throwsStateError);
    expect(
      db.select("SELECT name FROM sqlite_master WHERE type='table'"),
      isEmpty,
    );
  });

  test('database name validation occurs before filesystem access', () async {
    await expectLater(
      LibraryDatabase.open('../other.sqlite3'),
      throwsArgumentError,
    );
  });

  test(
    'service publishes committed changes and suppresses rolled back changes',
    () async {
      final service = LibraryService(sqlite3.openInMemory());
      addTearDown(service.close);
      var notifications = 0;
      final subscription = service.changes.listen((_) => notifications++);
      addTearDown(subscription.cancel);
      expect(
        () => service.transaction(() {
          service.repository.insertMedia('rolled-back', 'Rolled back');
          throw StateError('abort');
        }),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.db.select('SELECT * FROM media'), isEmpty);
      expect(notifications, 0);
      service.transaction(
        () => service.repository.insertMedia('committed', 'Committed'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        service.db.select('SELECT title FROM media').single['title'],
        'Committed',
      );
      expect(notifications, 1);
    },
  );
}
