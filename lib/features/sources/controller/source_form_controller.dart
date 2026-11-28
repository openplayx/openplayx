import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../capabilities/sources/source_manager.dart';
import '../../../core/capabilities/source_capability.dart';
import '../../../data/remote_access/remote_config.dart';
import '../../../data/sources/dlna_source.dart';
import '../../../data/sources/source_config.dart';
import '../../../data/sources/source_connection.dart';
import '../../../data/sources/source_sign_in.dart';
import '../../../data/sources/cloud_oauth.dart';
import '../../../data/sources/cloud_file_source.dart';
import '../../../data/sources/onedrive_source.dart';
import '../../../l10n/l10n.dart';
import '../../../ui/components/forms/secret_input.dart';

/// Adding or editing one connection: the draft fields, address
/// normalisation, Plex sign-in, DLNA discovery, the connection test and
/// saving. The form view only lays the fields out.
class SourceFormController extends ChangeNotifier {
  SourceFormController({
    required this.manager,
    this.initial,
    SourceKind? initialKind,
    SourceSignIn? signIn,
    this.openBrowser,
    this.chooseDirectory,
    this.discoverDlna,
    required this.onFailure,
  }) : _ownsSignIn = signIn == null,
       signIn = signIn ?? SourceSignIn() {
    final initial = this.initial;
    id = initial?.id ?? '${DateTime.now().microsecondsSinceEpoch}';
    _kind = initial?.kind ?? initialKind ?? SourceKind.local;
    _preset = SourcePreset.byId(initial?.presetId);
    _cloudRootId = initial?.cloudRootId ?? '';
    _cloudDriveId = initial?.cloudDriveId ?? '';
    name.text = initial?.name ?? '';
    final remote = initial?.remote;
    _remoteEnabled = remote != null;
    _remoteProxy = remote?.proxy;
    _connectionMode = remote?.mode ?? RemoteConnectionMode.remoteOnly;
    localEndpoint.text = remote?.localAddress ?? '';
    localFingerprint.text = remote?.localTlsSha256 ?? '';
    if (initial != null) {
      _fillConnection(initial);
      // Jellyfin/Emby keep a session token, not the password: never shown.
      final field = switch (initial.kind) {
        SourceKind.smb ||
        SourceKind.webdav ||
        SourceKind.ftp ||
        SourceKind.sftp ||
        SourceKind.s3 => password,
        SourceKind.plex => manualToken,
        _ => null,
      };
      unawaited(field?.loadStored(() => manager.storedSecret(initial.id)));
    }
    // DLNA validates the address live; the name hint follows the address.
    address.addListener(_notify);
  }

  final SourceManager manager;

  /// The connection being edited; null adds a new one.
  final SourceConfig? initial;
  SourceConfig? _saved;
  final SourceSignIn signIn;
  final bool _ownsSignIn;
  final Future<bool> Function(Uri)? openBrowser;
  final Future<String?> Function()? chooseDirectory;
  final Future<List<DlnaDevice>> Function()? discoverDlna;

  /// Shows a failure to the user (the view toasts it).
  final void Function(String message) onFailure;

  late final String id;

  final name = TextEditingController();
  final address = TextEditingController();
  final username = TextEditingController();
  final password = SecretController();
  final port = TextEditingController();
  final path = TextEditingController();
  final domain = TextEditingController();
  final manualToken = SecretController();
  final localEndpoint = TextEditingController();
  final localFingerprint = TextEditingController();

  SourcePreset? _preset;
  SourcePreset? get preset => _preset;
  CloudTokens? _cloudTokens;
  String _cloudRootId = '';
  String _cloudDriveId = '';
  String _cloudFolderName = '/';
  String get cloudFolderName => _cloudFolderName;
  List<SourceEntry> _cloudFolders = [];
  List<SourceEntry> get cloudFolders => _cloudFolders;
  final _cloudParents = <(String, String)>[];
  bool get cloudCanBack => _cloudParents.isNotEmpty;
  bool get cloudConnected => _cloudTokens != null || initial?.hasSecret == true;

  late SourceKind _kind;
  SourceKind get kind => _kind;
  late bool _remoteEnabled;
  bool get remoteEnabled => _remoteEnabled;
  late RemoteConnectionMode _connectionMode;
  RemoteConnectionMode get connectionMode => _connectionMode;

  /// frpc proxy name from the App-wide Relay connection.
  String? _remoteProxy;
  String? get remoteProxy => _remoteProxy;
  bool _https = false;
  bool get https => _https;
  bool _busy = false;
  bool get busy => _busy;
  bool _authorizing = false;
  bool get authorizing => _authorizing;
  bool _manualPlex = false;
  bool get manualPlex => _manualPlex;
  bool _advanced = false;
  bool get advanced => _advanced;
  List<PlexServer> _servers = [];
  List<PlexServer> get servers => _servers;
  PlexServer? _server;
  PlexServer? get server => _server;
  String? _plexToken;
  Uri? _loginUri;
  Uri? get loginUri => _loginUri;
  int _loginGeneration = 0;
  List<DlnaDevice>? _devices;
  List<DlnaDevice>? get devices => _devices;
  DlnaDevice? _device;
  DlnaDevice? get device => _device;
  bool _searching = false;
  bool get searching => _searching;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _fillConnection(SourceConfig config) {
    username.text = config.username;
    domain.text = config.domain;
    if (config.kind.oauth ||
        config.kind == SourceKind.local ||
        config.kind == SourceKind.dlna) {
      address.text = config.address;
      return;
    }
    final connection = SourceConnection.fromConfig(config);
    address.text = connection.host;
    port.text = '${connection.port}';
    path.text = connection.path;
    _https = connection.https;
  }

  // ---- Field changes ---------------------------------------------------------

  void changeKind(SourceKind kind) {
    _loginGeneration++;
    _kind = kind;
    _preset = null;
    _cloudTokens = null;
    _cloudRootId = '';
    _cloudDriveId = '';
    _cloudFolderName = '/';
    _cloudFolders = [];
    _cloudParents.clear();
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
      address,
      username,
      password,
      port,
      path,
      domain,
      manualToken,
      localEndpoint,
      localFingerprint,
    ]) {
      c.clear();
    }
    _notify();
  }

  void changePreset(SourcePreset? preset) {
    _preset = preset;
    address.text = preset?.address ?? '';
    path.clear();
    port.clear();
    _https = false;
    normalizeAddress(notify: false);
    _notify();
  }

  /// Splits a pasted URL into host, port, path and HTTPS.
  void normalizeAddress({bool notify = true}) {
    if (_kind.oauth ||
        _kind == SourceKind.local ||
        _kind == SourceKind.dlna ||
        !address.text.contains('://')) {
      return;
    }
    final uri = Uri.tryParse(address.text.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !_kind.schemes.contains(uri.scheme)) {
      return;
    }
    if (_kind == SourceKind.smb && uri.hasPort && uri.port != 445) return;
    _https = uri.scheme == 'https';
    port.text = uri.hasPort || _kind.standardPort == null
        ? '${uri.port}'
        : '${_kind.standardPort}';
    path.text = uri.path.replaceFirst(RegExp(r'^/+'), '');
    address.text = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    if (notify) _notify();
  }

  void toggleAdvanced() {
    _advanced = !_advanced;
    if (_advanced) normalizeAddress(notify: false);
    _notify();
  }

  void setHttps(bool value) {
    _https = value;
    port.clear();
    _notify();
  }

  void setManualPlex(bool value) {
    _manualPlex = value;
    _notify();
  }

  void selectServer(PlexServer server) {
    _server = server;
    _notify();
  }

  void selectDevice(DlnaDevice? device) {
    _device = device;
    if (device != null) address.text = device.location.toString();
    _notify();
  }

  void setRemoteEnabled(bool value) {
    _remoteEnabled = value;
    _remoteProxy ??= RemoteProxy.defaultFor(
      manager.remoteNetwork.proxies,
      _kind.name,
    )?.name;
    _notify();
  }

  void setRemoteProxy(String? proxy) {
    _remoteProxy = proxy;
    _notify();
  }

  void setConnectionMode(RemoteConnectionMode mode) {
    _connectionMode = mode;
    _notify();
  }

  // ---- Derived -----------------------------------------------------------------

  /// Proxies of the App-wide Relay connection by name; the saved proxy is
  /// included even when no longer offered (value null) so the user notices.
  Map<String, RemoteProxy?> get remoteProxies {
    final proxies = manager.remoteNetwork.proxies;
    return {
      for (final p in proxies) p.name: p,
      if (_remoteProxy != null && !proxies.any((p) => p.name == _remoteProxy))
        _remoteProxy!: null,
    };
  }

  bool get canSave =>
      !(_busy ||
          _kind.oauth && !cloudConnected ||
          (_kind == SourceKind.local || _kind == SourceKind.dlna) &&
              address.text.trim().isEmpty ||
          _kind == SourceKind.plex &&
              initial == null &&
              !_manualPlex &&
              _server == null);

  String _connectionAddress() {
    normalizeAddress(notify: false);
    if (_kind.oauth) return '${_kind.name}://account';
    return _kind == SourceKind.local
        ? address.text
        : SourceConnection.address(
            _kind,
            address.text,
            port: port.text,
            path: path.text,
            https: _https,
          );
  }

  SourceConfig _draft() {
    final address = _connectionAddress();
    // A blank name stays blank: it displays as "type · address". Only a
    // server the user picked from sign-in discovery brings its own name.
    final defaultName =
        _server?.name ?? _device?.name ?? initial?.remote?.serviceName ?? '';
    final config =
        _saved ??
        initial ??
        SourceConfig(
          id: id,
          kind: _kind,
          name: '',
          address: '',
          presetId: _preset?.name,
        );
    // Hidden management policies are preserved when editing, never reset by
    // this connection form. Only the fields the user can see are changed.
    return config.copyWith(
      name: name.text.trim().isEmpty ? defaultName : name.text.trim(),
      cloudRootId: _cloudRootId,
      cloudDriveId: _cloudDriveId,
      address: address,
      username: username.text.trim(),
      domain: domain.text.trim(),
      remote: _remoteEnabled && _remoteProxy != null
          ? SourceRemote(
              proxy: _remoteProxy!,
              accountId: initial?.remote?.accountId,
              connectorId: initial?.remote?.connectorId,
              serviceName: initial?.remote?.serviceName,
              managedLocal: initial?.remote?.managedLocal ?? false,
              mode: _connectionMode,
              localAddress: localEndpoint.text.trim(),
              localTlsSha256: localFingerprint.text.trim(),
            )
          : null,
      clearRemote: !_remoteEnabled || _remoteProxy == null,
    );
  }

  // ---- Actions -------------------------------------------------------------------

  Future<void> pickDirectory() async {
    try {
      final picked =
          await (chooseDirectory?.call() ?? SourceManager.pickLocalFolder());
      if (picked != null && !_disposed) {
        address.text = picked;
        _notify();
      }
    } catch (_) {
      if (!_disposed) onFailure(appStrings.pickFolderFailed);
    }
  }

  Future<bool> _open(Uri uri) =>
      openBrowser?.call(uri) ??
      launchUrl(uri, mode: LaunchMode.externalApplication);

  /// Opens the sign-in page again while waiting for Plex.
  Future<void> reopenSignIn() async {
    final uri = _loginUri;
    if (uri != null) await _open(uri);
  }

  Future<void> loginPlex() async {
    final generation = ++_loginGeneration;
    _busy = true;
    _authorizing = true;
    _loginUri = null;
    _servers = [];
    _server = null;
    _plexToken = null;
    _notify();
    bool current() => !_disposed && generation == _loginGeneration;
    try {
      final pin = await signIn.startPlex(id);
      if (!current()) return;
      _loginUri = pin.loginUri;
      _notify();
      if (!await _open(pin.loginUri)) {
        throw PluginException('unsupported', appStrings.openBrowserFailed);
      }
      String? token;
      while (current() && token == null) {
        token = await signIn.pollPlex(id, pin);
        if (token == null) await Future<void>.delayed(Duration(seconds: 2));
      }
      if (!current() || token == null) return;
      final found = await signIn.plexServers(id, token);
      if (!current()) return;
      if (found.isEmpty) {
        throw PluginException('notFound', appStrings.noPlexServers);
      }
      _servers = found;
      if (found.length == 1) _server = found.single;
    } catch (error) {
      if (current()) {
        onFailure(
          error is PluginException
              ? error.message
              : appStrings.plexSignInFailed,
        );
      }
    } finally {
      if (current()) {
        _busy = false;
        _authorizing = false;
        _notify();
      }
    }
  }

  Future<bool> disconnectCloud() async {
    _busy = true;
    _notify();
    try {
      await manager.remove(id);
      return !_disposed;
    } catch (_) {
      if (!_disposed) onFailure(appStrings.connectionFormFailed);
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> loginCloud() async {
    final generation = ++_loginGeneration;
    _busy = true;
    _authorizing = true;
    _notify();
    try {
      final tokens = await CloudOAuth.signIn(_kind);
      if (_disposed || generation != _loginGeneration || tokens == null) return;
      _cloudTokens = tokens;
      _cloudRootId = '';
      _cloudDriveId = '';
      _cloudParents.clear();
      await _loadCloudFolders();
    } catch (error) {
      if (!_disposed) {
        onFailure(
          error is PluginException
              ? error.message
              : appStrings.cloudSignInFailed,
        );
      }
    } finally {
      if (!_disposed && generation == _loginGeneration) {
        _busy = false;
        _authorizing = false;
        _notify();
      }
    }
  }

  Future<void> _loadCloudFolders() async {
    final shared = _cloudTokens == null && initial != null;
    if (!shared && _cloudTokens == null) return;
    final session = shared
        ? await manager.cloudTokenSession(initial!)
        : CloudTokenSession(
            _kind,
            _cloudTokens!,
            persist: (next) async {
              _cloudTokens = next;
            },
          );
    final provider = createSourceProvider(
      _draft(),
      session.tokens.encode(),
      cloudSession: session,
      ownsCloudSession: !shared,
    ) as CloudFileSource;
    try {
      final folder = await provider.root();
      if (provider is OneDriveSource) _cloudDriveId = await provider.driveId;
      _cloudRootId = folder.id;
      _cloudFolderName = folder.name;
      final folders = <SourceEntry>[];
      int? offset = 0;
      do {
        final page = await provider.browse(
          BrowseRequest(offset: offset!, limit: 200),
          CallContext.forInstance(id),
        );
        folders.addAll(page.entries.where((e) => e.isFolder));
        offset = page.nextOffset;
      } while (offset != null && !_disposed);
      if (!_disposed) {
        _cloudFolders = folders;
        if (!shared) _cloudTokens = session.tokens;
      }
    } finally {
      await provider.dispose();
    }
  }

  Future<void> selectAllCloudFiles() async {
    final previous = (_cloudRootId, _cloudFolderName);
    _busy = true;
    _notify();
    try {
      _cloudRootId = '';
      await _loadCloudFolders();
      _cloudParents.clear();
    } catch (error) {
      _cloudRootId = previous.$1;
      _cloudFolderName = previous.$2;
      if (!_disposed) {
        onFailure(
          error is PluginException
              ? error.message
              : appStrings.cloudSignInFailed,
        );
      }
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> browseCloudFolder([
    SourceEntry? folder,
    bool back = false,
  ]) async {
    final previous = (_cloudRootId, _cloudFolderName);
    _busy = true;
    _notify();
    try {
      if (back && _cloudParents.isNotEmpty) {
        final parent = _cloudParents.removeLast();
        _cloudRootId = parent.$1;
        _cloudFolderName = parent.$2;
      } else if (folder != null) {
        _cloudParents.add(previous);
        _cloudRootId = folder.ref.id;
        _cloudFolderName = folder.name;
      }
      await _loadCloudFolders();
    } catch (error) {
      _cloudRootId = previous.$1;
      _cloudFolderName = previous.$2;
      if (!_disposed) {
        onFailure(
          error is PluginException
              ? error.message
              : appStrings.cloudSignInFailed,
        );
      }
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> searchDlna() async {
    _searching = true;
    _notify();
    try {
      final found = await (discoverDlna?.call() ?? DlnaDiscovery.search());
      if (_disposed) return;
      _devices = found;
      if (found.length == 1) selectDevice(found.single);
    } catch (_) {
      if (!_disposed) _devices = const [];
    } finally {
      _searching = false;
      _notify();
    }
  }

  /// Tests and saves the connection; true once saved.
  Future<bool> save() async {
    _busy = true;
    _notify();
    try {
      if (_remoteEnabled && _remoteProxy == null) {
        throw FormatException(appStrings.remoteNoProxies);
      }
      var secret = '';
      if (_kind == SourceKind.plex && !_manualPlex && _server != null) {
        final connected = await signIn.connectPlex(id, _server!);
        if (_disposed) return false;
        _fillConnection(
          SourceConfig(
            id: id,
            kind: _kind,
            name: _server!.name,
            address: connected.toString(),
          ),
        );
        _plexToken = _server!.token;
      }
      if (_kind.oauth) await _loadCloudFolders();
      var draft = _draft();
      switch (_kind) {
        case SourceKind.onedrive || SourceKind.dropbox || SourceKind.baidu:
          secret = _cloudTokens?.encode() ?? '';
          await manager.testDraft(draft, secret);
        case SourceKind.local || SourceKind.dlna:
          await manager.testDraft(draft, '');
        case SourceKind.smb ||
            SourceKind.webdav ||
            SourceKind.ftp ||
            SourceKind.sftp ||
            SourceKind.s3:
          secret = password.edited;
          await manager.testDraft(draft, secret);
        case SourceKind.jellyfin || SourceKind.emby:
          final initial = _saved ?? this.initial;
          final reauthenticate =
              initial == null ||
              password.text.isNotEmpty ||
              draft.username != initial.username ||
              draft.address != initial.address ||
              draft.remote?.proxy != initial.remote?.proxy;
          if (reauthenticate) {
            final session = await signIn.jellyfin(
              manager.withRemoteRoute(draft),
              password.text,
            );
            draft = draft.copyWith(userId: session.userId, clearExpiry: true);
            secret = session.token;
          }
        case SourceKind.plex:
          secret = _manualPlex ? manualToken.edited : _plexToken ?? '';
          if (initial == null && secret.isEmpty) {
            throw PluginException(
              'authRequired',
              _manualPlex ? appStrings.enterToken : appStrings.signInPlexFirst,
            );
          }
          await manager.testDraft(draft, secret);
      }
      if (_disposed) return false;
      await manager.save(draft, secret);
      _saved = manager.configs.where((c) => c.id == id).firstOrNull;
      password.clear();
      return !_disposed;
    } catch (error) {
      if (!_disposed) {
        onFailure(
          error is FormatException
              ? error.message
              : error is PluginException
              ? error.message
              : appStrings.connectionFormFailed,
        );
      }
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _loginGeneration++;
    if (_ownsSignIn) signIn.close();
    for (final c in [
      name,
      address,
      username,
      password,
      port,
      path,
      domain,
      manualToken,
      localEndpoint,
      localFingerprint,
    ]) {
      c.dispose();
    }
    super.dispose();
  }
}
