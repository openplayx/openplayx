import 'package:integration_test/integration_test.dart';

import '../test/ui_preview_test.dart' as previews;

/// Captures actual application frames while running in the native macOS app.
/// Use OPENPLAYX_UI_PREVIEW_DIR to opt into writing sample-data screenshots.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  previews.main();
}
