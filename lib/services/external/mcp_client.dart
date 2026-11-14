import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A failed MCP exchange. [code] is short and safe to show to the model.
class McpException implements Exception {
  const McpException(this.code, [this.message]);
  final String code;
  final String? message;
  @override
  String toString() =>
      'McpException($code${message == null ? '' : ': $message'})';
}

/// Minimal MCP client over Streamable HTTP for one endpoint.
///
/// - `initialize` + `notifications/initialized` once; an `Mcp-Session-Id`
///   from the server is kept and sent back, and a 404 for it re-initialises.
/// - Responses may be `application/json` or a `text/event-stream` carrying
///   the JSON-RPC response; server-initiated requests are not supported.
/// - Only `tools/list` and `tools/call` are used. The token is sent as a
///   bearer header and never appears in arguments or results.
class McpClient {
  McpClient({
    required this.endpoint,
    required this.token,
    HttpClient? http,
    this.timeout = const Duration(seconds: 60),
  }) : _http = http ?? HttpClient() {
    _http.connectionTimeout = const Duration(seconds: 10);
  }

  final Uri endpoint;

  /// Bearer token; sent as a header only, never in arguments or results.
  final String token;
  final HttpClient _http;
  final Duration timeout;
  static const protocolVersion = '2025-11-25';
  static const _maxBody = 4 << 20;

  String? _session;
  String? _negotiated;

  /// `serverInfo` from the handshake (name, title, version).
  Map<String, dynamic> serverInfo = const {};
  Future<void>? _initializing;
  var _id = 0;

  void close() => _http.close(force: true);

  Future<void> _ensureInitialized() => _initializing ??=
      () async {
        final result = await _send('initialize', {
          'protocolVersion': protocolVersion,
          'capabilities': {},
          'clientInfo': {'name': 'openplayx', 'version': '1'},
        }, initializing: true);
        _negotiated = result['protocolVersion'] as String? ?? protocolVersion;
        final info = result['serverInfo'];
        if (info is Map) serverInfo = Map<String, dynamic>.from(info);
        await _notify('notifications/initialized');
      }().catchError((Object e) {
        _initializing = null;
        throw e;
      });

  /// Runs the handshake (once) and returns [serverInfo].
  Future<Map<String, dynamic>> initialize() async {
    await _ensureInitialized();
    return serverInfo;
  }

  /// `tools/list`, following pagination cursors.
  Future<List<Map<String, dynamic>>> listTools() async {
    final tools = <Map<String, dynamic>>[];
    String? cursor;
    for (var page = 0; page < 20; page++) {
      final result = await request('tools/list', {'cursor': ?cursor});
      for (final t in result['tools'] as List? ?? const []) {
        if (t is Map) tools.add(Map<String, dynamic>.from(t));
      }
      cursor = result['nextCursor'] as String?;
      if (cursor == null) break;
    }
    return tools;
  }

  /// `tools/call`; returns the raw result (`content`, `structuredContent`,
  /// `isError`).
  Future<Map<String, dynamic>> callTool(
    String name,
    Map<String, dynamic> arguments,
  ) => request('tools/call', {'name': name, 'arguments': arguments});

  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params,
  ) async {
    await _ensureInitialized();
    try {
      return await _send(method, params);
    } on _SessionExpired {
      _session = null;
      _initializing = null;
      await _ensureInitialized();
      return _send(method, params);
    }
  }

  Future<HttpClientRequest> _open() async {
    final req = await _http.postUrl(endpoint).timeout(timeout);
    req.followRedirects = false;
    req.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
      ..set(HttpHeaders.acceptHeader, 'application/json, text/event-stream')
      ..contentType = ContentType.json;
    final session = _session;
    if (session != null) req.headers.set('Mcp-Session-Id', session);
    final version = _negotiated;
    if (version != null) req.headers.set('MCP-Protocol-Version', version);
    return req;
  }

  Future<void> _notify(String method) async {
    try {
      final req = await _open();
      req.write(jsonEncode({'jsonrpc': '2.0', 'method': method}));
      final res = await req.close().timeout(timeout);
      await res.drain<void>();
    } catch (_) {
      // A lost notification does not block tool calls.
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    Map<String, dynamic> params, {
    bool initializing = false,
  }) async {
    final id = ++_id;
    try {
      final req = await _open();
      req.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'method': method,
          'params': params,
        }),
      );
      final res = await req.close().timeout(timeout);
      if (initializing) {
        final session = res.headers.value('mcp-session-id');
        if (session != null && session.isNotEmpty) _session = session;
      }
      if (res.statusCode == 404 && !initializing && _session != null) {
        await res.drain<void>();
        throw const _SessionExpired();
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        await res.drain<void>();
        throw const McpException('unauthorized');
      }
      final body = await _read(res);
      if (res.statusCode != 200) {
        throw McpException('http_${res.statusCode}');
      }
      final type = res.headers.contentType?.mimeType ?? '';
      final message = type == 'text/event-stream'
          ? _fromEventStream(body, id)
          : _decode(body);
      if (message['error'] is Map) {
        final error = message['error'] as Map;
        throw McpException(
          'rpc_${error['code'] ?? 'error'}',
          error['message'] as String?,
        );
      }
      final result = message['result'];
      if (result is! Map) throw const McpException('invalid_response');
      return Map<String, dynamic>.from(result);
    } on McpException {
      rethrow;
    } on _SessionExpired {
      rethrow;
    } on TimeoutException {
      throw const McpException('timeout');
    } on SocketException {
      throw const McpException('unreachable');
    } on HandshakeException {
      throw const McpException('tls_failed');
    } on HttpException {
      throw const McpException('unreachable');
    }
  }

  static Future<String> _read(HttpClientResponse res) async {
    final bytes = <int>[];
    await for (final chunk in res) {
      bytes.addAll(chunk);
      if (bytes.length > _maxBody) {
        throw const McpException('response_too_large');
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static Map<String, dynamic> _decode(String text) {
    try {
      final v = jsonDecode(text);
      if (v is Map) return Map<String, dynamic>.from(v);
    } catch (_) {}
    throw const McpException('invalid_response');
  }

  /// The JSON-RPC response for [id] inside an SSE body.
  static Map<String, dynamic> _fromEventStream(String body, int id) {
    for (final event in body.split(RegExp(r'\r?\n\r?\n'))) {
      final data = event
          .split(RegExp(r'\r?\n'))
          .where((l) => l.startsWith('data:'))
          .map((l) => l.substring(5).trimLeft())
          .join('\n');
      if (data.isEmpty) continue;
      try {
        final v = jsonDecode(data);
        if (v is Map && v['id'] == id) return Map<String, dynamic>.from(v);
      } catch (_) {}
    }
    throw const McpException('invalid_response');
  }
}

class _SessionExpired implements Exception {
  const _SessionExpired();
}
