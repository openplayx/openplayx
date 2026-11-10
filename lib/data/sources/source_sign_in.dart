import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/plugins/source_capability.dart';
import 'source_config.dart';

class JellyfinSession {
  const JellyfinSession(this.userId, this.token);
  final String userId;
  final String token;
}

class PlexPin {
  const PlexPin(this.id, this.code, this.expiresAt, this.loginUri);
  final int id;
  final String code;
  final DateTime expiresAt;
  final Uri loginUri;
}

class PlexServer {
  const PlexServer({
    required this.id,
    required this.name,
    required this.token,
    required this.connections,
  });
  final String id;
  final String name;
  final String token;
  final List<Uri> connections;
}

/// Host-only account flow. Passwords and the Plex account token stay in memory;
/// only the selected server's session token is passed to the credential broker.
class SourceSignIn {
  SourceSignIn({Uri? plexApi, Uri? plexResources})
    : _plexApi = plexApi ?? Uri.parse('https://plex.tv/api/v2/'),
      _plexResources =
          plexResources ??
          Uri.parse('https://clients.plex.tv/api/v2/resources');
  final Uri _plexApi;
  final Uri _plexResources;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  Map<String, String> _plexHeaders(String id) => {
    'Accept': 'application/json',
    'X-Plex-Product': 'OpenPlayX',
    'X-Plex-Version': '1',
    'X-Plex-Client-Identifier': 'openplayx-$id',
  };
  Future<Object?> _json(
    Uri uri, {
    String method = 'GET',
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    try {
      final request = await _client.openUrl(method, uri);
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      if (body != null) {
        // Plain application/json with an explicit length: Emby parses neither
        // the charset variant nor a chunked request body.
        final bytes = utf8.encode(jsonEncode(body));
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          request.abort();
          throw TimeoutException('sign-in');
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        throw PluginException(
          response.statusCode == 401 || response.statusCode == 403
              ? 'authRequired'
              : response.statusCode == 404
              ? 'notFound'
              : 'networkUnavailable',
          response.statusCode == 401 || response.statusCode == 403
              ? '登录失败，请检查账号和密码或重新授权。'
              : response.isRedirect
              ? '地址发生跳转，请填写服务器的实际入口。'
              : '无法连接服务，请检查地址和网络。',
        );
      }
      final content = await utf8.decoder
          .bind(response)
          .timeout(const Duration(seconds: 15))
          .join();
      return content.isEmpty ? null : jsonDecode(content);
    } on PluginException {
      rethrow;
    } on TimeoutException {
      throw const PluginException('timeout', '连接超时，请重试。');
    } catch (_) {
      throw const PluginException('networkUnavailable', '无法连接服务，请检查地址和网络。');
    }
  }

  Future<JellyfinSession> jellyfin(SourceConfig config, String password) async {
    if (config.username.trim().isEmpty) {
      throw PluginException('invalidInput', '请填写 ${config.kind.label} 用户名。');
    }
    final base = Uri.parse(
      '${config.address.replaceFirst(RegExp(r'/+$'), '')}/',
    );
    final data = await _json(
      base.resolve('Users/AuthenticateByName'),
      method: 'POST',
      headers: {
        'Authorization':
            'MediaBrowser Client="OpenPlayX", Device="OpenPlayX", DeviceId="${config.id}", Version="1"',
        'X-Emby-Authorization':
            'MediaBrowser Client="OpenPlayX", Device="OpenPlayX", DeviceId="${config.id}", Version="1"',
      },
      body: {'Username': config.username, 'Pw': password},
    ) as Map<String, dynamic>;
    final id = (data['User'] as Map?)?['Id'];
    final token = data['AccessToken'];
    if (id is! String || id.isEmpty || token is! String || token.isEmpty) {
      throw const PluginException('authRequired', '服务器未返回有效的登录结果。');
    }
    return JellyfinSession(id, token);
  }

  Future<PlexPin> startPlex(String instanceId) async {
    final data = await _json(
      _plexApi.resolve('pins').replace(queryParameters: {'strong': 'true'}),
      method: 'POST',
      headers: _plexHeaders(instanceId),
    ) as Map<String, dynamic>;
    final expires =
        DateTime.tryParse('${data['expiresAt']}') ??
        DateTime.now().add(Duration(seconds: data['expiresIn'] as int? ?? 300));
    final query = Uri(
      queryParameters: {
        'clientID': 'openplayx-$instanceId',
        'code': data['code'] as String,
        'context[device][product]': 'OpenPlayX',
      },
    ).query;
    return PlexPin(
      data['id'] as int,
      data['code'] as String,
      expires,
      Uri.parse('https://app.plex.tv/auth#?$query'),
    );
  }

  Future<String?> pollPlex(String instanceId, PlexPin pin) async {
    if (!pin.expiresAt.isAfter(DateTime.now())) {
      throw const PluginException('authRequired', '登录已过期，请重新登录 Plex。');
    }
    final data = await _json(
      _plexApi.resolve('pins/${pin.id}'),
      headers: _plexHeaders(instanceId),
    ) as Map<String, dynamic>;
    final token = data['authToken'];
    return token is String && token.isNotEmpty ? token : null;
  }

  Future<List<PlexServer>> plexServers(
    String instanceId,
    String accountToken,
  ) async {
    final data = await _json(
      _plexResources.replace(
        queryParameters: {
          'includeHttps': '1',
          'includeRelay': '1',
          'includeIPv6': '1',
        },
      ),
      headers: {..._plexHeaders(instanceId), 'X-Plex-Token': accountToken},
    ) as List;
    final servers = <PlexServer>[];
    for (final item in data.cast<Map<String, dynamic>>()) {
      if (!'${item['provides']}'.split(',').contains('server') ||
          item['accessToken'] is! String) {
        continue;
      }
      final connections = (item['connections'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .toList();
      int priority(Map<String, dynamic> c) =>
          (c['relay'] == true ? 4 : 0) +
          (c['local'] == true ? 0 : 2) +
          (c['protocol'] == 'https' ? 0 : 1);
      connections.sort((a, b) => priority(a).compareTo(priority(b)));
      final urls = connections
          .map((c) => Uri.tryParse('${c['uri']}'))
          .whereType<Uri>()
          .where(
            (u) =>
                ['http', 'https'].contains(u.scheme) &&
                u.host.isNotEmpty &&
                u.userInfo.isEmpty &&
                !u.hasQuery &&
                !u.hasFragment,
          )
          .toList();
      if (urls.isNotEmpty) {
        servers.add(
          PlexServer(
            id: '${item['clientIdentifier']}',
            name: item['name'] as String? ?? 'Plex',
            token: item['accessToken'] as String,
            connections: List.unmodifiable(urls),
          ),
        );
      }
    }
    return servers;
  }

  Future<Uri> connectPlex(String instanceId, PlexServer server) async {
    for (final base in server.connections.take(8)) {
      try {
        final request = await _client
            .getUrl(
              base.replace(
                path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/identity',
              ),
            )
            .timeout(const Duration(seconds: 3));
        request.followRedirects = false;
        ({
          ..._plexHeaders(instanceId),
          'X-Plex-Token': server.token,
        }).forEach(request.headers.set);
        final response = await request.close().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            request.abort();
            throw TimeoutException('Plex server');
          },
        );
        final success = response.statusCode == 200;
        await response.drain<void>().timeout(const Duration(seconds: 3));
        if (success) return base;
      } catch (_) {
        /* Try the next connection for this explicitly chosen server. */
      }
    }
    throw const PluginException(
      'networkUnavailable',
      '无法连接这台 Plex 服务器，请确认服务器在线。',
    );
  }

  void close() => _client.close(force: true);
}
