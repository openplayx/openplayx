// Opt-in real server + package-media playback test (ALL-328).
// flutter test integration_test/live/jellyfin_live_test.dart \
//   --dart-define=OPX_JELLYFIN_SESSION=/tmp/session.json \
//   --dart-define=OPX_JELLYFIN_REPORT=/absolute/report
// Session JSON: address,userId,token. The isolated server needs /test-media/
// Remux/Remux.mp4 (H264/AAC) and Transcode/Transcode.webm (AV1/Opus), 8 s,
// 320x240, 25 fps, 1 kHz tone. Credentials never enter sample/report files.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/sources/media_server_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';

void main() {
  const sessionPath = String.fromEnvironment('OPX_JELLYFIN_SESSION');
  const reportPath = String.fromEnvironment('OPX_JELLYFIN_REPORT');
  test(
    'real Jellyfin DirectPlay/Remux/Transcode play through package-media',
    () async {
      final session = jsonDecode(await File(sessionPath).readAsString());
      final config = SourceConfig(
        id: 'advanced-live',
        kind: SourceKind.jellyfin,
        name: 'Isolated test',
        address: session['address'] as String,
        userId: session['userId'] as String,
      );
      final http = SourceHttp(config, session['token'] as String);
      final plugin = JellyfinPlugin(config, http);
      addTearDown(plugin.dispose);
      final items =
          (await http.json('Users/${config.userId}/Items', {
                'Recursive': 'true',
                'MediaTypes': 'Video',
                'Fields': 'MediaSources',
              }))['Items']
              as List;
      final handles = <PlayableStream>[];
      final samples = <Map<String, dynamic>>[];
      final dir = Directory(reportPath);
      await dir.create(recursive: true);
      for (final kind in ['Remux', 'Transcode']) {
        final item = items.firstWhere(
          (i) => (i['MediaSources'] as List? ?? []).any(
            (s) => (s['Path'] as String? ?? '').contains('/test-media/$kind/'),
          ),
        );
        final source = (item['MediaSources'] as List).firstWhere(
          (s) => (s['Path'] as String? ?? '').contains('/test-media/$kind/'),
        );
        final direct = await plugin.resolve(
          ResolveRequest(
            ResourceRef(config.id, 'version:${item['Id']}:${source['Id']}'),
          ),
          CallContext.forInstance(config.id),
        );
        expect(direct.playbackMethod, 'DirectPlay');
        handles.add(direct);
        final fallback = (await direct.retry())!;
        expect(fallback.playbackMethod, kind);
        handles.add(fallback);
        for (final stream in [direct, fallback]) {
          samples.add({
            'id':
                'jellyfin-${kind.toLowerCase()}-${stream.playbackMethod!.toLowerCase()}',
            'linear': ['ALL-328'],
            'ext': stream == direct ? source['Container'] : 'ts',
            'path': stream.uri.toString(),
            'status': 'ok',
            'note': stream.playbackMethod,
            'probe': {
              'width': 320,
              'height': 240,
              'sar': '1:1',
              'video_codec': stream == direct && kind == 'Transcode'
                  ? 'av1'
                  : 'h264',
              'audio_codec': stream == direct && kind == 'Transcode'
                  ? 'opus'
                  : 'aac',
            },
            'expect': {
              'video': true,
              'audio': true,
              'seek': stream == direct,
              'duration_ms': stream == direct ? 8000 : null,
              'frame': null,
              'tone_hz': 1000,
            },
          });
        }
      }
      final input = File('${dir.path}/samples-01.json');
      await input.writeAsString(jsonEncode({'samples': samples}));
      await File('${dir.path}/samples.json')
          .writeAsString(jsonEncode({'samples': samples}));
      final package = Directory('../package-media/example').absolute;
      try {
        final result = await Process.run(
          Platform.environment['FLUTTER_BIN'] ?? 'flutter',
          [
            'test',
            'integration_test/formats_test.dart',
            '-d',
            'macos',
            '--dart-define=OPX_SAMPLES=${input.absolute.path}',
            '--dart-define=OPX_REPORT=${dir.absolute.path}',
            '--dart-define=OPX_ENGINE=auto',
          ],
          workingDirectory: package.path,
        );
        await File('${dir.path}/flutter.log')
            .writeAsString('${result.stdout}\n${result.stderr}');
        expect(
          result.exitCode,
          0,
          reason: 'package-media playback failed; see ${dir.path}/flutter.log',
        );
      } finally {
        for (final h in handles) {
          await h.release();
          expect(await h.retry(), isNull);
        }
        // Released loopback URLs must no longer serve authenticated content.
        final client = HttpClient();
        addTearDown(() => client.close(force: true));
        await expectLater(
          () async => (await client.getUrl(handles.first.uri)).close(),
          throwsA(isA<SocketException>()),
        );
      }
    },
    skip: sessionPath.isEmpty || reportPath.isEmpty,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
