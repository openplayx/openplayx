import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:xml/xml.dart';

import '../../core/plugins/source_capability.dart';
import 'file_sources.dart';
import 'source_config.dart';
import 'source_schema.dart';
import 'stream_gateway.dart';

/// Keeps resource paths of a remote file source inside its configured root
/// and access scope. Paths are decoded and absolute ("/share/Movies/a.mkv").
class RemotePaths {
  RemotePaths(this.config);
  final SourceConfig config;
  String get root => config.rootPath;

  String check(String? path, {bool directory = false}) {
    path ??= root;
    if (!path.startsWith('/') ||
        path.contains('\\') ||
        path.split('/').any((s) => s == '..' || s == '.') ||
        (path != root && !path.startsWith(root == '/' ? '/' : '$root/'))) {
      throw const PluginException('permissionDenied', '路径超出配置的根目录。');
    }
    if (!config.allows(relative(path), directory: directory)) {
      throw const PluginException('permissionDenied', '目录不在此实例配置的访问范围内。');
    }
    return path;
  }

  String relative(String path) =>
      path == root ? '' : path.substring(root == '/' ? 1 : root.length + 1);

  bool visible(String path, {required bool directory}) =>
      config.allows(relative(path), directory: directory);

  static String join(String parent, String name) =>
      parent == '/' ? '/$name' : '$parent/$name';

  static String name(String path) =>
      path.split('/').lastWhere((s) => s.isNotEmpty, orElse: () => path);
}

class RemoteFile {
  const RemoteFile(this.path, {required this.folder, this.size});
  final String path;
  final bool folder;
  final int? size;
  String get name => RemotePaths.name(path);
}

Iterable<XmlElement> xmlElements(XmlNode node, String local) => node.descendants
    .whereType<XmlElement>()
    .where((e) => e.name.local == local);

String? xmlText(XmlNode node, String local) =>
    xmlElements(node, local).firstOrNull?.innerText.trim();

Future<List<int>> readCapped(Stream<List<int>> stream, int maxBytes) async {
  final bytes = <int>[];
  await for (final chunk in stream) {
    if (bytes.length + chunk.length > maxBytes) {
      throw const PluginException('quotaExceeded', '附件过大');
    }
    bytes.addAll(chunk);
  }
  return bytes;
}

/// Shared browse/resolve/attachment flow for path-addressed remote sources.
/// A directory listing is cached briefly so later pages don't refetch it.
abstract class RemoteFilePlugin
    implements Plugin, SourceCapability, SourceAttachmentCapability {
  RemoteFilePlugin(this.config) : paths = RemotePaths(config);
  final SourceConfig config;
  final RemotePaths paths;
  final _listings = <String, (DateTime, List<RemoteFile>)>{};

  Future<List<RemoteFile>> list(String path);
  Future<PlayableStream> open(String path, String name);
  Future<List<int>> read(String path, int maxBytes);

  @override
  PluginManifest get manifest => SourceSchemas.forKind(config.kind);

  @override
  Future<BrowseResult> browse(
    BrowseRequest request,
    CallContext context,
  ) async {
    checkOwnership(config.id, request.node, context);
    final path = paths.check(request.node?.id, directory: true);
    final cached = _listings[path];
    final List<RemoteFile> files;
    if (request.offset > 0 &&
        cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(minutes: 1)) {
      files = cached.$2;
    } else {
      files = await list(path);
      _listings[path] = (DateTime.now(), files);
      if (_listings.length > 32) _listings.remove(_listings.keys.first);
    }
    return pageEntries(
      files
          .where(
            (f) =>
                f.name != '.' &&
                f.name != '..' &&
                f.path != path &&
                paths.visible(f.path, directory: f.folder),
          )
          .map(
            (f) => SourceEntry(
              ResourceRef(config.id, f.path),
              f.name,
              isFolder: f.folder,
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
    final path = paths.check(request.resource.id);
    return open(path, RemotePaths.name(path));
  }

  @override
  Future<List<int>> readAttachment(
    ResourceRef ref,
    CallContext context, {
    required int maxBytes,
  }) async {
    checkOwnership(config.id, ref, context);
    validateAttachment(ref, maxBytes);
    return read(paths.check(ref.id), maxBytes);
  }

  Duration get timeout => Duration(seconds: config.requestTimeoutSeconds);
}

PluginException _httpFailure(int status, String service) => PluginException(
  status == 401 || status == 403
      ? 'authRequired'
      : status == 404
      ? 'notFound'
      : 'networkUnavailable',
  status == 401 || status == 403
      ? '$service 拒绝访问（HTTP $status），请检查用户名和密码。'
      : status == 404
      ? '文件或文件夹不存在。'
      : '$service 请求失败（HTTP $status）。',
  retryable: status >= 500,
);

// ---------------------------------------------------------------- WebDAV --

class WebDavPlugin extends RemoteFilePlugin {
  WebDavPlugin(super.config, this._password) {
    _client.authenticate = (uri, scheme, realm) async {
      if (config.username.isEmpty || !_sameOrigin(uri)) return false;
      _client.addCredentials(
        _base.replace(path: '/'),
        realm ?? '',
        scheme.toLowerCase() == 'digest'
            ? HttpClientDigestCredentials(config.username, _password)
            : HttpClientBasicCredentials(config.username, _password),
      );
      return true;
    };
  }
  final String _password;
  late final HttpClient _client = HttpClient()
    ..connectionTimeout = timeout
    ..maxConnectionsPerHost = config.maxConcurrentRequests;
  Uri get _base => Uri.parse(config.address);

  Map<String, String> get _headers => {
    if (config.username.isNotEmpty)
      'Authorization':
          'Basic ${base64Encode(utf8.encode('${config.username}:$_password'))}',
  };

  bool _sameOrigin(Uri uri) =>
      uri.scheme == _base.scheme &&
      uri.host == _base.host &&
      uri.port == _base.port;

  Uri _uri(String path, {bool folder = false}) => Uri(
    scheme: _base.scheme,
    host: _base.host,
    port: _base.port,
    pathSegments: [
      ...path.split('/').where((s) => s.isNotEmpty),
      if (folder && path != '/') '',
    ],
  );

  Future<HttpClientResponse> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final request = await _client.openUrl(method, uri);
    request.followRedirects = false;
    ({..._headers, ...headers}).forEach(request.headers.set);
    if (body != null) {
      // Explicit length: not every WebDAV server accepts a chunked body.
      final bytes = utf8.encode(body);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/xml; charset=utf-8',
      );
      request.contentLength = bytes.length;
      request.add(bytes);
    }
    return request.close().timeout(
      timeout,
      onTimeout: () {
        request.abort();
        throw TimeoutException('WebDAV');
      },
    );
  }

  static const _propfind =
      '<?xml version="1.0" encoding="utf-8"?>'
      '<d:propfind xmlns:d="DAV:"><d:prop>'
      '<d:resourcetype/><d:getcontentlength/>'
      '</d:prop></d:propfind>';

  @override
  Future<List<RemoteFile>> list(String path) async {
    final response = await _send(
      'PROPFIND',
      _uri(path, folder: true),
      headers: {'Depth': '1'},
      body: _propfind,
    );
    if (response.statusCode != 207) {
      await response.drain<void>();
      throw _httpFailure(response.statusCode, 'WebDAV');
    }
    final text = await utf8.decoder.bind(response).join().timeout(timeout);
    return parseWebDavListing(text, path);
  }

  /// Files are served through the loopback gateway; a redirect (common for
  /// cloud-drive gateways such as Alist) is followed first, without passing
  /// credentials to another host.
  @override
  Future<PlayableStream> open(String path, String name) async {
    var uri = _uri(path);
    var headers = _headers;
    for (var hop = 0; hop < 5; hop++) {
      final response = await _send(
        'GET',
        uri,
        headers: {...headers, 'Range': 'bytes=0-0'},
      );
      final location = response.headers.value('location');
      await response.drain<void>().catchError((_) {});
      if (response.isRedirect && location != null) {
        uri = uri.resolve(location);
        if (!_sameOrigin(uri)) headers = const {};
        continue;
      }
      if (response.statusCode >= 400) {
        throw _httpFailure(response.statusCode, 'WebDAV');
      }
      break;
    }
    final same = _sameOrigin(uri);
    return StreamGateway.http(
      uri,
      same ? headers : const {},
      filename: name,
      sharedClient: same ? _client : null,
    );
  }

  @override
  Future<List<int>> read(String path, int maxBytes) async {
    final response = await _send('GET', _uri(path));
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw _httpFailure(response.statusCode, 'WebDAV');
    }
    return readCapped(response, maxBytes);
  }

  @override
  Future<void> dispose() async => _client.close(force: true);
}

/// Parses a PROPFIND multistatus body into the children of [path].
List<RemoteFile> parseWebDavListing(String body, String path) {
  final document = XmlDocument.parse(body);
  final files = <RemoteFile>[];
  for (final response in xmlElements(document, 'response')) {
    final href = xmlText(response, 'href');
    if (href == null || href.isEmpty) continue;
    final segments = Uri.parse(href).pathSegments.where((s) => s.isNotEmpty);
    final child = '/${segments.join('/')}';
    if (child == path || segments.isEmpty) continue;
    final parent = child.substring(0, child.lastIndexOf('/'));
    if ((parent.isEmpty ? '/' : parent) != path) continue;
    files.add(
      RemoteFile(
        child,
        folder: xmlElements(response, 'collection').isNotEmpty,
        size: int.tryParse(xmlText(response, 'getcontentlength') ?? ''),
      ),
    );
  }
  return files;
}

// ------------------------------------------------------------------- FTP --

class FtpReply {
  const FtpReply(this.code, this.text);
  final int code;
  final String text;
}

/// Minimal passive-mode FTP client (binary transfers, MLSD with LIST
/// fallback, REST for ranged reads).
class FtpConnection {
  FtpConnection._(this._socket, this._lines, this._timeout);
  final Socket _socket;
  final StreamIterator<String> _lines;
  final Duration _timeout;

  static Future<FtpConnection> connect(
    SourceConfig config,
    String password,
  ) async {
    final uri = Uri.parse(config.address);
    final timeout = Duration(seconds: config.requestTimeoutSeconds);
    final socket = await Socket.connect(
      uri.host,
      uri.hasPort ? uri.port : 21,
      timeout: timeout,
    );
    final lines = StreamIterator(
      socket
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter()),
    );
    final connection = FtpConnection._(socket, lines, timeout);
    try {
      final greeting = await connection._read();
      if (greeting.code != 220) {
        throw const PluginException('networkUnavailable', 'FTP 服务器拒绝连接。');
      }
      final anonymous = config.username.isEmpty;
      var reply = await connection.command(
        'USER ${anonymous ? 'anonymous' : config.username}',
      );
      if (reply.code == 331) {
        reply = await connection.command(
          'PASS ${anonymous ? 'anonymous@' : password}',
        );
      }
      if (reply.code != 230 && reply.code != 202) {
        throw const PluginException('authRequired', 'FTP 登录失败，请检查用户名和密码。');
      }
      await connection.command('OPTS UTF8 ON');
      if ((await connection.command('TYPE I')).code != 200) {
        throw const PluginException('unsupported', 'FTP 服务器不支持二进制传输。');
      }
    } catch (_) {
      connection.close();
      rethrow;
    }
    return connection;
  }

  Future<String> _line() async {
    if (!await _lines.moveNext().timeout(_timeout)) {
      throw const SocketException('FTP control connection closed');
    }
    return _lines.current;
  }

  Future<FtpReply> _read() async {
    final first = await _line();
    final code = int.tryParse(first.length >= 3 ? first.substring(0, 3) : '');
    if (code == null) throw const FormatException('Invalid FTP reply');
    final text = StringBuffer(first.length > 4 ? first.substring(4) : '');
    if (first.length > 3 && first[3] == '-') {
      while (true) {
        final line = await _line();
        if (line.startsWith('$code ')) break;
        text.writeln(line);
      }
    }
    return FtpReply(code, text.toString());
  }

  Future<FtpReply> command(String command) {
    if (command.contains('\r') || command.contains('\n')) {
      throw const PluginException('invalidInput', '路径包含不支持的字符。');
    }
    _socket.write('$command\r\n');
    return _read();
  }

  Future<Socket> _passive() async {
    // The advertised address is ignored (NAT); data goes to the same host.
    var reply = await command('EPSV');
    int? port;
    if (reply.code == 229) {
      port = int.tryParse(
        RegExp(r'\|\|\|(\d+)\|').firstMatch(reply.text)?[1] ?? '',
      );
    }
    if (port == null) {
      reply = await command('PASV');
      final numbers = RegExp(r'(\d+),(\d+),(\d+),(\d+),(\d+),(\d+)')
          .firstMatch(reply.text);
      if (reply.code != 227 || numbers == null) {
        throw const PluginException('unsupported', 'FTP 服务器不支持被动模式。');
      }
      port = int.parse(numbers[5]!) * 256 + int.parse(numbers[6]!);
    }
    return Socket.connect(_socket.remoteAddress, port, timeout: _timeout);
  }

  Future<List<RemoteFile>> list(String path) async {
    var data = await _passive();
    var reply = await command('MLSD $path');
    var machine = true;
    if (reply.code >= 500 && reply.code != 550) {
      data.destroy();
      data = await _passive();
      reply = await command('LIST $path');
      machine = false;
    }
    if (reply.code != 150 && reply.code != 125) {
      data.destroy();
      throw PluginException(
        reply.code == 550 ? 'notFound' : 'networkUnavailable',
        reply.code == 550 ? '文件夹不存在或无权访问。' : 'FTP 无法列出文件夹。',
      );
    }
    final text = await data
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .join()
        .timeout(_timeout);
    await _read();
    return parseFtpListing(text, path, machine: machine);
  }

  Future<int?> size(String path) async {
    final reply = await command('SIZE $path');
    return reply.code == 213 ? int.tryParse(reply.text.trim()) : null;
  }

  Stream<List<int>> retrieve(String path, int offset) async* {
    final data = await _passive();
    try {
      if (offset > 0 && (await command('REST $offset')).code != 350) {
        throw const PluginException('unsupported', 'FTP 服务器不支持断点续传，无法拖动进度。');
      }
      final reply = await command('RETR $path');
      if (reply.code != 150 && reply.code != 125) {
        throw const PluginException('notFound', '无法读取该 FTP 文件。');
      }
      yield* data;
    } finally {
      data.destroy();
    }
  }

  void close() {
    try {
      _socket.write('QUIT\r\n');
    } catch (_) {}
    _socket.destroy();
  }
}

final _unixList = RegExp(
  r'^([\-dlbcps])\S{9}\S*\s+\d+\s+\S+\s+\S+\s+(\d+)\s+\w{3}\s+\d{1,2}\s+[\d:]{4,5}\s+(.+)$',
);
final _dosList = RegExp(
  r'^\d{2}-\d{2}-\d{2,4}\s+\d{1,2}:\d{2}\s*(?:AM|PM)?\s+(<DIR>|\d+)\s+(.+)$',
  caseSensitive: false,
);

/// Parses MLSD facts or a Unix/DOS style LIST into the children of [path].
List<RemoteFile> parseFtpListing(
  String text,
  String path, {
  required bool machine,
}) {
  final files = <RemoteFile>[];
  for (final line in const LineSplitter().convert(text)) {
    if (line.trim().isEmpty) continue;
    if (machine) {
      final space = line.indexOf(' ');
      if (space < 0) continue;
      final facts = <String, String>{
        for (final fact in line.substring(0, space).split(';'))
          if (fact.contains('='))
            fact.substring(0, fact.indexOf('=')).toLowerCase(): fact.substring(
              fact.indexOf('=') + 1,
            ),
      };
      final name = line.substring(space + 1);
      final type = facts['type']?.toLowerCase();
      if (type == 'cdir' || type == 'pdir' || name.contains('/')) continue;
      files.add(
        RemoteFile(
          RemotePaths.join(path, name),
          folder: type == 'dir',
          size: int.tryParse(facts['size'] ?? ''),
        ),
      );
      continue;
    }
    final unix = _unixList.firstMatch(line);
    if (unix != null) {
      var name = unix[3]!;
      if (unix[1] == 'l') name = name.split(' -> ').first;
      if (name.contains('/')) continue;
      files.add(
        RemoteFile(
          RemotePaths.join(path, name),
          folder: unix[1] == 'd',
          size: int.tryParse(unix[2]!),
        ),
      );
      continue;
    }
    final dos = _dosList.firstMatch(line);
    if (dos != null && !dos[2]!.contains('/')) {
      files.add(
        RemoteFile(
          RemotePaths.join(path, dos[2]!),
          folder: dos[1]!.toUpperCase() == '<DIR>',
          size: int.tryParse(dos[1]!),
        ),
      );
    }
  }
  return files;
}

class FtpPlugin extends RemoteFilePlugin {
  FtpPlugin(super.config, this._password);
  final String _password;
  Future<FtpConnection>? _control;
  Future<void> _queue = Future.value();

  /// One control connection for listings, used by one request at a time.
  Future<T> _withControl<T>(Future<T> Function(FtpConnection) action) {
    final result = _queue.then((_) async {
      final connection = await (_control ??= FtpConnection.connect(
        config,
        _password,
      ));
      try {
        return await action(connection);
      } catch (_) {
        _control = null;
        connection.close();
        rethrow;
      }
    });
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<List<RemoteFile>> list(String path) =>
      _withControl((c) => c.list(path));

  /// Each range request gets its own connection, so seeking restarts the
  /// transfer at the requested offset.
  @override
  Future<PlayableStream> open(String path, String name) async {
    final length = await _withControl((c) => c.size(path));
    if (length == null) {
      throw const PluginException('unsupported', 'FTP 服务器未返回文件大小，无法播放。');
    }
    return StreamGateway.ranged(
      length: length,
      filename: name,
      read: (start, end) async* {
        final connection = await FtpConnection.connect(config, _password);
        try {
          yield* connection.retrieve(path, start);
        } finally {
          connection.close();
        }
      },
    );
  }

  @override
  Future<List<int>> read(String path, int maxBytes) async {
    final length = await _withControl((c) => c.size(path));
    if (length != null && length > maxBytes) {
      throw const PluginException('quotaExceeded', '附件过大');
    }
    final connection = await FtpConnection.connect(config, _password);
    try {
      return await readCapped(connection.retrieve(path, 0), maxBytes);
    } finally {
      connection.close();
    }
  }

  @override
  Future<void> dispose() async {
    final control = _control;
    _control = null;
    if (control != null) {
      try {
        (await control).close();
      } catch (_) {}
    }
  }
}

// ------------------------------------------------------------------ SFTP --

class SftpPlugin extends RemoteFilePlugin {
  SftpPlugin(super.config, this._password);
  final String _password;
  Future<(SSHClient, SftpClient)>? _session;

  Future<SftpClient> _sftp() async {
    final session = await (_session ??= _connect().catchError((Object error) {
      _session = null;
      throw error;
    }));
    return session.$2;
  }

  Future<(SSHClient, SftpClient)> _connect() async {
    final uri = Uri.parse(config.address);
    final socket = await SSHSocket.connect(
      uri.host,
      uri.hasPort ? uri.port : 22,
      timeout: timeout,
    );
    final client = SSHClient(
      socket,
      username: config.username,
      onPasswordRequest: () => _password,
      onUserInfoRequest: (request) => [
        for (final _ in request.prompts) _password,
      ],
    );
    try {
      await client.authenticated.timeout(timeout);
    } catch (_) {
      client.close();
      throw const PluginException('authRequired', 'SFTP 登录失败，请检查用户名和密码。');
    }
    try {
      return (client, await client.sftp());
    } catch (_) {
      client.close();
      throw const PluginException('unsupported', '服务器未启用 SFTP。');
    }
  }

  PluginException _failure(Object error) => error is SftpStatusError
      ? PluginException(
          error.code == SftpStatusCode.noSuchFile
              ? 'notFound'
              : error.code == SftpStatusCode.permissionDenied
              ? 'permissionDenied'
              : 'networkUnavailable',
          error.code == SftpStatusCode.noSuchFile
              ? '文件或文件夹不存在。'
              : error.code == SftpStatusCode.permissionDenied
              ? '没有权限访问该路径。'
              : 'SFTP 请求失败。',
        )
      : error is PluginException
      ? error
      : const PluginException('networkUnavailable', 'SFTP 连接失败。');

  @override
  Future<List<RemoteFile>> list(String path) async {
    final sftp = await _sftp();
    try {
      final files = <RemoteFile>[];
      for (final entry in await sftp.listdir(path)) {
        if (entry.filename == '.' || entry.filename == '..') continue;
        final child = RemotePaths.join(path, entry.filename);
        var attr = entry.attr;
        if (attr.isSymbolicLink) {
          try {
            attr = await sftp.stat(child);
          } catch (_) {
            continue; // Dangling link.
          }
        }
        if (!attr.isDirectory && !attr.isFile) continue;
        files.add(RemoteFile(child, folder: attr.isDirectory, size: attr.size));
      }
      return files;
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<PlayableStream> open(String path, String name) async {
    final sftp = await _sftp();
    final SftpFileAttrs attr;
    try {
      attr = await sftp.stat(path);
    } catch (error) {
      throw _failure(error);
    }
    if (!attr.isFile || attr.size == null) {
      throw const PluginException('notFound', '无法播放该 SFTP 文件。');
    }
    return StreamGateway.ranged(
      length: attr.size!,
      filename: name,
      read: (start, end) async* {
        final file = await (await _sftp()).open(path);
        try {
          yield* file.read(offset: start, length: end - start + 1);
        } finally {
          await file.close();
        }
      },
    );
  }

  @override
  Future<List<int>> read(String path, int maxBytes) async {
    final sftp = await _sftp();
    try {
      final attr = await sftp.stat(path);
      if ((attr.size ?? 0) > maxBytes) {
        throw const PluginException('quotaExceeded', '附件过大');
      }
      final file = await sftp.open(path);
      try {
        return await file.readBytes(length: attr.size);
      } finally {
        await file.close();
      }
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<void> dispose() async {
    final session = _session;
    _session = null;
    if (session != null) {
      try {
        (await session).$1.close();
      } catch (_) {}
    }
  }
}

// -------------------------------------------------------------------- S3 --

/// AWS Signature Version 4 for S3-compatible services (path-style requests).
class S3Signer {
  const S3Signer({
    required this.accessKey,
    required this.secretKey,
    required this.region,
  });
  final String accessKey;
  final String secretKey;
  final String region;
  static const emptyHash =
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

  static String encode(String value, {bool keepSlash = false}) {
    final out = StringBuffer();
    for (final byte in utf8.encode(value)) {
      final c = String.fromCharCode(byte);
      if (RegExp(r'[A-Za-z0-9\-_.~]').hasMatch(c) || (keepSlash && c == '/')) {
        out.write(c);
      } else {
        out.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return out.toString();
  }

  static String canonicalQuery(Map<String, String> query) {
    final pairs =
        query.entries.map((e) => (encode(e.key), encode(e.value))).toList()
          ..sort((a, b) => a.$1.compareTo(b.$1));
    return pairs.map((p) => '${p.$1}=${p.$2}').join('&');
  }

  static String hostHeader(Uri base) =>
      base.hasPort &&
          !(base.scheme == 'http' && base.port == 80) &&
          !(base.scheme == 'https' && base.port == 443)
      ? '${base.host}:${base.port}'
      : base.host;

  static String _stamp(DateTime time) {
    final t = time.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}T'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}Z';
  }

  List<int> _key(String date) {
    List<int> mac(List<int> key, String data) =>
        Hmac(sha256, key).convert(utf8.encode(data)).bytes;
    return mac(
      mac(mac(mac(utf8.encode('AWS4$secretKey'), date), region), 's3'),
      'aws4_request',
    );
  }

  String _signature(String date, String stamp, String scope, String request) {
    final toSign = [
      'AWS4-HMAC-SHA256',
      stamp,
      scope,
      sha256.convert(utf8.encode(request)).toString(),
    ].join('\n');
    return Hmac(sha256, _key(date)).convert(utf8.encode(toSign)).toString();
  }

  /// URL for [decodedPath] with the signature in the query, valid for
  /// [expires] (a playback session doesn't outlive header-signature limits).
  Uri presign(
    Uri base,
    String decodedPath,
    DateTime now, {
    Duration expires = const Duration(hours: 12),
  }) {
    final stamp = _stamp(now);
    final date = stamp.substring(0, 8);
    final scope = '$date/$region/s3/aws4_request';
    final path = encode(decodedPath, keepSlash: true);
    final host = hostHeader(base);
    final query = canonicalQuery({
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': '$accessKey/$scope',
      'X-Amz-Date': stamp,
      'X-Amz-Expires': '${expires.inSeconds}',
      'X-Amz-SignedHeaders': 'host',
    });
    final request = [
      'GET',
      path,
      query,
      'host:$host',
      '',
      'host',
      'UNSIGNED-PAYLOAD',
    ].join('\n');
    final signature = _signature(date, stamp, scope, request);
    return Uri.parse(
      '${base.scheme}://$host$path?$query&X-Amz-Signature=$signature',
    );
  }

  /// Headers for a GET of [decodedPath] with [query] at [now].
  Map<String, String> sign(
    Uri base,
    String decodedPath,
    Map<String, String> query,
    DateTime now,
  ) {
    final stamp = _stamp(now);
    final date = stamp.substring(0, 8);
    final scope = '$date/$region/s3/aws4_request';
    const signed = 'host;x-amz-content-sha256;x-amz-date';
    final request = [
      'GET',
      encode(decodedPath, keepSlash: true),
      canonicalQuery(query),
      'host:${hostHeader(base)}',
      'x-amz-content-sha256:$emptyHash',
      'x-amz-date:$stamp',
      '',
      signed,
      emptyHash,
    ].join('\n');
    final signature = _signature(date, stamp, scope, request);
    return {
      'x-amz-date': stamp,
      'x-amz-content-sha256': emptyHash,
      'Authorization':
          'AWS4-HMAC-SHA256 Credential=$accessKey/$scope, '
          'SignedHeaders=$signed, Signature=$signature',
    };
  }
}

/// Buckets and key prefixes as folders. The address is the endpoint plus an
/// optional bucket and prefix (`https://s3.example.com/bucket/videos`); the
/// region comes from the domain field. Without keys, requests are anonymous.
class S3Plugin extends RemoteFilePlugin {
  S3Plugin(super.config, String secret)
    : _signer = config.username.isEmpty
          ? null
          : S3Signer(
              accessKey: config.username,
              secretKey: secret,
              region: config.domain.trim().isEmpty
                  ? 'us-east-1'
                  : config.domain.trim(),
            );
  final S3Signer? _signer;
  late final HttpClient _client = HttpClient()
    ..connectionTimeout = timeout
    ..maxConnectionsPerHost = config.maxConcurrentRequests;
  Uri get _base => Uri.parse(config.address);

  Uri _url(String decodedPath, [Map<String, String> query = const {}]) =>
      Uri.parse(
        '${_base.scheme}://${S3Signer.hostHeader(_base)}'
        '${S3Signer.encode(decodedPath, keepSlash: true)}'
        '${query.isEmpty ? '' : '?${S3Signer.canonicalQuery(query)}'}',
      );

  Future<HttpClientResponse> _get(
    String decodedPath, [
    Map<String, String> query = const {},
  ]) async {
    final request = await _client.getUrl(_url(decodedPath, query));
    request.followRedirects = false;
    _signer
        ?.sign(_base, decodedPath, query, DateTime.now())
        .forEach(request.headers.set);
    final response = await request.close().timeout(
      timeout,
      onTimeout: () {
        request.abort();
        throw TimeoutException('S3');
      },
    );
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw _httpFailure(response.statusCode, 'S3');
    }
    return response;
  }

  Future<XmlDocument> _xml(
    String path, [
    Map<String, String> query = const {},
  ]) async => XmlDocument.parse(
    await utf8.decoder.bind(await _get(path, query)).join().timeout(timeout),
  );

  @override
  Future<List<RemoteFile>> list(String path) async {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      final document = await _xml('/');
      return [
        for (final bucket in xmlElements(document, 'Bucket'))
          if (xmlText(bucket, 'Name') case final name? when name.isNotEmpty)
            RemoteFile('/$name', folder: true),
      ];
    }
    final bucket = segments.first;
    final key = segments.skip(1).join('/');
    final prefix = key.isEmpty ? '' : '$key/';
    final files = <RemoteFile>[];
    String? token;
    for (var page = 0; page < 20; page++) {
      final document = await _xml('/$bucket', {
        'list-type': '2',
        'delimiter': '/',
        'prefix': prefix,
        'continuation-token': ?token,
      });
      for (final common in xmlElements(document, 'CommonPrefixes')) {
        final value = xmlText(common, 'Prefix');
        if (value == null || !value.startsWith(prefix)) continue;
        final name = value.substring(prefix.length).replaceAll('/', '');
        if (name.isEmpty) continue;
        files.add(RemoteFile(RemotePaths.join(path, name), folder: true));
      }
      for (final object in xmlElements(document, 'Contents')) {
        final value = xmlText(object, 'Key');
        if (value == null || !value.startsWith(prefix)) continue;
        final name = value.substring(prefix.length);
        if (name.isEmpty || name.contains('/')) continue;
        files.add(
          RemoteFile(
            RemotePaths.join(path, name),
            folder: false,
            size: int.tryParse(xmlText(object, 'Size') ?? ''),
          ),
        );
      }
      token = xmlText(document, 'NextContinuationToken');
      if (xmlText(document, 'IsTruncated') != 'true' || token == null) break;
    }
    return files;
  }

  @override
  Future<PlayableStream> open(String path, String name) async {
    if (path.split('/').where((s) => s.isNotEmpty).length < 2) {
      throw const PluginException('invalidInput', '请选择文件。');
    }
    final url = _signer?.presign(_base, path, DateTime.now()) ?? _url(path);
    return StreamGateway.http(
      url,
      const {},
      filename: name,
      sharedClient: _client,
    );
  }

  @override
  Future<List<int>> read(String path, int maxBytes) async =>
      readCapped(await _get(path), maxBytes);

  @override
  Future<void> dispose() async => _client.close(force: true);
}
