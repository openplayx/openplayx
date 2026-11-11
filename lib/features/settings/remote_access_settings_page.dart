import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/remote_access/remote_access_service.dart';
import '../../data/remote_access/remote_config.dart';
import '../../data/remote_access/remote_transport.dart';
import '../../data/sources/source_config.dart';
import '../../data/sources/source_manager.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/settings/settings_section.dart';
import '../../ui/tokens/app_spacing.dart';

class RemoteAccessSettingsPage extends StatefulWidget {
  const RemoteAccessSettingsPage({super.key, required this.sources});
  final SourceManager sources;
  @override
  State<RemoteAccessSettingsPage> createState() =>
      _RemoteAccessSettingsPageState();
}

class _RemoteAccessSettingsPageState extends State<RemoteAccessSettingsPage> {
  RemoteAccessService? _service;
  RemoteAccessDocument? _draft;
  bool _busy = false;
  String? _message;
  final _probe = TextEditingController(),
      _stability = TextEditingController(),
      _attempts = TextEditingController(),
      _delay = TextEditingController();
  final _staged = <(String, String)>[];
  @override
  void initState() {
    super.initState();
    _run(_reload);
  }

  Future<void> _reload() async {
    try {
      await widget.sources.reload();
    } catch (_) {
      _service = await widget.sources.remoteConfigurationForRecovery;
      rethrow;
    }
    final service = await widget.sources.remoteSettings;
    final document = await service.refresh();
    if (!mounted) return;
    _service = service;
    _draft = document;
    _probe.text = '${document.probeTimeoutMs}';
    _stability.text = '${document.stabilitySeconds}';
    _attempts.text = '${document.reconnectAttempts}';
    _delay.text = '${document.reconnectDelayMs}';
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _message = error is FormatException ? error.message : '$error';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  RemoteAccessDocument _document() => _draft!.copyWith(
    probeTimeoutMs: int.parse(_probe.text),
    stabilitySeconds: int.parse(_stability.text),
    reconnectAttempts: int.parse(_attempts.text),
    reconnectDelayMs: int.parse(_delay.text),
  );
  Future<void> _edit(SourceConfig source, {bool backup = false}) async {
    final current = _draft!.bindings[source.id];
    final result = await showShadDialog<RemoteAccessConfig>(
      context: context,
      builder: (_) => _RemoteEditor(
        source: source,
        initial: backup ? null : current?.primary,
      ),
    );
    if (result == null || !mounted) return;
    if (result.credentialRef != current?.primary.credentialRef) {
      _staged.add((source.id, result.credentialRef));
    }
    final bindings = Map<String, RemoteAccessBinding>.of(_draft!.bindings);
    final next = backup && current != null
        ? RemoteAccessBinding(
            current.primary,
            backups: [...current.backups, result],
          )
        : RemoteAccessBinding(result, backups: current?.backups ?? const []);
    try {
      RemoteAccessBinding.fromJson(next.toJson());
      bindings[source.id] = next;
      RemoteAccessConfig update(RemoteAccessConfig route) =>
          route.lineId == result.lineId
          ? RemoteAccessConfig.fromJson({
              ...route.toJson(),
              'outboundOptions': result.outboundOptions,
            })
          : route;
      final updated = bindings.map(
        (id, b) => MapEntry(
          id,
          RemoteAccessBinding(
            update(b.primary),
            backups: b.backups.map(update).toList(),
          ),
        ),
      );
      final document = _draft!.copyWith(bindings: updated);
      document.validate();
      setState(() => _draft = document);
    } catch (error) {
      setState(() => _message = '$error');
    }
  }

  Widget _number(TextEditingController controller, String label, String help) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label),
            const SizedBox(height: 6),
            ShadInput(
              key: ValueKey(label),
              controller: controller,
              enabled: !_busy,
              keyboardType: TextInputType.number,
            ),
            Text(help, style: ShadTheme.of(context).textTheme.muted),
          ],
        ),
      );
  Future<void> _save() async {
    final next = await _service!.save(
      _document(),
      expectedRevision: _draft!.revision,
    );
    _draft = next;
    _message = '修订 ${next.revision} 已保存到 remote_access.json，尚未应用。';
  }

  Future<void> _apply() async {
    await widget.sources.applyRemoteSettings(_service!.desired.revision);
    _message =
        '修订 ${_service!.active.revision} 已在本 App 生效。已有播放保留原连接租约；这不表示其他端或实际播放已验证。';
  }

  Future<void> _test(SourceConfig source, RemoteAccessConfig config) async {
    final revision = _draft!.revision;
    await widget.sources.testDraft(
      source.copyWith(
        remoteAccess: config,
        remoteRuntimePolicy: _document().runtimePolicy,
      ),
      '',
    );
    _message = '草稿修订 $revision 的 ${source.titleName} 连接测试通过，未保存或应用。';
  }

  @override
  void dispose() {
    for (final controller in [_probe, _stability, _attempts, _delay]) {
      controller.dispose();
    }
    final service = _service;
    if (service != null) {
      service.cleanupStaged(_staged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: const Text('远程访问'),
    body: ListView(
      padding: AppSpacing.page(context),
      children: [
        if (_busy) const ShadProgress(),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ShadAlert(title: Text(_message!)),
          ),
        if (_service != null && _draft == null)
          ShadButton.outline(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final confirmed = await showShadDialog<bool>(
                      context: context,
                      builder: (dialogContext) => ShadDialog(
                        title: const Text('恢复已知备份？'),
                        description: const Text(
                          '无法识别的原文件将另存保留；备份会保存为新修订，仍需另行应用。',
                        ),
                        actions: [
                          ShadButton.ghost(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('取消'),
                          ),
                          ShadButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('保留原文件并恢复'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    await _service!.recoverFromBackup();
                    await _reload();
                    _message = '已保留原文件并恢复备份，尚未应用。';
                  }),
            child: const Text('恢复已知备份'),
          ),
        if (_service != null && _draft != null) ...[
          SettingsSection(
            title: '配置与生效状态',
            children: [
              Text(
                '草稿修订 ${_draft!.revision} · 已保存 ${_service!.desired.revision} · 实际生效 ${_service!.active.revision}',
              ),
              Text(
                _service!.error == null
                    ? (_service!.desired.revision == _service!.active.revision
                          ? '当前保存修订已应用'
                          : '已保存但未生效')
                    : '已保存但应用失败，保留上一份有效运行配置',
              ),
              const Text(
                '连接配置只保存在应用私有目录的 remote_access.json；实际 UUID 只保存在系统安全存储。',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ShadButton.outline(
                    onPressed: _busy ? null : () => _run(_save),
                    child: const Text('保存 JSON'),
                  ),
                  ShadButton(
                    onPressed: _busy ? null : () => _run(_apply),
                    child: const Text('应用已保存配置'),
                  ),
                  ShadButton.ghost(
                    onPressed: _busy ? null : () => _run(_reload),
                    child: const Text('重新加载'),
                  ),
                  ShadButton.ghost(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            _draft = await _service!.restore(
                              expectedRevision: _draft!.revision,
                            );
                            _message = '上一份配置已恢复为新修订，尚未应用。';
                          }),
                    child: const Text('恢复备份'),
                  ),
                  ShadButton.ghost(
                    onPressed: _busy
                        ? null
                        : () => showShadDialog<void>(
                            context: context,
                            builder: (_) => ShadDialog(
                              title: const Text('脱敏导出'),
                              child: SizedBox(
                                width: 520,
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    _service!.exportRedacted(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                    child: const Text('脱敏导出'),
                  ),
                ],
              ),
            ],
          ),
          SettingsSection(
            title: '探测与连接策略',
            children: [
              _number(_probe, '局域网探测超时（毫秒）', '200–10000；每次仅探测已配置且配对的端点。'),
              _number(_stability, '路径稳定窗口（秒）', '5–300；复用同一来源的探测，避免频繁切换。'),
              _number(_attempts, '播放前连接重试次数', '0–5；只重试网络建立阶段，不重复提交媒体登录。'),
              _number(_delay, '连接重试间隔（毫秒）', '100–10000；不主动中断健康的播放租约。'),
              ShadSwitch(
                value: _draft!.allowCellular,
                enabled: !_busy,
                label: const Text('允许蜂窝网络远程访问'),
                onChanged: (v) =>
                    setState(() => _draft = _draft!.copyWith(allowCellular: v)),
              ),
            ],
          ),
          for (final source in widget.sources.configs.where(
            (c) =>
                c.kind.mediaBrowser ||
                c.kind == SourceKind.plex ||
                c.kind == SourceKind.smb,
          ))
            SettingsSection(
              title: source.titleName,
              children: [
                if (_draft!.bindings[source.id] case final binding?) ...[
                  Text(
                    '家庭 ${binding.primary.homeId} · 服务 ${binding.primary.serviceId}',
                  ),
                  Text(
                    '主线路 ${binding.primary.lineId} · ${binding.primary.outboundOptions?['server'] ?? '已保存线路'}',
                  ),
                  Text(
                    '模式 ${binding.primary.mode.name} · 远程端点 ${binding.primary.remoteAddress}',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ShadButton.outline(
                        onPressed: _busy ? null : () => _edit(source),
                        child: const Text('编辑连接'),
                      ),
                      ShadButton.ghost(
                        onPressed: _busy
                            ? null
                            : () => _run(() => _test(source, binding.primary)),
                        child: const Text('测试草稿'),
                      ),
                      if (binding.backups.length < 4)
                        ShadButton.ghost(
                          onPressed: _busy
                              ? null
                              : () => _edit(source, backup: true),
                          child: const Text('添加备用线路'),
                        ),
                      ShadButton.ghost(
                        onPressed: _busy
                            ? null
                            : () => setState(
                                () => _draft = _draft!.copyWith(
                                  bindings: Map.of(_draft!.bindings)
                                    ..remove(source.id),
                                ),
                              ),
                        child: const Text('移除绑定'),
                      ),
                    ],
                  ),
                  for (final backup in binding.backups)
                    SettingsRow(
                      title: '备用 ${backup.lineId}',
                      description:
                          '${backup.outboundOptions?['server'] ?? backup.remoteAddress} · 手动切换后保存并应用',
                      control: Wrap(
                        children: [
                          ShadButton.ghost(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    final list = [
                                      binding.primary,
                                      ...binding.backups.where(
                                        (r) => r != backup,
                                      ),
                                    ];
                                    _draft = _draft!.copyWith(
                                      bindings: Map.of(_draft!.bindings)
                                        ..[source.id] = RemoteAccessBinding(
                                          backup,
                                          backups: list,
                                        ),
                                    );
                                  }),
                            child: const Text('设为主线路'),
                          ),
                          ShadButton.ghost(
                            onPressed: _busy
                                ? null
                                : () => setState(
                                    () => _draft = _draft!.copyWith(
                                      bindings: Map.of(_draft!.bindings)
                                        ..[source.id] = RemoteAccessBinding(
                                          binding.primary,
                                          backups: binding.backups
                                              .where((r) => r != backup)
                                              .toList(),
                                        ),
                                    ),
                                  ),
                            child: const Text('移除'),
                          ),
                        ],
                      ),
                    ),
                ] else
                  ShadButton.outline(
                    onPressed: _busy ? null : () => _edit(source),
                    child: const Text('配置家庭远程访问'),
                  ),
              ],
            ),
          const Text('App 只管理本端。更换映射、凭据或端口后，还需分别确认 Relay 与 Home 配置一致。'),
        ],
      ],
    ),
  );
}

class _RemoteEditor extends StatefulWidget {
  const _RemoteEditor({required this.source, this.initial});
  final SourceConfig source;
  final RemoteAccessConfig? initial;
  @override
  State<_RemoteEditor> createState() => _RemoteEditorState();
}

class _RemoteEditorState extends State<_RemoteEditor> {
  final _fields = <String, TextEditingController>{};
  RemoteConnectionMode _mode = RemoteConnectionMode.remoteOnly;
  Map<String, dynamic> _extra = {};
  String? _error;
  bool _busy = false;
  TextEditingController c(String key) =>
      _fields.putIfAbsent(key, () => TextEditingController());
  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _mode = r?.mode ?? RemoteConnectionMode.remoteOnly;
    final out = r?.outboundOptions ?? const <String, dynamic>{};
    _extra = Map.of(out);
    final tls = out['tls'] as Map<String, dynamic>? ?? {};
    final values = {
      'lineId': r?.lineId ?? 'line-${DateTime.now().microsecondsSinceEpoch}',
      'homeId': r?.homeId ?? 'home-main',
      'serviceId': r?.serviceId ?? widget.source.kind.name,
      'remoteAddress': r?.remoteAddress ?? widget.source.address,
      'remotePort': '${r?.remotePort ?? 18096}',
      'host': out['server'] as String? ?? '',
      'port': '${out['server_port'] ?? 443}',
      'serverName': tls['server_name'] as String? ?? '',
      'ca': tls['certificate'] is String ? tls['certificate'] as String : '',
      'localAddress': r?.localAddress ?? '',
      'fingerprint': r?.localTlsSha256 ?? '',
    };
    for (final e in values.entries) {
      c(e.key).text = e.value;
    }
  }

  void _import() {
    try {
      final pair = RemotePairing.parse(c('pairing').text);
      final j = pair.data;
      for (final key in [
        'lineId',
        'homeId',
        'serviceId',
        'remoteAddress',
        'remotePort',
      ]) {
        c(key).text = '${j[key]}';
      }
      final out = pair.outbound;
      _extra = Map.of(out)..remove('uuid');
      c('host').text = out['server'] as String;
      c('port').text = '${out['server_port']}';
      c('uuid').text = out['uuid'] as String;
      final tls = out['tls'] as Map;
      c('serverName').text = tls['server_name'] as String;
      c('ca').text = tls['certificate'] is String
          ? tls['certificate'] as String
          : '';
      c('pairing').clear();
      setState(() => _error = null);
    } catch (error) {
      setState(() => _error = '$error');
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    String? staged;
    try {
      Map<String, dynamic> old = {};
      if (widget.initial != null) {
        old = await RemoteCredentialStore.read(
          widget.source.id,
          widget.initial!.credentialRef,
        );
      }
      final tls = Map<String, dynamic>.of(
        _extra['tls'] as Map<String, dynamic>? ?? {},
      )..remove('certificate');
      final public = {
        ..._extra,
        'type': 'vless',
        'server': c('host').text.trim(),
        'server_port': int.parse(c('port').text),
        'tls': {
          ...tls,
          'enabled': true,
          'server_name': c('serverName').text.trim(),
          if (c('ca').text.trim().isNotEmpty)
            'certificate': c('ca').text.trim(),
        },
      }..remove('uuid');
      final secret = c('uuid').text.trim().isEmpty
          ? old['uuid']
          : c('uuid').text.trim();
      RemotePairing.validateOutbound({...public, 'uuid': secret});
      var ref = widget.initial?.credentialRef;
      if (ref == null || c('uuid').text.trim().isNotEmpty) {
        ref = staged = await RemoteCredentialStore.stage(widget.source.id, {
          'uuid': secret,
        });
      }
      final result = RemoteAccessConfig(
        lineId: c('lineId').text.trim(),
        homeId: c('homeId').text.trim(),
        serviceId: c('serviceId').text.trim(),
        remoteAddress: c('remoteAddress').text.trim(),
        remotePort: int.parse(c('remotePort').text),
        credentialRef: ref,
        mode: _mode,
        localAddress: c('localAddress').text.trim(),
        localTlsSha256: c('fingerprint').text.trim(),
        outboundOptions: public,
      );
      widget.source.copyWith(remoteAccess: result).validate();
      if (mounted) {
        Navigator.pop(context, result);
      } else if (staged != null) {
        await RemoteCredentialStore.delete(widget.source.id, staged);
      }
    } catch (error) {
      if (staged != null) {
        await RemoteCredentialStore.delete(widget.source.id, staged);
      }
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget field(
    String key,
    String label, {
    bool secret = false,
    bool multiline = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label),
        const SizedBox(height: 6),
        ShadInput(
          key: ValueKey('remote-$key'),
          controller: c(key),
          enabled: !_busy,
          obscureText: secret,
          maxLines: multiline ? 4 : 1,
          autocorrect: false,
          enableSuggestions: false,
        ),
      ],
    ),
  );
  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShadDialog(
    title: const Text('远程连接设置'),
    constraints: const BoxConstraints(maxWidth: 580),
    actions: [
      ShadButton.ghost(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      ShadButton(onPressed: _busy ? null : _save, child: const Text('更新草稿')),
    ],
    child: SizedBox(
      width: 530,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '通过可信渠道导入配对，确认局域网与远程入口属于同一媒体服务。同一线路 ID 的公开代理参数会一起更新。编辑这里只更新草稿，返回后保存并应用。',
            ),
            field('pairing', '可选：Relay 配对 JSON', multiline: true),
            ShadButton.outline(
              onPressed: _busy ? null : _import,
              child: const Text('导入配对并填充表单'),
            ),
            field('lineId', '稳定线路 ID'),
            field('homeId', '家庭 ID'),
            field('serviceId', '服务 ID'),
            field('host', 'Relay 地址'),
            field('port', '代理端口'),
            field('serverName', '代理 TLS 服务名称'),
            field('uuid', 'VLESS UUID（留空保留已有机密）', secret: true),
            field('ca', '可选代理 CA（公开证书）', multiline: true),
            field('remoteAddress', '媒体服务逻辑端点'),
            field('remotePort', 'Relay 分配的映射端口'),
            const SizedBox(height: 12),
            ShadSelect<RemoteConnectionMode>(
              initialValue: _mode,
              selectedOptionBuilder: (_, v) => Text(v.name),
              onChanged: (v) => setState(() => _mode = v!),
              options:
                  (widget.source.kind == SourceKind.smb
                          ? [RemoteConnectionMode.remoteOnly]
                          : RemoteConnectionMode.values)
                      .map(
                        (v) => ShadOption(
                          value: v,
                          child: Text(switch (v) {
                            RemoteConnectionMode.automatic => '自动：验证局域网，否则远程',
                            RemoteConnectionMode.localOnly => '仅局域网',
                            RemoteConnectionMode.remoteOnly => '仅远程',
                          }),
                        ),
                      )
                      .toList(),
            ),
            if (_mode != RemoteConnectionMode.remoteOnly) ...[
              field('localAddress', '已配对的局域网 HTTPS 地址'),
              field('fingerprint', '通过可信途径确认的证书 SHA-256（64 位）'),
            ],
            if (_extra['tls'] is Map &&
                (_extra['tls'] as Map)['reality'] != null)
              const Text('已保留导入的 REALITY 协议参数；更换协议请重新导入可信配对。'),
            if (_error != null) ShadAlert.destructive(title: Text(_error!)),
          ],
        ),
      ),
    ),
  );
}
