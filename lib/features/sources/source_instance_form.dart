import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
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
    this.fileSources,
    this.signIn,
    this.openBrowser,
    this.chooseDirectory,
  });
  final SourceConfig? initial;
  final bool? fileSources;
  final SourceManager manager;
  final SourceSignIn? signIn;
  final Future<bool> Function(Uri)? openBrowser;
  final Future<String?> Function()? chooseDirectory;
  @override
  State<SourceInstanceForm> createState() => _SourceInstanceFormState();
}

class _SourceInstanceFormState extends State<SourceInstanceForm> {
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
  bool _advanced = false;
  String? _error;
  List<PlexServer> _servers = const [];
  PlexServer? _server;
  String? _plexToken;
  Uri? _loginUri;
  int _loginGeneration = 0;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _id = initial?.id ?? '${DateTime.now().microsecondsSinceEpoch}';
    _kind =
        initial?.kind ??
        (widget.fileSources == false ? SourceKind.jellyfin : SourceKind.local);
    _signIn = widget.signIn ?? SourceSignIn();
    _name.text = initial?.name ?? '';
    if (initial != null) _fillConnection(initial);
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
      _advanced = false;
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
              '本地文件夹'
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
      if (mounted) setState(() => _error = '无法选择文件夹，请重试。');
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
        throw const PluginException('unsupported', '无法打开浏览器，请点击登录链接重试。');
      }
      String? token;
      while (mounted && generation == _loginGeneration && token == null) {
        token = await _signIn.pollPlex(_id, pin);
        if (token == null) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
      if (!mounted || generation != _loginGeneration || token == null) return;
      final servers = await _signIn.plexServers(_id, token);
      if (!mounted || generation != _loginGeneration) return;
      if (servers.isEmpty) {
        throw const PluginException('notFound', '此 Plex 账号下没有可访问的服务器。');
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
              : 'Plex 登录失败，请重试。',
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
              _manualPlex ? '请填写访问令牌后连接服务器。' : '请先登录 Plex 并选择服务器。',
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
              : '连接失败，请检查地址和登录信息。',
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
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: c,
      focusNode: identical(c, _address) ? _addressFocus : null,
      enabled: !_busy,
      autocorrect: false,
      enableSuggestions: !password,
      obscureText: password && !_showPassword,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: help,
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
        suffixIcon: password
            ? IconButton(
                tooltip: _showPassword ? '隐藏密码' : '显示密码',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
              )
            : null,
      ),
    ),
  );
  Widget _networkFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _field(
        _address,
        '地址',
        hint: _kind == SourceKind.smb
            ? '192.168.1.10'
            : '192.168.1.10 或 https://media.example.com',
      ),
      _field(
        _username,
        '用户名',
        help: _kind == SourceKind.smb ? '访客访问时，用户名和密码都留空' : null,
      ),
      _field(
        _password,
        '密码',
        password: true,
        help: widget.initial != null ? '留空保留当前登录' : null,
      ),
      ExpansionTile(
        key: ValueKey('advanced-${_kind.name}'),
        title: const Text('高级'),
        initiallyExpanded: _advanced,
        onExpansionChanged: (value) {
          _advanced = value;
          if (value) {
            FocusScope.of(context).unfocus();
            _normalizeAddress();
          }
        },
        children: [
          if (_kind == SourceKind.smb)
            const ListTile(title: Text('端口'), trailing: Text('445'))
          else ...[
            SwitchListTile(
              title: const Text('HTTPS'),
              value: _https,
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _https = value;
                      _port.clear();
                    }),
            ),
            _field(_port, '端口', number: true, hint: _https ? '443' : '8096'),
          ],
          _field(
            _path,
            '路径（可选）',
            hint: _kind == SourceKind.smb ? '共享文件夹/影片目录' : '例如 jellyfin，没有则留空',
          ),
          if (_kind == SourceKind.smb) _field(_domain, '工作组（可选）'),
        ],
      ),
    ],
  );
  Widget _plexFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      if (widget.initial != null && _servers.isEmpty)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.dns_outlined),
          title: Text(widget.initial!.name),
          subtitle: Text(Uri.parse(widget.initial!.address).host),
        ),
      FilledButton.icon(
        onPressed: _busy ? null : _loginPlex,
        icon: const Icon(Icons.login),
        label: Text(
          _authorizing
              ? '等待 Plex 授权…'
              : widget.initial == null
              ? '登录 Plex'
              : '重新登录 Plex',
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('在浏览器中登录 Plex，然后选择要连接的服务器。'),
      ),
      if (_authorizing && _loginUri != null)
        TextButton(
          onPressed: () =>
              widget.openBrowser?.call(_loginUri!) ??
              launchUrl(_loginUri!, mode: LaunchMode.externalApplication),
          child: const Text('重新打开登录页'),
        ),
      if (_servers.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: DropdownButtonFormField<PlexServer>(
            initialValue: _server,
            decoration: const InputDecoration(labelText: '服务器'),
            items: _servers
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                .toList(),
            onChanged: _busy ? null : (s) => setState(() => _server = s),
          ),
        ),
      ExpansionTile(
        title: const Text('高级'),
        children: [
          SwitchListTile(
            title: const Text('手动连接服务器'),
            value: _manualPlex,
            onChanged: _busy
                ? null
                : (value) => setState(() => _manualPlex = value),
          ),
          if (_manualPlex) ...[
            _field(
              _address,
              '服务器地址',
              hint: 'http://192.168.1.10:32400',
              help: '使用自定义端口时，请在地址中一并填写。',
            ),
            _field(
              _manualToken,
              '访问令牌',
              password: true,
              help: widget.initial == null ? null : '留空保留当前登录',
            ),
          ],
        ],
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? '添加媒体源' : '编辑媒体源'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<SourceKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: '类型'),
              items: SourceKind.values
                  .where(
                    (kind) =>
                        widget.fileSources == null ||
                        (kind == SourceKind.local || kind == SourceKind.smb) ==
                            widget.fileSources,
                  )
                  .map(
                    (kind) =>
                        DropdownMenuItem(value: kind, child: Text(kind.label)),
                  )
                  .toList(),
              onChanged: _busy || widget.initial != null
                  ? null
                  : (kind) => _changeKind(kind!),
            ),
            _field(_name, '名称（可选）'),
            if (_kind == SourceKind.local) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickDirectory,
                icon: const Icon(Icons.folder_open),
                label: const Text('选择文件夹'),
              ),
              if (_address.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _address.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (Platform.isAndroid || Platform.isIOS)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('请选择系统允许应用访问的文件夹。'),
                ),
            ] else if (_kind == SourceKind.plex)
              _plexFields()
            else
              _networkFields(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy && !_authorizing ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed:
            _busy ||
                _kind == SourceKind.local && _address.text.isEmpty ||
                _kind == SourceKind.plex &&
                    widget.initial == null &&
                    !_manualPlex &&
                    _server == null
            ? null
            : _save,
        child: Text(widget.initial == null ? '添加' : '保存'),
      ),
    ],
  );
}
