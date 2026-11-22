import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';
import '../ui/icons/app_icons.dart';

/// Top-level destinations in their fixed order: 首页 → 来源 → 问问 → 设置.
/// Persist and restore by [name], never by index: inserting [plugins] moved
/// the settings index.
enum AppDestination {
  home(AppIcons.home),
  sources(AppIcons.folder),
  plugins(AppIcons.chat),
  settings(AppIcons.settings);

  const AppDestination(this.icon);
  final IconData icon;
  String label(BuildContext context) {
    final l = AppLocalizations.of(context);
    return switch (this) {
      home => l.home,
      sources => l.sources,
      plugins => l.plugins,
      settings => l.settings,
    };
  }
}
