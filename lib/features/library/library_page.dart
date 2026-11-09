import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_manager.dart';
import '../../services/library/library_service.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.sources, this.service});
  final SourceManager sources;
  final LibraryService? service;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  LibraryService? _service;
  String? _library;
  String _search = '';
  String? _sourceFilter;
  String? _typeFilter;
  bool? _watchedFilter;
  String? _error;
  bool _favorites = false;
  bool _scanning = false;
  bool _resolving = false;
  Timer? _scanRefresh;
  int _offset = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = widget.service ?? await LibraryService.open();
      await widget.sources.load();
      if (!mounted) {
        if (widget.service == null) service.close();
        return;
      }
      setState(() {
        _service = service;
        _library = service.libraries.firstOrNull?['id'] as String?;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '媒体库打开失败，请返回后重试');
    }
  }

  @override
  void dispose() {
    _scanRefresh?.cancel();
    // Database closure waits for any active scan.
    if (widget.service == null) _service?.close();
    super.dispose();
  }

  Future<String?> _text(String title, {String initial = ''}) async {
    var value = initial;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initial,
          onChanged: (text) => value = text,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (value.trim().isNotEmpty) {
                Navigator.pop(context, value.trim());
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _create() async {
    final name = await _text('创建媒体库');
    if (name != null && mounted) {
      final type = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('内容类型'),
          children: [
            for (final entry in const {
              'mixed': '混合',
              'movie': '电影',
              'series': '剧集',
              'home': '家庭视频',
              'audio': '音频',
            }.entries)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, entry.key),
                child: Text(entry.value),
              ),
          ],
        ),
      );
      if (type == null || !mounted) return;
      setState(() {
        _library = _service!.create(name, type: type);
        _offset = 0;
      });
    }
  }

  Future<void> _bind() async {
    try {
      await widget.sources.load();
      if (!mounted) return;
      final source = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('选择来源（仅扫描选定范围）'),
          children: [
            for (final source in widget.sources.configs.where((c) => c.enabled))
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, source.id),
                child: Text(source.name),
              ),
            if (widget.sources.configs.where((c) => c.enabled).isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('请先在媒体源中添加并启用来源'),
              ),
          ],
        ),
      );
      if (source == null || !mounted) return;
      final scope = await Navigator.of(context).push<SourceEntry>(
        MaterialPageRoute(
          builder: (_) => _ScopePage(sources: widget.sources, source: source),
        ),
      );
      if (scope == null || !mounted) return;
      final binding = _service!.bind(
        _library!,
        source,
        root: scope.ref.id.isEmpty ? null : scope.ref.id,
        rootEntry: scope,
      );
      await _scan(binding);
    } catch (_) {
      if (mounted) setState(() => _error = '无法添加来源，请检查连接后重试');
    }
  }

  Future<void> _scan(String binding) async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    _scanRefresh = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
    try {
      await _service!.scan(binding, widget.sources);
    } catch (_) {
      if (mounted) setState(() => _error = '扫描失败；已入库的内容保留，可重试');
    } finally {
      _scanRefresh?.cancel();
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<PlayableStream> _resolve(ResourceRef ref) async {
    if (ref.instanceId == '@local') {
      if (!await File(ref.id).exists()) throw StateError('本地文件不可用');
      return PlayableStream(Uri.file(ref.id));
    }
    return widget.sources.resolve(ref);
  }

  String _resourceLabel(dynamic resource) {
    final checkpoint = _service!.checkpoint(resource['id'] as String);
    final progress = checkpoint != null && checkpoint['completed'] == 0
        ? ' · 已看 ${(checkpoint['position'] as int) ~/ 60000} 分钟'
        : checkpoint?['completed'] == 1
        ? ' · 已看完'
        : '';
    if (resource['source'] == '@local') return '本机文件（播放时检查访问权限）$progress';
    final source = widget.sources.configs
        .where((c) => c.id == resource['source'] && c.enabled)
        .firstOrNull;
    if (source == null) return '需要配置或启用来源$progress';
    return '${source.name} · ${_service!.observedMissing(resource['id'] as String) ? '扫描未发现，可能已失联' : '播放时验证可用性'}$progress';
  }

  Future<void> _detail(dynamic media) async {
    final service = _service!;
    var childOffset = 0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, updateDetail) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(media['title'] as String),
                subtitle: const Text('选择资源版本播放；不同版本不自动换算时间轴'),
              ),
              for (final child in service.children(
                media['id'] as String,
                library: _library,
                offset: childOffset,
              ))
                ListTile(
                  leading: const Icon(Icons.video_collection_outlined),
                  title: Text(child['title'] as String),
                  subtitle: Text(
                    '${const {'series': '剧集', 'season': '季', 'episode': '单集'}[child['kind']] ?? '媒体'} · ${child['season'] ?? '-'} / ${child['episode'] ?? '-'}',
                  ),
                  onTap: () {
                    Navigator.pop(sheet);
                    _detail(child);
                  },
                ),
              if (childOffset > 0 ||
                  service
                          .children(
                            media['id'] as String,
                            library: _library,
                            offset: childOffset,
                          )
                          .length ==
                      40)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: childOffset == 0
                          ? null
                          : () => updateDetail(() => childOffset -= 40),
                      child: const Text('上一页'),
                    ),
                    TextButton(
                      onPressed:
                          service
                                  .children(
                                    media['id'] as String,
                                    library: _library,
                                    offset: childOffset,
                                  )
                                  .length <
                              40
                          ? null
                          : () => updateDetail(() => childOffset += 40),
                      child: const Text('下一页'),
                    ),
                  ],
                ),
              for (final resource in service.resources(media['id'] as String))
                ListTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: Text(resource['name'] as String),
                  subtitle: Text(_resourceLabel(resource)),
                  onTap: () async {
                    try {
                      if (_resolving) return;
                      _resolving = true;
                      final stream = await _resolve(
                        ResourceRef(
                          resource['source'] as String,
                          resource['item'] as String,
                        ),
                      );
                      if (!mounted || !sheet.mounted) {
                        await stream.release();
                        return;
                      }
                      Navigator.pop(sheet);
                      Navigator.pop(
                        context,
                        SourceSelection(
                          resource['name'] as String,
                          stream,
                          ref: ResourceRef(
                            resource['source'] as String,
                            resource['item'] as String,
                          ),
                        ),
                      );
                    } catch (_) {
                      if (sheet.mounted) {
                        ScaffoldMessenger.of(sheet).showSnackBar(
                          const SnackBar(content: Text('此版本无法打开，请检查来源或选择其他版本')),
                        );
                      }
                    } finally {
                      _resolving = false;
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('加入其他媒体库'),
                onTap: () async {
                  final library = await showDialog<String>(
                    context: context,
                    builder: (c) => SimpleDialog(
                      title: const Text('选择媒体库'),
                      children: [
                        for (final library in service.libraries)
                          SimpleDialogOption(
                            onPressed: () =>
                                Navigator.pop(c, library['id'] as String),
                            child: Text(library['name'] as String),
                          ),
                      ],
                    ),
                  );
                  if (library != null && mounted) {
                    service.addManual(library, media['id'] as String);
                    setState(() {});
                  }
                  if (sheet.mounted) Navigator.pop(sheet);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('修正标题'),
                onTap: () async {
                  final title = await _text(
                    '修正标题',
                    initial: media['title'] as String,
                  );
                  if (title != null && mounted) {
                    service.rename(media['id'] as String, title);
                    setState(() {});
                  }
                  if (sheet.mounted) Navigator.pop(sheet);
                },
              ),
              if (_library != null)
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline),
                  title: const Text('从当前库移除（保留原文件和媒体记录）'),
                  onTap: () {
                    service.remove(_library!, media['id'] as String);
                    Navigator.pop(sheet);
                    setState(() {});
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    final rows = service == null || _library == null
        ? []
        : service.query(
            _library!,
            search: _search,
            favorites: _favorites,
            source: _sourceFilter,
            contentType: _typeFilter,
            watched: _watchedFilter,
            offset: _offset,
          );
    return PopScope(
      canPop: !_scanning,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('媒体库'),
          actions: [
            if (service != null)
              IconButton(
                onPressed: _scanning ? null : _create,
                icon: const Icon(Icons.add),
                tooltip: '创建媒体库',
              ),
          ],
        ),
        body: service == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Text(_error!),
              )
            : Column(
                children: [
                  Flexible(
                    flex: 2,
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (service.continueWatching().isNotEmpty) ...[
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('继续观看（包括未入库的播放记录）'),
                              ),
                            ),
                            SizedBox(
                              height: 100,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  for (final media
                                      in service.continueWatching())
                                    SizedBox(
                                      width: 240,
                                      child: Card(
                                        child: ListTile(
                                          leading: const Icon(Icons.history),
                                          title: Text(
                                            media['title'] as String,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            '${(media['position'] as int) ~/ 60000} / ${(media['duration'] as int) ~/ 60000} 分钟',
                                          ),
                                          onTap: _scanning
                                              ? null
                                              : () => _detail(media),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          if (service.libraries.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: _library,
                                      items: [
                                        for (final library in service.libraries)
                                          DropdownMenuItem(
                                            value: library['id'] as String,
                                            child: Text(
                                              library['name'] as String,
                                            ),
                                          ),
                                      ],
                                      onChanged: _scanning
                                          ? null
                                          : (value) => setState(() {
                                              _library = value;
                                              _offset = 0;
                                            }),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _scanning
                                        ? null
                                        : () async {
                                            final name = await _text(
                                              '重命名媒体库',
                                              initial:
                                                  service.libraries.firstWhere(
                                                        (l) =>
                                                            l['id'] == _library,
                                                      )['name']
                                                      as String,
                                            );
                                            if (name != null && mounted) {
                                              setState(
                                                () => service.renameLibrary(
                                                  _library!,
                                                  name,
                                                ),
                                              );
                                            }
                                          },
                                    icon: const Icon(
                                      Icons.drive_file_rename_outline,
                                    ),
                                    tooltip: '重命名媒体库',
                                  ),
                                  IconButton(
                                    onPressed: _scanning ? null : _bind,
                                    icon: const Icon(
                                      Icons.create_new_folder_outlined,
                                    ),
                                    tooltip: '添加来源范围',
                                  ),
                                  IconButton(
                                    onPressed: _scanning
                                        ? null
                                        : () async {
                                            final confirmed =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (c) => AlertDialog(
                                                    title: const Text(
                                                      '删除当前媒体库？',
                                                    ),
                                                    content: const Text(
                                                      '仅删除库和成员关系，保留原文件、媒体和收藏。',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              c,
                                                              false,
                                                            ),
                                                        child: const Text('取消'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              c,
                                                              true,
                                                            ),
                                                        child: const Text('删除'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                            if (confirmed == true && mounted) {
                                              setState(() {
                                                service.delete(_library!);
                                                _library =
                                                    service
                                                            .libraries
                                                            .firstOrNull?['id']
                                                        as String?;
                                                _offset = 0;
                                              });
                                            }
                                          },
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: '删除库',
                                  ),
                                ],
                              ),
                            ),
                          if (_library != null) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: '搜索库内媒体',
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (value) => setState(() {
                                  _search = value;
                                  _offset = 0;
                                }),
                              ),
                            ),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                DropdownButton<String>(
                                  value: _sourceFilter ?? '*',
                                  items: [
                                    const DropdownMenuItem(
                                      value: '*',
                                      child: Text('全部来源'),
                                    ),
                                    for (final source in widget.sources.configs)
                                      DropdownMenuItem(
                                        value: source.id,
                                        child: Text(source.name),
                                      ),
                                  ],
                                  onChanged: (value) => setState(() {
                                    _sourceFilter = value == '*' ? null : value;
                                    _offset = 0;
                                  }),
                                ),
                                DropdownButton<String>(
                                  value: _typeFilter ?? '*',
                                  items: [
                                    for (final entry in const {
                                      '*': '全部类型',
                                      'movie': '电影',
                                      'series': '剧集',
                                      'season': '季',
                                      'episode': '单集',
                                      'video': '普通视频',
                                      'audio': '音频',
                                    }.entries)
                                      DropdownMenuItem(
                                        value: entry.key,
                                        child: Text(entry.value),
                                      ),
                                  ],
                                  onChanged: (value) => setState(() {
                                    _typeFilter = value == '*' ? null : value;
                                    _offset = 0;
                                  }),
                                ),
                                DropdownButton<String>(
                                  value: _watchedFilter == null
                                      ? '*'
                                      : _watchedFilter!
                                      ? 'yes'
                                      : 'no',
                                  items: const [
                                    DropdownMenuItem(
                                      value: '*',
                                      child: Text('全部观看状态'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'yes',
                                      child: Text('已看完'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'no',
                                      child: Text('未看完'),
                                    ),
                                  ],
                                  onChanged: (value) => setState(() {
                                    _watchedFilter = value == '*'
                                        ? null
                                        : value == 'yes';
                                    _offset = 0;
                                  }),
                                ),
                                FilterChip(
                                  label: const Text('收藏'),
                                  selected: _favorites,
                                  onSelected: (value) => setState(() {
                                    _favorites = value;
                                    _offset = 0;
                                  }),
                                ),
                                TextButton(
                                  onPressed: _scanning
                                      ? null
                                      : () {
                                          service.clearIgnored(_library!);
                                          setState(() {});
                                        },
                                  child: const Text('取消移除忽略（下次扫描恢复）'),
                                ),
                              ],
                            ),
                            for (final binding in service.bindings(_library!))
                              ListTile(
                                dense: true,
                                title: Text(
                                  '${binding['status']} · ${widget.sources.configs.where((c) => c.id == binding['source']).firstOrNull?.name ?? '需要配置来源'}',
                                ),
                                subtitle: binding['error'] == null
                                    ? null
                                    : Text(binding['error'] as String),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: _scanning
                                          ? null
                                          : () =>
                                                _scan(binding['id'] as String),
                                      icon: const Icon(Icons.refresh),
                                      tooltip: '重新扫描',
                                    ),
                                    IconButton(
                                      onPressed: _scanning
                                          ? null
                                          : () async {
                                              final count = service
                                                  .bindingImpact(
                                                    binding['id'] as String,
                                                  );
                                              final confirmed =
                                                  await showDialog<bool>(
                                                    context: context,
                                                    builder: (c) => AlertDialog(
                                                      title: const Text(
                                                        '移除扫描绑定？',
                                                      ),
                                                      content: Text(
                                                        '此绑定关联 $count 项内容。仅移除失去全部来源证据的自动成员，保留手动成员、共享媒体和原文件。',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                c,
                                                                false,
                                                              ),
                                                          child: const Text(
                                                            '取消',
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                c,
                                                                true,
                                                              ),
                                                          child: const Text(
                                                            '移除',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                              if (confirmed == true &&
                                                  mounted) {
                                                setState(
                                                  () => service.removeBinding(
                                                    binding['id'] as String,
                                                  ),
                                                );
                                              }
                                            },
                                      icon: const Icon(Icons.link_off),
                                      tooltip: '移除绑定',
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          if (_scanning) const LinearProgressIndicator(),
                          if (_error != null)
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: _library == null
                        ? Center(
                            child: FilledButton(
                              onPressed: _create,
                              child: const Text('创建第一个媒体库'),
                            ),
                          )
                        : rows.isEmpty
                        ? Center(
                            child: Text(
                              _search.isNotEmpty ||
                                      _favorites ||
                                      _sourceFilter != null ||
                                      _typeFilter != null ||
                                      _watchedFilter != null
                                  ? '没有符合条件的媒体'
                                  : '暂无内容，请添加来源范围或刷新扫描',
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 220,
                                  mainAxisExtent: 220,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            itemCount: rows.length,
                            itemBuilder: (_, index) {
                              final media = rows[index];
                              return Card(
                                child: InkWell(
                                  onTap: _scanning
                                      ? null
                                      : () => _detail(media),
                                  child: Column(
                                    children: [
                                      const Expanded(
                                        child: Center(
                                          child: Icon(
                                            Icons.movie_outlined,
                                            size: 64,
                                          ),
                                        ),
                                      ),
                                      ListTile(
                                        title: Text(
                                          media['title'] as String,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: IconButton(
                                          icon: Icon(
                                            media['favorite'] == 1
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                          ),
                                          onPressed: () => setState(
                                            () => service.favorite(
                                              media['id'] as String,
                                              media['favorite'] != 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (_library != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _offset == 0
                              ? null
                              : () => setState(() => _offset -= 40),
                          child: const Text('上一页'),
                        ),
                        Text('${_offset ~/ 40 + 1}'),
                        TextButton(
                          onPressed: rows.length < 40
                              ? null
                              : () => setState(() => _offset += 40),
                          child: const Text('下一页'),
                        ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}

class _ScopePage extends StatefulWidget {
  const _ScopePage({required this.sources, required this.source});
  final SourceManager sources;
  final String source;
  @override
  State<_ScopePage> createState() => _ScopePageState();
}

class _ScopePageState extends State<_ScopePage> {
  final List<SourceEntry> _path = [];
  List<SourceEntry> _folders = [];
  int? _next;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await widget.sources.browse(
        widget.source,
        BrowseRequest(node: _path.lastOrNull?.ref, offset: more ? _next! : 0),
      );
      if (mounted) {
        setState(() {
          _folders = [
            ...(more ? _folders : <SourceEntry>[]),
            ...page.entries.where((e) => e.isFolder),
          ];
          _next = page.nextOffset;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '无法浏览，请检查来源后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_path.lastOrNull?.name ?? '选择扫描范围')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('扫描会索引此范围内的媒体，不下载视频。请选择已授权的目录或服务端库。'),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          TextButton(onPressed: () => _load(), child: Text(_error!)),
        if (_path.isNotEmpty)
          ListTile(
            title: const Text('上一级'),
            onTap: _busy
                ? null
                : () {
                    _path.removeLast();
                    _load();
                  },
          ),
        Expanded(
          child: ListView(
            children: [
              for (final folder in _folders)
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(folder.name),
                  onTap: _busy
                      ? null
                      : () {
                          _path.add(folder);
                          _load();
                        },
                ),
              if (_next != null)
                TextButton(
                  onPressed: _busy ? null : () => _load(more: true),
                  child: const Text('加载更多'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _busy || _error != null
                ? null
                : () => Navigator.pop(
                    context,
                    _path.lastOrNull ??
                        SourceEntry(
                          ResourceRef(widget.source, ''),
                          '根目录',
                          isFolder: true,
                        ),
                  ),
            child: const Text('确认扫描此范围'),
          ),
        ),
      ],
    ),
  );
}
