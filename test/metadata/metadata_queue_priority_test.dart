import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/metadata/metadata_queue.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late LibraryService library;
  late List<String> media;
  setUp(() {
    library = LibraryService(
      sqlite3.openInMemory(),
      watchExternalChanges: false,
    );
    final lib = library.create('Films');
    media = [
      for (final name in ['A', 'B', 'C', 'D'])
        library.register(
          SourceEntry(
            ResourceRef('s', '/$name.mkv'),
            '$name.mkv',
            isFolder: false,
          ),
        ),
    ];
    for (final m in media) {
      library.addManual(lib, m);
    }
  });
  tearDown(() => library.close());

  String claimed(MetadataQueue q, String owner) =>
      q.claim(owner)!['media_id'] as String;

  test('boosted items are claimed first, most recent boost wins', () {
    final queue = MetadataQueue(library.db);
    final baseline = claimed(queue, 'probe');
    queue.release('probe');
    final target = media.firstWhere((m) => m != baseline);
    final other = media.firstWhere((m) => m != baseline && m != target);
    library.prioritizeMetadata([target]);
    library.prioritizeMetadata([other]);
    expect(claimed(queue, 'o1'), other);
    expect(claimed(queue, 'o2'), target);
  });

  test('order inside one boost is preserved', () {
    final queue = MetadataQueue(library.db);
    library.prioritizeMetadata([media[3], media[2]]);
    expect(claimed(queue, 'o1'), media[3]);
    expect(claimed(queue, 'o2'), media[2]);
  });

  test('finished, running and unknown items are not boosted', () {
    final queue = MetadataQueue(library.db);
    final first = claimed(queue, 'o');
    expect(queue.boost([first, 'missing']), 0);
    queue.finish(first, 'o', 'completed');
    expect(queue.boost([first]), 0);
    expect(queue.item(first)!['priority'], 0);
  });

  test('priority clears on completion but survives a requeued phase', () {
    final queue = MetadataQueue(library.db);
    library.prioritizeMetadata([media[1]]);
    final id = claimed(queue, 'o');
    expect(id, media[1]);
    queue.finish(id, 'o', 'queued', phase: 1);
    expect(queue.item(id)!['priority'], greaterThan(0));
    expect(claimed(queue, 'o2'), id);
    queue.finish(id, 'o2', 'completed');
    expect(queue.item(id)!['priority'], 0);
  });

  test('a boost wakes listeners only when something changed', () async {
    var events = 0;
    final sub = library.priorityRequests.listen((_) => events++);
    library.prioritizeMetadata([media[0]]);
    library.prioritizeMetadata(['missing']);
    await Future<void>.delayed(Duration.zero);
    expect(events, 1);
    await sub.cancel();
  });

  test('progress counts finished states, not queued, blocked or removed', () {
    final queue = MetadataQueue(library.db);
    expect(queue.progress, (done: 0, total: 4));
    void set(int i, String state) => library.db.execute(
      'UPDATE metadata_queue SET state=? WHERE media_id=?',
      [state, media[i]],
    );
    set(0, 'completed');
    set(1, 'unmatched');
    set(2, 'waitingConfiguration');
    expect(queue.progress, (done: 2, total: 4));
    set(3, 'cancelled');
    expect(queue.progress, (done: 2, total: 3));
    set(2, 'failed');
    expect(queue.progress, (done: 3, total: 3));
  });
}
