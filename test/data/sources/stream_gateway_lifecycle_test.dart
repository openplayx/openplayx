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
}
