import 'package:flutter/foundation.dart';

import '../core/capabilities/source_capability.dart';
import '../data/configuration/source_configuration_service.dart';
import '../l10n/l10n.dart';

/// Providers that need another one switched on: local speech recognition
/// extracts audio with FFmpeg.
const asrWhisperDependencies = ['media.ffmpeg'];
const capabilityDependencies = {'asr.whisper': asrWhisperDependencies};

/// Which capability providers (a source kind, FFmpeg, local speech
/// recognition…) the user switched off.
@immutable
class CapabilitySwitchState {
  const CapabilitySwitchState({
    this.off = const {},
    this.sourceWriteGrants = const {},
    this.revision = 0,
  });

  /// Providers switched off.
  final Set<String> off;

  /// Explicit opt-in for writing new files, per source instance.
  final Set<String> sourceWriteGrants;

  /// Storage revision, for compare-and-set writes.
  final int revision;

  bool isOn(String id) => !off.contains(id);

  CapabilitySwitchState copyWith({
    Set<String>? off,
    Set<String>? sourceWriteGrants,
    int? revision,
  }) => CapabilitySwitchState(
    off: off ?? this.off,
    sourceWriteGrants: sourceWriteGrants ?? this.sourceWriteGrants,
    revision: revision ?? this.revision,
  );

  CapabilitySwitchState withSwitch(String id, bool on) =>
      copyWith(off: on ? (off.toSet()..remove(id)) : {...off, id});

  // Keep source write grants in the existing policy document. Global
  // capability switches were removed, so disabledPlugins is no longer saved
  // or restored; old disabled providers become available again.
  Map<String, dynamic> toJson() => {
    'version': 1,
    'sourceWriteGrants': (sourceWriteGrants.toList()..sort()),
  };

  factory CapabilitySwitchState.fromJson(
    Map<String, dynamic> json,
    int revision,
  ) => CapabilitySwitchState(
    sourceWriteGrants: {
      ...(json['sourceWriteGrants'] as List? ?? const []).cast<String>(),
    },
    revision: revision,
  );
}

/// Storage of the switches.
abstract interface class CapabilitySwitchStore {
  CapabilitySwitchState? read();

  /// Compare-and-set; throws `PluginException('conflict')` on a stale write.
  CapabilitySwitchState write(CapabilitySwitchState next);
}

/// Stores the switches in `configuration.sqlite3` (settings namespace
/// `plugins`, key `policy`, kept from the plugin policy).
class ConfigurationSwitchStore implements CapabilitySwitchStore {
  ConfigurationSwitchStore(this._configuration);
  final SourceConfigurationService Function() _configuration;
  static const _namespace = 'plugins';
  static const _key = 'policy';

  @override
  CapabilitySwitchState? read() {
    final (value, revision) = _configuration().readDocument(_namespace, _key);
    return value == null
        ? null
        : CapabilitySwitchState.fromJson(value, revision);
  }

  @override
  CapabilitySwitchState write(CapabilitySwitchState next) {
    final revision = _configuration().writeDocument(
      _namespace,
      _key,
      next.toJson(),
      expectedRevision: next.revision,
    );
    return next.copyWith(revision: revision);
  }
}

/// In-memory store for tests and builds without a configuration database.
class MemorySwitchStore implements CapabilitySwitchStore {
  CapabilitySwitchState? value;
  @override
  CapabilitySwitchState? read() => value;
  @override
  CapabilitySwitchState write(CapabilitySwitchState next) {
    if ((value?.revision ?? 0) != next.revision) {
      throw PluginException('conflict', appStrings.errSettingsChangedElsewhere);
    }
    return value = next.copyWith(revision: next.revision + 1);
  }
}

/// App-wide capability switches. A provider switched off (or whose
/// dependency is off) accepts no new work anywhere in the App; the AI
/// follows the same switches.
class CapabilitySwitches extends ChangeNotifier {
  /// [store] returns the storage once it is available (the configuration
  /// database opens asynchronously); until then every provider is on.
  CapabilitySwitches(this._resolveStore);

  /// Switches kept in memory only.
  factory CapabilitySwitches.memory() {
    final store = MemorySwitchStore();
    return CapabilitySwitches(() => store);
  }

  final CapabilitySwitchStore? Function() _resolveStore;
  CapabilitySwitchStore? _store;
  CapabilitySwitchState _state = const CapabilitySwitchState();

  CapabilitySwitchStore? _ensure() {
    if (_store != null) return _store;
    final store = _store = _resolveStore();
    if (store != null) {
      _state = store.read() ?? store.write(const CapabilitySwitchState());
    }
    return store;
  }

  CapabilitySwitchState get state {
    _ensure();
    return _state;
  }

  int get revision => state.revision;

  /// The user's switch for [id], dependencies aside.
  bool isOn(String id) => state.isOn(id);

  /// Whether [id] may take new work: on, and its dependencies too.
  bool enabled(String id, [int depth = 0]) {
    if (!isOn(id)) return false;
    if (depth > 8) return false;
    return (capabilityDependencies[id] ?? const <String>[]).every(
      (dep) => enabled(dep, depth + 1),
    );
  }

  /// Switches [id]; throws `PluginException('conflict')` when another window
  /// saved meanwhile.
  void set(String id, bool on) {
    final store = _ensure() ?? (_store = MemorySwitchStore());
    _state = store.write(state.withSwitch(id, on));
    notifyListeners();
  }

  void setSourceWrite(String instanceId, bool allowed) {
    final store = _ensure() ?? (_store = MemorySwitchStore());
    final grants = state.sourceWriteGrants.toSet();
    if (allowed) {
      grants.add(instanceId);
    } else {
      grants.remove(instanceId);
    }
    _state = store.write(state.copyWith(sourceWriteGrants: grants));
    notifyListeners();
  }

  /// Re-reads the stored switches (another window may have saved).
  void reload() {
    final store = _ensure();
    if (store == null) return;
    final stored = store.read();
    if (stored == null) return;
    _state = stored;
    notifyListeners();
  }
}
