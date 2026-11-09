import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/sources/file_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/data/sources/source_schema.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('openplayx/source_access'),
        (_) async => null,
      );
  test('directory policy permits parent navigation, blocks sibling and symlink escape, scan respects excludes', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final root = await Directory.systemTemp.createTemp('source-scope-');
    final canonical = await root.resolveSymbolicLinks();
    final allowed = await Directory('${root.path}/movies/allowed')
        .create(recursive: true);
    final forbidden = await Directory('${root.path}/private').create();
    await File('${allowed.path}/keep.mp4').writeAsString('video');
    await File('${allowed.path}/skip.tmp').writeAsString('temporary');
    await File('${allowed.path}/.DS_Store').writeAsString('metadata');
    await File('${forbidden.path}/secret.mp4').writeAsString('private');
    await Link('${allowed.path}/linked').create(forbidden.path);
    final service = SourceConfigurationService(sqlite3.openInMemory());
    addTearDown(() async {
      service.close();
      await root.delete(recursive: true);
    });
    final config = SourceConfig(
      id: 'local',
      kind: SourceKind.local,
      name: 'Restricted',
      address: root.path,
      allowedPaths: const ['movies/allowed'],
      scanExclusions: const ['**/*.tmp', '**/.DS_Store'],
    );
    service.save(config, expectedRevision: 0);
    final host = SourceManager(configuration: service);
    await host.load();
    final page = await host.browse(config.id, const BrowseRequest());
    expect(page.entries.map((e) => e.name), ['movies']);
    final parent = await host.browse(
      config.id,
      BrowseRequest(node: page.entries.single.ref),
    );
    expect(parent.entries.single.name, 'allowed');
    final scan = await host.scan(config.id).toList();
    expect(scan.map((e) => e.name), ['keep.mp4']);
    final provider = LocalFolderPlugin(config);
    final context = CallContext.forInstance(config.id);
    await expectLater(
      provider.resolve(
        ResolveRequest(ResourceRef(config.id, '$canonical/private/secret.mp4')),
        context,
      ),
      throwsA(isA<PluginException>()),
    );
    await expectLater(
      provider.browse(
        BrowseRequest(
          node: ResourceRef(config.id, '$canonical/movies/allowed/linked'),
        ),
        context,
      ),
      throwsA(isA<PluginException>()),
    );
    await host.save(
      host.configs.single.copyWith(scanMode: ScanMode.disabled),
      '',
    );
    await expectLater(
      host.scan(config.id).toList(),
      throwsA(isA<PluginException>()),
    );
    await host.dispose();
  });
  test('protocol schemas expose only relevant connection fields and reject unavailable features', () {
    final local = SourceSchemas.forKind(SourceKind.local).configSchema!.fields;
    expect(local.map((f) => f.key), ['address']);
    final plex = SourceSchemas.forKind(SourceKind.plex).configSchema!.fields;
    expect(plex.map((f) => f.key), ['address']);
    const config = SourceConfig(
      id: 'id',
      kind: SourceKind.smb,
      name: 'NAS',
      address: 'smb://host/share',
    );
    for (final bad in [
      config.copyWith(allowedPaths: ['../private']),
      config.copyWith(requestTimeoutSeconds: 0),
      config.copyWith(maxConcurrentRequests: 9),
      config.copyWith(includeInSearch: true),
      config.copyWith(backgroundIndexing: true),
    ]) {
      expect(() => SourceSchemas.validate(bad), throwsFormatException);
    }
    expect(config.excludedFromScan('file'), isFalse);
    final policy = config.copyWith(
      scanExclusions: ['**/.DS_Store', 'private/**'],
    );
    expect(policy.excludedFromScan('.DS_Store'), isTrue);
    expect(policy.excludedFromScan('a/.DS_Store'), isTrue);
    expect(policy.excludedFromScan('private'), isTrue);
    expect(policy.excludedFromScan('private/file.mp4'), isTrue);
  });
}
