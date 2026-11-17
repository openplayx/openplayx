import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/features/library/controller/home_controller.dart';
import 'package:openplayx/features/library/controller/media_detail_controller.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../support/library_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LibraryService library;

  setUp(() => library = LibraryService(sqlite3.openInMemory()));
  tearDown(() => library.close());

  String film() {
    final id = library.register(
      const SourceEntry(
        ResourceRef('nas', '/films/Film.mp4'),
        'Film.mp4',
        isFolder: false,
      ),
    );
    addToLibrary(library, id);
    return id;
  }

  group('MediaDetailController', () {
    test('a movie plays its version and tracks progress', () {
      final id = film();
      final controller = MediaDetailController(
        service: library,
        media: {'id': id, 'title': 'Film'},
      );
      addTearDown(controller.dispose);
      expect(controller.series, isFalse);
      expect(controller.playable, isTrue);
      final version = controller.versions(id).single;
      expect(
        (version.ref.instanceId, version.ref.id),
        ('nas', '/films/Film.mp4'),
      );
      expect(controller.latestProgress(id), isNull);

      final session = library.beginSession(version.id);
      library.saveProgress(
        version.id,
        session,
        const Duration(minutes: 3),
        const Duration(minutes: 90),
      );
      final progress = controller.latestProgress(id)!;
      expect(progress.inProgress, isTrue);
      expect(progress.position, const Duration(minutes: 3));
    });

    test('extras show without the series prefix', () {
      expect(
        MediaDetailController.extraTitle('Show - S01 Extra - Making Of.mkv'),
        'Making Of',
      );
      expect(MediaDetailController.extraTitle('Trailer.mp4'), 'Trailer');
    });
  });

  group('HomeController', () {
    test('changes while hidden reload once the page is visible', () async {
      final controller = HomeController(library);
      addTearDown(controller.dispose);
      var notified = 0;
      controller.addListener(() => notified++);
      controller.setVisible(false);
      film();
      library.notifyChanged();
      await pumpEventQueue();
      expect(notified, 0);
      expect(controller.shelves.recentlyAdded, isEmpty);

      controller.setVisible(true);
      expect(notified, 1);
      expect(controller.shelves.recentlyAdded, hasLength(1));
      expect(controller.hasFileSources, isTrue);
    });
  });
}
