import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/plugins/plugin_gate.dart';

/// One configured OpenPlayX BitTorrent API server (bittorrent-server).
/// Downloads run on that server; finishing there is not the same as being in
/// the App library or offline on this device.
class TorrentServiceConfig {
  const TorrentServiceConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.defaultDestination = 'default',
    this.allowDeleteFiles = false,
    this.pollSeconds = 10,
    this.enabled = true,
  });

  /// Host-issued server_ref; never the URL.
  final String id;
  final String name;
  final String baseUrl;
  final String defaultDestination;

  /// Access scope: whether the assistant may even propose deleting data.
  final bool allowDeleteFiles;

  /// Query policy: minimum seconds between list refreshes (UI polling and
  /// assistant queries share a cache).
  final int pollSeconds;
  final bool enabled;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'base_url': baseUrl,
    'default_destination': defaultDestination,
    'allow_delete_files': allowDeleteFiles,
    'poll_seconds': pollSeconds,
    'enabled': enabled,
  };

  factory TorrentServiceConfig.fromJson(Map<String, dynamic> j) =>
      TorrentServiceConfig(
        id: j['id'] as String,
        name: j['name'] as String,
        baseUrl: j['base_url'] as String,
        defaultDestination: j['default_destination'] as String? ?? 'default',
        allowDeleteFiles: j['allow_delete_files'] as bool? ?? false,
        pollSeconds: (j['poll_seconds'] as int? ?? 10).clamp(5, 300),
        enabled: j['enabled'] as bool? ?? true,
      );

  TorrentServiceConfig copyWith({
    String? name,
    String? baseUrl,
    String? defaultDestination,
    bool? allowDeleteFiles,
    int? pollSeconds,
    bool? enabled,
  }) => TorrentServiceConfig(
    id: id,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    defaultDestination: defaultDestination ?? this.defaultDestination,
    allowDeleteFiles: allowDeleteFiles ?? this.allowDeleteFiles,
    pollSeconds: pollSeconds ?? this.pollSeconds,
    enabled: enabled ?? this.enabled,
  );

  /// HTTPS anywhere; plain HTTP only to loopback/private LAN addresses.
  static String? validateUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return '请输入服务根地址，例如 https://bt.example.com';
    }
    if (uri.scheme == 'https') return null;
    if (uri.scheme == 'http' && isPrivateHost(uri.host)) return null;
    return '公网地址必须使用 HTTPS；HTTP 仅允许局域网或本机地址';
  }

  static bool isPrivateHost(String host) {
    if (host == 'localhost') return true;
    final ip = InternetAddress.tryParse(host);
    if (ip == null) return false;
    if (ip.isLoopback || ip.isLinkLocal) return true;
    final b = ip.rawAddress;
    if (ip.type == InternetAddressType.IPv4) {
      return b[0] == 10 ||
          (b[0] == 172 && b[1] >= 16 && b[1] < 32) ||
          (b[0] == 192 && b[1] == 168) ||
          (b[0] == 100 && b[1] >= 64 && b[1] < 128);
    }
    return (b[0] & 0xfe) == 0xfc; // fc00::/7
  }
}

/// Non-secret settings live in SharedPreferences; API tokens only in the
/// platform secure storage.
class TorrentServiceStore {
  TorrentServiceStore({FlutterSecureStorage? secure})
    : _secure =
          secure ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  /// Shared instance for settings pages and the assistant.
  static TorrentServiceStore? current;

  static const _key = 'openplayx.torrent.services.v1';
  final FlutterSecureStorage _secure;
  final _clients = <String, TorrentServiceClient>{};
  List<TorrentServiceConfig> configs = [];
  bool loaded = false;
  final changes = StreamController<void>.broadcast();

  String _tokenKey(String id) => 'openplayx.torrent.$id.token';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    configs = raw == null
        ? []
        : [
            for (final item in jsonDecode(raw) as List)
              TorrentServiceConfig.fromJson(Map<String, dynamic>.from(item)),
          ];
    loaded = true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final c in configs) c.toJson()]),
    );
    changes.add(null);
  }

  static String newId() =>
      'bt-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  /// Saves a config; [token] null keeps the stored one.
  Future<void> save(TorrentServiceConfig config, {String? token}) async {
    final error = TorrentServiceConfig.validateUrl(config.baseUrl);
    if (error != null) throw FormatException(error);
    if (token != null) {
      await _secure.write(key: _tokenKey(config.id), value: token.trim());
    }
    configs = [
      for (final c in configs)
        if (c.id != config.id) c,
      config,
    ];
    _clients.remove(config.id)?.close();
    await _persist();
  }

  /// Removing the configuration keeps remote downloads running; only the
  /// App's link and token are forgotten.
  Future<void> delete(String id) async {
    configs = configs.where((c) => c.id != id).toList();
    _clients.remove(id)?.close();
    await _secure.delete(key: _tokenKey(id));
    await _persist();
  }

  Future<bool> hasToken(String id) async =>
      (await _secure.read(key: _tokenKey(id)))?.isNotEmpty ?? false;

  TorrentServiceConfig? config(String id) =>
      configs.where((c) => c.id == id).firstOrNull;

  /// Instances accepting new calls: instance switch and plugin switch.
  List<TorrentServiceConfig> get enabled => PluginGate.enabled(pluginId)
      ? configs.where((c) => c.enabled).toList()
      : const [];

  static const pluginId = 'torrent.download';

  Future<TorrentServiceClient> client(String id) async {
    final existing = _clients[id];
    if (existing != null) return existing;
    final c = config(id);
    if (c == null || !c.enabled || !PluginGate.enabled(pluginId)) {
      throw const TorrentServiceException('serviceNotConfigured');
    }
    final token = await _secure.read(key: _tokenKey(id));
    if (token == null || token.isEmpty) {
      throw const TorrentServiceException('tokenMissing');
    }
    return _clients[id] = TorrentServiceClient(Uri.parse(c.baseUrl), token);
  }
}

class TorrentServiceException implements Exception {
  const TorrentServiceException(
    this.code, {
    this.status,
    this.retryable = false,
    this.detail,
  });
  final String code;
  final int? status;
  final bool retryable;
  final Map<String, dynamic>? detail;
  @override
  String toString() => 'TorrentServiceException($code)';
}

/// Restricted HTTP client for one bittorrent-server. It only talks to the
/// configured base URL, never follows redirects, caps response sizes and
/// throttles list queries so neither UI polling nor the model can hammer it.
class TorrentServiceClient {
  TorrentServiceClient(
    this.base,
    this._token, {
    HttpClient? http,
    this.timeout = const Duration(seconds: 15),
  }) : _http = http ?? HttpClient() {
    _http.connectionTimeout = const Duration(seconds: 10);
  }

  final Uri base;
  final String _token;
  final HttpClient _http;
  final Duration timeout;
  static const _maxBody = 4 << 20;

  void close() => _http.close(force: true);

  Uri _uri(String path, [Map<String, String>? query]) => base.replace(
    path: '${base.path.replaceAll(RegExp(r'/$'), '')}$path',
    queryParameters: query == null || query.isEmpty ? null : query,
  );

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? json,
    Uint8List? torrent,
    Map<String, String>? query,
  }) async {
    try {
      final req = await _http
          .openUrl(method, _uri(path, query))
          .timeout(timeout);
      req.followRedirects = false;
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (json != null) {
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(jsonEncode(json)));
      } else if (torrent != null) {
        req.headers.contentType = ContentType('application', 'x-bittorrent');
        req.add(torrent);
      }
      final res = await req.close().timeout(timeout);
      final bytes = <int>[];
      await for (final chunk in res.timeout(timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > _maxBody) {
          throw const TorrentServiceException('responseTooLarge');
        }
      }
      Map<String, dynamic> body = const {};
      if (bytes.isNotEmpty) {
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is Map<String, dynamic>) body = decoded;
      }
      if (res.statusCode >= 300) {
        final err = body['error'];
        if (err is Map) {
          throw TorrentServiceException(
            err['code'] as String? ?? 'serviceError',
            status: res.statusCode,
            retryable: err['retryable'] == true,
            detail: err['detail'] is Map
                ? Map<String, dynamic>.from(err['detail'] as Map)
                : null,
          );
        }
        throw TorrentServiceException(
          res.statusCode == 401 ? 'unauthorized' : 'serviceError',
          status: res.statusCode,
          retryable: res.statusCode >= 500,
        );
      }
      return body;
    } on TorrentServiceException {
      rethrow;
    } on TimeoutException {
      throw const TorrentServiceException('serviceTimeout', retryable: true);
    } on SocketException {
      throw const TorrentServiceException(
        'serviceUnreachable',
        retryable: true,
      );
    } on HandshakeException {
      throw const TorrentServiceException('tlsFailed');
    } on HttpException {
      throw const TorrentServiceException(
        'serviceUnreachable',
        retryable: true,
      );
    } on FormatException {
      throw const TorrentServiceException('invalidResponse');
    }
  }

  // Every call goes to the server, which reads the engine live; nothing is
  // cached here.

  Future<Map<String, dynamic>> capabilities() =>
      _send('GET', '/api/v1/capabilities');
  Future<Map<String, dynamic>> destinations() =>
      _send('GET', '/api/v1/destinations');

  Future<Map<String, dynamic>> uploadTorrent(Uint8List data) =>
      _send('POST', '/api/v1/torrent-inputs', torrent: data);

  Future<Map<String, dynamic>> plan(Map<String, dynamic> request) =>
      _send('POST', '/api/v1/torrent-plans', json: request);

  /// Adds the planned torrent; returns the task (also when it already
  /// existed in the engine).
  Future<Map<String, dynamic>> create(String planRef) =>
      _send('POST', '/api/v1/torrents', json: {'plan_ref': planRef});

  /// Every torrent in the engine, including ones added in the WebUI.
  Future<Map<String, dynamic>> list() => _send('GET', '/api/v1/torrents');

  Future<Map<String, dynamic>> task(String id) =>
      _send('GET', '/api/v1/torrents/$id');
  Future<Map<String, dynamic>> files(String id) =>
      _send('GET', '/api/v1/torrents/$id/files');

  Future<Map<String, dynamic>> select(
    String id,
    String revision, {
    String? preset,
    List<String>? fileIds,
  }) => _send(
    'PATCH',
    '/api/v1/torrents/$id/selection',
    json: {
      'expected_revision': revision,
      'preset': ?preset,
      'file_ids': ?fileIds,
    },
  );

  Future<Map<String, dynamic>> pause(String id) =>
      _send('POST', '/api/v1/torrents/$id/pause');
  Future<Map<String, dynamic>> resume(String id) =>
      _send('POST', '/api/v1/torrents/$id/resume');

  Future<Map<String, dynamic>> limits(String id, int download, int upload) =>
      _send(
        'PATCH',
        '/api/v1/torrents/$id/limits',
        json: {'download_limit': download, 'upload_limit': upload},
      );

  Future<Map<String, dynamic>> removePlan(String id, bool deleteFiles) => _send(
    'POST',
    '/api/v1/torrents/$id/remove-plan',
    json: {'delete_files': deleteFiles},
  );

  Future<Map<String, dynamic>> remove(String id, String planRef) =>
      _send('POST', '/api/v1/torrents/$id/remove', json: {'plan_ref': planRef});
}
