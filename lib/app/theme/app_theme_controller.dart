import 'package:flutter/material.dart';

import '../../data/configuration/source_configuration_service.dart';

/// Observes presentation preferences; never owns playback or source lifetimes.
class AppThemeController extends ChangeNotifier {
  AppThemeController({
    this._configuration,
    ThemeMode initialMode = ThemeMode.system,
    String initialLanguage = 'system',
  }) : _mode = initialMode,
       _language = initialLanguage;
  SourceConfigurationService? _configuration;
  bool _ownsConfiguration = false;
  ThemeMode _mode;
  String _language;
  String? _saveError;
  ThemeMode get mode => _mode;
  String get language => _language;
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
}
