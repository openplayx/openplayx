import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/capabilities/source_capability.dart';
import '../../l10n/l10n.dart';
import 'cloud_oauth.dart';
import 'file_sources.dart';
import 'network_file_sources.dart' show readCapped;
import 'source_config.dart';
import 'source_schema.dart';
import 'stream_gateway.dart';

class CloudFile {
  const CloudFile(
    this.id,
    this.name, {
    required this.folder,
    this.parent,
    this.size,
  });
  final String id;
  final String name;
  final bool folder;
  final String? parent;
  final int? size;
}

/// The two API adapters share only transport, paging and playback lifecycle.
abstract class CloudFileSource
    implements
        Plugin,
        SourceCapability,
        SourceAttachmentCapability,
        SourceHierarchyCapability {
  CloudFileSource(
    this.config,
    this.session, {
    HttpClient? client,
    this.ownsSession = true,
  }) : client = client ?? HttpClient() {
    this.client.connectionTimeout = timeout;
    session.closeListeners.add(_onSessionClose);
    if (session.isClosed) _onSessionClose();
  }
  final SourceConfig config;
  final CloudTokenSession session;
  final bool ownsSession;
  void _onSessionClose() {
    unawaited(dispose());
  }

  final HttpClient client;
  final _cancel = Completer<void>();
  bool get closed => _cancel.isCompleted;
  Duration get timeout => Duration(seconds: config.requestTimeoutSeconds);
  String get apiHost;
  Future<CloudFile> root();
  Future<CloudFile> metadata(String id);
  Future<(List<CloudFile>, String?)> children(String id, String? cursor);
  Future<Uri> download(String id);
  final _pages = <String, Map<int, String?>>{};

  @override
  PluginManifest get manifest => SourceSchemas.forKind(config.kind);

  void checkOpen() {
    if (closed) {
      throw PluginException('cancelled', appStrings.errInstanceChanged);
    }
  }

  Future<void> delay(Duration value) async {
    final complete = Completer<void>();
    final timer = Timer(value, complete.complete);
    try {
      await Future.any([complete.future, _cancel.future]);
      checkOpen();
    } finally {
      timer.cancel();
    }
  }

  /// API requests never follow redirects with bearer credentials. Next-page
  /// URLs must stay on the provider's exact HTTPS API origin.
  Future<Map<String, dynamic>> api(
    Uri uri, {
    Map<String, dynamic>? body,
    bool post = false,
  }) async {
    if (uri.scheme != 'https' ||
        uri.host != apiHost ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty) {
      throw PluginException('permissionDenied', appStrings.errPathOutsideRoot);
    }
    var refreshed = false;
    for (var retry = 0; ; retry++) {
      checkOpen();
      final token = await session.access();
      checkOpen();
      final request = await client
          .openUrl(post ? 'POST' : 'GET', uri)
          .timeout(timeout);
      request.followRedirects = false;
      request.headers.set('Authorization', 'Bearer $token');
      if (post) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(timeout);
      if (response.statusCode == 401 && !refreshed) {
        await response.drain<void>();
        await session.access(force: true, rejectedToken: token);
        refreshed = true;
        continue;
      }
      if (response.statusCode == 429 && retry < 3) {
        final header = response.headers.value('retry-after');
        final seconds = int.tryParse(header ?? '');
        Duration wait = const Duration(seconds: 1);
        if (seconds != null) {
          wait = Duration(seconds: seconds < 0 ? 0 : seconds);
        } else if (header != null) {
          try {
            wait = HttpDate.parse(header).difference(DateTime.now());
          } catch (_) {}
        }
        await response.drain<void>();
        // Never retry earlier than Retry-After. A long backoff belongs to a
        // later user retry, rather than an operation outliving its deadline.
        if (wait > timeout) {
          throw PluginException(
            'rateLimited',
            appStrings.errConnectTimeout,
            retryable: true,
          );
        }
        await delay(wait.isNegative ? Duration.zero : wait);
        continue;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        throw PluginException(
          response.statusCode == 401 || response.statusCode == 403
              ? 'authRequired'
              : response.statusCode == 404 || response.statusCode == 409
              ? 'notFound'
              : 'networkUnavailable',
          response.statusCode == 401 || response.statusCode == 403
              ? appStrings.cloudReauthorize
              : appStrings.errSourceUnreachable,
          retryable: response.statusCode == 429 || response.statusCode >= 500,
        );
      }
      final bytes = await readCapped(
        response.timeout(timeout),
        16 * 1024 * 1024,
      );
      checkOpen();
      if (bytes.isEmpty) return {};
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    }
  }

  /// Re-evaluate ancestry on each operation, including restored library refs.
  /// Files moved outside the selected root stop being accessible immediately.
  Future<CloudFile> checked(String? id) async {
    final selected = await root();
    if (id == null || id == selected.id) return selected;
    final item = await metadata(id);
    var current = item;
    final seen = <String>{};
    for (var depth = 0; depth < 256 && seen.add(current.id); depth++) {
      if (current.id == selected.id) return item;
      final parent = current.parent;
      if (parent == null) break;
      current = parent == selected.id ? selected : await metadata(parent);
    }
    throw PluginException('permissionDenied', appStrings.errPathOutsideRoot);
  }

  @override
  Future<ResourceRef?> parent(ResourceRef ref, CallContext context) async {
    checkOwnership(config.id, ref, context);
    final item = await checked(ref.id);
    if (item.id == (await root()).id || item.parent == null) return null;
    return ResourceRef(config.id, item.parent!);
  }

  @override
  Future<BrowseResult> browse(
    BrowseRequest request,
    CallContext context,
  ) async {
    checkOwnership(config.id, request.node, context);
    if (request.offset < 0 ||
        request.limit < 1 ||
        request.limit > 200 ||
        request.search != null) {
      throw PluginException('invalidInput', appStrings.errInvalidPaging);
    }
    final folder = await checked(request.node?.id);
    if (!folder.folder) {
      throw PluginException('invalidInput', appStrings.errChooseFolder);
    }
    // Cursor state is bounded and reconstructible after app restart. API page
    // sizes need not match the host's offset/limit contract.
    final key = '${folder.id}:${request.limit}';
    final cursors = request.offset == 0
        ? (_pages[key] = {0: null})
        : _pages.putIfAbsent(key, () => {0: null});
    if (_pages.length > 32) _pages.remove(_pages.keys.first);
    var offset = cursors.keys
        .where((o) => o <= request.offset)
        .fold(0, (a, b) => a > b ? a : b);
    var cursor = cursors[offset];
    var pages = 0;
    final entries = <SourceEntry>[];
    while (entries.length < request.limit) {
      if (++pages > 10000) {
        throw PluginException('quotaExceeded', appStrings.errScanPageLimit);
      }
      final (files, next) = await children(folder.id, cursor);
      final skip = request.offset > offset ? request.offset - offset : 0;
      for (final file in files.skip(skip)) {
        if (entries.length == request.limit) break;
        entries.add(
          SourceEntry(
            ResourceRef(config.id, file.id),
            file.name,
            isFolder: file.folder,
            size: file.folder ? null : file.size,
          ),
        );
      }
      final end = offset + files.length;
      if (next != null && end > 0) cursors[end] = next;
      if (cursors.length > 128) {
        final remove = cursors.keys
            .where((k) => k != 0 && k != end)
            .firstOrNull;
        if (remove != null) cursors.remove(remove);
      }
      if (request.offset + entries.length < end) {
        return BrowseResult(
          entries,
          nextOffset: request.offset + entries.length,
        );
      }
      if (next == null) return BrowseResult(entries);
      if (next == cursor) {
        throw PluginException('invalidInput', appStrings.errInvalidPaging);
      }
      offset = end;
      cursor = next;
    }
    return BrowseResult(entries, nextOffset: request.offset + entries.length);
  }

  /// Signed links never leave this object. Every local GET/HEAD resolves a
  /// fresh link and can retry once on expiry. No bearer header reaches a CDN.
  Future<HttpClientResponse> content(
    String method,
    String id, {
    String? range,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      var uri = await download(id);
      for (var hop = 0; hop < 6; hop++) {
        checkOpen();
        if (uri.scheme != 'https' ||
            uri.userInfo.isNotEmpty ||
            uri.host.isEmpty) {
          throw PluginException(
            'permissionDenied',
            appStrings.errInvalidServerAddress,
          );
        }
        final request = await client.openUrl(method, uri).timeout(timeout);
        request.followRedirects = false;
        if (range != null) request.headers.set('Range', range);
        final response = await request.close().timeout(timeout);
        if (response.isRedirect) {
          final location = response.headers.value('location');
          await response.drain<void>();
          if (location == null) break;
          uri = uri.resolve(location);
          continue;
        }
        if ((response.statusCode == 401 ||
                response.statusCode == 403 ||
                response.statusCode == 410) &&
            attempt == 0) {
          await response.drain<void>();
          break;
        }
        return response;
      }
    }
    throw PluginException(
      'networkUnavailable',
      appStrings.errSourceUnreachable,
    );
  }

  @override
  Future<PlayableStream> resolve(
    ResolveRequest request,
    CallContext context,
  ) async {
    checkOwnership(config.id, request.resource, context);
    final file = await checked(request.resource.id);
    if (file.folder) {
      throw PluginException('invalidInput', appStrings.errChooseFolder);
    }
    return StreamGateway.serve((request) async {
      await checked(file.id);
      final upstream = await content(
        request.method,
        file.id,
        range: request.headers.value('range'),
      );
      request.response.statusCode = upstream.statusCode;
      for (final key in [
        'content-length',
        'content-type',
        'content-range',
        'accept-ranges',
      ]) {
        final value = upstream.headers.value(key);
        if (value != null) request.response.headers.set(key, value);
      }
      await request.response.addStream(upstream.timeout(timeout));
    }, filename: file.name);
  }

  @override
  Future<List<int>> readAttachment(
    ResourceRef ref,
    CallContext context, {
    required int maxBytes,
  }) async {
    checkOwnership(config.id, ref, context);
    final file = await checked(ref.id);
    validateAttachment(ResourceRef(config.id, file.name), maxBytes);
    if (file.folder || (file.size != null && file.size! > maxBytes)) {
      throw PluginException('quotaExceeded', appStrings.errAttachmentTooLarge);
    }
    final response = await content('GET', file.id);
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw PluginException(
        'networkUnavailable',
        appStrings.errSourceUnreachable,
      );
    }
    return readCapped(response.timeout(timeout), maxBytes);
  }

  @override
  Future<void> dispose() async {
    if (closed) return;
    _cancel.complete();
    session.closeListeners.remove(_onSessionClose);
    if (ownsSession) session.close();
    client.close(force: true);
    _pages.clear();
  }
}
