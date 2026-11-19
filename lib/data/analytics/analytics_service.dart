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
  static Map<String, Object> sanitize(Map<String, Object> properties) => {
    for (final entry in properties.entries)
      if (values[entry.key]?.contains(entry.value) == true ||
          (entry.key == 'success' && entry.value is bool))
        entry.key: entry.value,
  };
  bool _ready = false;
  bool get enabled => _ready;
  bool get configured => token.isNotEmpty;
  String _version = 'unknown';
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
        ..sessionReplay = false
        ..surveys = false
        ..personProfiles = PostHogPersonProfiles.never
        ..preloadFeatureFlags = false
        ..sendFeatureFlagEvent = false
        ..capturePushNotificationOpened = false
        ..capturePushNotificationSubscriptions = false
        ..disableGeoIp = true
        ..maxQueueSize = 100
        ..debug = false;
      config.beforeSend = [
        (event) {
          if (!_ready || !events.contains(event.event)) return null;
          event.userProperties = null;
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
              'origin': 'app',
              'environment': environment,
              'schema_version': 1,
              'app_version': _version,
              'platform': Platform.operatingSystem,
            },
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      /* Never log event payloads or interrupt the caller. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(capture('app_session_started'));
    }
  }
}
