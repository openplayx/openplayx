import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../ui/components/media/content_row.dart';
import '../../ui/icons/app_icons.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_config.dart';
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
  });
  final SourceConfig? initial;
  final SourceManager manager;
  final SourceSignIn? signIn;
  final Future<bool> Function(Uri)? openBrowser;
  final Future<String?> Function()? chooseDirectory;
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
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _id = initial?.id ?? '${DateTime.now().microsecondsSinceEpoch}';
    _kind = initial?.kind ?? SourceKind.local;
    _signIn = widget.signIn ?? SourceSignIn();
    _name.text = initial?.name ?? '';
    if (initial != null) _fillConnection(initial);
    _advancedController.addListener(() {
      if (_advancedController.value.isNotEmpty && mounted) {
        FocusScope.of(context).unfocus();
        _normalizeAddress();
      }
    });
    _addressFocus.addListener(() {
      if (!_addressFocus.hasFocus && mounted) _normalizeAddress();
    });
  }

  void _fillConnection(SourceConfig config) {
    _username.text = config.username;
    _domain.text = config.domain;
    if (config.kind == SourceKind.local) {
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
      _server = null;
      _servers = [];
      _plexToken = null;
      _loginUri = null;
      _https = false;
      for (final c in [
        _address,
        _username,
        _password,
        _port,
        _path,
        _domain,
        _manualToken,
      ]) {
        c.clear();
      }
    });
  }

  void _normalizeAddress({bool notify = true}) {
    if (_kind == SourceKind.local || !_address.text.contains('://')) return;
    final uri = Uri.tryParse(_address.text.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !(_kind == SourceKind.smb ? ['smb'] : ['http', 'https']).contains(
          uri.scheme,
        )) {
      return;
    }
    if (_kind == SourceKind.smb && uri.hasPort && uri.port != 445) return;
    void update() {
      _https = uri.scheme == 'https';
      _port.text = _kind == SourceKind.smb ? '445' : '${uri.port}';
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
    final defaultName = _kind == SourceKind.local
        ? Directory(address).uri.pathSegments
                  .where((s) => s.isNotEmpty)
                  .lastOrNull ??
              l.localFolder
        : _server?.name ?? Uri.parse(address).host;
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
        case SourceKind.smb:
          secret = _password.text;
          await widget.manager.testDraft(draft, secret);
        case SourceKind.jellyfin:
          final initial = widget.initial;
          final reauthenticate =
              initial == null ||
              _password.text.isNotEmpty ||
              draft.username != initial.username ||
              draft.address != initial.address;
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
  Widget _networkFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _field(
        _address,
        l.address,
        hint: _kind == SourceKind.smb ? '192.168.1.10' : l.addressHint,
      ),
      _field(
        _username,
        l.username,
        help: _kind == SourceKind.smb ? l.guestHelp : null,
      ),
      _field(
        _password,
        l.password,
        password: true,
        help: widget.initial != null ? l.keepCredentials : null,
      ),
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
                    hint: _https ? '443' : '8096',
                  ),
                ],
                _field(
                  _path,
                  l.optionalPath,
                  hint: _kind == SourceKind.smb
                      ? l.smbPathHint
                      : l.serverPathHint,
                ),
                if (_kind == SourceKind.smb) _field(_domain, l.optionalDomain),
              ],
            ),
          ),
        ],
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
          title: Text(widget.initial!.name),
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
            maxWidth: 520,
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
  @override
  Widget build(BuildContext context) => ShadDialog(
    closeIcon: SizedBox.shrink(),
    constraints: BoxConstraints(maxWidth: 568),
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
                _kind == SourceKind.local && _address.text.isEmpty ||
                _kind == SourceKind.plex &&
                    widget.initial == null &&
                    !_manualPlex &&
                    _server == null
            ? null
            : _save,
        enabled:
            !(_busy ||
                _kind == SourceKind.local && _address.text.isEmpty ||
                _kind == SourceKind.plex &&
                    widget.initial == null &&
                    !_manualPlex &&
                    _server == null),
        child: Text(widget.initial == null ? l.add : l.save),
      ),
    ],
    child: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShadSelect<SourceKind>(
              initialValue: _kind,
              onChanged: _busy || widget.initial != null
                  ? null
                  : (kind) => _changeKind(kind!),
              selectedOptionBuilder: (_, kind) =>
                  Text(kind == SourceKind.local ? l.localFolder : kind.label),
              key: ValueKey('kind-${_kind.name}'),
              placeholder: Text(l.type),
              options: SourceKind.values
                  .map(
                    (kind) => ShadOption(
                      value: kind,
                      child: Text(
                        kind == SourceKind.local ? l.localFolder : kind.label,
                      ),
                    ),
                  )
                  .toList(),
              maxWidth: 520,
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
            else
              _networkFields(),
            if (_error != null)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: ShadAlert.destructive(title: Text(_error!)),
              ),
            if (_busy)
              Padding(padding: EdgeInsets.only(top: 12), child: ShadProgress()),
          ],
        ),
      ),
    ),
  );
}
