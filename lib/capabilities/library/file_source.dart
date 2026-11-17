import 'package:flutter/foundation.dart';

import '../../data/library/scan_status.dart';

/// A folder of a connection that feeds the library (a "file source").
@immutable
class FileSource {
  const FileSource({
    required this.id,
    required this.connectionId,
    required this.enabled,
    this.name,
    this.root,
    this.status = ScanStatus.pending,
    this.error,
  });

  factory FileSource.fromRow(Map<String, Object?> row) => FileSource(
    id: row['id'] as String,
    connectionId: row['source'] as String,
    enabled: row['enabled'] == 1,
    name: row['name'] as String?,
    root: row['root'] as String?,
    status: row['status'] as String? ?? ScanStatus.pending,
    error: row['error'] as String?,
  );

  final String id;

  /// The connection (source instance) the folder belongs to.
  final String connectionId;
  final bool enabled;

  /// User-given name; null shows the connection's name.
  final String? name;

  /// Folder within the connection; null or empty is its root.
  final String? root;

  /// Stored scan state ([ScanStatus]).
  final String status;
  final String? error;

  bool get isRoot => root == null || root!.isEmpty;
  bool get scanning => enabled && status == ScanStatus.scanning;
}
