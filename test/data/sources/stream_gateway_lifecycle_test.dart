import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/sources/stream_gateway.dart';

void main() {
  test('closing the gateway never reads port from an unbound server', () async {
    final stream = await StreamGateway.serve((request) async {});
    await stream.release();
    await stream.release();
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'a late handler failure remains handled after the gateway closes',
    () async {
      final entered = Completer<void>();
      final resume = Completer<void>();
      final stream = await StreamGateway.serve((request) async {
        entered.complete();
        await resume.future;
        throw StateError('fixture failure after close');
      });
      final client = HttpClient();
      addTearDown(() async {
        if (!resume.isCompleted) resume.complete();
        client.close(force: true);
        await stream.release();
      });
      final request = await client.getUrl(stream.uri);
      final response = request.close().then<void>(
        (r) => r.drain<void>(),
        onError: (Object error, StackTrace stack) {},
      );
      await entered.future;
      await stream.release();
      resume.complete();
      await response;
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('accepts clients that percent-encode reserved filename chars', () async {
    const name = 'Modern Family S01E01 Pilot  (1080p x265 10bit Joy).mkv';
    final stream = await StreamGateway.serve((request) async {
      request.response.write('ok');
    }, filename: name);
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await stream.release();
    });
    // VLC re-encodes '(' and ')' that Uri.encodeComponent leaves as-is.
    final vlcStyle = stream.uri.replace(
      path: stream.uri.path.replaceAll('(', '%28').replaceAll(')', '%29'),
    );
    for (final uri in [stream.uri, vlcStyle]) {
      final response = await (await client.getUrl(uri)).close();
      expect(response.statusCode, HttpStatus.ok, reason: '$uri');
      await response.drain<void>();
    }
    final bad = stream.uri.replace(path: '${stream.uri.path}x');
    final response = await (await client.getUrl(bad)).close();
    expect(response.statusCode, HttpStatus.notFound);
    await response.drain<void>();
  });
}
