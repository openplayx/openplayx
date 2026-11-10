import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/sources/source_defaults_page.dart';

import '../../app_test_host.dart';

class _Sources extends SourceManager {
  @override
  List<SourceConfig> get configs => [
    const SourceConfig(
      id: 's',
      kind: SourceKind.smb,
      name: 'NAS',
      address: 'smb://host/share',
    ),
  ];
  @override
  Future<void> load() async {}
}

void main() {
  for (final width in [1024.0, 1440.0, 390.0]) {
    testWidgets('default instance selects lay out at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        TestApp(home: SourceDefaultsPage(manager: _Sources())),
      );
      await tester.pumpAndSettle();
      // A wide window used to throw "non-normalized width constraints".
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
