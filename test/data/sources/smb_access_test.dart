import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/file_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:smb_connect/smb_connect.dart';
// SmbTransport is not exported by the package barrel.
// ignore: implementation_imports
import 'package:smb_connect/src/connect/smb_transport.dart';

class _FakeTransport implements SmbTransport {
  @override
  bool isClosed = false;
  @override
  Duration idleFor = Duration.zero;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeConnect implements SmbConnect {
  _FakeConnect(this.id, [this.media]);
  final int id;
  final File? media;
  bool closed = false;
  int echoes = 0;

  /// A half-open socket: requests are sent but never answered.
  bool silent = false;
  @override
  Future<void> echo() {
    echoes++;
    return silent ? Completer<void>().future : Future.value();
  }

  @override
  Future<SmbFile> file(String path) async {
    final size = media?.lengthSync() ?? 0;
    return SmbFile(path, path, 'share', 0, 0, 0, 0, size, true);
  }

  @override
  Future<RandomAccessFile> open(
    SmbFile file, {
    FileMode mode = FileMode.read,
    SmbReadRamp? readRamp,
  }) async {
    if (transport.isClosed) throw StateError('StreamSink is closed');
    return media!.open();
  }

  @override
  final _FakeTransport transport = _FakeTransport();
  @override
  Future<void> close() async {
    closed = true;
    transport.isClosed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const config = SourceConfig(
    id: 'smb-1',
    kind: SourceKind.smb,
    name: 'NAS',
    address: 'smb://nas.test/share',
  );
  late List<_FakeConnect> opened;
  late void Function(SmbConnect) disconnect;
  late SmbAccess access;

  setUp(() {
    opened = [];
    access = SmbAccess(
      config,
      'secret',
      connector: (onDisconnect) async {
        disconnect = onDisconnect;
        final connection = _FakeConnect(opened.length);
        opened.add(connection);
        return connection;
      },
    );
  });

  test('reuses one live connection', () async {
    expect(await access.run((c) async => (c as _FakeConnect).id), 0);
    expect(await access.run((c) async => (c as _FakeConnect).id), 0);
    expect(opened, hasLength(1));
  });

  test('a failed call discards the connection and retries once', () async {
    final seen = <int>[];
    final result = await access.run((c) async {
      seen.add((c as _FakeConnect).id);
      if (c.id == 0) throw StateError('StreamSink is closed');
      return 'ok';
    });
    expect(result, 'ok');
    expect(seen, [0, 1]);
    expect(opened.first.closed, isTrue);
  });

  test('a closed socket is replaced before the next call', () async {
    await access.run((c) async {});
    opened.first.transport.isClosed = true;
    expect(await access.run((c) async => (c as _FakeConnect).id), 1);
  });

  test('a disconnect callback drops the cached connection', () async {
    await access.run((c) async {});
    disconnect(opened.first);
    expect(await access.run((c) async => (c as _FakeConnect).id), 1);
  });

  test('plugin answers are not retried', () async {
    var calls = 0;
    await expectLater(
      access.run((c) async {
        calls++;
        throw const PluginException('notFound', 'missing');
      }),
      throwsA(isA<PluginException>()),
    );
    expect(calls, 1);
    expect(opened, hasLength(1));
  });

  test('a stalled quick call times out and retries', () async {
    final seen = <int>[];
    final result = await access
        .run((c) {
          seen.add((c as _FakeConnect).id);
          // A half-open socket: the first connection never answers.
          return c.id == 0 ? Completer<String>().future : Future.value('ok');
        }, quick: true)
        .timeout(SmbAccess.staleCallTimeout * 2);
    expect(result, 'ok');
    expect(seen, [0, 1]);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test(
    'playback reads reopen on a new connection after a disconnect',
    () async {
      final dir = await Directory.systemTemp.createTemp('smb_access_test');
      addTearDown(() => dir.delete(recursive: true));
      final media = File('${dir.path}/episode.mkv')
        ..writeAsBytesSync(List.generate(4096, (i) => i % 251));
      final connections = <_FakeConnect>[];
      final plugin = SmbPlugin.withAccess(
        config,
        SmbAccess(
          config,
          'secret',
          connector: (_) async {
            final connection = _FakeConnect(connections.length, media);
            connections.add(connection);
            return connection;
          },
        ),
      );
      final stream = await plugin.resolve(
        const ResolveRequest(ResourceRef('smb-1', '/share/episode.mkv')),
        CallContext.forInstance('smb-1'),
      );
      addTearDown(stream.release);
      // The OS drops the socket while playback is paused in the background.
      connections.single.transport.isClosed = true;

      final client = HttpClient();
      addTearDown(client.close);
      final response = await (await client.getUrl(stream.uri)).close();
      final body = await response.fold<List<int>>([], (a, b) => a..addAll(b));
      expect(response.statusCode, 200);
      expect(body, media.readAsBytesSync());
      expect(connections, hasLength(2));
    },
  );

  test('a fresh connection is used without probing', () async {
    await access.run((c) async {});
    await access.run((c) async {});
    expect(opened.single.echoes, 0);
  });

  test('an idle connection that still answers is kept', () async {
    await access.run((c) async {});
    opened.single.transport.idleFor = const Duration(minutes: 3);
    expect(await access.run((c) async => (c as _FakeConnect).id), 0);
    expect(opened.single.echoes, 1);
  });

  test('an idle half-open connection is replaced after the probe', () async {
    await access.run((c) async {});
    opened.single
      ..transport.idleFor = const Duration(minutes: 3)
      ..silent = true;
    final watch = Stopwatch()..start();
    expect(await access.run((c) async => (c as _FakeConnect).id), 1);
    expect(watch.elapsed, lessThan(SmbAccess.probeTimeout * 2));
    expect(opened.first.closed, isTrue);
  });
}
