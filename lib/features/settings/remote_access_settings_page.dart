import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/remote_access/remote_access_service.dart';
import '../../data/sources/source_manager.dart';
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
          title: proxy.name,
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
