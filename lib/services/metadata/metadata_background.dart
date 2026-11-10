import 'dart:async';
import 'dart:io';

import 'package:workmanager/workmanager.dart';

import '../../data/sources/source_manager.dart';
import '../library/library_service.dart';
import 'metadata_queue_runner.dart';

const metadataDatabaseName = String.fromEnvironment(
  'OPENPLAYX_METADATA_DATABASE',
  defaultValue: 'library.sqlite3',
);

const metadataCollectTask = 'openplayx.metadata.collect';
const metadataOnlineTask = 'openplayx.metadata.online';
MetadataQueueRunner? _androidRunner;

/// Android invokes this entry point in its own Flutter engine, without a page.
@pragma('vm:entry-point')
void metadataCallbackDispatcher() {
  Workmanager().executeTask(
    (task, input) async {
      if (task != metadataCollectTask && task != metadataOnlineTask) {
        return true;
      }
      LibraryService? library;
      SourceManager? sources;
      MetadataQueueRunner? runner;
      try {
        library = await LibraryService.open(
          recoverInterrupted: false,
          databaseName: metadataDatabaseName,
          watchExternalChanges: false,
        );
        sources = SourceManager();
        await sources.load();
        runner = _androidRunner = MetadataQueueRunner(library, sources);
        await runner.reconcile();
        final online = task == metadataOnlineTask;
        await runner.runBatch(allowOnline: online);
        return !runner.queue.pending(allowOnline: online);
      } catch (_) {
        // Native retry is bounded by the queue's per-item attempt count. Never
        // put tokens, private paths or provider exception bodies into WorkData.
        return false;
      } finally {
        _androidRunner = null;
        await runner?.dispose();
        await sources?.dispose();
        library?.close();
      }
    },
    onTaskStopped: (task, reason) async {
      _androidRunner?.stop();
    },
  );
}

abstract interface class MetadataScheduler {
  bool get native;
  Future<void> initialize();
  Future<void> schedule({bool collect = true, bool online = true});
}

/// WorkManager owns restart/reboot persistence and network/battery constraints.
class AndroidMetadataScheduler implements MetadataScheduler {
  AndroidMetadataScheduler({Workmanager? workmanager})
    : _workmanager = workmanager ?? Workmanager();
  final Workmanager _workmanager;
  @override
  bool get native => Platform.isAndroid;
  static Future<void>? _initialization;
  @override
  Future<void> initialize() async {
    if (!native) return;
    await (_initialization ??= _workmanager
        .initialize(metadataCallbackDispatcher)
        .catchError((Object error) {
          _initialization = null;
          throw error;
        }));
    await _workmanager.registerPeriodicTask(
      'openplayx.metadata.recovery',
      metadataOnlineTask,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  }

  @override
  Future<void> schedule({bool collect = true, bool online = true}) async {
    if (!native) return;
    if (collect) {
      await _workmanager.registerOneOffTask(
        metadataCollectTask,
        metadataCollectTask,
        existingWorkPolicy: ExistingWorkPolicy.keep,
        constraints: Constraints(requiresBatteryNotLow: true),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
      );
    }
    if (online) {
      await _workmanager.registerOneOffTask(
        metadataOnlineTask,
        metadataOnlineTask,
        existingWorkPolicy: ExistingWorkPolicy.keep,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
      );
    }
  }
}
