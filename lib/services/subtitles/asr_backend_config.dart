import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:openplayx_whisper/openplayx_whisper.dart' show WhisperEngine;
import 'package:sqlite3/sqlite3.dart';

import '../../core/plugins/speech_recognition_capability.dart';
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
  String get pluginId => kind == 'http' ? 'asr.http' : 'asr.whisper';
  String get credentialKey => 'openplayx.asr.$id.token';
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

const asrCredentialStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);

/// Persists backend instances and builds their capability objects.
class AsrBackendRegistry {
  AsrBackendRegistry({
    required this.db,
    required this.models,
    this.embeddedEngine,
    this.credentials = asrCredentialStorage,
    this._readCredential,
  }) {
    db.execute('''CREATE TABLE IF NOT EXISTS asr_backends (
      id TEXT PRIMARY KEY, kind TEXT NOT NULL, name TEXT NOT NULL, url TEXT,
      model_id TEXT NOT NULL, language TEXT NOT NULL DEFAULT 'auto',
      allow_insecure_http INTEGER NOT NULL DEFAULT 0, upload_consent_at INTEGER,
      created INTEGER NOT NULL)''');
    if (db.select("SELECT 1 FROM asr_backends WHERE id='embedded'").isEmpty) {
      db.execute(
        "INSERT INTO asr_backends (id,kind,name,model_id,created) VALUES ('embedded','embedded','On device',?,?)",
        ['whisper-base-multilingual', DateTime.now().millisecondsSinceEpoch],
      );
    }
  }

  final Database db;
  final AsrModelStore models;

  /// Overrides the shared engine (tests load a host-built library).
  final WhisperEngine? embeddedEngine;
  final FlutterSecureStorage credentials;
  final Future<String?> Function(String key)? _readCredential;

  Future<String?> credential(AsrBackendConfig c) async {
    try {
      return await (_readCredential?.call(c.credentialKey) ??
          credentials.read(key: c.credentialKey));
    } catch (_) {
      return null;
    }
  }

  static AsrBackendConfig _row(Row r) => AsrBackendConfig(
    id: r['id'] as String,
    kind: r['kind'] as String,
    name: r['name'] as String,
    url: r['url'] as String?,
    modelId: r['model_id'] as String,
    language: r['language'] as String,
    allowInsecureHttp: r['allow_insecure_http'] == 1,
    uploadConsentAt: r['upload_consent_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r['upload_consent_at'] as int),
  );

  List<AsrBackendConfig> list() => [
    for (final r in db.select(
      "SELECT * FROM asr_backends ORDER BY kind='embedded' DESC, created",
    ))
      _row(r),
  ];

  AsrBackendConfig? get(String id) {
    final rows = db.select('SELECT * FROM asr_backends WHERE id=?', [id]);
    return rows.isEmpty ? null : _row(rows.first);
  }

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
    db.execute(
      '''INSERT INTO asr_backends (id,kind,name,url,model_id,language,
         allow_insecure_http,upload_consent_at,created) VALUES (?,?,?,?,?,?,?,?,?)
         ON CONFLICT(id) DO UPDATE SET name=excluded.name,url=excluded.url,
         model_id=excluded.model_id,language=excluded.language,
         allow_insecure_http=excluded.allow_insecure_http,
         upload_consent_at=excluded.upload_consent_at''',
      [
        c.id,
        c.kind,
        c.name.trim().isEmpty ? c.host : c.name.trim(),
        c.url,
        c.modelId,
        c.language,
        c.allowInsecureHttp ? 1 : 0,
        consent?.millisecondsSinceEpoch,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
    return get(c.id)!;
  }

  void grantUploadConsent(String id) => db.execute(
    'UPDATE asr_backends SET upload_consent_at=? WHERE id=?',
    [DateTime.now().millisecondsSinceEpoch, id],
  );

  Future<void> remove(String id) async {
    final c = get(id);
    if (c == null || c.kind == 'embedded') return;
    db.execute('DELETE FROM asr_backends WHERE id=?', [id]);
    try {
      await credentials.delete(key: c.credentialKey);
    } catch (_) {}
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
