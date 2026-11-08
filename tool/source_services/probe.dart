import 'dart:convert';
import 'dart:io';

import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/file_sources.dart';
import 'package:openplayx/data/sources/media_server_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';

Future<void> main() async {
  final defines = jsonDecode(
    await File('tool/source_services/defines.local.json').readAsString(),
  );
  final original = await File('test/fixtures/test_video.mp4').readAsBytes();
  for (final kind in [SourceKind.smb, SourceKind.plex, SourceKind.jellyfin]) {
    final config = SourceConfig(
      id: kind.name,
      kind: kind,
      name: kind.label,
      address: switch (kind) {
        SourceKind.smb => 'smb://127.0.0.1/media',
        SourceKind.plex => 'http://127.0.0.1:13240',
        _ => 'http://127.0.0.1:18096',
      },
      username: 'openplayx',
      userId: defines['JELLYFIN_USER_ID'],
    );
    final SourceCapability source = switch (kind) {
      SourceKind.smb => SmbPlugin(config, 'test-only-password'),
      SourceKind.plex => PlexPlugin(config, SourceHttp(config, 'test-token')),
      _ => JellyfinPlugin(
        config,
        SourceHttp(config, defines['JELLYFIN_TOKEN']),
      ),
    };
    final context = CallContext.forInstance(config.id);
    final client = HttpClient();
    PlayableStream? stream;
    try {
      ResourceRef? node;
      for (var depth = 0; depth < 6; depth++) {
        final page = await source
            .browse(BrowseRequest(node: node), context)
            .timeout(const Duration(seconds: 20));
        stdout.writeln(
          '${kind.name}: ${page.entries.map((e) => '${e.name} ${e.isFolder}')}',
        );
        final entry = page.entries.first;
        if (entry.isFolder) {
          node = entry.ref;
          continue;
        }
        stream = await source.resolve(ResolveRequest(entry.ref), context);
        break;
      }
      for (final range in [null, 'bytes=1024-2047']) {
        final request = await client.getUrl(stream!.uri);
        if (range != null) request.headers.set('Range', range);
        final response = await request.close().timeout(
          const Duration(seconds: 10),
        );
        final bytes = await response
            .fold<List<int>>([], (a, b) => a..addAll(b))
            .timeout(const Duration(seconds: 10));
        final expected = range == null
            ? original
            : original.sublist(1024, 2048);
        if (bytes.length != expected.length ||
            List.generate(
              bytes.length,
              (i) => bytes[i] == expected[i],
            ).contains(false)) {
          throw StateError('Byte mismatch');
        }
        stdout.writeln(
          '${kind.name}: ${response.statusCode} ${bytes.length} bytes match',
        );
      }
    } finally {
      client.close(force: true);
      await stream?.release();
      await (source as Plugin).dispose();
    }
  }
}
