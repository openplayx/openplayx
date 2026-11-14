import 'dart:math';

import 'package:openplayx_whisper/openplayx_whisper.dart' show WhisperEngine;
import 'package:sqlite3/sqlite3.dart';

import '../../core/plugins/speech_recognition_capability.dart';
import '../../data/configuration/configuration_database.dart';
import 'asr_model_store.dart';
import 'embedded_whisper_backend.dart';
import 'http_asr_backend.dart';

/// One configured recognition backend instance (Settings → AI & models →
/// Speech recognition). The built-in on-device instance always exists.
class AsrBackendConfig {
  const AsrBackendConfig({
    required this.id,
    required this.kind,
    required this.name,
    this.url,
    required this.modelId,
    this.language = 'auto',
    this.allowInsecureHttp = false,
    this.uploadConsentAt,
  });
  final String id;

  /// `embedded` | `http`.
  final String kind;
  final String name;

  /// HTTP service base URL; never holds credentials.
  final String? url;
  final String modelId;

  /// `auto` or an ISO 639-1 code; the default for new recognitions.
  final String language;

  /// Explicit opt-in for plain HTTP on a LAN. TLS verification itself is
  /// never disabled.
  final bool allowInsecureHttp;

  /// When the user authorised uploading audio to this service.
  final DateTime? uploadConsentAt;

  bool get uploads => kind == 'http';

  /// Plugin implementing this instance (see the plugin catalog).
  /// All backends belong to the single speech recognition plugin.
  String get pluginId => 'asr.whisper';
  String get host => url == null ? '' : Uri.parse(url!).host;

  AsrBackendConfig copyWith({
    String? name,
    String? url,
    String? modelId,
    String? language,
    bool? allowInsecureHttp,
    DateTime? uploadConsentAt,
    bool clearConsent = false,
  }) => AsrBackendConfig(
    id: id,
    kind: kind,
    name: name ?? this.name,
    url: url ?? this.url,
    modelId: modelId ?? this.modelId,
    language: language ?? this.language,
    allowInsecureHttp: allowInsecureHttp ?? this.allowInsecureHttp,
    uploadConsentAt: clearConsent
        ? null
        : uploadConsentAt ?? this.uploadConsentAt,
  );
}

/// Persists backend instances, with their access token, as the
/// `asr / backends` settings document in configuration.sqlite3 and builds
/// their capability objects.
class AsrBackendRegistry {
  AsrBackendRegistry({
    required this.db,
    required this.models,
    this.embeddedEngine,
    this._readCredential,
  }) {
    ConfigurationDatabase.initialize(db);
    if (_documents().every((d) => d['id'] != 'embedded')) {
      _store([
        {
          'id': 'embedded',
          'kind': 'embedded',
          'name': 'On device',
          'model_id': 'whisper-base-multilingual',
          'language': 'auto',
          'allow_insecure_http': false,
          'created': DateTime.now().millisecondsSinceEpoch,
        },
        ..._documents(),
      ]);
    }
  }

  static const _namespace = 'asr';
  static const _key = 'backends';

  List<Map<String, dynamic>> _documents() {
    final value = ConfigurationDatabase.readSetting(db, _namespace, _key);
    return [
      if (value is List)
        for (final item in value)
          if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  void _store(List<Map<String, dynamic>> documents) =>
      ConfigurationDatabase.writeSetting(db, _namespace, _key, documents);

  final Database db;
  final AsrModelStore models;

  /// Overrides the shared engine (tests load a host-built library).
  final WhisperEngine? embeddedEngine;
  final Future<String?> Function(String key)? _readCredential;

  Future<String?> credential(AsrBackendConfig c) async {
    try {
      return await (_readCredential?.call(c.id) ?? Future.value(token(c.id)));
    } catch (_) {
      return null;
    }
  }

  static AsrBackendConfig _fromDocument(Map<String, dynamic> d) =>
      AsrBackendConfig(
        id: d['id'] as String,
        kind: d['kind'] as String,
        name: d['name'] as String,
        url: d['url'] as String?,
        modelId: d['model_id'] as String,
        language: d['language'] as String? ?? 'auto',
        allowInsecureHttp: d['allow_insecure_http'] == true,
        uploadConsentAt: d['upload_consent_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                d['upload_consent_at'] as int,
              ),
      );

  /// The on-device instance first, then in the order they were added.
  List<AsrBackendConfig> list() {
    final documents = _documents()
      ..sort((a, b) {
        final embedded =
            (b['kind'] == 'embedded' ? 1 : 0) -
            (a['kind'] == 'embedded' ? 1 : 0);
        return embedded != 0
            ? embedded
            : (a['created'] as int? ?? 0).compareTo(b['created'] as int? ?? 0);
      });
    return [for (final d in documents) _fromDocument(d)];
  }

  AsrBackendConfig? get(String id) =>
      list().where((c) => c.id == id).firstOrNull;

  /// Validates and stores an instance. A changed URL drops upload consent:
  /// consent names one destination.
  AsrBackendConfig save(AsrBackendConfig c) {
    if (c.kind == 'http') {
      final uri = Uri.tryParse(c.url ?? '');
      if (uri == null ||
          !uri.hasAuthority ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          !(uri.scheme == 'https' ||
              (uri.scheme == 'http' && c.allowInsecureHttp))) {
        throw const FormatException('url');
      }
    } else if (c.kind != 'embedded' || asrModelSpec(c.modelId) == null) {
      throw const FormatException('model');
    }
    if (c.language != 'auto' && !RegExp(r'^[a-z]{2,3}$').hasMatch(c.language)) {
      throw const FormatException('language');
    }
    final previous = get(c.id);
    final consent = previous != null && previous.url != c.url
        ? null
        : c.uploadConsentAt;
    final documents = _documents();
    final existing = documents.where((d) => d['id'] == c.id).firstOrNull;
    final document = {
      'id': c.id,
      'kind': c.kind,
      'name': c.name.trim().isEmpty ? c.host : c.name.trim(),
      'url': c.url,
      'model_id': c.modelId,
      'language': c.language,
      'allow_insecure_http': c.allowInsecureHttp,
      'upload_consent_at': consent?.millisecondsSinceEpoch,
      // Editing keeps the instance's place in the list and its token.
      'created': existing?['created'] ?? DateTime.now().millisecondsSinceEpoch,
      if (existing?['token'] != null) 'token': existing!['token'],
    };
    _store([
      for (final d in documents)
        if (d['id'] != c.id) d,
      document,
    ]);
    return get(c.id)!;
  }

  /// The access token saved on backend [id].
  String? token(String id) =>
      _documents().where((d) => d['id'] == id).firstOrNull?['token'] as String?;

  /// Saves [token] on backend [id]; empty removes it.
  void setToken(String id, String token) => _store([
    for (final d in _documents())
      d['id'] == id
          ? {
              for (final e in d.entries)
                if (e.key != 'token') e.key: e.value,
              if (token.trim().isNotEmpty) 'token': token.trim(),
            }
          : d,
  ]);

  void grantUploadConsent(String id) => _store([
    for (final d in _documents())
      d['id'] == id
          ? {...d, 'upload_consent_at': DateTime.now().millisecondsSinceEpoch}
          : d,
  ]);

  Future<void> remove(String id) async {
    final c = get(id);
    if (c == null || c.kind == 'embedded') return;
    _store([
      for (final d in _documents())
        if (d['id'] != id) d,
    ]);
  }

  static String newId() {
    final r = Random.secure();
    return 'asr-${List.generate(10, (_) => r.nextInt(16).toRadixString(16)).join()}';
  }

  /// The capability object for one configured instance.
  SpeechRecognitionModelCapability backend(String id) {
    final c = get(id);
    if (c == null) throw const AsrBackendException('backend_not_configured');
    return switch (c.kind) {
      'embedded' => EmbeddedWhisperBackend(
        store: models,
        engine: embeddedEngine,
        modelId: () => get(id)?.modelId ?? c.modelId,
        instanceId: id,
      ),
      _ => HttpAsrBackend(config: c, token: () => credential(get(id) ?? c)),
    };
  }
}
