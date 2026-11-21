import 'package:flutter/material.dart';

import 'platform_login_page.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/remote_access/remote_access_service.dart';
import '../../capabilities/sources/source_manager.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/forms/form_actions.dart';
import '../../ui/components/settings/settings_adaptive.dart';
import '../../ui/components/settings/settings_section.dart';
import '../../ui/components/feedback/app_feedback.dart';
import '../../l10n/l10n.dart';

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
  RemoteAccessService? _service;

  /// What is running (shown in the action bar), or null when idle.
  String? _busyLabel;
  bool get _busy => _busyLabel != null;

  /// The last failure, shown in the action bar until the next action.
  String? _error;

  RemoteNetwork get _network => widget.sources.remoteNetwork;

  @override
  void initState() {
    super.initState();
    _run(appStrings.loading, () async {
      await widget.sources.load();
      _service = await widget.sources.remoteSettings;
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
    final l = AppLocalizations.of(context);
    final text = await pushSettingsPage<String>(
      context,
      title: l.remoteImportTitle,
      children: (c) => [
        SettingsSection(
          footer: l.remoteImportFooter,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: ShadInput(
                key: const ValueKey('remote-pairing'),
                controller: _pairing,
                maxLines: 8,
                placeholder: Text(l.remoteImportPlaceholder),
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
          label: l.remoteImport,
          onPressed: () => Navigator.pop(c, _pairing.text),
        ),
      ],
    );
    if (text == null || !mounted) return;
    await _run(
      l.remoteImporting,
      () => widget.sources.importRemotePairing(text),
      done: l.remoteImported,
    );
    _pairing.clear();
  }

  Future<void> _register() async {
    final l = AppLocalizations.of(context);
    final email = TextEditingController(text: _service?.account.email);
    try {
      final address = await pushSettingsPage<String>(
        context,
        title: l.remotePlatformRegister,
        children: (_) => [
          SettingsSection(
            footer: l.remotePlatformRegisterHint,
            children: [
              ShadInput(
                key: const ValueKey('relay-registration-email'),
                controller: email,
                placeholder: Text(l.remotePlatformEmail),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
              ),
            ],
          ),
        ],
        trailing: (c) => [
          PageSubmitButton(
            key: const ValueKey('relay-registration-submit'),
            label: l.remotePlatformSendRegistration,
            onPressed: () {
              final value = email.text.trim();
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                showAppToast(
                  c,
                  l.remotePlatformInvalidEmail,
                  kind: FeedbackKind.error,
                );
                return;
              }
              Navigator.pop(c, value);
            },
          ),
        ],
      );
      if (address == null || !mounted) return;
      await _run(
        l.loading,
        () => _service!.account.requestRegistration(address),
        done: l.remotePlatformRegistrationSent,
      );
    } finally {
      // Route exit animations may still retain the input briefly.
      WidgetsBinding.instance.addPostFrameCallback((_) => email.dispose());
    }
  }

  Future<void> _login() async {
    if (_busy || _service == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'PlatformLoginPage'),
        builder: (_) => PlatformLoginPage(
          email: _service!.account.email,
          login: _service!.loginPlatform,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  String _nodeLabel(Map<String, dynamic> node, AppLocalizations l) {
    final id = node['nodeId'] as String;
    final name = node['name'] as String;
    final results = _service!.nodeLatencyMs;
    if (!results.containsKey(id)) return name;
    return '$name · ${results[id] == null ? l.remoteNodeUnreachable : l.remoteNodeLatency(results[id]!)}';
  }

  Widget _platform(AppLocalizations l) {
    final service = _service!;
    final profile = service.platformProfile;
    final active = service.activeNode;
    return SettingsSection(
      title: l.remotePlatformTitle,
      footer: l.remotePlatformHint,
      children: [
        SettingsRow(
          title: service.usePlatform
              ? l.remotePlatformActive
              : l.remoteCustomActive,
          description: service.account.email ?? l.remotePlatformHint,
        ),
        if (service.account.signedIn) ...[
          if (profile == null) SettingsRow(title: l.remotePlatformNotLoaded),
          if (profile != null && !profile.valid)
            SettingsRow(title: l.remotePlatformExpired),
          if (profile != null && profile.nodes.isEmpty)
            SettingsRow(title: l.remotePlatformEmpty),
          if (profile != null && profile.proxies.isEmpty)
            SettingsRow(title: l.remotePlatformNoServices),
          if (active != null)
            SettingsRow(
              key: const ValueKey('relay-platform-node'),
              title: l.remotePlatformNode,
              description:
                  '${_nodeLabel(active, l)} · ${service.followsConnector ? l.remotePlatformAutomatic : l.remotePlatformNodeUnavailable}',
            ),
        ],
        if (service.platformError != null)
          SettingsRow(
            title: l.remotePlatformRequestFailed(service.platformError!),
          ),
        if (service.nodeLatencyMs.isNotEmpty)
          SettingsRow(title: l.remoteNodeTestHint),
        FormActions([
          if (profile?.nodes.isNotEmpty == true)
            FormAction(
              l.remoteNodeTest,
              _busy
                  ? null
                  : () => _run(l.loading, () => service.testPlatformNodes()),
              key: const ValueKey('relay-platform-test'),
            ),
          if (service.account.signedIn)
            FormAction.destructive(
              l.remotePlatformLogout,
              _busy ? null : () => _run(l.loading, service.logoutPlatform),
            ),
          if (service.account.signedIn)
            FormAction(
              l.refresh,
              _busy ? null : () => _run(l.loading, service.refreshPlatform),
              key: const ValueKey('relay-platform-refresh'),
            ),
          FormAction(
            l.remotePlatformRestore,
            _busy
                ? null
                : () => _run(l.loading, () => service.selectPlatform()),
            key: const ValueKey('relay-platform-restore'),
          ),
          if (!service.account.signedIn)
            FormAction.primary(
              l.remotePlatformLogin,
              _busy ? null : _login,
              key: const ValueKey('relay-platform-login'),
            ),
          if (!service.account.signedIn)
            FormAction(
              l.remotePlatformRegister,
              _busy ? null : _register,
              key: const ValueKey('relay-platform-register'),
            ),
        ]),
      ],
    );
  }

  Future<void> _clear() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showSettingsConfirm(
      context,
      title: l.remoteClearConfirmTitle,
      message: l.remoteClearConfirmMessage,
      confirmLabel: l.remoteClear,
      cancelLabel: l.cancel,
      destructive: true,
    );
    if (confirmed && mounted) {
      await _run(
        l.remoteClearing,
        widget.sources.clearRemoteNetwork,
        done: l.remoteCleared,
      );
    }
  }

  List<Widget> _connection(AppLocalizations l) {
    final network = _network;
    final out = network.outbound;
    if (out == null) {
      return [
        SettingsRow(
          key: const ValueKey('remote-unconfigured'),
          title: l.remoteNotImported,
          description: l.remoteNotImportedHint,
        ),
      ];
    }
    final tls = out['tls'] as Map? ?? const {};
    return [
      SettingsRow(
        key: const ValueKey('remote-server'),
        title: l.server,
        control: Text('${out['server']}:${out['server_port']}'),
      ),
      SettingsRow(
        title: l.remoteServerName,
        control: Text('${tls['server_name'] ?? ''}'),
      ),
      SettingsRow(
        title: l.remoteCredentials,
        control: Text(l.remoteCredentialsSecure),
      ),
    ];
  }

  List<Widget> _proxies(AppLocalizations l) {
    final sources = widget.sources.configs;
    return [
      for (final proxy in _network.proxies)
        SettingsRow(
          key: ValueKey('remote-proxy-${proxy.name}'),
          title: proxy.displayName,
          description: () {
            final users = sources
                .where((s) => s.remote?.proxy == proxy.name)
                .map((s) => s.titleName)
                .toList();
            return users.isEmpty
                ? l.remoteProxyUnused
                : l.remoteProxyUsedBy(users.join(l.listSeparator));
          }(),
          control: Text(l.remoteProxyPort(proxy.remotePort)),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final network = _network;
    final missing = widget.sources.configs
        .where(
          (s) => s.remote != null && network.proxy(s.remote!.proxy) == null,
        )
        .toList();
    return AppPage(
      pageContext: const PageContextData(pageType: 'remote_access_settings'),
      title: Text(l.remoteAccess),
      body: SettingsListView(
        children: [
          if (_loaded) ...[
            _platform(l),
            SettingsSection(
              title: l.remoteRelayServer,
              footer: l.remoteRelayFooter,
              children: _connection(l),
            ),
            if (network.proxies.isNotEmpty)
              SettingsSection(
                title: l.remoteAvailableServices,
                footer: l.remoteAvailableServicesFooter,
                children: _proxies(l),
              ),
            if (network.configured && missing.isNotEmpty)
              SettingsSection(
                title: l.remoteNeedsAttention,
                children: [
                  for (final source in missing)
                    SettingsRow(
                      title: source.titleName,
                      description: l.remoteSourceProxyMissing(
                        source.remote!.proxy,
                      ),
                    ),
                ],
              ),
          ],
          // Clear asks for confirmation first (see _clear).
          FormActions(
            status: _busy
                ? FormStatus.busy(_busyLabel!)
                : _error == null
                ? FormStatus.idle
                : FormStatus.error(_error!),
            [
              FormAction.destructive(
                l.remoteClear,
                _busy || !_network.configured ? null : _clear,
                key: const ValueKey('remote-clear'),
              ),
              FormAction.primary(
                l.remoteImport,
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
