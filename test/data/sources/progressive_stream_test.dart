import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smb_connect/smb_connect.dart';
import 'package:openplayx/data/sources/progressive_read_session.dart';
import 'package:openplayx/data/sources/stream_gateway.dart';

class MemoryReader implements RandomAccessFile {
  final Uint8List data;
  final SmbReadRamp ramp;
  final List<int> requests;
  final Completer<void>? gate;
  final Completer<void> closed = Completer<void>();
  int offset = 0, calls = 0;
  MemoryReader(this.data, this.ramp, this.requests, {this.gate});
  @override
  Future<RandomAccessFile> setPosition(int value) async {
    offset = value;
    return this;
  }

  @override
  Future<Uint8List> read(int count) async {
    requests.add(count);
    calls++;
    if (calls > 1) await gate?.future;
    final bytes = Uint8List.sublistView(
      data,
      offset,
      min(offset + count, data.length),
    );
    offset += bytes.length;
    ramp.recordRead(bytes.length);
    return bytes;
  }

  @override
  Future<void> close() async {
    if (!closed.isCompleted) closed.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'adjacent ranges retain progress; parallel probes own independent ramps',
    () {
      final session = ProgressiveReadSession();
      final original = session.begin(0);
      original.ramp.recordRead(65536);
      original.advance(65536);
      final probe = session.begin(1000000);
      probe.ramp.recordRead(4096);
      probe.advance(4096);
      final continuation = session.begin(65536);
      expect(continuation.ramp.readSize, 262144);
      original.ramp.recordRead(262144);
      original.advance(262144);
      expect(continuation.ramp.readSize, 262144);
      expect(probe.ramp.readSize, 65536);
      expect(session.begin(2000000).ramp.readSize, 65536);
    },
  );
  test('session keeps only a bounded number of continuation records', () {
    final session = ProgressiveReadSession();
    final first = session.begin(0);
    first.ramp.recordRead(65536);
    first.advance(65536);
    for (var i = 1; i <= 4; i++) {
      session.begin(i * 1000000);
    }
    expect(session.begin(65536).ramp.readSize, 65536);
  });
  test(
    'HTTP output ramps immediately and adjacent ranges remain warm',
    () async {
      final data = Uint8List.fromList(
        List.generate(2 * 1024 * 1024, (i) => i % 251),
      );
      final seeds = <int>[], requests = <int>[];
      final readers = <MemoryReader>[];
      final stream = await StreamGateway.randomAccess(
        length: data.length,
        open: () async => throw StateError('Unexpected fallback'),
        progressiveOpen: (ramp) async {
          seeds.add(ramp.sequentialBytes);
          final reader = MemoryReader(data, ramp, requests);
          readers.add(reader);
          return reader;
        },
      );
      final client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await stream.release();
      });
      Future<List<int>> read(int start, int end) async {
        final q = await client.getUrl(stream.uri);
        q.headers.set('Range', 'bytes=$start-$end');
        final response = await q.close();
        expect(response.statusCode, 206);
        return response.fold<List<int>>([], (a, b) => a..addAll(b));
      }

      final head = await client.openUrl('HEAD', stream.uri);
      await (await head.close()).drain<void>();
      expect(seeds, isEmpty);
      expect(await read(0, 65535), data.sublist(0, 65536));
      expect(await read(65536, 327679), data.sublist(65536, 327680));
      expect(await read(327680, 589823), data.sublist(327680, 589824));
      expect(seeds, [0, 65536, 327680]);
      expect(requests, [65536, 262144, 262144]);
      expect(await read(1048576, 1114111), data.sublist(1048576, 1114112));
      expect(seeds.last, 0);
      expect(requests.last, 65536);
      final q = await client.getUrl(stream.uri);
      q.headers.set('Range', 'bytes=-3');
      final suffix = await q.close();
      expect(
        await suffix.fold<List<int>>([], (a, b) => a..addAll(b)),
        data.sublist(data.length - 3),
      );
      for (final r in readers) {
        await r.closed.future.timeout(const Duration(seconds: 2));
      }
    },
  );
  for (final releaseSession in [true, false]) {
    test(
      'first output is immediate; cancellation closes handle (release=$releaseSession)',
      () async {
        final gate = Completer<void>(), first = Completer<void>();
        final requests = <int>[];
        late MemoryReader reader;
        final stream = await StreamGateway.randomAccess(
          length: 1024 * 1024,
          open: () async => throw StateError('Unexpected fallback'),
          progressiveOpen: (ramp) async => reader = MemoryReader(
            Uint8List(1024 * 1024),
            ramp,
            requests,
            gate: gate,
          ),
        );
        final client = HttpClient();
        final request = await client.getUrl(stream.uri);
        final response = await request.close();
        final subscription = response.listen((bytes) {
          if (!first.isCompleted) first.complete();
        });
        try {
          await first.future.timeout(const Duration(seconds: 2));
          expect(requests.first, 65536);
          expect(gate.isCompleted, isFalse);
        } finally {
          client.close(force: true);
          await subscription.cancel();
          if (releaseSession) {
            await stream.release();
          } else {
            await Future<void>.delayed(const Duration(milliseconds: 30));
          }
          gate.complete();
        }
        await reader.closed.future.timeout(const Duration(seconds: 2));
        await stream.release();
        if (releaseSession) {
          expect(requests.length, lessThanOrEqualTo(2));
        } else {
          // TCP disconnect detection is asynchronous: a buffered read may
          // already be scheduled, but the source must not drain to EOF.
          expect(
            requests.fold<int>(0, (sum, n) => sum + n),
            lessThan(1024 * 1024),
          );
        }
      },
    );
  }
}
