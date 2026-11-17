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

  test('expanding follows the switch until the user chooses', () {
    final nas = sources.saved.single;
    expect(controller.isExpanded(nas), isTrue);
    controller.setExpanded('nas', false);
    expect(controller.isExpanded(nas), isFalse);
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
