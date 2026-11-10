import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../../core/plugins/source_capability.dart';

/// Loopback-only, unguessable session URLs keep remote passwords/tokens out of
/// libVLC, UI, history and diagnostics. Each handle owns its server/resources.
class StreamGateway {
  static Future<PlayableStream> serve(
    Future<void> Function(HttpRequest) handler, {
    String? filename,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final random = Random.secure();
    final key = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final path = '/$key/${Uri.encodeComponent(filename ?? 'media')}';
    server.listen((request) async {
      try {
        if (request.uri.path != path ||
            !['GET', 'HEAD'].contains(request.method)) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          await handler(request);
        }
      } catch (_) {
        // Never forward exception text (it can contain upstream credentials).
        try {
          request.response.statusCode = HttpStatus.badGateway;
        } catch (_) {}
      } finally {
        try {
          await request.response.close();
        } catch (_) {}
      }
    });
    return PlayableStream(
      Uri.parse('http://127.0.0.1:${server.port}$path'),
      release: () async => server.close(force: true),
    );
  }

  static Future<PlayableStream> randomAccess({
    required int length,
    String? filename,
    required Future<RandomAccessFile> Function() open,
  }) => ranged(
    length: length,
    filename: filename,
    read: (start, end) async* {
      final file = await open();
      try {
        await file.setPosition(start);
        var remaining = end - start + 1;
        while (remaining > 0) {
          final bytes = await file.read(min(remaining, 256 * 1024));
          if (bytes.isEmpty) throw const FileSystemException('Unexpected EOF');
          yield bytes;
          remaining -= bytes.length;
        }
      } finally {
        await file.close();
      }
    },
  );

  /// Serves a file of known [length] with HTTP range support; [read] yields
  /// the bytes from [start] to [end] (inclusive) and may yield more, which is
  /// cut off.
  static Future<PlayableStream> ranged({
    required int length,
    String? filename,
    required Stream<List<int>> Function(int start, int end) read,
  }) => serve((request) async {
    final response = request.response;
    response.headers.set('Accept-Ranges', 'bytes');
    response.headers.contentType =
        filename?.toLowerCase().endsWith('.mp4') == true
        ? ContentType('video', 'mp4')
        : ContentType.binary;
    var start = 0;
    var end = length - 1;
    final range = request.headers.value('range');
    if (range != null) {
      final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
      if (match == null ||
          length == 0 ||
          (match[1]!.isEmpty && match[2]!.isEmpty)) {
        response.statusCode = 416;
        response.headers.set('Content-Range', 'bytes */$length');
        return;
      }
      if (match[1]!.isEmpty) {
        start = max(0, length - int.parse(match[2]!));
      } else {
        start = int.parse(match[1]!);
        if (match[2]!.isNotEmpty) end = min(end, int.parse(match[2]!));
      }
      if (start > end || start >= length) {
        response.statusCode = 416;
        response.headers.set('Content-Range', 'bytes */$length');
        return;
      }
      response.statusCode = 206;
      response.headers.set('Content-Range', 'bytes $start-$end/$length');
    }
    response.contentLength = length == 0 ? 0 : end - start + 1;
    if (request.method == 'HEAD' || length == 0) return;
    var remaining = end - start + 1;
    await for (final chunk in read(start, end)) {
      final part = chunk.length > remaining
          ? chunk.sublist(0, remaining)
          : chunk;
      response.add(part);
      await response.flush();
      remaining -= part.length;
      if (remaining <= 0) break;
    }
    if (remaining > 0) throw const FileSystemException('Unexpected EOF');
  }, filename: filename);

  static Future<PlayableStream> http(
    Uri uri,
    Map<String, String> headers, {
    String? filename,
    HttpClient? sharedClient,
  }) async {
    final client =
        sharedClient ??
        (HttpClient()..connectionTimeout = const Duration(seconds: 15));
    final stream = await serve((request) async {
      final upstream = await client.openUrl(request.method, uri);
      // Do not forward credentials to redirects, even to a LAN host.
      upstream.followRedirects = false;
      headers.forEach(upstream.headers.set);
      final range = request.headers.value('range');
      if (range != null) upstream.headers.set('Range', range);
      final result = await upstream.close();
      request.response.statusCode = result.isRedirect ? 502 : result.statusCode;
      for (final name in [
        'content-type',
        'content-length',
        'content-range',
        'accept-ranges',
      ]) {
        final value = result.headers.value(name);
        if (value != null) request.response.headers.set(name, value);
      }
      if (result.isRedirect) {
        await result.drain<void>();
        return;
      }
      await request.response.addStream(result);
    }, filename: filename ?? uri.pathSegments.last);
    return PlayableStream(
      stream.uri,
      release: () async {
        await stream.release();
        if (sharedClient == null) client.close(force: true);
      },
    );
  }
}
