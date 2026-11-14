import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:openplayx/features/player/player_page.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/services/subtitles/recognized_subtitles.dart';
import 'package:openplayx_playback/playback.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../app_test_host.dart';
import 'player_page_test.dart' show FakeBackend;

/// Fake player that accepts external subtitle files like libVLC: the added
/// file becomes a new selectable track.
class _ExternalBackend extends FakeBackend {
  final added = <Uri>[];
  @override
  bool get supportsExternalSubtitles => true;
  @override
  Future<void> addExternalSubtitle(Uri file) async => added.add(file);
  @override
  Future<List<PlayerSubtitleTrack>> getSubtitleTracks() async => [
    ...await super.getSubtitleTracks(),
    for (var i = 0; i < added.length; i++)
      PlayerSubtitleTrack(id: 20 + i, name: 'Track ${20 + i}'),
  ];
}

void _schema(Database db) {
  db.execute('''CREATE TABLE IF NOT EXISTS media_artifacts (
    id TEXT PRIMARY KEY, task_id TEXT NOT NULL, kind TEXT NOT NULL,
    path TEXT NOT NULL, name TEXT NOT NULL, bytes INTEGER NOT NULL,
    created INTEGER NOT NULL)''');
  db.execute('''CREATE TABLE IF NOT EXISTS subtitle_bindings (
    id TEXT PRIMARY KEY, task_id TEXT NOT NULL, subtitle_artifact_id TEXT NOT NULL,
    transcript_artifact_id TEXT, resource_source TEXT NOT NULL,
    resource_item TEXT NOT NULL, fingerprint TEXT, track_index INTEGER,
    range_start_ms INTEGER NOT NULL, range_end_ms INTEGER NOT NULL,
    partial INTEGER NOT NULL, language TEXT, backend TEXT, model_id TEXT,
    model_revision TEXT, preset_revision INTEGER, format TEXT NOT NULL,
    created INTEGER NOT NULL)''');
}

void _bind(
  Database db,
  String id,
  String path,
  String item, {
  bool partial = true,
}) {
  db.execute('INSERT INTO media_artifacts VALUES (?,?,?,?,?,?,?)', [
    'a-$id',
    't',
    'subtitle',
    path,
    'x.srt',
    10,
    0,
  ]);
  db.execute(
    '''INSERT INTO subtitle_bindings (id,task_id,subtitle_artifact_id,resource_source,
       resource_item,range_start_ms,range_end_ms,partial,language,backend,model_id,format,created)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)''',
    [
      id,
      't',
      'a-$id',
      '@local',
      item,
      0,
      60000,
      partial ? 1 : 0,
      'en',
      'embedded',
      'whisper-base-multilingual',
      'srt',
      1700000000000,
    ],
  );
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('opx_rec_sub'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test(
    'lists saved subtitles of exactly this resource; missing files skipped',
    () {
      final db = sqlite3.openInMemory();
      expect(
        recognizedSubtitles(db, const ResourceRef('@local', '/a.mkv')),
        isEmpty,
      );
      _schema(db);
      final file = File('${tmp.path}/a.srt')
        ..writeAsStringSync('1\n00:00:01,000 --> 00:00:02,000\nhi\n');
      _bind(db, 'b1', file.path, '/a.mkv');
      _bind(db, 'b2', '${tmp.path}/gone.srt', '/a.mkv');
      _bind(db, 'b3', file.path, '/other.mkv');
      final list = recognizedSubtitles(
        db,
        const ResourceRef('@local', '/a.mkv'),
      );
      expect(list.map((s) => s.bindingId), ['b1']);
      expect(list.single.partial, isTrue);
      db.close();
    },
  );

  testWidgets(
    'subtitle sheet shows recognised entries after embedded ones; selecting loads once',
    (tester) async {
      final library = LibraryService(sqlite3.openInMemory());
      addTearDown(library.close);
      _schema(library.db);
      final srt = File('${tmp.path}/rec.srt')
        ..writeAsStringSync('1\n00:00:01,000 --> 00:00:02,000\nhi\n');
      _bind(library.db, 'b1', srt.path, '/demo.mp4');
      final backend = _ExternalBackend();
      await tester.pumpWidget(
        TestApp(
          home: PlayerPage(
            backend: backend,
            libraryService: library,
            pickMedia: () async =>
                LocalMedia(Uri.file('/demo.mp4'), 'demo.mp4'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.state<PlayerPageState>(find.byType(PlayerPage)).openFile();
      // Tracking resolves the local path with real file IO.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('字幕'));
      await tester.pumpAndSettle();
      expect(find.text('简体中文'), findsOneWidget); // embedded tracks stay
      expect(find.text('识别字幕'), findsOneWidget);
      expect(find.text('识别'), findsOneWidget); // badge
      expect(find.textContaining('部分 00:00–01:00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recognized-b1')));
      await tester.pumpAndSettle();
      expect(backend.added, [Uri.file(srt.path)]);

      // Re-opening: the loaded copy is not listed again as an embedded track,
      // and selecting the recognised entry again switches without re-adding.
      await tester.tap(find.byTooltip('字幕'));
      await tester.pumpAndSettle();
      expect(find.text('Track 20'), findsNothing);
      await tester.tap(find.text('简体中文'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('字幕'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recognized-b1')));
      await tester.pumpAndSettle();
      expect(backend.added, hasLength(1));
      expect(backend.subtitleSelections, [2, 20]);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('players without external subtitle support do not list them', (
    tester,
  ) async {
    final library = LibraryService(sqlite3.openInMemory());
    addTearDown(library.close);
    _schema(library.db);
    final srt = File('${tmp.path}/rec.srt')..writeAsStringSync('x');
    _bind(library.db, 'b1', srt.path, '/demo.mp4');
    await tester.pumpWidget(
      TestApp(
        home: PlayerPage(
          backend: FakeBackend(),
          libraryService: library,
          pickMedia: () async => LocalMedia(Uri.file('/demo.mp4'), 'demo.mp4'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.state<PlayerPageState>(find.byType(PlayerPage)).openFile();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('字幕'));
    await tester.pumpAndSettle();
    expect(find.text('识别字幕'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('assistant shows the newest saved subtitle, a named one, or '
      'none', (tester) async {
    final library = LibraryService(sqlite3.openInMemory());
    addTearDown(library.close);
    _schema(library.db);
    final srt = File('${tmp.path}/rec.srt')
      ..writeAsStringSync('1\n00:00:01,000 --> 00:00:02,000\nhi\n');
    _bind(library.db, 'b1', srt.path, '/demo.mp4');
    final backend = _ExternalBackend();
    await tester.pumpWidget(
      TestApp(
        home: PlayerPage(
          backend: backend,
          libraryService: library,
          pickMedia: () async => LocalMedia(Uri.file('/demo.mp4'), 'demo.mp4'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester.state<PlayerPageState>(find.byType(PlayerPage));
    await state.openFile();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final session = state.assistantSnapshot()['session_id'];

    Future<Map<String, dynamic>> control(Map<String, dynamic> args) async {
      late Map<String, dynamic> result;
      await tester.runAsync(() async {
        result = await state.assistantControl('set_subtitle', {
          'session_id': session,
          ...args,
        });
      });
      await tester.pumpAndSettle();
      return result;
    }

    expect((await control({}))['subtitle'], {
      'kind': 'recognized',
      'binding_id': 'b1',
    });
    expect(backend.added, [Uri.file(srt.path)]);
    expect((await control({'off': true}))['subtitle'], {
      'kind': 'off_or_default',
    });
    await control({'binding_id': 'b1'});
    expect(backend.added, hasLength(1)); // switched back without re-adding
    Object? error;
    await tester.runAsync(() async {
      try {
        await state.assistantControl('set_subtitle', {
          'session_id': session,
          'binding_id': 'other',
        });
      } catch (e) {
        error = e;
      }
    });
    expect(error, isA<StateError>());
    expect((error as StateError).message, 'subtitleNotFound');
    await tester.pumpWidget(const SizedBox());
  });
}
