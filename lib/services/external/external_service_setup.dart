import 'dart:async';
import 'dart:io';

import 'external_service_registry.dart';
import 'mcp_client.dart';

/// What an address turned out to be after the MCP handshake.
class ExternalServiceProbe {
  const ExternalServiceProbe({
    required this.baseUrl,
    required this.endpoint,
    required this.serverName,
    required this.title,
    required this.version,
    required this.tools,
    this.toolDefs = const [],
  });

  /// Full tool definitions as listed by the service.
  final List<Map<String, dynamic>> toolDefs;

  /// Service root (without the MCP path).
  final String baseUrl;

  /// The MCP endpoint that answered.
  final String endpoint;
  final String serverName;
  final String title;
  final String version;
  final List<String> tools;
}

class ExternalServiceException implements Exception {
  const ExternalServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Configures a custom external capability from its address and token: the
/// App connects over MCP (Streamable HTTP), reads `serverInfo` and the tool
/// list, and saves the service in [ExternalServiceRegistry]. The user never
/// picks a service type.
class ExternalServiceSetup {
  ExternalServiceSetup({
    required this.registry,
    HttpClient Function()? http,
    this.timeout = const Duration(seconds: 10),
  }) : _http = http ?? HttpClient.new;

  final ExternalServiceRegistry registry;
  final HttpClient Function() _http;
  final Duration timeout;

  /// MCP paths tried in order (torrent-search / ASR use /mcp, the
  /// BitTorrent server keeps its API under /api).
  static const _paths = ['/mcp', '/api/mcp'];

  /// Loopback, RFC 1918 / unique-local addresses and .local/.lan names: the
  /// only hosts plain HTTP is accepted for.
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

  /// Accepts a pasted root or MCP URL; returns the service root.
  static Uri normalize(String raw) {
    var text = raw.trim();
    while (text.endsWith('/')) {
      text = text.substring(0, text.length - 1);
    }
    for (final suffix in ['/api/mcp', '/mcp']) {
      if (text.endsWith(suffix)) {
        text = text.substring(0, text.length - suffix.length);
        break;
      }
    }
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const ExternalServiceException(
        '请输入服务根地址，例如 https://bt.example.com',
      );
    }
    if (uri.scheme == 'http' && !isLanHost(uri.host)) {
      throw const ExternalServiceException('公网地址必须使用 HTTPS；HTTP 仅允许局域网或本机地址');
    }
    return uri.replace(path: '');
  }

  Future<ExternalServiceProbe> probe(String rawUrl, String token) async {
    final base = normalize(rawUrl);
    final secret = token.trim();
    if (secret.isEmpty) {
      throw const ExternalServiceException('请填写访问令牌');
    }
    var rejected = false;
    for (final path in _paths) {
      final endpoint = base.replace(path: path);
      final client = McpClient(
        endpoint: endpoint,
        token: secret,
        http: _http(),
        timeout: timeout,
      );
      try {
        final info = await client.initialize();
        final listed = await client.listTools();
        final defs = [
          for (final t in listed)
            if (t['name'] is String)
              {
                'name': t['name'],
                if (t['title'] is String) 'title': t['title'],
                if (t['description'] is String) 'description': t['description'],
                if (t['inputSchema'] is Map) 'inputSchema': t['inputSchema'],
                if (t['annotations'] is Map) 'annotations': t['annotations'],
              },
        ];
        final name = info['name'] is String ? info['name'] as String : '';
        return ExternalServiceProbe(
          baseUrl: base.toString(),
          endpoint: endpoint.toString(),
          serverName: name,
          title: info['title'] is String ? info['title'] as String : name,
          version: info['version'] is String ? info['version'] as String : '',
          tools: [for (final d in defs) d['name'] as String],
          toolDefs: defs,
        );
      } on McpException catch (e) {
        switch (e.code) {
          // Another app on this path (e.g. a WebUI) may also refuse us.
          case 'unauthorized':
            rejected = true;
          // Not an MCP endpoint at this path: try the next one.
          case 'http_404' || 'http_405' || 'invalid_response':
            break;
          case 'timeout':
            throw const ExternalServiceException('连接超时');
          case 'unreachable':
            throw const ExternalServiceException('无法连接到这个地址');
          case 'tls_failed':
            throw const ExternalServiceException('TLS 证书校验失败');
          case 'response_too_large':
            throw const ExternalServiceException('服务返回的数据过大');
          default:
            throw ExternalServiceException(
              e.code.startsWith('rpc_')
                  ? '服务拒绝了请求：${e.message ?? e.code}'
                  : '服务返回错误（${e.code}）',
            );
        }
      } finally {
        client.close();
      }
    }
    throw ExternalServiceException(rejected ? '访问令牌无效' : '这个地址没有提供 MCP 入口');
  }

  /// Saves a probed service. The same address again updates it instead of
  /// adding a duplicate.
  Future<ExternalService> save(
    ExternalServiceProbe probe,
    String token, {
    String? name,
  }) async {
    if (!registry.loaded) await registry.load();
    final existing = registry.byBaseUrl(probe.baseUrl);
    final label = name?.trim().isNotEmpty == true
        ? name!.trim()
        : existing?.name ??
              (probe.title.isNotEmpty
                  ? probe.title
                  : Uri.parse(probe.baseUrl).host);
    final service = ExternalService(
      id: existing?.id ?? ExternalServiceRegistry.newId(),
      name: label,
      baseUrl: probe.baseUrl,
      endpoint: probe.endpoint,
      serverName: probe.serverName,
      serverTitle: probe.title,
      version: probe.version,
      tools: probe.tools,
      toolDefs: probe.toolDefs,
      available: true,
      checkedAt: DateTime.now(),
    );
    await registry.save(service, token: token);
    return service;
  }

  /// Connects again with the stored token and refreshes tools and status.
  Future<ExternalService> recheck(ExternalService service) async {
    final token = await registry.token(service.id) ?? '';
    try {
      final probe = await this.probe(service.baseUrl, token);
      final next = service.copyWith(
        endpoint: probe.endpoint,
        serverName: probe.serverName,
        serverTitle: probe.title,
        version: probe.version,
        tools: probe.tools,
        toolDefs: probe.toolDefs,
        available: true,
        checkedAt: DateTime.now(),
      );
      await registry.save(next);
      return next;
    } on ExternalServiceException {
      await registry.save(
        service.copyWith(available: false, checkedAt: DateTime.now()),
      );
      rethrow;
    }
  }
}
