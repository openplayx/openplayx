import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../data/diagnostics/diagnostics_bootstrap.dart';

import 'dart:async';
import 'dart:io';

import 'package:workmanager/workmanager.dart';

import '../sources/source_manager.dart';
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
      await runWithDiagnostics(DiagnosticRole.background, () async {});
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
      } catch (error, stack) {
        await reportDiagnostic(error, DiagnosticRole.background, stack);
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

/// tvOS launches a dedicated engine for the OS-scheduled processing task.
@pragma('vm:entry-point')
Future<void> tvosMetadataBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('openplayx/tvos_background');
  MetadataQueueRunner? runner;
  LibraryService? library;
  SourceManager? sources;
  channel.setMethodCallHandler((call) async {
    if (call.method == 'stop') runner?.stop();
  });
  var succeeded = false;
  try {
    library = await LibraryService.open(
      recoverInterrupted: false,
      databaseName: metadataDatabaseName,
      watchExternalChanges: false,
    );
    sources = SourceManager();
    await sources.load();
    runner = MetadataQueueRunner(library, sources);
    await runner.reconcile();
    await runner.runBatch(allowOnline: true);
    succeeded = !runner.queue.pending(allowOnline: true);
    if (!succeeded)
      await const MethodChannel('openplayx/tvos')
          .invokeMethod<void>('scheduleMetadata', {'online': true});
  } finally {
    await runner?.dispose();
    await sources?.dispose();
    library?.close();
    await channel.invokeMethod<void>('complete', succeeded);
  }
}

class TVOSMetadataScheduler implements MetadataScheduler {
  static const _channel = MethodChannel('openplayx/tvos');
  @override
  bool get native => Platform.operatingSystem == 'tvos';
  @override
  Future<void> initialize() async {
    if (native) await schedule();
  }

  @override
  Future<void> schedule({bool collect = true, bool online = true}) async {
    if (native && (collect || online))
      await _channel.invokeMethod<void>('scheduleMetadata', {'online': online});
  }
}
