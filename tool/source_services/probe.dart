import 'dart:convert';
import 'dart:io';

import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/dlna_source.dart';
import 'package:openplayx/data/sources/file_sources.dart';
import 'package:openplayx/data/sources/media_server_sources.dart';
import 'package:openplayx/data/sources/network_file_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';

import '../../integration_test/support/source_services.dart';

/// Protocol check against the services in compose.yaml, without Flutter UI:
/// walks each source to the fixture and compares full and ranged bytes.
/// Pass kind names to probe only those (e.g. `dart run ... webdav ftp`).
Future<void> main(List<String> args) async {
  final defines = jsonDecode(
    await File('tool/source_services/defines.local.json').readAsString(),
  );
  final host = defines['SOURCE_HOST'] as String? ?? '127.0.0.1';
  final original = await File('test/fixtures/test_video.mp4').readAsBytes();
  final kinds = SourceKind.values
      .where((k) => k != SourceKind.local)
      .where((k) => args.isEmpty || args.contains(k.name));
  final failures = <String>[];
  for (final kind in kinds) {
    final config = sourceServiceConfig(kind, host, defines);
    final secret = sourceServiceSecret(kind, defines);
    // Same construction as SourceManager, which can't load under plain Dart.
    final SourceCapability source = switch (kind) {
      SourceKind.local => LocalFolderPlugin(config),
      SourceKind.smb => SmbPlugin(config, secret),
      SourceKind.webdav => WebDavPlugin(config, secret),
      SourceKind.ftp => FtpPlugin(config, secret),
      SourceKind.sftp => SftpPlugin(config, secret),
      SourceKind.s3 => S3Plugin(config, secret),
      SourceKind.plex => PlexPlugin(config, SourceHttp(config, secret)),
      SourceKind.jellyfin ||
      SourceKind.emby => JellyfinPlugin(config, SourceHttp(config, secret)),
      SourceKind.dlna => DlnaPlugin(config),
    };
    final context = CallContext.forInstance(config.id);
    final client = HttpClient();
    PlayableStream? stream;
    try {
      // The shelf feed is checked first: it doesn't need the fixture.
      if (source case final RecentCapability recent) {
        final items = await recent.recent(5, context);
        stdout.writeln('${kind.name}: recent ${items.map((e) => e.name)}');
      }

      Future<SourceEntry?> find(ResourceRef? node, int depth) async {
        if (depth > 5) return null;
        final page = await source
            .browse(BrowseRequest(node: node), context)
            .timeout(const Duration(seconds: 20));
        stdout.writeln(
          '${kind.name}: ${page.entries.map((e) => '${e.name}${e.isFolder ? '/' : ''}').join(', ')}',
        );
        for (final entry in page.entries) {
          // DLNA titles are metadata, not file names.
          if (!entry.isFolder &&
              (entry.name.contains('test_video') || kind == SourceKind.dlna)) {
            return entry;
          }
        }
        for (final entry in page.entries.where((e) => e.isFolder)) {
          final found = await find(entry.ref, depth + 1);
          if (found != null) return found;
        }
        return null;
      }

      final entry = await find(null, 0);
      if (entry == null) throw StateError('fixture not found');
      stream = await source.resolve(ResolveRequest(entry.ref), context);
      for (final range in [null, 'bytes=1024-2047']) {
        final request = await client.getUrl(stream.uri);
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
          throw StateError(
            'byte mismatch (${response.statusCode}, ${bytes.length} bytes)',
          );
        }
        stdout.writeln(
          '${kind.name}: ${range ?? 'full'} ${response.statusCode} '
          '${bytes.length} bytes match',
        );
      }
    } catch (error) {
      failures.add('${kind.name}: $error');
      stdout.writeln('${kind.name}: FAILED $error');
    } finally {
      client.close(force: true);
      await stream?.release();
      await (source as Plugin).dispose();
    }
  }
  stdout.writeln(
    failures.isEmpty
        ? 'All sources passed.'
        : 'Failed:\n${failures.join('\n')}',
  );
  exit(failures.isEmpty ? 0 : 1);
}
