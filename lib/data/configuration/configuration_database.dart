import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// `configuration.sqlite3`: everything the user configured, and nothing the
/// App produces while it is used (that lives in `library.sqlite3`). It stays
/// small and is the only place configuration is kept.
///
/// A password, token or API key is stored on the configuration item it
/// belongs to (a source row, an external service row, a settings document),
/// not in a separate store. It is kept here instead of the OS keychain so
/// saving a credential never triggers a system password prompt.
///
/// Every configuration table is declared here, so the whole schema can be
/// read in one place. Opening is idempotent; each owner (sources, ASR,
/// external services, …) may call [initialize] on the connection it gets.
abstract final class ConfigurationDatabase {
  static const fileName = 'configuration.sqlite3';
  static const version = 4;

  static Future<Database> open() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final db = sqlite3.open(
      '${directory.path}${Platform.pathSeparator}$fileName',
    );
    try {
      initialize(db);
    } catch (_) {
      db.close();
      rethrow;
    }
    return db;
  }

  static void initialize(Database db) {
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('PRAGMA busy_timeout = 5000');
    final current = db.select('PRAGMA user_version').first.values.first as int;
    if (current > version) {
      throw StateError('本地配置数据库版本较新，请升级应用。');
    }
    if (current != 0 && current < 4) {
      // Not migrated (no backward compatibility): credentials moved onto
      // their configuration items; speech recognition backends became the
      // `asr / backends` setting. Tables whose shape changed are recreated.
      for (final table in [
        'source_secrets',
        'asr_backends',
        'secrets',
        'plugin_instance_configs',
        'config_applications',
        'external_services',
      ]) {
        db.execute('DROP TABLE IF EXISTS $table');
      }
    }
    // Media source instances (SMB, WebDAV, Plex, …) with their password or
    // token in [secret].
    db.execute('''CREATE TABLE IF NOT EXISTS plugin_instance_configs (
      instance_id TEXT PRIMARY KEY, plugin_id TEXT NOT NULL, config_json TEXT NOT NULL,
      config_version INTEGER NOT NULL, revision INTEGER NOT NULL, enabled_desired INTEGER NOT NULL,
      secret TEXT)''');
    // Typed settings documents: appearance, scanning, plugin policy, speech
    // recognition backends, assistant model, metadata, remote access,
    // diagnostics, …
    db.execute('''CREATE TABLE IF NOT EXISTS settings (
      namespace TEXT NOT NULL, scope TEXT NOT NULL, owner_id TEXT NOT NULL,
      key TEXT NOT NULL, value_json TEXT NOT NULL, revision INTEGER NOT NULL,
      PRIMARY KEY(namespace, scope, owner_id, key))''');
    // External MCP services (AI → 外部能力) with their access [token].
    db.execute('''CREATE TABLE IF NOT EXISTS external_services (
      id TEXT PRIMARY KEY, name TEXT NOT NULL,
      base_url TEXT NOT NULL, endpoint TEXT NOT NULL,
      server_name TEXT NOT NULL DEFAULT '',
      server_title TEXT NOT NULL DEFAULT '',
      version TEXT NOT NULL DEFAULT '',
      tools_json TEXT NOT NULL DEFAULT '[]',
      tool_defs_json TEXT NOT NULL DEFAULT '[]',
      available INTEGER NOT NULL DEFAULT 0,
      checked_at TEXT,
      created INTEGER NOT NULL, token TEXT)''');
    // File sources: one connection (a media source instance) plus the folder
    // chosen on it, with a display name and a switch. Their scan state and
    // results live in library.sqlite3, keyed by this id.
    db.execute('''CREATE TABLE IF NOT EXISTS file_sources (
      id TEXT PRIMARY KEY, source_id TEXT NOT NULL, root TEXT, name TEXT,
      enabled INTEGER NOT NULL DEFAULT 1, created INTEGER NOT NULL)''');
    if (current != version) db.execute('PRAGMA user_version = $version');
  }

  /// Reads a device-level setting written by [writeSetting].
  static Object? readSetting(Database db, String namespace, String key) {
    final rows = db.select(
      "SELECT value_json FROM settings WHERE namespace=? AND scope='device' AND owner_id='local' AND key=?",
      [namespace, key],
    );
    return rows.isEmpty ? null : jsonDecode(rows.first['value_json'] as String);
  }

  static void writeSetting(
    Database db,
    String namespace,
    String key,
    Object? value,
  ) => db.execute(
    "INSERT INTO settings VALUES (?,'device','local',?,?,1) "
    'ON CONFLICT(namespace,scope,owner_id,key) DO UPDATE SET value_json=excluded.value_json, revision=settings.revision+1',
    [namespace, key, jsonEncode(value)],
  );
}
