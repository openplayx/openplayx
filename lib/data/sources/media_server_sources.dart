import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/plugins/source_capability.dart';
import 'file_sources.dart';
import 'source_config.dart';
import 'source_schema.dart';
import 'stream_gateway.dart';

/// Host-owned authenticated network boundary. URLs from a server response must
/// stay on the configured origin and inside its base path before adding secrets.
class SourceHttp {
  SourceHttp(this.config, String token)
    : _headers = config.kind == SourceKind.plex
          ? {
              'X-Plex-Token': token,
              'X-Plex-Client-Identifier': 'openplayx-${config.id}',
              'Accept': 'application/json',
            }
          : {
              'Authorization':
                  'MediaBrowser Client="OpenPlayX", Device="OpenPlayX", DeviceId="${config.id}", Version="1", Token="$token"',
              'Accept': 'application/json',
            };
  final SourceConfig config;
  final Map<String, String> _headers;
  late final HttpClient _client = HttpClient()
    ..connectionTimeout = Duration(seconds: config.requestTimeoutSeconds)
    ..maxConnectionsPerHost = config.maxConcurrentRequests;
  Uri uri(String path, [Map<String, String> query = const {}]) {
    final base = Uri.parse(config.address);
    if (path
        .split('/')
        .any(
          (s) =>
              Uri.decodeComponent(s) == '..' || Uri.decodeComponent(s) == '.',
        )) {
      throw const PluginException('permissionDenied', '媒体服务返回了不安全的资源地址。');
    }
    final relative = Uri.parse(path);
    if (relative.hasScheme ||
        relative.hasAuthority ||
        relative.hasQuery ||
        relative.hasFragment ||
        relative.pathSegments.any(
          (s) => s == '..' || s == '.' || s.contains('\\'),
        )) {
      throw const PluginException('permissionDenied', '媒体服务返回了不安全的资源地址。');
    }
    final prefix = base.path.replaceFirst(RegExp(r'/+$'), '');
    return base.replace(
      path: '$prefix/${relative.path.replaceFirst(RegExp(r'^/+'), '')}',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  Future<Map<String, dynamic>> json(
    String path, [
    Map<String, String> query = const {},
  ]) async {
    final request = await _client.getUrl(uri(path, query));
    request.followRedirects = false;
    _headers.forEach(request.headers.set);
    final response = await request.close().timeout(
      Duration(seconds: config.requestTimeoutSeconds),
      onTimeout: () {
        request.abort();
        throw TimeoutException('Media server request timed out');
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw PluginException(
        response.statusCode == 401 || response.statusCode == 403
            ? 'authRequired'
            : 'networkUnavailable',
        '媒体服务请求失败（HTTP ${response.statusCode}），请检查地址和凭据。',
        retryable: true,
      );
    }
    return jsonDecode(
      await utf8.decoder
          .bind(response)
          .timeout(Duration(seconds: config.requestTimeoutSeconds))
          .join(),
    ) as Map<String, dynamic>;
  }

  Future<PlayableStream> stream(
    String path, {
    Map<String, String> query = const {},
    String? filename,
  }) => StreamGateway.http(
    uri(path, query),
    _headers,
    filename: filename,
    sharedClient: _client,
  );
  void close() => _client.close(force: true);
}

class JellyfinPlugin implements Plugin, SourceCapability {
  JellyfinPlugin(this.config, this.http);
  final SourceConfig config;
  final SourceHttp http;
  @override
  PluginManifest get manifest => SourceSchemas.forKind(SourceKind.jellyfin);
  @override
  Future<BrowseResult> browse(
    BrowseRequest request,
    CallContext context,
  ) async {
    checkOwnership(config.id, request.node, context);
    if (request.node?.id.startsWith('versions:') == true) {
      final id = request.node!.id.substring(9);
      final item = await http.json(
        'Users/${Uri.encodeComponent(config.userId)}/Items/${Uri.encodeComponent(id)}',
      );
      final sources = (item['MediaSources'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      return pageEntries(
        sources
            .map(
              (source) => SourceEntry(
                ResourceRef(config.id, 'version:$id:${source['Id']}'),
                source['Name'] as String? ?? '${source['Id']}',
                isFolder: false,
                media: _jellyfinInfo(item),
              ),
            )
            .toList(),
        request,
      );
    }
    final result = await http.json(
      'Users/${Uri.encodeComponent(config.userId)}/Items',
      {
        if (request.node != null) 'ParentId': request.node!.id,
        'StartIndex': '${request.offset}',
        'Limit': '${request.limit}',
        'Fields': 'MediaSources,ParentId',
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
      },
    );
    final entries = (result['Items'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where(
          (item) =>
              item['IsFolder'] == true ||
              item['MediaType'] == 'Video' ||
              item['MediaType'] == 'Audio',
        )
        .map(
          (item) => SourceEntry(
            ResourceRef(
              config.id,
              (item['MediaSources'] as List? ?? []).length > 1
                  ? 'versions:${item['Id']}'
                  : item['Id'] as String,
            ),
            item['Name'] as String? ?? '未命名',
            media: _jellyfinInfo(item),
            isFolder:
                item['IsFolder'] == true ||
                (item['MediaSources'] as List? ?? []).length > 1,
          ),
        )
        .toList();
    final count = (result['Items'] as List? ?? []).length;
    final next = request.offset + count;
    return BrowseResult(
      entries,
      nextOffset: next < (result['TotalRecordCount'] as int? ?? next)
          ? next
          : null,
    );
  }

  @override
  Future<PlayableStream> resolve(
    ResolveRequest request,
    CallContext context,
  ) async {
    checkOwnership(config.id, request.resource, context);
    final selection = request.resource.id.startsWith('version:')
        ? request.resource.id.split(':')
        : null;
    final id = Uri.encodeComponent(
      selection == null ? request.resource.id : selection[1],
    );
    final item = await http.json(
      'Users/${Uri.encodeComponent(config.userId)}/Items/$id',
    );
    if (item['IsFolder'] == true ||
        !['Video', 'Audio'].contains(item['MediaType'])) {
      throw const PluginException('invalidInput', '请选择视频或音频。');
    }
    final sources = (item['MediaSources'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    if (sources.isEmpty) throw const PluginException('notFound', '此媒体没有可播放版本。');
    final selected = selection == null
        ? (sources.length == 1 ? sources.single : null)
        : sources.where((s) => s['Id'] == selection[2]).firstOrNull;
    if (selected == null) {
      throw const PluginException('invalidInput', '请返回媒体库重新选择一个版本。');
    }
    return http.stream(
      '${item['MediaType'] == 'Audio' ? 'Audio' : 'Videos'}/$id/stream',
      query: {'Static': 'true', 'MediaSourceId': selected['Id'] as String},
      filename: 'media.${selected['Container'] ?? item['Container'] ?? 'bin'}',
    );
  }

  @override
  Future<void> dispose() async => http.close();
}

class PlexPlugin implements Plugin, SourceCapability {
  PlexPlugin(this.config, this.http);
  final SourceConfig config;
  final SourceHttp http;
  @override
  PluginManifest get manifest => SourceSchemas.forKind(SourceKind.plex);
  @override
  Future<BrowseResult> browse(
    BrowseRequest request,
    CallContext context,
  ) async {
    checkOwnership(config.id, request.node, context);
    if (request.node?.id.startsWith('versions:') == true) {
      final json = await http.json(request.node!.id.substring(9));
      final parts = _parts(json);
      final metadata = (json['MediaContainer']['Metadata'] as List)
          .cast<Map<String, dynamic>>()
          .first;
      return pageEntries(
        parts.indexed
            .map(
              (pair) => SourceEntry(
                ResourceRef(config.id, 'part:${pair.$2['key']}'),
                '文件 ${pair.$1 + 1} · ${pair.$2['container'] ?? '媒体'}',
                isFolder: false,
                media: _plexInfo(metadata),
              ),
            )
            .toList(),
        request,
      );
    }
    final root = request.node == null;
    final path = request.node?.id ?? '/library/sections';
    final json = await http.json(path, {
      'X-Plex-Container-Start': '${request.offset}',
      'X-Plex-Container-Size': '${request.limit}',
    });
    final container = json['MediaContainer'] as Map<String, dynamic>;
    final items = (container[root ? 'Directory' : 'Metadata'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final entries = items.map((item) {
      final folder =
          root || !['movie', 'episode', 'track', 'clip'].contains(item['type']);
      final key = root
          ? '/library/sections/${Uri.encodeComponent('${item['key']}')}/all'
          : folder
          ? "${'${item['key']}'.replaceFirst(RegExp(r'/children$'), '')}/children"
          : '${item['key']}';
      final multiple =
          !folder &&
          (item['Media'] as List? ?? []).fold<int>(
                0,
                (n, m) => n + (m['Part'] as List? ?? []).length,
              ) >
              1;
      return SourceEntry(
        ResourceRef(config.id, multiple ? 'versions:$key' : key),
        item['title'] as String? ?? '未命名',
        isFolder: folder || multiple,
        media: root ? null : _plexInfo(item),
      );
    }).toList();
    final next = request.offset + items.length;
    final total =
        container['totalSize'] as int? ?? container['size'] as int? ?? next;
    return BrowseResult(
      entries,
      nextOffset: items.isNotEmpty && next < total ? next : null,
    );
  }

  @override
  Future<PlayableStream> resolve(
    ResolveRequest request,
    CallContext context,
  ) async {
    checkOwnership(config.id, request.resource, context);
    if (request.resource.id.startsWith('part:')) {
      return http.stream(request.resource.id.substring(5));
    }
    final json = await http.json(request.resource.id);
    final parts = _parts(json);
    if (parts.isEmpty) throw const PluginException('notFound', '此媒体没有可播放文件。');
    if (parts.length > 1) {
      throw const PluginException('unsupported', '该媒体包含多个版本或分段，暂不支持直接播放。');
    }
    return http.stream(parts.single['key'] as String);
  }

  List<Map<String, dynamic>> _parts(Map<String, dynamic> json) {
    final metadata = (json['MediaContainer']['Metadata'] as List)
        .cast<Map<String, dynamic>>();
    final parts = <Map<String, dynamic>>[];
    for (final item in metadata) {
      for (final media in item['Media'] as List? ?? []) {
        parts.addAll(
          (media['Part'] as List? ?? []).cast<Map<String, dynamic>>(),
        );
      }
    }
    return parts;
  }

  @override
  Future<void> dispose() async => http.close();
}

SourceMediaInfo? _jellyfinInfo(Map<String, dynamic> item) {
  if (item['Id'] == null ||
      ![
        'Movie',
        'Series',
        'Season',
        'Episode',
        'Audio',
        'Video',
        'MusicVideo',
      ].contains(item['Type'])) {
    return null;
  }
  return SourceMediaInfo(
    id: item['Id'] as String,
    title: item['Name'] as String? ?? '未命名',
    kind: switch (item['Type']) {
      'Movie' => 'movie',
      'Series' => 'series',
      'Season' => 'season',
      'Episode' => 'episode',
      'Audio' => 'audio',
      _ => 'video',
    },
    parentId: item['ParentId'] as String?,
    year: item['ProductionYear'] as int?,
    season: item['ParentIndexNumber'] as int?,
    episode: item['IndexNumber'] as int?,
  );
}

SourceMediaInfo? _plexInfo(Map<String, dynamic> item) {
  final id = item['ratingKey']?.toString();
  if (id == null) return null;
  return SourceMediaInfo(
    id: id,
    title: item['title'] as String? ?? '未命名',
    kind: switch (item['type']) {
      'movie' => 'movie',
      'show' => 'series',
      'season' => 'season',
      'episode' => 'episode',
      'track' => 'audio',
      _ => 'video',
    },
    parentId: item['parentRatingKey']?.toString(),
    year: item['year'] as int?,
    season: item['parentIndex'] as int?,
    episode: item['index'] as int?,
  );
}
