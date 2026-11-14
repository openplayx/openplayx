import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../core/plugins/source_capability.dart';
import '../sources/source_config.dart';
import '../sources/source_schema.dart';
import 'configuration_database.dart';

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

/// SQLite is authoritative. Unknown/incompatible rows remain untouched.
class SourceConfigurationService {
  SourceConfigurationService(this._db) {
    _initialize();
  }
  final Database _db;

  /// The `configuration.sqlite3` connection, for the other configuration
  /// owners (ASR, external services, assistant, …).
  Database get db => _db;
  final issues = <ConfigurationIssue>[];
  static Future<SourceConfigurationService> open() async {
    final service = SourceConfigurationService(
      await ConfigurationDatabase.open(),
    );
    return service;
  }

  void _initialize() {
    try {
      ConfigurationDatabase.initialize(_db);
    } on StateError {
      _db.close();
      throw const PluginException('unsupported', '本地配置数据库版本较新，请升级应用。');
    }
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
        configs.add(config.copyWith(hasSecret: row['secret'] != null));
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

  /// Saves [config]; [secret] replaces the saved password or token, null
  /// keeps it.
  SourceConfig save(
    SourceConfig config, {
    required int expectedRevision,
    String? secret,
  }) {
    SourceSchemas.validate(config);
    return _transaction(() {
      final rows = _db.select(
        'SELECT revision, config_version, secret FROM plugin_instance_configs WHERE instance_id=?',
        [config.id],
      );
      if (rows.isNotEmpty && rows.first['config_version'] != 2) {
        throw const PluginException('unsupported', '不能覆盖版本不兼容的实例配置。');
      }
      final revision = rows.isEmpty ? 0 : rows.first['revision'] as int;
      if (revision != expectedRevision) {
        throw const PluginException('conflict', '配置已被其他窗口修改，请重新加载后编辑。');
      }
      final stored =
          secret ?? (rows.isEmpty ? null : rows.first['secret'] as String?);
      final saved = config.copyWith(
        revision: revision + 1,
        hasSecret: stored != null,
      );
      _db.execute(
        'INSERT OR REPLACE INTO plugin_instance_configs VALUES (?,?,?,?,?,?,?)',
        [
          saved.id,
          saved.pluginId,
          jsonEncode(saved.toJson()),
          saved.configVersion,
          saved.revision,
          saved.enabled ? 1 : 0,
          stored,
        ],
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
  });
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

  /// Global file-suffix filter for scans; null means never customized.
  List<String>? scanExtensions() {
    final rows = _db.select(
      "SELECT value_json FROM settings WHERE namespace='sources' AND scope='device' AND owner_id='local' AND key='scanExtensions'",
    );
    return rows.isEmpty
        ? null
        : (jsonDecode(rows.first['value_json'] as String) as List)
              .cast<String>();
  }

  void saveScanExtensions(List<String> value) => _transaction(() {
    _db.execute(
      "INSERT INTO settings VALUES ('sources','device','local','scanExtensions',?,1) "
      'ON CONFLICT(namespace,scope,owner_id,key) DO UPDATE SET value_json=excluded.value_json, revision=settings.revision+1',
      [jsonEncode(value)],
    );
  });

  /// Device-local artwork disk cache limit in MiB; null means never customized.
  int? artworkCacheQuotaMb() {
    final rows = _db.select(
      "SELECT value_json FROM settings WHERE namespace='artwork' AND scope='device' AND owner_id='local' AND key='cacheQuotaMb'",
    );
    return rows.isEmpty
        ? null
        : jsonDecode(rows.first['value_json'] as String) as int?;
  }

  void saveArtworkCacheQuotaMb(int value) => _transaction(() {
    _db.execute(
      "INSERT INTO settings VALUES ('artwork','device','local','cacheQuotaMb',?,1) "
      'ON CONFLICT(namespace,scope,owner_id,key) DO UPDATE SET value_json=excluded.value_json, revision=settings.revision+1',
      [jsonEncode(value)],
    );
  });

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

  /// A typed device-local settings document and its revision (0 when absent).
  (Map<String, dynamic>?, int) readDocument(String namespace, String key) {
    final rows = _db.select(
      "SELECT value_json, revision FROM settings WHERE namespace=? AND scope='device' AND owner_id='local' AND key=?",
      [namespace, key],
    );
    if (rows.isEmpty) return (null, 0);
    return (
      jsonDecode(rows.first['value_json'] as String) as Map<String, dynamic>,
      rows.first['revision'] as int,
    );
  }

  /// Compare-and-set write: fails with `conflict` when another window saved
  /// first, so two editors never silently overwrite each other.
  int writeDocument(
    String namespace,
    String key,
    Map<String, dynamic> value, {
    required int expectedRevision,
  }) => _transaction(() {
    final (_, revision) = readDocument(namespace, key);
    if (revision != expectedRevision) {
      throw const PluginException('conflict', '设置已被其他窗口修改，请重新加载。');
    }
    _db.execute('INSERT OR REPLACE INTO settings VALUES (?,?,?,?,?,?)', [
      namespace,
      'device',
      'local',
      key,
      jsonEncode(value),
      revision + 1,
    ]);
    return revision + 1;
  });

  /// The password or token saved on instance [id], if any.
  String? readSecret(String id) =>
      _db.select(
            'SELECT secret FROM plugin_instance_configs WHERE instance_id=?',
            [id],
          ).firstOrNull?['secret']
          as String?;

  void close() => _db.close();
}
