import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/remote_access/remote_access_service.dart';
import '../../data/sources/source_manager.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/settings/settings_adaptive.dart';
import '../../ui/components/settings/settings_section.dart';

/// The App's network layer: one Relay connection (sing-box outbound) and the
/// frpc proxies it offers. Sources pick a proxy in their own settings.
class RemoteAccessSettingsPage extends StatefulWidget {
  const RemoteAccessSettingsPage({super.key, required this.sources});
  final SourceManager sources;
  @override
  State<RemoteAccessSettingsPage> createState() =>
      _RemoteAccessSettingsPageState();
}

class _RemoteAccessSettingsPageState extends State<RemoteAccessSettingsPage> {
  final _pairing = TextEditingController();
  bool _busy = false, _loaded = false;
  String? _message;
  bool _error = false;

  RemoteNetwork get _network => widget.sources.remoteNetwork;

  @override
  void initState() {
    super.initState();
    _run(() async {
      await widget.sources.load();
      await widget.sources.remoteSettings;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _pairing.dispose();
    super.dispose();
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
    } catch (error) {
      if (mounted) {
        _message = error is FormatException ? error.message : '$error';
        _error = true;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    _pairing.clear();
    final text = await pushSettingsPage<String>(
      context,
      title: '导入远程配置',
      children: (c) => [
        SettingsSection(
          footer: '粘贴 Relay 导出的 App 配置，导入后立即生效。',
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: ShadInput(
                key: const ValueKey('remote-pairing'),
                controller: _pairing,
                maxLines: 8,
                placeholder: const Text('App 配置 JSON'),
                autocorrect: false,
                enableSuggestions: false,
              ),
            ),
          ],
        ),
      ],
      trailing: (c) => [
        ShadButton(
          key: const ValueKey('remote-import-confirm'),
          onPressed: () => Navigator.pop(c, _pairing.text),
          child: const Text('导入'),
        ),
      ],
    );
    if (text == null || !mounted) return;
    await _run(() => widget.sources.importRemotePairing(text), done: '已导入并生效。');
    _pairing.clear();
  }

  Future<void> _clear() async {
    final confirmed = await showSettingsConfirm(
      context,
      title: '清空远程配置？',
      message: '清空本机的远程配置与凭据，重新导入后可恢复远程访问。',
      confirmLabel: '清空',
      cancelLabel: '取消',
      destructive: true,
    );
    if (confirmed && mounted) {
      await _run(widget.sources.clearRemoteNetwork, done: '已清空远程配置。');
    }
  }

  List<Widget> _connection() {
    final network = _network;
    final out = network.outbound;
    if (out == null) {
      return [
        const SettingsRow(
          key: ValueKey('remote-unconfigured'),
          title: '尚未导入',
          description: '点击上方“导入”添加远程配置。',
        ),
      ];
    }
    final tls = out['tls'] as Map? ?? const {};
    return [
      SettingsRow(
        key: const ValueKey('remote-server'),
        title: '服务器',
        control: Text('${out['server']}:${out['server_port']}'),
      ),
      SettingsRow(title: '服务器名称', control: Text('${tls['server_name'] ?? ''}')),
      SettingsRow(title: '认证凭据', control: const Text('已保存在系统安全存储')),
    ];
  }

  List<Widget> _proxies() {
    final sources = widget.sources.configs;
    return [
      for (final proxy in _network.proxies)
        SettingsRow(
          key: ValueKey('remote-proxy-${proxy.name}'),
          title: proxy.name,
          description: () {
            final users = sources
                .where((s) => s.remote?.proxy == proxy.name)
                .map((s) => s.titleName)
                .toList();
            return users.isEmpty ? '未被来源使用' : '来源：${users.join('、')}';
          }(),
          control: Text('端口 ${proxy.remotePort}'),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final network = _network;
    final missing = widget.sources.configs
        .where(
          (s) => s.remote != null && network.proxy(s.remote!.proxy) == null,
        )
        .toList();
    return AppPage(
      title: const Text('远程访问'),
      body: SettingsListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: ShadButton(
                    key: const ValueKey('remote-import'),
                    onPressed: _busy || !_loaded ? null : _import,
                    child: const Text('导入'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ShadButton.outline(
                    key: const ValueKey('remote-clear'),
                    onPressed: _busy || !_network.configured ? null : _clear,
                    child: const Text('清空'),
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
          if (_loaded) ...[
            SettingsSection(
              title: '中继服务器',
              footer: '整个 App 共用此连接；认证凭据保存在系统安全存储。',
              children: _connection(),
            ),
            if (network.proxies.isNotEmpty)
              SettingsSection(
                title: '可用服务',
                footer: '由 Home 注册在 Relay 上。来源在“编辑来源 → 家庭远程访问”中选择其中一个。',
                children: _proxies(),
              ),
            if (network.configured && missing.isNotEmpty)
              SettingsSection(
                title: '需要处理',
                children: [
                  for (final source in missing)
                    SettingsRow(
                      title: source.titleName,
                      description:
                          '使用的 proxy「${source.remote!.proxy}」不在当前配置中，远程连接不可用。',
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
