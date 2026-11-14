import 'package:sqlite3/sqlite3.dart';

import '../../data/configuration/configuration_database.dart';

/// Only fixed codes cross this boundary; never pass provider error messages.
enum DiagnosticFailure { startup, playbackCommand, metadataBatch }

enum DiagnosticRole { main, player, background }

/// The opt-in switch lives in `configuration.sqlite3` (`diagnostics /
/// enabled`). It is read on every check, so a change made in the main window
/// applies to player windows and background work too.
class DiagnosticsService {
  static const namespace = 'diagnostics';
  static const key = 'enabled';
  static Future<Database>? _db;

  static Future<Database> _open() async {
    final pending = _db ??= ConfigurationDatabase.open();
    try {
      return await pending;
    } catch (_) {
      // Retry on the next check instead of caching the failure.
      if (identical(_db, pending)) _db = null;
      rethrow;
    }
  }

  static Future<bool> enabled() async {
    try {
      return ConfigurationDatabase.readSetting(await _open(), namespace, key) ==
          true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool value) async =>
      ConfigurationDatabase.writeSetting(await _open(), namespace, key, value);
}
