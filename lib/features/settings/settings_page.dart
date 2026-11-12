import 'diagnostics_section.dart';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_theme_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/adaptive/app_page.dart';
import '../../services/library/library_service.dart';
import '../../ui/components/media/tmdb_attribution.dart';
import '../../ui/components/settings/settings_section.dart';
import '../../ui/icons/app_icons.dart';
import '../../ui/tokens/app_metrics.dart';
import '../../data/sources/source_manager.dart';
import 'scan_extensions_row.dart';
import 'scrape_management_section.dart';
import 'tmdb_settings_section.dart';
import 'remote_access_settings_page.dart';

/// One settings category. On phones it is a row in the root menu that opens
/// [sections] on a sub-page (or runs [onOpen] for categories that already
/// have their own page); on wider windows the sections are shown inline.
class _Category {
  const _Category({
    required this.icon,
    required this.title,
    this.sections = const [],
    this.onOpen,
  });
  final IconData icon;
  final String title;
  final List<Widget> sections;
  final VoidCallback? onOpen;
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    this.onModelSettings,
    this.library,
    this.sources,
  });
  final LibraryService? library;
  final SourceManager? sources;
  final VoidCallback? onModelSettings;

  List<List<_Category>> _groups(BuildContext context) {
    final l = AppLocalizations.of(context);
    void openRemote() => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RemoteAccessSettingsPage(sources: sources!),
      ),
    );
    return [
      [
        _Category(
          icon: AppIcons.theme,
          title: l.appearance,
          sections: [_AppearanceSection(key: const ValueKey('appearance'))],
        ),
        if (sources != null)
          _Category(
            icon: AppIcons.folder,
            title: l.sources,
            sections: [
              SettingsSection(
                key: const ValueKey('sources'),
                title: l.sources,
                children: [ScanExtensionsRow(sources: sources!)],
              ),
            ],
          ),
        if (sources != null)
          _Category(
            icon: AppIcons.connection,
            title: '远程访问',
            onOpen: openRemote,
            sections: [
              SettingsSection(
                key: const ValueKey('remote'),
                title: '远程访问',
                children: [
                  SettingsRow(
                    title: '家庭与连接线路',
                    chevron: true,
                    onTap: openRemote,
                  ),
                ],
              ),
            ],
          ),
      ],
      [
        if (library != null)
          _Category(
            icon: AppIcons.movie,
            title: 'TMDB',
            sections: [
              TmdbSettingsSection(
                key: const ValueKey('tmdb'),
                library: library!,
              ),
            ],
          ),
        if (library != null && sources != null)
          _Category(
            icon: AppIcons.scan,
            title: l.scrapeManagement,
            sections: [
              ScrapeManagementSection(
                key: const ValueKey('scrape'),
                library: library!,
                sources: sources!,
              ),
            ],
          ),
        if (onModelSettings != null)
          _Category(
            icon: AppIcons.assistant,
            title: l.aiAssistant,
            onOpen: onModelSettings,
            sections: [
              SettingsSection(
                key: const ValueKey('ai'),
                title: l.aiAssistant,
                children: [
                  SettingsRow(
                    title: l.aiModelSettings,
                    chevron: true,
                    onTap: onModelSettings,
                  ),
                ],
              ),
            ],
          ),
      ],
      [
        _Category(
          icon: AppIcons.preferences,
          title: l.developerMode,
          sections: [
            const DiagnosticsSection(key: ValueKey('diagnostics')),
            _DeveloperSection(key: const ValueKey('developer')),
          ],
        ),
        _Category(
          icon: AppIcons.info,
          title: l.about,
          sections: [_AboutSection(key: const ValueKey('about'))],
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final groups = _groups(context)
        .where((g) => g.isNotEmpty)
        .toList(growable: false);
    final compact =
        MediaQuery.sizeOf(context).width < AppMetrics.compactBreakpoint;
    final children = compact
        ? [
            for (final group in groups)
              SettingsSection(
                children: [
                  for (final category in group)
                    SettingsRow(
                      key: ValueKey('settings-${category.title}'),
                      icon: category.icon,
                      title: category.title,
                      chevron: true,
                      onTap:
                          category.onOpen ??
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _SettingsSubPage(
                                title: category.title,
                                sections: category.sections,
                              ),
                            ),
                          ),
                    ),
                ],
              ),
          ]
        : [
            for (final group in groups)
              for (final category in group) ...category.sections,
          ];
    return AppPage(
      title: Text(l.settings),
      body: SettingsListView(children: children),
    );
  }
}

class _SettingsSubPage extends StatelessWidget {
  const _SettingsSubPage({required this.title, required this.sections});
  final String title;
  final List<Widget> sections;
  @override
  Widget build(BuildContext context) => AppPage(
    title: Text(title),
    body: SettingsHeaderScope(
      // A lone section repeats the page title; several keep their headers.
      hidden: sections.length == 1,
      child: SettingsListView(children: sections),
    ),
  );
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({super.key});
  @override
  Widget build(BuildContext context) {
    final appearance = AppAppearance.of(context);
    final l = AppLocalizations.of(context);
    final modes = {
      ThemeMode.system: l.system,
      ThemeMode.light: l.light,
      ThemeMode.dark: l.dark,
    };
    final languages = {
      'system': l.system,
      'en': 'English',
      'zh-Hans': '简体中文',
      'zh-Hant': '繁體中文',
    };
    return SettingsSection(
      title: l.appearance,
      children: [
        SettingsChoiceRow<ThemeMode>(
          title: l.themeMode,
          value: appearance.mode,
          options: modes,
          onChanged: appearance.setMode,
        ),
        SettingsChoiceRow<String>(
          title: l.language,
          value: languages.containsKey(appearance.language)
              ? appearance.language
              : 'system',
          options: languages,
          onChanged: appearance.setLanguage,
        ),
        if (appearance.saveError != null)
          ShadAlert.destructive(
            title: Text(l.preferenceSaveFailed),
            description: Text(l.preferenceSaveRetry),
          ),
      ],
    );
  }
}

class _DeveloperSection extends StatelessWidget {
  const _DeveloperSection({super.key});
  @override
  Widget build(BuildContext context) {
    final appearance = AppAppearance.of(context);
    final l = AppLocalizations.of(context);
    return SettingsSection(
      title: l.developerMode,
      children: [
        SettingsRow(
          title: l.developerMode,
          description: l.developerModeDescription,
          control: ShadSwitch(
            key: const ValueKey('developer-mode'),
            value: appearance.developerMode,
            onChanged: appearance.setDeveloperMode,
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SettingsSection(
      title: l.about,
      children: [
        SettingsRow(
          title: 'OpenPlayX',
          description: l.aboutDescription,
          control: const Text('1.0.0'),
        ),
        const TmdbAttribution(),
      ],
    );
  }
}
