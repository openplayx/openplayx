import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:smb_connect/smb_connect.dart';

import '../../core/capabilities/source_capability.dart';
import 'source_config.dart';
import '../remote_access/remote_transport.dart';
import 'source_schema.dart';
import 'stream_gateway.dart';
import '../../l10n/l10n.dart';

void checkOwnership(String id, ResourceRef? ref, CallContext context) {
  if (context.instanceId != id || (ref != null && ref.instanceId != id)) {
    throw PluginException(
      'permissionDenied',
      appStrings.errResourceNotThisSource,
    );
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

class LocalFolderPlugin
    implements Plugin, SourceCapability, SourceAttachmentCapability {
  LocalFolderPlugin(this.config);
  final SourceConfig config;
  @override
  PluginManifest get manifest => SourceSchemas.forKind(SourceKind.local);

  Future<String> _path(String? id) async {
    final root = await Directory(config.address).resolveSymbolicLinks();
    final candidate = id ?? root;
    final type = await FileSystemEntity.type(candidate);
    if (type == FileSystemEntityType.notFound) {
      throw PluginException('notFound', appStrings.errFileNotFound);
    }
    final resolved = type == FileSystemEntityType.directory
        ? await Directory(candidate).resolveSymbolicLinks()
        : await File(candidate).resolveSymbolicLinks();
    final separator = Platform.pathSeparator;
    final prefix = root.endsWith(separator) ? root : '$root$separator';
    if (resolved != root && !resolved.startsWith(prefix)) {
      throw PluginException(
        'permissionDenied',
        appStrings.errOutsideAuthorizedFolder,
      );
    }
    final relative = resolved == root
        ? ''
        : resolved.substring(prefix.length).replaceAll('\\', '/');
    if (!config.allows(
      relative,
      directory: type == FileSystemEntityType.directory,
    )) {
      throw PluginException('permissionDenied', appStrings.errOutsideScope);
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
          size: file is File ? (await file.stat()).size : null,
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
      throw PluginException('invalidInput', appStrings.errChooseFile);
    }
    return PlayableStream(file.uri);
  }

  @override
  Future<List<int>> readAttachment(
    ResourceRef ref,
    CallContext context, {
    required int maxBytes,
  }) async {
    checkOwnership(config.id, ref, context);
    validateAttachment(ref, maxBytes);
    final file = File(await _path(ref.id));
    if (await file.length() > maxBytes) {
      throw PluginException('quotaExceeded', appStrings.errAttachmentTooLarge);
    }
    final bytes = <int>[];
    await for (final chunk in file.openRead()) {
      if (bytes.length + chunk.length > maxBytes) {
        throw PluginException(
          'quotaExceeded',
          appStrings.errAttachmentTooLarge,
        );
      }
      bytes.addAll(chunk);
    }
    return bytes;
  }

  @override
  Future<void> dispose() async {}
}

class SmbPlugin
    implements
        Plugin,
        SourceCapability,
        SourceAttachmentCapability,
        SourceWriteCapability {
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
      throw PluginException('permissionDenied', appStrings.errOutsideSmbShare);
    }
    final relative = path == _root
        ? ''
        : path.substring(_root.length + (_root == '/' ? 0 : 1));
    if (!config.allows(relative, directory: directory)) {
      throw PluginException('permissionDenied', appStrings.errOutsideScope);
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
    final path = _path(request.node?.id, directory: true);
    if (path == '/') {
      final List<SmbFile> shares;
      try {
        shares = await _access.run((connection) => connection.listShares());
      } catch (_) {
        throw PluginException('permissionDenied', appStrings.errSmbListShares);
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
    final files = await _access.run((connection) async {
      final folder = await connection.file(path);
      if (!folder.isDirectory()) {
        throw PluginException('invalidInput', appStrings.errChooseFolder);
      }
      return connection.listFiles(folder);
    });
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
              size: file.isDirectory() ? null : file.size,
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
    final path = _path(request.resource.id);
    final (connection, file) = await _access.run((connection) async {
      final file = await connection.file(path);
      if (!file.isExists || file.isDirectory()) {
        throw PluginException('notFound', appStrings.errSmbPlay);
      }
      return (connection, file);
    }, quick: true);
    // Each player range request opens the file anew on whichever connection
    // is live then, so playback resumed after the original connection died
    // (paused in the background, network change) reconnects instead of
    // failing on the dead one.
    Future<SmbFile> fileOn(SmbConnect live) async =>
        identical(live, connection) ? file : await live.file(path);
    return StreamGateway.randomAccess(
      length: file.size,
      filename: file.name,
      open: () => _access.run(
        (live) async => live.open(await fileOn(live)),
        quick: true,
      ),
      progressiveOpen: (ramp) => _access.run(
        (live) async => live.open(await fileOn(live), readRamp: ramp),
        quick: true,
      ),
    );
  }

  @override
  Future<List<int>> readAttachment(
    ResourceRef ref,
    CallContext context, {
    required int maxBytes,
  }) async {
    checkOwnership(config.id, ref, context);
    validateAttachment(ref, maxBytes);
    final path = _path(ref.id);
    return _access.run((connection) async {
      final file = await connection.file(path);
      if (!file.isExists || file.isDirectory()) {
        throw PluginException('notFound', appStrings.errAttachmentNotFound);
      }
      if (file.size > maxBytes) {
        throw PluginException(
          'quotaExceeded',
          appStrings.errAttachmentTooLarge,
        );
      }
      final bytes = <int>[];
      await for (final chunk in await connection.openRead(file)) {
        if (bytes.length + chunk.length > maxBytes) {
          throw PluginException(
            'quotaExceeded',
            appStrings.errAttachmentTooLarge,
          );
        }
        bytes.addAll(chunk);
      }
      return bytes;
    });
  }

  @override
  Future<SourceEntry> writeNewFile(
    ResourceRef near,
    String name,
    File source,
    CallContext context, {
    String? folder,
    SourceWriteCancellation? cancellation,
  }) async {
    checkOwnership(config.id, near, context);
    final nearPath = _path(near.id);
    final segments = nearPath.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      throw const PluginException('invalidInput', 'Select an SMB share first.');
    }
    final share = _root == '/' ? '/${segments.first}' : _root;
    return _write(
      source.openRead(),
      await source.length(),
      name,
      context,
      share,
      folder ?? SourceWriteCapability.folderName,
      cancellation,
    );
  }

  @override
  Future<SourceEntry> writeNewStream(
    Stream<List<int>> stream,
    int length,
    String name,
    CallContext context, {
    String? folder,
    SourceWriteCancellation? cancellation,
  }) => _write(
    stream,
    length,
    name,
    context,
    _root,
    folder ?? 'OpenPlayX/Downloads',
    cancellation,
  );

  Future<SourceEntry> _write(
    Stream<List<int>> stream,
    int length,
    String name,
    CallContext context,
    String root,
    String folder,
    SourceWriteCancellation? cancellation,
  ) async {
    cancellation?.check();
    checkOwnership(config.id, null, context);
    if (root == '/') {
      throw const PluginException(
        'invalidInput',
        'Configure a target SMB share.',
      );
    }
    validateWriteName(name);
    final folderPath = writeFolder(root, folder);
    _path(folderPath, directory: true);
    _path('$folderPath/$name');
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    final token = List.generate(
      12,
      (_) => Random.secure().nextInt(16).toRadixString(16),
    ).join();
    final tmpPath = '$folderPath/.openplayx-$token.part';
    return _access.run((c) async {
      final stop = cancellation?.listen(() {
        unawaited(c.close());
      });
      try {
        cancellation?.check();
        var parent = root;
        for (final segment in folder.split('/').where((s) => s.isNotEmpty)) {
          parent = '$parent/$segment';
          final dir = await c.file(parent);
          if (!dir.isExists) {
            await c.createFolder(parent);
          } else if (!dir.isDirectory()) {
            throw const PluginException('conflict', 'Target folder is a file.');
          }
        }
        var target = name;
        for (var n = 2; (await c.file('$folderPath/$target')).isExists; n++) {
          if (n > 99) {
            throw PluginException('conflict', appStrings.errTooManySameName);
          }
          target = '$stem ($n)$ext';
        }
        if ((await c.file(tmpPath)).isExists) {
          throw PluginException('conflict', appStrings.errTempNameConflict);
        }
        final tmp = await c.createFile(tmpPath);
        try {
          var sink = await c.openWrite(tmp);
          var offset = 0;
          try {
            await for (final chunk in checkedWriteStream(
              stream,
              length,
              cancellation: cancellation,
            )) {
              var skip = 0;
              var failures = 0;
              while (skip < chunk.length) {
                cancellation?.check();
                try {
                  await sink.addStream(Stream.value(chunk.sublist(skip)));
                  // addStream completes only after the SMB consumer has
                  // acknowledged these bytes, keeping at most one chunk.
                  skip = chunk.length;
                } catch (error) {
                  cancellation?.check();
                  if (!(c.transport.isClosed ||
                          error is SocketException ||
                          error is TimeoutException) ||
                      ++failures > 30) {
                    rethrow;
                  }
                  try {
                    await sink.close();
                  } catch (_) {}
                  _access._discard(c);
                  await Future<void>.delayed(const Duration(seconds: 2));
                  cancellation?.check();
                  while (true) {
                    cancellation?.check();
                    try {
                      c = await _access._connect();
                      break;
                    } catch (_) {
                      if (++failures > 30) rethrow;
                      await Future<void>.delayed(const Duration(seconds: 2));
                    }
                  }
                  final partial = await c.file(tmpPath);
                  if (!partial.isExists ||
                      partial.size < offset ||
                      partial.size > offset + chunk.length) {
                    throw const PluginException(
                      'resumeConflict',
                      'Partial destination changed.',
                    );
                  }
                  skip = partial.size - offset;
                  sink = await c.openWrite(partial, append: true);
                }
              }
              offset += chunk.length;
            }
          } finally {
            try {
              await sink.close();
            } catch (_) {}
          }
          final written = await c.file(tmpPath);
          if (written.size != length) {
            throw PluginException(
              'writeFailed',
              appStrings.errUploadIncomplete,
            );
          }
          // Server-side rename without replace: never overwrites a file
          // that appeared meanwhile.
          cancellation?.check();
          await c.rename(written, '$folderPath/$target');
        } catch (_) {
          try {
            await c.delete(await c.file(tmpPath));
          } catch (_) {}
          rethrow;
        }
        final saved = await c.file('$folderPath/$target');
        return SourceEntry(
          ResourceRef(config.id, saved.path),
          saved.name,
          isFolder: false,
        );
      } on PluginException {
        rethrow;
      } catch (_) {
        // Not retried by [SmbAccess.run]: a retry after a rename that did
        // succeed would leave a duplicate copy.
        throw PluginException(
          'writeFailed',
          appStrings.errSmbWrite,
          retryable: true,
        );
      } finally {
        stop?.call();
      }
    });
  }

  @override
  Future<void> dispose() async {
    await _access.close();
  }
}

/// Host transport owns credentials; the plugin receives this scoped client.
///
/// One SMB connection is shared by browsing, resolving and playback reads. It
/// is dropped as soon as its socket ends (mobile OSes abort a backgrounded
/// app's sockets) or a call on it fails, and the next call reconnects, so a
/// dead connection never keeps every later request waiting on timeouts.
class SmbAccess {
  SmbAccess(this.config, this._password, {this.connector});
  final SourceConfig config;
  final String _password;

  /// Replaces the real SMB login in tests. It receives the disconnect hook.
  final Future<SmbConnect> Function(void Function(SmbConnect) onDisconnect)?
  connector;
  Future<SmbConnect>? _connection;
  SmbConnect? _live;
  RemotePathLease? _path;
  bool _closed = false;

  /// Bounds a quick call on a reused connection, which may be half-open
  /// (no FIN after a network change), so the retry still fits in the
  /// caller's request timeout.
  static const staleCallTimeout = Duration(seconds: 8);

  /// A connection silent this long is probed before reuse: after the app was
  /// suspended the socket is often half-open, and every request on it would
  /// otherwise wait out the library's retries (~15 s) before failing.
  static const idleBeforeProbe = Duration(seconds: 15);
  static const probeTimeout = Duration(seconds: 3);

  Future<SmbConnect> _connect() {
    if (_live?.transport.isClosed ?? false) _discard(_live!);
    final pending = _connection;
    if (pending != null) return pending;
    final opening = _open();
    _connection = opening;
    opening.then(
      (connection) {
        if (identical(_connection, opening)) _live = connection;
      },
      onError: (Object _) {
        if (identical(_connection, opening)) _connection = null;
      },
    );
    return opening;
  }

  /// Runs [action] on the shared connection. If it fails for a reason other
  /// than a plugin-level answer, the connection is discarded and [action]
  /// runs once more on a fresh one. [quick] bounds the first attempt by
  /// [staleCallTimeout]; use it only for calls that make a few requests.
  Future<T> run<T>(
    Future<T> Function(SmbConnect connection) action, {
    bool quick = false,
  }) async {
    final connection = await _liveConnection();
    try {
      final attempt = action(connection);
      return await (quick ? attempt.timeout(staleCallTimeout) : attempt);
    } on PluginException {
      rethrow;
    } catch (e) {
      print('DIAG smb run failed ${e.runtimeType}, retrying'); // DIAG
      _discard(connection);
      if (_closed) rethrow;
    }
    return action(await _connect());
  }

  Future<SmbConnect> _liveConnection() async {
    final connection = await _connect();
    print(
      'DIAG smb idle=${connection.transport.idleFor.inSeconds}s closed=${connection.transport.isClosed}',
    ); // DIAG
    if (connection.transport.idleFor < idleBeforeProbe) return connection;
    try {
      await connection.echo().timeout(probeTimeout);
      print('DIAG smb probe ok'); // DIAG
      return connection;
    } catch (e) {
      print('DIAG smb probe failed ${e.runtimeType}'); // DIAG
      _discard(connection);
      if (_closed) rethrow;
      return _connect();
    }
  }

  void _discard(SmbConnect connection) {
    if (!identical(_live, connection)) return;
    _live = null;
    _connection = null;
    final path = _path;
    _path = null;
    // Playback streams opened on it fail and are reopened by the player.
    connection.close().catchError((Object _) {}).whenComplete(() {
      path?.close();
    });
  }

  Future<SmbConnect> _open() async {
    if (_closed) {
      throw PluginException('cancelled', appStrings.errConnectionClosed);
    }
    final path = config.remoteAccess == null
        ? null
        : await RemoteTransport.acquire(config);
    final host = Uri.parse(config.address).host;
    Future<SmbConnect> connect() =>
        connector?.call(_discard) ??
        SmbConnect.connectAuth(
          host: host,
          username: config.username,
          password: _password,
          domain: config.domain,
          onDisconnect: _discard,
        );
    try {
      final connection = path == null
          ? await connect()
          : await path.runWithTcp(connect, logicalHost: host, logicalPort: 445);
      if (_closed) {
        await connection.close();
        path?.close();
        throw PluginException('cancelled', appStrings.errConnectionClosed);
      }
      _path = path;
      return connection;
    } catch (_) {
      path?.close();
      rethrow;
    }
  }

  Future<void> close() async {
    _closed = true;
    final connection = _connection;
    _connection = null;
    _live = null;
    if (connection != null) {
      try {
        await (await connection).close();
      } catch (_) {}
    }
    _path?.close();
    _path = null;
  }
}

void validateAttachment(ResourceRef ref, int maxBytes) {
  if (maxBytes < 1 ||
      maxBytes > 20 * 1024 * 1024 ||
      !RegExp(
        r'\.(nfo|jpg|jpeg|png|webp)$',
        caseSensitive: false,
      ).hasMatch(ref.id)) {
    throw PluginException('invalidInput', appStrings.errAttachmentTypeOrLimit);
  }
}

/// Validate model and remote supplied names before any network operation.
void validateWriteName(String name) {
  if (!RegExp(r'^[^/\\:*?"<>|\x00-\x1f]{1,180}$').hasMatch(name) ||
      name.startsWith('.') ||
      name.trim() != name) {
    throw const PluginException(
      'invalidInput',
      'Invalid destination filename.',
    );
  }
}

String writeFolder(String root, String? folder) {
  folder ??= 'OpenPlayX/Downloads';
  if (folder.startsWith('/') ||
      folder.contains('\\') ||
      folder
          .split('/')
          .any(
            (s) => s == '.' || s == '..' || RegExp(r'[\x00-\x1f]').hasMatch(s),
          )) {
    throw const PluginException(
      'invalidInput',
      'Folder must be relative to the source root.',
    );
  }
  final parts = folder.split('/').where((s) => s.isNotEmpty);
  final suffix = parts.join('/');
  return suffix.isEmpty ? root : '${root == '/' ? '' : root}/$suffix';
}

Stream<List<int>> checkedWriteStream(
  Stream<List<int>> stream,
  int length, {
  SourceWriteCancellation? cancellation,
}) async* {
  cancellation?.check();
  var written = 0;
  await for (final chunk in stream) {
    cancellation?.check();
    written += chunk.length;
    if (written > length) {
      throw const PluginException(
        'lengthMismatch',
        'File is larger than expected.',
      );
    }
    yield chunk;
  }
  cancellation?.check();
  if (written != length) {
    throw const PluginException(
      'lengthMismatch',
      'File transfer was incomplete.',
    );
  }
}

String numberedWriteName(String name, int n) {
  if (n == 1) return name;
  final dot = name.lastIndexOf('.');
  return dot > 0
      ? '${name.substring(0, dot)} ($n)${name.substring(dot)}'
      : '$name ($n)';
}
