import 'package:shared_preferences/shared_preferences.dart';

/// Only fixed codes cross this boundary; never pass provider error messages.
enum DiagnosticFailure { startup, playbackCommand, metadataBatch }

enum DiagnosticRole { main, player, background }

class DiagnosticsService {
  static const preferenceKey = 'diagnostics.enabled';
  static final preferences = SharedPreferencesAsync();
  static Future<bool> enabled() async {
    try {
      return await preferences.getBool(preferenceKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool value) =>
      preferences.setBool(preferenceKey, value);
}
