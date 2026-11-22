// Run with flutter-tvos run -d <Apple-TV-simulator> -t tool/tvos_smoke.dart.
// Exercises native storage and VLC without real accounts or network services.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openplayx_playback/playback.dart';

import 'package:openplayx/data/configuration/configuration_database.dart';
import 'package:openplayx/data/library/library_database.dart';
import 'package:openplayx/data/storage/app_directories.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await appSupportDirectory();
  await directory.create(recursive: true);
  final report = File('${directory.path}/tvos-smoke.json');
  final checks = <String, Object>{};
  LibVlcBackend? backend;
  try {
    final db = await ConfigurationDatabase.open();
    ConfigurationDatabase.writeSetting(db, 'tvos_smoke', 'probe', 'ok');
    if (ConfigurationDatabase.readSetting(db, 'tvos_smoke', 'probe') != 'ok') {
      throw StateError('SQLite round trip failed');
    }
    db.close();
    final library = await LibraryDatabase.open('tvos_smoke.sqlite3');
    LibraryDatabase.initialize(library);
    library.close();
    checks['sqlite'] = 'passed';
    checks['storage'] = directory.path.contains('/Caches/')
        ? 'passed'
        : 'failed';
    final data = await rootBundle.load('test/fixtures/test_video.mp4');
    final video = File('${directory.path}/tvos-smoke.mp4');
    await video.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    backend = LibVlcBackend();
    runApp(
      MaterialApp(
        home: Scaffold(body: PlayerVideoView(backend: backend)),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(seconds: 1));
    await backend.open(video.uri);
    Future<void> waitFor(bool Function() ready) async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!ready()) {
        if (DateTime.now().isAfter(deadline))
          throw StateError(
            'Timed out: ${backend!.value.status}, ${backend.value.position}',
          );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    await waitFor(
      () =>
          backend!.value.position > const Duration(milliseconds: 400) &&
          backend.value.videoSize != null,
    );
    checks['decode'] = 'passed';
    await backend.pause();
    await waitFor(() => backend!.value.status == PlaybackStatus.paused);
    checks['pause'] = 'passed';
    await backend.seek(const Duration(milliseconds: 500));
    await backend.play();
    await waitFor(() => backend!.value.status == PlaybackStatus.playing);
    checks['seek_resume'] = 'passed';
    checks['status'] = 'passed';
  } catch (error, stack) {
    checks['status'] = 'failed';
    checks['error'] = '$error';
    debugPrint('$error\n$stack');
  }
  await report.writeAsString(jsonEncode(checks), flush: true);
  debugPrint('TVOS_SMOKE ${jsonEncode(checks)}');
}
