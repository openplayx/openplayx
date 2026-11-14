import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/remote_access/remote_access_service.dart';
import 'package:openplayx/data/remote_access/remote_config.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'runtime SMB provider retains resolved Relay route and never dials LAN',
    () async {
      final configuration = SourceConfigurationService(sqlite3.openInMemory());
      final remote = RemoteAccessService.memory();
      remote.network = const RemoteNetwork(
        outbound: {
          'type': 'vless',
          'server': 'relay.test',
          'server_port': 443,
          'tls': {'enabled': true, 'server_name': 'relay.test'},
        },
        credential: {'uuid': '11111111-1111-4111-8111-111111111111'},
        proxies: [RemoteProxy('smb', 18445)],
      );
      final manager = SourceManager(
        configuration: configuration,
        remoteAccess: remote,
      );
      addTearDown(() async {
        await manager.dispose();
        configuration.close();
      });
      await manager.save(
        const SourceConfig(
          id: 'remote-smb',
          kind: SourceKind.smb,
          name: 'Remote SMB',
          address: 'smb://192.0.2.200/share',
          username: 'fixture-user',
          remote: SourceRemote(proxy: 'smb'),
        ),
        'fixture-smb-password',
      );
      var directSockets = 0;
      await IOOverrides.runZoned(
        () async {
          await expectLater(
            manager.browse('remote-smb', const BrowseRequest()),
            throwsA(
              // The Relay core is not available in tests: the route is still
              // the Relay one, and the LAN address is never dialled.
              isA<PluginException>().having(
                (e) => e.code,
                'code',
                'remoteCoreUnavailable',
              ),
            ),
          );
        },
        socketConnect:
            (
              host,
              port, {
              sourceAddress,
              int sourcePort = 0,
              Duration? timeout,
            }) async {
              directSockets++;
              throw StateError('Remote source must never dial LAN');
            },
      );
      expect(directSockets, 0);
    },
  );
}
