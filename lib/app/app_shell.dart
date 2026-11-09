import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:openplayx_playback/playback.dart';

import '../core/plugins/source_capability.dart';
import '../data/sources/source_manager.dart';
import '../features/library/library_page.dart';
import '../features/player/player_page.dart';
import '../features/sources/source_defaults_page.dart';
import '../features/sources/source_page.dart';
import '../services/library/library_service.dart';

enum AppDestination {
  home('首页', Icons.home_outlined),
  library('媒体库', Icons.video_library_outlined),
  sources('来源', Icons.folder_outlined),
  settings('设置', Icons.settings_outlined);

  const AppDestination(this.label, this.icon);
  final String label;
  final IconData icon;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.sources, this.library, this.backend});
  final SourceManager? sources;
  final LibraryService? library;
  final PlayerBackend? backend;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final _sources = widget.sources ?? SourceManager();
  final _revision = ValueNotifier(0);
  final _player = GlobalKey<PlayerPageState>();
  final _branches = List.generate(4, (_) => GlobalKey<NavigatorState>());
  LibraryService? _library;
  PlayerBackend? _backend;
  int _destination = 0;
  bool _showPlayer = false;
  bool _opening = false;
  bool _exitingPlayer = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final library = widget.library ?? await LibraryService.open();
      if (!mounted) {
        if (widget.library == null) library.close();
        return;
      }
      setState(() {
        _library = library;
        _backend =
            widget.backend ??
            (LibVlcBackend.isSupported ? LibVlcBackend() : null);
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '无法打开媒体库，请重试');
    }
  }

  @override
  void dispose() {
    if (widget.library == null) _library?.close();
    if (widget.sources == null) unawaited(_sources.dispose());
    super.dispose();
  }

  Future<void> _exitPlayer() async {
    if (_exitingPlayer) return;
    _exitingPlayer = true;
    try {
      if (await _player.currentState!.stopPlayback() && mounted) {
        setState(() => _showPlayer = false);
        _revision.value++;
      }
    } finally {
      _exitingPlayer = false;
    }
  }

  Future<void> _play(SourceSelection selection) async {
    if (_opening || _exitingPlayer || _backend == null) {
      await selection.stream.release();
      if (mounted && _backend == null) _message('当前平台暂不支持播放');
      return;
    }
    _opening = true;
    setState(() {
      _showPlayer = true;
    });
    try {
      await _player.currentState!.playSelection(selection);
    } finally {
      _opening = false;
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _playHistory(dynamic media) async {
    if (_opening) return;
    // Continue the exact recorded resource, rather than selecting another version.
    final resources = _library!
        .resources(media['id'] as String)
        .where((r) => r['id'] == media['resource_id']);
    if (resources.isEmpty) {
      _message('此播放记录的资源不可用');
      return;
    }
    final resource = resources.first;
    final ref = ResourceRef(
      resource['source'] as String,
      resource['item'] as String,
    );
    _opening = true;
    try {
      PlayableStream stream;
      if (ref.instanceId == '@local') {
        if (!await File(ref.id).exists()) throw StateError('文件不可用');
        stream = PlayableStream(Uri.file(ref.id));
      } else {
        await _sources.load();
        stream = await _sources.resolve(ref);
      }
      if (!mounted) {
        await stream.release();
        return;
      }
      _opening = false;
      await _play(
        SourceSelection(resource['name'] as String, stream, ref: ref),
      );
    } catch (_) {
      if (mounted) _message('无法打开此记录，请检查文件或来源连接');
    } finally {
      _opening = false;
    }
  }

  Widget _home() => ValueListenableBuilder<int>(
    valueListenable: _revision,
    builder: (_, _, _) => _homeContent(),
  );

  Widget _homeContent() => Scaffold(
    appBar: AppBar(title: const Text('首页')),
    body: ListView(
      key: const PageStorageKey('home'),
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '欢迎使用 OpenPlayX',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('从上次停下的地方继续，或浏览你的媒体库。'),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _backend == null
                ? null
                : () async {
                    setState(() => _showPlayer = true);
                    await _player.currentState?.openFile();
                  },
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('打开文件'),
          ),
        ),
        const SizedBox(height: 28),
        _history(
          '继续观看',
          _library!.continueWatching(),
          empty: '还没有未看完的视频，播放后会在这里显示。',
        ),
        const SizedBox(height: 28),
        _history(
          '最近播放',
          _library!.recentlyPlayed(),
          empty: '还没有播放记录。去媒体库或来源中选择视频。',
        ),
      ],
    ),
  );

  Widget _history(
    String title,
    List<dynamic> rows, {
    required String empty,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (rows.isEmpty)
        Card(
          child: Padding(padding: const EdgeInsets.all(24), child: Text(empty)),
        )
      else
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final row = rows[index];
              final position = row['position'] as int;
              final duration = row['duration'] as int;
              return SizedBox(
                width: 256,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _playHistory(row),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.play_circle_outline),
                          const SizedBox(height: 8),
                          Text(
                            row['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Text(
                            row['completed'] == 1
                                ? '已看完 · 重新播放'
                                : '已看 ${position ~/ 60000} / ${duration ~/ 60000} 分钟',
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: duration > 0
                                ? (position / duration).clamp(0, 1)
                                : 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
    ],
  );

  Widget _settings() => Scaffold(
    appBar: AppBar(title: const Text('设置')),
    body: ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.tune),
          title: const Text('来源默认配置'),
          subtitle: const Text('管理浏览、搜索与扫描使用的默认来源'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _branches[3].currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => SourceDefaultsPage(manager: _sources),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('关于 OpenPlayX'),
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'OpenPlayX',
            applicationVersion: '1.0.0',
          ),
        ),
      ],
    ),
  );

  Widget _branch(int index) => Navigator(
    key: _branches[index],
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      builder: (_) => switch (index) {
        0 => _home(),
        1 => LibraryPage(sources: _sources, service: _library, onPlay: _play),
        2 => SourcePage(manager: _sources, onPlay: _play),
        _ => _settings(),
      },
    ),
  );

  void _select(int index) {
    setState(() => _destination = index);
    if (index == 0) _revision.value++;
  }

  @override
  Widget build(BuildContext context) {
    if (_library == null) {
      return Scaffold(
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    TextButton(onPressed: _load, child: const Text('重试')),
                  ],
                ),
        ),
      );
    }
    return PopScope(
      canPop: !_showPlayer && _destination == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_showPlayer) {
          await _exitPlayer();
        } else if (!await _branches[_destination].currentState!.maybePop()) {
          if (mounted) _select(0);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 840;
          return Scaffold(
            body: Stack(
              children: [
                Offstage(
                  offstage: _showPlayer,
                  child: Row(
                    children: [
                      SizedBox(
                        width: wide ? 208 : 0,
                        child: wide
                            ? NavigationRail(
                                extended: true,
                                minExtendedWidth: 208,
                                leading: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Text(
                                    'OpenPlayX',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                destinations: [
                                  for (final d in AppDestination.values)
                                    NavigationRailDestination(
                                      icon: Icon(d.icon),
                                      label: Text(d.label),
                                    ),
                                ],
                                selectedIndex: _destination,
                                onDestinationSelected: _select,
                              )
                            : null,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: IndexedStack(
                                index: _destination,
                                children: [
                                  for (var i = 0; i < 4; i++) _branch(i),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_backend != null)
                  Offstage(
                    offstage: !_showPlayer,
                    child: ExcludeFocus(
                      excluding: !_showPlayer,
                      child: PlayerPage(
                        key: _player,
                        backend: _backend,
                        sourceManager: _sources,
                        libraryService: _library,
                        onExit: _exitPlayer,
                      ),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: wide || _showPlayer
                ? null
                : NavigationBar(
                    selectedIndex: _destination,
                    onDestinationSelected: _select,
                    destinations: [
                      for (final d in AppDestination.values)
                        NavigationDestination(
                          icon: Icon(d.icon),
                          label: d.label,
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
