import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/files/local_media_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('openplayx/local_media');

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'Android opens media using metadata without transferring file bytes',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'pickMedia');
            return {
              'path': '/cache/large video.cache',
              'name': 'large video.mp4',
            };
          });
      final media = await pickLocalMedia();
      expect(media!.uri, Uri.file('/cache/large video.cache'));
      expect(media.name, 'large video.mp4');
    },
  );

  test('Android cancellation returns no selection', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    expect(await pickLocalMedia(), isNull);
  });

  test('Android copy errors propagate to the player', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'media_open_failed');
        });
    await expectLater(pickLocalMedia(), throwsA(isA<PlatformException>()));
  });
}
