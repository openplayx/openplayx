import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:smb_connect/smb_connect.dart';

import '../../core/plugins/source_capability.dart';
import 'progressive_read_session.dart';

class _ReadCancellation {
  bool cancelled = false;
}

/// Loopback-only, unguessable session URLs keep remote passwords/tokens out of
/// libVLC, UI, history and diagnostics. Each handle owns its server/resources.
class StreamGateway {
  static Future<PlayableStream> serve(
    Future<void> Function(HttpRequest) handler, {
    String? filename,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    // HttpServer.port throws once the listener closes; callbacks may outlive it.
    final port = server.port;
    final random = Random.secure();
    final key = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final path = '/$key/${Uri.encodeComponent(filename ?? 'media')}';
    server.listen((request) async {
      print('DIAG gateway $port ${request.method} range=${request.headers.value('range')}'); // DIAG
      try {
        if (request.uri.path != path ||
            !['GET', 'HEAD'].contains(request.method)) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          await handler(request);
        }
      } catch (e) {
        print('DIAG gateway $port handler error ${e.runtimeType}'); // DIAG
        // Never forward exception text (it can contain upstream credentials).
        try {
          request.response.statusCode = HttpStatus.badGateway;
        } catch (_) {}
      } finally {
        try {
          await request.response.close();
        } catch (_) {}
      }
    }, onError: (Object e) => print('DIAG gateway $port server error $e'), // DIAG
    onDone: () => print('DIAG gateway $port server done')); // DIAG
    return PlayableStream(
      Uri.parse('http://127.0.0.1:$port$path'),
      release: () async => server.close(force: true),
    );
  }

  static Future<PlayableStream> randomAccess({
    required int length,
    String? filename,
    required Future<RandomAccessFile> Function() open,
    Future<RandomAccessFile> Function(SmbReadRamp ramp)? progressiveOpen,
  }) {
    final progress = progressiveOpen == null ? null : ProgressiveReadSession();
    return _ranged(
      length: length,
      filename: filename,
      read: (start, end, cancellation) async* {
        if (cancellation.cancelled) return;
        final cursor = progress?.begin(start);
        final file = progressiveOpen == null
            ? await open()
            : await progressiveOpen(cursor!.ramp);
        try {
          if (cancellation.cancelled) return;
          await file.setPosition(start);
          var remaining = end - start + 1;
          while (remaining > 0) {
            if (cancellation.cancelled) return;
            final size = min(256 * 1024, cursor?.ramp.readSize ?? 256 * 1024);
            final bytes = await file.read(min(remaining, size));
            if (cancellation.cancelled) return;
            if (bytes.isEmpty) {
              throw const FileSystemException('Unexpected EOF');
            }
            cursor?.advance(bytes.length);
            yield bytes;
            remaining -= bytes.length;
          }
        } finally {
          await file.close();
        }
      },
    );
  }

  /// Serves a file of known [length] with HTTP range support; [read] yields
  /// the bytes from [start] to [end] (inclusive) and may yield more, which is
  /// cut off.
  static Future<PlayableStream> ranged({
    required int length,
    String? filename,
    required Stream<List<int>> Function(int start, int end) read,
  }) => _ranged(
    length: length,
    filename: filename,
    read: (start, end, cancellation) => read(start, end),
  );

  static Future<PlayableStream> _ranged({
    required int length,
    String? filename,
    required Stream<List<int>> Function(
      int start,
      int end,
      _ReadCancellation cancellation,
    )
    read,
  }) async {
    final active = <_ReadCancellation>{};
    var released = false;
    final stream = await serve((request) async {
      if (released) return;
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
      final cancellation = _ReadCancellation();
      active.add(cancellation);
      unawaited(
        response.done.then<void>(
          (_) {
            cancellation.cancelled = true;
          },
          onError: (Object error, StackTrace stack) {
            cancellation.cancelled = true;
          },
        ),
      );
      try {
        Stream<List<int>> output() async* {
          var remaining = end - start + 1;
          await for (final chunk in read(start, end, cancellation)) {
            if (cancellation.cancelled) break;
            final part = chunk.length > remaining
                ? chunk.sublist(0, remaining)
                : chunk;
            remaining -= part.length;
            yield part;
            if (remaining <= 0) break;
          }
          if (remaining > 0 && !cancellation.cancelled) {
            throw const FileSystemException('Unexpected EOF');
          }
        }

        // addStream propagates socket failure/cancellation to its source.
        // Repeated add()/flush() can silently discard output after a peer
        // disconnect while continuing to pull the entire upstream movie.
        response.bufferOutput = false;
        await response.addStream(output());
      } finally {
        cancellation.cancelled = true;
        active.remove(cancellation);
      }
    }, filename: filename);
    return PlayableStream(
      stream.uri,
      release: () async {
        released = true;
        for (final token in active) {
          token.cancelled = true;
        }
        await stream.release();
      },
    );
  }

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
