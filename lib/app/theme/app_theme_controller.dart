import 'package:flutter/material.dart';

import '../../data/configuration/source_configuration_service.dart';

/// Observes presentation preferences; never owns playback or source lifetimes.
class AppThemeController extends ChangeNotifier {
  AppThemeController({
    this._configuration,
    ThemeMode initialMode = ThemeMode.system,
    String initialLanguage = 'system',
    bool initialDeveloperMode = false,
  }) : _mode = initialMode,
       _language = initialLanguage,
       _developerMode = initialDeveloperMode;
  SourceConfigurationService? _configuration;
  bool _ownsConfiguration = false;
  ThemeMode _mode;
  String _language;
  bool _developerMode;
  String? _saveError;
  ThemeMode get mode => _mode;
  String get language => _language;

  /// Shows developer/debug entry points (e.g. the raw metadata page).
  bool get developerMode => _developerMode;
  String? get saveError => _saveError;
  Locale? get locale => switch (_language) {
    'en' => const Locale('en'),
    'zh-Hans' => const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
    ),
    'zh-Hant' => const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
    ),
    _ => null,
  };
  Future<void> load() async {
    try {
      if (_configuration == null) {
        _configuration = await SourceConfigurationService.open();
        _ownsConfiguration = true;
      }
      final value = _configuration!.appearance('themeMode');
      _mode =
          ThemeMode.values.where((m) => m.name == value).firstOrNull ??
          ThemeMode.system;
      _language = _configuration!.appearance('language') ?? 'system';
      _developerMode = _configuration!.appearance('developerMode') == 'true';
    } catch (_) {
      // An unreadable preference must not prevent application startup.
    }
  }

  Future<void> _save(String key, String value) async {
    try {
      if (_configuration == null) {
        _configuration = await SourceConfigurationService.open();
        _ownsConfiguration = true;
      }
      _configuration!.saveAppearance(key, value);
      _saveError = null;
    } catch (_) {
      _saveError = 'preferenceSaveFailed';
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode value) async {
    _mode = value;
    notifyListeners();
    await _save('themeMode', value.name);
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    notifyListeners();
    await _save('language', value);
  }

  Future<void> setDeveloperMode(bool value) async {
    _developerMode = value;
    notifyListeners();
    await _save('developerMode', '$value');
  }

  @override
  void dispose() {
    if (_ownsConfiguration) _configuration?.close();
    super.dispose();
  }
}

class AppAppearance extends InheritedNotifier<AppThemeController> {
  const AppAppearance({
    super.key,
    required AppThemeController controller,
    required super.child,
  }) : super(notifier: controller);
  static AppThemeController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppAppearance>()!.notifier!;
  static AppThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppAppearance>()?.notifier;
}
