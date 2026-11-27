import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/remote_access/remote_config.dart';
import 'package:openplayx/data/sources/file_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_connection.dart';

void main() {
  group('LocalFolderPlugin', () {
    late Directory root;
    late LocalFolderPlugin plugin;
    final ctx = CallContext.forInstance('loc-1');

    setUp(() {
      root = Directory.systemTemp.createTempSync('opx_local_src_');
      Directory('${root.path}/Movies').createSync();
      File('${root.path}/Movies/film.mkv').writeAsBytesSync([0, 1, 2, 3, 4]);
      File('${root.path}/Movies/film.nfo')
          .writeAsStringSync('<movie><title>Film</title></movie>');
      File('${root.path}/notes.txt').writeAsStringSync('ignore');
      plugin = LocalFolderPlugin(
        SourceConfig(
          id: 'loc-1',
          name: 'Local',
          kind: SourceKind.local,
          address: root.path,
        ),
      );
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test('manifest, browse, resolve, attachments and traversal guard', () async {
      expect(plugin.manifest.id, isNotEmpty);

      final top = await plugin.browse(const BrowseRequest(), ctx);
      expect(top.entries.any((e) => e.isFolder && e.name == 'Movies'), isTrue);

      final moviesFolder = top.entries.firstWhere((e) => e.name == 'Movies');
      final inside = await plugin.browse(
        BrowseRequest(node: moviesFolder.ref),
        ctx,
      );
      expect(inside.entries.any((e) => e.name == 'film.mkv'), isTrue);

      final film = inside.entries.firstWhere((e) => e.name == 'film.mkv');
      final stream = await plugin.resolve(ResolveRequest(film.ref), ctx);
      expect(stream.uri.scheme, 'file');
      await stream.release();

      // Wrong ownership rejected
      expect(
        () => checkOwnership(
          'loc-1',
          film.ref,
          CallContext.forInstance('other'),
        ),
        throwsA(isA<PluginException>()),
      );

      // Path outside root rejected
      await expectLater(
        plugin.resolve(
          const ResolveRequest(ResourceRef('loc-1', '/etc/hosts')),
          ctx,
        ),
        throwsA(isA<PluginException>()),
      );

      // Missing file rejected
      await expectLater(
        plugin.resolve(
          ResolveRequest(ResourceRef('loc-1', '${root.path}/missing.mkv')),
          ctx,
        ),
        throwsA(isA<PluginException>()),
      );

      // Attachment read (sibling NFO) + quotaExceeded guard
      final nfo = inside.entries.firstWhere((e) => e.name == 'film.nfo');
      final bytes = await plugin.readAttachment(nfo.ref, ctx, maxBytes: 1024);
      expect(bytes, isNotEmpty);
      await expectLater(
        plugin.readAttachment(nfo.ref, ctx, maxBytes: 2),
        throwsA(isA<PluginException>()),
      );
      await plugin.dispose();
    });
  });

  group('SourceConfig, SourceConnection & SourceRemote', () {
    test('SourceConnection parses and formats all protocol kinds', () {
      for (final (kind, addr) in [
        (SourceKind.smb, 'smb://192.168.1.2/share'),
        (SourceKind.webdav, 'https://dav.example.com:8443/files'),
        (SourceKind.ftp, 'ftp://ftp.example.com:2121/pub'),
        (SourceKind.sftp, 'sftp://sftp.example.com:2222/home'),
        (SourceKind.s3, 'https://s3.example.com/bucket'),
        (SourceKind.plex, 'http://192.168.1.5:32400'),
        (SourceKind.jellyfin, 'http://192.168.1.6:8096'),
        (SourceKind.emby, 'https://emby.example.com'),
      ]) {
        final cfg = SourceConfig(
          id: 'id-${kind.name}',
          name: kind.name,
          kind: kind,
          address: addr,
        );
        final conn = SourceConnection.fromConfig(cfg);
        expect(conn.host, isNotEmpty);
        final rt = SourceConfig.fromJson(cfg.toJson());
        expect(rt.kind, kind);
        expect(rt.address, addr);
      }
    });

    test('SourceRemote JSON round-trip', () {
      const remote = SourceRemote(
        proxy: 'home-nas',
        accountId: 'acc-1',
        connectorId: 'conn-1',
        serviceName: 'nas',
        managedLocal: true,
        mode: RemoteConnectionMode.remoteOnly,
      );
      final decoded = SourceRemote.fromJson(remote.toJson());
      expect(decoded.proxy, 'home-nas');
      expect(decoded.managedLocal, isTrue);
      expect(decoded.mode, RemoteConnectionMode.remoteOnly);
    });
  });
}
