import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../data/configuration/configuration_database.dart';
import '../../data/configuration/source_configuration_service.dart';
import '../../data/metadata/metadata_repository.dart';
import '../../data/remote_access/remote_access_service.dart';
import '../../data/sources/source_config.dart';
import '../../data/sources/source_manager.dart';
import '../../services/conversations/assistant_store.dart';
import '../../services/external/external_service_registry.dart';
import '../../services/external/external_service_setup.dart';
import '../../services/metadata/tmdb_credentials.dart';
import '../../services/subtitles/asr_backend_config.dart';
import '../../services/subtitles/asr_model_store.dart';
import '../diagnostics/diagnostics_service.dart';

/// Outcome of one seed import, per item (`sources/nas-smb`, `metadata`, …).
class DebugSeedReport {
  final applied = <String>[];
  final failed = <String, String>{};
  bool skipped = false;

  @override
  String toString() => skipped
      ? 'unchanged since last import, skipped'
      : 'applied ${applied.length}: ${applied.join(', ')}'
            '${failed.isEmpty ? '' : '; failed ${failed.length}: ${failed.entries.map((e) => '${e.key} (${e.value})').join(', ')}'}';
}

/// Preloads configuration for testing from a resolved seed (a JSON template
/// whose `${VAR}` were filled from `.env` by `tool/debug_seed.dart`).
///
/// Never in release builds. The seed comes from
/// `--dart-define=OPENPLAYX_DEBUG_SEED=BASE64` (any platform, via
/// `flutter run`) or from
/// `debug-seed.json` in the App support directory (pushed into an installed
/// App). Everything lands in configuration.sqlite3 through the same stores
/// the settings pages use, before the UI starts. The same content is
/// imported once; items are upserted by their fixed ids.
abstract final class DebugSeed {
  static const defineKey = 'OPENPLAYX_DEBUG_SEED';
  static const fileName = 'debug-seed.json';
  static const _encoded = String.fromEnvironment(defineKey);

  static const _namespace = 'debug_seed';
  static const _appliedKey = 'appliedSha256';

  /// Called from main() before the UI starts; never throws.
  static Future<void> applyAtStartup() async {
    if (kReleaseMode) return;
    try {
      String? text;
      File? file;
      if (_encoded.isNotEmpty) {
        text = utf8.decode(base64.decode(_encoded));
      } else {
        final dir = await getApplicationSupportDirectory();
        final candidate = File('${dir.path}${Platform.pathSeparator}$fileName');
        if (await candidate.exists()) {
          file = candidate;
          text = await candidate.readAsString();
        }
      }
      if (text == null) return;
      final db = await ConfigurationDatabase.open();
      try {
        final report = await apply(db, text);
        debugPrint('[debug-seed] $report');
      } finally {
        db.close();
      }
      // Keep the pushed file for reference, out of the way of the next start.
      await file?.rename(
        '${file.parent.path}${Platform.pathSeparator}debug-seed.applied.json',
      );
    } catch (error) {
      debugPrint('[debug-seed] not imported: $error');
    }
  }

  /// Applies the resolved seed [text] to configuration database [db]. A seed
  /// identical to the last imported one is skipped unless [force].
  static Future<DebugSeedReport> apply(
    Database db,
    String text, {
    bool force = false,
  }) async {
    final report = DebugSeedReport();
    final hash = sha256.convert(utf8.encode(text)).toString();
    ConfigurationDatabase.initialize(db);
    if (!force &&
        ConfigurationDatabase.readSetting(db, _namespace, _appliedKey) ==
            hash) {
      return report..skipped = true;
    }
    final seed = jsonDecode(text);
    if (seed is! Map || seed['version'] != 1) {
      throw const FormatException('seed must be an object with "version": 1');
    }

    Future<void> item(String name, Future<void> Function() body) async {
      try {
        await body();
        report.applied.add(name);
      } catch (error) {
        report.failed[name] = '$error';
      }
    }

    List<Map<String, dynamic>> list(String key) => [
      for (final e in (seed[key] as List? ?? const []))
        Map<String, dynamic>.from(e as Map),
    ];

    final configuration = SourceConfigurationService(db);
    final sources = SourceManager(configuration: configuration);
    try {
      await sources.load();
      for (final s in list('sources')) {
        await item('sources/${s['id']}', () => _source(sources, s));
      }
      for (final f in list('fileSources')) {
        await item('fileSources/${f['id']}', () async => _fileSource(db, f));
      }
      if (seed['scanExtensions'] case final List extensions) {
        await item(
          'scanExtensions',
          () => sources.setScanExtensions([
            for (final e in extensions) '$e'.toLowerCase(),
          ]),
        );
      }
    } finally {
      await sources.dispose();
    }

    final external = ExternalServiceRegistry(db: db);
    for (final e in list('externalServices')) {
      await item('externalServices/${e['id']}', () => _external(external, e));
    }
    final asr = AsrBackendRegistry(
      db: db,
      models: AsrModelStore(Future.value(null)),
    );
    for (final a in list('asr')) {
      await item('asr/${a['id']}', () async => _asr(asr, a));
    }
    if (seed['assistant'] case final Map a) {
      await item('assistant', () async {
        AssistantStore.writeConfig(
          db,
          AssistantConfig(
            endpoint:
                a['endpoint'] as String? ?? AssistantConfig.exampleEndpoint,
            model: a['model'] as String? ?? AssistantConfig.exampleModel,
            cloudAllowed: a['cloudAllowed'] == true,
            toolsSupported: a['toolsSupported'] == true,
            maxTokens: a['maxTokens'] as int? ?? 2048,
          ),
          a['apiKey'] as String? ?? '',
        );
      });
    }
    if (seed['metadata'] case final Map m) {
      await item('metadata', () async {
        void set(String key, Object? value) =>
            ConfigurationDatabase.writeSetting(
              db,
              MetadataRepository.settingsNamespace,
              key,
              value,
            );
        if (m['language'] case final String language) set('language', language);
        if (m['tmdbToken'] case final String token) {
          set(tmdbTokenKey, token.trim());
          // Makes the metadata runtime rebuild its TMDB plugin.
          set('tmdbRevision', '${DateTime.now().microsecondsSinceEpoch}');
        }
      });
    }
    if (seed['remoteAccess'] case final Map r) {
      await item('remoteAccess', () async {
        final pairing = r['pairing'];
        await RemoteAccessService(db)
            .importPairing(pairing is String ? pairing : jsonEncode(pairing));
      });
    }
    if (seed['appearance'] case final Map a) {
      await item('appearance', () async {
        for (final key in ['themeMode', 'language', 'developerMode']) {
          if (a[key] != null) configuration.saveAppearance(key, '${a[key]}');
        }
      });
    }
    if (seed['diagnostics'] case final bool enabled) {
      await item('diagnostics', () async {
        ConfigurationDatabase.writeSetting(
          db,
          DiagnosticsService.namespace,
          DiagnosticsService.key,
          enabled,
        );
      });
    }
    ConfigurationDatabase.writeSetting(db, _namespace, _appliedKey, hash);
    return report;
  }

  static Future<void> _source(SourceManager sources, Map<String, dynamic> s) {
    final secret = s.remove('secret') as String? ?? '';
    final existing = sources.configs.where((c) => c.id == s['id']).firstOrNull;
    final config = SourceConfig.fromJson({
      ...s,
      'revision': existing?.revision ?? 0,
    });
    if (config.kind == SourceKind.local) {
      throw const FormatException(
        'local folders need the user to grant access; add them in the App',
      );
    }
    return sources.save(config, secret);
  }

  static void _fileSource(Database db, Map<String, dynamic> f) {
    final source = f['source'] as String;
    if (db.select('SELECT 1 FROM plugin_instance_configs WHERE instance_id=?', [
      source,
    ]).isEmpty) {
      throw FormatException('unknown source "$source"');
    }
    db.execute(
      '''INSERT INTO file_sources(id,source_id,root,name,enabled,created) VALUES (?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET source_id=excluded.source_id, root=excluded.root,
      name=excluded.name, enabled=excluded.enabled''',
      [
        f['id'] as String,
        source,
        f['root'] as String?,
        f['name'] as String?,
        f['enabled'] == false ? 0 : 1,
        DateTime.now().microsecondsSinceEpoch,
      ],
    );
  }

  /// Saved unchecked; the App re-checks every external service at start
  /// and fills in its endpoint and tools.
  static Future<void> _external(
    ExternalServiceRegistry registry,
    Map<String, dynamic> e,
  ) async {
    final base = ExternalServiceSetup.normalize(e['baseUrl'] as String);
    await registry.save(
      ExternalService(
        id: e['id'] as String,
        name: e['name'] as String? ?? base.host,
        baseUrl: base.toString(),
        endpoint: base.replace(path: '/mcp').toString(),
        serverName: '',
      ),
      token: e['token'] as String?,
    );
  }

  static void _asr(AsrBackendRegistry registry, Map<String, dynamic> a) {
    final id = a['id'] as String;
    final existing = registry.get(id);
    registry.save(
      AsrBackendConfig(
        id: id,
        kind: a['kind'] as String? ?? 'http',
        name: a['name'] as String? ?? '',
        url: a['url'] as String?,
        modelId: a['modelId'] as String? ?? existing?.modelId ?? '',
        language: a['language'] as String? ?? 'auto',
        allowInsecureHttp: a['allowInsecureHttp'] == true,
        uploadConsentAt: existing?.uploadConsentAt,
      ),
    );
    if (a['token'] case final String token) registry.setToken(id, token);
    if (a['uploadConsent'] == true) registry.grantUploadConsent(id);
  }
}
