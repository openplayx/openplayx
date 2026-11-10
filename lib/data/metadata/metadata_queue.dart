import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

/// Durable host queue shared by foreground UI and Android's headless engine.
/// Leases and ownership checks prevent concurrent engines applying one item.
class MetadataQueue {
  MetadataQueue(this.db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final Database db;
  final DateTime Function() _clock;
  int get now => _clock().millisecondsSinceEpoch;
  static void migrate(Database db) {
    db.execute('''CREATE TABLE IF NOT EXISTS metadata_queue (
      media_id TEXT PRIMARY KEY REFERENCES media(id), input_key TEXT NOT NULL DEFAULT '',
      state TEXT NOT NULL DEFAULT 'queued', phase INTEGER NOT NULL DEFAULT 0,
      attempts INTEGER NOT NULL DEFAULT 0, next_at INTEGER NOT NULL DEFAULT 0,
      lease_owner TEXT, lease_until INTEGER, job_id TEXT, error_code TEXT,
      updated_at INTEGER NOT NULL DEFAULT 0)''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS metadata_queue_due ON metadata_queue(state,next_at,phase)',
    );
    db.execute('''INSERT OR IGNORE INTO metadata_queue(media_id)
      SELECT DISTINCT media_id FROM memberships''');
  }

  static void observe(Database db, String media, {bool refresh = false}) {
    db.execute(
      'INSERT OR IGNORE INTO metadata_queue(media_id) SELECT ? WHERE EXISTS(SELECT 1 FROM memberships WHERE media_id=?)',
      [media, media],
    );
    if (refresh) {
      db.execute(
        "UPDATE metadata_queue SET state='queued',phase=0,attempts=0,next_at=0,error_code=NULL WHERE media_id=? AND state IN ('completed','unmatched','failed','skipped','waitingConfiguration')",
        [media],
      );
    }
  }

  static String fingerprint(Object input) =>
      sha256.convert(utf8.encode(jsonEncode(input))).toString();
  T _transaction<T>(T Function() action) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final value = action();
      db.execute('COMMIT');
      return value;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  int reconcile(Map<String, String> inputs) => _transaction(() {
    var added = 0;
    // Removed items stay in the library DB for playback history but leave work.
    db.execute(
      "UPDATE metadata_queue SET state='cancelled',lease_owner=NULL,lease_until=NULL WHERE state<>'cancelled' AND NOT EXISTS(SELECT 1 FROM memberships m WHERE m.media_id=metadata_queue.media_id)",
    );
    db.execute(
      "UPDATE metadata_queue SET state='queued',lease_owner=NULL,lease_until=NULL,error_code='interrupted' WHERE state='running' AND lease_until<=?",
      [now],
    );
    for (final entry in inputs.entries) {
      final old = db.select('SELECT * FROM metadata_queue WHERE media_id=?', [
        entry.key,
      ]).firstOrNull;
      final reset =
          old == null ||
          old['input_key'] != entry.value ||
          old['state'] == 'cancelled';
      if (reset) {
        db.execute(
          '''INSERT INTO metadata_queue(media_id,input_key,updated_at) VALUES (?,?,?)
          ON CONFLICT(media_id) DO UPDATE SET input_key=excluded.input_key,state='queued',phase=0,
          attempts=0,next_at=0,lease_owner=NULL,lease_until=NULL,job_id=NULL,error_code=NULL,updated_at=excluded.updated_at''',
          [entry.key, entry.value, now],
        );
        added++;
      } else if (old['state'] == 'completed' &&
          db.select('SELECT association FROM metadata_state WHERE media_id=?', [
                entry.key,
              ]).firstOrNull?['association'] ==
              null) {
        // Explicit reset matching invalidates an otherwise completed item.
        retry(entry.key);
        added++;
      } else if (old['state'] == 'awaitingSelection') {
        final latest = db.select(
          'SELECT stage,updated_at FROM metadata_jobs WHERE media_id=? ORDER BY updated_at DESC,rowid DESC LIMIT 1',
          [entry.key],
        ).firstOrNull;
        if (latest?['stage'] == 'completed' &&
            (latest!['updated_at'] as int) >= (old['updated_at'] as int)) {
          // Manual confirmation resolves ambiguity; finish image caching using
          // that selected identity instead of leaving a stale "waiting" badge.
          db.execute(
            "UPDATE metadata_queue SET state='queued',phase=1,attempts=0,next_at=0,error_code=NULL WHERE media_id=?",
            [entry.key],
          );
          added++;
        }
      }
    }
    return added;
  });
  Row? claim(
    String owner, {
    bool allowOnline = true,
    Duration lease = const Duration(minutes: 12),
  }) => _transaction(() {
    db.execute(
      "UPDATE metadata_queue SET state='queued',lease_owner=NULL,lease_until=NULL,error_code='interrupted' WHERE state='running' AND lease_until<=?",
      [now],
    );
    final row = db.select(
      "SELECT * FROM metadata_queue q WHERE state='queued' AND next_at<=? AND (?=1 OR phase=0) AND EXISTS(SELECT 1 FROM memberships m WHERE m.media_id=q.media_id) ORDER BY updated_at,media_id LIMIT 1",
      [now, allowOnline ? 1 : 0],
    ).firstOrNull;
    if (row == null) return null;
    db.execute(
      "UPDATE metadata_queue SET state='running',lease_owner=?,lease_until=?,updated_at=? WHERE media_id=?",
      [owner, now + lease.inMilliseconds, now, row['media_id']],
    );
    return db.select('SELECT * FROM metadata_queue WHERE media_id=?', [
      row['media_id'],
    ]).single;
  });
  bool owns(String media, String owner) => db.select(
    "SELECT 1 FROM metadata_queue q WHERE media_id=? AND state='running' AND lease_owner=? AND lease_until>? AND EXISTS(SELECT 1 FROM memberships m WHERE m.media_id=q.media_id)",
    [media, owner, now],
  ).isNotEmpty;
  bool finish(
    String media,
    String owner,
    String state, {
    String? error,
    String? job,
    int? phase,
    Duration delay = Duration.zero,
    bool retryable = false,
  }) {
    if (!owns(media, owner)) return false;
    final row = db.select('SELECT * FROM metadata_queue WHERE media_id=?', [
      media,
    ]).single;
    final attempts = (row['attempts'] as int) + (retryable ? 1 : 0);
    final failed = retryable && attempts >= 5;
    db.execute(
      '''UPDATE metadata_queue SET state=?,phase=?,attempts=?,next_at=?,lease_owner=NULL,
      lease_until=NULL,error_code=?,job_id=COALESCE(?,job_id),updated_at=? WHERE media_id=? AND lease_owner=?''',
      [
        failed ? 'failed' : state,
        phase ?? row['phase'],
        attempts,
        now + delay.inMilliseconds,
        error,
        job,
        now,
        media,
        owner,
      ],
    );
    return db.updatedRows == 1;
  }

  void release(String owner) => db.execute(
    "UPDATE metadata_queue SET state=CASE WHEN EXISTS(SELECT 1 FROM memberships m WHERE m.media_id=metadata_queue.media_id) THEN 'queued' ELSE 'cancelled' END,lease_owner=NULL,lease_until=NULL,error_code='interrupted' WHERE state='running' AND lease_owner=?",
    [owner],
  );
  void retry(String media) => db.execute(
    "UPDATE metadata_queue SET state='queued',phase=0,attempts=0,next_at=0,lease_owner=NULL,lease_until=NULL,error_code=NULL,updated_at=? WHERE media_id=?",
    [now, media],
  );
  void retryBlocked() => db.execute(
    "UPDATE metadata_queue SET state='queued',attempts=0,next_at=0,error_code=NULL WHERE state IN ('waitingConfiguration','failed')",
  );
  bool pending({bool allowOnline = true}) => db.select(
    "SELECT 1 FROM metadata_queue WHERE state IN ('queued','running') AND (?=1 OR phase=0) LIMIT 1",
    [allowOnline ? 1 : 0],
  ).isNotEmpty;
  Map<String, int> get counts => {
    for (final row in db.select(
      'SELECT state,COUNT(*) AS n FROM metadata_queue GROUP BY state',
    ))
      row['state'] as String: row['n'] as int,
  };
  Row? item(String media) => db.select(
    'SELECT * FROM metadata_queue WHERE media_id=?',
    [media],
  ).firstOrNull;
}
