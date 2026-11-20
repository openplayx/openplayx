import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/capabilities/source_capability.dart';
import '../../l10n/l10n.dart';
import 'cloud_file_source.dart';
import 'file_sources.dart' show checkOwnership;
import 'network_file_sources.dart' show readCapped;

class _BaiduFile extends CloudFile {
  const _BaiduFile(
    super.id,
    super.name, {
    required super.folder,
    super.size,
    required this.path,
  });
  final String path;
}

/// Official xpan read APIs. Resource identities are fs_id, never expiring URLs
/// or user-supplied paths. The synthetic root selects all accessible files.
class BaiduSource extends CloudFileSource {
  BaiduSource(super.config, super.session, {super.client, super.ownsSession});
  static const _all = _BaiduFile('root', '/', folder: true, path: '/');
  @override
  String get apiHost => 'pan.baidu.com';

  PluginException _permission() =>
      PluginException('permissionDenied', appStrings.baiduPermissionDenied);
  PluginException _network() => PluginException(
    'networkUnavailable',
    appStrings.errSourceUnreachable,
    retryable: true,
  );
  void _validateId(String id) {
    if (!RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(id)) {
      throw PluginException('permissionDenied', appStrings.errPathOutsideRoot);
    }
  }

  Future<Map<String, dynamic>> _call(
    String route,
    Map<String, String> fields,
  ) async {
    var refreshed = false;
    try {
      for (var retry = 0; ; retry++) {
        checkOpen();
        final token = await session.access();
        checkOpen();
        final request = await client
            .openUrl(
              'GET',
              Uri.https(apiHost, '/rest/2.0/xpan/$route', {
                ...fields,
                'access_token': token,
              }),
            )
            .timeout(timeout);
        request.followRedirects = false;
        final response = await request.close().timeout(timeout);
        if (response.statusCode == 401 && !refreshed) {
          await response.drain<void>();
          await session.access(force: true, rejectedToken: token);
          refreshed = true;
          continue;
        }
        if (response.statusCode == 403) {
          await response.drain<void>();
          throw _permission();
        }
        if (response.statusCode == 429) {
          final seconds =
              int.tryParse(response.headers.value('retry-after') ?? '') ?? 1;
          await response.drain<void>();
          if (retry >= 3 || seconds > timeout.inSeconds) {
            throw PluginException(
              'rateLimited',
              appStrings.errConnectTimeout,
              retryable: true,
            );
          }
          await delay(Duration(seconds: seconds < 0 ? 0 : seconds));
          continue;
        }
        if (response.statusCode != 200) {
          await response.drain<void>();
          if (response.statusCode == 401) {
            throw PluginException('authRequired', appStrings.cloudReauthorize);
          }
          throw _network();
        }
        final bytes = await readCapped(
          response.timeout(timeout),
          16 * 1024 * 1024,
        );
        checkOpen();
        final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final error = data['errno'] ?? data['error_code'];
        if (error == 0) {
          if (data['list'] is! List) throw _network();
          return data;
        }
        if ({110, 111, 20016, 20017, 31045}.contains(error)) {
          if (refreshed) {
            throw PluginException('authRequired', appStrings.cloudReauthorize);
          }
          await session.access(force: true, rejectedToken: token);
          refreshed = true;
          continue;
        }
        if ({-6, 31023}.contains(error)) throw _permission();
        if (error == -9 || error == 31066) {
          throw PluginException('notFound', appStrings.errSourceUnreachable);
        }
        if (error == 31034) {
          throw PluginException(
            'rateLimited',
            appStrings.errConnectTimeout,
            retryable: true,
          );
        }
        throw _network();
      }
    } on SocketException {
      throw _network();
    } on TimeoutException {
      throw PluginException(
        'networkUnavailable',
        appStrings.errConnectTimeout,
        retryable: true,
      );
    } on FormatException {
      throw _network();
    }
  }

  _BaiduFile _file(Map<String, dynamic> data) {
    final id = '${data['fs_id']}';
    _validateId(id);
    final path = data['path'] as String;
    if (!path.startsWith('/') ||
        path.split('/').any((p) => p == '.' || p == '..')) {
      throw PluginException('permissionDenied', appStrings.errPathOutsideRoot);
    }
    return _BaiduFile(
      id,
      (data['server_filename'] ?? data['filename'] ?? path.split('/').last)
          as String,
      folder: data['isdir'] == 1,
      size: (data['size'] as num?)?.toInt(),
      path: path,
    );
  }

  Future<Map<String, dynamic>> _meta(String id, {bool link = false}) async {
    _validateId(id);
    final data = await _call('multimedia', {
      'method': 'filemetas',
      'fsids': '[$id]',
      'dlink': link ? '1' : '0',
    });
    final files = (data['list'] as List).cast<Map<String, dynamic>>();
    final file = files.where((e) => '${e['fs_id']}' == id).firstOrNull;
    if (file == null) {
      throw PluginException('notFound', appStrings.errSourceUnreachable);
    }
    if (file['errno'] != null && file['errno'] != 0) throw _permission();
    return file;
  }

  @override
  Future<CloudFile> root() async =>
      config.cloudRootId.isEmpty || config.cloudRootId == 'root'
      ? _all
      : metadata(config.cloudRootId);
  @override
  Future<CloudFile> metadata(String id) async =>
      id == 'root' ? _all : _file(await _meta(id));

  @override
  Future<CloudFile> checked(String? id) async {
    final selected = await root() as _BaiduFile;
    if (!selected.folder) {
      throw PluginException('notFound', appStrings.errChooseFolder);
    }
    if (id == null || id == selected.id) return selected;
    final file = await metadata(id) as _BaiduFile;
    if (selected.path == '/' || file.path.startsWith('${selected.path}/')) {
      return file;
    }
    throw PluginException('permissionDenied', appStrings.errPathOutsideRoot);
  }

  Future<(List<CloudFile>, String?)> _list(String path, String? cursor) async {
    final start = int.tryParse(cursor ?? '0');
    if (start == null || start < 0) {
      throw PluginException('invalidInput', appStrings.errInvalidPaging);
    }
    final data = await _call('file', {
      'method': 'list',
      'dir': path,
      'start': '$start',
      'limit': '200',
      'order': 'name',
      'desc': '0',
    });
    final files = (data['list'] as List)
        .cast<Map<String, dynamic>>()
        .map(_file)
        .toList();
    // The list API has no cursor/has_more. A full page needs one more request.
    return (files, files.length == 200 ? '${start + files.length}' : null);
  }

  @override
  Future<(List<CloudFile>, String?)> children(
    String id,
    String? cursor,
  ) async => _list((await checked(id) as _BaiduFile).path, cursor);

  @override
  Future<ResourceRef?> parent(ResourceRef ref, CallContext context) async {
    checkOwnership(config.id, ref, context);
    final file = await checked(ref.id) as _BaiduFile;
    final selected = await root() as _BaiduFile;
    if (file.id == selected.id) return null;
    final slash = file.path.lastIndexOf('/');
    final path = slash == 0 ? '/' : file.path.substring(0, slash);
    if (path == selected.path) return ResourceRef(config.id, selected.id);
    final grandparent = path.substring(0, path.lastIndexOf('/'));
    String? cursor;
    do {
      final (files, next) = await _list(
        grandparent.isEmpty ? '/' : grandparent,
        cursor,
      );
      for (final folder in files.cast<_BaiduFile>()) {
        if (folder.path == path && folder.folder) {
          return ResourceRef(config.id, folder.id);
        }
      }
      cursor = next;
    } while (cursor != null);
    throw PluginException('notFound', appStrings.errSourceUnreachable);
  }

  bool _trusted(Uri uri) =>
      uri.scheme == 'https' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      [
        'baidu.com',
        'baidupcs.com',
      ].any((host) => uri.host == host || uri.host.endsWith('.$host'));

  @override
  Future<Uri> download(String id) async {
    await checked(id);
    final data = await _meta(id, link: true);
    final link = data['dlink'] as String?;
    if (link == null || link.isEmpty) throw _permission();
    final uri = Uri.parse(link);
    if (!_trusted(uri)) throw _permission();
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'access_token': await session.access(),
      },
    );
  }

  @override
  Future<HttpClientResponse> content(
    String method,
    String id, {
    String? range,
  }) async {
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        var uri = await download(id);
        for (var hop = 0; hop < 6; hop++) {
          checkOpen();
          if (!_trusted(uri)) throw _permission();
          final request = await client.openUrl(method, uri).timeout(timeout);
          request.followRedirects = false;
          request.headers.set('User-Agent', 'OpenPlayX pan.baidu.com');
          if (range != null) request.headers.set('Range', range);
          final response = await request.close().timeout(timeout);
          if (response.isRedirect) {
            final location = response.headers.value('location');
            await response.drain<void>();
            if (location == null) throw _network();
            uri = uri.resolve(location);
            continue;
          }
          if ({401, 403, 410}.contains(response.statusCode)) {
            await response.drain<void>();
            if (attempt == 0) break;
            throw _permission();
          }
          if (response.statusCode != 200 && response.statusCode != 206) {
            await response.drain<void>();
            throw _network();
          }
          return response;
        }
      }
      throw _network();
    } on SocketException {
      throw _network();
    } on TimeoutException {
      throw PluginException(
        'networkUnavailable',
        appStrings.errConnectTimeout,
        retryable: true,
      );
    }
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
    // Report account/download restrictions in the UI before handing a loopback
    // URL to the player. Cancel immediately if an upstream ignores Range.
    final probe = await content('GET', file.id, range: 'bytes=0-0');
    await probe.listen((_) {}).cancel();
    return super.resolve(request, context);
  }
}
