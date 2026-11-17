import 'package:openplayx/capabilities/library/library_service.dart';

const _testFileSourceName = 'Test library';

/// Puts [media] in the library the way a scan finds it: evidence for it and
/// its files in [fileSource] (by default an enabled test file source), a
/// membership, and queued identification. Idempotent. Returns the file
/// source id.
String addToLibrary(
  LibraryService service,
  String media, {
  String? fileSource,
}) {
  final source =
      fileSource ??
      service
              .fileSources()
              .where((s) => s['name'] == _testFileSourceName)
              .firstOrNull?['id']
          as String? ??
      service.addFileSource('test', name: _testFileSourceName);
  final repository = service.repository;
  service.transaction(() {
    for (final row in service.db.select(
      'SELECT id FROM resources WHERE media_id=?',
      [media],
    )) {
      repository.observeResource(source, row['id'] as String, 'test');
    }
    repository.observeMedia(source, media);
    repository.observeMembership(media, DateTime.now().millisecondsSinceEpoch);
    repository.queueMetadata(media);
  });
  return source;
}
