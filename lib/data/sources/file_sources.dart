import 'dart:io';

import 'package:smb_connect/smb_connect.dart';

import '../../core/plugins/source_capability.dart';
import 'source_config.dart';
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
  PluginManifest get manifest =>
      const PluginManifest('source.local', '本地文件夹', browseExperience: 'files');

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
    return resolved;
  }

  @override
  Future<BrowseResult> browse(
    BrowseRequest request,
    CallContext context,
  ) async {
    checkOwnership(config.id, request.node, context);
    final directory = Directory(await _path(request.node?.id));
    final entries = <SourceEntry>[];
    await for (final file in directory.list(followLinks: false)) {
      // Symlinks cannot escape the selected directory, and aren't navigated.
      if (file is! File && file is! Directory) continue;
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
  SmbPlugin(this.config, this.password);
  final SourceConfig config;
  final String password;
  Future<SmbConnect>? _connection;
  Future<SmbConnect> _connect() => _connection ??=
      SmbConnect.connectAuth(
        host: Uri.parse(config.address).host,
        username: config.username,
        password: password,
        domain: config.domain,
      ).catchError((Object error) {
        _connection = null;
        throw error;
      });
  String get _root =>
      '/${Uri.parse(config.address).pathSegments.where((s) => s.isNotEmpty).join('/')}';
  String _path(String? path) {
    path ??= _root;
    if (path.contains('\\') ||
        path.split('/').any((s) => s == '..' || s == '.') ||
        (path != _root && !path.startsWith('$_root/'))) {
      throw const PluginException('permissionDenied', '路径超出配置的 SMB 共享。');
    }
    return path;
  }

  @override
  PluginManifest get manifest =>
      const PluginManifest('source.smb', 'SMB', browseExperience: 'files');
  @override
  Future<BrowseResult> browse(
    BrowseRequest request,
    CallContext context,
  ) async {
    checkOwnership(config.id, request.node, context);
    final connection = await _connect();
    final folder = await connection.file(_path(request.node?.id));
    if (!folder.isDirectory()) {
      throw const PluginException('invalidInput', '请选择文件夹。');
    }
    final files = await connection.listFiles(folder);
    return pageEntries(
      files
          .where((f) => f.name != '.' && f.name != '..')
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
    final connection = await _connect();
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
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      try {
        await (await connection).close();
      } catch (_) {}
    }
  }
}
