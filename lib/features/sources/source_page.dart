import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_config.dart';
import '../../data/sources/source_manager.dart';

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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _nodes.isNotEmpty ? _nodes.last.name : _source?.name ?? '媒体源',
      ),
      actions: [
        if (_source == null)
          TextButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    final added = await showDialog<bool>(
                      context: context,
                      builder: (_) => _SourceForm(manager: widget.manager),
                    );
                    if (added == true && mounted) await _load();
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
                      ListTile(
                        leading: Icon(
                          source.kind == SourceKind.local
                              ? Icons.folder
                              : Icons.dns,
                        ),
                        title: Text(source.name),
                        subtitle: Text(source.kind.label),
                        onTap: _busy
                            ? null
                            : () {
                                _source = source;
                                _load();
                              },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '编辑媒体源',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      final changed = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => _SourceForm(
                                          manager: widget.manager,
                                          initial: source,
                                        ),
                                      );
                                      if (changed == true && mounted) {
                                        await _load();
                                      }
                                    },
                            ),
                            IconButton(
                              tooltip: '删除媒体源',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('删除 ${source.name}？'),
                                          content: const Text(
                                            '删除源配置，不会删除原始文件。',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('取消'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('删除'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed != true || !mounted) return;
                                      setState(() => _busy = true);
                                      try {
                                        await widget.manager.remove(source.id);
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

class _SourceForm extends StatefulWidget {
  const _SourceForm({required this.manager, this.initial});
  final SourceConfig? initial;
  final SourceManager manager;
  @override
  State<_SourceForm> createState() => _SourceFormState();
}

class _SourceFormState extends State<_SourceForm> {
  SourceKind _kind = SourceKind.local;
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _username = TextEditingController();
  final _domain = TextEditingController();
  final _userId = TextEditingController();
  final _secret = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _kind = initial.kind;
      _name.text = initial.name;
      _address.text = initial.address;
      _username.text = initial.username;
      _domain.text = initial.domain;
      _userId.text = initial.userId;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _username, _domain, _userId, _secret]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.manager.save(
        SourceConfig(
          id: widget.initial?.id ?? '${DateTime.now().microsecondsSinceEpoch}',
          bookmark: widget.initial?.bookmark,
          kind: _kind,
          name: _name.text.trim(),
          address: _address.text.trim(),
          username: _username.text.trim(),
          domain: _domain.text.trim(),
          userId: _userId.text.trim(),
        ),
        _secret.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is FormatException
              ? error.message
              : error is PluginException
              ? error.message
              : '保存失败，请检查系统安全存储是否可用。';
          _saving = false;
        });
      }
    }
  }

  Widget _field(TextEditingController c, String label, {bool secret = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: c,
          enabled: !_saving,
          obscureText: secret,
          autocorrect: false,
          enableSuggestions: !secret,
          decoration: InputDecoration(
            labelText: label,
            helperText: secret && widget.initial != null ? '留空保留原凭据' : null,
            border: const OutlineInputBorder(),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? '添加媒体源' : '编辑媒体源'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<SourceKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: '类型'),
              items: SourceKind.values
                  .map(
                    (kind) =>
                        DropdownMenuItem(value: kind, child: Text(kind.label)),
                  )
                  .toList(),
              onChanged: _saving || widget.initial != null
                  ? null
                  : (kind) => setState(() {
                      _kind = kind!;
                      _address.clear();
                      _secret.clear();
                      _error = null;
                    }),
            ),
            _field(_name, '名称'),
            if (_kind == SourceKind.local) ...[
              if (Platform.isAndroid || Platform.isIOS)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('此平台请填写应用可访问的目录；单文件可使用播放器的“打开文件”。'),
                ),
              _field(_address, '本地文件夹路径'),
              if (!Platform.isAndroid && !Platform.isIOS)
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          final path = await getDirectoryPath();
                          if (path != null && mounted) {
                            setState(() => _address.text = path);
                          }
                        },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('选择文件夹'),
                ),
            ] else ...[
              _field(
                _address,
                _kind == SourceKind.smb
                    ? 'smb://主机/共享名/可选目录'
                    : '服务器 URL（可含子路径）',
              ),
              if (_kind == SourceKind.smb) ...[
                _field(_username, '用户名（访客可留空）'),
                _field(_domain, '域（可选）'),
              ],
              if (_kind == SourceKind.jellyfin)
                _field(_userId, 'Jellyfin 用户 ID'),
              _field(
                _secret,
                _kind == SourceKind.smb
                    ? '密码'
                    : _kind == SourceKind.plex
                    ? 'X-Plex-Token'
                    : 'Jellyfin 访问令牌 / API Key',
                secret: true,
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? '保存中…' : '保存'),
      ),
    ],
  );
}
