import 'package:sqlite3/sqlite3.dart';

/// Runtime state of each media source instance, in `library.sqlite3`
/// (`source_state`): which configuration revision was last applied, and
/// whether connecting with it succeeded. The configuration itself lives in
/// `plugin_instance_configs` of configuration.sqlite3, keyed by the same id.
class SourceStateStore {
  SourceStateStore(this.db) {
    ensureTable(db);
  }

  final Database db;

  /// Also called by the library schema, so a rebuilt library file keeps it.
  static void ensureTable(Database db) =>
      db.execute('''CREATE TABLE IF NOT EXISTS source_state (
      instance_id TEXT PRIMARY KEY, desired_revision INTEGER NOT NULL,
      applied_revision INTEGER, status TEXT NOT NULL, error_code TEXT)''');

  /// A newly saved revision: `pending` (or `disabled`) until applied.
  void reset(String id, int revision, String status) => db.execute(
    '''INSERT INTO source_state VALUES (?,?,NULL,?,NULL) ON CONFLICT(instance_id) DO UPDATE SET
      desired_revision=excluded.desired_revision, status=excluded.status, error_code=NULL''',
    [id, revision, status],
  );

  /// Records the outcome of applying [revision]; `ready` also makes it the
  /// applied revision.
  void mark(String id, int revision, String status, {String? errorCode}) =>
      db.execute(
        '''INSERT INTO source_state VALUES (?,?,?,?,?) ON CONFLICT(instance_id) DO UPDATE SET
        desired_revision=excluded.desired_revision,
        applied_revision=CASE WHEN excluded.status='ready' THEN excluded.applied_revision ELSE source_state.applied_revision END,
        status=excluded.status, error_code=excluded.error_code''',
        [id, revision, status == 'ready' ? revision : null, status, errorCode],
      );

  Map<String, Object?>? get(String id) {
    final rows = db.select('SELECT * FROM source_state WHERE instance_id=?', [
      id,
    ]);
    return rows.isEmpty ? null : Map.of(rows.first);
  }

  void delete(String id) =>
      db.execute('DELETE FROM source_state WHERE instance_id=?', [id]);
}
