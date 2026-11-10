import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/plugins/source_capability.dart';
import '../../core/plugins/metadata_capability.dart';
import '../../data/metadata/metadata_repository.dart';
import '../../data/metadata/metadata_queue.dart';
import '../../data/sources/source_manager.dart';
import '../../data/sources/source_config.dart';

/// Local business data. Source credentials and resolved playback URLs never enter
/// this database. Media identity survives membership and binding removal.
class LibraryService {
  LibraryService(
    this.db, {
    bool recoverInterrupted = true,
    bool watchExternalChanges = false,
  }) {
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
    metadata = MetadataRepository(db, onChanged: notifyChanged);
    transaction(() {
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
    _dataVersion = db.select('PRAGMA data_version').single.values.single as int;
    if (watchExternalChanges) {
      _externalWatch = Timer.periodic(
        const Duration(seconds: 2),
        (_) => checkExternalChanges(),
      );
    }
  }
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  Timer? _externalWatch;
  int _dataVersion = 0;
  bool _inTransaction = false;
  bool _databaseClosed = false;
  void notifyChanged() {
    if (_closeRequested || _changes.isClosed) return;
    if (_inTransaction) return;
    // Leading + trailing throttle while background metadata work runs; it emits several
    // changes per item and every listener rebuilds with synchronous queries.
    if (_notifyTimer != null) {
      _notifyPending = true;
      return;
    }
    _changes.add(null);
    if (_running.isEmpty) return;
    _notifyTimer = Timer(const Duration(milliseconds: 300), () {
      _notifyTimer = null;
      if (_notifyPending) {
        _notifyPending = false;
        notifyChanged();
      }
    });
  }

  Timer? _notifyTimer;

  /// Metadata scraping progress (done/total) for the library page header.
  ({int done, int total}) metadataProgress() => MetadataQueue(db).progress;
  final _priorityRequests = StreamController<void>.broadcast();

  /// Fires when a visible item was moved to the front of the metadata queue.
  Stream<void> get priorityRequests => _priorityRequests.stream;

  /// Raises metadata priority for items the user is looking at (recent list,
  /// detail page, visible library entries). Already-processed items are no-ops.
  void prioritizeMetadata(Iterable<String> mediaIds) {
    if (_closeRequested || _databaseClosed) return;
    final ids = mediaIds.toSet().toList();
    if (ids.isEmpty) return;
    if (MetadataQueue(db).boost(ids) > 0 && !_priorityRequests.isClosed) {
      _priorityRequests.add(null);
    }
  }

  bool _notifyPending = false;

  void checkExternalChanges() {
    if (_closeRequested) return;
    final version =
        db.select('PRAGMA data_version').single.values.single as int;
    if (version != _dataVersion) {
      _dataVersion = version;
      notifyChanged();
    }
  }

  void _closeDatabase() {
    if (_databaseClosed) return;
    _databaseClosed = true;
    _externalWatch?.cancel();
    _notifyTimer?.cancel();
    _priorityRequests.close();
    _changes.close();
    db.close();
  }

  final Database db;
  late final MetadataRepository metadata;
  bool get isClosing => _closeRequested;
  void beginMetadataWork(String id) {
    if (_closeRequested) throw StateError("媒体库正在关闭");
    _running.add("metadata:$id");
  }

  void endMetadataWork(String id) {
    _running.remove("metadata:$id");
    if (_closeRequested && _running.isEmpty) _closeDatabase();
  }

  final Set<String> _running = {};
  bool _closeRequested = false;
  static String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  static Future<LibraryService> open({
    bool recoverInterrupted = true,
    bool watchExternalChanges = true,
    String databaseName = 'library.sqlite3',
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+\.sqlite3$').hasMatch(databaseName)) {
      throw ArgumentError('Invalid library database name');
    }
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final db = sqlite3.open(
      '${dir.path}${Platform.pathSeparator}$databaseName',
    );
    try {
      return LibraryService(
        db,
        recoverInterrupted: recoverInterrupted,
        watchExternalChanges: watchExternalChanges,
      );
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  T transaction<T>(T Function() action) {
    db.execute('BEGIN IMMEDIATE');
    _inTransaction = true;
    try {
      final result = action();
      db.execute('COMMIT');
      _inTransaction = false;
      notifyChanged();
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      _inTransaction = false;
      rethrow;
    }
  }

  List<Row> get libraries =>
      db.select('SELECT * FROM libraries ORDER BY name,id');
  String create(String name, {String type = 'mixed'}) {
    if (name.trim().isEmpty) throw ArgumentError('请输入库名称');
    final id = _id();
    db.execute('INSERT INTO libraries VALUES (?,?,?)', [id, name.trim(), type]);
    return id;
  }

  void renameLibrary(String library, String name) {
    if (name.trim().isEmpty) throw ArgumentError('请输入库名称');
    db.execute('UPDATE libraries SET name=? WHERE id=?', [
      name.trim(),
      library,
    ]);
  }

  void delete(String library) {
    db.execute('DELETE FROM libraries WHERE id=?', [library]);
    notifyChanged();
  }

  /// The single implicit library behind the "all file sources" poster wall.
  /// Created lazily so an unused database stays empty.
  static const defaultLibraryId = 'default';
  String defaultLibrary() {
    db.execute('INSERT OR IGNORE INTO libraries VALUES (?,?,?)', [
      defaultLibraryId,
      '媒体库',
      'mixed',
    ]);
    return defaultLibraryId;
  }

  List<Row> bindings(String library) => db.select(
    'SELECT * FROM bindings WHERE library_id=? ORDER BY id',
    [library],
  );

  /// File sources: every binding, regardless of the library it belongs to.
  List<Row> fileSources() => db.select('SELECT * FROM bindings ORDER BY id');

  void setBindingEnabled(String binding, bool enabled) {
    db.execute('UPDATE bindings SET enabled=? WHERE id=?', [
      enabled ? 1 : 0,
      binding,
    ]);
    notifyChanged();
  }

  void renameBinding(String binding, String name) {
    if (name.trim().isEmpty) throw ArgumentError('请输入名称');
    db.execute('UPDATE bindings SET name=? WHERE id=?', [name.trim(), binding]);
    notifyChanged();
  }

  String bind(
    String library,
    String source, {
    String? root,
    String? name,
    SourceEntry? rootEntry,
  }) {
    final id = _id();
    db.execute(
      'INSERT INTO bindings(id,library_id,source,root,name) VALUES (?,?,?,?,?)',
      [id, library, source, root, name?.trim().isEmpty == true ? null : name],
    );
    if (rootEntry?.media != null) {
      final media = register(rootEntry!);
      transaction(() => _observe(id, library, media));
    }
    return id;
  }

  String _content(SourceEntry entry) {
    final info = entry.media;
    if (info != null) {
      final known = db.select(
        'SELECT media_id FROM source_media WHERE source=? AND source_key=?',
        [entry.ref.instanceId, info.id],
      ).firstOrNull;
      if (known != null) {
        final media = known['media_id'] as String;
        _serverMetadata(media, entry);
        return media;
      }
    }
    if (info != null && info.parentId != null) {
      final visited = <String>{info.id};
      String? parent = info.parentId;
      while (parent != null) {
        if (!visited.add(parent)) {
          throw const PluginException('invalidInput', '来源返回了循环季集关系');
        }
        parent =
            db.select(
                  'SELECT parent_key FROM source_media WHERE source=? AND source_key=?',
                  [entry.ref.instanceId, parent],
                ).firstOrNull?['parent_key']
                as String?;
      }
    }
    final media = _id();
    db.execute('INSERT INTO media(id,title) VALUES (?,?)', [
      media,
      info?.title ?? entry.name,
    ]);
    if (info != null) {
      db.execute('INSERT INTO source_media VALUES (?,?,?,?,?,?,?,?)', [
        entry.ref.instanceId,
        info.id,
        media,
        info.kind,
        info.parentId,
        info.year,
        info.season,
        info.episode,
      ]);
    }
    _serverMetadata(media, entry);
    return media;
  }

  void _serverMetadata(String media, SourceEntry entry) {
    final info = entry.media;
    if (info == null) return;
    final kind = MediaKind.values.where((k) => k.name == info.kind).firstOrNull;
    if (kind == null) return;
    final record = metadataFromSource(info, entry.ref.instanceId);
    final selected = metadata.association(media);
    if (selected != null && !metadata.compatible(record, selected)) return;
    metadata.apply(
      media,
      record,
      sourceKey: 'server:${entry.ref.instanceId}',
      authority: 300,
      expectedRevision: metadata.revision(media),
      operationId: _id(),
      select: selected == null,
    );
  }

  void _observe(String binding, String library, String media) {
    db.execute('INSERT OR IGNORE INTO media_evidence VALUES (?,?)', [
      binding,
      media,
    ]);
    db.execute(
      'INSERT OR IGNORE INTO memberships SELECT ?,?,? WHERE NOT EXISTS (SELECT 1 FROM ignored WHERE library_id=? AND media_id=?)',
      [library, media, DateTime.now().millisecondsSinceEpoch, library, media],
    );
    MetadataQueue.observe(db, media, refresh: true);
  }

  List<Row> children(
    String media, {
    String? library,
    int offset = 0,
    int limit = 40,
  }) => db.select(
    '''WITH children AS (
      SELECT s.media_id FROM source_media p JOIN source_media s ON s.source=p.source AND s.parent_key=p.source_key WHERE p.media_id=?
      UNION SELECT child_id FROM metadata_relations WHERE parent_id=?)
      SELECT m.*,COALESCE(json_extract(mp.fields,'\$.kind'),sm.kind) AS kind,
      COALESCE(json_extract(mp.fields,'\$.season'),sm.season) AS season,
      COALESCE(json_extract(mp.fields,'\$.episode'),sm.episode) AS episode
      FROM children c JOIN media m ON m.id=c.media_id
      LEFT JOIN metadata_projection mp ON mp.media_id=m.id
      LEFT JOIN source_media sm ON sm.media_id=m.id
      WHERE (? IS NULL OR EXISTS (SELECT 1 FROM memberships lm WHERE lm.media_id=m.id AND lm.library_id=?))
      GROUP BY m.id ORDER BY season,episode,m.id LIMIT ? OFFSET ?''',
    [media, media, library, library, limit, offset],
  );
  String register(SourceEntry entry, {String? localPath}) => transaction(() {
    final existing = db.select(
      'SELECT r.media_id FROM resource_locators l JOIN resources r ON r.id=l.resource_id WHERE l.source=? AND l.item=?',
      [entry.ref.instanceId, entry.ref.id],
    );
    if (existing.isNotEmpty) {
      final media = existing.first['media_id'] as String;
      _serverMetadata(media, entry);
      return media;
    }
    if (localPath != null) {
      final local = db.select(
        'SELECT r.* FROM local_identity l JOIN resources r ON r.id=l.resource_id WHERE l.path=?',
        [localPath],
      );
      if (local.isNotEmpty) {
        db.execute('INSERT OR IGNORE INTO resource_locators VALUES (?,?,?)', [
          entry.ref.instanceId,
          entry.ref.id,
          local.first['id'],
        ]);
        return local.first['media_id'] as String;
      }
    }
    final media = _content(entry);
    if (entry.isFolder) return media;
    final resource = _id();
    db.execute('INSERT INTO resources VALUES (?,?,?,?,?)', [
      resource,
      media,
      entry.ref.instanceId,
      entry.ref.id,
      entry.name,
    ]);
    db.execute('INSERT INTO resource_locators VALUES (?,?,?)', [
      entry.ref.instanceId,
      entry.ref.id,
      resource,
    ]);
    if (localPath != null) {
      db.execute('INSERT INTO local_identity VALUES (?,?)', [
        localPath,
        resource,
      ]);
    }
    return media;
  });

  /// Media whose files are all hidden dot files (macOS `._movie.mp4` sidecars,
  /// kept from scans before those were filtered) never show in the library.
  List<Row> query(
    String? library, {
    String search = '',
    bool favorites = false,
    String? source,
    String? contentType,
    int? year,
    bool? watched,
    int offset = 0,
    int limit = 40,
  }) {
    if (offset < 0 || limit < 1 || limit > 200) throw ArgumentError('无效分页');
    return db.select(
      '''SELECT m.*, lm.added_at FROM media m JOIN (SELECT media_id, MAX(added_at) AS added_at FROM memberships WHERE (? IS NULL OR library_id=?) GROUP BY media_id) lm ON lm.media_id=m.id
      WHERE instr(lower(m.title),lower(?))>0 ${favorites ? 'AND m.favorite=1' : ''}
      AND NOT (EXISTS (SELECT 1 FROM media_evidence e WHERE e.media_id=m.id)
        AND NOT EXISTS (SELECT 1 FROM media_evidence e JOIN bindings b ON b.id=e.binding_id WHERE e.media_id=m.id AND b.enabled=1)
        AND NOT EXISTS (SELECT 1 FROM manual_memberships mm WHERE mm.media_id=m.id))
      AND NOT (EXISTS (SELECT 1 FROM resources r WHERE r.media_id=m.id)
        AND NOT EXISTS (SELECT 1 FROM resources r WHERE r.media_id=m.id AND substr(r.name,1,1)<>'.'))
      AND (?<>'' OR ${favorites ? '1' : '0'}=1 OR ? IS NOT NULL OR ? IS NOT NULL OR NOT EXISTS (SELECT 1 FROM source_media child JOIN source_media parent ON child.source=parent.source AND child.parent_key=parent.source_key JOIN memberships pm ON pm.media_id=parent.media_id AND (? IS NULL OR pm.library_id=?) WHERE child.media_id=m.id))
      AND (?<>'' OR ${favorites ? '1' : '0'}=1 OR ? IS NOT NULL OR ? IS NOT NULL OR NOT EXISTS (SELECT 1 FROM metadata_relations mr JOIN memberships pm ON pm.media_id=mr.parent_id WHERE mr.child_id=m.id AND (? IS NULL OR pm.library_id=?)))
      AND (? IS NULL OR EXISTS (SELECT 1 FROM source_media sm WHERE sm.media_id=m.id AND sm.source=?) OR EXISTS (SELECT 1 FROM resources r JOIN resource_locators l ON l.resource_id=r.id WHERE r.media_id=m.id AND l.source=?))
      AND (? IS NULL OR COALESCE((SELECT json_extract(mp.fields,'\$.kind') FROM metadata_projection mp WHERE mp.media_id=m.id),(SELECT sm.kind FROM source_media sm WHERE sm.media_id=m.id LIMIT 1),'video')=?)
      AND (? IS NULL OR COALESCE((SELECT json_extract(mp.fields,'\$.year') FROM metadata_projection mp WHERE mp.media_id=m.id),(SELECT sm.year FROM source_media sm WHERE sm.media_id=m.id LIMIT 1))=?)
      AND (? IS NULL OR EXISTS (SELECT 1 FROM progress p JOIN resources r ON r.id=p.resource_id WHERE r.media_id=m.id AND p.completed=1)=?)
      ORDER BY lm.added_at DESC,m.id LIMIT ? OFFSET ?''',
      [
        library,
        library,
        search,
        search,
        contentType,
        year,
        library,
        library,
        search,
        contentType,
        year,
        library,
        library,
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

  List<Row> resources(String media) => db.select(
    'SELECT r.id,r.media_id,l.source,l.item,r.name FROM resources r JOIN resource_locators l ON l.resource_id=r.id WHERE r.media_id=? ORDER BY r.id,l.source,l.item',
    [media],
  );
  void favorite(String media, bool value) => db.execute(
    'UPDATE media SET favorite=? WHERE id=?',
    [value ? 1 : 0, media],
  );
  void rename(String media, String title) {
    if (title.trim().isEmpty) throw ArgumentError('请输入标题');
    transaction(
      () => metadata.overrideField(
        media,
        'title',
        title.trim(),
        expectedRevision: metadata.revision(media),
      ),
    );
  }

  void remove(String library, String media) => transaction(() {
    db.execute('INSERT OR IGNORE INTO ignored VALUES (?,?)', [library, media]);
    db.execute(
      'DELETE FROM manual_memberships WHERE library_id=? AND media_id=?',
      [library, media],
    );
    db.execute('DELETE FROM memberships WHERE library_id=? AND media_id=?', [
      library,
      media,
    ]);
  });
  void clearIgnored(String library) =>
      db.execute('DELETE FROM ignored WHERE library_id=?', [library]);

  /// Hide a title from the whole poster wall: remove it from every library it
  /// belongs to. Files, media records and progress are untouched.
  void hide(String media) => transaction(() {
    db.execute(
      'INSERT OR IGNORE INTO ignored SELECT library_id,media_id FROM memberships WHERE media_id=?',
      [media],
    );
    db.execute('DELETE FROM manual_memberships WHERE media_id=?', [media]);
    db.execute('DELETE FROM memberships WHERE media_id=?', [media]);
  });
  void clearAllIgnored() =>
      transaction(() => db.execute('DELETE FROM ignored'));

  /// Browse explicitly selected scope, preserving source identities. Only a fully
  /// successful traversal marks old observations unavailable; failures retain data.
  Future<void> scan(String binding, SourceManager sources) async {
    if (!_running.add(binding)) throw StateError('扫描已在运行');
    var batch = _id();
    try {
      final b = db.select('SELECT * FROM bindings WHERE id=?', [binding]).first;
      if (b['enabled'] == 0) throw StateError('文件源已停用');
      await sources.load();
      final source = b['source'] as String;
      final config = sources.configs.firstWhere((c) => c.id == source);
      if (!config.enabled || config.scanMode == ScanMode.disabled) {
        throw StateError('来源未启用扫描');
      }
      var scanRoot = config.kind == SourceKind.local
          ? config.address
          : Uri.parse(config.address).path;
      if (config.kind == SourceKind.local) {
        try {
          scanRoot = await Directory(scanRoot).resolveSymbolicLinks();
        } catch (_) {}
      }
      final revision = config.revision;
      db.execute("UPDATE bindings SET status='扫描中',error=NULL WHERE id=?", [
        binding,
      ]);
      final prior = db.select('SELECT * FROM scan_tasks WHERE binding_id=?', [
        binding,
      ]).firstOrNull;
      if (prior != null && prior['revision'] == revision) {
        batch = prior['batch'] as String;
      } else {
        transaction(() {
          db.execute('DELETE FROM scan_tasks WHERE binding_id=?', [binding]);
          db.execute('INSERT INTO scan_tasks VALUES (?,?,?)', [
            binding,
            batch,
            revision,
          ]);
          db.execute('INSERT INTO scan_queue(binding_id,node) VALUES (?,?)', [
            binding,
            b['root'] ?? '',
          ]);
        });
      }
      var requests = 0;
      while (true) {
        final work = db.select(
          'SELECT * FROM scan_queue WHERE binding_id=? AND done=0 ORDER BY node LIMIT 1',
          [binding],
        ).firstOrNull;
        if (work == null) break;
        final nodeId = work['node'] as String;
        final node = nodeId.isEmpty ? null : ResourceRef(source, nodeId);
        final offset = work['offset'] as int;
        if (++requests > 10000) throw StateError('扫描范围过大，请缩小范围');
        final page = await sources.browse(
          source,
          BrowseRequest(node: node, offset: offset),
        );
        await sources.reload();
        if (!sources.configs.any(
              (c) => c.id == source && c.enabled && c.revision == revision,
            ) ||
            db.select('SELECT id FROM bindings WHERE id=?', [
              binding,
            ]).isEmpty) {
          throw StateError('来源或绑定已变更，请重新扫描');
        }
        for (final entry in page.entries) {
          if (entry.ref.instanceId != source) throw StateError('来源身份不匹配');
          final prefix = scanRoot;
          final normalized = entry.ref.id.replaceAll('\\', '/');
          final root = prefix
              .replaceAll('\\', '/')
              .replaceFirst(RegExp(r'/+$'), '');
          final relative = normalized.startsWith('$root/')
              ? normalized.substring(root.length + 1)
              : normalized;
          if (config.isFileSource && config.excludedFromScan(relative)) {
            continue;
          }
          if (entry.isFolder) {
            if (entry.media != null) {
              final container = register(entry);
              transaction(
                () => _observe(binding, b['library_id'] as String, container),
              );
            }
            db.execute(
              'INSERT OR IGNORE INTO scan_queue(binding_id,node) VALUES (?,?)',
              [binding, entry.ref.id],
            );
            continue;
          }
          if (config.isFileSource &&
              !matchesScanExtension(entry.name, sources.scanExtensions)) {
            continue;
          }
          final media = register(
            entry,
            localPath: config.kind == SourceKind.local ? entry.ref.id : null,
          );
          transaction(() {
            final resource =
                resourceFor(entry.ref)?['id'] ?? resources(media).first['id'];
            db.execute(
              'INSERT INTO evidence VALUES (?,?,?,1) ON CONFLICT(binding_id,resource_id) DO UPDATE SET seen=excluded.seen,available=1',
              [binding, resource, batch],
            );
            _observe(binding, b['library_id'] as String, media);
          });
        }
        final next = page.nextOffset;
        if (next != null && next <= offset) throw StateError('来源分页游标未前进');
        db.execute(
          'UPDATE scan_queue SET offset=?,done=? WHERE binding_id=? AND node=?',
          [next ?? offset, next == null ? 1 : 0, binding, nodeId],
        );
      }
      transaction(() {
        db.execute(
          'UPDATE evidence SET available=0 WHERE binding_id=? AND seen<>?',
          [binding, batch],
        );
        db.execute('DELETE FROM scan_tasks WHERE binding_id=?', [binding]);
        db.execute("UPDATE bindings SET status='扫描完成',error=NULL WHERE id=?", [
          binding,
        ]);
      });
    } catch (error) {
      db.execute("UPDATE bindings SET status='扫描失败',error=? WHERE id=?", [
        error is PluginException ? error.message : '扫描未完成，请检查来源后重试',
        binding,
      ]);
      rethrow;
    } finally {
      _running.remove(binding);
      if (_closeRequested && _running.isEmpty) _closeDatabase();
    }
  }

  /// Valid media files the running scan of [binding] has found so far.
  int scannedMediaCount(String binding) =>
      db.select(
            'SELECT COUNT(*) AS n FROM evidence e JOIN scan_tasks t ON t.binding_id=e.binding_id AND t.batch=e.seen WHERE e.binding_id=?',
            [binding],
          ).first['n']
          as int;

  void addManual(String library, String media) => transaction(() {
    db.execute('DELETE FROM ignored WHERE library_id=? AND media_id=?', [
      library,
      media,
    ]);
    db.execute('INSERT OR IGNORE INTO manual_memberships VALUES (?,?)', [
      library,
      media,
    ]);
    db.execute('INSERT OR IGNORE INTO memberships VALUES (?,?,?)', [
      library,
      media,
      DateTime.now().millisecondsSinceEpoch,
    ]);
    MetadataQueue.observe(db, media);
  });
  Row? resourceFor(ResourceRef ref) => db.select(
    'SELECT r.id,r.media_id,l.source,l.item,r.name FROM resources r JOIN resource_locators l ON l.resource_id=r.id WHERE l.source=? AND l.item=?',
    [ref.instanceId, ref.id],
  ).firstOrNull;
  Row? checkpoint(String resource) => db.select(
    'SELECT * FROM progress WHERE resource_id=?',
    [resource],
  ).firstOrNull;
  String beginSession(String resource) {
    final session = _id();
    db.execute(
      "INSERT INTO progress(resource_id,session,updated_at) VALUES (?,?,?) ON CONFLICT(resource_id) DO UPDATE SET session=excluded.session,updated_at=excluded.updated_at",
      [resource, session, DateTime.now().millisecondsSinceEpoch],
    );
    return session;
  }

  void saveProgress(
    String resource,
    String session,
    Duration position,
    Duration duration, {
    bool completed = false,
  }) {
    if (position.isNegative || duration <= Duration.zero) return;
    db.execute(
      'UPDATE progress SET position=?,duration=?,updated_at=?,completed=? WHERE resource_id=? AND session=?',
      [
        position.inMilliseconds.clamp(0, duration.inMilliseconds),
        duration.inMilliseconds,
        DateTime.now().millisecondsSinceEpoch,
        completed ? 1 : 0,
        resource,
        session,
      ],
    );
  }

  List<Row> continueWatching({int limit = 20}) => db.select(
    """WITH ranked AS (SELECT m.*,r.id AS resource_id,p.position,p.duration,p.completed,p.updated_at,
    ROW_NUMBER() OVER(PARTITION BY m.id ORDER BY p.updated_at DESC,r.id) AS rank
    FROM progress p JOIN resources r ON r.id=p.resource_id JOIN media m ON m.id=r.media_id)
    SELECT * FROM ranked WHERE rank=1 AND position>0 AND completed=0 ORDER BY updated_at DESC,id LIMIT ?""",
    [limit],
  );
  List<Row> recentlyPlayed({int limit = 20}) => db.select(
    """WITH ranked AS (SELECT m.*,r.id AS resource_id,p.position,p.duration,p.completed,p.updated_at,
    ROW_NUMBER() OVER(PARTITION BY m.id ORDER BY p.updated_at DESC,r.id) AS rank
    FROM progress p JOIN resources r ON r.id=p.resource_id JOIN media m ON m.id=r.media_id)
    SELECT * FROM ranked WHERE rank=1 ORDER BY updated_at DESC,id LIMIT ?""",
    [limit],
  );

  bool observedMissing(String resource) {
    final rows = db.select(
      'SELECT available FROM evidence WHERE resource_id=?',
      [resource],
    );
    return rows.isNotEmpty && rows.every((r) => r['available'] == 0);
  }

  int bindingImpact(String binding) =>
      db.select(
            'SELECT COUNT(DISTINCT media_id) AS n FROM media_evidence WHERE binding_id=?',
            [binding],
          ).first['n']
          as int;
  void removeBinding(String binding) => transaction(() {
    final b = db.select('SELECT library_id FROM bindings WHERE id=?', [
      binding,
    ]).first;
    final affected = db.select(
      'SELECT media_id FROM media_evidence WHERE binding_id=?',
      [binding],
    );
    db.execute('DELETE FROM bindings WHERE id=?', [binding]);
    for (final media in affected) {
      db.execute(
        "DELETE FROM memberships WHERE library_id=? AND media_id=? AND NOT EXISTS (SELECT 1 FROM manual_memberships mm WHERE mm.library_id=memberships.library_id AND mm.media_id=memberships.media_id) AND NOT EXISTS (SELECT 1 FROM media_evidence e JOIN bindings b ON b.id=e.binding_id WHERE b.library_id=? AND e.media_id=?)",
        [
          b['library_id'],
          media['media_id'],
          b['library_id'],
          media['media_id'],
        ],
      );
    }
  });
  void close() {
    if (_closeRequested) return;
    _closeRequested = true;
    _externalWatch?.cancel();
    if (_running.isEmpty) _closeDatabase();
  }
}
