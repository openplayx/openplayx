import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/components/media/source_kind_icon.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../ui/components/media/content_row.dart';
import '../../ui/adaptive/form_page.dart';
import '../../ui/icons/app_icons.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_config.dart';
import '../../data/remote_access/remote_config.dart';
import '../../data/remote_access/remote_transport.dart';
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
  final _pairing = TextEditingController();
  final _localEndpoint = TextEditingController();
  final _localFingerprint = TextEditingController();
  bool _remoteEnabled = false;
  RemoteConnectionMode _connectionMode = RemoteConnectionMode.remoteOnly;
  RemoteAccessConfig? _preparedRemote;
  bool _https = false;
  bool _busy = false;
  bool _authorizing = false;
  bool _showPassword = false;
  bool _manualPlex = false;
  final _advancedController = ShadAccordionController<String>();
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
    _preparedRemote = initial?.remoteAccess;
    _remoteEnabled = _preparedRemote != null;
    _connectionMode = _preparedRemote?.mode ?? RemoteConnectionMode.remoteOnly;
    _localEndpoint.text = _preparedRemote?.localAddress ?? '';
    _localFingerprint.text = _preparedRemote?.localTlsSha256 ?? '';
    if (initial != null) _fillConnection(initial);
    _advancedController.addListener(() {
      if (_advancedController.value.isNotEmpty && mounted) {
        FocusScope.of(context).unfocus();
        _normalizeAddress();
      }
    });
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
    _advancedController.dispose();
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
      _pairing,
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
      _advancedController.value = [];
      _manualPlex = false;
      _remoteEnabled = false;
      _preparedRemote = null;
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
        _pairing,
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
      remoteAccess: _preparedRemote,
      clearRemoteAccess: !_remoteEnabled,
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
    String? stagedRemote;
    var savedRemote = false;
    try {
      if (_remoteEnabled) {
        final pair = _pairing.text.trim().isEmpty
            ? null
            : RemotePairing.parse(_pairing.text);
        final previous = widget.initial?.remoteAccess;
        if (pair == null && previous == null) {
          throw const FormatException('请粘贴 relay 生成的服务配对配置。');
        }
        final ref = pair == null
            ? previous!.credentialRef
            : (stagedRemote = await RemoteCredentialStore.stage(_id, {
                'uuid': pair.outbound['uuid'],
              }));
        final j = pair?.data ?? previous!.toJson();
        _preparedRemote = RemoteAccessConfig(
          lineId: j['lineId'] as String,
          homeId: j['homeId'] as String,
          serviceId: j['serviceId'] as String,
          remoteAddress: j['remoteAddress'] as String,
          remotePort: j['remotePort'] as int,
          credentialRef: ref,
          mode: _connectionMode,
          localAddress: _localEndpoint.text.trim(),
          localTlsSha256: _localFingerprint.text.trim(),
          outboundOptions: pair == null
              ? previous?.outboundOptions
              : ({...pair.outbound}..remove('uuid')),
        );
        _preparedRemote!.validate();
        if (_address.text.trim().isEmpty) {
          _fillConnection(
            SourceConfig(
              id: _id,
              kind: _kind,
              name: '',
              address: _preparedRemote!.remoteAddress,
            ),
          );
        }
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
              stagedRemote != null;
          if (reauthenticate) {
            final session = await _signIn.jellyfin(draft, _password.text);
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
      savedRemote = true;
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
      if (stagedRemote != null && !savedRemote) {
        await widget.manager.discardRemoteSecret(_id, stagedRemote);
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Kind name with its recognisable mark.
  Widget _kindLabel(SourceKind kind) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SourceKindIcon(kind, size: 24),
      const SizedBox(width: 8),
      Text(kind == SourceKind.local ? l.localFolder : kind.label),
    ],
  );

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    String? help,
    bool password = false,
    bool number = false,
  }) => Padding(
    padding: EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: ShadTheme.of(context).textTheme.small),
        SizedBox(height: 8),
        ShadInput(
          key: ValueKey(label),
          controller: c,
          focusNode: identical(c, _address) ? _addressFocus : null,
          enabled: !_busy,
          autocorrect: false,
          enableSuggestions: !password,
          obscureText: password && !_showPassword,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          placeholder: hint == null ? null : Text(hint),
          trailing: password
              ? Tooltip(
                  message: _showPassword ? l.hidePassword : l.showPassword,
                  child: Semantics(
                    button: true,
                    label: _showPassword ? l.hidePassword : l.showPassword,
                    child: ShadIconButton.ghost(
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
        ),
        if (help != null)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(help, style: ShadTheme.of(context).textTheme.muted),
          ),
      ],
    ),
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

  Widget _networkFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
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
      ShadAccordion<String>(
        key: ValueKey('advanced-${_kind.name}'),
        controller: _advancedController,
        children: [
          ShadAccordionItem(
            value: 'advanced',
            title: Text(l.advanced),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_kind == SourceKind.smb)
                  ContentRow(title: Text(l.port), trailing: Text('445'))
                else if (!_kind.isHttp)
                  _field(
                    _port,
                    l.port,
                    number: true,
                    hint: '${_kind.standardPort}',
                  )
                else ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ShadSwitch(
                      enabled: !_busy,
                      label: Text('HTTPS'),
                      value: _https,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              _https = value;
                              _port.clear();
                            }),
                    ),
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
            ),
          ),
        ],
      ),
    ],
  );

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

  Widget _dlnaFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(height: 12),
      ShadButton.outline(
        onPressed: _busy || _searching ? null : _searchDlna,
        leading: Icon(AppIcons.search),
        enabled: !(_busy || _searching),
        child: Text(_searching ? l.dlnaSearching : l.dlnaSearch),
      ),
      if (_devices != null && _devices!.isEmpty)
        Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            l.dlnaNoDevices,
            style: ShadTheme.of(context).textTheme.muted,
          ),
        ),
      if (_devices?.isNotEmpty == true)
        Padding(
          padding: EdgeInsets.only(top: 12),
          child: ShadSelect<DlnaDevice>(
            initialValue: _device,
            onChanged: _busy ? null : (d) => setState(() => _selectDevice(d)),
            selectedOptionBuilder: (_, device) => Text(device.name),
            placeholder: Text(l.dlnaDevice),
            key: ValueKey(_device?.location ?? 'dlna-device'),
            options: _devices!
                .map((d) => ShadOption(value: d, child: Text(d.name)))
                .toList(),
            maxWidth: 560,
            enabled: !_busy,
          ),
        ),
      _field(
        _address,
        l.dlnaAddress,
        hint: 'http://192.168.1.10:8200/rootDesc.xml',
        help: l.dlnaAddressHelp,
      ),
    ],
  );

  Widget _plexFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(height: 12),
      if (widget.initial != null && _servers.isEmpty)
        ContentRow(
          contentPadding: EdgeInsets.zero,
          leading: Icon(AppIcons.server),
          title: Text(widget.initial!.titleName),
          subtitle: Text(Uri.parse(widget.initial!.address).host),
        ),
      ShadButton(
        onPressed: _busy ? null : _loginPlex,
        leading: Icon(AppIcons.signIn),
        enabled: !(_busy),
        child: Text(
          _authorizing
              ? l.waitingPlex
              : widget.initial == null
              ? l.signInPlex
              : l.signInPlexAgain,
        ),
      ),
      Padding(padding: EdgeInsets.only(top: 8), child: Text(l.plexBrowserHelp)),
      if (_authorizing && _loginUri != null)
        ShadButton.ghost(
          onPressed: () =>
              widget.openBrowser?.call(_loginUri!) ??
              launchUrl(_loginUri!, mode: LaunchMode.externalApplication),
          child: Text(l.reopenSignIn),
        ),
      if (_servers.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(top: 12),
          child: ShadSelect<PlexServer>(
            initialValue: _server,
            onChanged: _busy ? null : (s) => setState(() => _server = s),
            selectedOptionBuilder: (_, server) => Text(server.name),
            placeholder: Text(l.server),
            key: ValueKey(_server?.id ?? 'plex-server'),
            options: _servers
                .map((s) => ShadOption(value: s, child: Text(s.name)))
                .toList(),
            maxWidth: 560,
            enabled: !(_busy),
          ),
        ),
      ShadAccordion<String>(
        children: [
          ShadAccordionItem(
            value: 'advanced',
            title: Text(l.advanced),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ShadSwitch(
                    enabled: !_busy,
                    label: Text(l.manualServer),
                    value: _manualPlex,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _manualPlex = value),
                  ),
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
            ),
          ),
        ],
      ),
    ],
  );
  Widget _remoteFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 16),
      ShadSwitch(
        value: _remoteEnabled,
        enabled: !_busy,
        label: Text(l.remoteHomeAccess),
        onChanged: (v) => setState(() => _remoteEnabled = v),
      ),
      if (_remoteEnabled) ...[
        const SizedBox(height: 12),
        Text(l.remotePairingHelp),
        const SizedBox(height: 8),
        ShadInput(
          key: const ValueKey('remote-pairing'),
          controller: _pairing,
          maxLines: 6,
          enabled: !_busy,
          placeholder: Text(
            widget.initial?.remoteAccess == null
                ? l.remotePairingJson
                : l.remoteKeepCredentials,
          ),
          autocorrect: false,
          enableSuggestions: false,
        ),
        const SizedBox(height: 12),
        ShadSelect<RemoteConnectionMode>(
          initialValue: _connectionMode,
          enabled: !_busy,
          onChanged: (v) => setState(() => _connectionMode = v!),
          selectedOptionBuilder: (_, v) => Text(_modeLabel(v)),
          options:
              (_kind == SourceKind.smb
                      ? [RemoteConnectionMode.remoteOnly]
                      : RemoteConnectionMode.values)
                  .map((v) => ShadOption(value: v, child: Text(_modeLabel(v))))
                  .toList(),
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
  String _modeLabel(RemoteConnectionMode mode) => switch (mode) {
    RemoteConnectionMode.automatic => l.remoteAutomatic,
    RemoteConnectionMode.localOnly => l.remoteLocalOnly,
    RemoteConnectionMode.remoteOnly => l.remoteRemoteOnly,
  };
  @override
  Widget build(BuildContext context) => FormPage(
    // Leaving mid-save would orphan the request; Plex sign-in can be abandoned.
    canPop: !(_busy && !_authorizing),
    title: Text(widget.initial == null ? l.addSource : l.editSource),
    actions: [
      ShadButton.ghost(
        onPressed: _busy && !_authorizing ? null : () => Navigator.pop(context),
        enabled: !(_busy && !_authorizing),
        child: Text(l.cancel),
      ),
      ShadButton(
        onPressed:
            _busy ||
                (_kind == SourceKind.local || _kind == SourceKind.dlna) &&
                    _address.text.trim().isEmpty ||
                _kind == SourceKind.plex &&
                    widget.initial == null &&
                    !_manualPlex &&
                    _server == null
            ? null
            : _save,
        enabled:
            !(_busy ||
                (_kind == SourceKind.local || _kind == SourceKind.dlna) &&
                    _address.text.trim().isEmpty ||
                _kind == SourceKind.plex &&
                    widget.initial == null &&
                    !_manualPlex &&
                    _server == null),
        child: Text(widget.initial == null ? l.add : l.save),
      ),
    ],
    children: [
      ShadSelect<SourceKind>(
        initialValue: _kind,
        onChanged: _busy || widget.initial != null
            ? null
            : (kind) => _changeKind(kind!),
        selectedOptionBuilder: (_, kind) => _kindLabel(kind),
        key: ValueKey('kind-${_kind.name}'),
        placeholder: Text(l.type),
        options: SourceKind.values
            .map((kind) => ShadOption(value: kind, child: _kindLabel(kind)))
            .toList(),
        maxWidth: 560,
        enabled: !(_busy || widget.initial != null),
      ),
      _field(_name, l.optionalName),
      if (_kind == SourceKind.local) ...[
        SizedBox(height: 12),
        ShadButton.outline(
          onPressed: _busy ? null : _pickDirectory,
          leading: Icon(AppIcons.openFolder),
          enabled: !(_busy),
          child: Text(l.chooseFolder),
        ),
        if (_address.text.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              _address.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (Platform.isAndroid || Platform.isIOS)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(l.folderAccessHelp),
          ),
      ] else if (_kind == SourceKind.plex)
        _plexFields()
      else if (_kind == SourceKind.dlna)
        _dlnaFields()
      else
        _networkFields(),
      if (_kind.mediaBrowser ||
          _kind == SourceKind.plex ||
          _kind == SourceKind.smb)
        _remoteFields(),
      if (_error != null)
        Padding(
          padding: EdgeInsets.only(top: 12),
          child: ShadAlert.destructive(title: Text(_error!)),
        ),
      if (_busy)
        Padding(padding: EdgeInsets.only(top: 12), child: ShadProgress()),
    ],
  );
}
