import 'package:openplayx/app/app.dart';
import 'package:openplayx/features/settings/app_theme_controller.dart';

/// Exercises the same themes, localization and overlays as the application.
class TestApp extends OpenPlayXApp {
  TestApp({super.key, required super.home})
    : super(appearance: AppThemeController(initialLanguage: 'zh-Hans'));
}
