import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../configuration/configuration_database.dart';

import 'package:sqlite3/sqlite3.dart';

import '../../l10n/l10n.dart';
import 'remote_config.dart';
import 'discovered_source.dart';

class RelayApiException implements Exception {
  const RelayApiException(this.code, this.status);
  final String code;
  final int status;
  @override
  String toString() => appStrings.remotePlatformRequestFailed(code);
}

/// Only the fixed first-party API receives account credentials. Redirects are
/// never followed. Serial requests prevent concurrent refresh-token reuse.
class RelaySubscription {
  RelaySubscription(this.db, {http.Client? client})
    : _client = client ?? http.Client();
  final Database db;
  final http.Client _client;
  Map<String, dynamic>? _session;
  Future<void> _tail = Future.value();
  static final _origin = Uri.parse('https://api.openplayx.com');
  String? get userId => _session?['userId'] as String?;
  String? get email => _session?['email'] as String?;
  bool get signedIn => _session != null;
  void load() {
    final saved = ConfigurationDatabase.readSetting(
      db,
      'relay_account',
      'session',
    );
    if (saved is Map &&
        saved['accessToken'] is String &&
        saved['refreshToken'] is String) {
      _session = Map<String, dynamic>.from(saved);
    }
  }

  void _save() => ConfigurationDatabase.writeSetting(
    db,
    'relay_account',
    'session',
    _session,
  );
  Future<T> _serial<T>(Future<T> Function() run) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    await previous;
    try {
      return await run();
    } finally {
      done.complete();
    }
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? token,
    Map<String, String>? headers,
  }) async {
    final request = http.Request(method, _origin.resolve(path))
      ..followRedirects = false;
    request.headers['Accept'] = 'application/json';
    if (headers != null) request.headers.addAll(headers);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 20));
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 20),
    )) {
      bytes.addAll(chunk);
      if (bytes.length > 1024 * 1024) {
        throw const FormatException('Relay response too large');
      }
    }
    final Object? data;
    try {
      data = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw RelayApiException('invalid_response', response.statusCode);
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data is! Map<String, dynamic>) {
      final error = data is Map ? data['error'] : null;
      final code = error is Map && error['code'] is String
          ? error['code'] as String
          : 'request_failed';
      throw RelayApiException(
        RegExp(r'^[a-z0-9_]{1,80}$').hasMatch(code) ? code : 'request_failed',
        response.statusCode,
      );
    }
    return data;
  }

  Future<void> requestRegistration(String email) => _serial(() async {
    await _request(
      '/v1/auth/registration/request',
      method: 'POST',
      body: {'email': email.trim()},
    );
  });

  /// Proves the email with the emailed 6-digit code and sets the password.
  /// The account still needs a separate sign-in afterwards.
  Future<void> completeRegistration(
    String email,
    String code,
    String password,
  ) => _serial(() async {
    await _request(
      '/v1/auth/registration/complete',
      method: 'POST',
      body: {'email': email.trim(), 'code': code.trim(), 'password': password},
    );
  });

  Future<void> login(String email, String password) => _serial(() async {
    // Keep the previous session until a new login succeeds.
    final tokens = await _request(
      '/v1/auth/login',
      method: 'POST',
      body: {'email': email.trim(), 'password': password, 'clientType': 'app'},
    );
    _session = {
      ...tokens,
      'email': email.trim(),
      'expiresAt': DateTime.now()
          .add(Duration(seconds: tokens['expiresIn'] as int))
          .toIso8601String(),
    };
    _save();
  });
  Future<Map<String, dynamic>> _authenticated(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    if (_session == null) throw const RelayApiException('login_required', 401);
    if (DateTime.tryParse(_session!['expiresAt'] as String? ?? '')
            ?.isAfter(DateTime.now().add(const Duration(seconds: 30))) !=
        true) {
      try {
        final tokens = await _request(
          '/v1/auth/refresh',
          method: 'POST',
          body: {'refreshToken': _session!['refreshToken']},
        );
        _session = {
          ...tokens,
          'email': email,
          if (userId != null) 'userId': userId,
          'expiresAt': DateTime.now()
              .add(Duration(seconds: tokens['expiresIn'] as int))
              .toIso8601String(),
        };
        _save();
      } on RelayApiException catch (e) {
        if (e.status == 401) {
          _session = null;
          _save();
        }
        rethrow;
      }
    }
    return _request(
      path,
      method: method,
      body: body,
      headers: headers,
      token: _session!['accessToken'] as String,
    );
  }

  Future<RelayDeviceProfile> fetchProfile() => _serial(() async {
    try {
      Map<String, dynamic> data;
      try {
        data = await _authenticated('/v1/relay/device/config');
      } on RelayApiException catch (e) {
        if (e.code != 'device_session_required') rethrow;
        try {
          await _authenticated(
            '/v1/relay/me/devices',
            method: 'POST',
            body: {
              'name': 'OpenPlayX ${Platform.operatingSystem}',
              'platform': Platform.operatingSystem,
              'installId': installId,
            },
          );
        } on RelayApiException catch (e) {
          if (e.code != 'session_already_bound') rethrow;
        }
        data = await _authenticated('/v1/relay/device/config');
      }
      final profile = RelayDeviceProfile.parse(data);
      if (userId != null && userId != profile.userId) {
        throw const FormatException('Relay account mismatch');
      }
      _session!['userId'] = profile.userId;
      _save();
      return profile;
    } on RelayApiException catch (e) {
      if (e.status == 401 ||
          e.code == 'account_inactive' ||
          e.code == 'relay_device_revoked') {
        _session = null;
        _save();
      }
      rethrow;
    }
  });

  /// A random ID for this App install, kept across sign-ins, so signing in
  /// again replaces this install's device instead of taking another slot.
  String get installId {
    final saved = ConfigurationDatabase.readSetting(
      db,
      'relay_account',
      'install_id',
    );
    if (saved is String && RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(saved)) {
      return saved;
    }
    final random = Random.secure();
    final id = [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    ConfigurationDatabase.writeSetting(db, 'relay_account', 'install_id', id);
    return id;
  }

  /// The account's enabled devices, for freeing a slot on device_limit.
  Future<RelayDeviceList> listDevices() => _serial(() async {
    final devices = <RelayDevice>[];
    String? cursor;
    late String revision;
    for (var page = 0; page < 20; page++) {
      final data = await _authenticated(
        '/v1/relay/me/devices?limit=100'
        '${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}',
      );
      revision = data['revision'] as String;
      for (final item in (data['items'] as List).whereType<Map>()) {
        if (item['status'] == 'enabled') devices.add(RelayDevice.parse(item));
      }
      cursor = data['nextCursor'] as String?;
      if (cursor == null) break;
    }
    return RelayDeviceList(devices, revision);
  });

  Future<void> removeDevice(String deviceId, String revision) =>
      _serial(() async {
        await _authenticated(
          '/v1/relay/me/devices/${Uri.encodeComponent(deviceId)}',
          method: 'DELETE',
          headers: {'If-Match': '"$revision"'},
        );
      });

  Future<void> logout() => _serial(() async {
    try {
      if (_session != null) {
        await _authenticated('/v1/auth/logout', method: 'POST', body: {});
      }
    } finally {
      _session = null;
      _save();
    }
  });
  void close() => _client.close();
}

class RelayDevice {
  const RelayDevice(this.id, this.name, this.platform, this.createdAt);
  factory RelayDevice.parse(Map item) => RelayDevice(
    item['deviceId'] as String,
    item['name'] as String,
    item['platform'] as String? ?? 'other',
    DateTime.tryParse(item['createdAt'] as String? ?? ''),
  );
  final String id;
  final String name;
  final String platform;
  final DateTime? createdAt;
}

class RelayDeviceList {
  const RelayDeviceList(this.devices, this.revision);
  final List<RelayDevice> devices;
  final String revision;
}

class RelayDeviceProfile {
  RelayDeviceProfile._(
    this.data,
    this.validUntil,
    this.revision,
    this.nodes,
    this.proxies,
    this.uuid,
  );
  final Map<String, dynamic> data;
  final DateTime validUntil;
  final BigInt revision;
  final List<Map<String, dynamic>> nodes;
  final List<RemoteProxy> proxies;
  final String uuid;
  bool get valid => validUntil.isAfter(DateTime.now());
  String get userId => data['userId'] as String;
  String get deviceId => data['deviceId'] as String;
  List<DiscoveredSource> get sources => DiscoveredSource.parseCatalog(data);

  /// The Relay node the owning Connector reported (serviceStatus.readyNodeIds).
  /// Connectors choose their node; devices follow it. With services on several
  /// nodes the one carrying the most services wins (ties: node order). Null
  /// while no Connector has reported a node that is still listed.
  String? get activeNodeId {
    final status = data['serviceStatus'];
    if (status is! List) return null;
    final counts = <String, int>{
      for (final n in nodes) n['nodeId'] as String: 0,
    };
    for (final entry in status) {
      final ids = entry is Map ? entry['readyNodeIds'] : null;
      if (ids is! List) continue;
      for (final id in ids.toSet()) {
        if (id is String && counts.containsKey(id)) {
          counts[id] = counts[id]! + 1;
        }
      }
    }
    String? best;
    counts.forEach((id, count) {
      if (count > 0 && (best == null || count > counts[best]!)) best = id;
    });
    return best;
  }

  factory RelayDeviceProfile.parse(Map<String, dynamic> data) {
    final expiry = DateTime.tryParse(data['validUntil'] as String? ?? '');
    final revision = BigInt.tryParse(data['revision'] as String? ?? '');
    if (data['schemaVersion'] != 1 ||
        expiry == null ||
        expiry.isAfter(DateTime.now().add(const Duration(minutes: 31))) ||
        revision == null ||
        revision < BigInt.zero ||
        data['userId'] is! String ||
        data['deviceId'] is! String ||
        data['nodes'] is! List ||
        data['services'] is! List) {
      throw const FormatException('Invalid Relay profile');
    }
    // Validate the entire directory before replacing a previously good snapshot.
    // Older servers may omit descriptive service fields.
    if (data['sourceCatalog'] != null) DiscoveredSource.parseCatalog(data);
    final credential = data['credential'];
    if (credential is! Map ||
        credential['type'] != 'vless' ||
        credential['uuid'] is! String) {
      throw const FormatException('Invalid Relay credential');
    }
    final uuid = credential['uuid'] as String;
    final nodes = <Map<String, dynamic>>[];
    for (final n in data['nodes'] as List) {
      if (n is! Map<String, dynamic> ||
          n['status'] != 'enabled' ||
          n['nodeId'] is! String ||
          n['name'] is! String ||
          n['sortOrder'] is! int) {
        throw const FormatException('Invalid Relay node');
      }
      RemotePairing.validateOutbound({
        'type': 'vless',
        'server': n['host'],
        'server_port': n['port'],
        'uuid': uuid,
        'tls': {'enabled': true, 'server_name': n['tlsServerName']},
      });
      nodes.add(n);
    }
    // Validate the UUID even when the platform currently has no ready nodes.
    RemotePairing.validateOutbound({
      'type': 'vless',
      'server': 'relay.invalid',
      'server_port': 443,
      'uuid': uuid,
      'tls': {'enabled': true, 'server_name': 'relay.invalid'},
    });
    nodes.sort((a, b) {
      final order = (a['sortOrder'] as int).compareTo(b['sortOrder'] as int);
      return order == 0
          ? (a['nodeId'] as String).compareTo(b['nodeId'] as String)
          : order;
    });
    if (nodes.map((n) => n['nodeId']).toSet().length != nodes.length) {
      throw const FormatException('Duplicate Relay node');
    }
    final proxies = <RemoteProxy>[];
    for (final s in data['services'] as List) {
      if (s is! Map ||
          s['serviceId'] is! String ||
          s['remotePort'] is! int ||
          (s['remotePort'] as int) < 1 ||
          (s['remotePort'] as int) > 65535) {
        throw const FormatException('Invalid Relay service');
      }
      proxies.add(
        RemoteProxy(
          s['serviceId'] as String,
          s['remotePort'] as int,
          label: s['name'] is String
              ? '${s['connectorName'] ?? ''} · ${s['name']}'
              : null,
          kind: s['type'] as String?,
        ),
      );
    }
    if (proxies.map((p) => p.name).toSet().length != proxies.length) {
      throw const FormatException('Duplicate Relay service');
    }
    return RelayDeviceProfile._(data, expiry, revision, nodes, proxies, uuid);
  }
}
