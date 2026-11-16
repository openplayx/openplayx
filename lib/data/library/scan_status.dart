import '../../l10n/l10n.dart';

/// Scan state of a file source as persisted in `file_source_state.status`.
///
/// The values are stable storage keys (written by earlier versions too), not
/// display text: show them through [label].
abstract final class ScanStatus {
  static const pending = '待扫描';
  static const scanning = '扫描中';
  static const done = '扫描完成';
  static const failed = '扫描失败';
  static const interrupted = '扫描中断';

  /// Error stored with [interrupted] by earlier versions.
  static const legacyRescanError = '请重新扫描';

  static String label(Object? status) => switch (status) {
    pending || null => appStrings.scanStatusPending,
    scanning => appStrings.scanStatusScanning,
    done => appStrings.scanStatusDone,
    failed => appStrings.scanStatusFailed,
    interrupted => appStrings.scanStatusInterrupted,
    _ => '$status',
  };

  /// The stored error message, localized where it is a known fixed value.
  static String? error(Object? error) => switch (error) {
    null => null,
    legacyRescanError => appStrings.scanRescanHint,
    _ => '$error',
  };
}
