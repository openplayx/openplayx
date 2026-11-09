import 'dart:io';

import 'package:smb_connect/smb_connect.dart';

import '../../core/plugins/source_capability.dart';
import 'source_config.dart';
import 'source_schema.dart';
import 'stream_gateway.dart';

void checkOwnership(String id, ResourceRef? ref, CallContext context) {
  if (context.instanceId != id || (ref != null && ref.instanceId != id)) {
    throw const PluginException('permissionDenied', '资源不属于此媒体源。');
  }
}

BrowseResult pageEntries(List<SourceEntry> entries, BrowseRequest request) {
  entries.sort(
    (a, b) => a.isFolder != b.isFolder
        ? (a.isFolder ? -1 : 1)
        : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
  final end = (request.offset + request.limit).clamp(0, entries.length);
  return BrowseResult(
    List.unmodifiable(
      entries.sublist(request.offset.clamp(0, entries.length), end),
    ),
    nextOffset: end < entries.length ? end : null,
  );
}

class LocalFolderPlugin implements Plugin, SourceCapability {
  LocalFolderPlugin(this.config);
  final SourceConfig config;
  @override
  PluginManifest get manifest => SourceSchemas.forKind(SourceKind.local);

  Future<String> _path(String? id) async {
    final root = await Directory(config.address).resolveSymbolicLinks();
    final candidate = id ?? root;
    final type = await FileSystemEntity.type(candidate);
    if (type == FileSystemEntityType.notFound) {
      throw const PluginException('notFound', '文件或文件夹不存在。');
    }
    final resolved = type == FileSystemEntityType.directory
        ? await Directory(candidate).resolveSymbolicLinks()
        : await File(candidate).resolveSymbolicLinks();
    final separator = Platform.pathSeparator;
    final prefix = root.endsWith(separator) ? root : '$root$separator';
    if (resolved != root && !resolved.startsWith(prefix)) {
      throw const PluginException('permissionDenied', '文件超出已授权文件夹。');
    }
    final relative = resolved == root
        ? ''
        : resolved.substring(prefix.length).replaceAll('\\', '/');
    if (!config.allows(
      relative,
      directory: type == FileSystemEntityType.directory,
    )) {
      throw const PluginException('permissionDenied', '目录不在此实例配置的访问范围内。');
    }
    return resolved;
  }

  @override
  Future<BrowseResult> browse(
    BrowseRequest request,
    CallContext context,
  ) async {
    checkOwnership(config.id, request.node, context);
    final directory = Directory(await _path(request.node?.id));
    final root = await Directory(config.address).resolveSymbolicLinks();
    final entries = <SourceEntry>[];
    await for (final file in directory.list(followLinks: false)) {
      // Symlinks cannot escape the selected directory, and aren't navigated.
      if (file is! File && file is! Directory) continue;
      final relative = file.path
          .substring(
            root.endsWith(Platform.pathSeparator)
                ? root.length
                : root.length + 1,
          )
          .replaceAll('\\', '/');
      if (!config.allows(relative, directory: file is Directory)) continue;
      entries.add(
        SourceEntry(
          ResourceRef(config.id, file.path),
          file.uri.pathSegments.where((s) => s.isNotEmpty).last,
          isFolder: file is Directory,
        ),
      );
    }
    return pageEntries(entries, request);
  }

  @override
  Future<PlayableStream> resolve(
    ResolveRequest request,
    CallContext context,
  ) async {
    checkOwnership(config.id, request.resource, context);
    final file = File(await _path(request.resource.id));
    if (await FileSystemEntity.type(file.path) != FileSystemEntityType.file) {
      throw const PluginException('invalidInput', '请选择文件。');
    }
    return PlayableStream(file.uri);
  }

  @override
  Future<void> dispose() async {}
}

class SmbPlugin implements Plugin, SourceCapability {
  SmbPlugin(this.config, String password)
    : _access = SmbAccess(config, password);
  SmbPlugin.withAccess(this.config, this._access);
  final SourceConfig config;
  final SmbAccess _access;
  String get _root =>
      '/${Uri.parse(config.address).pathSegments.where((s) => s.isNotEmpty).join('/')}';
  String _path(String? path, {bool directory = false}) {
    path ??= _root;
    if (path.contains('\\') ||
        path.split('/').any((s) => s == '..' || s == '.') ||
        (path != _root && !path.startsWith(_root == '/' ? '/' : '$_root/'))) {
      throw const PluginException('permissionDenied', '路径超出配置的 SMB 共享。');
    }
    final relative = path == _root
        ? ''
        : path.substring(_root.length + (_root == '/' ? 0 : 1));
    if (!config.allows(relative, directory: directory)) {
      throw const PluginException('permissionDenied', '目录不在此实例配置的访问范围内。');
    }
    return path;
  }

  @override
  PluginManifest get manifest => SourceSchemas.forKind(SourceKind.smb);
  @override
  Future<BrowseResult> browse(
    BrowseRequest request,
    CallContext context,
  ) async {
    checkOwnership(config.id, request.node, context);
    final connection = await _access._connect();
    final path = _path(request.node?.id, directory: true);
    if (path == '/') {
      final List<SmbFile> shares;
      try {
        shares = await connection.listShares();
      } catch (_) {
        throw const PluginException(
          'permissionDenied',
          '无法读取共享列表，请在“高级”中填写共享文件夹路径后重试。',
        );
      }
      return pageEntries(
        shares
            .where(
              (s) =>
                  !s.name.endsWith(r'$') &&
                  config.allows(
                    s.path.replaceFirst(RegExp(r'^/+'), ''),
                    directory: true,
                  ),
            )
            .map(
              (s) => SourceEntry(
                ResourceRef(config.id, s.path),
                s.name,
                isFolder: true,
              ),
            )
            .toList(),
        request,
      );
    }
    final folder = await connection.file(path);
    if (!folder.isDirectory()) {
      throw const PluginException('invalidInput', '请选择文件夹。');
    }
    final files = await connection.listFiles(folder);
    return pageEntries(
      files
          .where(
            (f) =>
                f.name != '.' &&
                f.name != '..' &&
                config.allows(
                  f.path
                      .substring(_root.length)
                      .replaceFirst(RegExp(r'^/+'), ''),
                  directory: f.isDirectory(),
                ),
          )
          .map(
            (file) => SourceEntry(
              ResourceRef(config.id, file.path),
              file.name,
              isFolder: file.isDirectory(),
            ),
          )
          .toList(),
      request,
    );
  }

  @override
  Future<PlayableStream> resolve(
    ResolveRequest request,
    CallContext context,
  ) async {
    checkOwnership(config.id, request.resource, context);
    final connection = await _access._connect();
    final file = await connection.file(_path(request.resource.id));
    if (!file.isExists || file.isDirectory()) {
      throw const PluginException('notFound', '无法播放该 SMB 文件。');
    }
    return StreamGateway.randomAccess(
      length: file.size,
      filename: file.name,
      open: () => connection.open(file),
    );
  }

  @override
  Future<void> dispose() async {
    await _access.close();
  }
}

/// Host transport owns credentials; the plugin receives this scoped client.
class SmbAccess {
  SmbAccess(this.config, this._password);
  final SourceConfig config;
  final String _password;
  Future<SmbConnect>? _connection;
  Future<SmbConnect> _connect() => _connection ??=
      SmbConnect.connectAuth(
        host: Uri.parse(config.address).host,
        username: config.username,
        password: _password,
        domain: config.domain,
      ).catchError((Object error) {
        _connection = null;
        throw error;
      });
  Future<void> close() async {
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      try {
        await (await connection).close();
      } catch (_) {}
    }
  }
}
