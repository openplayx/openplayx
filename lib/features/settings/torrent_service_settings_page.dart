import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../services/ai_tools/torrent_tools.dart';
import '../../services/torrent/torrent_service.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/settings/settings_adaptive.dart';
import '../../ui/components/settings/settings_section.dart';

String formatBytes(num? bytes) {
  final b = (bytes ?? 0).toDouble();
  if (b < 1024) return '${b.toInt()} B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var v = b / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v < 10 ? 1 : 0)} ${units[i]}';
}

const torrentStateLabels = {
  'metadata_pending': '获取元数据',
  'queued': '排队中',
  'downloading': '下载中',
  'paused': '已暂停',
  'checking': '校验中',
  'stalled': '等待连接',
  'completed': '服务器下载完成',
  'seeding': '服务器下载完成 · 做种中',
  'error': '出错',
  'removed': '已移除',
};

const torrentHoldLabels = {
  'awaiting_selection': '等待开始',
  'quota_exceeded': '超出额度',
  'disk_low': '磁盘空间不足',
  'no_files_match_preset': '没有匹配的文件',
};

/// Settings → 来源与下载 → BitTorrent 服务. Downloads run on the server;
/// this page shows them as server downloads, never as App library items.
class TorrentServiceSettingsPage extends StatefulWidget {
  const TorrentServiceSettingsPage({super.key, required this.store});
  final TorrentServiceStore store;
  @override
  State<TorrentServiceSettingsPage> createState() =>
      _TorrentServiceSettingsPageState();
}

class _TorrentServiceSettingsPageState
    extends State<TorrentServiceSettingsPage> {
  bool _busy = false;
  String? _message;
  bool _error = false;
  Timer? _timer;
  final _status = <String, String>{};
  final _tasks = <String, List<Map<String, dynamic>>>{};

  TorrentServiceStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _run(() async {
      if (!_store.loaded) await _store.load();
      await _refresh(force: true);
    });
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final enabled = _store.enabled;
    if (enabled.isEmpty) return;
    final seconds = enabled
        .map((c) => c.pollSeconds)
        .reduce((a, b) => a < b ? a : b);
    // Bounded polling only while this page is visible.
    _timer = Timer.periodic(Duration(seconds: seconds), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool force = false}) async {
    for (final c in _store.enabled) {
      try {
        final client = await _store.client(c.id);
        if (force || !_status.containsKey(c.id)) {
          final caps = await client.capabilities();
          final engine = caps['engine'] as Map? ?? const {};
          _status[c.id] = engine['available'] == true
              ? '可用 · qBittorrent ${engine['version']}'
              : '服务在线，下载引擎不可用';
        }
        final list = await client.list(force: force);
        _tasks[c.id] = [
          for (final t in list['items'] as List)
            if ((t as Map)['state'] != 'removed') Map<String, dynamic>.from(t),
        ];
      } on TorrentServiceException catch (e) {
        // Keep the last known tasks; an unreachable server deletes nothing.
        _status[c.id] = '不可用（${e.code}）';
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted && done != null) {
        _message = done;
        _error = false;
      }
    } on TorrentServiceException catch (e) {
      _message = '操作失败：${e.code}';
      _error = true;
    } catch (e) {
      _message = e is FormatException ? e.message : '$e';
      _error = true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([TorrentServiceConfig? config]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TorrentServiceForm(store: _store, config: config),
      ),
    );
    if (saved == true && mounted) {
      _status.clear();
      _schedule();
      await _run(() => _refresh(force: true));
    }
  }

  Future<TorrentServiceConfig?> _pickServer() async {
    final enabled = _store.enabled;
    if (enabled.length <= 1) return enabled.firstOrNull;
    TorrentServiceConfig? picked;
    await showSettingsActionSheet(
      context,
      title: '选择服务器',
      actions: [
        for (final c in enabled) SettingsSheetAction(c.name, () => picked = c),
      ],
    );
    return picked;
  }

  /// Upload a .torrent the user picked; the assistant can then plan it via
  /// its input_ref, or the user starts it here directly.
  Future<void> _upload() async {
    final server = await _pickServer();
    if (server == null || !mounted) return;
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'BitTorrent',
          extensions: ['torrent'],
          mimeTypes: ['application/x-bittorrent'],
          uniformTypeIdentifiers: ['org.bittorrent.torrent', 'public.data'],
        ),
      ],
    );
    if (file == null || !mounted) return;
    await _run(() async {
      final bytes = await file.readAsBytes();
      if (bytes.length > 4 << 20) throw const FormatException('种子文件过大');
      final client = await _store.client(server.id);
      final input = await client.uploadTorrent(bytes);
      TorrentToolsRegistry.current?.registerUpload(server.id, input);
      final plan = await client.plan({
        'source': {'type': 'input', 'input_ref': input['input_ref']},
        'destination_ref': server.defaultDestination,
        'selection_preset': 'all',
      });
      if (!mounted) return;
      final ok = await showSettingsConfirm(
        context,
        title: '在服务器上下载？',
        message:
            '${plan['name']}\n${plan['file_count']} 个文件 · ${formatBytes(plan['selected_size'] as num?)}\n'
            '下载在「${server.name}」上进行，App 关闭后仍会继续；完成后不会自动进入媒体库。',
        confirmLabel: '开始下载',
        cancelLabel: '稍后让助手处理',
      );
      if (!ok) {
        _message = '已上传。可以让 AI 助手“下载我刚上传的种子”。';
        _error = false;
        return;
      }
      var op = await client.create(
        plan['plan_ref'] as String,
        (plan['revision'] as num).toInt(),
        'app-ui-${plan['plan_ref']}',
      );
      op = await client.settle(op);
      if (op['status'] == 'failed') {
        throw TorrentServiceException('${op['error_code']}');
      }
      await _refresh(force: true);
      _message = '已开始服务器下载。';
      _error = false;
    });
  }

  Future<void> _control(
    TorrentServiceConfig server,
    Map<String, dynamic> task,
    String action,
  ) => _run(() async {
    final client = await _store.client(server.id);
    final key =
        'app-ui-$action-${task['id']}-${DateTime.now().microsecondsSinceEpoch}';
    var op = action == 'pause'
        ? await client.pause(task['id'] as String, key)
        : await client.resume(task['id'] as String, key);
    op = await client.settle(op);
    if (op['status'] == 'failed') {
      throw TorrentServiceException('${op['error_code']}');
    }
    await _refresh(force: true);
  });

  Future<void> _remove(
    TorrentServiceConfig server,
    Map<String, dynamic> task,
  ) async {
    var deleteFiles = false;
    if (server.allowDeleteFiles) {
      String? choice;
      await showSettingsActionSheet(
        context,
        title: '移除「${task['name']}」',
        message: '移除服务器下载任务。默认保留已下载的文件。',
        actions: [
          SettingsSheetAction('移除任务，保留文件', () => choice = 'keep'),
          SettingsSheetAction(
            '移除任务并删除文件',
            () => choice = 'delete',
            destructive: true,
          ),
        ],
      );
      if (choice == null) return;
      deleteFiles = choice == 'delete';
    }
    if (!mounted) return;
    await _run(() async {
      final client = await _store.client(server.id);
      final plan = await client.removePlan(task['id'] as String, deleteFiles);
      if (!mounted) return;
      final ok = await showSettingsConfirm(
        context,
        title: deleteFiles ? '删除服务器上的文件？' : '移除下载任务？',
        message: deleteFiles
            ? '将删除「${plan['task_name']}」的 ${plan['files_on_disk']} 个文件（${formatBytes(plan['bytes_on_disk'] as num?)}），不可恢复。媒体库不受影响。'
            : '任务从服务器移除，已下载的 ${formatBytes(plan['bytes_on_disk'] as num?)} 文件保留在服务器上。',
        confirmLabel: deleteFiles ? '删除' : '移除',
        cancelLabel: '取消',
        destructive: deleteFiles,
      );
      if (!ok) return;
      var op = await client.remove(
        task['id'] as String,
        plan['plan_ref'] as String,
        'app-ui-rm-${plan['plan_ref']}',
      );
      op = await client.settle(op);
      if (op['status'] == 'failed') {
        throw TorrentServiceException('${op['error_code']}');
      }
      await _refresh(force: true);
    }, done: '已移除。');
  }

  Widget _task(TorrentServiceConfig server, Map<String, dynamic> t) {
    final theme = ShadTheme.of(context);
    final state = t['state'] as String? ?? '';
    final hold = torrentHoldLabels[t['hold_reason']];
    final progress = (t['progress'] as num? ?? 0).toDouble();
    final paused = state == 'paused' || state == 'completed';
    final parts = <String>[
      '服务器下载',
      hold ?? torrentStateLabels[state] ?? state,
      '${(progress * 100).toStringAsFixed(progress < 1 ? 1 : 0)}%',
      if ((t['download_speed'] as num? ?? 0) > 0)
        '↓${formatBytes(t['download_speed'] as num?)}/s',
      if ((t['upload_speed'] as num? ?? 0) > 0)
        '↑${formatBytes(t['upload_speed'] as num?)}/s',
      if (t['stale'] == true) '状态未更新',
      if (t['error_code'] != null) '${t['error_code']}',
    ];
    return Padding(
      key: ValueKey('torrent-task-${t['id']}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${t['name']}', style: theme.textTheme.small),
          const SizedBox(height: 4),
          Text(parts.join(' · '), style: theme.textTheme.muted),
          const SizedBox(height: 6),
          ShadProgress(value: progress.clamp(0, 1)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: _busy || state == 'error'
                    ? null
                    : () => _control(server, t, paused ? 'resume' : 'pause'),
                child: Text(paused ? '恢复' : '暂停'),
              ),
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: _busy ? null : () => _remove(server, t),
                child: const Text('移除'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configs = _store.configs;
    return AppPage(
      title: const Text('BitTorrent 服务'),
      body: SettingsListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: ShadButton(
                    key: const ValueKey('torrent-add-service'),
                    onPressed: _busy ? null : () => _edit(),
                    child: const Text('添加服务'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ShadButton.outline(
                    key: const ValueKey('torrent-upload'),
                    onPressed: _busy || _store.enabled.isEmpty ? null : _upload,
                    child: const Text('上传种子文件'),
                  ),
                ),
              ],
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: ShadProgress(),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _error
                  ? ShadAlert.destructive(title: Text(_message!))
                  : ShadAlert(title: Text(_message!)),
            ),
          if (_store.loaded && configs.isEmpty)
            const SettingsSection(
              footer: '连接你自己部署的 OpenPlayX BitTorrent 服务后，可在这里或通过 AI 助手添加 Magnet / 种子下载。下载在服务器上进行。',
              children: [
                SettingsRow(
                  key: ValueKey('torrent-unconfigured'),
                  title: '尚未配置',
                ),
              ],
            ),
          for (final c in configs)
            SettingsSection(
              key: ValueKey('torrent-service-${c.id}'),
              title: c.name,
              footer: '下载在服务器上进行，App 关闭不会停止；服务器下载完成不代表已进入媒体库或已离线到本机。',
              children: [
                SettingsRow(
                  title: '地址',
                  control: Text(Uri.tryParse(c.baseUrl)?.host ?? ''),
                  chevron: true,
                  onTap: _busy ? null : () => _edit(c),
                ),
                SettingsRow(
                  title: '状态',
                  control: Text(c.enabled ? (_status[c.id] ?? '…') : '已停用'),
                ),
                for (final t in _tasks[c.id] ?? const <Map<String, dynamic>>[])
                  _task(c, t),
              ],
            ),
        ],
      ),
    );
  }
}

/// Edit form for one service. The API token is written only to secure
/// storage and never shown again.
class TorrentServiceForm extends StatefulWidget {
  const TorrentServiceForm({super.key, required this.store, this.config});
  final TorrentServiceStore store;
  final TorrentServiceConfig? config;
  @override
  State<TorrentServiceForm> createState() => _TorrentServiceFormState();
}

class _TorrentServiceFormState extends State<TorrentServiceForm> {
  late final _name = TextEditingController(
    text: widget.config?.name ?? 'BitTorrent 服务器',
  );
  late final _url = TextEditingController(text: widget.config?.baseUrl ?? '');
  final _token = TextEditingController();
  late final _dest = TextEditingController(
    text: widget.config?.defaultDestination ?? 'default',
  );
  late final _poll = TextEditingController(
    text: '${widget.config?.pollSeconds ?? 10}',
  );
  late bool _allowDelete = widget.config?.allowDeleteFiles ?? false;
  late bool _enabled = widget.config?.enabled ?? true;
  bool _hasToken = false, _busy = false;
  String? _message;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    if (c != null) {
      widget.store.hasToken(c.id).then((v) {
        if (mounted) setState(() => _hasToken = v);
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _url, _token, _dest, _poll]) {
      c.dispose();
    }
    super.dispose();
  }

  TorrentServiceConfig _build() => TorrentServiceConfig(
    id: widget.config?.id ?? TorrentServiceStore.newId(),
    name: _name.text.trim().isEmpty ? 'BitTorrent 服务器' : _name.text.trim(),
    baseUrl: _url.text.trim().replaceAll(RegExp(r'/+$'), ''),
    defaultDestination: _dest.text.trim().isEmpty
        ? 'default'
        : _dest.text.trim(),
    allowDeleteFiles: _allowDelete,
    pollSeconds: (int.tryParse(_poll.text) ?? 10).clamp(5, 300),
    enabled: _enabled,
  );

  Future<void> _save({bool test = false}) async {
    final config = _build();
    final urlError = TorrentServiceConfig.validateUrl(config.baseUrl);
    if (urlError != null) {
      setState(() {
        _message = urlError;
        _error = true;
      });
      return;
    }
    if (_token.text.trim().isEmpty && !_hasToken) {
      setState(() {
        _message = '请填写 API Token';
        _error = true;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.store.save(
        config,
        token: _token.text.trim().isEmpty ? null : _token.text.trim(),
      );
      _hasToken = true;
      _token.clear();
      if (test) {
        final caps = await (await widget.store.client(config.id))
            .capabilities();
        final engine = caps['engine'] as Map? ?? const {};
        _message = engine['available'] == true
            ? '连接成功：qBittorrent ${engine['version']}'
            : '服务可达，但下载引擎当前不可用';
        _error = engine['available'] != true;
      } else if (mounted) {
        Navigator.pop(context, true);
        return;
      }
    } on TorrentServiceException catch (e) {
      _message = '连接失败：${e.code}';
      _error = true;
    } on FormatException catch (e) {
      _message = e.message;
      _error = true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showSettingsConfirm(
      context,
      title: '移除此服务配置？',
      message: '只移除 App 中的地址和 Token；服务器上的下载继续进行，文件不会被删除。',
      confirmLabel: '移除',
      cancelLabel: '取消',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await widget.store.delete(widget.config!.id);
    if (mounted) Navigator.pop(context, true);
  }

  Widget _input(
    String id,
    TextEditingController c,
    String hint, {
    bool secret = false,
  }) => ShadInput(
    key: ValueKey('torrent-field-$id'),
    controller: c,
    placeholder: Text(hint),
    obscureText: secret,
    autocorrect: false,
    enableSuggestions: false,
    decoration: ShadDecoration.none,
  );

  @override
  Widget build(BuildContext context) => AppPage(
    title: Text(
      widget.config == null ? '添加 BitTorrent 服务' : '编辑 BitTorrent 服务',
    ),
    trailing: [
      ShadButton(
        key: const ValueKey('torrent-save'),
        onPressed: _busy ? null : _save,
        child: const Text('保存'),
      ),
    ],
    body: SettingsListView(
      children: [
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _error
                ? ShadAlert.destructive(title: Text(_message!))
                : ShadAlert(title: Text(_message!)),
          ),
        SettingsSection(
          title: '连接',
          footer: '公网地址必须使用 HTTPS；HTTP 仅允许局域网地址。Token 保存在系统安全存储中。',
          children: [
            SettingsFieldRow(title: '名称', field: _input('name', _name, '名称')),
            SettingsFieldRow(
              title: '地址',
              field: _input('url', _url, 'https://bt.example.com'),
            ),
            SettingsFieldRow(
              title: 'API Token',
              field: _input(
                'token',
                _token,
                _hasToken ? '已保存（留空不修改）' : 'obt_…',
                secret: true,
              ),
            ),
          ],
        ),
        SettingsSection(
          title: '下载与访问范围',
          children: [
            SettingsFieldRow(
              title: '默认目标',
              field: _input('destination', _dest, 'default'),
              description: '服务端配置的逻辑目标名（destination_ref），不是服务器路径。',
            ),
            SettingsFieldRow(
              title: '刷新间隔',
              field: _input('poll', _poll, '10'),
              description: '秒（5–300）。任务列表与 AI 查询共用此间隔的缓存。',
            ),
            SettingsRow(
              title: '允许删除服务器文件',
              description: '关闭时 AI 助手和此页面只能移除任务并保留文件。',
              control: ShadSwitch(
                value: _allowDelete,
                onChanged: (v) => setState(() => _allowDelete = v),
              ),
            ),
            SettingsRow(
              title: '启用',
              control: ShadSwitch(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: ShadButton.outline(
                key: const ValueKey('torrent-test'),
                onPressed: _busy ? null : () => _save(test: true),
                child: const Text('保存并测试连接'),
              ),
            ),
            if (widget.config != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ShadButton.destructive(
                  onPressed: _busy ? null : _delete,
                  child: const Text('移除配置'),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

/// Lets the settings page hand uploads to the assistant's tools.
class TorrentToolsRegistry {
  static TorrentTools? current;
}
