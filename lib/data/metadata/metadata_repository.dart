import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:sqlite3/sqlite3.dart';

import '../../core/plugins/metadata_capability.dart';
import '../../core/plugins/source_capability.dart';

/// Shares the media library database. Projection updates and job commits are a
/// single transaction; resources and playback progress are never rewritten.
class MetadataRepository {
  MetadataRepository(this.db);
  final Database db;
  void migrate() {
    db.execute(
      '''CREATE TABLE IF NOT EXISTS metadata_state (
      media_id TEXT PRIMARY KEY REFERENCES media(id), revision INTEGER NOT NULL DEFAULT 0,
      fallback_title TEXT NOT NULL, association TEXT, confirmed INTEGER NOT NULL DEFAULT 0)''',
    );
    db.execute('''CREATE TABLE IF NOT EXISTS metadata_observations (
      media_id TEXT NOT NULL REFERENCES media(id), source_key TEXT NOT NULL,
      authority INTEGER NOT NULL, record TEXT NOT NULL, fetched_at INTEGER NOT NULL,
      missing INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(media_id,source_key))''');
    db.execute('''CREATE TABLE IF NOT EXISTS metadata_overrides (
      media_id TEXT NOT NULL REFERENCES media(id), field TEXT NOT NULL, value TEXT NOT NULL,
      updated_at INTEGER NOT NULL, PRIMARY KEY(media_id,field))''');
    db.execute(
      '''CREATE TABLE IF NOT EXISTS metadata_projection (
      media_id TEXT PRIMARY KEY REFERENCES media(id), fields TEXT NOT NULL, provenance TEXT NOT NULL)''',
    );
    db.execute('''CREATE TABLE IF NOT EXISTS metadata_jobs (
      id TEXT PRIMARY KEY, media_id TEXT NOT NULL REFERENCES media(id), stage TEXT NOT NULL,
      revision INTEGER NOT NULL, input TEXT NOT NULL, candidates TEXT NOT NULL DEFAULT '[]',
      error_code TEXT, updated_at INTEGER NOT NULL)''');
    db.execute('''CREATE TABLE IF NOT EXISTS metadata_history (
      operation_id TEXT PRIMARY KEY, media_id TEXT NOT NULL REFERENCES media(id),
      previous TEXT, current TEXT, changed_at INTEGER NOT NULL)''');
    db.execute('''CREATE TABLE IF NOT EXISTS artwork_selections (
      media_id TEXT NOT NULL REFERENCES media(id), type TEXT NOT NULL, descriptor TEXT NOT NULL,
      locked INTEGER NOT NULL, PRIMARY KEY(media_id,type))''');
    db.execute('''CREATE TABLE IF NOT EXISTS metadata_settings (
      key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
    db.execute('''CREATE TABLE IF NOT EXISTS metadata_containers (
      scope TEXT PRIMARY KEY, media_id TEXT NOT NULL REFERENCES media(id))''');
    db.execute('''CREATE TABLE IF NOT EXISTS metadata_relations (
      parent_id TEXT NOT NULL REFERENCES media(id), child_id TEXT PRIMARY KEY REFERENCES media(id),
      CHECK(parent_id<>child_id))''');
    db.execute(
      'INSERT OR IGNORE INTO metadata_state(media_id,fallback_title) SELECT id,title FROM media',
    );
  }

  /// Only materializes confirmed ancestors of an owned item, never the full
  /// provider catalogue. Scope prevents merging media across source instances.
  void attachHierarchy(
    String media,
    List<({String scope, MetadataRecord record})> ancestors, {
    required String operationId,
  }) {
    String? parent;
    for (var index = 0; index < ancestors.length; index++) {
      final entry = ancestors[index];
      final id = 'metadata:${sha256.convert(utf8.encode(entry.scope))}';
      db.execute('INSERT OR IGNORE INTO media(id,title) VALUES (?,?)', [
        id,
        entry.record.title,
      ]);
      db.execute('INSERT OR IGNORE INTO metadata_containers VALUES (?,?)', [
        entry.scope,
        id,
      ]);
      ensure(id);
      final selected = association(id);
      if (selected != null &&
          !compatible(entry.record, selected) &&
          confirmed(id)) {
        throw const PluginException('identityConflict', '剧集或季的身份存在冲突');
      }
      apply(
        id,
        entry.record,
        sourceKey: entry.scope,
        authority: entry.record.ref.provider == 'tmdb' ? 100 : 200,
        expectedRevision: revision(id),
        operationId: '$operationId:ancestor:$index',
        select: true,
        selectedRef: entry.record.externalIds.firstOrNull ?? entry.record.ref,
        userConfirmed: confirmed(id),
      );
      db.execute(
        '''INSERT OR IGNORE INTO memberships SELECT library_id,?,added_at FROM memberships
        WHERE media_id=? AND NOT EXISTS (SELECT 1 FROM ignored i WHERE i.library_id=memberships.library_id AND i.media_id=?)''',
        [id, media, id],
      );
      if (parent != null) {
        db.execute(
          'INSERT INTO metadata_relations VALUES (?,?) ON CONFLICT(child_id) DO UPDATE SET parent_id=excluded.parent_id',
          [parent, id],
        );
      }
      parent = id;
    }
    if (parent != null) {
      db.execute(
        'INSERT INTO metadata_relations VALUES (?,?) ON CONFLICT(child_id) DO UPDATE SET parent_id=excluded.parent_id',
        [parent, media],
      );
    }
  }

  void recover() => db.execute(
    "UPDATE metadata_jobs SET stage='cancelled',error_code='interrupted' WHERE stage IN ('queued','collecting','searching','fetching','applying')",
  );
  int get _now => DateTime.now().millisecondsSinceEpoch;
  void ensure(String media) => db.execute(
    'INSERT OR IGNORE INTO metadata_state(media_id,fallback_title) SELECT id,title FROM media WHERE id=?',
    [media],
  );
  int revision(String media) {
    ensure(media);
    return db.select('SELECT revision FROM metadata_state WHERE media_id=?', [
          media,
        ]).single['revision']
        as int;
  }

  void check(String media, int expected) {
    if (revision(media) != expected) {
      throw const PluginException('conflict', '信息已更改，请重新加载后操作');
    }
  }

  void _bump(String media) => db.execute(
    'UPDATE metadata_state SET revision=revision+1 WHERE media_id=?',
    [media],
  );
  MetadataRef? association(String media) {
    ensure(media);
    final raw =
        db.select('SELECT association FROM metadata_state WHERE media_id=?', [
              media,
            ]).single['association']
            as String?;
    return raw == null ? null : MetadataRef.fromJson(jsonDecode(raw));
  }

  bool confirmed(String media) {
    ensure(media);
    return db.select('SELECT confirmed FROM metadata_state WHERE media_id=?', [
          media,
        ]).single['confirmed'] ==
        1;
  }

  Map<String, dynamic> fields(String media) {
    final r = db.select(
      'SELECT fields FROM metadata_projection WHERE media_id=?',
      [media],
    ).firstOrNull;
    return r == null
        ? {
            'title':
                db.select('SELECT title FROM media WHERE id=?', [
                  media,
                ]).firstOrNull?['title'] ??
                '',
          }
        : jsonDecode(r['fields'] as String);
  }

  Map<String, dynamic> provenance(String media) {
    final r = db.select(
      'SELECT provenance FROM metadata_projection WHERE media_id=?',
      [media],
    ).firstOrNull;
    return r == null ? {} : jsonDecode(r['provenance'] as String);
  }

  Set<String> lockedFields(String media) => db
      .select('SELECT field FROM metadata_overrides WHERE media_id=?', [media])
      .map((r) => r['field'] as String)
      .toSet();
  List<MetadataRecord> observations(String media) => db
      .select(
        'SELECT record FROM metadata_observations WHERE media_id=? ORDER BY authority DESC,fetched_at DESC',
        [media],
      )
      .map((r) => MetadataRecord.fromJson(jsonDecode(r['record'] as String)))
      .toList();
  bool compatible(MetadataRecord record, MetadataRef selected) =>
      record.ref.key == selected.key ||
      record.externalIds.any((e) => e.key == selected.key);

  /// Must be called inside the library's transaction.
  bool apply(
    String media,
    MetadataRecord record, {
    required String sourceKey,
    required int authority,
    required int expectedRevision,
    required String operationId,
    bool select = false,
    bool userConfirmed = false,
    MetadataRef? selectedRef,
  }) {
    if (db.select(
      'SELECT operation_id FROM metadata_history WHERE operation_id=?',
      [operationId],
    ).isNotEmpty) {
      return false;
    }
    check(media, expectedRevision);
    final old = association(media);
    final oldConfirmed = confirmed(media);
    var selected = old;
    if (select) {
      selected = selectedRef ?? record.ref;
      db.execute(
        'UPDATE metadata_state SET association=?,confirmed=? WHERE media_id=?',
        [jsonEncode(selected.toJson()), userConfirmed ? 1 : 0, media],
      );
    }
    if (selected != null && !compatible(record, selected)) {
      throw const PluginException('identityConflict', '作品 ID 冲突，需要人工确认');
    }
    // Empty fields in refresh do not delete existing valid data.
    final prior = db.select(
      'SELECT record,missing FROM metadata_observations WHERE media_id=? AND source_key=?',
      [media, sourceKey],
    ).firstOrNull;
    if (prior != null) {
      final previous = MetadataRecord.fromJson(
        jsonDecode(prior['record'] as String),
      );
      if (previous.ref.key == record.ref.key ||
          (selected != null && compatible(previous, selected))) {
        final merged = {...previous.fields};
        for (final f in record.fields.entries) {
          if (f.value != null &&
              f.value != '' &&
              !(f.value is List && (f.value as List).isEmpty)) {
            merged[f.key] = f.value;
          }
        }
        record = MetadataRecord(
          ref: record.ref,
          fields: merged,
          language: record.language,
          externalIds: record.externalIds.isEmpty
              ? previous.externalIds
              : record.externalIds,
          artwork: record.artwork.isEmpty ? previous.artwork : record.artwork,
          children: record.children,
          warnings: record.warnings,
          contentRevision: record.contentRevision,
        );
      }
    }
    if (prior != null &&
        prior['missing'] == 0 &&
        prior['record'] == jsonEncode(record.toJson()) &&
        old?.key == selected?.key &&
        (!select || oldConfirmed == userConfirmed)) {
      return false;
    }
    db.execute(
      '''INSERT INTO metadata_observations VALUES (?,?,?,?,?,0)
      ON CONFLICT(media_id,source_key) DO UPDATE SET authority=excluded.authority,
      record=excluded.record,fetched_at=excluded.fetched_at,missing=0''',
      [media, sourceKey, authority, jsonEncode(record.toJson()), _now],
    );
    db.execute('INSERT INTO metadata_history VALUES (?,?,?,?,?)', [
      operationId,
      media,
      old == null ? null : jsonEncode(old.toJson()),
      selected == null ? null : jsonEncode(selected.toJson()),
      _now,
    ]);
    _bump(media);
    rebuild(media);
    return true;
  }

  void rebuild(String media) {
    ensure(media);
    final selected = association(media);
    final fields = <String, dynamic>{};
    final provenance = <String, dynamic>{};
    // Fill high-priority valid fields first, then fallback to lower-priority.
    for (final row in db.select(
      'SELECT * FROM metadata_observations WHERE media_id=? ORDER BY authority DESC,fetched_at DESC',
      [media],
    )) {
      final record = MetadataRecord.fromJson(
        jsonDecode(row['record'] as String),
      );
      if (selected != null && !compatible(record, selected)) continue;
      for (final entry in record.fields.entries) {
        if (entry.value == null ||
            entry.value == '' ||
            entry.value is List && (entry.value as List).isEmpty) {
          continue;
        }
        if (entry.key == 'ratings' &&
            fields['ratings'] is Map &&
            entry.value is Map) {
          fields['ratings'] = {
            ...entry.value as Map,
            ...fields['ratings'] as Map,
          };
        } else if (!fields.containsKey(entry.key)) {
          fields[entry.key] = entry.value;
          provenance[entry.key] = {
            'source': row['source_key'],
            'language': record.language,
            'missing': row['missing'] == 1,
          };
        }
      }
    }
    fields['title'] ??= db.select(
      'SELECT fallback_title FROM metadata_state WHERE media_id=?',
      [media],
    ).single['fallback_title'];
    provenance['title'] ??= {'source': 'filename', 'language': 'und'};
    for (final row in db.select(
      'SELECT * FROM metadata_overrides WHERE media_id=?',
      [media],
    )) {
      fields[row['field'] as String] = jsonDecode(row['value'] as String);
      provenance[row['field'] as String] = {'source': 'user', 'locked': true};
    }
    db.execute(
      'INSERT INTO metadata_projection VALUES (?,?,?) ON CONFLICT(media_id) DO UPDATE SET fields=excluded.fields,provenance=excluded.provenance',
      [media, jsonEncode(fields), jsonEncode(provenance)],
    );
    db.execute('UPDATE media SET title=? WHERE id=?', [fields['title'], media]);
    // Auto selection follows the current work; explicit poster locks survive.
    final artwork = artworkCandidates(media);
    for (final type in ['poster', 'backdrop', 'thumbnail']) {
      final chosen = artwork.where((a) => a.type == type).firstOrNull;
      final locked =
          db.select(
            'SELECT locked FROM artwork_selections WHERE media_id=? AND type=?',
            [media, type],
          ).firstOrNull?['locked'] ==
          1;
      if (!locked) {
        db.execute(
          'DELETE FROM artwork_selections WHERE media_id=? AND type=?',
          [media, type],
        );
        if (chosen != null) {
          db.execute('INSERT INTO artwork_selections VALUES (?,?,?,0)', [
            media,
            type,
            jsonEncode(chosen.toJson()),
          ]);
        }
      }
    }
  }

  void overrideField(
    String media,
    String field,
    dynamic value, {
    required int expectedRevision,
  }) {
    check(media, expectedRevision);
    if (![
          'title',
          'originalTitle',
          'overview',
          'year',
          'genres',
        ].contains(field) ||
        (value != null &&
            (jsonEncode(value).length > 32768 ||
                (['title', 'originalTitle', 'overview'].contains(field) &&
                    value is! String) ||
                (field == 'title' && (value as String).trim().isEmpty) ||
                (field == 'year' && value is! int) ||
                (field == 'genres' && value is! List)))) {
      throw const PluginException('invalidInput', '字段值无效');
    }
    if (value == null) {
      db.execute(
        'DELETE FROM metadata_overrides WHERE media_id=? AND field=?',
        [media, field],
      );
    } else {
      db.execute(
        'INSERT INTO metadata_overrides VALUES (?,?,?,?) ON CONFLICT(media_id,field) DO UPDATE SET value=excluded.value,updated_at=excluded.updated_at',
        [media, field, jsonEncode(value), _now],
      );
    }
    _bump(media);
    rebuild(media);
  }

  List<ArtworkDescriptor> artworkCandidates(String media) {
    final selected = association(media);
    final result = <ArtworkDescriptor>[];
    for (final record in observations(media)) {
      if (selected != null && !compatible(record, selected)) continue;
      for (final a in record.artwork) {
        if (!result.any((e) => e.id == a.id)) result.add(a);
      }
    }
    return result;
  }

  List<ArtworkDescriptor> get retainedArtwork => db
      .select('SELECT descriptor FROM artwork_selections WHERE locked=1')
      .map(
        (r) =>
            ArtworkDescriptor.fromJson(jsonDecode(r['descriptor'] as String)),
      )
      .toList();

  ArtworkDescriptor? selectedArtwork(String media, {String type = 'poster'}) {
    final row = db.select(
      'SELECT descriptor FROM artwork_selections WHERE media_id=? AND type=?',
      [media, type],
    ).firstOrNull;
    return row == null
        ? null
        : ArtworkDescriptor.fromJson(jsonDecode(row['descriptor'] as String));
  }

  bool artworkLocked(String media, {String type = 'poster'}) =>
      db.select(
        'SELECT locked FROM artwork_selections WHERE media_id=? AND type=?',
        [media, type],
      ).firstOrNull?['locked'] ==
      1;
  void unlockArtwork(
    String media, {
    String type = 'poster',
    required int expectedRevision,
  }) {
    check(media, expectedRevision);
    db.execute(
      'UPDATE artwork_selections SET locked=0 WHERE media_id=? AND type=?',
      [media, type],
    );
    _bump(media);
    rebuild(media);
  }

  void selectArtwork(
    String media,
    ArtworkDescriptor artwork, {
    required int expectedRevision,
    bool locked = true,
  }) {
    check(media, expectedRevision);
    if (!artworkCandidates(media).any((a) => a.id == artwork.id)) {
      throw const PluginException('invalidInput', '海报不属于当前作品');
    }
    db.execute(
      'INSERT INTO artwork_selections VALUES (?,?,?,?) ON CONFLICT(media_id,type) DO UPDATE SET descriptor=excluded.descriptor,locked=excluded.locked',
      [media, artwork.type, jsonEncode(artwork.toJson()), locked ? 1 : 0],
    );
    _bump(media);
  }

  void reset(
    String media, {
    required int expectedRevision,
    required String operationId,
  }) {
    check(media, expectedRevision);
    final old = association(media);
    db.execute('INSERT INTO metadata_history VALUES (?,?,?,?,?)', [
      operationId,
      media,
      old == null ? null : jsonEncode(old.toJson()),
      null,
      _now,
    ]);
    db.execute(
      'UPDATE metadata_state SET association=NULL,confirmed=0 WHERE media_id=?',
      [media],
    );
    db.execute('DELETE FROM metadata_observations WHERE media_id=?', [media]);
    db.execute('DELETE FROM metadata_relations WHERE child_id=?', [media]);
    db.execute('DELETE FROM artwork_selections WHERE media_id=? AND locked=0', [
      media,
    ]);
    _bump(media);
    rebuild(media);
  }

  void markMissing(String media, String sourceKey) {
    db.execute(
      'UPDATE metadata_observations SET missing=1 WHERE media_id=? AND source_key=?',
      [media, sourceKey],
    );
    rebuild(media);
  }

  String setting(String key, {String fallback = ''}) =>
      db.select('SELECT value FROM metadata_settings WHERE key=?', [
            key,
          ]).firstOrNull?['value']
          as String? ??
      fallback;
  void setSetting(String key, String value) => db.execute(
    'INSERT INTO metadata_settings VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
    [key, value],
  );
  String createJob(String media, Map<String, dynamic> input) {
    final id = '${DateTime.now().microsecondsSinceEpoch}-$media';
    db.execute(
      'INSERT INTO metadata_jobs(id,media_id,stage,revision,input,updated_at) VALUES (?,?,?,?,?,?)',
      [id, media, 'queued', revision(media), jsonEncode(input), _now],
    );
    return id;
  }

  Row job(String id) =>
      db.select('SELECT * FROM metadata_jobs WHERE id=?', [id]).single;
  Row? latestJob(String media) => db.select(
    'SELECT * FROM metadata_jobs WHERE media_id=? ORDER BY updated_at DESC,rowid DESC LIMIT 1',
    [media],
  ).firstOrNull;
  void stage(
    String id,
    String stage, {
    String? error,
    List<MetadataRecord>? candidates,
  }) {
    db.execute(
      'UPDATE metadata_jobs SET stage=?,error_code=?,updated_at=? WHERE id=?',
      [stage, error, _now, id],
    );
    if (candidates != null) {
      db.execute('UPDATE metadata_jobs SET candidates=? WHERE id=?', [
        jsonEncode(candidates.map((r) => r.toJson()).toList()),
        id,
      ]);
    }
  }
}
