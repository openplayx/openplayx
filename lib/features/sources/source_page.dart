import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_config.dart';
import '../../data/sources/source_manager.dart';
import 'source_instance_form.dart';
import 'source_defaults_page.dart';

class SourcePage extends StatefulWidget {
  const SourcePage({super.key, required this.manager});
  final SourceManager manager;
  @override
  State<SourcePage> createState() => _SourcePageState();
}

class _SourcePageState extends State<SourcePage> {
  SourceConfig? _source;
  final _nodes = <SourceEntry>[];
  final _entries = <SourceEntry>[];
  int? _next;
  String? _error;
  bool _busy = true;
  StreamIterator<SourceEntry>? _scanIterator;
  @override
  void dispose() {
    unawaited(_scanIterator?.cancel());
    super.dispose();
  }

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
      await widget.manager.load();
      if (_source == null && !more) await widget.manager.reload();
      if (_source != null) {
        final result = await widget.manager.browse(
          _source!.id,
          BrowseRequest(
            node: _nodes.isEmpty ? null : _nodes.last.ref,
            offset: more ? _next! : 0,
          ),
        );
        if (!mounted) return;
        if (!more) _entries.clear();
        _entries.addAll(result.entries);
        _next = result.nextOffset;
      }
    } catch (error) {
      if (mounted) {
        _error = error is PluginException ? error.message : '加载媒体源失败，请重试。';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(SourceEntry entry) async {
    if (entry.isFolder) {
      _nodes.add(entry);
      await _load();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final stream = await widget.manager.resolve(entry.ref);
      if (!mounted) {
        await stream.release();
        return;
      }
      Navigator.of(context).pop(SourceSelection(entry.name, stream));
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is PluginException ? error.message : '无法播放此文件。';
          _busy = false;
        });
      }
    }
  }

  void _back() {
    if (_nodes.isNotEmpty) {
      _nodes.removeLast();
    } else {
      _source = null;
    }
    _entries.clear();
    _next = null;
    _load();
  }

  String _deletionMessage(String id) {
    final impact = widget.manager.impact(id);
    return '仅删除此实例配置与凭据引用，不删除原始文件、收藏或产物。默认能力绑定 ${impact.defaultCapabilities.length} 项和搜索范围绑定将被清除。当前播放 ${impact.playing} 个、进行中请求 ${impact.running} 个可完成，之后释放连接。';
  }

  Future<void> _scan(SourceConfig config) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final entries = <SourceEntry>[];
      final iterator = StreamIterator(widget.manager.scan(config.id));
      _scanIterator = iterator;
      try {
        while (await iterator.moveNext()) {
          entries.add(iterator.current);
        }
      } finally {
        await iterator.cancel();
        _scanIterator = null;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('扫描预览：${config.name}'),
          content: SizedBox(
            width: 480,
            height: 320,
            child: ListView(
              children: [
                Text(
                  entries.length >= 500
                      ? '已达到预览上限 500 个文件，结果不完整。'
                      : '发现 ${entries.length} 个文件。',
                ),
                const Text('已应用访问范围和扫描排除项；此操作不写入媒体库、不创建后台索引。'),
                for (final entry in entries) ListTile(title: Text(entry.name)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _error = error is PluginException ? error.message : '扫描失败。';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _nodes.isNotEmpty ? _nodes.last.name : _source?.name ?? '媒体源',
      ),
      actions: [
        if (_source == null)
          IconButton(
            tooltip: '重新加载配置',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : () => _load(),
          ),
        if (_source == null &&
            widget.manager.bindings.defaults['source.browse'] != null)
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    final id =
                        widget.manager.bindings.defaults['source.browse'];
                    final config = widget.manager.configs
                        .where((c) => c.id == id && c.enabled)
                        .firstOrNull;
                    if (config == null) {
                      setState(() => _error = '默认实例不可用，请重新选择，未自动切换其他账号。');
                      return;
                    }
                    _source = config;
                    _load();
                  },
            child: const Text('默认浏览'),
          ),
        if (_source == null)
          IconButton(
            tooltip: '能力默认实例',
            icon: const Icon(Icons.tune),
            onPressed: _busy
                ? null
                : () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SourceDefaultsPage(manager: widget.manager),
                      ),
                    );
                    if (mounted) await _load();
                  },
          ),
        if (_source == null)
          TextButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          SourceInstanceForm(manager: widget.manager),
                    );
                    if (mounted) await _load();
                  },
            icon: const Icon(Icons.add),
            label: const Text('添加源'),
          ),
      ],
    ),
    body: Column(
      children: [
        if (_source != null)
          ListTile(
            leading: const Icon(Icons.arrow_upward),
            title: const Text('返回上一级'),
            onTap: _busy ? null : _back,
          ),
        if (_busy) const LinearProgressIndicator(),
        for (final issue in widget.manager.configurationIssues)
          ListTile(
            leading: const Icon(Icons.warning_amber),
            title: Text(issue.message),
            subtitle: Text(issue.instanceId),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _source == null
              ? ListView(
                  children: [
                    if (!_busy && widget.manager.configs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('添加本地文件夹、SMB、Plex 或 Jellyfin 媒体源。'),
                      ),
                    for (final source in widget.manager.configs)
                      Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              leading: Icon(
                                source.kind == SourceKind.local
                                    ? Icons.folder
                                    : Icons.dns,
                              ),
                              title: Text(source.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${source.kind.label} · 插件 ${source.pluginVersion} · 配置 v${source.configVersion} · r${source.revision}',
                                  ),
                                  Text(
                                    widget.manager.applicationLabel(source.id),
                                  ),
                                  FutureBuilder(
                                    future: widget.manager.credentialStatus(
                                      source.id,
                                    ),
                                    builder: (context, snapshot) => Text(
                                      snapshot.data?.label ??
                                          (snapshot.hasError
                                              ? '授权状态暂不可用'
                                              : '正在检查授权…'),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: _busy || !source.enabled
                                  ? null
                                  : () {
                                      _source = source;
                                      _load();
                                    },
                            ),
                            Wrap(
                              alignment: WrapAlignment.end,
                              children: [
                                Switch(
                                  value: source.enabled,
                                  onChanged: _busy
                                      ? null
                                      : (enabled) async {
                                          final impact = widget.manager.impact(
                                            source.id,
                                          );
                                          if (!enabled &&
                                              (impact.playing > 0 ||
                                                  impact.running > 0 ||
                                                  impact
                                                      .defaultCapabilities
                                                      .isNotEmpty)) {
                                            final accepted = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('禁用媒体源？'),
                                                content: Text(
                                                  '当前播放 ${impact.playing} 个，进行中请求 ${impact.running} 个，默认能力绑定 ${impact.defaultCapabilities.length} 项。禁用后拒绝新请求并清除默认绑定；当前播放可继续，结束后释放连接。配置、收藏和产物保留。',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          false,
                                                        ),
                                                    child: const Text('取消'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    child: const Text('禁用'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (accepted != true || !mounted) {
                                              return;
                                            }
                                          }
                                          setState(() => _busy = true);
                                          try {
                                            await widget.manager.setEnabled(
                                              source.id,
                                              enabled,
                                            );
                                            await _load();
                                          } catch (error) {
                                            if (mounted) {
                                              setState(() {
                                                _busy = false;
                                                _error =
                                                    error is PluginException
                                                    ? error.message
                                                    : '启停失败，请重试。';
                                              });
                                            }
                                          }
                                        },
                                ),
                                IconButton(
                                  tooltip: '验证连接',
                                  icon: const Icon(Icons.wifi_find),
                                  onPressed: _busy || !source.enabled
                                      ? null
                                      : () async {
                                          setState(() => _busy = true);
                                          try {
                                            await widget.manager.testConnection(
                                              source.id,
                                            );
                                            await _load();
                                          } catch (error) {
                                            if (mounted) {
                                              setState(() {
                                                _busy = false;
                                                _error =
                                                    error is PluginException
                                                    ? error.message
                                                    : '连接失败。';
                                              });
                                            }
                                          }
                                        },
                                ),
                                if (source.isFileSource)
                                  IconButton(
                                    tooltip: '预览扫描',
                                    icon: const Icon(Icons.manage_search),
                                    onPressed:
                                        _busy ||
                                            !source.enabled ||
                                            source.scanMode == ScanMode.disabled
                                        ? null
                                        : () => _scan(source),
                                  ),
                                IconButton(
                                  tooltip: '编辑媒体源',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          await showDialog<bool>(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (_) => SourceInstanceForm(
                                              manager: widget.manager,
                                              initial: source,
                                            ),
                                          );
                                          if (mounted) await _load();
                                        },
                                ),
                                IconButton(
                                  tooltip: '删除媒体源',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          final confirmed =
                                              await showDialog<bool>(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                      title: Text(
                                                        '删除 ${source.name}？',
                                                      ),
                                                      content: Text(
                                                        _deletionMessage(
                                                          source.id,
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                false,
                                                              ),
                                                          child: const Text(
                                                            '取消',
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                true,
                                                              ),
                                                          child: const Text(
                                                            '删除',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                              );
                                          if (confirmed != true || !mounted) {
                                            return;
                                          }
                                          setState(() => _busy = true);
                                          try {
                                            await widget.manager.remove(
                                              source.id,
                                            );
                                            await _load();
                                          } catch (_) {
                                            if (mounted) {
                                              setState(() {
                                                _error = '删除源失败，请重试。';
                                                _busy = false;
                                              });
                                            }
                                          }
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                )
              : ListView(
                  children: [
                    if (!_busy && _error == null && _entries.isEmpty)
                      const ListTile(title: Text('此目录没有可浏览的媒体。')),
                    for (final entry in _entries)
                      ListTile(
                        leading: Icon(
                          entry.isFolder
                              ? Icons.folder_outlined
                              : Icons.play_circle_outline,
                        ),
                        title: Text(entry.name),
                        onTap: _busy ? null : () => _select(entry),
                      ),
                    if (_next != null)
                      TextButton(
                        onPressed: _busy ? null : () => _load(more: true),
                        child: const Text('加载更多'),
                      ),
                  ],
                ),
        ),
      ],
    ),
  );
}
