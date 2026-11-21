import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../configuration/configuration_database.dart';
import '../metadata/metadata_repository.dart';
import '../metadata/metadata_queue.dart';
import 'library_database.dart';
import 'scan_status.dart';

/// Library persistence. No source connections, widgets or scan traversal live here.
/// Multi-step business operations use [transaction] to commit atomically.

/// Whether media [x] may be shown: the one rule for the poster wall, episode
/// lists and continue watching. Media with files must have
/// - a file that is not hidden: dot files such as macOS `._movie.mp4`
///   sidecars are dropped by scans, but older scans kept some; and
/// - evidence in an enabled file source: every scan records evidence, so
///   files without it were only played by browsing a source or are left over
///   from a deleted file source.
/// Media without files (metadata series and seasons) pass here and are judged
/// by their episodes in [_visibleContainer]. Needs the `enabled_sources(id)`
/// CTE ([_enabledSourcesCte]).
String _visibleMedia(String x) =>
    """(NOT EXISTS (SELECT 1 FROM resources r WHERE r.media_id=$x)
        OR EXISTS (SELECT 1 FROM resources r JOIN evidence e ON e.resource_id=r.id
          WHERE r.media_id=$x AND substr(r.name,1,1)<>'.' AND e.available=1
          AND e.file_source_id IN (SELECT id FROM enabled_sources)))""";

/// Browsed files have no scan evidence and can still be played directly.
/// A scanned file is unavailable only when every observation confirms absence.
String _availableResource(String x) =>
    '(NOT EXISTS (SELECT 1 FROM evidence e WHERE e.resource_id=$x) '
    'OR EXISTS (SELECT 1 FROM evidence e WHERE e.resource_id=$x AND e.available=1))';

/// Binds the JSON list of enabled file source ids.
const _enabledSourcesCte =
    'enabled_sources(id) AS (SELECT value FROM json_each(?))';

/// The version group of media [x]: media identified as the same movie or the
/// same episode are versions of one title, shown once; any other media is a
/// group of its own. Follows identification, so correcting a match regroups.
String _versionGroup(String x) =>
    """COALESCE((SELECT json_extract(ms.association,'\$.provider')||':'||json_extract(ms.association,'\$.kind')||':'||json_extract(ms.association,'\$.id')
      FROM metadata_state ms WHERE ms.media_id=$x AND json_extract(ms.association,'\$.kind') IN ('movie','episode')),$x)""";

/// SQL condition for media `m`: false for metadata containers (series,
/// seasons) whose descendants have files but none of them passes
/// [_visibleMedia]. Containers have no files or evidence of their own, so
/// disabled or deleted file sources hide their series this way, and a series
/// that metadata grouping built only from hidden sidecars does not show up
/// as a duplicate of the real one.
final _visibleContainer =
    """NOT (EXISTS (SELECT 1 FROM metadata_relations c1 WHERE c1.parent_id=m.id)
        AND NOT EXISTS (SELECT 1 FROM resources r WHERE r.media_id=m.id AND substr(r.name,1,1)<>'.')
        AND NOT EXISTS (SELECT 1 FROM metadata_relations c1 JOIN resources r ON r.media_id=c1.child_id WHERE c1.parent_id=m.id AND ${_visibleMedia('c1.child_id')})
        AND NOT EXISTS (SELECT 1 FROM metadata_relations c1 JOIN metadata_relations c2 ON c2.parent_id=c1.child_id JOIN resources r ON r.media_id=c2.child_id WHERE c1.parent_id=m.id AND ${_visibleMedia('c2.child_id')})
        AND (EXISTS (SELECT 1 FROM metadata_relations c1 JOIN resources r ON r.media_id=c1.child_id WHERE c1.parent_id=m.id)
          OR EXISTS (SELECT 1 FROM metadata_relations c1 JOIN metadata_relations c2 ON c2.parent_id=c1.child_id JOIN resources r ON r.media_id=c2.child_id WHERE c1.parent_id=m.id)))""";

/// SQL condition for the media bound five times as `?`: a series or season
/// left with no children, files, evidence or server items.
const _emptyContainer =
    '''NOT EXISTS (SELECT 1 FROM metadata_relations WHERE parent_id=?)
  AND NOT EXISTS (SELECT 1 FROM resources WHERE media_id=?)
  AND NOT EXISTS (SELECT 1 FROM media_evidence WHERE media_id=?)
  AND NOT EXISTS (SELECT 1 FROM source_media WHERE media_id=?)
  AND EXISTS (SELECT 1 FROM media WHERE id=?)''';

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
    String? source,
    String? contentType,
    int? year,
    bool? watched,
    int offset = 0,
    int limit = 40,
  }) {
    return db.select(
      '''WITH $_enabledSourcesCte, visible AS (
      SELECT m.*, lm.added_at, ${_versionGroup('m.id')} AS version_group
      FROM media m JOIN memberships lm ON lm.media_id=m.id
      WHERE instr(lower(m.title),lower(?))>0
      AND ${_visibleMedia('m.id')}
      AND $_visibleContainer
      AND (?<>'' OR ? IS NOT NULL OR ? IS NOT NULL OR NOT EXISTS (SELECT 1 FROM source_media child JOIN source_media parent ON child.source=parent.source AND child.parent_key=parent.source_key JOIN memberships pm ON pm.media_id=parent.media_id WHERE child.media_id=m.id))
      AND (?<>'' OR ? IS NOT NULL OR ? IS NOT NULL OR NOT EXISTS (SELECT 1 FROM metadata_relations mr JOIN memberships pm ON pm.media_id=mr.parent_id WHERE mr.child_id=m.id))
      AND (? IS NULL OR EXISTS (SELECT 1 FROM source_media sm WHERE sm.media_id=m.id AND sm.source=?) OR EXISTS (SELECT 1 FROM resources r JOIN resource_locators l ON l.resource_id=r.id WHERE r.media_id=m.id AND l.source=?))
      AND (? IS NULL OR COALESCE((SELECT json_extract(mp.fields,'\$.kind') FROM metadata_projection mp WHERE mp.media_id=m.id),(SELECT sm.kind FROM source_media sm WHERE sm.media_id=m.id LIMIT 1),'video')=?)
      AND (? IS NULL OR COALESCE((SELECT json_extract(mp.fields,'\$.year') FROM metadata_projection mp WHERE mp.media_id=m.id),(SELECT sm.year FROM source_media sm WHERE sm.media_id=m.id LIMIT 1))=?)
      AND (? IS NULL OR EXISTS (SELECT 1 FROM progress p JOIN resources r ON r.id=p.resource_id WHERE r.media_id=m.id AND p.completed=1)=?)),
      -- One card per version group: its first added media stands for it.
      grouped AS (SELECT *, ROW_NUMBER() OVER(PARTITION BY version_group ORDER BY added_at,id) AS version_rank FROM visible)
      SELECT *, COUNT(*) OVER() AS total FROM grouped WHERE version_rank=1
      ORDER BY added_at DESC,id LIMIT ? OFFSET ?''',
      [
        jsonEncode(enabledFileSourceIds()),
        search,
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
    'status': state?['status'] ?? ScanStatus.pending,
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

  /// File sources that are enabled and whose connection is not disabled.
  List<String> enabledFileSourceIds() => [
    for (final r in configuration.select(
      'SELECT id FROM file_sources f WHERE enabled=1 '
      'AND NOT EXISTS (SELECT 1 FROM plugin_instance_configs c '
      'WHERE c.instance_id=f.source_id AND c.enabled_desired=0)',
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

  /// Everything file source [id] brought into the library, for removing it:
  /// its scan state and evidence; the files only it found, with their
  /// playback progress; and the media left without files, with their
  /// metadata, along with series and seasons left without episodes. Files and
  /// media another file source also found stay. Generated subtitles and
  /// processing outputs, which belong to the connection, stay too.
  /// Runs inside the caller's transaction.
  void deleteFileSourceData(String id) {
    db.execute(
      'CREATE TEMP TABLE IF NOT EXISTS removed_resources(id TEXT PRIMARY KEY)',
    );
    db.execute(
      'CREATE TEMP TABLE IF NOT EXISTS removed_media(id TEXT PRIMARY KEY)',
    );
    db.execute('DELETE FROM removed_resources');
    db.execute('DELETE FROM removed_media');
    try {
      db.execute(
        '''INSERT INTO removed_resources SELECT resource_id FROM evidence e
        WHERE file_source_id=? AND NOT EXISTS (SELECT 1 FROM evidence o
          WHERE o.resource_id=e.resource_id AND o.file_source_id<>?)''',
        [id, id],
      );
      // Candidates for removal; only those left without files are removed.
      db.execute(
        '''INSERT OR IGNORE INTO removed_media
        SELECT media_id FROM resources WHERE id IN (SELECT id FROM removed_resources)
        UNION SELECT media_id FROM media_evidence WHERE file_source_id=?''',
        [id],
      );
      for (final table in [
        'scan_queue',
        'scan_tasks',
        'evidence',
        'media_evidence',
        'file_source_state',
      ]) {
        db.execute('DELETE FROM $table WHERE file_source_id=?', [id]);
      }
      for (final table in [
        'progress',
        'subtitle_choices',
        'local_identity',
        'resource_locators',
        'evidence',
      ]) {
        db.execute(
          'DELETE FROM $table WHERE resource_id IN (SELECT id FROM removed_resources)',
        );
      }
      db.execute(
        'DELETE FROM resources WHERE id IN (SELECT id FROM removed_resources)',
      );
      _deleteMediaWithoutFiles();
    } finally {
      db.execute('DROP TABLE removed_resources');
      db.execute('DROP TABLE removed_media');
    }
  }

  /// Deletes the media in `removed_media` that have no files and no other
  /// file source's evidence left, then their series and seasons that are left
  /// without children, files or server items.
  void _deleteMediaWithoutFiles() {
    const empty = '''NOT EXISTS (SELECT 1 FROM resources r WHERE r.media_id=removed_media.id)
      AND NOT EXISTS (SELECT 1 FROM media_evidence e WHERE e.media_id=removed_media.id)''';
    db.execute('DELETE FROM removed_media WHERE NOT ($empty)');
    // Episodes, then seasons, then series.
    for (var level = 0; level < 3; level++) {
      final ids = [
        for (final r in db.select('SELECT id FROM removed_media'))
          r['id'] as String,
      ];
      if (ids.isEmpty) return;
      final parents = [
        for (final r in db.select(
          'SELECT DISTINCT parent_id FROM metadata_relations '
          'WHERE child_id IN (SELECT id FROM removed_media)',
        ))
          r['parent_id'] as String,
      ];
      db.execute(
        'DELETE FROM metadata_relations WHERE child_id IN (SELECT id FROM removed_media) '
        'OR parent_id IN (SELECT id FROM removed_media)',
      );
      for (final table in const [
        'memberships',
        'ignored',
        'media_evidence',
        'source_media',
        'metadata_containers',
        'metadata_queue',
        'metadata_observations',
        'metadata_overrides',
        'metadata_projection',
        'metadata_jobs',
        'metadata_history',
        'artwork_selections',
        'metadata_state',
      ]) {
        db.execute(
          'DELETE FROM $table WHERE media_id IN (SELECT id FROM removed_media)',
        );
      }
      db.execute(
        'DELETE FROM media WHERE id IN (SELECT id FROM removed_media)',
      );
      db.execute('DELETE FROM removed_media');
      for (final parent in parents) {
        db.execute(
          '''INSERT OR IGNORE INTO removed_media SELECT ? WHERE $_emptyContainer''',
          [parent, ...List.filled(5, parent)],
        );
      }
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

  /// Children shown by the same rules as [query].
  ResultSet children(String media, int limit, int offset) => db.select(
    '''WITH $_enabledSourcesCte, children AS (
      SELECT s.media_id FROM source_media p JOIN source_media s ON s.source=p.source AND s.parent_key=p.source_key WHERE p.media_id=?
      UNION SELECT child_id FROM metadata_relations WHERE parent_id=?),
      visible AS (SELECT m.*,${_versionGroup('m.id')} AS version_group,
      COALESCE(json_extract(mp.fields,'\$.kind'),sm.kind) AS kind,
      COALESCE(json_extract(mp.fields,'\$.season'),sm.season) AS season,
      COALESCE(json_extract(mp.fields,'\$.episode'),sm.episode) AS episode
      FROM children c JOIN media m ON m.id=c.media_id
      LEFT JOIN metadata_projection mp ON mp.media_id=m.id
      LEFT JOIN source_media sm ON sm.media_id=m.id
      WHERE ${_visibleMedia('m.id')}
      AND $_visibleContainer
      GROUP BY m.id),
      -- One row per version group (an episode with several files).
      grouped AS (SELECT *, ROW_NUMBER() OVER(PARTITION BY version_group ORDER BY id) AS version_rank FROM visible)
      SELECT * FROM grouped WHERE version_rank=1
      ORDER BY season,episode,id LIMIT ? OFFSET ?''',
    [jsonEncode(enabledFileSourceIds()), media, media, limit, offset],
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
  ) => db.execute(
    'INSERT INTO resources(id,media_id,source,item,name) VALUES (?,?,?,?,?)',
    [id, media, source, item, name],
  );

  /// Records the size the source listed for the file at [source]/[item].
  void setResourceSize(String source, String item, int size) => db.execute(
    'UPDATE resources SET size=? WHERE id IN '
    '(SELECT resource_id FROM resource_locators WHERE source=? AND item=?)',
    [size, source, item],
  );

  void insertLocator(String source, String item, String resource) => db.execute(
    'INSERT INTO resource_locators VALUES (?,?,?)',
    [source, item, resource],
  );

  void insertLocalIdentity(String path, String resource) =>
      db.execute('INSERT INTO local_identity VALUES (?,?)', [path, resource]);

  /// Hidden dot files (macOS `._movie.mkv` sidecars kept from scans before
  /// they were filtered) are never offered for playback.
  ResultSet resources(String media) => db.select(
    "SELECT r.id,r.media_id,l.source,l.item,r.name,r.size FROM resources r JOIN resource_locators l ON l.resource_id=r.id WHERE r.media_id=? AND substr(r.name,1,1)<>'.' AND ${_availableResource('r.id')} ORDER BY r.id,l.source,l.item",
    [media],
  );

  /// The media in the version group of [media] (including it).
  List<String> versionGroup(String media) => [
    for (final r in db.select(
      'WITH g(k) AS (SELECT ${_versionGroup('?')}) '
      'SELECT ? AS id UNION SELECT ms.media_id FROM metadata_state ms, g '
      "WHERE json_extract(ms.association,'\$.kind') IN ('movie','episode') "
      "AND json_extract(ms.association,'\$.provider')||':'||json_extract(ms.association,'\$.kind')||':'||json_extract(ms.association,'\$.id')=g.k",
      [media, media, media],
    ))
      r['id'] as String,
  ];

  /// The files of every shown version of [media], largest first; files of
  /// unknown size last.
  ResultSet versions(String media) => db.select(
    '''WITH $_enabledSourcesCte
    SELECT r.id,r.media_id,l.source,l.item,r.name,r.size FROM resources r
    JOIN resource_locators l ON l.resource_id=r.id
    WHERE r.media_id IN (SELECT value FROM json_each(?))
      AND substr(r.name,1,1)<>'.' AND ${_visibleMedia('r.media_id')}
      AND EXISTS (SELECT 1 FROM evidence e WHERE e.resource_id=r.id
        AND e.available=1 AND e.file_source_id IN (SELECT id FROM enabled_sources))
    ORDER BY r.size IS NULL,r.size DESC,r.name,r.id,l.source,l.item''',
    [jsonEncode(enabledFileSourceIds()), jsonEncode(versionGroup(media))],
  );

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

  void removeMembership(String media) =>
      db.execute('DELETE FROM memberships WHERE media_id=?', [media]);

  void clearAllIgnored() => db.execute('DELETE FROM ignored');

  void markScanRunning(String fileSource) =>
      _setScanState(fileSource, ScanStatus.scanning, null);

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

  /// Reconciles only a successfully completed traversal, inside its transaction.
  /// Keep file identities and progress so returning files reuse them, but drop
  /// stale library associations unless another file source still observes them.
  void markUnseenResourcesMissing(String fileSource, String batch) {
    db.execute(
      'UPDATE evidence SET available=0 WHERE file_source_id=? AND seen<>?',
      [fileSource, batch],
    );
    final affected = fileSourceMedia(fileSource);
    db.execute(
      '''DELETE FROM media_evidence WHERE file_source_id=?
      AND EXISTS (SELECT 1 FROM resources r WHERE r.media_id=media_evidence.media_id)
      AND NOT EXISTS (SELECT 1 FROM resources r JOIN evidence e ON e.resource_id=r.id
        WHERE r.media_id=media_evidence.media_id AND e.file_source_id=? AND e.available=1)''',
      [fileSource, fileSource],
    );
    for (final row in affected) {
      pruneUnobservedMembership(row['media_id'] as String);
    }
  }

  void removeScanTask(String fileSource) =>
      db.execute('DELETE FROM scan_tasks WHERE file_source_id=?', [fileSource]);

  void markScanComplete(String fileSource) =>
      _setScanState(fileSource, ScanStatus.done, null);

  void markScanFailed(String error, String fileSource) =>
      _setScanState(fileSource, ScanStatus.failed, error);

  ResultSet scannedMediaCount(String fileSource) => db.select(
    'SELECT COUNT(*) AS n FROM evidence e JOIN scan_tasks t ON t.file_source_id=e.file_source_id AND t.batch=e.seen WHERE e.file_source_id=?',
    [fileSource],
  );

  int fileSourceMediaCount(String fileSource) =>
      db.select(
            'SELECT COUNT(DISTINCT r.media_id) AS n FROM evidence e '
            'JOIN resources r ON r.id=e.resource_id '
            'WHERE e.file_source_id=? AND e.available=1',
            [fileSource],
          ).first['n']
          as int;

  ResultSet resourceFor(String source, String item) => db.select(
    'SELECT r.id,r.media_id,l.source,l.item,r.name FROM resources r JOIN resource_locators l ON l.resource_id=r.id WHERE l.source=? AND l.item=?',
    [source, item],
  );

  ResultSet checkpoint(String resource) =>
      db.select('SELECT * FROM progress WHERE resource_id=?', [resource]);

  ResultSet subtitleChoice(String resource) => db.select(
    'SELECT choice FROM subtitle_choices WHERE resource_id=?',
    [resource],
  );

  void saveSubtitleChoice(String resource, String choice, int timestamp) =>
      db.execute(
        'INSERT INTO subtitle_choices(resource_id,choice,updated_at) VALUES (?,?,?) ON CONFLICT(resource_id) DO UPDATE SET choice=excluded.choice,updated_at=excluded.updated_at',
        [resource, choice, timestamp],
      );

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
    """WITH $_enabledSourcesCte, ranked AS (SELECT m.*,r.id AS resource_id,p.position,p.duration,p.completed,p.updated_at,
    -- One entry per version group: the version played last.
    ROW_NUMBER() OVER(PARTITION BY ${_versionGroup('m.id')} ORDER BY p.updated_at DESC,r.id) AS rank
    FROM progress p JOIN resources r ON r.id=p.resource_id JOIN media m ON m.id=r.media_id
    WHERE ${_visibleMedia('m.id')} AND ${_availableResource('r.id')})
    SELECT * FROM ranked WHERE rank=1 AND position>0 AND completed=0 ORDER BY updated_at DESC,id LIMIT ?""",
    [jsonEncode(enabledFileSourceIds()), limit],
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

  /// Drops [media] from the poster wall unless another file source still
  /// found it.
  void pruneUnobservedMembership(String media) => db.execute(
    'DELETE FROM memberships WHERE media_id=? '
    'AND NOT EXISTS (SELECT 1 FROM media_evidence WHERE media_id=?)',
    [media, media],
  );
}
