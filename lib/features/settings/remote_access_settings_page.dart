import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/remote_access/remote_access_service.dart';
import '../../data/sources/source_manager.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/forms/form_actions.dart';
import '../../ui/components/settings/settings_adaptive.dart';
import '../../ui/components/settings/settings_section.dart';
import '../../ui/components/feedback/app_feedback.dart';

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
  bool _loaded = false;

  /// What is running (shown in the action bar), or null when idle.
  String? _busyLabel;
  bool get _busy => _busyLabel != null;

  /// The last failure, shown in the action bar until the next action.
  String? _error;

  RemoteNetwork get _network => widget.sources.remoteNetwork;

  @override
  void initState() {
    super.initState();
    _run('正在加载…', () async {
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

  Future<void> _run(
    String busyLabel,
    Future<void> Function() action, {
    String? done,
  }) async {
    if (_busy) return;
    setState(() {
      _busyLabel = busyLabel;
      _error = null;
    });
    try {
      await action();
      // Success is a toast; the action bar keeps only failures.
      if (mounted && done != null) {
        showAppToast(context, done, kind: FeedbackKind.success);
      }
    } catch (error) {
      if (mounted) {
        _error = error is FormatException ? error.message : '$error';
      }
    } finally {
      if (mounted) setState(() => _busyLabel = null);
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
        PageSubmitButton(
          key: const ValueKey('remote-import-confirm'),
          label: '导入',
          onPressed: () => Navigator.pop(c, _pairing.text),
        ),
      ],
    );
    if (text == null || !mounted) return;
    await _run(
      '正在导入…',
      () => widget.sources.importRemotePairing(text),
      done: '已导入并生效。',
    );
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
      await _run('正在清空…', widget.sources.clearRemoteNetwork, done: '已清空远程配置。');
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
      pageContext: const PageContextData(pageType: 'remote_access_settings'),
      title: const Text('远程访问'),
      body: SettingsListView(
        children: [
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
          // 清空 asks for confirmation first (see _clear).
          FormActions(
            status: _busy
                ? FormStatus.busy(_busyLabel!)
                : _error == null
                ? FormStatus.idle
                : FormStatus.error(_error!),
            [
              FormAction.destructive(
                '清空',
                _busy || !_network.configured ? null : _clear,
                key: const ValueKey('remote-clear'),
              ),
              FormAction.primary(
                '导入',
                _busy || !_loaded ? null : _import,
                key: const ValueKey('remote-import'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
