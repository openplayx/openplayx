import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/features/sources/controller/sources_controller.dart';
import 'package:openplayx/features/sources/model/sources_state.dart';
import 'package:sqlite3/sqlite3.dart';

import 'source_flow_test.dart' show MemorySources;

void main() {
  late LibraryService library;
  late MemorySources sources;
  late SourcesController controller;

  setUp(() {
    library = LibraryService(sqlite3.openInMemory());
    sources = MemorySources()
      ..saved.add(
        const SourceConfig(
          id: 'nas',
          kind: SourceKind.smb,
          name: 'NAS',
          address: 'smb://nas/media',
        ),
      );
    library.followSources(sources);
    controller = SourcesController(sources: sources, library: library);
  });
  tearDown(() {
    controller.dispose();
    library.close();
  });

  test('deleting a connection takes its file sources along, through the '
      'library following the sources', () async {
    library.addFileSource('nas', root: '/media', name: 'Films');
    expect(controller.fileSourcesOf('nas').single.name, 'Films');
    expect(controller.impact('nas').fileSources, 1);

    await controller.remove('nas');
    expect(controller.connections, isEmpty);
    expect(library.fileSourceList(), isEmpty);
    expect(controller.state.busy, isFalse);
    expect(controller.state.failure, isNull);
  });

  test('file sources of a connection that is gone stay listed as '
      'orphans', () {
    library.addFileSource('old', root: '/x', name: 'Old');
    expect(controller.orphanFileSources.single.connectionId, 'old');
    expect(controller.fileSourcesOf('nas'), isEmpty);
  });

  test('browsing opens folders, plays files and goes back out', () async {
    controller.browse(sources.saved.single);
    await pumpEventQueue();
    expect(controller.state.entries.single.name, 'Videos');

    expect(
      await controller.open(
        controller.state.entries.single,
        wanted: () => true,
      ),
      isNull, // a folder is browsed into
    );
    expect(controller.state.path.single.name, 'Videos');
    final file = controller.state.entries.single;
    final selection = await controller.open(file, wanted: () => true);
    expect(selection!.name, 'Demo.mp4');

    controller.back();
    await pumpEventQueue();
    expect(controller.state.path, isEmpty);
    controller.back();
    await pumpEventQueue();
    expect(controller.state.browsing, isNull);
  });

  test('a failing source reports its own message', () async {
    sources.failBrowse = true;
    controller.browse(sources.saved.single);
    await pumpEventQueue();
    expect(controller.state.failure?.kind, SourcesFailureKind.load);
    expect(controller.state.failure?.message, '测试服务不可用');
  });

  test('all source kinds start collapsed, enabled or disabled', () {
    for (final kind in SourceKind.values) {
      for (final enabled in [true, false]) {
        final connection = SourceConfig(
          id: '${kind.name}-$enabled',
          kind: kind,
          name: kind.name,
          address: '',
          enabled: enabled,
        );
        expect(controller.isExpanded(connection), isFalse);
      }
    }
  });

  test('manual expansion survives reloads per connection', () async {
    final nas = sources.saved.single;
    final other = SourceConfig(
      id: 'other',
      kind: nas.kind,
      name: 'Other',
      address: nas.address,
    );
    sources.saved.add(other);
    await controller.load();
    expect(controller.isExpanded(nas), isFalse);
    controller.setExpanded('nas', true);
    expect(controller.isExpanded(nas), isTrue);
    expect(controller.isExpanded(other), isFalse);
    await controller.load();
    expect(controller.isExpanded(nas), isTrue);
    expect(controller.isExpanded(other), isFalse);

    controller.setExpanded('nas', false);
    controller.setExpanded('other', true);
    await controller.load();
    expect(controller.isExpanded(nas), isFalse);
    expect(controller.isExpanded(other), isTrue);
  });

  test('changing enabled state does not change manual expansion', () async {
    final nas = sources.saved.single;
    controller.setExpanded('nas', true);
    // A refreshed config snapshot keeps the same connection identity.
    sources.saved[0] = nas.copyWith(enabled: false);
    await controller.load();
    expect(controller.isExpanded(sources.saved.single), isTrue);

    controller.setExpanded('nas', false);
    sources.saved[0] = nas.copyWith(enabled: true);
    await controller.load();
    expect(controller.isExpanded(sources.saved.single), isFalse);
  });

  test('a stale entry is never resolved for a page that left', () async {
    final selection = await controller.open(
      SourceEntry(
        const ResourceRef('nas', 'video'),
        'Demo.mp4',
        isFolder: false,
      ),
      wanted: () => false,
    );
    expect(selection, isNull);
    expect(sources.releases, 1);
  });
}
