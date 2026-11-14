import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../metadata/metadata_repository.dart';
import '../metadata/metadata_queue.dart';
import '../sources/source_state_store.dart';

/// `library.sqlite3`: what the App produces while it is used (scan results,
/// metadata, playback progress, tasks, conversations). It may grow large and
/// can be rebuilt; the user's configuration lives in `configuration.sqlite3`.
///
/// Owns the library file location, schema and crash recovery.
abstract final class LibraryDatabase {
  /// Schema version of this file. Older files are not migrated: they are
  /// emptied and rebuilt, since everything here can be scanned and scraped
  /// again.
  static const version = 5;

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

  /// Drops every table of an older file, including those other services
  /// create in it; they recreate their own tables when constructed.
  static void _reset(Database db) {
    db.execute('PRAGMA foreign_keys=OFF');
    transaction(db, () {
      for (final row in db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      )) {
        db.execute('DROP TABLE IF EXISTS "${row['name']}"');
      }
    });
    db.execute('PRAGMA user_version=0');
  }

  static void initialize(Database db, {bool recoverInterrupted = true}) {
    final current = db.select('PRAGMA user_version').first.values.first as int;
    if (current > version) throw StateError('媒体库版本较新，请升级应用');
    db.execute('PRAGMA busy_timeout=5000');
    if (current != 0 && current < version) _reset(db);
    db.execute('PRAGMA foreign_keys=ON');
    db.execute(
      '''CREATE TABLE IF NOT EXISTS media (
      id TEXT PRIMARY KEY, title TEXT NOT NULL, favorite INTEGER NOT NULL DEFAULT 0)''',
    );
    db.execute('''CREATE TABLE IF NOT EXISTS resources (
      id TEXT PRIMARY KEY, media_id TEXT NOT NULL REFERENCES media(id),
      source TEXT NOT NULL, item TEXT NOT NULL, name TEXT NOT NULL,
      UNIQUE(source,item))''');
    // The poster wall: media found by file sources or added by hand.
    db.execute(
      '''CREATE TABLE IF NOT EXISTS memberships (
      media_id TEXT PRIMARY KEY REFERENCES media(id), added_at INTEGER NOT NULL)''',
    );
    // Titles the user hid; scans do not bring them back.
    db.execute(
      'CREATE TABLE IF NOT EXISTS ignored (media_id TEXT PRIMARY KEY)',
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS manual_memberships (media_id TEXT PRIMARY KEY REFERENCES media(id))',
    );
    // Runtime state of each media source instance (applied configuration
    // revision, connection result), keyed by its id in
    // `plugin_instance_configs` of configuration.sqlite3; see SourceStateStore.
    SourceStateStore.ensureTable(db);
    // Scan state of each file source. The file sources themselves (source,
    // folder, name, switch) are configuration: `file_sources` in
    // configuration.sqlite3. Rows below are keyed by its id, without a
    // foreign key across the two files; removing a file source clears them.
    db.execute(
      '''CREATE TABLE IF NOT EXISTS file_source_state (
      file_source_id TEXT PRIMARY KEY, status TEXT NOT NULL DEFAULT '待扫描', error TEXT)''',
    );
    db.execute(
      '''CREATE TABLE IF NOT EXISTS evidence (
      file_source_id TEXT NOT NULL,
      resource_id TEXT NOT NULL REFERENCES resources(id), seen TEXT NOT NULL,
      available INTEGER NOT NULL DEFAULT 1, PRIMARY KEY(file_source_id,resource_id))''',
    );
    db.execute(
      '''CREATE TABLE IF NOT EXISTS media_evidence (
      file_source_id TEXT NOT NULL,
      media_id TEXT NOT NULL REFERENCES media(id), PRIMARY KEY(file_source_id,media_id))''',
    );
    db.execute(
      '''CREATE TABLE IF NOT EXISTS scan_tasks (
      file_source_id TEXT PRIMARY KEY, batch TEXT NOT NULL, revision INTEGER NOT NULL)''',
    );
    db.execute('''CREATE TABLE IF NOT EXISTS scan_queue (
      file_source_id TEXT NOT NULL REFERENCES scan_tasks(file_source_id) ON DELETE CASCADE,
      node TEXT NOT NULL, offset INTEGER NOT NULL DEFAULT 0, done INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(file_source_id,node))''');
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
    db.execute('''CREATE TABLE IF NOT EXISTS source_media (
      source TEXT NOT NULL, source_key TEXT NOT NULL, media_id TEXT NOT NULL REFERENCES media(id),
      kind TEXT NOT NULL, parent_key TEXT, year INTEGER, season INTEGER, episode INTEGER,
      PRIMARY KEY(source,source_key))''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS membership_order ON memberships(added_at DESC,media_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS locator_resource ON resource_locators(resource_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS resources_media ON resources(media_id)',
    );
    // The composite primary key leads with another column, so the library
    // list's per-row EXISTS checks would build a temp index every query.
    db.execute(
      'CREATE INDEX IF NOT EXISTS media_evidence_media ON media_evidence(media_id)',
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
      db.execute('PRAGMA user_version=$version');
    });
    if (recoverInterrupted) metadata.recover();
    // A crashed or interrupted scan must never reconcile missing observations.
    if (recoverInterrupted) {
      db.execute(
        "UPDATE file_source_state SET status='扫描中断', error='请重新扫描' WHERE status='扫描中'",
      );
    }
  }
}
