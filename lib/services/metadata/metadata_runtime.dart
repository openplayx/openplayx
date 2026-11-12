import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/sources/source_manager.dart';
import '../library/library_service.dart';
import 'metadata_background.dart';
import 'metadata_queue_runner.dart';

/// App-scoped coordinator. Android executes the queue through WorkManager;
/// desktop executes the same queue while the application process is running.
class MetadataRuntime with WidgetsBindingObserver {
  MetadataRuntime(
    this.library,
    this.sources, {
    MetadataScheduler? scheduler,
    MetadataQueueRunner Function()? runnerFactory,
  }) : scheduler = scheduler ?? AndroidMetadataScheduler(),
       _runnerFactory =
           runnerFactory ?? (() => MetadataQueueRunner(library, sources));
  final LibraryService library;
  final SourceManager sources;
  final MetadataScheduler scheduler;
  final MetadataQueueRunner Function() _runnerFactory;
  MetadataQueueRunner? _runner;
  StreamSubscription<void>? _changes, _priority;
  Timer? _debounce, _poll;
  Future<void>? _draining;
  bool _closed = false,
      _refreshing = false,
      _nativeReady = false,
      _started = false;
  String? _configuration;

  /// Inputs of the last full reconcile. Reconcile is O(library) on the UI
  /// isolate, so the 15s poll and app resume skip it when nothing changed.
  bool _dirty = true;
  String? _reconciled;
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _changes = library.changes.listen((_) {
      _dirty = true;
      _scheduleRefresh();
    });
    // Boosts are picked up by the running batch's next claim; this only wakes
    // an idle runtime so a boosted item does not wait for the 15s poll.
    _priority = library.priorityRequests.listen((_) => _scheduleRefresh());
    _poll = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _scheduleRefresh(),
    );
    try {
      await scheduler.initialize();
      _nativeReady = scheduler.native;
    } catch (_) {
      _nativeReady = false;
    }
    if (!_closed) await refresh();
  }

  void _scheduleRefresh() {
    if (_closed || library.isClosing) return;
    // The running batch emits a change per item; a full reconcile after each
    // one is O(library) on the UI isolate. The batch end schedules one instead.
    if (_draining != null) return;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 200),
      () => unawaited(refresh()),
    );
  }

  Future<void> refresh() async {
    if (_closed || library.isClosing || _refreshing) return;
    _refreshing = true;
    try {
      await sources.reload();
      if (_closed || library.isClosing) return;
      final config =
          '${library.metadata.setting('language')}:${library.metadata.setting('tmdbRevision')}';
      if (_configuration != config) {
        final old = _runner;
        _runner = _runnerFactory();
        if (_configuration != null) _runner!.queue.retryBlocked();
        _configuration = config;
        await old?.dispose();
      }
      _runner ??= _runnerFactory();
      final inputs = [
        config,
        for (final c in sources.configs) '${c.id}:${c.revision}:${c.enabled}',
      ].join('|');
      if (_dirty || _reconciled != inputs) {
        // Cleared first: a change during the reconcile marks it dirty again.
        _dirty = false;
        try {
          await _runner!.reconcile();
          _reconciled = inputs;
        } catch (_) {
          _dirty = true;
          rethrow;
        }
      }
      if (_closed || library.isClosing) return;
      if (_nativeReady) {
        final queue = _runner!.queue;
        if (queue.pending()) {
          await scheduler.schedule(collect: queue.pending(allowOnline: false));
        }
      } else if (_runner!.queue.pending() && _draining == null) {
        final runner = _runner!;
        _draining = runner.runBatch().whenComplete(() {
          _draining = null;
          _scheduleRefresh();
        });
        unawaited(_draining!.catchError((Object _) {}));
      }
    } catch (_) {
      // Queue contents are durable; a source/configuration error must not tear
      // down playback. A later resume, library event or periodic check retries.
    } finally {
      _refreshing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_closed && !library.isClosing) {
      library.checkExternalChanges();
      unawaited(refresh());
    }
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _debounce?.cancel();
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _changes?.cancel();
    await _priority?.cancel();
    await _runner?.dispose();
  }
}
