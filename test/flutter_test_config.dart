import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Device sensors are supplied by native hosts, which widget tests do not run.
  setUp(() {
    // Only install the mock when the suite already needs a Flutter binding.
    // Creating one here also replaces HttpClient in pure unit tests, preventing
    // their local HTTP servers from receiving requests.
    if (BindingBase.debugBindingType() == null) return;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('openplayx/device_orientation'),
          (_) async => null,
        );
  });
  await testMain();
}
