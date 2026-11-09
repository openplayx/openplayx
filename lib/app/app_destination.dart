import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';
import '../ui/icons/app_icons.dart';

enum AppDestination {
  home(AppIcons.home),
  library(AppIcons.library),
  sources(AppIcons.folder),
  settings(AppIcons.settings);

  const AppDestination(this.icon);
  final IconData icon;
  String label(BuildContext context) {
    final l = AppLocalizations.of(context);
    return switch (this) {
      home => l.home,
      library => l.library,
      sources => l.sources,
      settings => l.settings,
    };
  }
}
