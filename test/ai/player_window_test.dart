import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/player_window.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_manager.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('mixin.one/desktop_multi_window');
  const ipc = MethodChannel('mixin.one/desktop_multi_window/channels');

  test('desktop AI waits for the child session, routes subtitle commands, and releases on close', () async {
    var released = false;
    var snapshots = 0;
    Map? command;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(native, (
      call,
    ) async {
      if (call.method == 'createWindow') return 'child';
      if (call.method == 'getAllWindows') return <Map>[];
      throw MissingPluginException();
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(ipc, (call) async {
      final payload = call.arguments as Map;
      expect(payload['channel'], 'mixin.one/window_controller/child');
      if (payload['method'] == 'assistant_snapshot') {
        if (snapshots++ == 0) {
          throw PlatformException(code: 'CHANNEL_NOT_FOUND');
        }
        return {'status': 'playing', 'session_id': 'real-child-session'};
      }
      command = payload;
      final args = payload['arguments'] as Map;
      if ((args['arguments'] as Map)['session_id'] != 'real-child-session') {
        throw PlatformException(code: 'staleSession');
      }
      return {
        'status': 'playing',
        'session_id': 'real-child-session',
        'subtitle': {'kind': 'recognized', 'binding_id': 'saved-subtitle'},
      };
    });
    final windows = PlayerWindows();
    try {
      expect(
        await windows.open(
          SourceSelection(
            'clip',
            PlayableStream(
              Uri.parse('http://127.0.0.1/clip'),
              release: () async => released = true,
            ),
          ),
        ),
        true,
      );
      expect(await windows.snapshot(waitForSession: true), {
        'status': 'playing',
        'session_id': 'real-child-session',
      });
      expect(released, false);
      final result = await windows.control('set_subtitle', {
        'session_id': 'real-child-session',
        'binding_id': 'saved-subtitle',
      });
      expect((command!['arguments'] as Map)['command'], 'set_subtitle');
      expect((result['subtitle'] as Map)['binding_id'], 'saved-subtitle');
      await expectLater(
        windows.control('pause', {'session_id': 'old-session'}),
        throwsA(
          isA<StateError>().having((e) => e.message, 'code', 'staleSession'),
        ),
      );
      await binding.defaultBinaryMessenger.handlePlatformMessage(
        native.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWindowsChanged'),
        ),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(released, true);
      expect(windows.hasActive, false);
      expect(windows.lastSnapshot, isNull);
    } finally {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(native, null);
      binding.defaultBinaryMessenger.setMockMethodCallHandler(ipc, null);
    }
  });
}
