import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/components/media/source_kind_icon.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../ui/adaptive/app_page.dart';
import '../../ui/components/settings/settings_section.dart';
import '../../ui/tokens/app_metrics.dart';
import '../../ui/tokens/app_spacing.dart';
import '../../ui/icons/app_icons.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_config.dart';
import '../../data/remote_access/remote_config.dart';
import '../../data/sources/dlna_source.dart';
import '../../data/sources/source_connection.dart';
import '../../data/sources/source_manager.dart';
import '../../data/sources/source_sign_in.dart';

class SourceInstanceForm extends StatefulWidget {
  const SourceInstanceForm({
    super.key,
    required this.manager,
    this.initial,
    this.signIn,
    this.openBrowser,
    this.chooseDirectory,
    this.discoverDlna,
  });
  final SourceConfig? initial;
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
  late SourceKind _kind;
  late final String _id;
  late final SourceSignIn _signIn;
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _addressFocus = FocusNode();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _port = TextEditingController();
  final _path = TextEditingController();
  final _domain = TextEditingController();
  final _manualToken = TextEditingController();
  final _localEndpoint = TextEditingController();
  final _localFingerprint = TextEditingController();
  bool _remoteEnabled = false;
  RemoteConnectionMode _connectionMode = RemoteConnectionMode.remoteOnly;

  /// frpc proxy name from the App-wide Relay connection.
  String? _remoteProxy;
  bool _https = false;
  bool _busy = false;
  bool _authorizing = false;
  bool _showPassword = false;
  bool _manualPlex = false;
  bool _advanced = false;
  String? _error;
  List<PlexServer> _servers = [];
  PlexServer? _server;
  String? _plexToken;
  Uri? _loginUri;
  int _loginGeneration = 0;
  List<DlnaDevice>? _devices;
  DlnaDevice? _device;
  bool _searching = false;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _id = initial?.id ?? '${DateTime.now().microsecondsSinceEpoch}';
    _kind = initial?.kind ?? SourceKind.local;
    _signIn = widget.signIn ?? SourceSignIn();
    _name.text = initial?.name ?? '';
    final remote = initial?.remote;
    _remoteEnabled = remote != null;
    _remoteProxy = remote?.proxy;
    _connectionMode = remote?.mode ?? RemoteConnectionMode.remoteOnly;
    _localEndpoint.text = remote?.localAddress ?? '';
    _localFingerprint.text = remote?.localTlsSha256 ?? '';
    if (initial != null) _fillConnection(initial);
    _address.addListener(() {
      if (_kind == SourceKind.dlna && mounted) setState(() {});
    });
    _addressFocus.addListener(() {
      if (!_addressFocus.hasFocus && mounted) _normalizeAddress();
    });
  }

  void _fillConnection(SourceConfig config) {
    _username.text = config.username;
    _domain.text = config.domain;
    if (config.kind == SourceKind.local || config.kind == SourceKind.dlna) {
      _address.text = config.address;
      return;
    }
    final connection = SourceConnection.fromConfig(config);
    _address.text = connection.host;
    _port.text = '${connection.port}';
    _path.text = connection.path;
    _https = connection.https;
  }

  @override
  void dispose() {
    _loginGeneration++;
    _addressFocus.dispose();
    if (widget.signIn == null) _signIn.close();
    for (final c in [
      _name,
      _address,
      _username,
      _password,
      _port,
      _path,
      _domain,
      _manualToken,
      _localEndpoint,
      _localFingerprint,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changeKind(SourceKind kind) {
    _loginGeneration++;
    setState(() {
      _kind = kind;
      _error = null;
      _advanced = false;
      _manualPlex = false;
      _remoteEnabled = false;
      _remoteProxy = null;
      _connectionMode = RemoteConnectionMode.remoteOnly;
      _server = null;
      _servers = [];
      _plexToken = null;
      _loginUri = null;
      _https = false;
      _devices = null;
      _device = null;
      for (final c in [
        _address,
        _username,
        _password,
        _port,
        _path,
        _domain,
        _manualToken,
        _localEndpoint,
        _localFingerprint,
      ]) {
        c.clear();
      }
    });
  }

  void _normalizeAddress({bool notify = true}) {
    if (_kind == SourceKind.local ||
        _kind == SourceKind.dlna ||
        !_address.text.contains('://')) {
      return;
    }
    final uri = Uri.tryParse(_address.text.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !_kind.schemes.contains(uri.scheme)) {
      return;
    }
    if (_kind == SourceKind.smb && uri.hasPort && uri.port != 445) return;
    void update() {
      _https = uri.scheme == 'https';
      _port.text = uri.hasPort || _kind.standardPort == null
          ? '${uri.port}'
          : '${_kind.standardPort}';
      _path.text = uri.path.replaceFirst(RegExp(r'^/+'), '');
      _address.text = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    }

    if (notify) {
      setState(update);
    } else {
      update();
    }
  }

  String _connectionAddress() {
    _normalizeAddress(notify: false);
    return _kind == SourceKind.local
        ? _address.text
        : SourceConnection.address(
            _kind,
            _address.text,
            port: _port.text,
            path: _path.text,
            https: _https,
          );
  }

  SourceConfig _draft() {
    final address = _connectionAddress();
    // A blank name stays blank: it displays as "type · address". Only a server
    // the user picked from sign-in discovery brings its own name.
    final defaultName = _server?.name ?? _device?.name ?? '';
    final config =
        widget.initial ??
        SourceConfig(id: _id, kind: _kind, name: '', address: '');
    // Hidden management policies are preserved when editing, never reset by this
    // connection form. Only the fields the user can see are changed here.
    return config.copyWith(
      name: _name.text.trim().isEmpty ? defaultName : _name.text.trim(),
      address: address,
      username: _username.text.trim(),
      domain: _domain.text.trim(),
      remote: _remoteEnabled && _remoteProxy != null
          ? SourceRemote(
              proxy: _remoteProxy!,
              mode: _connectionMode,
              localAddress: _localEndpoint.text.trim(),
              localTlsSha256: _localFingerprint.text.trim(),
            )
          : null,
      clearRemote: !_remoteEnabled || _remoteProxy == null,
    );
  }

  Future<void> _pickDirectory() async {
    try {
      final path = await (widget.chooseDirectory?.call() ?? getDirectoryPath());
      if (path != null && mounted) setState(() => _address.text = path);
    } catch (_) {
      if (mounted) setState(() => _error = l.pickFolderFailed);
    }
  }

  Future<void> _loginPlex() async {
    final generation = ++_loginGeneration;
    setState(() {
      _busy = true;
      _authorizing = true;
      _error = null;
      _loginUri = null;
      _servers = [];
      _server = null;
      _plexToken = null;
    });
    try {
      final pin = await _signIn.startPlex(_id);
      if (!mounted || generation != _loginGeneration) return;
      setState(() => _loginUri = pin.loginUri);
      final opened =
          await (widget.openBrowser?.call(pin.loginUri) ??
              launchUrl(pin.loginUri, mode: LaunchMode.externalApplication));
      if (!opened) {
        throw PluginException('unsupported', l.openBrowserFailed);
      }
      String? token;
      while (mounted && generation == _loginGeneration && token == null) {
        token = await _signIn.pollPlex(_id, pin);
        if (token == null) {
          await Future<void>.delayed(Duration(seconds: 2));
        }
      }
      if (!mounted || generation != _loginGeneration || token == null) return;
      final servers = await _signIn.plexServers(_id, token);
      if (!mounted || generation != _loginGeneration) return;
      if (servers.isEmpty) {
        throw PluginException('notFound', l.noPlexServers);
      }
      setState(() {
        _servers = servers;
        if (servers.length == 1) _server = servers.single;
      });
    } catch (error) {
      if (mounted && generation == _loginGeneration) {
        setState(
          () => _error = error is PluginException
              ? error.message
              : l.plexSignInFailed,
        );
      }
    } finally {
      if (mounted && generation == _loginGeneration) {
        setState(() {
          _busy = false;
          _authorizing = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_remoteEnabled && _remoteProxy == null) {
        throw FormatException(l.remoteNoProxies);
      }
      var secret = '';
      if (_kind == SourceKind.plex && !_manualPlex && _server != null) {
        final address = await _signIn.connectPlex(_id, _server!);
        if (!mounted) return;
        _fillConnection(
          SourceConfig(
            id: _id,
            kind: _kind,
            name: _server!.name,
            address: address.toString(),
          ),
        );
        _plexToken = _server!.token;
      }
      var draft = _draft();
      switch (_kind) {
        case SourceKind.local:
          await widget.manager.testDraft(draft, '');
        case SourceKind.smb ||
            SourceKind.webdav ||
            SourceKind.ftp ||
            SourceKind.sftp ||
            SourceKind.s3:
          secret = _password.text;
          await widget.manager.testDraft(draft, secret);
        case SourceKind.dlna:
          await widget.manager.testDraft(draft, '');
        case SourceKind.jellyfin || SourceKind.emby:
          final initial = widget.initial;
          final reauthenticate =
              initial == null ||
              _password.text.isNotEmpty ||
              draft.username != initial.username ||
              draft.address != initial.address ||
              draft.remote?.proxy != initial.remote?.proxy;
          if (reauthenticate) {
            final session = await _signIn.jellyfin(
              widget.manager.withRemoteRoute(draft),
              _password.text,
            );
            draft = draft.copyWith(userId: session.userId, clearExpiry: true);
            secret = session.token;
          }
        case SourceKind.plex:
          secret = _manualPlex ? _manualToken.text : _plexToken ?? '';
          if (widget.initial == null && secret.isEmpty) {
            throw PluginException(
              'authRequired',
              _manualPlex ? l.enterToken : l.signInPlexFirst,
            );
          }
          await widget.manager.testDraft(draft, secret);
      }
      if (!mounted) return;
      await widget.manager.save(draft, secret);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : error is PluginException
              ? error.message
              : l.connectionFormFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
    final inline = maxLines == 1;
    final input = ShadInput(
      key: key ?? ValueKey(label),
      controller: c,
      focusNode: identical(c, _address) ? _addressFocus : null,
      enabled: !_busy,
      maxLines: maxLines,
      autocorrect: false,
      enableSuggestions: !password,
      obscureText: password && !_showPassword,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: inline ? ShadDecoration.none : null,
      padding: inline ? EdgeInsets.zero : null,
      placeholder: hint == null ? null : Text(hint),
      trailing: password
          ? Tooltip(
              message: _showPassword ? l.hidePassword : l.showPassword,
              child: Semantics(
                button: true,
                label: _showPassword ? l.hidePassword : l.showPassword,
                child: ShadIconButton.ghost(
                  width: 32,
                  height: 32,
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword
                        ? AppIcons.hidePassword
                        : AppIcons.showPassword,
                  ),
                ),
              ),
            )
          : null,
    );
    return inline
        ? SettingsFieldRow(title: label, description: help, field: input)
        : SettingsRow(
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
    onTap: _busy ? null : () => onChanged(!value),
    control: ShadSwitch(
      key: key,
      value: value,
      enabled: !_busy,
      onChanged: _busy ? null : onChanged,
    ),
  );

  /// A row that reveals its section's less common fields in place.
  Widget _advancedToggle() {
    final open = _advanced;
    return SettingsRow(
      key: ValueKey('advanced-${_kind.name}'),
      title: l.advanced,
      control: Icon(open ? AppIcons.collapse : AppIcons.expand, size: 18),
      onTap: () => setState(() {
        _advanced = !open;
        if (_advanced) {
          FocusScope.of(context).unfocus();
          _normalizeAddress(notify: false);
        }
      }),
    );
  }

  /// A choosable item (device, server) with a check on the current one.
  Widget _pickRow(String title, bool selected, VoidCallback onTap) =>
      SettingsRow(
        title: title,
        onTap: _busy ? null : onTap,
        control: selected
            ? Icon(
                AppIcons.check,
                size: 20,
                color: ShadTheme.of(context).colorScheme.primary,
              )
            : null,
      );

  String get _addressHint => switch (_kind) {
    SourceKind.smb || SourceKind.ftp || SourceKind.sftp => '192.168.1.10',
    SourceKind.s3 => 's3.amazonaws.com',
    _ => l.addressHint,
  };

  String? get _usernameHelp => switch (_kind) {
    SourceKind.smb => l.guestHelp,
    SourceKind.webdav || SourceKind.ftp => l.anonymousHelp,
    SourceKind.s3 => l.s3AnonymousHelp,
    _ => null,
  };

  String get _pathHint => switch (_kind) {
    SourceKind.smb => l.smbPathHint,
    SourceKind.s3 => l.s3PathHint,
    SourceKind.webdav || SourceKind.ftp || SourceKind.sftp => l.remotePathHint,
    _ => l.serverPathHint,
  };

  Widget _pathField() => _field(_path, l.optionalPath, hint: _pathHint);

  List<Widget> _localSections() => [
    SettingsSection(
      footer: Platform.isAndroid || Platform.isIOS ? l.folderAccessHelp : null,
      children: [
        SettingsRow(
          title: l.chooseFolder,
          icon: AppIcons.openFolder,
          accent: true,
          description: _address.text.isEmpty ? null : _address.text,
          onTap: _busy ? null : _pickDirectory,
        ),
      ],
    ),
  ];

  List<Widget> _networkSections() => [
    SettingsSection(
      children: [
        _field(_address, l.address, hint: _addressHint),
        _field(
          _username,
          _kind == SourceKind.s3 ? l.s3AccessKey : l.username,
          help: _usernameHelp,
        ),
        _field(
          _password,
          _kind == SourceKind.s3 ? l.s3SecretKey : l.password,
          password: true,
          help: widget.initial != null ? l.keepCredentials : null,
        ),
        if (_kind == SourceKind.s3) ...[
          _field(_domain, l.s3Region, hint: 'us-east-1'),
          _pathField(),
        ],
      ],
    ),
    SettingsSection(
      children: [
        _advancedToggle(),
        if (_advanced) ...[
          if (_kind == SourceKind.smb)
            SettingsRow(title: l.port, control: const Text('445'))
          else if (!_kind.isHttp)
            _field(_port, l.port, number: true, hint: '${_kind.standardPort}')
          else ...[
            _switchRow(
              'HTTPS',
              _https,
              (value) => setState(() {
                _https = value;
                _port.clear();
              }),
              key: const ValueKey('https-switch'),
            ),
            _field(
              _port,
              l.port,
              number: true,
              hint: _https ? '443' : '${_kind.defaultPort ?? 80}',
            ),
          ],
          if (_kind != SourceKind.s3) _pathField(),
          if (_kind == SourceKind.smb) _field(_domain, l.optionalDomain),
        ],
      ],
    ),
  ];

  Future<void> _searchDlna() async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final devices =
          await (widget.discoverDlna?.call() ?? DlnaDiscovery.search());
      if (!mounted) return;
      setState(() {
        _devices = devices;
        if (devices.length == 1) _selectDevice(devices.single);
      });
    } catch (_) {
      if (mounted) setState(() => _devices = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectDevice(DlnaDevice? device) {
    _device = device;
    if (device != null) _address.text = device.location.toString();
  }

  List<Widget> _dlnaSections() => [
    SettingsSection(
      footer: _devices != null && _devices!.isEmpty ? l.dlnaNoDevices : null,
      children: [
        SettingsRow(
          title: _searching ? l.dlnaSearching : l.dlnaSearch,
          icon: AppIcons.search,
          accent: true,
          onTap: _busy || _searching ? null : _searchDlna,
        ),
        for (final device in _devices ?? const <DlnaDevice>[])
          _pickRow(
            device.name,
            device.location == _device?.location,
            () => setState(() => _selectDevice(device)),
          ),
      ],
    ),
    SettingsSection(
      footer: l.dlnaAddressHelp,
      children: [
        _field(
          _address,
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
        if (widget.initial != null && _servers.isEmpty)
          SettingsRow(
            icon: AppIcons.server,
            title: widget.initial!.titleName,
            description: Uri.parse(widget.initial!.address).host,
          ),
        SettingsRow(
          title: _authorizing
              ? l.waitingPlex
              : widget.initial == null
              ? l.signInPlex
              : l.signInPlexAgain,
          icon: AppIcons.signIn,
          accent: true,
          onTap: _busy ? null : _loginPlex,
        ),
        if (_authorizing && _loginUri != null)
          SettingsRow(
            title: l.reopenSignIn,
            accent: true,
            onTap: () =>
                widget.openBrowser?.call(_loginUri!) ??
                launchUrl(_loginUri!, mode: LaunchMode.externalApplication),
          ),
      ],
    ),
    if (_servers.isNotEmpty)
      SettingsSection(
        title: l.server,
        children: [
          for (final server in _servers)
            _pickRow(
              server.name,
              server.id == _server?.id,
              () => setState(() => _server = server),
            ),
        ],
      ),
    SettingsSection(
      children: [
        _advancedToggle(),
        if (_advanced) ...[
          _switchRow(
            l.manualServer,
            _manualPlex,
            (value) => setState(() => _manualPlex = value),
            key: const ValueKey('plex-manual'),
          ),
          if (_manualPlex) ...[
            _field(
              _address,
              l.serverAddress,
              hint: 'http://192.168.1.10:32400',
              help: l.portInAddress,
            ),
            _field(
              _manualToken,
              l.accessToken,
              password: true,
              help: widget.initial == null ? null : l.keepCredentials,
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
        _remoteEnabled,
        (v) => setState(() {
          _remoteEnabled = v;
          _remoteProxy ??= RemoteProxy.defaultFor(
            widget.manager.remoteNetwork.proxies,
            _kind.name,
          )?.name;
        }),
        key: const ValueKey('remote-switch'),
      ),
      if (_remoteEnabled) ...[
        if (_remoteProxyOptions.isEmpty)
          SettingsRow(
            key: const ValueKey('remote-no-proxies'),
            title: l.remoteNoProxies,
          )
        else
          SettingsChoiceRow<String>(
            key: const ValueKey('remote-proxy'),
            title: l.remoteProxy,
            value: _remoteProxy ?? '',
            enabled: !_busy,
            options: {
              if (_remoteProxy == null) '': '—',
              ..._remoteProxyOptions,
            },
            onChanged: (v) =>
                setState(() => _remoteProxy = v.isEmpty ? null : v),
          ),
        SettingsChoiceRow<RemoteConnectionMode>(
          title: l.remoteConnectionMode,
          value: _connectionMode,
          enabled: !_busy && _kind != SourceKind.smb,
          options: {
            for (final mode
                in _kind == SourceKind.smb
                    ? [RemoteConnectionMode.remoteOnly]
                    : RemoteConnectionMode.values)
              mode: _modeLabel(mode),
          },
          onChanged: (v) => setState(() => _connectionMode = v),
        ),
        if (_connectionMode != RemoteConnectionMode.remoteOnly) ...[
          _field(
            _localEndpoint,
            l.remoteLanAddress,
            hint: 'https://nas.example.com:8920',
          ),
          _field(
            _localFingerprint,
            l.remoteLanFingerprint,
            help: l.remoteLanIdentityHelp,
          ),
        ],
      ],
    ],
  );

  /// Proxies of the App-wide Relay connection; a saved proxy that is no
  /// longer offered stays visible so the user notices.
  Map<String, String> get _remoteProxyOptions {
    final proxies = widget.manager.remoteNetwork.proxies;
    return {
      for (final p in proxies) p.name: '${p.name} · ${p.remotePort}',
      if (_remoteProxy != null && !proxies.any((p) => p.name == _remoteProxy))
        _remoteProxy!: l.remoteProxyMissing(_remoteProxy!),
    };
  }

  String _modeLabel(RemoteConnectionMode mode) => switch (mode) {
    RemoteConnectionMode.automatic => l.remoteAutomatic,
    RemoteConnectionMode.localOnly => l.remoteLocalOnly,
    RemoteConnectionMode.remoteOnly => l.remoteRemoteOnly,
  };

  bool get _canSave =>
      !(_busy ||
          (_kind == SourceKind.local || _kind == SourceKind.dlna) &&
              _address.text.trim().isEmpty ||
          _kind == SourceKind.plex &&
              widget.initial == null &&
              !_manualPlex &&
              _server == null);

  @override
  Widget build(BuildContext context) => PopScope(
    // Leaving mid-save would orphan the request; Plex sign-in can be abandoned.
    canPop: !(_busy && !_authorizing),
    child: AppPage(
      title: Text(widget.initial == null ? l.addSource : l.editSource),
      trailing: [
        ShadButton.ghost(
          key: const ValueKey('source-save'),
          onPressed: _canSave ? _save : null,
          enabled: _canSave,
          child: Text(widget.initial == null ? l.add : l.save),
        ),
      ],
      body: SingleChildScrollView(
        padding: AppSpacing.page(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppMetrics.formWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_busy) ...[
                  const ShadProgress(),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_error != null) ...[
                  ShadAlert.destructive(title: Text(_error!)),
                  const SizedBox(height: AppSpacing.md),
                ],
                SettingsSection(
                  children: [
                    SettingsChoiceRow<SourceKind>(
                      key: const ValueKey('source-kind'),
                      title: l.type,
                      value: _kind,
                      enabled: !_busy && widget.initial == null,
                      options: {
                        for (final kind in SourceKind.values)
                          kind: _kindName(kind),
                      },
                      leading: (kind) => SourceKindIcon(kind, size: 28),
                      onChanged: _changeKind,
                    ),
                    _field(_name, l.optionalName),
                  ],
                ),
                ...switch (_kind) {
                  SourceKind.local => _localSections(),
                  SourceKind.plex => _plexSections(),
                  SourceKind.dlna => _dlnaSections(),
                  _ => _networkSections(),
                },
                if (_kind.mediaBrowser ||
                    _kind == SourceKind.plex ||
                    _kind == SourceKind.smb)
                  _remoteSection(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
