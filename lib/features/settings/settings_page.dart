import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'app_theme_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/feedback/app_feedback.dart';
import '../../capabilities/library/library_service.dart';
import '../../ui/components/settings/settings_section.dart';
import '../../ui/icons/app_icons.dart';
import '../../capabilities/sources/source_manager.dart';
import 'scan_extensions_row.dart';
import 'scrape_management_section.dart';
import 'tmdb_settings_section.dart';
import 'remote_access_settings_page.dart';
import 'asr_settings_section.dart';
import '../assistant/view/plugins/plugin_management_page.dart';
import '../../assistant/plugins/plugin_manager.dart';
import '../../capabilities/speech/asr_backend_config.dart';
import '../../capabilities/speech/asr_model_store.dart';
import '../../capabilities/speech/subtitle_generation_service.dart';

/// A navigation entry shared by compact and desktop settings layouts.
class _Category {
  const _Category({
    required this.icon,
    required this.title,
    this.sections = const [],
    this.onOpen,
    this.rowKey,
  });
  final IconData icon;
  final Key? rowKey;
  final String title;
  final List<Widget> sections;
  final VoidCallback? onOpen;
}

class _SettingsGroup {
  const _SettingsGroup(this.title, this.categories);
  final String title;
  final List<_Category> categories;
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    this.library,
    this.sources,
    this.plugins,
    this.aiGroupBuilder,
  });

  /// Builds one AI settings page (LLM / Whisper / external / built-in); null hides AI.
  final Widget Function(PluginGroup group)? aiGroupBuilder;
  final LibraryService? library;
  final PluginManager? plugins;
  final SourceManager? sources;

  List<_SettingsGroup> _groups(BuildContext context) {
    final l = AppLocalizations.of(context);
    void openRemote() => Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'RemoteAccessSettingsPage'),
        builder: (_) => RemoteAccessSettingsPage(sources: sources!),
      ),
    );
    void openAi(PluginGroup group) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'PluginGroupPage'),
        builder: (_) => aiGroupBuilder!(group),
      ),
    );
    AsrBackendRegistry asrRegistry() =>
        SubtitleGenerationService.current?.backends ??
        AsrBackendRegistry(
          db: library!.configuration,
          models: AsrModelStore(asrModelRoot()),
        );
    _Category settingsPageCategory({
      required String id,
      required IconData icon,
      required String title,
      required List<Widget> sections,
    }) {
      void open() => Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: RouteSettings(name: 'settings_$id'),
          builder: (_) => _SettingsSubPage(
            title: title,
            sections: sections,
            showSectionHeaders: true,
          ),
        ),
      );
      return _Category(
        rowKey: ValueKey('settings-$id'),
        icon: icon,
        title: title,
        onOpen: open,
        sections: sections,
      );
    }

    return [
      _SettingsGroup(l.settingsGeneral, [
        _Category(
          icon: AppIcons.theme,
          title: l.appearance,
          sections: [_AppearanceSection(key: const ValueKey('appearance'))],
        ),
      ]),
      _SettingsGroup(l.plMenuPlayback, [
        settingsPageCategory(
          id: 'player',
          icon: AppIcons.playMedia,
          title: l.settingsPlayer,
          sections: [const _PlaybackSection()],
        ),
        if (library != null)
          settingsPageCategory(
            id: 'subtitles',
            icon: AppIcons.captions,
            title: l.settingsSubtitles,
            sections: [
              SettingsSection(
                children: [
                  SettingsRow(
                    key: const ValueKey('settings-speech-recognition'),
                    icon: AppIcons.mic,
                    title: l.asrSettingsTitle,
                    chevron: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(
                          name: 'SpeechRecognitionSettingsPage',
                        ),
                        builder: (_) => _SettingsSubPage(
                          title: l.asrSettingsTitle,
                          sections: [
                            AsrSettingsSection(
                              key: const ValueKey('asr'),
                              registry: asrRegistry(),
                            ),
                          ],
                          showSectionHeaders: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ]),
      _SettingsGroup(l.settingsMediaLibrary, [
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
            title: l.remoteAccess,
            onOpen: openRemote,
            sections: [
              SettingsSection(
                key: const ValueKey('remote'),
                title: l.remoteAccess,
                children: [
                  SettingsRow(
                    title: l.remoteHomeAndRoutes,
                    chevron: true,
                    onTap: openRemote,
                  ),
                ],
              ),
            ],
          ),
        if (library != null && sources != null)
          settingsPageCategory(
            id: 'scrape',
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
        if (library != null)
          settingsPageCategory(
            id: 'tmdb',
            icon: AppIcons.movie,
            title: 'TMDB',
            sections: [
              TmdbSettingsSection(
                key: const ValueKey('tmdb'),
                library: library!,
              ),
            ],
          ),
      ]),
      _SettingsGroup(l.plugins, [
        if (aiGroupBuilder != null)
          for (final group in PluginGroup.values)
            _Category(
              rowKey: ValueKey('plugin-group-${group.name}'),
              icon: group.icon,
              title: group.label,
              onOpen: () => openAi(group),
            ),
      ]),
      _SettingsGroup(l.settingsApplication, [
        _Category(
          icon: AppIcons.preferences,
          title: l.developerMode,
          sections: [_DeveloperSection(key: const ValueKey('developer'))],
        ),
        _Category(
          icon: AppIcons.info,
          title: l.about,
          sections: [_AboutSection(key: const ValueKey('about'))],
        ),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final groups = _groups(context)
        .where((g) => g.categories.isNotEmpty)
        .toList(growable: false);
    final children = [
      for (final group in groups)
        SettingsSection(
          title: group.title,
          children: [
            for (final category in group.categories)
              SettingsRow(
                key: category.rowKey ?? ValueKey('settings-${category.title}'),
                icon: category.icon,
                title: category.title,
                chevron: true,
                onTap:
                    category.onOpen ??
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(name: 'settings_page'),
                        builder: (_) => _SettingsSubPage(
                          title: category.title,
                          sections: category.sections,
                        ),
                      ),
                    ),
              ),
          ],
        ),
    ];
    return AppPage(
      pageContext: const PageContextData(pageType: 'settings'),
      title: Text(l.settings),
      body: SettingsListView(children: children),
    );
  }
}

class _SettingsSubPage extends StatelessWidget {
  const _SettingsSubPage({
    required this.title,
    required this.sections,
    this.showSectionHeaders = false,
  });
  final String title;
  final List<Widget> sections;
  final bool showSectionHeaders;
  @override
  Widget build(BuildContext context) => AppPage(
    pageContext: const PageContextData(pageType: 'settings_detail'),
    title: Text(title),
    body: SettingsHeaderScope(
      // Keep headers when a category contains a differently named section.
      hidden: !showSectionHeaders && sections.length == 1,
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
          AppAlert.error(
            title: l.preferenceSaveFailed,
            description: l.preferenceSaveRetry,
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
          control: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) => Text(snapshot.data?.version ?? ''),
          ),
        ),
      ],
    );
  }
}

/// Dedicated editors stay the single place their configuration lives; the
/// plugin page links to them instead of keeping a copy.
PluginEditorOpener pluginEditorOpener({
  LibraryService? library,
  SourceManager? sources,
  VoidCallback? onModelSettings,
}) {
  AsrBackendRegistry asrRegistry() =>
      SubtitleGenerationService.current?.backends ??
      AsrBackendRegistry(
        db: library!.configuration,
        models: AsrModelStore(asrModelRoot()),
      );
  return (context, pluginId) async {
    final l = AppLocalizations.of(context);
    Widget page(String title, Widget section) =>
        _SettingsSubPage(title: title, sections: [section]);
    if (pluginId == 'model.llm') {
      onModelSettings?.call();
      return;
    }
    final Widget? target = switch (pluginId) {
      'asr.whisper' when library != null => page(
        l.asrSettingsTitle,
        AsrSettingsSection(registry: asrRegistry()),
      ),
      'metadata.tmdb' when library != null => page(
        'TMDB',
        TmdbSettingsSection(library: library),
      ),
      'metadata.nfo' when library != null && sources != null => page(
        l.scrapeManagement,
        ScrapeManagementSection(library: library, sources: sources),
      ),
      _ => null,
    };
    if (target == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'settings_page'),
        builder: (_) => target,
      ),
    );
  };
}

class _PlaybackSection extends StatelessWidget {
  const _PlaybackSection();

  @override
  Widget build(BuildContext context) {
    final preferences = AppAppearance.of(context);
    final l = AppLocalizations.of(context);
    return SettingsSection(
      title: l.plMenuPlayback,
      children: [
        SettingsRow(
          title: l.followSystemOrientation,
          control: ShadSwitch(
            key: const ValueKey('follow-system-orientation'),
            value: preferences.followSystemOrientation,
            onChanged: preferences.setFollowSystemOrientation,
          ),
        ),
        if (preferences.saveError != null)
          AppAlert.error(
            title: l.preferenceSaveFailed,
            description: l.preferenceSaveRetry,
          ),
      ],
    );
  }
}
