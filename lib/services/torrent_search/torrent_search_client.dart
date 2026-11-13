import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'torrent_search_config.dart';

class TorrentSearchException implements Exception {
  const TorrentSearchException(this.code, {this.retryable = false});
  final String code;
  final bool retryable;
  @override
  String toString() => 'TorrentSearchException($code)';
}

/// A candidate the user chose, resolved to a validated magnet for the
/// download plan. Produced by the host only; never by model text.
class TorrentResolution {
  const TorrentResolution({
    required this.serverRef,
    required this.resultRef,
    required this.title,
    required this.infoHash,
    required this.magnet,
  });
  final String serverRef;
  final String resultRef;
  final String title;
  final String infoHash;
  final String magnet;
}

/// HTTP client for the torrent-search service API (/v1, see
/// torrent-search/api/openapi.json). Certificates are always verified.
class TorrentSearchClient {
  TorrentSearchClient({
    required this.config,
    required this.token,
    HttpClient Function()? client,
    this.requestTimeout = const Duration(seconds: 25),
  }) : _client = client ?? HttpClient.new;

  final TorrentSearchConfig config;
  final Future<String?> Function() token;
  final HttpClient Function() _client;
  final Duration requestTimeout;

  static const maxResponseBytes = 1 << 20;
  static final refPattern = RegExp(r'^tsr_[A-Za-z0-9_-]{1,60}$');
  static final _magnet = RegExp(r'^magnet:\?xt=urn:btih:([0-9a-f]{40})(&|$)');

  /// Server error codes passed through as-is; anything else is generic.
  static const _known = {
    'invalid_request',
    'category_unsupported',
    'sort_unsupported',
    'not_found',
    'source_item_gone',
    'candidate_changed',
    'result_expired',
    'no_valid_magnet',
    'rate_limited',
    'upstream_unavailable',
    'upstream_rate_limited',
    'upstream_timeout',
    'parse_changed',
    'source_blocked',
  };

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(config.url);
    final prefix = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(
      path: '$prefix$path',
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    final secret = await token();
    if (secret == null || secret.isEmpty) {
      throw const TorrentSearchException('service_token_missing');
    }
    final client = _client()..connectionTimeout = requestTimeout;
    try {
      final request = await client
          .openUrl(method, _uri(path, query))
          .timeout(requestTimeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $secret');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        request.headers.contentType = ContentType.json;
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      final response = await request.close().timeout(requestTimeout);
      final chunks = <int>[];
      await for (final chunk in response.timeout(requestTimeout)) {
        chunks.addAll(chunk);
        if (chunks.length > maxResponseBytes) {
          throw const TorrentSearchException('service_response_too_large');
        }
      }
      Map<String, dynamic>? json;
      try {
        final decoded = jsonDecode(utf8.decode(chunks));
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {}
      if (response.statusCode == 200 && json != null) return json;
      throw _fail(response.statusCode, json);
    } on TimeoutException {
      throw const TorrentSearchException('service_timeout', retryable: true);
    } on HandshakeException {
      throw const TorrentSearchException('tls_verification_failed');
    } on SocketException {
      throw const TorrentSearchException(
        'service_unreachable',
        retryable: true,
      );
    } on HttpException {
      throw const TorrentSearchException(
        'service_unreachable',
        retryable: true,
      );
    } finally {
      client.close(force: true);
    }
  }

  static TorrentSearchException _fail(int status, Map<String, dynamic>? json) {
    final error = json?['error'];
    final code = error is Map ? error['code'] : null;
    final retryable = error is Map && error['retryable'] == true;
    if (status == 401) {
      return const TorrentSearchException('service_unauthorized');
    }
    if (status == 403) return const TorrentSearchException('service_forbidden');
    if (code is String && _known.contains(code)) {
      return TorrentSearchException(code, retryable: retryable);
    }
    return TorrentSearchException(
      status >= 500 ? 'service_error' : 'service_rejected',
      retryable: status >= 500,
    );
  }

  static String _ref(String ref) {
    if (!refPattern.hasMatch(ref)) {
      throw const TorrentSearchException('not_found');
    }
    return ref;
  }

  Future<Map<String, dynamic>> capabilities() =>
      _send('GET', '/v1/capabilities');

  Future<Map<String, dynamic>> categories() => _send('GET', '/v1/categories');

  Future<Map<String, dynamic>> search({
    required String query,
    String category = 'all',
    String sort = 'relevance',
    int page = 1,
  }) => _send(
    'POST',
    '/v1/search',
    body: {'query': query, 'category': category, 'sort': sort, 'page': page},
  );

  Future<Map<String, dynamic>> browse({
    required String category,
    String sort = 'date_desc',
    int page = 1,
  }) => _send(
    'GET',
    '/v1/browse',
    query: {'category': category, 'sort': sort, 'page': '$page'},
  );

  Future<Map<String, dynamic>> top({String category = 'all'}) =>
      _send('GET', '/v1/top', query: {'category': category});

  Future<Map<String, dynamic>> recent({int page = 1}) =>
      _send('GET', '/v1/recent', query: {'page': '$page'});

  Future<Map<String, dynamic>> detail(String resultRef) =>
      _send('GET', '/v1/search-results/${_ref(resultRef)}');

  /// Re-checks the candidate on the service and returns its magnet. The
  /// magnet must be a canonical v1 magnet for the reported info hash.
  Future<TorrentResolution> resolve(String resultRef) async {
    final json = await _send(
      'POST',
      '/v1/search-results/${_ref(resultRef)}/resolve',
    );
    final magnet = json['magnet'];
    final hash = json['info_hash'];
    final match = magnet is String && magnet.length <= 8192
        ? _magnet.firstMatch(magnet)
        : null;
    if (match == null || hash is! String || match.group(1) != hash) {
      throw const TorrentSearchException('no_valid_magnet');
    }
    return TorrentResolution(
      serverRef: config.id,
      resultRef: resultRef,
      title: json['title'] is String ? json['title'] as String : '',
      infoHash: hash,
      magnet: magnet as String,
    );
  }
}
