import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/capabilities/web_playback/web_playback_catalog.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';

import '../../support/library_test_helpers.dart';

void main() {
  late LibraryService library;
  late SourceManager sources;
  late LibraryWebPlaybackCatalog catalog;
  setUp(() {
    library = LibraryService(sqlite3.openInMemory());
    sources = SourceManager();
    catalog = LibraryWebPlaybackCatalog(library, sources);
  });
  tearDown(() async {
    library.close();
    await sources.dispose();
  });
  String add(String path, String scope, String connection) {
    final id = library.register(
      SourceEntry(
        ResourceRef(connection, path),
        path.split('/').last,
        isFolder: false,
      ),
    );
    addToLibrary(library, id, fileSource: scope);
    return library.db.select('SELECT id FROM resources WHERE media_id=?', [
          id,
        ]).single['id']
        as String;
  }

  test('sharing only exposes enabled scopes and their own locators', () {
    final a = library.addFileSource('a', name: 'Movies');
    final b = library.addFileSource('b', name: 'Private');
    final ra = add('/films/a.mp4', a, 'a');
    final rb = add('/private/b.mp4', b, 'b');
    expect(catalog.list({}), isEmpty);
    expect(catalog.list({a}).map((m) => m.id), [ra]);
    expect(catalog.find({a}, rb), isNull);
    // A foreign locator cannot inherit authorization from an observed resource.
    library.repository.ensureLocator('a', '/alias', rb);
    expect(catalog.find({a}, rb), isNull);
    library.setFileSourceEnabled(a, false);
    expect(catalog.list({a}), isEmpty);
    expect(catalog.find({a}, ra), isNull);
  });
  test('scope settings persist but newly added folders are not shared', () {
    final a = library.addFileSource('a', name: 'Movies');
    catalog.saveSharedScopes({a});
    final reopened = LibraryWebPlaybackCatalog(library, sources);
    expect(reopened.loadSharedScopes(), {a});
    final b = library.addFileSource('b', name: 'New private folder');
    add('/private/new.mp4', b, 'b');
    expect(reopened.list(reopened.loadSharedScopes()), isEmpty);
  });
  test('hidden files missing evidence removed memberships and account visibility are enforced', () {
    final a = library.addFileSource('a', name: 'Movies');
    final visible = add('/a/visible.mp4', a, 'a');
    add('/a/.private.mp4', a, 'a');
    expect(catalog.list({a}).map((m) => m.id), [visible]);
    library.repository.connectionVisible = (_) => false;
    expect(catalog.find({a}, visible), isNull);
    library.repository.connectionVisible = null;
    library.db.execute('UPDATE evidence SET available=0');
    expect(catalog.list({a}), isEmpty);
  });
  test('progress is written with the existing library session guard', () {
    final a = library.addFileSource('a', name: 'Movies');
    final id = add('/a/film.mp4', a, 'a');
    final media = catalog.find({a}, id)!;
    final session = catalog.beginProgress(media);
    catalog.saveProgress(media, session, 1200, 6000, false);
    expect(library.progressOf(id)!.position.inMilliseconds, 1200);
    final newer = library.beginSession(id);
    catalog.saveProgress(media, session, 5000, 6000, true);
    expect(library.progressOf(id)!.position.inMilliseconds, 1200);
    library.saveProgress(
      id,
      newer,
      const Duration(seconds: 2),
      const Duration(seconds: 6),
    );
    expect(catalog.find({a}, id)!.positionMs, 2000);
  });
}
