import 'diagnostics_section.dart';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_theme_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/adaptive/app_page.dart';
import '../../services/library/library_service.dart';
import '../../ui/components/media/tmdb_attribution.dart';
import '../../ui/components/settings/settings_section.dart';
import '../../ui/tokens/app_metrics.dart';
import '../../ui/tokens/app_spacing.dart';
import '../../data/sources/source_manager.dart';
import 'scan_extensions_row.dart';
import 'scrape_management_section.dart';
import 'tmdb_settings_section.dart';
import 'remote_access_settings_page.dart';

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
    return AppPage(
      title: Text(l.settings),
      body: ListView(
        padding: AppSpacing.page(context),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppMetrics.formWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsSection(
                    title: l.appearance,
                    children: [
                      SettingsRow(
                        title: l.themeMode,
                        description: l.themeDescription,
                        control: ShadSelect<ThemeMode>(
                          key: ValueKey(appearance.mode),
                          initialValue: appearance.mode,
                          selectedOptionBuilder: (_, value) =>
                              Text(modes[value]!),
                          options: [
                            for (final mode in modes.entries)
                              ShadOption(
                                value: mode.key,
                                child: Text(mode.value),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) appearance.setMode(value);
                          },
                        ),
                      ),
                      SettingsRow(
                        title: l.language,
                        control: ShadSelect<String>(
                          key: ValueKey(appearance.language),
                          initialValue:
                              languages.containsKey(appearance.language)
                              ? appearance.language
                              : 'system',
                          selectedOptionBuilder: (_, value) =>
                              Text(languages[value]!),
                          options: [
                            for (final language in languages.entries)
                              ShadOption(
                                value: language.key,
                                child: Text(language.value),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) appearance.setLanguage(value);
                          },
                        ),
                      ),
                      if (appearance.saveError != null)
                        ShadAlert.destructive(
                          title: Text(l.preferenceSaveFailed),
                          description: Text(l.preferenceSaveRetry),
                        ),
                    ],
                  ),
                  if (sources != null)
                    SettingsSection(
                      title: l.sources,
                      children: [ScanExtensionsRow(sources: sources!)],
                    ),
                  if (sources != null)
                    SettingsSection(
                      title: '远程访问',
                      children: [
                        SettingsRow(
                          title: '家庭与连接线路',
                          description:
                              '管理配对、局域网路径和连接策略，保存到 remote_access.json。',
                          control: ShadButton.outline(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    RemoteAccessSettingsPage(sources: sources!),
                              ),
                            ),
                            child: Text(l.manage),
                          ),
                        ),
                      ],
                    ),
                  if (library != null) TmdbSettingsSection(library: library!),
                  if (library != null && sources != null)
                    ScrapeManagementSection(
                      library: library!,
                      sources: sources!,
                    ),
                  if (onModelSettings != null)
                    SettingsSection(
                      title: l.aiAssistant,
                      children: [
                        SettingsRow(
                          title: l.aiModelSettings,
                          description: l.aiProviderDescription,
                          control: ShadButton.outline(
                            onPressed: onModelSettings,
                            child: Text(l.manage),
                          ),
                        ),
                      ],
                    ),
                  const DiagnosticsSection(),
                  SettingsSection(
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
                  ),
                  SettingsSection(
                    title: l.about,
                    children: [
                      Text(l.aboutDescription),
                      const Text('OpenPlayX 1.0.0'),
                      const TmdbAttribution(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
