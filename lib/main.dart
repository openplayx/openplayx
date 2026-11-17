import 'data/diagnostics/diagnostics_bootstrap.dart';
import 'data/diagnostics/diagnostics_service.dart';

import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/debug_seed/debug_seed.dart';
import 'app/player_window.dart';
import 'features/settings/app_theme_controller.dart';
import 'ui/theme/system_ui.dart';
export 'app/app.dart' show OpenPlayXApp;

Future<void> main(List<String> args) async {
  final role = args.isNotEmpty && args.first == playerWindowEntryArgument
      ? DiagnosticRole.player
      : DiagnosticRole.main;
  await runWithDiagnostics(role, () async {
    if (await runPlayerWindowIfRequested(args)) return;
    WidgetsFlutterBinding.ensureInitialized();
    await enableEdgeToEdge();
    // Debug/profile builds only: preloads test configuration, if given, before
    // anything reads configuration.sqlite3.
    await DebugSeed.applyAtStartup();
    final appearance = AppThemeController();
    await appearance.load();
    runApp(OpenPlayXApp(appearance: appearance));
  });
}
