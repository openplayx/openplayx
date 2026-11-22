// Run with flutter-tvos run -d <Apple-TV-simulator> -t tool/tvos_smoke.dart.
// Exercises native storage and VLC without real accounts or network services.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openplayx_playback/playback.dart';
import 'package:openplayx_ffmpeg/openplayx_ffmpeg.dart';
import 'package:openplayx_whisper/openplayx_whisper.dart';
import 'package:openplayx/data/remote_access/remote_native.dart';

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
    // Verify actual media processing, not only the presence of a dylib.
    final processor = MediaProcessor();
    if (!processor.available) throw StateError('FFmpeg library unavailable');
    final caps = await processor.capabilities();
    final expectedEncoders = ['libx264', 'libx265', 'libaom-av1', 'libvpx-vp9', 'libmp3lame', 'libopus'];
    if (!expectedEncoders.every(caps.encoders.contains)) {
      throw StateError('Missing FFmpeg codecs: ${caps.encoders}');
    }
    checks['ffmpeg_encoders'] = caps.encoders.toList();
    final probe = await processor.probe(video.path);
    if (probe.primaryVideo == null) throw StateError('FFmpeg probe failed');
    final plan = MediaPlanner.plan(
      MediaPreset.imagePreview,
      probe,
      caps,
      PlanRequest(time: Duration(microseconds: probe.durationUs ~/ 2)),
    );
    final frame =
        '${directory.path}/tvos-smoke-${DateTime.now().microsecondsSinceEpoch}.jpg';
    final result = await processor
        .submit(plan, input: video.path, output: frame)
        .done;
    if (!result.succeeded ||
        !await File(frame).exists() ||
        await File(frame).length() == 0) {
      throw StateError('FFmpeg snapshot failed: ${result.error}');
    }
    checks['ffmpeg_probe_snapshot'] = 'passed';
    processor.dispose();

    final whisper = WhisperEngine();
    if (!whisper.info().available)
      throw StateError('Whisper engine unavailable');
    checks['whisper_version'] = whisper.info().engineVersion;
    final model = await whisper.openModel('${directory.path}/ggml-tiny.bin');
    final speech = await rootBundle.load('test/fixtures/asr_en.wav');
    final wav = File('${directory.path}/tvos-smoke.wav');
    await wav.writeAsBytes(
      speech.buffer.asUint8List(speech.offsetInBytes, speech.lengthInBytes),
    );
    final transcription = await whisper
        .transcribe(model, AsrRequest(input: wav.path, language: 'en'))
        .done
        .timeout(const Duration(minutes: 2));
    final text =
        transcription.transcript?.windows
            .expand((w) => w.segments)
            .map((s) => s.text)
            .join(' ')
            .toLowerCase() ??
        '';
    if (!transcription.succeeded || !text.contains('quick brown fox')) {
      throw StateError(
        'Whisper transcription failed: ${transcription.error}, $text',
      );
    }
    checks['whisper_transcribe'] = 'passed';
    checks['whisper_text'] = text;
    model.close();
    whisper.dispose();

    // The public C ABI accepts only VLESS with verified TLS, so exercise a
    // valid session lifecycle without contacting an external relay.
    final remote = RemoteNative.instance;
    final port = remote.start({
      'type': 'vless',
      'server': 'relay.example.invalid',
      'server_port': 443,
      'uuid': '11111111-1111-4111-8111-111111111111',
      'tls': {'enabled': true, 'server_name': 'relay.example.invalid'},
    }, 18096);
    if (port <= 0) throw StateError('Remote core did not create a listener');
    remote.stop(port);
    checks['remote_start_stop'] = 'passed';
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
        if (DateTime.now().isAfter(deadline)) {
          throw StateError(
            'Timed out: ${backend!.value.status}, ${backend.value.position}',
          );
        }
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
