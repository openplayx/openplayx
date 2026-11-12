import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:smb_connect/smb_connect.dart';

import 'package:openplayx/data/sources/stream_gateway.dart';

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest digest) {
    value = digest;
  }

  @override
  void close() {}
}

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError('Provide a private local SMB config JSON path');
  }
  final c = jsonDecode(
    await File(args.single).readAsString(),
  ) as Map<String, dynamic>;
  final connection = await IOOverrides.runZoned(
    () => SmbConnect.connectAuth(
      host: c['host'],
      username: c['username'],
      password: c['password'],
      domain: c['domain'] ?? '',
    ),
    socketConnect:
        (
          host,
          port, {
          sourceAddress,
          int sourcePort = 0,
          Duration? timeout,
        }) async {
          if (host != c['host'] || port != 445) {
            throw StateError('Unexpected SMB target');
          }
          return (await Socket.startConnect(
            '127.0.0.1',
            c['proxyPort'] ?? 19445,
          )).socket;
        },
  );
  try {
    final file = await connection.file(c['file']);
    Future<Map<String, dynamic>> fetch(Uri uri, int start, int count) async {
      final client = HttpClient();
      final watch = Stopwatch()..start();
      final sink = _DigestSink();
      final hash = sha256.startChunkedConversion(sink);
      int? first;
      var total = 0;
      try {
        final request = await client.getUrl(uri);
        request.headers.set('Range', 'bytes=$start-${start + count - 1}');
        final response = await request.close();
        if (response.statusCode != 206) {
          throw StateError('Range response failed');
        }
        await for (final bytes in response) {
          first ??= watch.elapsedMicroseconds;
          total += bytes.length;
          hash.add(bytes);
        }
        watch.stop();
        hash.close();
        if (total != count) throw StateError('Unexpected HTTP byte count');
        return {
          'bytes': total,
          'seconds': watch.elapsedMicroseconds / 1e6,
          'firstHttpBodyMs': (first ?? 0) / 1000,
          'MBps': total / watch.elapsedMicroseconds,
          'sha256': sink.value.toString(),
        };
      } finally {
        client.close(force: true);
      }
    }

    for (var trial = 1; trial <= 3; trial++) {
      for (final progressive in trial.isEven ? [true, false] : [false, true]) {
        final stream = await StreamGateway.randomAccess(
          length: file.size,
          open: () => connection.open(file),
          progressiveOpen: progressive
              ? (ramp) => connection.open(file, readRamp: ramp)
              : null,
        );
        try {
          final r = await fetch(stream.uri, 1073741824, 32 * 1024 * 1024);
          if (r['sha256'] != c['benchmarkSha256']) {
            throw StateError('Movie checksum mismatch');
          }
          stdout.writeln(
            jsonEncode({
              ...r,
              'trial': trial,
              'mode': progressive ? 'progressive' : 'fixed1MiB',
            }),
          );
        } finally {
          await stream.release();
        }
      }
    }

    final seeds = <int>[];
    final progressive = await StreamGateway.randomAccess(
      length: file.size,
      open: () => connection.open(file),
      progressiveOpen: (ramp) {
        seeds.add(ramp.sequentialBytes);
        return connection.open(file, readRamp: ramp);
      },
    );
    final baseline = await StreamGateway.randomAccess(
      length: file.size,
      open: () => connection.open(file),
    );
    try {
      final client = HttpClient();
      try {
        await (await (await client.openUrl(
          'HEAD',
          progressive.uri,
        )).close()).drain<void>();
      } finally {
        client.close(force: true);
      }
      if (seeds.isNotEmpty) throw StateError('HEAD unexpectedly opened file');
      final ranges = [
        (1073741824, 65536),
        (1073741824 + 65536, 262144),
        (1073741824 + 327680, 262144),
        (2147483648, 65536),
        (file.size - 4096, 4096),
      ];
      for (final range in ranges) {
        final a = await fetch(progressive.uri, range.$1, range.$2);
        final b = await fetch(baseline.uri, range.$1, range.$2);
        if (a['sha256'] != b['sha256']) throw StateError('Range data mismatch');
      }
      final expected = [0, 65536, 327680, 0, 0];
      if (seeds.length != expected.length ||
          List.generate(
            seeds.length,
            (i) => seeds[i] == expected[i],
          ).contains(false)) {
        throw StateError('Range continuity/seek ramp mismatch');
      }
      stdout.writeln(
        jsonEncode({
          'rangeChecks': 5,
          'head': true,
          'adjacentWarmSeeds': seeds,
          'dataVerified': true,
        }),
      );
    } finally {
      await progressive.release();
      await baseline.release();
    }
  } finally {
    await connection.close();
  }
}
