import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlite3/sqlite3.dart';

/// One configured Torrent Search service instance (openplayx/torrent-search,
/// Settings → Sources & downloads → Torrent search). The URL never holds
/// credentials; the API token lives in secure storage only and is never
/// shared with the download service.
class TorrentSearchConfig {
  const TorrentSearchConfig({
    required this.id,
    required this.name,
    required this.url,
    this.enabled = true,
    this.allowInsecureHttp = false,
    this.defaultCategory = 'all',
  });
  final String id;
  final String name;
  final String url;
  final bool enabled;

  /// Explicit opt-in for plain HTTP on a LAN. TLS verification itself is
  /// never disabled.
  final bool allowInsecureHttp;

  /// Category key from the service's /v1/categories.
  final String defaultCategory;

  String get credentialKey => 'openplayx.torrent_search.$id.token';
  String get host => Uri.tryParse(url)?.host ?? '';

  TorrentSearchConfig copyWith({
    String? name,
    String? url,
    bool? enabled,
    bool? allowInsecureHttp,
    String? defaultCategory,
  }) => TorrentSearchConfig(
    id: id,
    name: name ?? this.name,
    url: url ?? this.url,
    enabled: enabled ?? this.enabled,
    allowInsecureHttp: allowInsecureHttp ?? this.allowInsecureHttp,
    defaultCategory: defaultCategory ?? this.defaultCategory,
  );
}

const torrentSearchCredentialStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);

/// Persists service instances in the instance configuration database.
class TorrentSearchRegistry {
  TorrentSearchRegistry({
    required this.db,
    this.credentials = torrentSearchCredentialStorage,
    this._readCredential,
  }) {
    db.execute('''CREATE TABLE IF NOT EXISTS torrent_search_services (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, url TEXT NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      allow_insecure_http INTEGER NOT NULL DEFAULT 0,
      default_category TEXT NOT NULL DEFAULT 'all',
      created INTEGER NOT NULL)''');
  }

  /// Shared by Settings and the assistant tools (both see the same rows).
  static TorrentSearchRegistry? current;

  /// The shared instance for [db]; replaced when the library database
  /// changes (a closed database is never reused).
  static TorrentSearchRegistry forDb(Database db) {
    final c = current;
    if (c != null && identical(c.db, db)) return c;
    return current = TorrentSearchRegistry(db: db);
  }

  final Database db;
  final FlutterSecureStorage credentials;
  final Future<String?> Function(String key)? _readCredential;

  Future<String?> credential(TorrentSearchConfig c) async {
    try {
      return await (_readCredential?.call(c.credentialKey) ??
          credentials.read(key: c.credentialKey));
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasToken(TorrentSearchConfig c) async =>
      (await credential(c))?.isNotEmpty ?? false;

  Future<void> setCredential(TorrentSearchConfig c, String token) =>
      credentials.write(key: c.credentialKey, value: token);

  static TorrentSearchConfig _row(Row r) => TorrentSearchConfig(
    id: r['id'] as String,
    name: r['name'] as String,
    url: r['url'] as String,
    enabled: r['enabled'] == 1,
    allowInsecureHttp: r['allow_insecure_http'] == 1,
    defaultCategory: r['default_category'] as String,
  );

  List<TorrentSearchConfig> list() => [
    for (final r in db.select(
      'SELECT * FROM torrent_search_services ORDER BY created, id',
    ))
      _row(r),
  ];

  List<TorrentSearchConfig> get enabled =>
      list().where((c) => c.enabled).toList();

  TorrentSearchConfig? get(String id) {
    final rows = db.select('SELECT * FROM torrent_search_services WHERE id=?', [
      id,
    ]);
    return rows.isEmpty ? null : _row(rows.first);
  }

  /// Validates and stores an instance: absolute https URL (http only with
  /// the explicit LAN opt-in), no credentials, query or fragment.
  TorrentSearchConfig save(TorrentSearchConfig c) {
    final uri = Uri.tryParse(c.url);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !(uri.scheme == 'https' ||
            (uri.scheme == 'http' && c.allowInsecureHttp))) {
      throw const FormatException('url');
    }
    if (uri.scheme == 'http' && !isLanHost(uri.host)) {
      throw const FormatException('url_http_public');
    }
    if (!RegExp(r'^[a-z][a-z0-9_.]{0,39}$').hasMatch(c.defaultCategory)) {
      throw const FormatException('category');
    }
    db.execute(
      '''INSERT INTO torrent_search_services (id,name,url,enabled,
         allow_insecure_http,default_category,created) VALUES (?,?,?,?,?,?,?)
         ON CONFLICT(id) DO UPDATE SET name=excluded.name,url=excluded.url,
         enabled=excluded.enabled,allow_insecure_http=excluded.allow_insecure_http,
         default_category=excluded.default_category''',
      [
        c.id,
        c.name.trim().isEmpty ? uri.host : c.name.trim(),
        c.url,
        c.enabled ? 1 : 0,
        c.allowInsecureHttp ? 1 : 0,
        c.defaultCategory,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
    return get(c.id)!;
  }

  Future<void> remove(String id) async {
    final c = get(id);
    if (c == null) return;
    db.execute('DELETE FROM torrent_search_services WHERE id=?', [id]);
    try {
      await credentials.delete(key: c.credentialKey);
    } catch (_) {}
  }

  /// Loopback, RFC 1918 / unique-local addresses and .local/.lan names.
  static bool isLanHost(String host) {
    final h = host.toLowerCase();
    if (h == 'localhost' || h.endsWith('.local') || h.endsWith('.lan')) {
      return true;
    }
    final v4 = RegExp(r'^(\d+)\.(\d+)\.\d+\.\d+$').firstMatch(h);
    if (v4 != null) {
      final a = int.parse(v4.group(1)!), b = int.parse(v4.group(2)!);
      return a == 10 ||
          a == 127 ||
          (a == 172 && b >= 16 && b <= 31) ||
          (a == 192 && b == 168);
    }
    return h.contains(':') &&
        (h == '::1' || h.startsWith('fd') || h.startsWith('fc'));
  }

  static String newId() {
    final r = Random.secure();
    return 'tsearch-${List.generate(10, (_) => r.nextInt(16).toRadixString(16)).join()}';
  }
}
