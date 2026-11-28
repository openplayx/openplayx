import 'dart:async';

import '../../data/analytics/analytics_service.dart';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/capabilities/source_capability.dart';
import '../../core/capabilities/metadata_capability.dart';
import '../capability_switches.dart';
import '../../data/configuration/source_configuration_service.dart';
import '../../data/configuration/source_credential_broker.dart';
import '../../data/configuration/source_secure_store.dart';
import '../../data/sources/cloud_oauth.dart';
import '../../data/sources/cloud_file_source.dart';
import '../../data/sources/onedrive_source.dart';
import '../../data/sources/dropbox_source.dart';
import '../../data/sources/baidu_source.dart';
import '../../data/library/library_database.dart';
import '../../data/sources/source_state_store.dart';
import '../../data/sources/file_sources.dart';
import '../../data/sources/dlna_source.dart';
import '../../data/sources/media_server_sources.dart';
import '../../data/sources/network_file_sources.dart';
import '../../data/sources/source_config.dart';
import '../../data/remote_access/remote_transport.dart';
import '../../data/remote_access/remote_access_service.dart';
import '../../data/remote_access/remote_native.dart';
import '../../data/remote_access/discovered_source.dart';
import '../../data/remote_access/remote_config.dart';

import 'dart:convert';

import '../../data/sources/source_schema.dart';
import '../../l10n/l10n.dart';

/// Builds the provider for one configuration snapshot and its secret.
SourceCapability createSourceProvider(
  SourceConfig config,
  String secret, {
  CloudTokenSession? cloudSession,
  bool ownsCloudSession = true,
}) => switch (config.kind) {
  SourceKind.onedrive => OneDriveSource(
    config,
    cloudSession ??
        CloudTokenSession(
          config.kind,
          CloudTokens.decode(secret),
          persist: (_) async {},
        ),
    ownsSession: ownsCloudSession,
  ),
  SourceKind.dropbox => DropboxSource(
    config,
    cloudSession ??
        CloudTokenSession(
          config.kind,
          CloudTokens.decode(secret),
          persist: (_) async {},
        ),
    ownsSession: ownsCloudSession,
  ),
  SourceKind.baidu => BaiduSource(
    config,
    cloudSession ??
        CloudTokenSession(
          config.kind,
          CloudTokens.decode(secret),
          persist: (_) async {},
        ),
    ownsSession: ownsCloudSession,
  ),
  SourceKind.local => LocalFolderPlugin(config),
  SourceKind.smb => SmbPlugin.withAccess(config, SmbAccess(config, secret)),
  SourceKind.webdav => WebDavPlugin(config, secret),
  SourceKind.ftp => FtpPlugin(config, secret),
  SourceKind.sftp => SftpPlugin(config, secret),
  SourceKind.s3 => S3Plugin(config, secret),
  SourceKind.plex => PlexPlugin(config, SourceHttp(config, secret)),
  SourceKind.jellyfin ||
  SourceKind.emby => JellyfinPlugin(config, SourceHttp(config, secret)),
  SourceKind.dlna => DlnaPlugin(config),
};

class SourceSelection {
  const SourceSelection(this.name, this.stream, {this.ref, this.entry});
  final SourceEntry? entry;
  final ResourceRef? ref;
  final String name;
  final PlayableStream stream;
}

class SourceInstanceImpact {
  const SourceInstanceImpact({this.playing = 0, this.running = 0});
  final int playing;
  final int running;
}

/// Plugin Manager is the sole UI entry point. Configuration/credentials are host
/// services; providers receive only their own immutable snapshot and clients.
enum SourceApplicationStatus { disabled, ready, failed, initialized, saved }

/// A change to a connection that others react to (the library drops the
/// file sources of a removed connection). Sources do not know who listens.
sealed class SourceChange {
  const SourceChange(this.id);
  final String id;
}

class SourceDirectoryChanged extends SourceChange {
  const SourceDirectoryChanged() : super('');
}

class SourceRemoved extends SourceChange {
  const SourceRemoved(super.id);
}

class SourceEnabledChanged extends SourceChange {
  const SourceEnabledChanged(super.id, this.enabled);
  final bool enabled;
}

class SourceManager {
  SourceManager({
    SourceConfigurationService? configuration,
    SourceStateStore? sourceState,
    SourceSecureStore? secureStore,
    RemoteAccessService? remoteAccess,
    Future<void> Function(Map<String, dynamic> outbound, int port)?
    remoteCoreValidator,
  }) : _configuration = configuration,
       _ownsConfiguration = configuration == null,
       // An injected configuration (tests) gets a throwaway state store.
       _state =
           sourceState ??
           (configuration == null
               ? null
               : SourceStateStore(sqlite3.openInMemory())) {
    _credentials = SourceCredentialBroker(
      () => _configuration!,
      secureStore: secureStore,
    );
    _remoteCoreValidator = remoteCoreValidator ?? _checkRemoteCore;
    _remote =
        remoteAccess ??
        (configuration == null ? null : RemoteAccessService.memory());
  }
  SourceConfigurationService? _configuration;
  final bool _ownsConfiguration;

  /// Runtime state per instance (`source_state` in library.sqlite3).
  SourceStateStore? _state;
  bool _ownsState = false;
  late final SourceCredentialBroker _credentials;
  late final Future<void> Function(Map<String, dynamic> outbound, int port)
  _remoteCoreValidator;

  /// Starts and stops the embedded sing-box core once with an imported
  /// outbound, so a broken App file is rejected before it is saved.
  static Future<void> _checkRemoteCore(
    Map<String, dynamic> outbound,
    int port,
  ) async {
    final core = RemoteNative.instance;
    core.stop(core.start(outbound, port));
  }

  RemoteAccessService? _remote;
  Future<RemoteAccessService>? _openingRemote;
  Future<RemoteAccessService> get remoteSettings =>
      _openingRemote ??= (() async {
        final service = _remote ??= RemoteAccessService(
          (_configuration ??= await SourceConfigurationService.open()).db,
        );
        try {
          await service.load();
          return service;
        } catch (_) {
          _openingRemote = null;
          rethrow;
        }
      })();
  StreamSubscription<void>? _networkChanges;
  bool _hasBookmarks = false;
  bool _disposed = false;
  final _configs = <SourceConfig>[];
  final _runtimes = <String, _SourceRuntime>{};
  final _retired = <_SourceRuntime>{};
  final _creating = <String, Future<_SourceRuntime>>{};
  final _cloudSessions = <String, (int, CloudTokenSession)>{};
  final _openingCloudSessions = <String, Future<CloudTokenSession>>{};
  List<SourceConfig> get configs => List.unmodifiable(
    _configs.where(
      (c) => _remote?.ownsSource(c.remote) ?? c.remote?.accountId == null,
    ),
  );
  bool get platformSignedIn => _remote?.account.signedIn ?? false;

  /// Whether connector sources are synced at all: platform mode is on and an
  /// account is signed in. Remote access is optional; without it the Sources
  /// page shows no connector UI.
  bool get syncsDiscoveredSources =>
      (_remote?.usePlatform ?? false) && platformSignedIn;
  String? get sourceSyncError => _remote?.platformError;
  List<DiscoveredSource> get discoveredSources =>
      _remote?.discoveredSources ?? const [];
  DiscoveredSource? discoveredFor(SourceConfig source) => discoveredSources
      .where(
        (s) =>
            s.serviceId == source.remote?.proxy &&
            s.accountId == source.remote?.accountId &&
            s.connectorId == source.remote?.connectorId,
      )
      .firstOrNull;
  bool sourceHidden(DiscoveredSource source) =>
      _remote?.isSourceHidden(source) ?? false;
  List<SourceConfig> get visibleConfigs => configs.where((c) {
    final entry = discoveredFor(c);
    return entry == null || !sourceHidden(entry);
  }).toList();
  List<DiscoveredSource> get pendingDiscoveredSources => discoveredSources
      .where(
        (s) =>
            s.kind != null &&
            s.status != 'removed' &&
            !sourceHidden(s) &&
            !configs.any(
              (c) =>
                  c.remote?.proxy == s.serviceId &&
                  c.remote?.accountId == s.accountId,
            ),
      )
      .toList();
  Future<void> hideDiscoveredSource(
    DiscoveredSource source,
    bool hidden,
  ) async => (await remoteSettings).setSourceHidden(source, hidden);

  Future<void> syncDiscoveredSources() async {
    await load();
    final remote = await remoteSettings;
    if (remote.usePlatform && remote.account.signedIn) {
      await remote.refreshPlatform();
    }
  }

  bool sourceVisibleToAccount(String id) {
    final config = _configs.where((c) => c.id == id).firstOrNull;
    return config == null ||
        (_remote?.ownsSource(config.remote) ??
            config.remote?.accountId == null);
  }

  /// The shared configuration service once [load] completed.
  SourceConfigurationService? get configuration => _configuration;

  /// App-wide capability switches, stored with the configuration; every
  /// window and isolate reads the same switches.
  late final CapabilitySwitches switches = CapabilitySwitches(
    () => _configuration == null
        ? null
        : ConfigurationSwitchStore(() => _configuration!),
  );

  /// Saved vs. applied revision and last error code of one instance.
  Map<String, Object?>? application(String id) => _state?.get(id);
  List<ConfigurationIssue> get configurationIssues =>
      List.unmodifiable(_configuration?.issues ?? []);
  SourceBindings get bindings =>
      _configuration?.bindings() ?? const SourceBindings();
  static const _bookmarks = MethodChannel('openplayx/source_access');

  /// Local folders outside the sandbox need a security-scoped bookmark.
  static bool get _usesBookmarks => Platform.isMacOS || Platform.isIOS;

  /// Asks the user for a local folder; null when cancelled. iOS has no
  /// `file_selector` folder picker, so it uses the native one, which also
  /// opens the folder's access for this session.
  static Future<String?> pickLocalFolder() => Platform.isIOS
      ? _bookmarks.invokeMethod<String>('pickDirectory')
      : getDirectoryPath();
  Future<void>? _loading;
  Future<void> load() => _loading ??= _load().catchError((Object error) {
    _loading = null;
    throw error;
  });
  Future<void> _load() async {
    _configuration ??= await SourceConfigurationService.open();
    if (_state == null) {
      _state = SourceStateStore(await LibraryDatabase.open('library.sqlite3'));
      _ownsState = true;
    }
    final remote = await remoteSettings;
    _migrateDiscoveredSources(remote);
    final records = _configuration!.load();
    _configs
      ..clear()
      ..addAll(records.map(remote.attach));
    remote.onChanged = _reattach;
    _networkChanges ??= RemoteTransport.networkChanges.listen(
      (_) => networkChanged(),
    );
    remote.startSubscription();
  }

  void _migrateDiscoveredSources(RemoteAccessService remote) {
    if (!remote.usePlatform || remote.platformProfile?.valid != true) return;
    for (final c in _configuration!.load()) {
      final link = c.remote;
      if (link == null) continue;
      if (link.accountId != null && !remote.ownsSource(link)) continue;
      if (link.accountId == null &&
          remote.customNetwork.proxy(link.proxy) != null) {
        continue;
      }
      final entry = remote.discoveredSources
          .where(
            (s) =>
                s.serviceId == link.proxy &&
                (link.accountId == null ||
                    link.accountId == s.accountId &&
                        link.connectorId == s.connectorId),
          )
          .firstOrNull;
      if (entry == null || entry.kind != c.kind) continue;
      final local = link.managedLocal && entry.supportsLocal
          ? entry.localAccess
          : null;
      final next = c.copyWith(
        name: link.serviceName != null && c.name == link.serviceName
            ? entry.name
            : c.name,
        address: link.accountId != null && entry.descriptor != null
            ? entry.draft().address
            : c.address,
        remote: SourceRemote(
          proxy: link.proxy,
          accountId: entry.accountId,
          connectorId: entry.connectorId,
          serviceName: entry.name,
          managedLocal: link.managedLocal,
          mode:
              link.managedLocal &&
                  !entry.supportsLocal &&
                  link.mode == RemoteConnectionMode.automatic
              ? RemoteConnectionMode.remoteOnly
              : link.mode,
          localAddress: local?['endpoint'] as String? ?? link.localAddress,
          localTlsSha256:
              (local?['identity'] as Map?)?['value'] as String? ??
              link.localTlsSha256,
        ),
      );
      if (jsonEncode(c.toJson()) != jsonEncode(next.toJson())) {
        _configuration!.save(next, expectedRevision: c.revision);
      }
    }
  }

  Future<void> reload() async {
    await load();
    final remote = await remoteSettings;
    _migrateDiscoveredSources(remote);
    final next = _configuration!.load().map(remote.attach).toList();
    for (final runtime in _runtimes.values.toList()) {
      if (!next.any(
        (c) =>
            c.id == runtime.config.id &&
            c.revision == runtime.config.revision &&
            jsonEncode(c.remoteAccess?.toJson()) ==
                jsonEncode(runtime.config.remoteAccess?.toJson()) &&
            c.enabled,
      )) {
        await _retire(runtime.config.id);
      }
    }
    for (final entry in _cloudSessions.entries.toList()) {
      if (!next.any((c) => c.id == entry.key && c.revision == entry.value.$1)) {
        await _retire(entry.key);
      }
    }
    _configs
      ..clear()
      ..addAll(next);
  }

  SourceConfig _config(String id) =>
      configs.where((c) => c.id == id).firstOrNull ??
      (throw PluginException('notFound', appStrings.errSourceMissing));

  /// The saved password or token of a configured source, for the edit form
  /// to show masked. Null when none is saved or the source is unknown.
  Future<String?> storedSecret(String id) async {
    final config = configs.where((c) => c.id == id).firstOrNull;
    return config == null ? null : _credentials.readForHost(config);
  }

  Future<void> save(SourceConfig config, String secret) async {
    SourceSchemas.validate(config);
    await load();
    final previous = _configs.where((c) => c.id == config.id).firstOrNull;
    if (previous != null && previous.kind != config.kind) {
      throw PluginException('invalidInput', appStrings.errSourceKindChange);
    }
    final remote = await remoteSettings;
    var saved = config.copyWith(
      pluginVersion: SourceSchemas.forKind(config.kind).version,
      hasSecret: previous?.hasSecret ?? false,
    );
    if (_usesBookmarks && config.kind == SourceKind.local) {
      final bookmark =
          previous?.address == config.address && previous?.bookmark != null
          ? previous!.bookmark
          : await _bookmarks.invokeMethod<String>('create', config.address);
      saved = saved.copyWith(bookmark: bookmark);
    }
    String? newSecret;
    if (config.kind != SourceKind.local &&
        config.kind != SourceKind.dlna &&
        (secret.isNotEmpty ||
            previous == null &&
                (config.kind.optionalCredential ||
                    config.kind == SourceKind.sftp) &&
                config.username.isNotEmpty)) {
      newSecret = secret;
    }
    if (config.kind.requiresSecret) {
      final effective =
          newSecret ??
          (previous == null ? null : await _credentials.readForHost(previous));
      if (effective?.isNotEmpty != true) {
        throw PluginException('authRequired', appStrings.errTokenRequired);
      }
    }
    if (config.kind.oauth) await _retire(config.id);
    final oldReference = _configuration!.readSecret(config.id);
    String? staged;
    if (newSecret != null && (config.kind.oauth || config.presetId != null)) {
      staged = await _credentials.stage(config.id, newSecret);
      newSecret = staged;
    }
    try {
      saved = _configuration!.save(
        saved,
        expectedRevision: config.revision,
        secret: newSecret,
      );
    } catch (_) {
      await _credentials.discard(staged, instanceId: config.id);
      rethrow;
    }
    if (staged != null) {
      await _credentials.discard(oldReference, instanceId: config.id);
    }
    _state?.reset(
      saved.id,
      saved.revision,
      saved.enabled ? 'pending' : 'disabled',
    );
    // Existing playback keeps the retired provider's lease.
    saved = remote.attach(saved);
    final index = _configs.indexWhere((c) => c.id == saved.id);
    if (index < 0) {
      _configs.add(saved);
    } else {
      _configs[index] = saved;
    }
    await _retire(saved.id);
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await save(_config(id).copyWith(enabled: enabled), '');
    announce(SourceEnabledChanged(id, enabled));
  }

  // Synchronous: listeners have reacted when the change returns.
  final _changes = StreamController<SourceChange>.broadcast(sync: true);

  /// Connection changes, delivered while the change is being made.
  Stream<SourceChange> get changes => _changes.stream;

  /// Tells listeners about [change]; subclasses replacing [remove] or
  /// [setEnabled] call it too.
  @protected
  void announce(SourceChange change) {
    if (!_changes.isClosed) _changes.add(change);
  }

  SourceInstanceImpact impact(String id) {
    final runtimes = [
      if (_runtimes[id] != null) _runtimes[id]!,
      ..._retired.where((r) => r.config.id == id),
    ];
    return SourceInstanceImpact(
      playing: runtimes.fold(0, (sum, r) => sum + r.streams),
      running: runtimes.fold(0, (sum, r) => sum + r.active),
    );
  }

  Future<void> remove(String id) async {
    await load();
    final config = _config(id);
    final reference = _configuration!.readSecret(id);
    await _retire(id);
    await _credentials.discard(reference, instanceId: config.id);
    _configuration!.remove(id, config.revision);
    _state?.delete(id);
    _configs.removeWhere((c) => c.id == id);
    announce(SourceRemoved(id));
  }

  /// Records the outcome of applying [config], unless it was edited since.
  void _markApplication(
    SourceConfig config,
    String status, {
    String? errorCode,
  }) {
    if (!_configs.any(
      (c) => c.id == config.id && c.revision == config.revision,
    )) {
      return;
    }
    _state?.mark(config.id, config.revision, status, errorCode: errorCode);
  }

  Future<void> _retire(String id) async {
    _cloudSessions.remove(id)?.$2.close();
    final runtime = _runtimes.remove(id);
    if (runtime == null) return;
    _retired.add(runtime);
    if (runtime.provider is CloudFileSource) {
      await (runtime.provider as Plugin).dispose();
    }
    await runtime.retire();
  }

  SourceCredentialStatus credentialStatus(String id) {
    final config = _config(id);
    final state = _state?.get(id);
    final sameRevision = state?['desired_revision'] == config.revision;
    return _credentials.status(
      config,
      verified: sameRevision && state?['status'] == 'ready',
      rejected: sameRevision && state?['error_code'] == 'authRequired',
    );
  }

  SourceApplicationStatus applicationStatus(String id) {
    final config = _config(id);
    if (_remote != null &&
        config.remote?.accountId != null &&
        !_remote!.sourceAuthorized(config.remote!)) {
      return SourceApplicationStatus.failed;
    }
    if (!config.enabled) return SourceApplicationStatus.disabled;
    final state = _state?.get(id);
    return switch (state?['status']) {
      'ready' => SourceApplicationStatus.ready,
      'failed' => SourceApplicationStatus.failed,
      'initialized' => SourceApplicationStatus.initialized,
      _ => SourceApplicationStatus.saved,
    };
  }

  String applicationLabel(String id) => switch (applicationStatus(id)) {
    SourceApplicationStatus.disabled => appStrings.srcStatusDisabled,
    SourceApplicationStatus.ready => appStrings.srcStatusReady,
    SourceApplicationStatus.failed => appStrings.srcStatusFailed,
    SourceApplicationStatus.initialized => appStrings.srcStatusInitialized,
    SourceApplicationStatus.saved => appStrings.srcStatusSaved,
  };

  /// Global suffix filter shared by preview scans and library scans.
  List<String> get scanExtensions =>
      _configuration?.scanExtensions() ?? defaultScanExtensions;

  /// Choices offered in Settings for the shared artwork disk cache, in MiB.
  static const artworkCacheQuotaChoicesMb = [128, 256, 512, 1024, 2048];
  static const defaultArtworkCacheQuotaMb = 256;

  /// Device-local artwork cache limit; read on every eviction so all
  /// ArtworkService instances over the shared cache follow one value.
  int get artworkCacheQuotaMb {
    final value = _configuration?.artworkCacheQuotaMb();
    return artworkCacheQuotaChoicesMb.contains(value)
        ? value!
        : defaultArtworkCacheQuotaMb;
  }

  Future<void> setArtworkCacheQuotaMb(int value) async {
    await load();
    if (!artworkCacheQuotaChoicesMb.contains(value)) {
      throw PluginException('invalidInput', appStrings.errArtworkCacheLimit);
    }
    _configuration!.saveArtworkCacheQuotaMb(value);
  }

  Future<void> setScanExtensions(List<String> extensions) async {
    await load();
    if (extensions.length > 100 ||
        extensions.any((e) => !RegExp(r'^[a-z0-9]{1,16}$').hasMatch(e))) {
      throw PluginException('invalidInput', appStrings.errExtensions);
    }
    _configuration!.saveScanExtensions(extensions);
  }

  Future<CloudTokenSession> cloudTokenSession(SourceConfig config) async {
    if (!_configs.any(
      (c) => c.id == config.id && c.revision == config.revision,
    )) {
      throw PluginException('cancelled', appStrings.errInstanceChanged);
    }
    final current = _cloudSessions[config.id];
    if (current != null &&
        current.$1 == config.revision &&
        !current.$2.isClosed) {
      return current.$2;
    }
    final key = '${config.id}:${config.revision}';
    return _openingCloudSessions[key] ??=
        (() async {
          final secret = await _credentials.readForHost(config);
          if (_disposed ||
              secret == null ||
              !_configs.any(
                (c) => c.id == config.id && c.revision == config.revision,
              )) {
            throw PluginException('authRequired', appStrings.cloudReauthorize);
          }
          late final CloudTokenSession session;
          session = CloudTokenSession(
            config.kind,
            CloudTokens.decode(secret),
            persist: (next) async {
              final old = _configuration!.readSecret(config.id);
              if (old == null) {
                throw PluginException(
                  'cancelled',
                  appStrings.errInstanceChanged,
                );
              }
              final reference = await _credentials.stage(
                config.id,
                next.encode(),
              );
              if (session.isClosed ||
                  !_configuration!.replaceSecret(
                    config.id,
                    old,
                    reference,
                    expectedRevision: config.revision,
                  )) {
                await _credentials.discard(reference, instanceId: config.id);
                throw PluginException(
                  'cancelled',
                  appStrings.errInstanceChanged,
                );
              }
              await _credentials.discard(old, instanceId: config.id);
            },
          );
          _cloudSessions[config.id]?.$2.close();
          _cloudSessions[config.id] = (config.revision, session);
          return session;
        })().whenComplete(() {
          unawaited(_openingCloudSessions.remove(key));
        });
  }

  Future<_SourceRuntime> _runtime(String id) async {
    await load();
    final config = _config(id);
    if (config.remote?.accountId != null &&
        _remote?.sourceAuthorized(config.remote!) != true) {
      throw PluginException(
        'remoteUnavailable',
        appStrings.connectorSourceAccount,
      );
    }
    if (!config.enabled) {
      throw PluginException('disabled', appStrings.errSourceDisabled);
    }
    if (!switches.enabled(config.providerId)) {
      throw PluginException('disabled', appStrings.errPluginDisabled);
    }
    if (!config.kind.oauth &&
        config.credentialExpiresAt != null &&
        !config.credentialExpiresAt!.isAfter(DateTime.now())) {
      throw PluginException('authRequired', appStrings.errTokenExpired);
    }
    if (config.remote?.accountId != null) withRemoteRoute(config);
    final existing = _runtimes[id];
    if (existing != null) return existing;
    return _creating[id] ??= _create(config).whenComplete(() {
      unawaited(_creating.remove(id));
    });
  }

  Future<_SourceRuntime> _create(SourceConfig config) async {
    final status = _credentials.status(config);
    if ([
      SourceAuthorization.expired,
      SourceAuthorization.missing,
    ].contains(status.authorization)) {
      throw PluginException('authRequired', status.label);
    }
    var pluginConfig = SourceConfig.fromJson({
      ...config.toJson(),
      'bookmark': null,
    });
    if (_usesBookmarks &&
        config.kind == SourceKind.local &&
        config.bookmark != null) {
      final String? path;
      try {
        path = await _bookmarks.invokeMethod<String>(
          'restore',
          config.bookmark,
        );
      } on PlatformException catch (error) {
        if (error.code != 'permissionDenied') rethrow;
        throw PluginException(
          'permissionDenied',
          appStrings.errReselectLocalFolder,
        );
      }
      if (path == null) {
        throw PluginException(
          'permissionDenied',
          appStrings.errReselectLocalFolder,
        );
      }
      _hasBookmarks = true;
      pluginConfig = pluginConfig.copyWith(address: path);
    }
    pluginConfig = withRemoteRoute(pluginConfig);
    final storedSecret = await _credentials.readForHost(config);
    final secret = storedSecret ?? '';
    if ((config.hasSecret && storedSecret == null) ||
        (config.kind.requiresSecret && secret.isEmpty)) {
      throw PluginException(
        'authRequired',
        appStrings.errCredentialsUnavailable,
      );
    }
    final provider = createSourceProvider(
      pluginConfig,
      secret,
      cloudSession: config.kind.oauth ? await cloudTokenSession(config) : null,
    );
    if (_disposed ||
        !_configs.any(
          (c) =>
              c.id == config.id && c.revision == config.revision && c.enabled,
        )) {
      await (provider as Plugin).dispose();
      throw PluginException('cancelled', appStrings.errInstanceChanged);
    }
    final runtime = _SourceRuntime(config, provider);
    _runtimes[config.id] = runtime;
    _markApplication(config, 'initialized');
    return runtime;
  }

  Future<T> _call<T>(
    String id,
    Future<T> Function(_SourceRuntime) action, {
    Future<void> Function(T)? releaseLate,
  }) async {
    await load();
    final config = _config(id);
    var expired = false;
    try {
      final pending = (() async {
        final runtime = await _runtime(id);
        final value = await runtime.run(() {
          if (expired) {
            throw PluginException('cancelled', appStrings.errRequestTimedOut);
          }
          return action(runtime);
        });
        if (expired) await releaseLate?.call(value);
        if (!_disposed &&
            !expired &&
            _configs.any((c) => c.id == id && c.revision == config.revision)) {
          _markApplication(config, 'ready');
        }
        return value;
      })();
      return await pending.timeout(
        Duration(seconds: config.requestTimeoutSeconds),
        onTimeout: () {
          expired = true;
          throw TimeoutException('source');
        },
      );
    } catch (error) {
      final failure = error is PluginException
          ? error
          : error is TimeoutException
          ? PluginException(
              'timeout',
              appStrings.errConnectTimeout,
              retryable: true,
            )
          : PluginException(
              'networkUnavailable',
              appStrings.errSourceUnreachable,
              retryable: true,
            );
      if (!_disposed &&
          config.enabled &&
          ![
            'invalidInput',
            'cancelled',
            'disabled',
            'quotaExceeded',
          ].contains(failure.code) &&
          _configs.any((c) => c.id == id && c.revision == config.revision)) {
        _markApplication(config, 'failed', errorCode: failure.code);
      }
      throw failure;
    }
  }

  Future<BrowseResult> browse(String id, BrowseRequest request) =>
      _call(id, (runtime) async {
        if (request.offset < 0 || request.limit < 1 || request.limit > 200) {
          throw PluginException('invalidInput', appStrings.errInvalidPaging);
        }
        return runtime.provider.browse(request, CallContext.forInstance(id));
      });
  Future<BrowseResult> search(
    String id,
    String query, {
    int offset = 0,
    int limit = 20,
  }) => _call(id, (runtime) async {
    if (query.trim().isEmpty ||
        query.length > 200 ||
        offset < 0 ||
        limit < 1 ||
        limit > 40) {
      throw PluginException('invalidInput', appStrings.errInvalidSearchPaging);
    }
    final provider = runtime.provider;
    if (provider is! SearchCapability) {
      throw PluginException('unsupported', appStrings.errSearchUnsupported);
    }
    return (provider as SearchCapability).search(
      query,
      BrowseRequest(offset: offset, limit: limit),
      CallContext.forInstance(id),
    );
  });

  /// Items for a media server's shelf: its newest additions when it can list
  /// them, otherwise the first entries of its root.
  Future<List<SourceEntry>> featured(String id, {int limit = 20}) =>
      _call(id, (runtime) async {
        final provider = runtime.provider;
        final context = CallContext.forInstance(id);
        if (provider is RecentCapability) {
          return (provider as RecentCapability).recent(limit, context);
        }
        return (await provider.browse(
          BrowseRequest(limit: limit),
          context,
        )).entries;
      });

  Future<PlayableStream> resolve(ResourceRef resource) =>
      _call(resource.instanceId, (runtime) async {
        final stream = await runtime.provider.resolve(
          ResolveRequest(resource),
          CallContext.forInstance(resource.instanceId),
        );
        runtime.streams++;
        return PlayableStream(
          stream.uri,
          release: () async {
            try {
              await stream.release();
            } finally {
              runtime.streams--;
              await runtime.cleanup();
            }
          },
        );
      }, releaseLate: (stream) => stream.release());
  Future<ResourceRef?> parent(ResourceRef ref) =>
      _call(ref.instanceId, (runtime) async {
        final provider = runtime.provider;
        if (provider is SourceHierarchyCapability) {
          return (provider as SourceHierarchyCapability).parent(
            ref,
            CallContext.forInstance(ref.instanceId),
          );
        }
        final slash = ref.id.replaceFirst(RegExp(r'/+$'), '').lastIndexOf('/');
        if (slash < 0) return null;
        return ResourceRef(
          ref.instanceId,
          slash == 0 ? '/' : ref.id.substring(0, slash),
        );
      });

  Future<MetadataResult> lookupMetadata(String id, MetadataRequest request) =>
      _call(id, (runtime) async {
        final provider = runtime.provider;
        if (provider is! MetadataCapability) {
          throw PluginException(
            'unsupported',
            appStrings.errMetadataUnsupported,
          );
        }
        return (provider as MetadataCapability).lookup(
          request,
          CallContext.forInstance(id),
        );
      });

  Future<List<int>> readAttachment(
    ResourceRef ref, {
    int maxBytes = 1024 * 1024,
  }) => _call(ref.instanceId, (runtime) async {
    final provider = runtime.provider;
    if (provider is! SourceAttachmentCapability) {
      throw PluginException(
        'unsupported',
        appStrings.errAttachmentsUnsupported,
      );
    }
    return (provider as SourceAttachmentCapability).readAttachment(
      ref,
      CallContext.forInstance(ref.instanceId),
      maxBytes: maxBytes,
    );
  });

  /// Writes [source] as a new file into the host-chosen `OpenPlayX` folder
  /// of [near]'s share and returns the new entry. Never overwrites. Uses its
  /// own size-based timeout instead of the short browse timeout.
  Future<SourceEntry> writeNewFile(
    ResourceRef near,
    String name,
    File source,
  ) async {
    await load();
    final config = _config(near.instanceId);
    final runtime = await _runtime(near.instanceId);
    final provider = runtime.provider;
    if (provider is! SourceWriteCapability) {
      throw PluginException('unsupported', appStrings.errWriteUnsupported);
    }
    final bytes = await source.length();
    // 30 s plus 1 MB/s worst case; a LAN SMB write is far faster.
    final limit = Duration(seconds: 30 + bytes ~/ (1024 * 1024));
    final entry = await runtime
        .run(
          () => (provider as SourceWriteCapability).writeNewFile(
            near,
            name,
            source,
            CallContext.forInstance(near.instanceId),
          ),
        )
        .timeout(
          limit,
          onTimeout: () =>
              throw PluginException('timeout', appStrings.errWriteTimeout),
        );
    if (!_disposed &&
        _configs.any(
          (c) => c.id == config.id && c.revision == config.revision,
        )) {
      _markApplication(config, 'ready');
    }
    return entry;
  }

  /// Root/folder writes do not need a reference to existing media.
  Future<SourceEntry> writeNewStream(
    String instanceId,
    String name,
    Stream<List<int>> stream,
    int length, {
    String? folder,
    File? cachedFile,
    SourceWriteCancellation? cancellation,
  }) async {
    await load();
    final config = _config(instanceId);
    final runtime = await _runtime(instanceId);
    final provider = runtime.provider;
    if (!config.enabled || provider is! SourceWriteCapability) {
      throw const PluginException(
        'sourceNotWritable',
        'Target source is not writable.',
      );
    }
    return runtime.run(
      () => cachedFile == null
          ? (provider as SourceWriteCapability).writeNewStream(
              stream,
              length,
              name,
              CallContext.forInstance(instanceId),
              folder: folder,
              cancellation: cancellation,
            )
          : (provider as SourceWriteCapability).writeNewFile(
              ResourceRef(instanceId, config.rootPath),
              name,
              cachedFile,
              CallContext.forInstance(instanceId),
              folder: folder ?? 'OpenPlayX/Downloads',
              cancellation: cancellation,
            ),
    );
  }

  /// The App-wide Relay connection (sing-box outbound + frpc proxies).
  RemoteNetwork get remoteNetwork => _remote?.network ?? const RemoteNetwork();

  /// [config] with its remote route resolved against [remoteNetwork]. A
  /// source that asks for remote access never silently connects directly.
  SourceConfig withRemoteRoute(SourceConfig config) {
    final network = remoteNetwork;
    if (config.remote?.accountId != null) {
      final entry = discoveredFor(config);
      if (entry == null ||
          entry.kind != config.kind ||
          config.remote!.managedLocal &&
              config.remote!.mode == RemoteConnectionMode.localOnly &&
              !entry.supportsLocal) {
        throw PluginException(
          'remoteUnavailable',
          appStrings.connectorSourceProtocolChanged,
        );
      }
    }
    final route = _remote == null
        ? network.routeFor(config.remote)
        : _remote!.routeFor(config.remote);
    if (config.remote != null && route == null) {
      throw PluginException(
        'remoteUnavailable',
        config.remote!.accountId == null
            ? appStrings.errSourceProxyMissing
            : _remote?.sourceAuthorized(config.remote!) == true
            ? appStrings.connectorSourceNotReady
            : appStrings.connectorSourceAccount,
      );
    }
    return config.copyWith(
      remoteAccess: route,
      clearRemoteAccess: route == null,
      remoteRuntimePolicy: network.runtimePolicy,
    );
  }

  /// Imports the App file exported by Relay and re-resolves every source.
  Future<void> importRemotePairing(String text) async {
    final remote = await remoteSettings;
    await remote.importPairing(text, check: _remoteCoreValidator);
    await _reattach();
  }

  Future<void> clearRemoteNetwork() async {
    await (await remoteSettings).clear();
    await _reattach();
  }

  Future<void> saveRemotePolicy(RemoteNetwork policy) async {
    await (await remoteSettings).savePolicy(policy);
    await _reattach();
  }

  /// Rebuilds runtime routes after the network layer changed; runtimes whose
  /// route changed are retired (existing playback keeps its lease).
  Future<void> _reattach() async {
    await load();
    final remote = await remoteSettings;
    _migrateDiscoveredSources(remote);
    final next = _configuration!.load().map(remote.attach).toList();
    for (final source in next) {
      if (jsonEncode(_runtimes[source.id]?.config.remoteAccess?.toJson()) !=
          jsonEncode(source.remoteAccess?.toJson())) {
        await _retire(source.id);
      }
    }
    _configs
      ..clear()
      ..addAll(next);
    announce(const SourceDirectoryChanged());
  }

  void networkChanged() {
    RemoteTransport.networkChanged();
    // Retire cached clients for new work; existing playback retains its lease.
    for (final runtime in _runtimes.values.toList()) {
      if (runtime.config.remote != null) unawaited(_retire(runtime.config.id));
    }
  }

  bool? connectionUsesLocal(String id) {
    if (applicationStatus(id) != SourceApplicationStatus.ready) return null;
    final path = RemoteTransport.selectedPaths[id];
    return path != null &&
            DateTime.now().difference(path.$2) < const Duration(seconds: 30)
        ? path.$1
        : null;
  }

  Future<void> testConnection(String id) async {
    var success = false;
    final analyticsTimer = Stopwatch()..start();
    final sourceType =
        configs.where((c) => c.id == id).firstOrNull?.kind.name ?? 'unknown';
    try {
      await browse(id, const BrowseRequest(limit: 1));
      success = true;
    } finally {
      unawaited(
        AnalyticsService.instance.capture('source_connection_completed', {
          'source_type': sourceType,
          'duration_ms': analyticsTimer.elapsedMilliseconds,
          'success': success,
        }),
      );
    }
  }

  Future<void> testDraft(SourceConfig draft, String secret) async {
    var success = false;
    final analyticsTimer = Stopwatch()..start();
    try {
      await _testDraft(draft, secret);
      success = true;
    } finally {
      unawaited(
        AnalyticsService.instance.capture('source_connection_completed', {
          'source_type': draft.kind.name,
          'duration_ms': analyticsTimer.elapsedMilliseconds,
          'success': success,
        }),
      );
    }
  }

  Future<void> _testDraft(SourceConfig draft, String secret) async {
    SourceSchemas.validate(draft);
    final existing = configs.where((c) => c.id == draft.id).firstOrNull;
    if (existing != null && draft.revision != existing.revision) {
      throw PluginException('conflict', appStrings.errReloadBeforeTest);
    }
    var config = withRemoteRoute(
      SourceConfig.fromJson({...draft.toJson(), 'bookmark': null}),
    );
    final value = secret.isNotEmpty
        ? secret
        : existing == null
        ? ''
        : await _credentials.readForHost(existing) ?? '';
    if (config.kind.requiresSecret && value.isEmpty) {
      throw PluginException('authRequired', appStrings.errTokenRequired);
    }
    final sharedSession =
        config.kind.oauth && secret.isEmpty && existing != null;
    final provider = createSourceProvider(
      config,
      value,
      cloudSession: sharedSession ? await cloudTokenSession(existing) : null,
      ownsCloudSession: !sharedSession,
    );
    final operation = provider.browse(
      const BrowseRequest(limit: 1),
      CallContext.forInstance(config.id),
    );
    // Timeout does not prematurely tear down an operation still using a handle.
    final completed = operation.whenComplete(
      () => (provider as Plugin).dispose(),
    );
    try {
      await completed.timeout(Duration(seconds: draft.requestTimeoutSeconds));
    } on TimeoutException {
      if (provider is CloudFileSource) await (provider as Plugin).dispose();
      throw PluginException('timeout', appStrings.errTestTimeout);
    } on PluginException {
      rethrow;
    } catch (_) {
      throw PluginException('networkUnavailable', appStrings.errTestFailed);
    }
  }

  Stream<SourceEntry> scan(String id, {int limit = 500}) async* {
    final config = _config(id);
    if (!config.isFileSource || config.scanMode == ScanMode.disabled) {
      throw PluginException('unsupported', appStrings.errManualScanDisabled);
    }
    if (limit < 1 || limit > 5000) {
      throw PluginException('invalidInput', appStrings.errScanLimit);
    }
    final runtime = await _runtime(id);
    final fileRoot = config.kind == SourceKind.local
        ? await Directory(
            (runtime.provider as LocalFolderPlugin).config.address,
          ).resolveSymbolicLinks()
        : null;
    var emitted = 0;
    var requests = 0;
    final visited = <String>{};
    final queue = <ResourceRef?>[null];
    while (queue.isNotEmpty && emitted < limit) {
      final node = queue.removeAt(0);
      int? offset = 0;
      do {
        if (++requests > 1000) {
          throw PluginException('quotaExceeded', appStrings.errScanPageLimit);
        }
        final page = await browse(
          id,
          BrowseRequest(node: node, offset: offset!),
        );
        if (_config(id).revision != config.revision) {
          throw PluginException('cancelled', appStrings.errScanConfigChanged);
        }
        for (final entry in page.entries) {
          final relative = config.kind.oauth
              ? entry.name
              : config.kind == SourceKind.local
              ? entry.ref.id
                    .substring(fileRoot!.length)
                    .replaceAll('\\', '/')
                    .replaceFirst(RegExp(r'^/+'), '')
              : entry.ref.id
                    .substring(
                      config.rootPath.replaceFirst(RegExp(r'/+$'), '').length,
                    )
                    .replaceFirst(RegExp(r'^/+'), '');
          if (config.excludedFromScan(relative)) continue;
          if (entry.isFolder) {
            if (visited.add(entry.ref.id)) queue.add(entry.ref);
          } else {
            if (!entry.isDisc &&
                !matchesScanExtension(entry.name, scanExtensions)) {
              continue;
            }
            yield entry;
            if (++emitted >= limit) return;
          }
        }
        offset = page.nextOffset;
      } while (offset != null);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    unawaited(_networkChanges?.cancel());
    _remote?.dispose();
    unawaited(_changes.close());
    for (final id in _runtimes.keys.toList()) {
      await _retire(id);
    }
    for (final runtime in _retired) {
      await runtime.cleanup();
    }
    for (final session in _cloudSessions.values) {
      session.$2.close();
    }
    _cloudSessions.clear();
    if (_hasBookmarks) await _bookmarks.invokeMethod<void>('releaseAll');
    if (_ownsConfiguration) _configuration?.close();
    if (_ownsState) _state?.db.close();
  }
}

class _SourceRuntime {
  _SourceRuntime(this.config, this.provider);
  final SourceConfig config;
  final SourceCapability provider;
  int active = 0;
  int streams = 0;
  bool retired = false;
  bool _closed = false;
  final _waiting = <Completer<void>>[];
  Future<T> run<T>(Future<T> Function() action) async {
    while (active >= config.maxConcurrentRequests && !retired) {
      if (_waiting.length >= 64) {
        throw PluginException('quotaExceeded', appStrings.errTooManyQueued);
      }
      final waiter = Completer<void>();
      _waiting.add(waiter);
      await waiter.future;
    }
    if (retired) {
      throw PluginException('cancelled', appStrings.errInstanceChanged);
    }
    active++;
    try {
      return await action();
    } finally {
      active--;
      if (_waiting.isNotEmpty) _waiting.removeAt(0).complete();
      await cleanup();
    }
  }

  Future<void> retire() async {
    retired = true;
    for (final waiter in _waiting) {
      waiter.complete();
    }
    _waiting.clear();
    await cleanup();
  }

  Future<void> cleanup() async {
    if (retired && active == 0 && streams == 0 && !_closed) {
      _closed = true;
      await (provider as Plugin).dispose();
    }
  }
}
