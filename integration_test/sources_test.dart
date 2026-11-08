import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/file_sources.dart';
import 'package:openplayx/data/sources/media_server_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx_playback/playback.dart';

import 'support/test_video.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const services = bool.fromEnvironment('SOURCE_SERVICES');
  for (final kind in SourceKind.values) {
    testWidgets('${kind.label}: real source browse, Range, VLC decode and seek', (
      tester,
    ) async {
      final dir = await Directory.systemTemp.createTemp('openplayx-source-');
      final fixture = await createTestVideo(dir);
      final config = SourceConfig(
        id: 'integration-${kind.name}',
        kind: kind,
        name: kind.label,
        address: switch (kind) {
          SourceKind.local => dir.path,
          SourceKind.smb => 'smb://127.0.0.1/media',
          SourceKind.plex => 'http://127.0.0.1:13240',
          SourceKind.jellyfin => 'http://127.0.0.1:18096',
        },
        username: 'openplayx',
        userId: const String.fromEnvironment('JELLYFIN_USER_ID'),
      );
      final SourceCapability source = switch (kind) {
        SourceKind.local => LocalFolderPlugin(config),
        SourceKind.smb => SmbPlugin(config, 'test-only-password'),
        SourceKind.plex => PlexPlugin(config, SourceHttp(config, 'test-token')),
        SourceKind.jellyfin => JellyfinPlugin(
          config,
          SourceHttp(config, const String.fromEnvironment('JELLYFIN_TOKEN')),
        ),
      };
      final backend = LibVlcBackend();
      PlayableStream? stream;
      addTearDown(() async {
        backend.dispose();
        await stream?.release();
        await (source as Plugin).dispose();
        await dir.delete(recursive: true);
      });
      final context = CallContext.forInstance(config.id);
      // Test bounded pages and traverse the actual media library to a playable leaf.
      Future<SourceEntry?> findVideo(ResourceRef? node, int depth) async {
        if (depth > 5) return null;
        int? offset = 0;
        while (offset != null) {
          final page = await source.browse(
            BrowseRequest(node: node, offset: offset, limit: 10),
            context,
          );
          for (final entry in page.entries) {
            if (!entry.isFolder) return entry;
            final child = await findVideo(entry.ref, depth + 1);
            if (child != null) return child;
          }
          offset = page.nextOffset;
        }
        return null;
      }

      final entry = await findVideo(null, 0);
      expect(
        entry,
        isNotNull,
        reason: 'Fixture must be discoverable from source root',
      );
      stream = await source.resolve(ResolveRequest(entry!.ref), context);
      expect(stream.uri.userInfo, isEmpty);
      if (kind != SourceKind.local) {
        final client = HttpClient();
        try {
          final request = await client.getUrl(stream.uri);
          request.headers.set('Range', 'bytes=0-31');
          final response = await request.close();
          expect(response.statusCode, 206);
          final bytes = await response.fold<List<int>>(
            [],
            (a, b) => a..addAll(b),
          );
          final original = await fixture.readAsBytes();
          expect(bytes, original.sublist(0, 32));
          final fullRequest = await client.getUrl(stream.uri);
          final fullResponse = await fullRequest.close();
          final fullBytes = await fullResponse.fold<List<int>>(
            [],
            (a, b) => a..addAll(b),
          );
          expect(
            fullBytes,
            original,
            reason: 'Entire source must match the original fixture',
          );
          final seekRequest = await client.getUrl(stream.uri);
          seekRequest.headers.set('Range', 'bytes=1024-2047');
          final seekResponse = await seekRequest.close();
          expect(
            await seekResponse.fold<List<int>>([], (a, b) => a..addAll(b)),
            original.sublist(1024, 2048),
          );
        } finally {
          client.close(force: true);
        }
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PlayerVideoView(backend: backend)),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await backend.open(stream.uri);
      Future<void> waitFor(bool Function() condition) async {
        for (var i = 0; i < 200; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (condition()) return;
        }
        fail(
          'Timed out: ${backend.value.status}, ${backend.value.position}, ${backend.value.videoSize}',
        );
      }

      await waitFor(
        () =>
            backend.value.status == PlaybackStatus.playing &&
            backend.value.videoSize != null &&
            backend.value.position.inMilliseconds > 1200,
      );
      expect(backend.value.videoSize, const Size(160, 90));
      expect(backend.value.canSeek, isTrue);
      await backend.pause();
      await waitFor(() => backend.value.status == PlaybackStatus.paused);
      await backend.seek(const Duration(seconds: 7));
      await backend.play();
      await waitFor(() => backend.value.position.inSeconds >= 6);
      await tester.pumpWidget(const SizedBox());
    }, skip: kind != SourceKind.local && !services);
  }
}
