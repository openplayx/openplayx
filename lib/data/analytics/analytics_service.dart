import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../configuration/configuration_database.dart';

/// Only the main engine owns the SDK. Other engines forward bounded events.
class AnalyticsService with WidgetsBindingObserver {
  AnalyticsService._();
  static final instance = AnalyticsService._();
  static const token = String.fromEnvironment(
    'POSTHOG_PROJECT_TOKEN',
    defaultValue: kReleaseMode
        ? 'phc_zduHr5ANVHceCeoTiMsp5EfWcFEjeDtTMhzDEvjrpCNc'
        : '',
  );
  static const host = String.fromEnvironment(
    'POSTHOG_INGEST_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );
  static const environment = String.fromEnvironment(
    'ANALYTICS_ENVIRONMENT',
    defaultValue: kReleaseMode ? 'production' : 'development',
  );
  static const events = {
    'app_first_observed',
    'app_session_started',
    'app_usage',
    'screen_usage',
    'ui_interaction',
    'playback_progress',
    'playback_finished',
    r'$screen',
    r'$exception',
    'source_connection_completed',
    'library_scan_completed',
    'playback_requested',
    'playback_started',
    'playback_failed',
    'ai_task_completed',
    'subtitle_generation_completed',
  };
  static const values = <String, Set<String>>{
    'source_type': {
      'local',
      'smb',
      'webdav',
      'ftp',
      'sftp',
      's3',
      'plex',
      'jellyfin',
      'emby',
      'dlna',
      'onedrive',
      'dropbox',
      'baidu',
      'unknown',
    },
    'status': {'success', 'failed', 'cancelled'},
    'backend': {'local', 'http', 'unknown'},
    'task_type': {'agent', 'subtitle'},
    'error_category': {
      'network',
      'authentication',
      'timeout',
      'playback',
      'unknown',
    },
  };
  static const numericKeys = {
    'duration_ms',
    'startup_ms',
    'playing_ms',
    'buffering_ms',
    'buffering_count',
    'position_ms',
    'media_duration_ms',
    'progress_percent',
    'screen_width',
    'screen_height',
    'viewport_width',
    'viewport_height',
    'x',
    'y',
    'timezone_offset_minutes',
    'item_count',
  };
  static const labelKeys = {
    'screen_name',
    r'$screen_name',
    'playback_id',
    'engine_role',
    'error_type',
    'locale',
  };
  static bool _safeValue(String key, Object value) =>
      values[key]?.contains(value) == true ||
      ({'success', 'completed'}.contains(key) && value is bool) ||
      (numericKeys.contains(key) &&
          value is num &&
          value.isFinite &&
          value.abs() <= 2592000000) ||
      (labelKeys.contains(key) &&
          value is String &&
          RegExp(r'^[a-zA-Z0-9_.:-]{1,100}$').hasMatch(value));
  static Map<String, Object> sanitize(Map<String, Object> properties) => {
    for (final entry in properties.entries)
      if (_safeValue(entry.key, entry.value)) entry.key: entry.value,
  };
  bool _ready = false;
  bool get enabled => _ready;
  bool get configured => token.isNotEmpty;
  String _version = 'unknown';
  final _foreground = Stopwatch();
  final _screenTime = Stopwatch();
  String _screen = 'home';
  String tabScreen = 'home';
  DateTime? _backgroundAt;
  Timer? _usageTimer;
  bool get ownsSdk => _ready && _forward == null;

  Map<String, Object> get _context {
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    return {
      'origin': 'app',
      'environment': environment,
      'schema_version': 2,
      'app_version': _version,
      'platform': Platform.operatingSystem,
      'locale': WidgetsBinding.instance.platformDispatcher.locale
          .toLanguageTag(),
      'timezone_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
      if (view != null) ...{
        'screen_width': view.display.size.width / view.display.devicePixelRatio,
        'screen_height':
            view.display.size.height / view.display.devicePixelRatio,
        'viewport_width': view.physicalSize.width / view.devicePixelRatio,
        'viewport_height': view.physicalSize.height / view.devicePixelRatio,
      },
    };
  }

  Future<void> _flushUsage() async {
    final sends = <Future<void>>[];
    if (_foreground.isRunning && _foreground.elapsedMilliseconds > 0) {
      sends.add(
        capture('app_usage', {'duration_ms': _foreground.elapsedMilliseconds}),
      );
      _foreground.reset();
    }
    if (_screenTime.isRunning && _screenTime.elapsedMilliseconds > 0) {
      sends.add(
        capture('screen_usage', {
          'screen_name': _screen,
          'duration_ms': _screenTime.elapsedMilliseconds,
        }),
      );
      _screenTime.reset();
    }
    await Future.wait(sends);
  }

  Future<void> screen(String name) async {
    if (!_safeValue('screen_name', name) ||
        name == _screen && _screenTime.isRunning) {
      return;
    }
    unawaited(_flushUsage());
    _screen = name;
    if (_foreground.isRunning) _screenTime.start();
    await capture(r'$screen', {r'$screen_name': name});
  }

  void interaction(Offset position) {
    unawaited(
      capture('ui_interaction', {
        'screen_name': _screen,
        'x': position.dx,
        'y': position.dy,
      }),
    );
  }

  Future<void>? _initialization;
  Future<void> Function(String, Map<String, Object>)? _forward;

  void forwardTo(Future<void> Function(String, Map<String, Object>) callback) {
    _forward = callback;
  }

  /// Configured builds start analytics automatically; there is no user setting.
  Future<void> load() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (!configured) return;
    try {
      _version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // Version metadata is optional and must not prevent initialization.
    }
    try {
      final config = PostHogConfig(token)
        ..host = host
        ..captureApplicationLifecycleEvents = false
        ..sessionReplay = true
        ..surveys = false
        ..personProfiles = PostHogPersonProfiles.always
        ..preloadFeatureFlags = false
        ..sendFeatureFlagEvent = false
        ..capturePushNotificationOpened = false
        ..capturePushNotificationSubscriptions = false
        ..disableGeoIp = false
        ..maxQueueSize = 100
        ..debug = false;
      config.sessionReplayConfig
        ..maskAllTexts = true
        ..maskAllImages = true
        ..maskAllPlatformViews = true
        ..maskCustomPaint = true
        ..sampleRate = 1;
      config.beforeSend = [
        (event) {
          if (!_ready || !events.contains(event.event)) return null;
          event.properties = {...?event.properties, ..._context};
          event.userProperties = {
            'app_version': _version,
            'platform': Platform.operatingSystem,
          };
          event.userPropertiesSetOnce = null;
          return event;
        },
      ];
      await Posthog().setup(config).timeout(const Duration(seconds: 4));
      // Clear any SDK opt-out persisted by earlier builds. The obsolete
      // analytics/enabled preference no longer controls collection.
      await Posthog().optIn();
      _ready = true;
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // Local playback never depends on analytics initialization.
      return;
    }
    await _captureFirstObserved();
    await capture('app_session_started');
    _foreground.start();
    _screenTime.start();
    await capture(r'$screen', {r'$screen_name': _screen});
    _usageTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _flushUsage(),
    );
  }

  Future<void> _captureFirstObserved() async {
    try {
      final db = await ConfigurationDatabase.open();
      try {
        if (ConfigurationDatabase.readSetting(
              db,
              'analytics',
              'observed:$environment',
            ) !=
            true) {
          await capture('app_first_observed');
          ConfigurationDatabase.writeSetting(
            db,
            'analytics',
            'observed:$environment',
            true,
          );
        }
      } finally {
        db.close();
      }
    } catch (_) {
      // A local marker failure must not stop session or business events.
    }
  }

  Future<void> close() async {
    await _flushUsage();
    _foreground.stop();
    _screenTime.stop();
    _usageTimer?.cancel();
    _usageTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    if (_ready) await Posthog().flush();
    _ready = false;
    _initialization = null;
  }

  Future<void> capture(
    String event, [
    Map<String, Object> properties = const {},
  ]) async {
    if (!events.contains(event)) return;
    try {
      final safe = sanitize(properties);
      if (_forward != null) {
        await _forward!(event, safe).timeout(const Duration(seconds: 1));
        return;
      }
      if (!_ready) return;
      await Posthog()
          .capture(
            eventName: event,
            properties: {
              ...safe,
              if (event == r'$exception')
                r'$exception_list': [
                  {
                    'type': safe['error_type'] ?? 'Exception',
                    'value': safe['error_type'] ?? 'Exception',
                    'mechanism': {'type': 'generic', 'handled': true},
                  },
                ],
              ..._context,
            },
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      /* Never log event payloads or interrupt the caller. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready) return;
    if (state == AppLifecycleState.resumed) {
      if (_backgroundAt != null &&
          DateTime.now().difference(_backgroundAt!) >=
              const Duration(minutes: 30)) {
        unawaited(capture('app_session_started'));
      }
      _backgroundAt = null;
      _foreground.start();
      _screenTime.start();
      _usageTimer ??= Timer.periodic(
        const Duration(minutes: 1),
        (_) => _flushUsage(),
      );
    } else if ({
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    }.contains(state)) {
      unawaited(_flushUsage());
      _foreground.stop();
      _screenTime.stop();
      _backgroundAt ??= DateTime.now();
      _usageTimer?.cancel();
      _usageTimer = null;
      unawaited(Posthog().flush());
    }
  }
}
