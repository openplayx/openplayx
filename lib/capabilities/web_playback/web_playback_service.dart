import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/capabilities/source_capability.dart';
import 'web_playback_catalog.dart';
import 'web_playback_assets.dart';

class WebPlaybackSession {
  WebPlaybackSession({
    required this.id,
    required this.owner,
    required this.media,
    required this.device,
    required this.progressSession,
    required this.stream,
  });
  final String id, owner, device, progressSession;
  final WebMedia media;
  final PlayableStream stream;
  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);
  DateTime lastSeen = DateTime.now();
  int positionMs = 0, durationMs = 0;
  bool active = true;

  Future<void> close() async {
    if (!active) return;
    active = false;
    client.close(force: true);
    await stream.release();
  }
}

class _Device {
  _Device(this.name, this.expires);
  final String name;
  final DateTime expires;
  int revision = 0;
}

class _Attempts {
  int count = 0;
  DateTime until = DateTime.now().add(const Duration(minutes: 1));
}

/// Opt-in, single-interface LAN service. Authentication is a short-lived,
/// HttpOnly same-site cookie; no source paths/URLs or tokens enter the UI.
/// Direct Play only: file jobs must not be mistaken for streaming transcodes.
class WebPlaybackService extends ChangeNotifier {
  WebPlaybackService(this.catalog) : _sharedScopes = catalog.loadSharedScopes();
  final WebPlaybackCatalog catalog;
  final Set<String> _sharedScopes;
  Set<String> get sharedScopes => Set.unmodifiable(_sharedScopes);
  final _random = Random.secure();
  final _devices = <String, _Device>{};
  final _sessions = <String, WebPlaybackSession>{};
  final _attempts = <String, _Attempts>{};
  final _pending = <Future<void>>{};
  HttpServer? _server;
  Timer? _maintenance;
  String? _code;
  DateTime? _codeExpires;
  int _epoch = 0, _connections = 0;
  bool _disposed = false, _starting = false;
  bool get running => _server != null;
  String? get address => _server == null
      ? null
      : 'http://${_server!.address.address}:${_server!.port}';
  String? get pairingCode => _code;
  DateTime? get pairingExpires => _codeExpires;
  List<WebPlaybackSession> get sessions => List.unmodifiable(_sessions.values);

  static bool isPrivateAddress(InternetAddress address) {
    if (address.type != InternetAddressType.IPv4) return false;
    final b = address.rawAddress;
    return b[0] == 10 ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168);
  }

  static Future<List<InternetAddress>> interfaces() async => [
    for (final nic in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    ))
      for (final ip in nic.addresses)
        if (isPrivateAddress(ip)) ip,
  ];

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  String _token() => List.generate(
    32,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  Future<void> start(InternetAddress bindAddress, {int port = 8090}) async {
    if (_disposed) throw StateError('disposed');
    if (running || _starting) throw StateError('already_running');
    if (!bindAddress.isLoopback && !isPrivateAddress(bindAddress)) {
      throw ArgumentError('A specific private IPv4 interface is required');
    }
    _starting = true;
    final epoch = ++_epoch;
    try {
      final server = await HttpServer.bind(bindAddress, port, shared: false);
      if (_disposed || epoch != _epoch) {
        await server.close(force: true);
        return;
      }
      _server = server;
      server.idleTimeout = const Duration(seconds: 20);
      refreshPairingCode();
      server.listen(
        (request) {
          final future = _handle(request);
          _pending.add(future);
          unawaited(future.whenComplete(() => _pending.remove(future)));
        },
        onError: (Object _) {},
        onDone: () {
          if (identical(_server, server)) unawaited(stop());
        },
      );
      _maintenance = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _sweep(),
      );
      _changed();
    } finally {
      _starting = false;
    }
  }

  void refreshPairingCode() {
    if (!running) return;
    final previous = _code;
    do {
      _code = (100000 + _random.nextInt(900000)).toString();
    } while (_code == previous);
    _codeExpires = DateTime.now().add(const Duration(minutes: 5));
    _changed();
  }

  Future<void> setSharedScopes(Set<String> ids) async {
    final allowed = catalog.scopes.map((s) => s.id).toSet();
    final next = ids.intersection(allowed);
    catalog.saveSharedScopes(next);
    _sharedScopes
      ..clear()
      ..addAll(next);
    for (final session in sessions) {
      if (catalog.find(_sharedScopes, session.media.id) == null) {
        await endSession(session.id);
      }
    }
    _changed();
  }

  Future<void> endSession(String id) async {
    final session = _sessions.remove(id);
    if (session != null) {
      _devices[session.owner]?.revision++;
      await session.close();
      _changed();
    }
  }

  Future<void> stop() async {
    ++_epoch;
    final server = _server;
    _server = null;
    _maintenance?.cancel();
    _maintenance = null;
    _code = null;
    _codeExpires = null;
    _devices.clear();
    _attempts.clear();
    final closing = sessions;
    _sessions.clear();
    await server?.close(force: true);
    await Future.wait(closing.map((s) => s.close()));
    _changed();
  }

  /// Called before the app closes its library and source manager.
  Future<void> shutdown() async {
    await stop();
    await Future.wait(_pending.toList());
  }

  void _sweep() {
    final now = DateTime.now();
    _attempts.removeWhere((_, a) => now.isAfter(a.until));
    _devices.removeWhere((_, d) => now.isAfter(d.expires));
    if (_codeExpires != null && now.isAfter(_codeExpires!)) {
      _code = null;
      _changed();
    }
    for (final session in sessions) {
      if (!_devices.containsKey(session.owner) ||
          now.difference(session.lastSeen) > const Duration(seconds: 90) ||
          catalog.find(_sharedScopes, session.media.id) == null) {
        unawaited(endSession(session.id));
      }
    }
  }

  bool _allowedRequest(HttpRequest request) {
    final server = _server;
    final peer = request.connectionInfo?.remoteAddress;
    if (server == null ||
        peer == null ||
        (!peer.isLoopback && !isPrivateAddress(peer))) {
      return false;
    }
    // Never trust arbitrary DNS names, forwarded hosts or CORS origins.
    final expected = '${server.address.address}:${server.port}';
    if (request.headers.value(HttpHeaders.hostHeader) != expected) return false;
    final origin = request.headers.value('origin');
    if (origin != null && origin != 'http://$expected') return false;
    if (!['GET', 'HEAD'].contains(request.method) &&
        request.headers.value('x-openplayx') != '1') {
      return false;
    }
    return true;
  }

  void _json(HttpRequest r, int status, Object data) {
    r.response.statusCode = status;
    r.response.headers.contentType = ContentType.json;
    if (r.method != 'HEAD') r.response.write(jsonEncode(data));
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    if (request.headers.contentType?.mimeType != 'application/json') {
      throw const FormatException('json_required');
    }
    final bytes = <int>[];
    await for (final chunk in request.timeout(const Duration(seconds: 10))) {
      if (bytes.length + chunk.length > 4096) {
        throw const FormatException('body_too_large');
      }
      bytes.addAll(chunk);
    }
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, dynamic>) {
      throw const FormatException('invalid_body');
    }
    return value;
  }

  String? _authenticated(HttpRequest request) {
    final token = request.cookies
        .where((c) => c.name == 'opx_web')
        .firstOrNull
        ?.value;
    final device = _devices[token];
    if (device == null || DateTime.now().isAfter(device.expires)) return null;
    return token;
  }

  Future<void> _handle(HttpRequest r) async {
    _connections++;
    try {
      r.response.headers
        ..set('Cache-Control', 'no-store')
        ..set('X-Content-Type-Options', 'nosniff')
        ..set('Referrer-Policy', 'no-referrer')
        ..set(
          'Content-Security-Policy',
          "default-src 'self'; script-src 'self'; style-src 'self'; media-src 'self'; img-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'",
        );
      if (!_allowedRequest(r)) {
        _json(r, 403, {'error': 'forbidden'});
        return;
      }
      if (_connections > 32) {
        _json(r, 429, {'error': 'busy'});
        return;
      }
      final path = r.uri.path;
      if (r.method == 'GET' || r.method == 'HEAD') {
        final asset = switch (path) {
          '/' => (ContentType.html, webPlaybackHtml),
          '/app.css' => (
            ContentType('text', 'css', charset: 'utf-8'),
            webPlaybackCss,
          ),
          '/app.js' => (
            ContentType('application', 'javascript', charset: 'utf-8'),
            webPlaybackJs,
          ),
          _ => null,
        };
        if (asset != null) {
          r.response.headers.contentType = asset.$1;
          if (r.method != 'HEAD') r.response.write(asset.$2);
          return;
        }
      }
      if (path == '/api/pair' && r.method == 'POST') {
        await _pair(r);
        return;
      }
      final owner = _authenticated(r);
      if (owner == null) {
        _json(r, 401, {'error': 'pairing_required'});
        return;
      }
      if (path == '/api/session' && r.method == 'GET') {
        _json(r, 200, {'device': _devices[owner]!.name, 'mode': 'direct'});
      } else if (path == '/api/logout' && r.method == 'POST') {
        _devices.remove(owner);
        for (final s in sessions.where((s) => s.owner == owner)) {
          await endSession(s.id);
        }
        r.response.cookies.add(
          Cookie('opx_web', '')
            ..path = '/'
            ..maxAge = 0
            ..httpOnly = true
            ..sameSite = SameSite.strict,
        );
        _json(r, 200, {'ok': true});
      } else if (path == '/api/library' && r.method == 'GET') {
        final offset = int.tryParse(r.uri.queryParameters['offset'] ?? '0');
        final search = r.uri.queryParameters['search'] ?? '';
        if (offset == null ||
            offset < 0 ||
            offset > 100000 ||
            search.length > 200) {
          _json(r, 400, {'error': 'invalid_query'});
          return;
        }
        final items = catalog.list(
          _sharedScopes,
          search: search,
          offset: offset,
        );
        _json(r, 200, {
          'items': items.map((m) => m.toJson()).toList(),
          'nextOffset': items.length == 48 ? offset + 48 : null,
        });
      } else if (path == '/api/playback' && r.method == 'POST') {
        await _startPlayback(r, owner);
      } else if (r.uri.pathSegments.length >= 3 &&
          r.uri.pathSegments.take(2).join('/') == 'api/playback') {
        final parts = r.uri.pathSegments;
        final s = _sessions[parts[2]];
        if (s == null ||
            s.owner != owner ||
            !s.active ||
            catalog.find(_sharedScopes, s.media.id) == null) {
          if (s?.owner == owner) await endSession(s!.id);
          _json(r, 404, {'error': 'session_ended'});
          return;
        }
        if (parts.length == 4 &&
            parts[3] == 'media' &&
            ['GET', 'HEAD'].contains(r.method)) {
          await _media(r, s);
        } else if (parts.length == 4 &&
            parts[3] == 'progress' &&
            r.method == 'POST') {
          await _progress(r, s);
        } else if (parts.length == 3 && r.method == 'DELETE') {
          await endSession(s.id);
          _json(r, 200, {'ok': true});
        } else {
          _json(r, 404, {'error': 'not_found'});
        }
      } else {
        _json(r, 404, {'error': 'not_found'});
      }
    } on FormatException {
      try {
        _json(r, 400, {'error': 'invalid_request'});
      } catch (_) {}
    } on TimeoutException {
      try {
        _json(r, 408, {'error': 'timeout'});
      } catch (_) {}
    } catch (_) {
      // Never publish source exceptions: URLs and passwords can appear there.
      try {
        _json(r, 502, {'error': 'media_unavailable'});
      } catch (_) {}
    } finally {
      try {
        await r.response.close();
      } catch (_) {}
      _connections--;
    }
  }

  bool _rateLimited(String key) {
    final now = DateTime.now();
    var a = _attempts[key];
    if (a == null || now.isAfter(a.until)) {
      if (_attempts.length >= 256) return true;
      a = _attempts[key] = _Attempts();
    }
    a.count++;
    return a.count > (key == '*' ? 30 : 5);
  }

  Future<void> _pair(HttpRequest r) async {
    if (_rateLimited('*') ||
        _rateLimited(r.connectionInfo!.remoteAddress.address)) {
      _json(r, 429, {'error': 'pairing_rate_limited'});
      return;
    }
    final body = await _body(r);
    if (!running ||
        _code == null ||
        body['code'] != _code ||
        DateTime.now().isAfter(_codeExpires!)) {
      _json(r, 403, {'error': 'invalid_pairing_code'});
      return;
    }
    if (_devices.length >= 16) {
      _json(r, 429, {'error': 'device_limit'});
      return;
    }
    final name = body['device'];
    if (name is! String || name.trim().isEmpty || name.length > 80) {
      _json(r, 400, {'error': 'invalid_device'});
      return;
    }
    final token = _token();
    _devices[token] = _Device(
      name.trim(),
      DateTime.now().add(const Duration(hours: 12)),
    );
    r.response.cookies.add(
      Cookie('opx_web', token)
        ..path = '/'
        ..httpOnly = true
        ..sameSite = SameSite.strict
        ..maxAge = 12 * 60 * 60,
    );
    _json(r, 200, {'ok': true});
  }

  Future<void> _startPlayback(HttpRequest r, String owner) async {
    final body = await _body(r);
    final id = body['id'];
    if (id is! String || id.length > 200) {
      _json(r, 400, {'error': 'invalid_media'});
      return;
    }
    final media = catalog.find(_sharedScopes, id);
    if (media == null) {
      _json(r, 404, {'error': 'not_shared'});
      return;
    }
    final device = _devices[owner]!;
    final revision = ++device.revision;
    final epoch = _epoch;
    var abandoned = false;
    final opening = catalog.open(media).then((stream) async {
      if (abandoned) await stream.release();
      return stream;
    });
    final stream = await opening.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        abandoned = true;
        throw TimeoutException('source_timeout');
      },
    );
    // A stopped service, revoked scope, or newer request must not resurrect work.
    if (!running ||
        epoch != _epoch ||
        _devices[owner] != device ||
        device.revision != revision ||
        catalog.find(_sharedScopes, id) == null) {
      await stream.release();
      _json(r, 409, {'error': 'session_replaced'});
      return;
    }
    final uri = stream.uri;
    if (uri.scheme != 'file' &&
        !(uri.scheme == 'http' &&
            uri.host == '127.0.0.1' &&
            uri.userInfo.isEmpty)) {
      await stream.release();
      _json(r, 422, {'error': 'source_requires_gateway'});
      return;
    }
    for (final s in sessions.where((s) => s.owner == owner)) {
      // Do not bump the request revision while replacing our own old session.
      _sessions.remove(s.id);
      await s.close();
    }
    if (!running ||
        epoch != _epoch ||
        _devices[owner] != device ||
        device.revision != revision ||
        catalog.find(_sharedScopes, id) == null) {
      await stream.release();
      _json(r, 409, {'error': 'session_replaced'});
      return;
    }
    if (_sessions.length >= 8) {
      await stream.release();
      _json(r, 429, {'error': 'playback_limit'});
      return;
    }
    final sid = _token();
    final s = WebPlaybackSession(
      id: sid,
      owner: owner,
      media: media,
      device: device.name,
      progressSession: catalog.beginProgress(media),
      stream: stream,
    );
    _sessions[sid] = s;
    _json(r, 200, {
      'id': sid,
      'title': media.title,
      'url': '/api/playback/$sid/media',
      'positionMs': media.positionMs,
      'mode': 'direct',
    });
    _changed();
  }

  Future<void> _progress(HttpRequest r, WebPlaybackSession s) async {
    final body = await _body(r);
    final p = body['positionMs'], d = body['durationMs'];
    if (p is! int ||
        d is! int ||
        p < 0 ||
        d <= 0 ||
        d > 7 * 24 * 3600 * 1000 ||
        p > d + 1000) {
      _json(r, 400, {'error': 'invalid_progress'});
      return;
    }
    if (!s.active || catalog.find(_sharedScopes, s.media.id) == null) {
      _json(r, 404, {'error': 'session_ended'});
      return;
    }
    s.lastSeen = DateTime.now();
    s.positionMs = min(p, d);
    s.durationMs = d;
    catalog.saveProgress(
      s.media,
      s.progressSession,
      s.positionMs,
      d,
      body['completed'] == true,
    );
    _json(r, 200, {'ok': true});
    _changed();
  }

  Future<void> _media(HttpRequest r, WebPlaybackSession s) async {
    if (s.stream.uri.scheme == 'file') {
      final file = File.fromUri(s.stream.uri);
      final length = await file.length();
      var start = 0, end = length - 1;
      final range = r.headers.value('range');
      r.response.headers.set('Accept-Ranges', 'bytes');
      r.response.headers.contentType = _mime(s.media.name);
      if (range != null) {
        final m = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
        if (m == null || length == 0 || (m[1]!.isEmpty && m[2]!.isEmpty)) {
          _rangeError(r, length);
          return;
        }
        if (m[1]!.isEmpty) {
          final suffix = int.tryParse(m[2]!);
          if (suffix == null || suffix == 0) {
            _rangeError(r, length);
            return;
          }
          start = max(0, length - suffix);
        } else {
          final first = int.tryParse(m[1]!);
          final last = m[2]!.isEmpty ? end : int.tryParse(m[2]!);
          if (first == null || last == null) {
            _rangeError(r, length);
            return;
          }
          start = first;
          end = min(end, last);
        }
        if (start > end || start >= length) {
          _rangeError(r, length);
          return;
        }
        r.response.statusCode = 206;
        r.response.headers.set('Content-Range', 'bytes $start-$end/$length');
      }
      r.response.contentLength = length == 0 ? 0 : end - start + 1;
      if (r.method == 'HEAD' || length == 0) return;
      r.response.bufferOutput = false;
      await r.response.addStream(
        file.openRead(start, end + 1).takeWhile((_) => s.active),
      );
    } else {
      final upstream = await s.client.openUrl(r.method, s.stream.uri);
      upstream.followRedirects = false;
      upstream.headers.set('Accept-Encoding', 'identity');
      final range = r.headers.value('range');
      if (range != null) upstream.headers.set('Range', range);
      final response = await upstream.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.isRedirect) {
        upstream.abort();
        _json(r, 502, {'error': 'upstream_redirect'});
        return;
      }
      r.response.statusCode = response.statusCode;
      for (final header in [
        'content-length',
        'content-range',
        'accept-ranges',
      ]) {
        final value = response.headers.value(header);
        if (value != null) r.response.headers.set(header, value);
      }
      r.response.headers.contentType = _mime(s.media.name);
      r.response.bufferOutput = false;
      try {
        await r.response.addStream(
          response
              .timeout(const Duration(seconds: 30))
              .takeWhile((_) => s.active),
        );
      } finally {
        upstream.abort();
      }
    }
  }

  void _rangeError(HttpRequest r, int length) {
    r.response.statusCode = 416;
    r.response.headers.set('Content-Range', 'bytes */$length');
    r.response.contentLength = 0;
  }

  ContentType _mime(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'mp4' || 'm4v' || 'mov' => ContentType('video', 'mp4'),
      'webm' => ContentType('video', 'webm'),
      'mkv' => ContentType('video', 'x-matroska'),
      'mp3' => ContentType('audio', 'mpeg'),
      'm4a' || 'aac' => ContentType('audio', ext == 'm4a' ? 'mp4' : 'aac'),
      'flac' => ContentType('audio', 'flac'),
      'ogg' || 'opus' => ContentType('audio', 'ogg'),
      _ => ContentType.binary,
    };
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
