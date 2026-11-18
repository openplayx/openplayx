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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/file_selector'),
          null,
        );
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

  for (final path in ['/cache/sub title.srt', 'content://subtitles/selected']) {
    test('subtitle picker accepts iOS types and returns $path', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/file_selector'),
            (call) async {
              expect(call.method, 'openFile');
              final args = call.arguments as Map;
              final groups = args['acceptedTypeGroups'] as List;
              final subtitles = groups.first as Map;
              // iOS validates each group in order; an extension-only group
              // throws even if a later group allows all files.
              expect(subtitles['uniformTypeIdentifiers'], ['public.data']);
              expect(
                subtitles['extensions'],
                containsAll(['srt', 'ass', 'vtt']),
              );
              return [path];
            },
          );
      expect(
        await pickSubtitleFile(),
        path.startsWith('content://') ? Uri.parse(path) : Uri.file(path),
      );
    });
  }

  test('subtitle picker cancellation returns no selection', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/file_selector'),
          (_) async => null,
        );
    expect(await pickSubtitleFile(), isNull);
  });
}
