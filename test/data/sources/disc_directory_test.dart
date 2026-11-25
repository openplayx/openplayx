import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/sources/file_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/capabilities/library/library_service.dart';

class _Sources extends SourceManager {
  _Sources(this.plugin);
  final LocalFolderPlugin plugin;
  @override
  List<SourceConfig> get configs => [plugin.config];
  @override
  Future<void> load() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<BrowseResult> browse(String id, BrowseRequest r) =>
      plugin.browse(r, CallContext.forInstance(id));
}

void main() {
  late Directory root;
  late LocalFolderPlugin source;
  final context = CallContext.forInstance('discs');
  Future<void> touch(String p) async {
    final f = File('${root.path}/$p');
    await f.parent.create(recursive: true);
    await f.writeAsBytes([1]);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('disc-source-');
    for (final f in [
      'Blu ray title/BDMV/index.bdmv',
      'Blu ray title/BDMV/MovieObject.bdmv',
      'Blu ray title/BDMV/PLAYLIST/00000.mpls',
      'Blu ray title/BDMV/CLIPINF/00000.clpi',
      'Blu ray title/BDMV/STREAM/00000.m2ts',
      'DVD title/VIDEO_TS/VIDEO_TS.IFO',
      'DVD title/VIDEO_TS/VIDEO_TS.BUP',
      'DVD title/VIDEO_TS/VTS_01_0.IFO',
      'DVD title/VIDEO_TS/VTS_01_1.VOB',
    ]) {
      await touch(f);
    }
    source = LocalFolderPlugin(
      SourceConfig(
        id: 'discs',
        kind: SourceKind.local,
        name: 'Discs',
        address: root.path,
      ),
    );
  });
  tearDown(() async {
    await source.dispose();
    await root.delete(recursive: true);
  });
  test(
    'each complete local disc is one playable item, not navigable fragments',
    () async {
      final page = await source.browse(const BrowseRequest(), context);
      expect(page.entries, hasLength(2));
      expect(page.entries.every((e) => e.isDisc && !e.isFolder), isTrue);
      for (final e in page.entries) {
        final stream = await source.resolve(ResolveRequest(e.ref), context);
        expect(stream.uri.scheme, e.name.startsWith('Blu') ? 'bluray' : 'dvd');
        expect(stream.uri.replace(scheme: 'file').toFilePath(), e.ref.id);
        expect(stream.uri.hasAuthority, isTrue);
        await stream.release();
      }
      final library = LibraryService(sqlite3.openInMemory());
      addTearDown(library.close);
      final fileSource = library.addFileSource('discs', root: root.path);
      final sources = _Sources(source);
      await library.scan(fileSource, sources);
      await library.scan(fileSource, sources);
      expect(library.query(), hasLength(2));
    },
  );
  test(
    'native reader cannot follow symlinks or bypass source authorization',
    () async {
      final outside = await Directory.systemTemp.createTemp('disc-outside-');
      addTearDown(() => outside.delete(recursive: true));
      await Link('${root.path}/Blu ray title/BDMV/STREAM/outside')
          .create(outside.path);
      final page = await source.browse(const BrowseRequest(), context);
      expect(page.entries.map((e) => e.name), ['DVD title']);
      await expectLater(
        source.resolve(
          ResolveRequest(ResourceRef('discs', '${root.path}/Blu ray title')),
          context,
        ),
        throwsA(isA<PluginException>()),
      );
      await expectLater(
        source.resolve(
          ResolveRequest(ResourceRef('discs', outside.path)),
          context,
        ),
        throwsA(isA<PluginException>()),
      );
    },
  );
}
