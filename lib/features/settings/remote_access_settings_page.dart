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
  final _expandedDetails = <_RemoteMode>{};
  RemoteAccessService? _service;

  /// What is running (shown in the action bar), or null when idle.
  String? _busyLabel;
  bool get _busy => _busyLabel != null;

  /// The last failure, shown in the action bar until the next action.
  String? _error;

  RemoteNetwork get _network => widget.sources.remoteNetwork;

  /// The tab on screen. Looking at a tab never changes which configuration
  /// is in use; only the enable / import actions switch it.
  _RemoteMode _tab = _RemoteMode.cloud;

  _RemoteMode get _activeMode =>
      _service?.usePlatform == false ? _RemoteMode.local : _RemoteMode.cloud;

  @override
  void initState() {
    super.initState();
    _run(appStrings.loading, () async {
      await widget.sources.load();
      _service = await widget.sources.remoteSettings;
      _tab = _activeMode;
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
    final service = _service;
    if (service != null &&
        service.usePlatform &&
        service.platformNetwork.configured) {
      final confirmed = await showSettingsConfirm(
        context,
        title: l.remoteImportReplaceCloudTitle,
        message: l.remoteImportReplaceCloudMessage,
        confirmLabel: l.remoteImport,
        cancelLabel: l.cancel,
      );
      if (!confirmed || !mounted) return;
    }
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
        FormActions([
          FormAction.primary(
            l.remoteImport,
            () => Navigator.pop(c, _pairing.text),
            key: const ValueKey('remote-import-confirm'),
          ),
        ]),
      ],
    );
    if (text == null || !mounted) return;
    await _run(
      l.remoteImporting,
      () => widget.sources.importRemotePairing(text),
      done: l.remoteImported,
    );
    _pairing.clear();
    if (mounted) setState(() => _tab = _activeMode);
  }

  Future<void> _register() async {
    final l = AppLocalizations.of(context);
    final email = TextEditingController(text: _service?.account.email);
    try {
      final address = await pushSettingsPage<String>(
        context,
        title: l.remotePlatformRegister,
        children: (c) => [
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
          FormActions([
            FormAction.primary(l.remotePlatformSendRegistration, () {
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
            }, key: const ValueKey('relay-registration-submit')),
          ]),
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

  /// Switches to [mode] after confirming that the other side stops working.
  Future<void> _enable(_RemoteMode mode) async {
    final l = AppLocalizations.of(context);
    final cloud = mode == _RemoteMode.cloud;
    final confirmed = await showSettingsConfirm(
      context,
      title: cloud
          ? l.remoteEnableCloudConfirmTitle
          : l.remoteEnableLocalConfirmTitle,
      message: cloud
          ? l.remoteEnableCloudConfirmMessage
          : l.remoteEnableLocalConfirmMessage,
      confirmLabel: l.remoteSwitch,
      cancelLabel: l.cancel,
    );
    if (!confirmed || !mounted) return;
    final service = _service!;
    await _run(
      l.loading,
      () => cloud ? service.selectPlatform() : service.selectCustom(),
      done: l.remoteSwitched,
    );
  }

  /// Whether the tab's configuration is in use, and the way to switch to it.
  Widget _modeStatus(AppLocalizations l, _RemoteMode mode) {
    final cloud = mode == _RemoteMode.cloud;
    final active = _activeMode == mode;
    final canEnable = !active && (cloud || _service!.customNetwork.configured);
    final String? hint;
    if (active) {
      hint = null;
    } else if (cloud) {
      hint = l.remoteCloudInactiveHint;
    } else if (canEnable) {
      hint = l.remoteLocalInactiveHint;
    } else {
      hint = l.remoteLocalEmptyHint;
    }
    return SettingsSection(
      children: [
        SettingsRow(
          key: ValueKey('remote-mode-${mode.name}'),
          title: active ? l.remoteModeActive : l.remoteModeInactive,
          description: hint,
          control: Icon(
            active ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).disabledColor,
          ),
        ),
        if (canEnable)
          FormActions([
            FormAction.primary(
              cloud ? l.remoteEnableCloud : l.remoteEnableLocal,
              _busy ? null : () => _enable(mode),
              key: ValueKey('remote-enable-${mode.name}'),
            ),
          ]),
      ],
    );
  }

  Widget _platform(AppLocalizations l) {
    final service = _service!;
    final profile = service.platformProfile;
    final active = service.activeNode;
    return SettingsSection(
      footer: service.account.signedIn ? null : l.remotePlatformHint,
      children: [
        if (service.account.signedIn)
          SettingsMenuRow(
            title: service.account.email ?? l.remotePlatformEmail,
            enabled: !_busy,
            items: [
              SettingsMenuItem(
                l.remotePlatformLogout,
                () => _run(l.loading, service.logoutPlatform),
                destructive: true,
              ),
            ],
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
        FormActions([
          if (service.account.signedIn)
            FormAction(
              l.refresh,
              _busy ? null : () => _run(l.loading, service.refreshPlatform),
              key: const ValueKey('relay-platform-refresh'),
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
      message: _activeMode == _RemoteMode.local
          ? l.remoteClearActiveMessage
          : l.remoteClearConfirmMessage,
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
      if (mounted) setState(() {});
    }
  }

  List<Widget> _connection(AppLocalizations l, RemoteNetwork network) {
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

  List<Widget> _proxies(AppLocalizations l, RemoteNetwork network) {
    final sources = widget.sources.configs;
    return [
      for (final proxy in network.proxies)
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

  /// Keep services visible; reveal technical and destructive controls on demand.
  List<Widget> _networkSections(AppLocalizations l, RemoteNetwork network) {
    if (!network.configured) return [];
    final expanded = _expandedDetails.contains(_tab);
    final service = _service!;
    final cloud = _tab == _RemoteMode.cloud;
    return [
      if (network.proxies.isNotEmpty)
        SettingsSection(
          title: l.remoteAvailableServices,
          footer: l.remoteAvailableServicesFooter,
          children: _proxies(l, network),
        ),
      SettingsSection(
        footer: expanded ? l.remoteRelayFooter : null,
        children: [
          SettingsRow(
            key: const ValueKey('remote-connection-details'),
            title: l.remoteConnectionDetails,
            control: Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
            ),
            onTap: () => setState(() {
              if (expanded) {
                _expandedDetails.remove(_tab);
              } else {
                _expandedDetails.add(_tab);
              }
            }),
          ),
          if (expanded) ...[
            ..._connection(l, network),
            if (cloud && service.platformProfile?.nodes.isNotEmpty == true) ...[
              SettingsRow(title: l.remoteNodeTestHint),
              FormActions([
                FormAction(
                  l.remoteNodeTest,
                  _busy
                      ? null
                      : () => _run(l.loading, service.testPlatformNodes),
                  key: const ValueKey('relay-platform-test'),
                ),
              ]),
            ],
            if (!cloud)
              FormActions([
                FormAction.destructive(
                  l.remoteClear,
                  _busy ? null : _clear,
                  key: const ValueKey('remote-clear'),
                ),
              ]),
          ],
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final network = _network;
    final service = _service;
    final local = _tab == _RemoteMode.local;
    final missing = widget.sources.configs
        .where(
          (s) => s.remote != null && network.proxy(s.remote!.proxy) == null,
        )
        .toList();
    final status = _busy
        ? FormStatus.busy(_busyLabel!)
        : _error == null
        ? FormStatus.idle
        : FormStatus.error(_error!);
    return AppPage(
      pageContext: const PageContextData(pageType: 'remote_access_settings'),
      title: Text(l.remoteAccess),
      body: SettingsListView(
        children: [
          if (_loaded && service != null) ...[
            ShadTabs<_RemoteMode>(
              key: const ValueKey('remote-mode-tabs'),
              value: _tab,
              onChanged: (mode) => setState(() => _tab = mode),
              tabs: [
                for (final mode in _RemoteMode.values)
                  ShadTab(
                    key: ValueKey('remote-tab-${mode.name}'),
                    value: mode,
                    trailing: _activeMode == mode
                        ? const Icon(Icons.check, size: 14)
                        : null,
                    child: Text(
                      mode == _RemoteMode.cloud
                          ? l.remoteTabCloud
                          : l.remoteTabLocal,
                    ),
                  ),
              ],
            ),
            if (!local) ...[
              _modeStatus(l, _RemoteMode.cloud),
              _platform(l),
              if (service.account.signedIn)
                ..._networkSections(l, service.platformNetwork),
            ] else ...[
              _modeStatus(l, _RemoteMode.local),
              if (!service.customNetwork.configured)
                SettingsSection(
                  children: _connection(l, service.customNetwork),
                ),
              ..._networkSections(l, service.customNetwork),
            ],
            if (_tab == _activeMode && network.configured && missing.isNotEmpty)
              SettingsSection(
                title: l.remoteNeedsAttention,
                children: [
                  for (final source in missing)
                    SettingsRow(
                      title: source.titleName,
                      description: l.remoteSourceProxyMissing,
                    ),
                ],
              ),
          ],
          // Clear asks for confirmation first (see _clear); importing over
          // the cloud configuration asks too (see _import).
          FormActions(status: status, [
            if (local) ...[
              FormAction.primary(
                l.remoteImport,
                _busy || !_loaded ? null : _import,
                key: const ValueKey('remote-import'),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}

enum _RemoteMode { cloud, local }
