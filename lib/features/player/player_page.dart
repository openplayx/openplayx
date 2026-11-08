import 'dart:async';

import 'package:flutter/material.dart';
import 'package:openplayx_playback/playback.dart';

import '../../data/files/local_media_picker.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, this.backend, this.pickMedia = pickLocalMedia});
  final PlayerBackend? backend;
  final Future<LocalMedia?> Function() pickMedia;
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  late final PlayerBackend _backend;
  String? _name;
  String? _error;
  bool _busy = false;
  bool _background = false;
  double? _drag;

  @override
  void initState() {
    super.initState();
    _backend = widget.backend ?? LibVlcBackend();
    _backend.addListener(_onPlayback);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onPlayback() {
    if (_background && _backend.value.status == PlaybackStatus.playing) {
      unawaited(_command(_backend.pause));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background =
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
    if (_background && _name != null) unawaited(_command(_backend.pause));
  }

  Future<void> _command(Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stack) {
      debugPrint('Playback command failed: $error\n$stack');
      if (mounted) setState(() => _error = '播放操作失败，请重新打开媒体文件。');
    }
  }

  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      final media = await widget.pickMedia();
      if (media == null || !mounted) return;
      setState(() {
        _name = media.name;
        _error = null;
        _drag = null;
      });
      await _command(() => _backend.open(media.uri));
      if (_background && mounted) await _command(_backend.pause);
    } catch (error, stack) {
      debugPrint('File selection failed: $error\n$stack');
      if (mounted) setState(() => _error = '无法打开文件，请重新选择。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backend.removeListener(_onPlayback);
    _backend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('OpenPlayX'),
      actions: [
        TextButton.icon(
          onPressed: _busy ? null : _open,
          icon: const Icon(Icons.folder_open),
          label: const Text('打开文件'),
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlayerVideoView(backend: _backend),
                  if (_name == null)
                    const IgnorePointer(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_outline,
                              size: 64,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 16),
                            Text('打开一个视频，开始播放', style: TextStyle(fontSize: 20)),
                            SizedBox(height: 8),
                            Text(
                              '本地播放 · libVLC',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          ValueListenableBuilder<PlayerSnapshot>(
            valueListenable: _backend,
            builder: (context, value, _) {
              final loading = _busy || value.status == PlaybackStatus.opening;
              final enabled =
                  _name != null &&
                  !loading &&
                  value.status != PlaybackStatus.error &&
                  _error == null;
              final duration = value.duration.inMilliseconds.toDouble();
              final seekable = enabled && value.canSeek && duration > 0;
              final position =
                  (_drag ?? value.position.inMilliseconds.toDouble()).clamp(
                    0.0,
                    duration > 0 ? duration : 1.0,
                  );
              final status = switch (value.status) {
                PlaybackStatus.idle => '等待打开文件',
                PlaybackStatus.opening => '正在加载…',
                PlaybackStatus.playing => '正在播放',
                PlaybackStatus.paused => '已暂停',
                PlaybackStatus.ended => '播放结束',
                PlaybackStatus.error => '播放失败，请检查文件或重新选择。',
              };
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _name ?? '未选择媒体',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _error ?? status,
                            style: TextStyle(
                              color:
                                  _error != null ||
                                      value.status == PlaybackStatus.error
                                  ? Theme.of(context).colorScheme.error
                                  : Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (loading) const LinearProgressIndicator(),
                    Row(
                      children: [
                        Text(
                          formatTime(Duration(milliseconds: position.round())),
                        ),
                        Expanded(
                          child: Slider(
                            value: position,
                            max: duration > 0 ? duration : 1,
                            onChanged: seekable
                                ? (v) => setState(() => _drag = v)
                                : null,
                            onChangeEnd: seekable
                                ? (v) async {
                                    await _command(
                                      () => _backend.seek(
                                        Duration(milliseconds: v.round()),
                                      ),
                                    );
                                    if (mounted) setState(() => _drag = null);
                                  }
                                : null,
                          ),
                        ),
                        Text(
                          duration > 0 ? formatTime(value.duration) : '--:--',
                        ),
                      ],
                    ),
                    IconButton.filled(
                      tooltip: value.status == PlaybackStatus.playing
                          ? '暂停'
                          : '播放',
                      iconSize: 32,
                      onPressed: enabled
                          ? () => _command(
                              value.status == PlaybackStatus.playing
                                  ? _backend.pause
                                  : _backend.play,
                            )
                          : null,
                      icon: Icon(
                        value.status == PlaybackStatus.playing
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

String formatTime(Duration time) {
  final seconds = time.inSeconds.clamp(0, 999999999);
  final minutes = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return seconds >= 3600
      ? '${seconds ~/ 3600}:$minutes:$rest'
      : '$minutes:$rest';
}
