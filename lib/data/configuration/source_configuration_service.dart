import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/plugins/source_capability.dart';
import '../sources/source_config.dart';
import '../sources/source_schema.dart';

class ConfigurationIssue {
  const ConfigurationIssue(this.instanceId, this.message);
  final String instanceId;
  final String message;
}

class SourceBindings {
  const SourceBindings({
    this.defaults = const {},
    this.searchInstances = const [],
    this.revision = 0,
  });
  final Map<String, String> defaults;
  final List<String> searchInstances;
  final int revision;
}

/// SQLite is authoritative; legacy preferences are read once and removed only
/// after a successful transaction. Unknown/incompatible rows remain untouched.
class SourceConfigurationService {
  SourceConfigurationService(this._db) {
    _initialize();
  }
  final Database _db;
  final issues = <ConfigurationIssue>[];
  static Future<SourceConfigurationService> open() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final service = SourceConfigurationService(
      sqlite3.open(
        '${directory.path}${Platform.pathSeparator}configuration.sqlite3',
      ),
    );
    await service.migrateLegacy();
    return service;
  }

  void _initialize() {
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('PRAGMA busy_timeout = 5000');
    final version = _db.select('PRAGMA user_version').first.values.first as int;
    if (version > 1) {
      _db.close();
      throw const PluginException('unsupported', '本地配置数据库版本较新，请升级应用。');
    }
    _db.execute(
      '''CREATE TABLE IF NOT EXISTS plugin_instance_configs (
      instance_id TEXT PRIMARY KEY, plugin_id TEXT NOT NULL, config_json TEXT NOT NULL,
      config_version INTEGER NOT NULL, revision INTEGER NOT NULL, enabled_desired INTEGER NOT NULL)''',
    );
    _db.execute('''CREATE TABLE IF NOT EXISTS config_applications (
      target_id TEXT PRIMARY KEY, desired_revision INTEGER NOT NULL, applied_revision INTEGER,
      status TEXT NOT NULL, error_code TEXT)''');
    _db.execute('''CREATE TABLE IF NOT EXISTS settings (
      namespace TEXT NOT NULL, scope TEXT NOT NULL, owner_id TEXT NOT NULL,
      key TEXT NOT NULL, value_json TEXT NOT NULL, revision INTEGER NOT NULL,
      PRIMARY KEY(namespace, scope, owner_id, key))''');
    _db.execute('PRAGMA user_version = 1');
  }

  T _transaction<T>(T Function() body) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final result = body();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> migrateLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('source.instances.v1');
    if (raw == null) return;
    final records = jsonDecode(raw) as List;
    _transaction(() {
      for (final (index, value) in records.indexed) {
        final record = value is Map<String, dynamic>
            ? value
            : <String, dynamic>{'invalid': value};
        final id = record['id'] is String
            ? record['id'] as String
            : 'legacy-invalid-$index';
        if (_db.select(
          'SELECT 1 FROM plugin_instance_configs WHERE instance_id=?',
          [id],
        ).isNotEmpty) {
          continue;
        }
        Map<String, dynamic> data;
        try {
          final config = SourceConfig.fromJson(record).copyWith(
            revision: 1,
            credentialRef: record['kind'] == 'local' ? null : 'source.$id',
          );
          SourceSchemas.validate(config);
          data = config.toJson();
        } catch (_) {
          data = Map.of(record);
        }
        _db.execute(
          'INSERT INTO plugin_instance_configs VALUES (?,?,?,?,?,?)',
          [
            id,
            'source.${record['kind']}',
            jsonEncode(data),
            data['configVersion'] is int ? data['configVersion'] : 2,
            1,
            data['enabled'] == false ? 0 : 1,
          ],
        );
      }
    });
    await prefs.remove('source.instances.v1');
  }

  List<SourceConfig> load() {
    issues.clear();
    final configs = <SourceConfig>[];
    for (final row in _db.select(
      'SELECT * FROM plugin_instance_configs ORDER BY rowid',
    )) {
      try {
        if (row['config_version'] != 2) {
          throw const FormatException('配置版本不兼容，原数据已保留。');
        }
        final config = SourceConfig.fromJson(
          jsonDecode(row['config_json'] as String) as Map<String, dynamic>,
        );
        SourceSchemas.validate(config);
        if (config.id != row['instance_id'] ||
            config.pluginId != row['plugin_id'] ||
            config.revision != row['revision'] ||
            config.enabled != (row['enabled_desired'] == 1)) {
          throw const FormatException('实例配置与元数据不一致。');
        }
        configs.add(config);
      } catch (_) {
        issues.add(
          ConfigurationIssue(
            row['instance_id'] as String,
            '实例配置不兼容或损坏，已隔离且保留原数据。',
          ),
        );
      }
    }
    return List.unmodifiable(configs);
  }

  SourceConfig save(SourceConfig config, {required int expectedRevision}) {
    SourceSchemas.validate(config);
    return _transaction(() {
      final rows = _db.select(
        'SELECT revision, config_version FROM plugin_instance_configs WHERE instance_id=?',
        [config.id],
      );
      if (rows.isNotEmpty && rows.first['config_version'] != 2) {
        throw const PluginException('unsupported', '不能覆盖版本不兼容的实例配置。');
      }
      final revision = rows.isEmpty ? 0 : rows.first['revision'] as int;
      if (revision != expectedRevision) {
        throw const PluginException('conflict', '配置已被其他窗口修改，请重新加载后编辑。');
      }
      final saved = config.copyWith(revision: revision + 1);
      _db.execute(
        'INSERT OR REPLACE INTO plugin_instance_configs VALUES (?,?,?,?,?,?)',
        [
          saved.id,
          saved.pluginId,
          jsonEncode(saved.toJson()),
          saved.configVersion,
          saved.revision,
          saved.enabled ? 1 : 0,
        ],
      );
      _db.execute(
        '''INSERT INTO config_applications VALUES (?,?,NULL,?,NULL) ON CONFLICT(target_id) DO UPDATE SET
          desired_revision=excluded.desired_revision,status=excluded.status,error_code=NULL''',
        [saved.id, saved.revision, saved.enabled ? 'pending' : 'disabled'],
      );
      if (!saved.enabled) _removeBindings(saved.id);
      return saved;
    });
  }

  void remove(String id, int expectedRevision) => _transaction(() {
    final rows = _db.select(
      'SELECT revision FROM plugin_instance_configs WHERE instance_id=?',
      [id],
    );
    if (rows.isEmpty) return;
    if (rows.first['revision'] != expectedRevision) {
      throw const PluginException('conflict', '配置已更新，请重新加载后删除。');
    }
    _removeBindings(id);
    _db.execute('DELETE FROM plugin_instance_configs WHERE instance_id=?', [
      id,
    ]);
    _db.execute('DELETE FROM config_applications WHERE target_id=?', [id]);
  });
  void markApplication(
    SourceConfig config,
    String status, {
    String? errorCode,
  }) {
    final current = _db.select(
      'SELECT revision FROM plugin_instance_configs WHERE instance_id=?',
      [config.id],
    );
    if (current.isEmpty || current.first['revision'] != config.revision) return;
    _db.execute(
      '''INSERT INTO config_applications VALUES (?,?,?,?,?) ON CONFLICT(target_id) DO UPDATE SET
      desired_revision=excluded.desired_revision, applied_revision=CASE WHEN excluded.status='ready' THEN excluded.applied_revision ELSE config_applications.applied_revision END,
      status=excluded.status,error_code=excluded.error_code''',
      [
        config.id,
        config.revision,
        status == 'ready' ? config.revision : null,
        status,
        errorCode,
      ],
    );
  }

  Map<String, Object?>? application(String id) {
    final result = _db.select(
      'SELECT * FROM config_applications WHERE target_id=?',
      [id],
    );
    return result.isEmpty ? null : Map.of(result.first);
  }

  SourceBindings bindings() {
    final rows = _db.select(
      "SELECT * FROM settings WHERE namespace='sources' AND scope='device' AND owner_id='local' AND key='bindings'",
    );
    if (rows.isEmpty) return const SourceBindings();
    final data =
        jsonDecode(rows.first['value_json'] as String) as Map<String, dynamic>;
    return SourceBindings(
      defaults: Map.unmodifiable(
        (data['defaults'] as Map).cast<String, String>(),
      ),
      searchInstances: List.unmodifiable(
        (data['searchInstances'] as List).cast<String>(),
      ),
      revision: rows.first['revision'] as int,
    );
  }

  void saveBindings(SourceBindings next, {required int expectedRevision}) =>
      _transaction(() {
        if (bindings().revision != expectedRevision) {
          throw const PluginException('conflict', '默认实例设置已更新，请重新加载。');
        }
        _writeBindings(next);
      });
  void _writeBindings(SourceBindings next) {
    _db.execute('INSERT OR REPLACE INTO settings VALUES (?,?,?,?,?,?)', [
      'sources',
      'device',
      'local',
      'bindings',
      jsonEncode({
        'defaults': next.defaults,
        'searchInstances': next.searchInstances,
      }),
      bindings().revision + 1,
    ]);
  }

  void _removeBindings(String id) {
    final current = bindings();
    if (current.defaults.containsValue(id) ||
        current.searchInstances.contains(id)) {
      _writeBindings(
        SourceBindings(
          defaults: Map.of(current.defaults)
            ..removeWhere((_, value) => value == id),
          searchInstances: current.searchInstances
              .where((value) => value != id)
              .toList(),
        ),
      );
    }
  }

  String? appearance(String key) {
    final rows = _db.select(
      "SELECT value_json FROM settings WHERE namespace='appearance' AND scope='user' AND owner_id='local' AND key=?",
      [key],
    );
    return rows.isEmpty
        ? null
        : jsonDecode(rows.first['value_json'] as String) as String?;
  }

  void saveAppearance(String key, String value) => _transaction(() {
    _db.execute(
      "INSERT INTO settings VALUES ('appearance','user','local',?,?,1) "
      'ON CONFLICT(namespace,scope,owner_id,key) DO UPDATE SET value_json=excluded.value_json, revision=settings.revision+1',
      [key, jsonEncode(value)],
    );
  });

  void close() => _db.close();
}
