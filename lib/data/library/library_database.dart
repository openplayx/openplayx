import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../metadata/metadata_repository.dart';
import '../metadata/metadata_queue.dart';

/// Owns the library file location, schema migration and crash recovery.
abstract final class LibraryDatabase {
  static Future<Database> open(String name) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+\.sqlite3$').hasMatch(name)) {
      throw ArgumentError('Invalid library database name');
    }
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return sqlite3.open('${dir.path}${Platform.pathSeparator}$name');
  }

  static T transaction<T>(Database db, T Function() action) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final result = action();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  static void initialize(Database db, {bool recoverInterrupted = true}) {
    final version = db.select('PRAGMA user_version').first.values.first as int;
    if (version > 4) throw StateError('媒体库版本较新，请升级应用');
    db.execute('PRAGMA foreign_keys=ON');
    db.execute('PRAGMA busy_timeout=5000');
    db.execute('''CREATE TABLE IF NOT EXISTS libraries (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL)''');
    db.execute(
      '''CREATE TABLE IF NOT EXISTS media (
      id TEXT PRIMARY KEY, title TEXT NOT NULL, favorite INTEGER NOT NULL DEFAULT 0)''',
    );
    db.execute('''CREATE TABLE IF NOT EXISTS resources (
      id TEXT PRIMARY KEY, media_id TEXT NOT NULL REFERENCES media(id),
      source TEXT NOT NULL, item TEXT NOT NULL, name TEXT NOT NULL,
      UNIQUE(source,item))''');
    db.execute(
      '''CREATE TABLE IF NOT EXISTS bindings (
      id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE,
      source TEXT NOT NULL, root TEXT, status TEXT NOT NULL DEFAULT '待扫描', error TEXT)''',
    );
    // v4: a binding is a user-facing "file source" (a connection plus one
    // chosen folder). It carries a display name and an enable switch.
    final bindingColumns = db
        .select('PRAGMA table_info(bindings)')
        .map((r) => r['name'])
        .toSet();
    if (!bindingColumns.contains('name')) {
      db.execute('ALTER TABLE bindings ADD COLUMN name TEXT');
    }
    if (!bindingColumns.contains('enabled')) {
      db.execute(
        'ALTER TABLE bindings ADD COLUMN enabled INTEGER NOT NULL DEFAULT 1',
      );
    }
    db.execute('''CREATE TABLE IF NOT EXISTS memberships (
      library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE,
      media_id TEXT NOT NULL REFERENCES media(id), added_at INTEGER NOT NULL,
      PRIMARY KEY(library_id,media_id))''');
    db.execute(
      '''CREATE TABLE IF NOT EXISTS evidence (
      binding_id TEXT NOT NULL REFERENCES bindings(id) ON DELETE CASCADE,
      resource_id TEXT NOT NULL REFERENCES resources(id), seen TEXT NOT NULL,
      available INTEGER NOT NULL DEFAULT 1, PRIMARY KEY(binding_id,resource_id))''',
    );
    db.execute('''CREATE TABLE IF NOT EXISTS ignored (
      library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE,
      media_id TEXT NOT NULL, PRIMARY KEY(library_id,media_id))''');
    db.execute(
      '''CREATE TABLE IF NOT EXISTS local_identity (
      path TEXT PRIMARY KEY, resource_id TEXT NOT NULL REFERENCES resources(id))''',
    );
    db.execute('''CREATE TABLE IF NOT EXISTS progress (
      resource_id TEXT PRIMARY KEY REFERENCES resources(id), session TEXT NOT NULL,
      position INTEGER NOT NULL DEFAULT 0, duration INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL, completed INTEGER NOT NULL DEFAULT 0)''');
    db.execute('''CREATE TABLE IF NOT EXISTS resource_locators (
      source TEXT NOT NULL, item TEXT NOT NULL, resource_id TEXT NOT NULL REFERENCES resources(id),
      PRIMARY KEY(source,item))''');
    db.execute(
      'INSERT OR IGNORE INTO resource_locators SELECT source,item,id FROM resources',
    );
    db.execute(
      '''CREATE TABLE IF NOT EXISTS manual_memberships (
      library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE,
      media_id TEXT NOT NULL REFERENCES media(id), PRIMARY KEY(library_id,media_id))''',
    );
    db.execute('''CREATE TABLE IF NOT EXISTS scan_tasks (
      binding_id TEXT PRIMARY KEY REFERENCES bindings(id) ON DELETE CASCADE,
      batch TEXT NOT NULL, revision INTEGER NOT NULL)''');
    db.execute('''CREATE TABLE IF NOT EXISTS scan_queue (
      binding_id TEXT NOT NULL REFERENCES scan_tasks(binding_id) ON DELETE CASCADE,
      node TEXT NOT NULL, offset INTEGER NOT NULL DEFAULT 0, done INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(binding_id,node))''');
    db.execute('''CREATE TABLE IF NOT EXISTS source_media (
      source TEXT NOT NULL, source_key TEXT NOT NULL, media_id TEXT NOT NULL REFERENCES media(id),
      kind TEXT NOT NULL, parent_key TEXT, year INTEGER, season INTEGER, episode INTEGER,
      PRIMARY KEY(source,source_key))''');
    db.execute(
      '''CREATE TABLE IF NOT EXISTS media_evidence (
      binding_id TEXT NOT NULL REFERENCES bindings(id) ON DELETE CASCADE,
      media_id TEXT NOT NULL REFERENCES media(id), PRIMARY KEY(binding_id,media_id))''',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS membership_order ON memberships(library_id,added_at DESC,media_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS locator_resource ON resource_locators(resource_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS resources_media ON resources(media_id)',
    );
    // The memberships primary key leads with library_id; the metadata queue's
    // EXISTS(... WHERE media_id=?) checks would otherwise scan the whole table.
    db.execute(
      'CREATE INDEX IF NOT EXISTS memberships_media ON memberships(media_id)',
    );
    // Same shape: these composite primary keys lead with another column, so the
    // library list's per-row EXISTS checks would build a temp index every query.
    db.execute(
      'CREATE INDEX IF NOT EXISTS media_evidence_media ON media_evidence(media_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS manual_memberships_media ON manual_memberships(media_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS source_media_parent ON source_media(source,parent_key)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS source_media_media ON source_media(media_id)',
    );
    final metadata = MetadataRepository(db);
    transaction(db, () {
      metadata.migrate();
      MetadataQueue.migrate(db);
      if (version < 2) {
        // Existing manual titles from v1 must become locks on first upgrade.
        db.execute(
          '''INSERT OR IGNORE INTO metadata_overrides
          SELECT m.id,'title',json_quote(m.title),0 FROM media m
          WHERE EXISTS (SELECT 1 FROM resources r WHERE r.media_id=m.id AND r.name<>m.title)
          AND NOT EXISTS (SELECT 1 FROM source_media s WHERE s.media_id=m.id)''',
        );
      }
      db.execute('PRAGMA user_version=4');
    });
    if (recoverInterrupted) metadata.recover();
    // A crashed or interrupted scan must never reconcile missing observations.
    if (recoverInterrupted) {
      db.execute(
        "UPDATE bindings SET status='扫描中断', error='请重新扫描' WHERE status='扫描中'",
      );
    }
  }
}
