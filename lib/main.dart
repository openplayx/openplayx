import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/player_window.dart';
import 'app/theme/app_theme_controller.dart';
export 'app/app.dart' show OpenPlayXApp;

Future<void> main(List<String> args) async {
  if (await runPlayerWindowIfRequested(args)) return;
  WidgetsFlutterBinding.ensureInitialized();
  final appearance = AppThemeController();
  await appearance.load();
  runApp(OpenPlayXApp(appearance: appearance));
}
