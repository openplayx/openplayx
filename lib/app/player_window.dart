import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openplayx_playback/playback.dart';

import '../core/plugins/source_capability.dart';
import '../data/sources/source_manager.dart';
import '../features/player/player_page.dart';
import 'app.dart';
import 'theme/app_theme_controller.dart';

/// First dart-entrypoint argument desktop_multi_window gives to a sub-window.
const playerWindowEntryArgument = 'multi_window';

/// Native bridge registered by the macOS runner for every sub-window.
const _nativeChannel = MethodChannel('openplayx/player_window');

/// Each desktop runner registers the plugins and the close bridge for these.
bool get supportsPlayerWindow =>
    !kIsWeb &&
    (Platform.isMacOS || Platform.isWindows || Platform.isLinux) &&
    LibVlcBackend.isSupported;

/// Entry point for engines that desktop_multi_window created for playback.
Future<bool> runPlayerWindowIfRequested(List<String> args) async {
  if (args.isEmpty || args.first != playerWindowEntryArgument) return false;
  WidgetsFlutterBinding.ensureInitialized();
  final request = jsonDecode(args.length > 2 ? args[2] : '{}');
  final appearance = AppThemeController();
  await appearance.load();
  runApp(
    OpenPlayXApp(
      appearance: appearance,
      home: PlayerWindowPage(request: request as Map<String, dynamic>),
    ),
  );
  return true;
}

/// Opens playback requests from the main window in their own OS windows.
class PlayerWindows {
  /// Returns false when the window could not be created, so the caller can fall
  /// back to the embedded player. [selection]'s stream stays owned by the main
  /// window and is released once the player window closes.
  Future<bool> open(SourceSelection selection) async {
    try {
      final controller = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: jsonEncode({
            'uri': selection.stream.uri.toString(),
            'name': selection.name,
            if (selection.ref != null)
              'ref': {
                'instance': selection.ref!.instanceId,
                'id': selection.ref!.id,
              },
          }),
        ),
      );
      unawaited(_releaseWhenClosed(controller.windowId, selection.stream));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _releaseWhenClosed(String id, PlayableStream stream) async {
    try {
      // The window exists as soon as create() returns; wait until it is gone.
      var seen = false;
      await for (final _ in onWindowsChanged) {
        final open = (await WindowController.getAll()).any(
          (w) => w.windowId == id,
        );
        if (open) {
          seen = true;
        } else if (seen) {
          break;
        }
      }
    } finally {
      await stream.release();
    }
  }
}

/// Root of a player window: one [PlayerPage] playing the requested stream.
class PlayerWindowPage extends StatefulWidget {
  const PlayerWindowPage({super.key, required this.request});
  final Map<String, dynamic> request;
  @override
  State<PlayerWindowPage> createState() => _PlayerWindowPageState();
}

class _PlayerWindowPageState extends State<PlayerWindowPage> {
  final _player = GlobalKey<PlayerPageState>();
  final _backend = LibVlcBackend();
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    // The runner holds back a native close request (title-bar button, Alt+F4)
    // and asks us to stop playback first; `close` then really closes it.
    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'windowClosing') await _close();
      return null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final request = widget.request;
    final ref = request['ref'] as Map<String, dynamic>?;
    final selection = SourceSelection(
      request['name'] as String? ?? '',
      PlayableStream(Uri.parse(request['uri'] as String)),
      ref: ref == null
          ? null
          : ResourceRef(ref['instance'] as String, ref['id'] as String),
    );
    final window = await WindowController.fromCurrentEngine();
    await window.show();
    await _player.currentState?.playSelection(selection);
  }

  Future<void> _stop() async {
    if (_closing) return;
    _closing = true;
    await _player.currentState?.stopPlayback();
  }

  Future<void> _close() async {
    await _stop();
    await _nativeChannel.invokeMethod<void>('close');
  }

  @override
  void dispose() {
    _nativeChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlayerPage(
    key: _player,
    backend: _backend,
    showBack: false,
    onExit: () => unawaited(_close()),
  );
}
