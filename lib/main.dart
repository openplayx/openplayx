import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:openplayx_playback/playback.dart';

import 'features/player/player_page.dart';

void main() => runApp(const OpenPlayXApp());

class OpenPlayXApp extends StatelessWidget {
  const OpenPlayXApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OpenPlayX',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF67D9BD),
    ),
    home: LibVlcBackend.isSupported
        ? const PlayerPage()
        : Scaffold(
            body: Center(
              child: Text(
                kIsWeb
                    ? '暂不支持 Web 播放。\n请使用桌面端或移动端应用。'
                    : '请在 Android、iOS、macOS、Windows 或 Linux 上体验播放。',
                textAlign: TextAlign.center,
              ),
            ),
          ),
  );
}
