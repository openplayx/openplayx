import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/remote_access/remote_access_service.dart';
import 'package:openplayx/data/remote_access/remote_config.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'runtime SMB provider retains resolved Relay route and never dials LAN',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final configuration = SourceConfigurationService(sqlite3.openInMemory());
      final remote = RemoteAccessService.memory();
      remote.network = const RemoteNetwork(
        outbound: {
          'type': 'vless',
          'server': 'relay.test',
          'server_port': 443,
          'tls': {'enabled': true, 'server_name': 'relay.test'},
        },
        credentialRef: 'remote.outbound.missing-fixture',
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
              isA<PluginException>()
                  .having((e) => e.code, 'code', 'authRequired')
                  .having((e) => e.message, 'message', contains('远程访问凭据不可用')),
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
