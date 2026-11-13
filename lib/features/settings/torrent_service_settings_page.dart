import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../l10n/generated/app_localizations.dart';
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

String? torrentStateLabel(AppLocalizations l, Object? state) =>
    switch (state) {
      'metadata_pending' => l.torrentStateMetadataPending,
      'queued' => l.torrentStateQueued,
      'downloading' => l.torrentStateDownloading,
      'paused' => l.torrentStatePaused,
      'checking' => l.torrentStateChecking,
      'stalled' => l.torrentStateStalled,
      'completed' => l.torrentStateCompleted,
      'seeding' => l.torrentStateSeeding,
      'error' => l.torrentStateError,
      'removed' => l.torrentStateRemoved,
      _ => null,
    };

String? torrentHoldLabel(AppLocalizations l, Object? reason) =>
    switch (reason) {
      'awaiting_start' => l.torrentHoldAwaitingStart,
      'quota_exceeded' => l.torrentHoldQuotaExceeded,
      'disk_low' => l.torrentHoldDiskLow,
      'no_files_match_preset' => l.torrentHoldNoFilesMatch,
      _ => null,
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
  final _magnet = TextEditingController();

  TorrentServiceStore get _store => widget.store;
  AppLocalizations get _l => AppLocalizations.of(context);

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
    _magnet.dispose();
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
              ? _l.torrentAvailable('${engine['version']}')
              : _l.torrentEngineUnavailable;
        }
        // Every torrent in the engine, read live (WebUI-added ones too).
        final list = await client.list();
        _tasks[c.id] = [
          for (final t in list['items'] as List)
            Map<String, dynamic>.from(t as Map),
        ];
      } on TorrentServiceException catch (e) {
        // Nothing is cached: an unreachable server shows no stale list.
        _status[c.id] = _l.torrentUnavailableCode(e.code);
        _tasks.remove(c.id);
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
      _message = _l.torrentOperationFailed(e.code);
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
      title: _l.torrentChooseServer,
      actions: [
        for (final c in enabled) SettingsSheetAction(c.name, () => picked = c),
      ],
    );
    return picked;
  }

  String? _magnetError(String code) => switch (code) {
    'invalid_magnet' => _l.torrentMagnetInvalid,
    'magnet_too_long' => _l.torrentMagnetTooLong,
    'unsupported_magnet_parameter' => _l.torrentMagnetUnsupportedParameter,
    'tracker_not_allowed' => _l.torrentMagnetTrackerNotAllowed,
    'too_many_trackers' => _l.torrentMagnetTooManyTrackers,
    'network_address_not_allowed' => _l.torrentMagnetNetworkAddressNotAllowed,
    'duplicate_task' => _l.torrentMagnetDuplicateTask,
    'destination_not_allowed' => _l.torrentMagnetDestinationNotAllowed,
    _ => null,
  };

  /// Paste a magnet link, preview it on the server, then start it there.
  Future<void> _addMagnet() async {
    final server = await _pickServer();
    if (server == null || !mounted) return;
    _magnet.clear();
    var videoOnly = false;
    final text = await pushSettingsPage<String>(
      context,
      title: _l.torrentAddMagnet,
      children: (c) => [
        SettingsSection(
          footer: _l.torrentMagnetFooter,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: ShadInput(
                key: const ValueKey('torrent-magnet-input'),
                controller: _magnet,
                maxLines: 5,
                placeholder: const Text('magnet:?xt=urn:btih:…'),
                autocorrect: false,
                enableSuggestions: false,
              ),
            ),
          ],
        ),
        SettingsSection(
          children: [
            StatefulBuilder(
              builder: (c, setLocal) => SettingsRow(
                title: _l.torrentVideoOnly,
                description: _l.torrentVideoOnlyDescription,
                control: ShadSwitch(
                  key: const ValueKey('torrent-magnet-video'),
                  value: videoOnly,
                  onChanged: (v) => setLocal(() => videoOnly = v),
                ),
              ),
            ),
          ],
        ),
      ],
      trailing: (c) => [
        ShadButton(
          key: const ValueKey('torrent-magnet-preview'),
          onPressed: () => Navigator.pop(c, _magnet.text.trim()),
          child: Text(_l.torrentPreview),
        ),
      ],
    );
    if (text == null || text.isEmpty || !mounted) return;
    if (!text.toLowerCase().startsWith('magnet:?')) {
      setState(() {
        _message = _l.torrentMagnetPrefixRequired;
        _error = true;
      });
      return;
    }
    await _run(() async {
      final client = await _store.client(server.id);
      final Map<String, dynamic> plan;
      try {
        plan = await client.plan({
          'source': {'type': 'magnet', 'magnet': text},
          'destination_ref': server.defaultDestination,
          'selection_preset': videoOnly ? 'video' : 'all',
        });
      } on TorrentServiceException catch (e) {
        final hint = _magnetError(e.code);
        if (hint == null) rethrow;
        throw FormatException(hint);
      }
      if (!mounted) return;
      final name = (plan['name'] as String?)?.isNotEmpty == true
          ? plan['name']
          : _l.torrentNamePending;
      final removed = plan['removed_addresses'] as Map?;
      final skipped =
          ((removed?['private_or_local_address'] as num?) ?? 0) +
          ((removed?['unsupported_address'] as num?) ?? 0);
      final note = skipped > 0
          ? '${_l.torrentTrackersSkipped(skipped.toInt())}\n'
          : '';
      final ok = await showSettingsConfirm(
        context,
        title: _l.torrentDownloadOnServer,
        message:
            '$name\n${videoOnly ? _l.torrentVideoOnly : _l.torrentAllFiles} · ${_l.torrentSizePending}\n$note'
            '${_l.torrentRunsOnServer(server.name)}',
        confirmLabel: _l.torrentStartDownload,
        cancelLabel: _l.cancel,
      );
      if (!ok) return;
      await client.create(plan['plan_ref'] as String);
      _magnet.clear();
      await _refresh(force: true);
      _message = _l.torrentAddedFetchingMetadata;
      _error = false;
    });
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
      if (bytes.length > 4 << 20) throw FormatException(_l.torrentFileTooLarge);
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
        title: _l.torrentDownloadOnServer,
        message:
            '${plan['name']}\n${_l.torrentFileCount((plan['file_count'] as num? ?? 0).toInt())} · ${formatBytes(plan['selected_size'] as num?)}\n'
            '${_l.torrentRunsOnServer(server.name)}',
        confirmLabel: _l.torrentStartDownload,
        cancelLabel: _l.torrentLetAssistantLater,
      );
      if (!ok) {
        _message = _l.torrentUploaded;
        _error = false;
        return;
      }
      await client.create(plan['plan_ref'] as String);
      await _refresh(force: true);
      _message = _l.torrentServerDownloadStarted;
      _error = false;
    });
  }

  Future<void> _control(
    TorrentServiceConfig server,
    Map<String, dynamic> task,
    String action,
  ) => _run(() async {
    final client = await _store.client(server.id);
    action == 'pause'
        ? await client.pause(task['id'] as String)
        : await client.resume(task['id'] as String);
    await _refresh(force: true);
  });

  /// One dialog: what is removed, with an opt-in "also delete files" box.
  /// Returns null when cancelled, otherwise whether to delete the files.
  Future<bool?> _confirmRemove(
    TorrentServiceConfig server,
    Map<String, dynamic> plan,
  ) {
    var deleteFiles = false;
    final size = formatBytes(plan['bytes_on_disk'] as num?);
    final count = plan['files_on_disk'] ?? 0;
    return showShadDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => ShadDialog(
          title: Text(
            deleteFiles ? _l.torrentRemoveAndDeleteTitle : _l.torrentRemoveTitle,
          ),
          description: Text(
            deleteFiles
                ? _l.torrentRemoveAndDeleteMessage(
                    '${plan['task_name']}',
                    (count as num).toInt(),
                    size,
                  )
                : _l.torrentRemoveMessage('${plan['task_name']}', size),
          ),
          actions: [
            ShadButton.ghost(
              key: const ValueKey('torrent-remove-cancel'),
              onPressed: () => Navigator.pop(c),
              child: Text(_l.cancel),
            ),
            deleteFiles
                ? ShadButton.destructive(
                    key: const ValueKey('torrent-remove-confirm'),
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(_l.delete),
                  )
                : ShadButton(
                    key: const ValueKey('torrent-remove-confirm'),
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(_l.remove),
                  ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ShadCheckbox(
              key: const ValueKey('torrent-remove-delete-files'),
              value: deleteFiles,
              enabled: server.allowDeleteFiles,
              onChanged: (v) => setLocal(() => deleteFiles = v),
              label: Text(_l.torrentAlsoDeleteFiles(size)),
              sublabel: server.allowDeleteFiles
                  ? null
                  : Text(_l.torrentDeleteFilesDisabledHint),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _remove(
    TorrentServiceConfig server,
    Map<String, dynamic> task,
  ) => _run(() async {
    final client = await _store.client(server.id);
    final id = task['id'] as String;
    // Preview first (sizes, name), then ask once.
    var plan = await client.removePlan(id, false);
    if (!mounted) return;
    final deleteFiles = await _confirmRemove(server, plan);
    if (deleteFiles == null) return;
    if (deleteFiles) {
      // The server binds the choice into the confirmation token.
      plan = await client.removePlan(id, true);
    }
    final result = await client.remove(id, plan['plan_ref'] as String);
    await _refresh(force: true);
    _message = result['data_deleted'] == true
        ? _l.torrentRemovedAndDeleted
        : _l.torrentRemovedKeptFiles;
    _error = false;
  });

  Widget _task(TorrentServiceConfig server, Map<String, dynamic> t) {
    final theme = ShadTheme.of(context);
    final state = t['state'] as String? ?? '';
    final hold = torrentHoldLabel(_l, t['hold_reason']);
    final progress = (t['progress'] as num? ?? 0).toDouble();
    final paused = state == 'paused' || state == 'completed';
    final parts = <String>[
      t['added_via'] == 'other'
          ? _l.torrentServerDownloadWebUi
          : _l.torrentServerDownload,
      hold ?? torrentStateLabel(_l, state) ?? state,
      '${(progress * 100).toStringAsFixed(progress < 1 ? 1 : 0)}%',
      if ((t['download_speed'] as num? ?? 0) > 0)
        '↓${formatBytes(t['download_speed'] as num?)}/s',
      if ((t['upload_speed'] as num? ?? 0) > 0)
        '↑${formatBytes(t['upload_speed'] as num?)}/s',
      if (t['stale'] == true) _l.torrentStatusStale,
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
                child: Text(paused ? _l.torrentResume : _l.torrentPause),
              ),
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: _busy ? null : () => _remove(server, t),
                child: Text(_l.remove),
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
      title: Text(_l.bitTorrentService),
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
                    child: Text(_l.torrentAddService),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ShadButton.outline(
                    key: const ValueKey('torrent-add-magnet'),
                    onPressed: _busy || _store.enabled.isEmpty
                        ? null
                        : _addMagnet,
                    child: Text(_l.torrentAddMagnet),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ShadButton.outline(
                    key: const ValueKey('torrent-upload'),
                    onPressed: _busy || _store.enabled.isEmpty ? null : _upload,
                    child: Text(_l.torrentUploadFile),
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
            SettingsSection(
              footer: _l.torrentUnconfiguredFooter,
              children: [
                SettingsRow(
                  key: const ValueKey('torrent-unconfigured'),
                  title: _l.torrentUnconfigured,
                ),
              ],
            ),
          for (final c in configs)
            SettingsSection(
              key: ValueKey('torrent-service-${c.id}'),
              title: c.name,
              footer: _l.torrentServiceFooter,
              children: [
                SettingsRow(
                  title: _l.torrentAddress,
                  control: Text(Uri.tryParse(c.baseUrl)?.host ?? ''),
                  chevron: true,
                  onTap: _busy ? null : () => _edit(c),
                ),
                SettingsRow(
                  title: _l.torrentStatus,
                  control: Text(
                    c.enabled ? (_status[c.id] ?? '…') : _l.torrentDisabled,
                  ),
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
    text: widget.config?.name ?? _l.torrentDefaultServerName,
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
  AppLocalizations get _l => AppLocalizations.of(context);

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
    name: _name.text.trim().isEmpty
        ? _l.torrentDefaultServerName
        : _name.text.trim(),
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
        _message = _l.torrentTokenRequired;
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
            ? _l.torrentConnected('${engine['version']}')
            : _l.torrentReachableEngineUnavailable;
        _error = engine['available'] != true;
      } else if (mounted) {
        Navigator.pop(context, true);
        return;
      }
    } on TorrentServiceException catch (e) {
      _message = _l.torrentConnectFailed(e.code);
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
      title: _l.torrentRemoveConfigTitle,
      message: _l.torrentRemoveConfigMessage,
      confirmLabel: _l.remove,
      cancelLabel: _l.cancel,
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
      widget.config == null ? _l.torrentAddServiceTitle : _l.torrentEditServiceTitle,
    ),
    trailing: [
      ShadButton(
        key: const ValueKey('torrent-save'),
        onPressed: _busy ? null : _save,
        child: Text(_l.save),
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
          title: _l.torrentConnection,
          footer: _l.torrentConnectionFooter,
          children: [
            SettingsFieldRow(
              title: _l.torrentName,
              field: _input('name', _name, _l.torrentName),
            ),
            SettingsFieldRow(
              title: _l.torrentAddress,
              field: _input('url', _url, 'https://bt.example.com'),
            ),
            SettingsFieldRow(
              title: 'API Token',
              field: _input(
                'token',
                _token,
                _hasToken ? _l.torrentTokenSaved : 'obt_…',
                secret: true,
              ),
            ),
          ],
        ),
        SettingsSection(
          title: _l.torrentDownloadScope,
          children: [
            SettingsFieldRow(
              title: _l.torrentDefaultDestination,
              field: _input('destination', _dest, 'default'),
              description: _l.torrentDefaultDestinationDescription,
            ),
            SettingsFieldRow(
              title: _l.torrentPollInterval,
              field: _input('poll', _poll, '10'),
              description: _l.torrentPollIntervalDescription,
            ),
            SettingsRow(
              title: _l.torrentAllowDeleteFiles,
              description: _l.torrentAllowDeleteFilesDescription,
              control: ShadSwitch(
                value: _allowDelete,
                onChanged: (v) => setState(() => _allowDelete = v),
              ),
            ),
            SettingsRow(
              title: _l.torrentEnabled,
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
                child: Text(_l.torrentSaveAndTest),
              ),
            ),
            if (widget.config != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ShadButton.destructive(
                  onPressed: _busy ? null : _delete,
                  child: Text(_l.torrentRemoveConfig),
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
