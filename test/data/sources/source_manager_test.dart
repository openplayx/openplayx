import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('openplayx/source_access'),
          (call) async => null,
        );
  });
  test('instances survive reload, credentials stay out of config, edits preserve or replace secrets', () async {
    final manager = SourceManager();
    const config = SourceConfig(
      id: 'one',
      kind: SourceKind.plex,
      name: 'Plex',
      address: 'http://localhost:32400',
    );
    await manager.save(config, 'private-token');
    final persisted = (await SharedPreferences.getInstance()).getString(
      'source.instances.v1',
    )!;
    expect(persisted, isNot(contains('private-token')));
    expect((jsonDecode(persisted) as List), hasLength(1));
    final reloaded = SourceManager();
    await reloaded.load();
    expect(reloaded.configs.single.name, 'Plex');
    await reloaded.save(
      const SourceConfig(
        id: 'one',
        kind: SourceKind.plex,
        name: 'New Plex',
        address: 'http://localhost:32401',
      ),
      '',
    );
    expect(
      await const FlutterSecureStorage().read(key: 'source.one'),
      'private-token',
    );
    expect(reloaded.configs.single.address, 'http://localhost:32401');
    await reloaded.save(reloaded.configs.single, 'replacement');
    expect(
      await const FlutterSecureStorage().read(key: 'source.one'),
      'replacement',
    );
    await reloaded.remove('one');
    expect(await const FlutterSecureStorage().read(key: 'source.one'), isNull);
    final empty = SourceManager();
    await empty.load();
    expect(empty.configs, isEmpty);
    await manager.dispose();
    await reloaded.dispose();
    await empty.dispose();
  });
  test(
    'new authenticated source requires a token and invalid paging is rejected',
    () async {
      final manager = SourceManager();
      await expectLater(
        manager.save(
          const SourceConfig(
            id: 'one',
            kind: SourceKind.plex,
            name: 'Plex',
            address: 'http://localhost:32400',
          ),
          '',
        ),
        throwsA(
          isA<PluginException>().having((e) => e.code, 'code', 'authRequired'),
        ),
      );
      await expectLater(
        manager.browse('one', const BrowseRequest(limit: 1000)),
        throwsA(isA<PluginException>()),
      );
      expect(manager.configs, isEmpty);
    },
  );
}
