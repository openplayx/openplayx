import 'dart:io';

import 'package:flutter/services.dart';

// Copy the original H.264 fixture into the app sandbox for native libVLC access.
Future<File> createTestVideo(Directory directory) async {
  final bytes = await rootBundle.load('test/fixtures/test_video.mp4');
  return File('${directory.path}/openplayx-test.mp4').writeAsBytes(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
  );
}
