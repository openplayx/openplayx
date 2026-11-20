import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/sources/file_sources.dart';
import 'package:openplayx/data/sources/network_file_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';

class _Ssh implements SSHClient {
  @override
  void close() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _File implements SftpFile {
  _File(this.data, this.fs);
  final _Sftp fs;
  final List<int> data;
  @override
  Future<void> writeBytes(Uint8List bytes, {int offset = 0}) async {
    expect(offset, lessThanOrEqualTo(data.length));
    while (data.length < offset + bytes.length) {
      data.add(0);
    }
    data.setRange(offset, offset + bytes.length, bytes);
    if (fs.failOnceNetwork) {
      fs.failOnceNetwork = false;
      throw const SocketException('lost acknowledgement');
    }
  }

  @override
  Future<void> close() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sftp implements SftpClient {
  final files = <String, List<int>>{};
  bool failOnceNetwork = false;
  final folders = <String>{'/'};
  @override
  Future<SftpFileAttrs> stat(String path, {bool followLink = true}) async {
    if (folders.contains(path)) {
      return SftpFileAttrs(mode: const SftpFileMode.value(0x4000));
    }
    if (files.containsKey(path)) {
      return SftpFileAttrs(
        mode: const SftpFileMode.value(0x8000),
        size: files[path]!.length,
      );
    }
    throw SftpStatusError(SftpStatusCode.noSuchFile, 'missing');
  }

  @override
  Future<void> mkdir(String path, [SftpFileAttrs? attrs]) async {
    folders.add(path);
  }

  @override
  Future<SftpFile> open(
    String path, {
    SftpFileOpenMode mode = SftpFileOpenMode.read,
  }) async {
    if (mode.flag & SftpFileOpenMode.create.flag == 0) {
      return _File(files[path]!, this);
    }
    expect(mode.flag & SftpFileOpenMode.exclusive.flag, isNonZero);
    expect(mode.flag & SftpFileOpenMode.truncate.flag, 0);
    if (files.containsKey(path)) {
      throw SftpStatusError(SftpStatusCode.failure, 'exists');
    }
    return _File(files[path] = [], this);
  }

  @override
  Future<void> remove(String path) async {
    files.remove(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('folder paths stay absolute and source relative', () {
    expect(writeFolder('/', null), '/OpenPlayX/Downloads');
    expect(writeFolder('/', ''), '/');
    expect(writeFolder('/movie', 'Films'), '/movie/Films');
    expect(
      () => writeFolder('/movie', '../other'),
      throwsA(isA<PluginException>()),
    );
  });
  test(
    'SFTP uses exclusive creation, auto renames and removes failed uploads',
    () async {
      final fs = _Sftp()..files['/a.mp4'] = [9];
      final plugin = SftpPlugin(
        const SourceConfig(
          id: 's',
          name: 'SFTP',
          kind: SourceKind.sftp,
          address: 'sftp://nas',
          username: 'test',
        ),
        '',
        connector: () async => (_Ssh(), fs),
      );
      final context = CallContext.forInstance('s');
      final entry = await plugin.writeNewStream(
        Stream.value([1, 2]),
        2,
        'a.mp4',
        context,
        folder: '',
      );
      expect(entry.ref.id, '/a (2).mp4');
      expect(fs.files['/a.mp4'], [9]);
      expect(fs.files[entry.ref.id], [1, 2]);
      await expectLater(
        plugin.writeNewStream(Stream.value([1]), 2, 'bad.mp4', context),
        throwsA(isA<PluginException>()),
      );
      expect(fs.files.keys.where((p) => p.contains('bad.mp4')), isEmpty);
    },
  );
  test('SFTP reconnects and rewrites only the chunk whose acknowledgement was lost', () async {
    final fs = _Sftp()..failOnceNetwork = true;
    final plugin = SftpPlugin(
      const SourceConfig(
        id: 's',
        name: 'SFTP',
        kind: SourceKind.sftp,
        address: 'sftp://nas',
        username: 'test',
      ),
      '',
      connector: () async => (_Ssh(), fs),
    );
    final entry = await plugin.writeNewStream(
      Stream.fromIterable([
        [1, 2],
        [3, 4],
      ]),
      4,
      'a.mp4',
      CallContext.forInstance('s'),
      folder: '',
    );
    expect(fs.files[entry.ref.id], [1, 2, 3, 4]);
  });
  for (final (name, renamed) in [
    ('a.mp4', 'a (2).mp4'),
    ('影片 100%.mp4', '影片 100% (2).mp4'),
    ('a%20.mp4', 'a%20 (2).mp4'),
  ]) {
    test(
      'WebDAV streams PUT then MOVE with Overwrite F, retries name collisions: $name',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final files = <String, List<int>>{
          '/$name': [9],
        };
        final methods = <String>[];
        server.listen((req) async {
          methods.add(req.method);
          // Store decoded filesystem paths, matching a real WebDAV server.
          final path = Uri.decodeComponent(req.uri.path);
          final res = req.response;
          switch (req.method) {
            case 'MKCOL':
              res.statusCode = 201;
            case 'PUT':
              expect(req.headers.value('if-none-match'), '*');
              files[path] = await req.expand((chunk) => chunk).toList();
              res.statusCode = 201;
            case 'MOVE':
              expect(req.headers.value('overwrite'), 'F');
              final target = Uri.decodeComponent(
                Uri.parse(req.headers.value('destination')!).path,
              );
              if (files.containsKey(target)) {
                res.statusCode = 412;
              } else {
                files[target] = files.remove(path)!;
                res.statusCode = 201;
              }
            case 'DELETE':
              files.remove(path);
              res.statusCode = 204;
            default:
              res.statusCode = 405;
          }
          await res.close();
        });
        final plugin = WebDavPlugin(
          SourceConfig(
            id: 'w',
            name: 'WebDAV',
            kind: SourceKind.webdav,
            address: 'http://127.0.0.1:${server.port}',
          ),
          '',
        );
        addTearDown(plugin.dispose);
        final result = await plugin.writeNewStream(
          Stream.fromIterable([
            [1],
            [2, 3],
          ]),
          3,
          name,
          CallContext.forInstance('w'),
          folder: '',
        );
        expect(result.ref.id, '/$renamed');
        expect(files['/$name'], [9]);
        expect(files['/$renamed'], [1, 2, 3]);
        expect(files.keys.where((p) => p.endsWith('.part')), isEmpty);
        expect(methods, ['PUT', 'MOVE', 'MOVE']);
      },
    );
  }
}
