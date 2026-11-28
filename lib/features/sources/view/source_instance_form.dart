import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'widgets/source_kind_icon.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/adaptive/app_page.dart';
import '../../../ui/components/forms/form_actions.dart';
import '../../../ui/components/forms/secret_input.dart';
import '../../../ui/components/forms/settings_text_input.dart';
import '../../../ui/components/settings/settings_section.dart';
import '../../../ui/tokens/app_metrics.dart';
import '../../../ui/tokens/app_spacing.dart';
import '../../../ui/icons/app_icons.dart';

import '../../../data/sources/source_config.dart';
import '../../../data/remote_access/remote_config.dart';
import '../../../data/sources/dlna_source.dart';
import '../../../capabilities/sources/source_manager.dart';
import '../../../data/sources/source_sign_in.dart';
import '../../../ui/components/feedback/app_feedback.dart';
import '../controller/source_form_controller.dart';

class SourceInstanceForm extends StatefulWidget {
  const SourceInstanceForm({
    super.key,
    required this.manager,
    this.initial,
    this.initialKind,
    this.signIn,
    this.openBrowser,
    this.chooseDirectory,
    this.discoverDlna,
    this.onAddToHome,
  });

  /// Saves the confirmed scope and schedules indexing before dismissing.
  final Future<bool> Function(String id)? onAddToHome;
  final SourceConfig? initial;

  /// Preselected type for a new instance (Settings → plugin → add instance).
  final SourceKind? initialKind;
  final SourceManager manager;
  final SourceSignIn? signIn;
  final Future<bool> Function(Uri)? openBrowser;
  final Future<String?> Function()? chooseDirectory;
  final Future<List<DlnaDevice>> Function()? discoverDlna;
  @override
  State<SourceInstanceForm> createState() => _SourceInstanceFormState();
}

class _SourceInstanceFormState extends State<SourceInstanceForm> {
  AppLocalizations get l => AppLocalizations.of(context);
  late final SourceFormController _c = SourceFormController(
    manager: widget.manager,
    initial: widget.initial,
    initialKind: widget.initialKind,
    signIn: widget.signIn,
    openBrowser: widget.openBrowser,
    chooseDirectory: widget.chooseDirectory,
    discoverDlna: widget.discoverDlna,
    onFailure: (message) {
      if (!mounted) return;
      if (widget.onAddToHome != null) {
        setState(() => _failure = message);
      } else {
        showAppToast(context, message, kind: FeedbackKind.error);
      }
    },
  );
  bool get _managed => widget.initial?.remote?.accountId != null;
  final _addressFocus = FocusNode();
  bool _submitting = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    if (widget.onAddToHome != null && widget.initialKind == SourceKind.local) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_c.pickDirectory());
      });
    }
    _addressFocus.addListener(() {
      if (!_addressFocus.hasFocus && mounted) _c.normalizeAddress();
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _addressFocus.dispose();
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      if (!await _c.save() || !mounted) return;
      if (widget.onAddToHome != null && !await widget.onAddToHome!(_c.id)) {
        return;
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _kindName(SourceKind kind) =>
      kind == SourceKind.local ? l.localFolder : kind.label;

  /// A labelled text field as one grouped-list row: label beside a
  /// borderless field, or above a boxed one for multi-line input.
  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    String? help,
    bool password = false,
    bool number = false,
    int maxLines = 1,
    Key? key,
  }) {
    // Label above a bordered input, like the 模型 settings form.
    final Widget input = password
        ? SecretInput(
            key: key ?? ValueKey(label),
            controller: c,
            enabled: !_c.busy,
            placeholder: hint,
          )
        : SettingsTextInput(
            key: key ?? ValueKey(label),
            controller: c,
            focusNode: identical(c, _c.address) ? _addressFocus : null,
            enabled: !_c.busy,
            maxLines: maxLines,
            keyboardType: number ? TextInputType.number : TextInputType.text,
            example: hint,
          );
    return SettingsRow(
      title: label,
      description: help,
      stacked: true,
      control: input,
    );
  }

  Widget _switchRow(
    String title,
    bool value,
    ValueChanged<bool> onChanged, {
    required Key key,
  }) => SettingsRow(
    title: title,
    onTap: _c.busy ? null : () => onChanged(!value),
    control: ShadSwitch(
      key: key,
      value: value,
      enabled: !_c.busy,
      onChanged: _c.busy ? null : onChanged,
    ),
  );

  /// A row that reveals its section's less common fields in place.
  Widget _advancedToggle() {
    final open = _c.advanced;
    return SettingsRow(
      key: ValueKey('advanced-${_c.kind.name}'),
      title: l.advanced,
      control: Icon(open ? AppIcons.collapse : AppIcons.expand, size: 18),
      onTap: () {
        if (!open) FocusScope.of(context).unfocus();
        _c.toggleAdvanced();
      },
    );
  }

  /// A choosable item (device, server) with a check on the current one.
  Widget _pickRow(String title, bool selected, VoidCallback onTap) =>
      SettingsRow(
        title: title,
        onTap: _c.busy ? null : onTap,
        control: selected
            ? Icon(
                AppIcons.check,
                size: 20,
                color: ShadTheme.of(context).colorScheme.primary,
              )
            : null,
      );

  /// What a blank name shows: the discovered server's own name, or
  /// "type · address" as the source list displays it.
  String get _nameHint {
    final found = _c.server?.name ?? _c.device?.name;
    if (found != null && found.isNotEmpty) return found;
    final address = _c.address.text.trim();
    return '${_kindName(_c.kind)} · ${address.isEmpty ? _addressHint : address}';
  }

  String get _addressHint => switch (_c.kind) {
    SourceKind.smb || SourceKind.ftp || SourceKind.sftp => '192.168.1.10',
    SourceKind.s3 => 's3.amazonaws.com',
    _ => l.addressHint,
  };

  String? get _usernameHelp => switch (_c.kind) {
    SourceKind.smb => l.guestHelp,
    SourceKind.webdav || SourceKind.ftp => l.anonymousHelp,
    SourceKind.s3 => l.s3AnonymousHelp,
    _ => null,
  };

  String get _pathHint => switch (_c.kind) {
    SourceKind.smb => l.smbPathHint,
    SourceKind.s3 => l.s3PathHint,
    SourceKind.webdav || SourceKind.ftp || SourceKind.sftp => l.remotePathHint,
    _ => l.serverPathHint,
  };

  Widget _pathField() => _field(_c.path, l.optionalPath, hint: _pathHint);

  List<Widget> _localSections() => [
    SettingsSection(
      footer: Platform.isAndroid || Platform.isIOS ? l.folderAccessHelp : null,
      children: [
        SettingsRow(
          title: l.chooseFolder,
          icon: AppIcons.openFolder,
          accent: true,
          description: _c.address.text.isEmpty ? null : _c.address.text,
          onTap: _c.busy ? null : _c.pickDirectory,
        ),
      ],
    ),
  ];

  List<Widget> _networkSections() => [
    if (_c.kind == SourceKind.webdav)
      SettingsSection(
        footer: _c.preset?.help,
        children: [
          SettingsChoiceRow<String>(
            title: l.cloudPreset,
            value: _c.preset?.name ?? '',
            enabled: !_c.busy && _c.initial == null,
            options: {
              '': l.cloudCustom,
              for (final p in SourcePreset.values) p.name: p.label,
            },
            onChanged: (value) => _c.changePreset(SourcePreset.byId(value)),
          ),
        ],
      ),
    SettingsSection(
      children: [
        _field(_c.address, l.address, hint: _addressHint),
        _field(
          _c.username,
          _c.kind == SourceKind.s3 ? l.s3AccessKey : l.username,
          help: _usernameHelp,
        ),
        _field(
          _c.password,
          _c.kind == SourceKind.s3 ? l.s3SecretKey : l.password,
          password: true,
          help: _c.initial != null ? l.keepCredentials : null,
        ),
        if (_c.kind == SourceKind.s3) ...[
          _field(_c.domain, l.s3Region, hint: 'us-east-1'),
          _pathField(),
        ],
      ],
    ),
    SettingsSection(
      children: [
        _advancedToggle(),
        if (_c.advanced) ...[
          if (_c.kind == SourceKind.smb)
            SettingsRow(title: l.port, control: const Text('445'))
          else if (!_c.kind.isHttp)
            _field(
              _c.port,
              l.port,
              number: true,
              hint: '${_c.kind.standardPort}',
            )
          else ...[
            _switchRow(
              'HTTPS',
              _c.https,
              _c.setHttps,
              key: const ValueKey('https-switch'),
            ),
            _field(
              _c.port,
              l.port,
              number: true,
              hint: _c.https ? '443' : '${_c.kind.defaultPort ?? 80}',
            ),
          ],
          if (_c.kind != SourceKind.s3) _pathField(),
          if (_c.kind == SourceKind.smb) _field(_c.domain, l.optionalDomain),
        ],
      ],
    ),
  ];

  List<Widget> _cloudSections() => [
    SettingsSection(
      footer: l.cloudSignInHelp,
      children: [
        SettingsRow(
          title: l.cloudSignIn,
          icon: AppIcons.signIn,
          onTap: _c.busy ? null : _c.loginCloud,
        ),
      ],
    ),
    if (_c.cloudConnected)
      SettingsSection(
        footer: l.cloudRootHelp,
        children: [
          SettingsRow(
            title: l.cloudRoot,
            description: _c.cloudFolderName,
            onTap: _c.busy ? null : () => _c.browseCloudFolder(),
          ),
          if (_c.kind == SourceKind.baidu)
            SettingsRow(
              title: l.baiduAllFiles,
              icon: AppIcons.folder,
              onTap: _c.busy ? null : _c.selectAllCloudFiles,
            ),
          if (_c.cloudCanBack)
            SettingsRow(
              title: l.backToParent,
              icon: AppIcons.parent,
              onTap: _c.busy ? null : () => _c.browseCloudFolder(null, true),
            ),
          for (final folder in _c.cloudFolders)
            SettingsRow(
              title: folder.name,
              icon: AppIcons.folder,
              onTap: _c.busy ? null : () => _c.browseCloudFolder(folder),
            ),
        ],
      ),
    if (_c.initial != null)
      SettingsSection(
        footer: l.cloudDisconnectHelp,
        children: [
          SettingsRow(
            title: l.cloudDisconnect,
            icon: AppIcons.delete,
            onTap: _c.busy
                ? null
                : () async {
                    if (await _c.disconnectCloud() && mounted) {
                      Navigator.pop(context, true);
                    }
                  },
          ),
        ],
      ),
  ];

  List<Widget> _dlnaSections() => [
    SettingsSection(
      footer: _c.devices != null && _c.devices!.isEmpty
          ? l.dlnaNoDevices
          : null,
      children: [
        SettingsRow(
          title: _c.searching ? l.dlnaSearching : l.dlnaSearch,
          icon: AppIcons.search,
          accent: true,
          onTap: _c.busy || _c.searching ? null : _c.searchDlna,
        ),
        for (final device in _c.devices ?? const <DlnaDevice>[])
          _pickRow(
            device.name,
            device.location == _c.device?.location,
            () => _c.selectDevice(device),
          ),
      ],
    ),
    SettingsSection(
      footer: l.dlnaAddressHelp,
      children: [
        _field(
          _c.address,
          l.dlnaAddress,
          hint: 'http://192.168.1.10:8200/rootDesc.xml',
        ),
      ],
    ),
  ];

  List<Widget> _plexSections() => [
    SettingsSection(
      footer: l.plexBrowserHelp,
      children: [
        if (_c.initial != null && _c.servers.isEmpty)
          SettingsRow(
            icon: AppIcons.server,
            title: _c.initial!.titleName,
            description: Uri.parse(_c.initial!.address).host,
          ),
        SettingsRow(
          title: _c.authorizing
              ? l.waitingPlex
              : _c.initial == null
              ? l.signInPlex
              : l.signInPlexAgain,
          icon: AppIcons.signIn,
          accent: true,
          onTap: _c.busy ? null : _c.loginPlex,
        ),
        if (_c.authorizing && _c.loginUri != null)
          SettingsRow(
            title: l.reopenSignIn,
            accent: true,
            onTap: _c.reopenSignIn,
          ),
      ],
    ),
    if (_c.servers.isNotEmpty)
      SettingsSection(
        title: l.server,
        children: [
          for (final server in _c.servers)
            _pickRow(
              server.name,
              server.id == _c.server?.id,
              () => _c.selectServer(server),
            ),
        ],
      ),
    SettingsSection(
      children: [
        _advancedToggle(),
        if (_c.advanced) ...[
          _switchRow(
            l.manualServer,
            _c.manualPlex,
            _c.setManualPlex,
            key: const ValueKey('plex-manual'),
          ),
          if (_c.manualPlex) ...[
            _field(
              _c.address,
              l.serverAddress,
              hint: 'http://192.168.1.10:32400',
              help: l.portInAddress,
            ),
            _field(
              _c.manualToken,
              l.accessToken,
              password: true,
              help: _c.initial == null ? null : l.keepCredentials,
            ),
          ],
        ],
      ],
    ),
  ];

  Widget _remoteSection() => SettingsSection(
    children: [
      _switchRow(
        l.remoteHomeAccess,
        _c.remoteEnabled,
        _c.setRemoteEnabled,
        key: const ValueKey('remote-switch'),
      ),
      if (_c.remoteEnabled) ...[
        if (_remoteProxyOptions.isEmpty)
          SettingsRow(
            key: const ValueKey('remote-no-proxies'),
            title: l.remoteNoProxies,
          )
        else
          SettingsChoiceRow<String>(
            key: const ValueKey('remote-proxy'),
            title: l.remoteProxy,
            value: _c.remoteProxy ?? '',
            enabled: !_c.busy,
            options: {
              if (_c.remoteProxy == null) '': '—',
              ..._remoteProxyOptions,
            },
            onChanged: (v) => _c.setRemoteProxy(v.isEmpty ? null : v),
          ),
        SettingsChoiceRow<RemoteConnectionMode>(
          title: l.remoteConnectionMode,
          value: _c.connectionMode,
          enabled: !_c.busy && _c.kind != SourceKind.smb,
          options: {
            for (final mode
                in _c.kind == SourceKind.smb
                    ? [RemoteConnectionMode.remoteOnly]
                    : RemoteConnectionMode.values)
              mode: _modeLabel(mode),
          },
          onChanged: _c.setConnectionMode,
        ),
        if (_c.connectionMode != RemoteConnectionMode.remoteOnly) ...[
          _field(
            _c.localEndpoint,
            l.remoteLanAddress,
            hint: 'https://nas.example.com:8920',
          ),
          _field(
            _c.localFingerprint,
            l.remoteLanFingerprint,
            help: l.remoteLanIdentityHelp,
          ),
        ],
      ],
    ],
  );

  /// Proxies of the App-wide Relay connection; a saved proxy that is no
  /// longer offered stays visible so the user notices.
  Map<String, String> get _remoteProxyOptions => {
    for (final MapEntry(key: name, value: proxy) in _c.remoteProxies.entries)
      name: proxy == null
          ? l.remoteProxyMissing(name)
          : '${proxy.displayName} · ${proxy.remotePort}',
  };

  String _modeLabel(RemoteConnectionMode mode) => switch (mode) {
    RemoteConnectionMode.automatic => l.remoteAutomatic,
    RemoteConnectionMode.localOnly => l.remoteLocalOnly,
    RemoteConnectionMode.remoteOnly => l.remoteRemoteOnly,
  };

  @override
  Widget build(BuildContext context) => PopScope(
    // Leaving mid-save would orphan the request; Plex sign-in can be abandoned.
    canPop: !_submitting && !(_c.busy && !_c.authorizing),
    child: AppPage(
      pageContext: const PageContextData(pageType: 'source_configuration'),
      title: Text(_c.initial == null ? l.addSource : l.editSource),
      body: SingleChildScrollView(
        padding: AppSpacing.page(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppMetrics.formWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_managed)
                  SettingsSection(
                    footer: l.connectorSourceManaged,
                    children: [
                      SettingsRow(
                        title: widget.initial!.name,
                        description: widget.initial!.kind.label,
                      ),
                      _field(
                        _c.name,
                        l.optionalName,
                        hint: widget.initial!.name,
                      ),
                    ],
                  )
                else
                  SettingsSection(
                    children: [
                      SettingsChoiceRow<SourceKind>(
                        key: const ValueKey('source-kind'),
                        title: l.type,
                        value: _c.kind,
                        enabled: !_c.busy && _c.initial == null,
                        options: {
                          for (final kind in SourceKind.values)
                            kind: _kindName(kind),
                        },
                        leading: (kind) => SourceKindIcon(kind, size: 28),
                        onChanged: _c.changeKind,
                      ),
                      _field(_c.name, l.optionalName, hint: _nameHint),
                    ],
                  ),
                if (_managed)
                  SettingsSection(
                    footer: l.connectorSourceLoginHelp,
                    children: [
                      _field(_c.username, l.username, help: _usernameHelp),
                      _field(_c.password, l.password, password: true),
                      if (_c.kind == SourceKind.smb)
                        _field(_c.domain, l.optionalDomain),
                    ],
                  )
                else
                  ...switch (_c.kind) {
                    SourceKind.onedrive ||
                    SourceKind.dropbox ||
                    SourceKind.baidu => _cloudSections(),
                    SourceKind.local => _localSections(),
                    SourceKind.plex => _plexSections(),
                    SourceKind.dlna => _dlnaSections(),
                    _ => _networkSections(),
                  },
                if (!_managed &&
                    (_c.kind.mediaBrowser ||
                        _c.kind == SourceKind.plex ||
                        _c.kind == SourceKind.smb))
                  _remoteSection(),
                if (widget.onAddToHome != null)
                  SettingsSection(
                    children: [
                      SettingsRow(
                        title: l.homeScanScope,
                        description: _managed
                            ? l.connectorSourceDiscovered
                            : _c.kind.oauth
                            ? _c.cloudFolderName
                            : _c.kind == SourceKind.local
                            ? _c.address.text
                            : [
                                _c.address.text,
                                _c.path.text,
                              ].where((s) => s.isNotEmpty).join('/'),
                      ),
                      SettingsRow(title: l.homeScanScopeHelp),
                    ],
                  ),
                const SizedBox(height: AppSpacing.lg),
                if (_failure != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      _failure!,
                      style: TextStyle(
                        color: ShadTheme.of(context).colorScheme.destructive,
                      ),
                    ),
                  ),
                FormActions(
                  status: _c.busy && !_c.authorizing
                      ? FormStatus.busy(l.saving)
                      : null,
                  [
                    FormAction.primary(
                      _managed
                          ? l.connectorSourceLogin
                          : widget.onAddToHome != null
                          ? l.addAndShowHome
                          : _c.initial == null
                          ? l.add
                          : l.save,
                      _c.canSave && !_submitting ? _save : null,
                      key: const ValueKey('source-save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
