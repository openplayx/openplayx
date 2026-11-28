import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../remote_access/remote_transport.dart';

import '../../core/capabilities/source_capability.dart';
import '../../core/capabilities/metadata_capability.dart';
import 'file_sources.dart';
import 'source_config.dart';
import 'source_schema.dart';
import 'stream_gateway.dart';
import '../../l10n/l10n.dart';

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
              // Jellyfin reads Authorization, Emby reads X-Emby-*.
              'Authorization':
                  'MediaBrowser Client="OpenPlayX", Device="OpenPlayX", DeviceId="${config.id}", Version="1", Token="$token"',
              if (config.kind == SourceKind.emby) ...{
                'X-Emby-Authorization':
                    'MediaBrowser Client="OpenPlayX", Device="OpenPlayX", DeviceId="${config.id}", Version="1", Token="$token"',
                'X-Emby-Token': token,
              },
              'Accept': 'application/json',
            };
  final SourceConfig config;
  final Map<String, String> _headers;
  bool _closed = false;
  final _connections = <_SourceHttpConnection>{};
  Future<_SourceHttpConnection> _connect() async {
    if (_closed) {
      throw PluginException('cancelled', appStrings.errConnectionClosed);
    }
    final remote = config.remoteAccess == null
        ? null
        : await RemoteTransport.acquire(config);
    final client = remote == null
        ? _client
        : (HttpClient()
            ..connectionTimeout = Duration(
              seconds: config.requestTimeoutSeconds,
            )
            ..maxConnectionsPerHost = config.maxConcurrentRequests);
    remote?.configure(client);
    late final _SourceHttpConnection connection;
    connection = _SourceHttpConnection(
      client,
      remote?.address ?? Uri.parse(config.address),
      () {
        if (remote != null) client.close(force: true);
        remote?.close();
        _connections.remove(connection);
      },
    );
    if (_closed) {
      connection.close();
      throw PluginException('cancelled', appStrings.errConnectionClosed);
    }
    _connections.add(connection);
    return connection;
  }

  late final HttpClient _client = HttpClient()
    ..connectionTimeout = Duration(seconds: config.requestTimeoutSeconds)
    ..maxConnectionsPerHost = config.maxConcurrentRequests;
  Uri uri(String path, [Map<String, String> query = const {}, Uri? endpoint]) {
    final base = endpoint ?? Uri.parse(config.address);
    if (path
        .split('/')
        .any(
          (s) =>
              Uri.decodeComponent(s) == '..' || Uri.decodeComponent(s) == '.',
        )) {
      throw PluginException(
        'permissionDenied',
        appStrings.errUnsafeResourceUrl,
      );
    }
    final relative = Uri.parse(path);
    if (relative.hasScheme ||
        relative.hasAuthority ||
        relative.hasQuery ||
        relative.hasFragment ||
        relative.pathSegments.any(
          (s) => s == '..' || s == '.' || s.contains('\\'),
        )) {
      throw PluginException(
        'permissionDenied',
        appStrings.errUnsafeResourceUrl,
      );
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
  ]) async => await _decode(path, query) as Map<String, dynamic>;

  Future<List<dynamic>> jsonList(
    String path, [
    Map<String, String> query = const {},
  ]) async => await _decode(path, query) as List<dynamic>;

  Future<Object?> request(
    String path, {
    String method = 'POST',
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
  }) => _decode(path, query, method: method, body: body);

  Future<Object?> _decode(
    String path,
    Map<String, String> query, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final connection = await _connect();
    try {
      final request = await connection.client.openUrl(
        method,
        uri(path, query, connection.address),
      );
      request.followRedirects = false;
      _headers.forEach(request.headers.set);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
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
          appStrings.errMediaServerHttp(response.statusCode),
          retryable: true,
        );
      }
      final text = await utf8.decoder
          .bind(response)
          .timeout(Duration(seconds: config.requestTimeoutSeconds))
          .join();
      return text.isEmpty ? null : jsonDecode(text);
    } finally {
      connection.close();
    }
  }

  Future<List<int>> attachment(String path, {required int maxBytes}) async {
    final connection = await _connect();
    try {
      final request = await connection.client.getUrl(
        uri(path, const {}, connection.address),
      );
      request.followRedirects = false;
      _headers.forEach(request.headers.set);
      final response = await request.close();
      if (response.statusCode != 200 ||
          ![
            'image/jpeg',
            'image/png',
            'image/webp',
          ].contains(response.headers.contentType?.mimeType)) {
        await response.drain<void>();
        throw PluginException(
          'invalidArtwork',
          appStrings.errServerArtworkUnavailable,
        );
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > maxBytes) {
          throw PluginException('quotaExceeded', appStrings.errImageTooLarge);
        }
        bytes.addAll(chunk);
      }
      return bytes;
    } finally {
      connection.close();
    }
  }

  Future<PlayableStream> stream(
    String path, {
    Map<String, String> query = const {},
    String? filename,
  }) async {
    final connection = await _connect();
    try {
      final stream = await StreamGateway.http(
        uri(path, query, connection.address),
        _headers,
        filename: filename,
        sharedClient: connection.client,
      );
      return PlayableStream(
        stream.uri,
        release: () async {
          try {
            await stream.release();
          } finally {
            connection.close();
          }
        },
      );
    } catch (_) {
      connection.close();
      rethrow;
    }
  }

  void close() {
    _closed = true;
    for (final connection in _connections.toList()) {
      connection.close();
    }
    _client.close(force: true);
  }
}

class _SourceHttpConnection {
  _SourceHttpConnection(this.client, this.address, this._release);
  final HttpClient client;
  final Uri address;
  final void Function() _release;
  bool _closed = false;
  void close() {
    if (!_closed) {
      _closed = true;
      _release();
    }
  }
}

/// Jellyfin and Emby (same MediaBrowser API).
class JellyfinPlugin
    implements
        Plugin,
        SourceCapability,
        SearchCapability,
        RecentCapability,
        MetadataCapability,
        SourceAttachmentCapability {
  JellyfinPlugin(this.config, this.http);
  static const _fields =
      'MediaSources,ParentId,Overview,Genres,ProviderIds,OriginalTitle';

  SourceEntry _entry(Map<String, dynamic> item) {
    final versions = (item['MediaSources'] as List? ?? []).length > 1;
    return SourceEntry(
      ResourceRef(
        config.id,
        versions ? 'versions:${item['Id']}' : item['Id'] as String,
      ),
      item['Name'] as String? ?? appStrings.untitled,
      media: _jellyfinInfo(item),
      isFolder: item['IsFolder'] == true || versions,
    );
  }

  static bool _listed(Map<String, dynamic> item) =>
      item['IsFolder'] == true ||
      item['MediaType'] == 'Video' ||
      item['MediaType'] == 'Audio';

  @override
  Future<List<SourceEntry>> recent(int limit, CallContext context) async {
    checkOwnership(config.id, null, context);
    final items = await http.jsonList(
      'Users/${Uri.encodeComponent(config.userId)}/Items/Latest',
      {
        'Limit': '$limit',
        'Fields': _fields,
        'IncludeItemTypes': 'Movie,Series,Episode,Video,MusicVideo',
      },
    );
    return items
        .cast<Map<String, dynamic>>()
        .where(_listed)
        .map(_entry)
        .toList();
  }

  final SourceConfig config;
  final SourceHttp http;
  final _playbackStreams = <PlayableStream>{};

  // Native engines decode these directly; the fallback has a bounded,
  // progressive HTTP profile so a playlist cannot escape the credential proxy.
  static Map<String, dynamic> _profile(bool fallback) => {
    'Name': 'OpenPlayX native',
    'MaxStreamingBitrate': 200000000,
    'MaxStaticBitrate': 200000000,
    'DirectPlayProfiles': [
      {
        'Type': 'Video',
        'Container': 'mp4,mkv,webm,avi,mov,ts,m2ts',
        'VideoCodec': fallback
            ? 'h264'
            : 'h264,hevc,av1,vp8,vp9,mpeg2video,mpeg4,vc1',
        'AudioCodec': fallback
            ? 'aac'
            : 'aac,ac3,eac3,dts,truehd,flac,opus,vorbis,mp3',
      },
      {'Type': 'Audio', 'Container': 'mp3,flac,ogg,opus,m4a,aac,wav'},
    ],
    'TranscodingProfiles': [
      {
        'Type': 'Video',
        'Container': 'ts',
        'VideoCodec': 'h264',
        'AudioCodec': 'aac',
        'Protocol': 'http',
        'Context': 'Streaming',
      },
    ],
  };

  Future<PlayableStream> _playback(
    String id,
    String sourceId, {
    bool fallback = false,
  }) async {
    final info = await http.request(
      'Items/$id/PlaybackInfo',
      body: {
        'UserId': config.userId,
        'MediaSourceId': sourceId,
        'EnableDirectPlay': !fallback,
        'EnableDirectStream': true,
        'EnableTranscoding': true,
        'AllowVideoStreamCopy': true,
        'AllowAudioStreamCopy': true,
        'DeviceProfile': _profile(fallback),
      },
    ) as Map<String, dynamic>;
    final sources = (info['MediaSources'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final source = sources.where((s) => s['Id'] == sourceId).firstOrNull;
    if (source == null || info['ErrorCode'] != null) {
      throw PluginException('notFound', appStrings.errNoPlayableVersion);
    }
    final sessionId = info['PlaySessionId'] as String?;
    Future<void> stop() async {
      if (sessionId == null) return;
      await http.request(
        'Sessions/Playing/Stopped',
        body: {
          'ItemId': id,
          'MediaSourceId': sourceId,
          'PlaySessionId': sessionId,
          'PositionTicks': 0,
        },
      );
    }

    PlayableStream? stream;
    try {
      var method = 'DirectPlay';
      if (!fallback && source['SupportsDirectPlay'] == true) {
        stream = await http.stream(
          'Videos/$id/stream',
          query: {
            'Static': 'true',
            'MediaSourceId': sourceId,
            'PlaySessionId': ?sessionId,
          },
          filename: 'media.${source['Container'] ?? 'bin'}',
        );
      } else {
        final raw = source['TranscodingUrl'] as String?;
        if (source['SupportsTranscoding'] != true ||
            raw == null ||
            source['TranscodingSubProtocol'] != 'http') {
          throw PluginException(
            'invalidInput',
            appStrings.errNoPlayableVersion,
          );
        }
        final url = Uri.parse(raw);
        final base = Uri.parse(config.address);
        final prefix = base.path.replaceFirst(RegExp(r'/+$'), '');
        if (url.hasFragment ||
            url.userInfo.isNotEmpty ||
            ((url.hasScheme || url.hasAuthority) &&
                (url.scheme != base.scheme ||
                    url.host != base.host ||
                    url.port != base.port ||
                    !url.path.startsWith('$prefix/')))) {
          throw PluginException(
            'permissionDenied',
            appStrings.errUnsafeResourceUrl,
          );
        }
        var path = url.path;
        if (prefix.isNotEmpty && path.startsWith('$prefix/')) {
          path = path.substring(prefix.length);
        }
        final query = Map<String, String>.from(url.queryParameters)
          ..removeWhere(
            (k, _) => {'apikey', 'api_key', 'token'}.contains(k.toLowerCase()),
          );
        final tracks = (source['MediaStreams'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        bool copies(String type) {
          final track = tracks.where((s) => s['Type'] == type).firstOrNull;
          final output = query['${type}Codec']?.split(',') ?? [];
          return output.contains('copy') ||
              (track == null && type == 'Audio') ||
              (track?['Codec'] != null && output.contains(track!['Codec']));
        }

        // Jellyfin's progressive URL names the output codec even when its
        // encoder selects stream copy. Only container errors allow that
        // inference; bitrate/profile/range changes still require transcoding.
        final reasons = (query['TranscodeReasons'] ?? '')
            .split(',')
            .where((r) => r.isNotEmpty);
        method =
            copies('Video') &&
                copies('Audio') &&
                reasons.every(
                  {
                    'ContainerNotSupported',
                    'VideoCodecTagNotSupported',
                    'DirectPlayError',
                  }.contains,
                )
            ? 'Remux'
            : 'Transcode';
        stream = await http.stream(path, query: query, filename: 'media.ts');
      }
      final opened = stream;
      late final PlayableStream handle;
      handle = PlayableStream(
        opened.uri,
        playbackMethod: method,
        fallback: !fallback && method == 'DirectPlay'
            ? () => _playback(id, sourceId, fallback: true)
            : null,
        release: () async {
          try {
            await opened.release();
          } finally {
            _playbackStreams.remove(handle);
            await stop();
          }
        },
      );
      _playbackStreams.add(handle);
      return handle;
    } catch (_) {
      await stream?.release();
      try {
        await stop();
      } catch (_) {
        /* Preserve the negotiation error. */
      }
      rethrow;
    }
  }

  @override
  PluginManifest get manifest => SourceSchemas.forKind(config.kind);
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
        if (request.search != null) ...{
          'SearchTerm': request.search!,
          'Recursive': 'true',
        },
        'StartIndex': '${request.offset}',
        'Limit': '${request.limit}',
        'Fields': _fields,
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
      },
    );
    final entries = (result['Items'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where(_listed)
        .map(_entry)
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
  Future<BrowseResult> search(
    String query,
    BrowseRequest page,
    CallContext context,
  ) => browse(
    BrowseRequest(search: query, offset: page.offset, limit: page.limit),
    context,
  );

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
      throw PluginException('invalidInput', appStrings.errChooseVideoOrAudio);
    }
    final sources = (item['MediaSources'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    if (sources.isEmpty) {
      throw PluginException('notFound', appStrings.errNoPlayableVersion);
    }
    final selected = selection == null
        ? (sources.length == 1 ? sources.single : null)
        : sources.where((s) => s['Id'] == selection[2]).firstOrNull;
    if (selected == null) {
      throw PluginException('invalidInput', appStrings.errReselectVersion);
    }
    if (config.kind == SourceKind.jellyfin && item['MediaType'] == 'Video') {
      return _playback(id, selected['Id'] as String);
    }
    return http.stream(
      '${item['MediaType'] == 'Audio' ? 'Audio' : 'Videos'}/$id/stream',
      query: {'Static': 'true', 'MediaSourceId': selected['Id'] as String},
      filename: 'media.${selected['Container'] ?? item['Container'] ?? 'bin'}',
    );
  }

  @override
  Set<MetadataAction> get actions => {MetadataAction.details};
  @override
  Future<MetadataResult> lookup(
    MetadataRequest request,
    CallContext context,
  ) async {
    checkMetadataRequest(config.id, request, context);
    final item = await http.json(
      'Users/${Uri.encodeComponent(config.userId)}/Items/${Uri.encodeComponent(request.ref!.id)}',
    );
    final info = _jellyfinInfo(item);
    if (info == null ||
        info.id != request.ref!.id ||
        info.kind != request.kind.name) {
      throw PluginException(
        'invalidMetadata',
        appStrings.errServerIdentityMismatch,
      );
    }
    return MetadataResult([metadataFromSource(info, config.id)]);
  }

  @override
  Future<List<int>> readAttachment(
    ResourceRef ref,
    CallContext context, {
    required int maxBytes,
  }) async {
    final parts = checkServerArtwork(config.id, ref, context, maxBytes);
    return http.attachment(
      'Items/${Uri.encodeComponent(parts[2])}/Images/${parts[1] == 'poster' ? 'Primary' : 'Backdrop'}/0',
      maxBytes: maxBytes,
    );
  }

  @override
  Future<void> dispose() async {
    try {
      await Future.wait(_playbackStreams.toList().map((s) => s.release()));
    } finally {
      http.close();
    }
  }
}

class PlexPlugin
    implements
        Plugin,
        SourceCapability,
        SearchCapability,
        RecentCapability,
        MetadataCapability,
        SourceAttachmentCapability {
  PlexPlugin(this.config, this.http);

  SourceEntry _entry(Map<String, dynamic> item, {bool root = false}) {
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
      item['title'] as String? ?? appStrings.untitled,
      isFolder: folder || multiple,
      media: root ? null : _plexInfo(item),
    );
  }

  @override
  Future<List<SourceEntry>> recent(int limit, CallContext context) async {
    checkOwnership(config.id, null, context);
    final json = await http.json('/library/recentlyAdded', {
      'X-Plex-Container-Start': '0',
      'X-Plex-Container-Size': '$limit',
    });
    final items = (json['MediaContainer']['Metadata'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    return items.map(_entry).toList();
  }

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
                appStrings.plexPartLabel(
                  pair.$1 + 1,
                  '${pair.$2['container'] ?? appStrings.plexPartMedia}',
                ),
                isFolder: false,
                media: _plexInfo(metadata),
              ),
            )
            .toList(),
        request,
      );
    }
    final root = request.node == null && request.search == null;
    final path = request.search != null
        ? '/library/all'
        : request.node?.id ?? '/library/sections';
    final json = await http.json(path, {
      if (request.search != null) 'title': request.search!,
      'X-Plex-Container-Start': '${request.offset}',
      'X-Plex-Container-Size': '${request.limit}',
    });
    final container = json['MediaContainer'] as Map<String, dynamic>;
    final items = (container[root ? 'Directory' : 'Metadata'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final entries = items.map((item) => _entry(item, root: root)).toList();
    final next = request.offset + items.length;
    final total =
        container['totalSize'] as int? ?? container['size'] as int? ?? next;
    return BrowseResult(
      entries,
      nextOffset: items.isNotEmpty && next < total ? next : null,
    );
  }

  @override
  Future<BrowseResult> search(
    String query,
    BrowseRequest page,
    CallContext context,
  ) => browse(
    BrowseRequest(search: query, offset: page.offset, limit: page.limit),
    context,
  );

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
    if (parts.isEmpty) {
      throw PluginException('notFound', appStrings.errNoPlayableFile);
    }
    if (parts.length > 1) {
      throw PluginException('unsupported', appStrings.errMultiPartUnsupported);
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
  Set<MetadataAction> get actions => {MetadataAction.details};
  @override
  Future<MetadataResult> lookup(
    MetadataRequest request,
    CallContext context,
  ) async {
    checkMetadataRequest(config.id, request, context);
    final result = await http.json(
      'library/metadata/${Uri.encodeComponent(request.ref!.id)}',
    );
    final items = result['MediaContainer']?['Metadata'] as List? ?? [];
    final info = items.length == 1 ? _plexInfo(items.single as Map<String, dynamic>) : null;
    if (info == null ||
        info.id != request.ref!.id ||
        info.kind != request.kind.name) {
      throw PluginException(
        'invalidMetadata',
        appStrings.errServerIdentityMismatch,
      );
    }
    return MetadataResult([metadataFromSource(info, config.id)]);
  }

  @override
  Future<List<int>> readAttachment(
    ResourceRef ref,
    CallContext context, {
    required int maxBytes,
  }) async {
    final parts = checkServerArtwork(config.id, ref, context, maxBytes);
    return http.attachment(
      'library/metadata/${Uri.encodeComponent(parts[2])}/${parts[1] == 'poster' ? 'thumb' : 'art'}',
      maxBytes: maxBytes,
    );
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
    title: item['Name'] as String? ?? appStrings.untitled,
    kind: switch (item['Type']) {
      'Movie' => 'movie',
      'Series' => 'series',
      'Season' => 'season',
      'Episode' => 'episode',
      'Audio' => 'audio',
      _ => 'video',
    },
    parentId: item['ParentId'] as String?,
    artworkTypes: [
      if ((item['ImageTags'] as Map?)?.containsKey('Primary') == true) 'poster',
      if ((item['BackdropImageTags'] as List?)?.isNotEmpty == true) 'backdrop',
    ],
    metadata: {
      if (item['Overview'] != null) 'overview': item['Overview'],
      if (item['OriginalTitle'] != null) 'originalTitle': item['OriginalTitle'],
      if (item['Genres'] != null) 'genres': item['Genres'],
    },
    externalIds: {
      for (final e in (item['ProviderIds'] as Map? ?? {}).entries)
        e.key.toString().toLowerCase(): e.value.toString(),
    },
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
    title: item['title'] as String? ?? appStrings.untitled,
    kind: switch (item['type']) {
      'movie' => 'movie',
      'show' => 'series',
      'season' => 'season',
      'episode' => 'episode',
      'track' => 'audio',
      _ => 'video',
    },
    parentId: item['parentRatingKey']?.toString(),
    artworkTypes: [
      if (item['thumb'] != null) 'poster',
      if (item['art'] != null) 'backdrop',
    ],
    metadata: {
      if (item['summary'] != null) 'overview': item['summary'],
      if (item['originalTitle'] != null) 'originalTitle': item['originalTitle'],
    },
    externalIds: {
      for (final g in item['Guid'] as List? ?? [])
        if (g['id'] is String && (g['id'] as String).contains('://'))
          (g['id'] as String).split('://').first: (g['id'] as String)
              .split('://')
              .last,
    },
    year: item['year'] as int?,
    season: item['parentIndex'] as int?,
    episode: item['index'] as int?,
  );
}

void checkMetadataRequest(
  String instance,
  MetadataRequest request,
  CallContext context,
) {
  if (context.instanceId != instance ||
      request.action != MetadataAction.details ||
      request.ref?.provider != 'server:$instance' ||
      !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(request.ref!.id)) {
    throw PluginException(
      'permissionDenied',
      appStrings.errMetadataNotThisServer,
    );
  }
}

List<String> checkServerArtwork(
  String instance,
  ResourceRef ref,
  CallContext context,
  int maxBytes,
) {
  checkOwnership(instance, ref, context);
  if (maxBytes < 1 ||
      maxBytes > 20 * 1024 * 1024 ||
      !RegExp(r'^artwork:(poster|backdrop):[A-Za-z0-9_-]{1,128}$')
          .hasMatch(ref.id)) {
    throw PluginException(
      'permissionDenied',
      appStrings.errArtworkNotThisServer,
    );
  }
  return ref.id.split(':');
}
