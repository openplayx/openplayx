import 'package:smb_connect/smb_connect.dart';

/// Retains only progress, never file bytes or handles. Each Range gets its own
/// ramp so a concurrent metadata probe cannot mutate another active reader.
class ProgressiveReadSession {
  final List<ProgressiveReadCursor> _recent = [];

  ProgressiveReadCursor begin(int offset) {
    RangeError.checkNotNegative(offset, 'offset');
    ProgressiveReadCursor? previous;
    for (final cursor in _recent.reversed) {
      if (cursor.nextOffset == offset) {
        previous = cursor;
        break;
      }
    }
    final ramp = previous?.ramp.clone() ?? SmbReadRamp();
    if (previous != null) _recent.remove(previous);
    final cursor = ProgressiveReadCursor(offset, ramp);
    _recent.add(cursor);
    if (_recent.length > 4) _recent.removeAt(0);
    return cursor;
  }
}

class ProgressiveReadCursor {
  int nextOffset;
  final SmbReadRamp ramp;
  ProgressiveReadCursor(this.nextOffset, this.ramp);

  void advance(int bytes) {
    RangeError.checkNotNegative(bytes, 'bytes');
    nextOffset += bytes;
    // The SMB reader records consumed bytes in ramp; do not double-count here.
  }
}
