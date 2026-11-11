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
        repository.insertLibrary('a', 'Movies', 'mixed');
        repository.insertMedia('m', 'Movie');
        throw StateError('abort');
      }),
      throwsStateError,
    );
    expect(repository.libraries(), isEmpty);
    expect(repository.db.select('SELECT * FROM media'), isEmpty);
    repository.transaction(() => repository.insertLibrary('b', 'TV', 'mixed'));
    expect(repository.libraries().single['id'], 'b');
  });

  test('repository recovery preserves resumable scans and observations', () {
    final db = sqlite3.openInMemory();
    final first = LibraryRepository(db);
    addTearDown(db.close);
    first.insertLibrary('l', 'Movies', 'mixed');
    first.insertBinding('b', 'l', 's', null, null);
    first.insertMedia('m', 'Movie');
    first.insertResource('r', 'm', 's', 'movie', 'movie.mp4');
    first.insertScanTask('b', 'batch', 1);
    first.insertScanRoot('b', '');
    first.observeResource('b', 'r', 'batch');
    first.markScanRunning('b');
    final background = LibraryRepository(db, recoverInterrupted: false);
    expect(background.binding('b').single['status'], '扫描中');
    final recovered = LibraryRepository(db);
    expect(recovered.binding('b').single['status'], '扫描中断');
    expect(recovered.scanTask('b').single['batch'], 'batch');
    expect(recovered.resourceObservations('r').single['available'], 1);
    expect(db.select('PRAGMA user_version').single.values.single, 4);
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
          service.create('Rolled back');
          throw StateError('abort');
        }),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.libraries, isEmpty);
      expect(notifications, 0);
      service.transaction(() => service.create('Committed'));
      await Future<void>.delayed(Duration.zero);
      expect(service.libraries.single['name'], 'Committed');
      expect(notifications, 1);
    },
  );
}
