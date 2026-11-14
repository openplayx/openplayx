import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../configuration/configuration_database.dart';
import '../metadata/metadata_repository.dart';
import '../metadata/metadata_queue.dart';
import 'library_database.dart';

/// Library persistence. No source connections, widgets or scan traversal live here.
/// Multi-step business operations use [transaction] to commit atomically.
/// SQL condition for media `m`: false for metadata containers (series,
/// seasons) whose descendant files are all hidden dot files, such as macOS
/// `._episode.mkv` sidecars kept from scans before those were filtered.
/// Without it each such series appears twice: once for the real files and
/// once for the sidecars, which metadata grouping put in a separate container.
const _visibleContainer =
    """NOT (EXISTS (SELECT 1 FROM metadata_relations c1 WHERE c1.parent_id=m.id)
        AND NOT EXISTS (SELECT 1 FROM resources r WHERE r.media_id=m.id AND substr(r.name,1,1)<>'.')
        AND NOT EXISTS (SELECT 1 FROM metadata_relations c1 JOIN resources r ON r.media_id=c1.child_id WHERE c1.parent_id=m.id AND substr(r.name,1,1)<>'.')
        AND NOT EXISTS (SELECT 1 FROM metadata_relations c1 JOIN metadata_relations c2 ON c2.parent_id=c1.child_id JOIN resources r ON r.media_id=c2.child_id WHERE c1.parent_id=m.id AND substr(r.name,1,1)<>'.')
        AND (EXISTS (SELECT 1 FROM metadata_relations c1 JOIN resources r ON r.media_id=c1.child_id WHERE c1.parent_id=m.id)
          OR EXISTS (SELECT 1 FROM metadata_relations c1 JOIN metadata_relations c2 ON c2.parent_id=c1.child_id JOIN resources r ON r.media_id=c2.child_id WHERE c1.parent_id=m.id)))""";

class LibraryRepository {
  LibraryRepository(
    this.db, {
    Database? configuration,
    bool recoverInterrupted = true,
    void Function()? onChanged,
  }) : configuration = configuration ?? sqlite3.openInMemory() {
    ConfigurationDatabase.initialize(this.configuration);
    LibraryDatabase.initialize(db, recoverInterrupted: recoverInterrupted);
    metadata = MetadataRepository(
      db,
      configuration: this.configuration,
      onChanged: onChanged,
    );
  }
  final Database db;

  /// `configuration.sqlite3` (in memory when none is given, e.g. in tests).
  final Database configuration;
  late final MetadataRepository metadata;
  T transaction<T>(T Function() action) =>
      LibraryDatabase.transaction(db, action);
  ({int done, int total}) metadataProgress() => MetadataQueue(db).progress;
  ({int done, int total}) metadataProgressFor(String fileSource) =>
      MetadataQueue(db).progressFor(fileSource);
  int prioritizeMetadata(List<String> ids) => MetadataQueue(db).boost(ids);
  void queueMetadata(String media, {bool refresh = false}) =>
      MetadataQueue.observe(db, media, refresh: refresh);

  List<Row> query({
    String search = '',
    bool favorites = false,
    String? source,
    String? contentType,
    int? year,
    bool? watched,
    int offset = 0,
    int limit = 40,
  }) {
    return db.select(
      '''SELECT m.*, lm.added_at, COUNT(*) OVER() AS total FROM media m JOIN memberships lm ON lm.media_id=m.id
      WHERE instr(lower(m.title),lower(?))>0 ${favorites ? 'AND m.favorite=1' : ''}
      AND NOT (EXISTS (SELECT 1 FROM media_evidence e WHERE e.media_id=m.id)
        AND NOT EXISTS (SELECT 1 FROM media_evidence e WHERE e.media_id=m.id AND e.file_source_id IN (SELECT value FROM json_each(?)))
        AND NOT EXISTS (SELECT 1 FROM manual_memberships mm WHERE mm.media_id=m.id))
      AND NOT (EXISTS (SELECT 1 FROM resources r WHERE r.media_id=m.id)
        AND NOT EXISTS (SELECT 1 FROM resources r WHERE r.media_id=m.id AND substr(r.name,1,1)<>'.'))
      AND $_visibleContainer
      AND (?<>'' OR ${favorites ? '1' : '0'}=1 OR ? IS NOT NULL OR ? IS NOT NULL OR NOT EXISTS (SELECT 1 FROM source_media child JOIN source_media parent ON child.source=parent.source AND child.parent_key=parent.source_key JOIN memberships pm ON pm.media_id=parent.media_id WHERE child.media_id=m.id))
      AND (?<>'' OR ${favorites ? '1' : '0'}=1 OR ? IS NOT NULL OR ? IS NOT NULL OR NOT EXISTS (SELECT 1 FROM metadata_relations mr JOIN memberships pm ON pm.media_id=mr.parent_id WHERE mr.child_id=m.id))
      AND (? IS NULL OR EXISTS (SELECT 1 FROM source_media sm WHERE sm.media_id=m.id AND sm.source=?) OR EXISTS (SELECT 1 FROM resources r JOIN resource_locators l ON l.resource_id=r.id WHERE r.media_id=m.id AND l.source=?))
      AND (? IS NULL OR COALESCE((SELECT json_extract(mp.fields,'\$.kind') FROM metadata_projection mp WHERE mp.media_id=m.id),(SELECT sm.kind FROM source_media sm WHERE sm.media_id=m.id LIMIT 1),'video')=?)
      AND (? IS NULL OR COALESCE((SELECT json_extract(mp.fields,'\$.year') FROM metadata_projection mp WHERE mp.media_id=m.id),(SELECT sm.year FROM source_media sm WHERE sm.media_id=m.id LIMIT 1))=?)
      AND (? IS NULL OR EXISTS (SELECT 1 FROM progress p JOIN resources r ON r.id=p.resource_id WHERE r.media_id=m.id AND p.completed=1)=?)
      ORDER BY lm.added_at DESC,m.id LIMIT ? OFFSET ?''',
      [
        search,
        jsonEncode(enabledFileSourceIds()),
        search,
        contentType,
        year,
        search,
        contentType,
        year,
        source,
        source,
        source,
        contentType,
        contentType,
        year,
        year,
        watched == null ? null : 1,
        watched == true ? 1 : 0,
        limit,
        offset,
      ],
    );
  }

  int get dataVersion =>
      db.select('PRAGMA data_version').single.values.single as int;

  void close() {
    db.close();
    configuration.close();
  }

  // ---- File sources: configuration in `file_sources` (configuration.sqlite3),
  // scan state in `file_source_state` (this database).

  static Map<String, Object?> _fileSource(Row config, Row? state) => {
    'id': config['id'],
    'source': config['source_id'],
    'root': config['root'],
    'name': config['name'],
    'enabled': config['enabled'],
    'status': state?['status'] ?? '待扫描',
    'error': state?['error'],
  };

  /// Every file source with its scan state, oldest first.
  List<Map<String, Object?>> fileSources() {
    final states = {
      for (final r in db.select('SELECT * FROM file_source_state'))
        r['file_source_id'] as String: r,
    };
    return [
      for (final c in configuration.select(
        'SELECT * FROM file_sources ORDER BY created, id',
      ))
        _fileSource(c, states[c['id']]),
    ];
  }

  Map<String, Object?>? fileSource(String id) {
    final config = configuration.select(
      'SELECT * FROM file_sources WHERE id=?',
      [id],
    ).firstOrNull;
    if (config == null) return null;
    return _fileSource(
      config,
      db.select('SELECT * FROM file_source_state WHERE file_source_id=?', [
        id,
      ]).firstOrNull,
    );
  }

  bool fileSourceExists(String id) => configuration.select(
    'SELECT 1 FROM file_sources WHERE id=?',
    [id],
  ).isNotEmpty;

  List<String> enabledFileSourceIds() => [
    for (final r in configuration.select(
      'SELECT id FROM file_sources WHERE enabled=1',
    ))
      r['id'] as String,
  ];

  void insertFileSource(String id, String source, String? root, String? name) =>
      configuration.execute(
        'INSERT INTO file_sources(id,source_id,root,name,created) VALUES (?,?,?,?,?)',
        [id, source, root, name, DateTime.now().microsecondsSinceEpoch],
      );

  void setFileSourceEnabled(String id, bool enabled) => configuration.execute(
    'UPDATE file_sources SET enabled=? WHERE id=?',
    [enabled ? 1 : 0, id],
  );

  void renameFileSource(String id, String name) => configuration.execute(
    'UPDATE file_sources SET name=? WHERE id=?',
    [name, id],
  );

  void deleteFileSource(String id) =>
      configuration.execute('DELETE FROM file_sources WHERE id=?', [id]);

  /// Scan results and state of [id], for removing the file source.
  void deleteFileSourceData(String id) {
    for (final table in [
      'scan_queue',
      'scan_tasks',
      'evidence',
      'media_evidence',
      'file_source_state',
    ]) {
      db.execute('DELETE FROM $table WHERE file_source_id=?', [id]);
    }
  }

  void _setScanState(String id, String status, String? error) => db.execute(
    'INSERT INTO file_source_state VALUES (?,?,?) '
    'ON CONFLICT(file_source_id) DO UPDATE SET status=excluded.status, error=excluded.error',
    [id, status, error],
  );

  ResultSet sourceMedia(String source, String key) => db.select(
    'SELECT media_id FROM source_media WHERE source=? AND source_key=?',
    [source, key],
  );

  ResultSet sourceParent(String source, String key) => db.select(
    'SELECT parent_key FROM source_media WHERE source=? AND source_key=?',
    [source, key],
  );

  void insertMedia(String id, String title) =>
      db.execute('INSERT INTO media(id,title) VALUES (?,?)', [id, title]);

  void insertSourceMedia(
    String source,
    String key,
    String media,
    String kind,
    String? parent,
    int? year,
    int? season,
    int? episode,
  ) => db.execute('INSERT INTO source_media VALUES (?,?,?,?,?,?,?,?)', [
    source,
    key,
    media,
    kind,
    parent,
    year,
    season,
    episode,
  ]);

  void observeMedia(String fileSource, String media) => db.execute(
    'INSERT OR IGNORE INTO media_evidence VALUES (?,?)',
    [fileSource, media],
  );

  void observeMembership(String media, int timestamp) => db.execute(
    'INSERT OR IGNORE INTO memberships SELECT ?,? WHERE NOT EXISTS (SELECT 1 FROM ignored WHERE media_id=?)',
    [media, timestamp, media],
  );

  /// Like [query], children whose files are all hidden dot files are skipped.
  ResultSet children(String media, int limit, int offset) => db.select(
    '''WITH children AS (
      SELECT s.media_id FROM source_media p JOIN source_media s ON s.source=p.source AND s.parent_key=p.source_key WHERE p.media_id=?
      UNION SELECT child_id FROM metadata_relations WHERE parent_id=?)
      SELECT m.*,COALESCE(json_extract(mp.fields,'\$.kind'),sm.kind) AS kind,
      COALESCE(json_extract(mp.fields,'\$.season'),sm.season) AS season,
      COALESCE(json_extract(mp.fields,'\$.episode'),sm.episode) AS episode
      FROM children c JOIN media m ON m.id=c.media_id
      LEFT JOIN metadata_projection mp ON mp.media_id=m.id
      LEFT JOIN source_media sm ON sm.media_id=m.id
      WHERE NOT (EXISTS (SELECT 1 FROM resources r WHERE r.media_id=m.id)
        AND NOT EXISTS (SELECT 1 FROM resources r WHERE r.media_id=m.id AND substr(r.name,1,1)<>'.'))
      AND $_visibleContainer
      GROUP BY m.id ORDER BY season,episode,m.id LIMIT ? OFFSET ?''',
    [media, media, limit, offset],
  );

  ResultSet mediaForLocator(String source, String item) => db.select(
    'SELECT r.media_id FROM resource_locators l JOIN resources r ON r.id=l.resource_id WHERE l.source=? AND l.item=?',
    [source, item],
  );

  ResultSet localResource(String path) => db.select(
    'SELECT r.* FROM local_identity l JOIN resources r ON r.id=l.resource_id WHERE l.path=?',
    [path],
  );

  void ensureLocator(String source, String item, String resource) => db.execute(
    'INSERT OR IGNORE INTO resource_locators VALUES (?,?,?)',
    [source, item, resource],
  );

  void insertResource(
    String id,
    String media,
    String source,
    String item,
    String name,
  ) => db.execute('INSERT INTO resources VALUES (?,?,?,?,?)', [
    id,
    media,
    source,
    item,
    name,
  ]);

  void insertLocator(String source, String item, String resource) => db.execute(
    'INSERT INTO resource_locators VALUES (?,?,?)',
    [source, item, resource],
  );

  void insertLocalIdentity(String path, String resource) =>
      db.execute('INSERT INTO local_identity VALUES (?,?)', [path, resource]);

  /// Hidden dot files (macOS `._movie.mkv` sidecars kept from scans before
  /// they were filtered) are never offered for playback.
  ResultSet resources(String media) => db.select(
    "SELECT r.id,r.media_id,l.source,l.item,r.name FROM resources r JOIN resource_locators l ON l.resource_id=r.id WHERE r.media_id=? AND substr(r.name,1,1)<>'.' ORDER BY r.id,l.source,l.item",
    [media],
  );

  void setFavorite(int favorite, String media) =>
      db.execute('UPDATE media SET favorite=? WHERE id=?', [favorite, media]);

  bool isFavorite(String media) =>
      db.select('SELECT favorite FROM media WHERE id=?', [
        media,
      ]).firstOrNull?['favorite'] ==
      1;

  /// Media whose projected metadata names the same collection, oldest first.
  ResultSet collectionMembers(String collection) => db.select(
    '''SELECT m.* FROM metadata_projection mp JOIN media m ON m.id=mp.media_id
    WHERE json_extract(mp.fields,'\$.collection.id')=?
    AND EXISTS (SELECT 1 FROM memberships ms WHERE ms.media_id=m.id)
    ORDER BY COALESCE(json_extract(mp.fields,'\$.airDate'),json_extract(mp.fields,'\$.year')),m.id''',
    [collection],
  );

  /// Clears a finished mark; the progress row stays for recently played.
  void resetProgress(String resource) => db.execute(
    'UPDATE progress SET position=0,completed=0 WHERE resource_id=?',
    [resource],
  );

  void ignoreMedia(String media) =>
      db.execute('INSERT OR IGNORE INTO ignored VALUES (?)', [media]);

  void removeManualMembership(String media) =>
      db.execute('DELETE FROM manual_memberships WHERE media_id=?', [media]);

  void removeMembership(String media) =>
      db.execute('DELETE FROM memberships WHERE media_id=?', [media]);

  void clearAllIgnored() => db.execute('DELETE FROM ignored');

  void markScanRunning(String fileSource) =>
      _setScanState(fileSource, '扫描中', null);

  ResultSet scanTask(String fileSource) => db.select(
    'SELECT * FROM scan_tasks WHERE file_source_id=?',
    [fileSource],
  );

  void insertScanTask(String fileSource, String batch, int revision) =>
      db.execute('INSERT INTO scan_tasks VALUES (?,?,?)', [
        fileSource,
        batch,
        revision,
      ]);

  void insertScanRoot(String fileSource, String root) => db.execute(
    'INSERT INTO scan_queue(file_source_id,node) VALUES (?,?)',
    [fileSource, root],
  );

  ResultSet nextScanNode(String fileSource) => db.select(
    'SELECT * FROM scan_queue WHERE file_source_id=? AND done=0 ORDER BY node LIMIT 1',
    [fileSource],
  );

  void enqueueScanNode(String fileSource, String node) => db.execute(
    'INSERT OR IGNORE INTO scan_queue(file_source_id,node) VALUES (?,?)',
    [fileSource, node],
  );

  void observeResource(String fileSource, String resource, String batch) =>
      db.execute(
        'INSERT INTO evidence VALUES (?,?,?,1) ON CONFLICT(file_source_id,resource_id) DO UPDATE SET seen=excluded.seen,available=1',
        [fileSource, resource, batch],
      );

  void advanceScanNode(
    int offset,
    int done,
    String fileSource,
    String node,
  ) => db.execute(
    'UPDATE scan_queue SET offset=?,done=? WHERE file_source_id=? AND node=?',
    [offset, done, fileSource, node],
  );

  void markUnseenResourcesMissing(String fileSource, String batch) =>
      db.execute(
        'UPDATE evidence SET available=0 WHERE file_source_id=? AND seen<>?',
        [fileSource, batch],
      );

  void removeScanTask(String fileSource) =>
      db.execute('DELETE FROM scan_tasks WHERE file_source_id=?', [fileSource]);

  void markScanComplete(String fileSource) =>
      _setScanState(fileSource, '扫描完成', null);

  void markScanFailed(String error, String fileSource) =>
      _setScanState(fileSource, '扫描失败', error);

  ResultSet scannedMediaCount(String fileSource) => db.select(
    'SELECT COUNT(*) AS n FROM evidence e JOIN scan_tasks t ON t.file_source_id=e.file_source_id AND t.batch=e.seen WHERE e.file_source_id=?',
    [fileSource],
  );

  void unignoreMedia(String media) =>
      db.execute('DELETE FROM ignored WHERE media_id=?', [media]);

  void addManualMembership(String media) => db.execute(
    'INSERT OR IGNORE INTO manual_memberships VALUES (?)',
    [media],
  );

  void addMembership(String media, int timestamp) => db.execute(
    'INSERT OR IGNORE INTO memberships VALUES (?,?)',
    [media, timestamp],
  );

  ResultSet resourceFor(String source, String item) => db.select(
    'SELECT r.id,r.media_id,l.source,l.item,r.name FROM resources r JOIN resource_locators l ON l.resource_id=r.id WHERE l.source=? AND l.item=?',
    [source, item],
  );

  ResultSet checkpoint(String resource) =>
      db.select('SELECT * FROM progress WHERE resource_id=?', [resource]);

  void beginSession(String resource, String session, int timestamp) =>
      db.execute(
        "INSERT INTO progress(resource_id,session,updated_at) VALUES (?,?,?) ON CONFLICT(resource_id) DO UPDATE SET session=excluded.session,updated_at=excluded.updated_at",
        [resource, session, timestamp],
      );

  void saveProgress(
    int position,
    int duration,
    int timestamp,
    int completed,
    String resource,
    String session,
  ) => db.execute(
    'UPDATE progress SET position=?,duration=?,updated_at=?,completed=? WHERE resource_id=? AND session=?',
    [position, duration, timestamp, completed, resource, session],
  );

  ResultSet continueWatching(int limit) => db.select(
    """WITH ranked AS (SELECT m.*,r.id AS resource_id,p.position,p.duration,p.completed,p.updated_at,
    ROW_NUMBER() OVER(PARTITION BY m.id ORDER BY p.updated_at DESC,r.id) AS rank
    FROM progress p JOIN resources r ON r.id=p.resource_id JOIN media m ON m.id=r.media_id)
    SELECT * FROM ranked WHERE rank=1 AND position>0 AND completed=0 ORDER BY updated_at DESC,id LIMIT ?""",
    [limit],
  );

  ResultSet recentlyPlayed(int limit) => db.select(
    """WITH ranked AS (SELECT m.*,r.id AS resource_id,p.position,p.duration,p.completed,p.updated_at,
    ROW_NUMBER() OVER(PARTITION BY m.id ORDER BY p.updated_at DESC,r.id) AS rank
    FROM progress p JOIN resources r ON r.id=p.resource_id JOIN media m ON m.id=r.media_id)
    SELECT * FROM ranked WHERE rank=1 ORDER BY updated_at DESC,id LIMIT ?""",
    [limit],
  );

  ResultSet resourceObservations(String resource) => db.select(
    'SELECT available FROM evidence WHERE resource_id=?',
    [resource],
  );

  ResultSet fileSourceImpact(String fileSource) => db.select(
    'SELECT COUNT(DISTINCT media_id) AS n FROM media_evidence WHERE file_source_id=?',
    [fileSource],
  );

  ResultSet fileSourceMedia(String fileSource) => db.select(
    'SELECT media_id FROM media_evidence WHERE file_source_id=?',
    [fileSource],
  );

  /// Drops [media] from the poster wall unless it was added by hand or
  /// another file source still found it.
  void pruneUnobservedMembership(String media) => db.execute(
    'DELETE FROM memberships WHERE media_id=? '
    'AND NOT EXISTS (SELECT 1 FROM manual_memberships WHERE media_id=?) '
    'AND NOT EXISTS (SELECT 1 FROM media_evidence WHERE media_id=?)',
    [media, media, media],
  );
}
