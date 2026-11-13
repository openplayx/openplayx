import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/file_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:smb_connect/smb_connect.dart';
// SmbTransport is not exported by the package barrel.
// ignore: implementation_imports
import 'package:smb_connect/src/connect/smb_transport.dart';

class _Transport implements SmbTransport {
  @override
  bool isClosed = false;
  @override
  Duration idleFor = Duration.zero;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sink implements StreamConsumer<List<int>> {
  _Sink(this.fs, this.path);
  final _MemorySmb fs;
  final String path;
  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      if (fs.failWrites) throw StateError('NT_STATUS_ACCESS_DENIED');
      fs.files[path] = Uint8List.fromList([...fs.files[path]!, ...chunk]);
    }
  }

  @override
  Future close() async {}
}

/// In-memory share: paths → bytes, plus a set of folders.
class _MemorySmb implements SmbConnect {
  final files = <String, Uint8List>{};
  final folders = <String>{'/movie', '/movie/Film'};
  bool failWrites = false;
  final renames = <(String, String)>[];

  @override
  final _Transport transport = _Transport();

  @override
  Future<SmbFile> file(String path) async {
    if (folders.contains(path)) {
      return SmbFile(path, path, 'movie', 0, 0, 0, 0x10, 0, true);
    }
    final bytes = files[path];
    return bytes == null
        ? SmbFile.notExists(path, path, 'movie')
        : SmbFile(path, path, 'movie', 0, 0, 0, 0x80, bytes.length, true);
  }

  @override
  Future<SmbFile> createFolder(String path) async {
    folders.add(path);
    return file(path);
  }

  @override
  Future<SmbFile> createFile(String path) async {
    files.putIfAbsent(path, () => Uint8List(0));
    return file(path);
  }

  @override
  Future<IOSink> openWrite(SmbFile file, {bool append = false}) async =>
      IOSink(_Sink(this, file.path));

  @override
  Future<SmbFile> rename(
    SmbFile srcFile,
    String dstPath, {
    bool replace = false,
  }) async {
    if (files.containsKey(dstPath) && !replace) throw 'exists';
    renames.add((srcFile.path, dstPath));
    files[dstPath] = files.remove(srcFile.path)!;
    return file(dstPath);
  }

  @override
  Future<SmbFile> delete(SmbFile file) async {
    files.remove(file.path);
    return SmbFile.notExists(file.path, file.path, 'movie');
  }

  @override
  Future<void> echo() async {}
  @override
  Future<void> close() async => transport.isClosed = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const config = SourceConfig(
    id: 'smb-1',
    kind: SourceKind.smb,
    name: 'NAS',
    address: 'smb://nas.test',
  );
  const near = ResourceRef('smb-1', '/movie/Film/film.mkv');
  late _MemorySmb fs;
  late SmbPlugin plugin;
  late File clip;

  setUp(() async {
    fs = _MemorySmb();
    plugin = SmbPlugin.withAccess(
      config,
      SmbAccess(config, 'pw', connector: (_) async => fs),
    );
    final dir = await Directory.systemTemp.createTemp('smb-write');
    addTearDown(() => dir.delete(recursive: true));
    clip = File('${dir.path}/clip.mp4')
      ..writeAsBytesSync(utf8.encode('x' * 200000));
  });

  Future<SourceEntry> write(String name) =>
      plugin.writeNewFile(near, name, clip, CallContext.forInstance('smb-1'));

  test('writes into the OpenPlayX folder of the same share via a temp '
      'file', () async {
    final entry = await write('Film [clip 10m00s-11m00s].mp4');
    expect(entry.ref.instanceId, 'smb-1');
    expect(entry.ref.id, '/movie/OpenPlayX/Film [clip 10m00s-11m00s].mp4');
    expect(fs.folders, contains('/movie/OpenPlayX'));
    expect(fs.files[entry.ref.id], clip.readAsBytesSync());
    expect(fs.renames.single.$1, contains('/movie/OpenPlayX/.openplayx-'));
    expect(fs.files.keys.where((k) => k.endsWith('.part')), isEmpty);
  });

  test('never overwrites an existing file', () async {
    fs.folders.add('/movie/OpenPlayX');
    fs.files['/movie/OpenPlayX/a.mp4'] = Uint8List.fromList([1, 2, 3]);
    final entry = await write('a.mp4');
    expect(entry.name, 'a (2).mp4');
    expect(fs.files['/movie/OpenPlayX/a.mp4'], [1, 2, 3]);
  });

  test(
    'a failed upload removes the temp file and reports writeFailed',
    () async {
      fs.failWrites = true;
      await expectLater(
        write('a.mp4'),
        throwsA(
          isA<PluginException>().having((e) => e.code, 'code', 'writeFailed'),
        ),
      );
      expect(fs.files, isEmpty);
    },
  );

  test('rejects names that could escape the folder', () async {
    for (final name in ['../a.mp4', 'a/b.mp4', '.hidden', 'a\\b.mp4']) {
      await expectLater(write(name), throwsA(isA<PluginException>()));
    }
    expect(fs.files, isEmpty);
  });
}
