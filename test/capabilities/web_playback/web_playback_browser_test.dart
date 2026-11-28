import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/web_playback/web_playback_service.dart';

import 'web_playback_service_test.dart' show TestCatalog;

void main() {
  test(
    'browser pairs plays seeks resumes and disconnects from the actual service',
    () async {
      final catalog = TestCatalog(
        File('test/fixtures/test_video.mp4').absolute,
      );
      final service = WebPlaybackService(catalog);
      await service.setSharedScopes({'movies'});
      final interfaces = await WebPlaybackService.interfaces();
      await service.start(
        interfaces.firstOrNull ?? InternetAddress.loopbackIPv4,
        port: 0,
      );
      addTearDown(() async {
        await service.shutdown();
        service.dispose();
      });
      final prepare = await Process.run('python3', [
        'tool/build_tizen.py',
        '--prepare-only',
      ]);
      expect(
        prepare.exitCode,
        0,
        reason: '${prepare.stdout}\n${prepare.stderr}',
      );
      final child = await Process.start('node', [
        'tool/web_playback_smoke.mjs',
      ]);
      addTearDown(() => child.kill());
      child.stdin.write(
        jsonEncode({'address': service.address, 'code': service.pairingCode}),
      );
      await child.stdin.close();
      final output = child.stdout.transform(utf8.decoder).join();
      final errors = child.stderr.transform(utf8.decoder).join();
      final exit = await child.exitCode.timeout(const Duration(seconds: 60));
      expect(exit, 0, reason: '${await output}\n${await errors}');
      expect(catalog.savedPosition, greaterThan(6000));
      expect(service.sessions, isEmpty);
    },
    skip: !Platform.environment.containsKey('OPX_PLAYWRIGHT_MODULE'),
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
