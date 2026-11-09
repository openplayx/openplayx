import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/theme/app_theme_controller.dart';
export 'app/app.dart' show OpenPlayXApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appearance = AppThemeController();
  await appearance.load();
  runApp(OpenPlayXApp(appearance: appearance));
}
