import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/data/sources/source_sign_in.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:sqlite3/sqlite3.dart';
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
      final mediaDirectory = await Directory('${dir.path}/media').create();
      final fixture = await createTestVideo(mediaDirectory);
      var config = SourceConfig(
        id: 'integration-${kind.name}-${DateTime.now().microsecondsSinceEpoch}',
        kind: kind,
        name: kind.label,
        address: switch (kind) {
          SourceKind.local => mediaDirectory.path,
          SourceKind.smb => 'smb://127.0.0.1',
          SourceKind.plex => 'http://127.0.0.1:13240',
          SourceKind.jellyfin => 'http://127.0.0.1:18096',
        },
        username: 'openplayx',
        userId: const String.fromEnvironment('JELLYFIN_USER_ID'),
      );
      final configuration = SourceConfigurationService(
        sqlite3.open('${dir.path}/configuration.sqlite3'),
      );
      final manager = SourceManager(configuration: configuration);
      final backend = LibVlcBackend();
      PlayableStream? stream;
      addTearDown(() async {
        backend.dispose();
        await stream?.release();
        if (manager.configs.any((c) => c.id == config.id)) {
          await manager.remove(config.id);
        }
        await manager.dispose();
        configuration.close();
        await dir.delete(recursive: true);
      });
      String? jellyfinToken;
      if (kind == SourceKind.jellyfin) {
        final signIn = SourceSignIn();
        try {
          final session = await signIn.jellyfin(config, 'test-only-password');
          config = config.copyWith(userId: session.userId);
          jellyfinToken = session.token;
        } finally {
          signIn.close();
        }
      }
      debugPrint('Source integration: ${kind.name} saving');
      await manager.save(config, switch (kind) {
        SourceKind.local => '',
        SourceKind.smb => 'test-only-password',
        SourceKind.plex => 'test-token',
        SourceKind.jellyfin => jellyfinToken!,
      });
      debugPrint('Source integration: ${kind.name} saved');
      await manager.setDefault('source.browse', config.id);
      // Test bounded pages and traverse the actual media library to a playable leaf.
      Future<SourceEntry?> findVideo(ResourceRef? node, int depth) async {
        if (depth > 5) return null;
        int? offset = 0;
        while (offset != null) {
          final request = BrowseRequest(node: node, offset: offset, limit: 10);
          final page = node == null
              ? await manager.browseDefault(request)
              : await manager.browse(config.id, request);
          for (final entry in page.entries) {
            if (!entry.isFolder) return entry;
            final child = await findVideo(entry.ref, depth + 1);
            if (child != null) return child;
          }
          offset = page.nextOffset;
        }
        return null;
      }

      debugPrint('Source integration: ${kind.name} browsing');
      final entry = await findVideo(null, 0);
      debugPrint('Source integration: ${kind.name} browsed');
      expect(
        entry,
        isNotNull,
        reason: 'Fixture must be discoverable from source root',
      );
      stream = await manager.resolve(entry!.ref);
      debugPrint('Source integration: ${kind.name} resolved');
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
      expect(manager.impact(config.id).playing, 1);
      debugPrint('Source integration: ${kind.name} disabling');
      await manager.setEnabled(config.id, false);
      debugPrint('Source integration: ${kind.name} disabled');
      await expectLater(
        manager.browse(config.id, const BrowseRequest()),
        throwsA(
          isA<PluginException>().having((e) => e.code, 'code', 'disabled'),
        ),
      );
      // Already-issued playback keeps its lease while future calls are blocked.
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
