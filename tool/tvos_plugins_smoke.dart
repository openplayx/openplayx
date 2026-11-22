// Native plugin verification: no real accounts, production telemetry or microphone hardware.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter_tvos/sentry_flutter_tvos.dart';
import 'package:record/record.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:openplayx/data/storage/app_directories.dart';
import 'package:openplayx/capabilities/speech/asr_model_store.dart';
import 'package:openplayx_whisper/openplayx_whisper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Apple TV native plugin verification')),
      ),
    ),
  );
  final report = <String, Object>{};
  final dir = await appSupportDirectory();
  await dir.create(recursive: true);
  HttpServer? server;
  try {
    final caps = await const MethodChannel('openplayx/tvos')
        .invokeMapMethod<String, dynamic>('capabilities');
    if (caps?.values.any((v) => v != true) ?? true)
      throw StateError('Native capabilities unavailable');
    report['native_services'] = caps!;
    try {
      await const MethodChannel('openplayx/tvos')
          .invokeMethod<void>('scheduleMetadata', {'online': true});
      report['background_schedule'] = 'passed';
    } on PlatformException catch (e) {
      if (e.code != 'BACKGROUND_UNAVAILABLE') rethrow;
      report['background_schedule'] =
          'OS unavailable in simulator; physical-device validation required';
    }
    if (FileSelectorPlatform.instance.runtimeType.toString() !=
        'TVOSFileSelector')
      throw StateError('tvOS picker not registered');
    report['file_picker_registration'] = 'passed';
    try {
      await const MethodChannel('flutter_web_auth_2')
          .invokeMethod<String>('authenticate', {
            'url': 'file:///not-permitted',
            'callbackUrlScheme': 'com.openplayx.app',
          });
      throw StateError('Invalid OAuth URL accepted');
    } on PlatformException catch (e) {
      if (e.code != 'INVALID_URL') rethrow;
      report['authentication_channel'] = 'passed';
    }
    final recorder = AudioRecorder();
    if (!await recorder.isEncoderSupported(AudioEncoder.wav))
      throw StateError('WAV recorder unavailable');
    await recorder.dispose();
    report['recording_plugin'] = 'passed';
    final modelStore = AsrModelStore(asrModelRoot());
    final model = await modelStore.path('whisper-tiny-multilingual');
    if (model == null ||
        !await Directory(
          '${File(model).parent.path}/ggml-tiny-encoder.mlmodelc',
        ).exists())
      throw StateError('Bundled model not installed');
    report['offline_models'] = 'passed';
    final engine = WhisperEngine();
    final info = engine.info();
    report['whisper_backends'] = info.systemInfo;
    if (!info.systemInfo.contains('COREML = 1') ||
        !info.systemInfo.contains('MTL :'))
      throw StateError('Apple accelerators absent: ${info.systemInfo}');
    final loaded = await engine.openModel(model);
    final wav = await rootBundle.load('test/fixtures/asr_en.wav');
    final input = File('${dir.path}/plugins-speech.wav');
    await input.writeAsBytes(
      wav.buffer.asUint8List(wav.offsetInBytes, wav.lengthInBytes),
    );
    final result = await engine
        .transcribe(loaded, AsrRequest(input: input.path, language: 'en'))
        .done
        .timeout(const Duration(minutes: 2));
    final text =
        result.transcript?.windows
            .expand((w) => w.segments)
            .map((s) => s.text)
            .join(' ')
            .toLowerCase() ??
        '';
    if (!result.succeeded || !text.contains('quick brown fox'))
      throw StateError(
        'Accelerated transcription failed: ${result.error}, $text',
      );
    report['accelerated_recognition'] = 'passed';
    loaded.close();
    engine.dispose();
    final posts = <String>[];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final bytes = await request.fold<List<int>>(
        [],
        (all, bytes) => all..addAll(bytes),
      );
      final data = request.headers.value('content-encoding') == 'gzip'
          ? gzip.decode(bytes)
          : bytes;
      posts.add(utf8.decode(data, allowMalformed: true));
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"status":1,"featureFlags":{}}');
      await request.response.close();
    });
    final host = 'http://127.0.0.1:${server.port}';
    await Posthog().setup(
      PostHogConfig('tvos_test_project')
        ..host = host
        ..preloadFeatureFlags = false
        ..sessionReplay = false
        ..captureApplicationLifecycleEvents = false,
    );
    await Posthog().capture(eventName: 'tvos_native_posthog_smoke');
    await Posthog().flush();
    await SentryFlutter.init((options) {
      options
        ..dsn = 'http://public@127.0.0.1:${server!.port}/1'
        ..autoSessionTrackingInterval = const Duration(seconds: 5);
    },
    // Sentry 10.3 needs this options hook for the tvOS platform adapter.
    // ignore: invalid_use_of_internal_member
    options: tvosSentryOptions());
    await Sentry.captureMessage('tvos_native_sentry_smoke');
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(end) &&
        (!posts.any((s) => s.contains('tvos_native_posthog_smoke')) ||
            !posts.any((s) => s.contains('tvos_native_sentry_smoke')))) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!posts.any((s) => s.contains('tvos_native_posthog_smoke')))
      throw StateError('PostHog event did not reach local collector');
    if (!posts.any((s) => s.contains('tvos_native_sentry_smoke')))
      throw StateError('Sentry event did not reach local collector');
    report['posthog_native_capture'] = 'passed';
    report['sentry_native_capture'] = 'passed';
    await Sentry.close();
    report['status'] = 'passed';
  } catch (e, s) {
    report['status'] = 'failed';
    report['error'] = '$e';
    debugPrint('$e\n$s');
  }
  await server?.close(force: true);
  await File('${dir.path}/tvos-plugins-smoke.json')
      .writeAsString(jsonEncode(report), flush: true);
  debugPrint('TVOS_PLUGINS ${jsonEncode(report)}');
}
