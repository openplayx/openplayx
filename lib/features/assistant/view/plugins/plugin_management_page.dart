import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../capabilities/sources/source_manager.dart';
import '../../../../assistant/conversation/assistant_store.dart';
import '../../../../assistant/plugins/plugin_catalog.dart';
import '../../../../assistant/plugins/plugin_manager.dart';
import '../../../../ui/adaptive/app_page.dart';
import '../../../../ui/icons/app_icons.dart';
import '../../../../ui/components/settings/settings_section.dart';
import '../../../../ui/tokens/app_metrics.dart';
import '../../../../ui/tokens/app_semantic_colors.dart';
import '../../../../ui/tokens/app_spacing.dart';
import '../../../../assistant/plugins/external/external_service_setup.dart';
import '../assistant_settings_page.dart';
import '../../../../assistant/plugins/external/external_service_registry.dart';
import 'external_service_config_page.dart';
import 'external_service_detail_view.dart';
import 'plugin_detail_view.dart';
import '../../../../ui/components/feedback/app_feedback.dart';
import '../../../../l10n/l10n.dart';

/// Opens the dedicated editor of a non-source plugin (TMDB, ASR,
/// model). Those forms stay the single place their configuration is edited.
typedef PluginEditorOpener = Future<void> Function(
  BuildContext context,
  String pluginId,
);

/// Product grouping of the plugin page: built-in capabilities are shown as a
/// count with a read-only list; models and external capabilities are the
/// managed areas.
enum PluginGroup {
  model,
  external,
  builtIn;

  String get label => switch (this) {
    model => appStrings.plgGroupModel,
    external => appStrings.plgGroupExternal,
    builtIn => appStrings.plgGroupBuiltIn,
  };

  static PluginGroup of(PluginDefinition d) {
    if (d.category == PluginCategory.model) return model;
    // Source adapters (local, SMB, Plex, Jellyfin, Emby, DLNA…) ship with the
    // App even when they talk to a server: they are built-in sources.
    if (d.sourceKind != null) return builtIn;
    // Metadata (NFO, TMDB) is App-provided scraping, even when TMDB calls a
    // cloud API.
    if (d.category == PluginCategory.metadata) return builtIn;
    return switch (d.location) {
      ExecutionLocation.selfHosted || ExecutionLocation.cloudApi => external,
      ExecutionLocation.device || ExecutionLocation.network => builtIn,
    };
  }
}

/// AI configuration opened from Settings, laid out like
/// settings in two levels: the root lists 模型 / 外部能力 / 内部能力, and each
/// row opens its own page. On wide windows the 外部能力 and 内部能力 pages
/// show list and detail side by side.
class PluginManagementPage extends StatefulWidget {
  const PluginManagementPage({
    super.key,
    required this.manager,
    this.sources,
    this.openEditor,
    this.initialPlugin,
    this.assistantStore,
    this.initialGroup,
    required this.externalServices,
  });
  final PluginManager manager;
  final SourceManager? sources;
  final PluginEditorOpener? openEditor;

  /// Opens this plugin's group page with the plugin selected.
  final String? initialPlugin;

  /// Model settings shown on the 模型 page; null when AI is unavailable.
  final AssistantStore? assistantStore;

  /// Group page to open on first show (e.g. the chat's model settings link).
  final PluginGroup? initialGroup;

  /// Custom external capabilities (外部能力).
  final ExternalServiceRegistry externalServices;

  @override
  State<PluginManagementPage> createState() => PluginManagementPageState();
}

class PluginManagementPageState extends State<PluginManagementPage> {
  late final _setup = ExternalServiceSetup(registry: widget.externalServices);
  StreamSubscription<void>? _externalChanges;

  PluginManager get manager => widget.manager;

  @override
  void initState() {
    super.initState();
    manager.addListener(_changed);
    manager.refresh();
    _externalChanges = _setup.registry.changes.stream.listen((_) => _changed());
    if (!_setup.registry.loaded) _setup.registry.load().then((_) => _changed());
    final initial = manager.catalog[widget.initialPlugin ?? ''];
    final group =
        widget.initialGroup ??
        (initial == null ? null : PluginGroup.of(initial));
    if (group != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showGroup(group, selected: widget.initialPlugin);
      });
    }
  }

  @override
  void dispose() {
    manager.removeListener(_changed);
    _externalChanges?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Opens one group's page on top of the root list (e.g. the chat's model
  /// settings link opens 模型), keeping the Settings return path.
  Future<void> showGroup(PluginGroup group, {String? selected}) async {
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'PluginGroupPage'),
        builder: (_) => PluginGroupPage(
          key: ValueKey('plugin-group-page-${group.name}'),
          group: group,
          manager: manager,
          setup: _setup,
          sources: widget.sources,
          openEditor: widget.openEditor,
          assistantStore: widget.assistantStore,
          initialSelected: selected,
        ),
      ),
    );
    _changed();
  }

  int _builtInCount() => manager.snapshots
      .where(
        (s) =>
            !s.definition.deprecated &&
            PluginGroup.of(s.definition) == PluginGroup.builtIn,
      )
      .length;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final config = widget.assistantStore?.loadConfig();
    final modelValue = config == null
        ? l.statusUnavailable
        : config.configured && config.model.isNotEmpty
        ? config.usePlatform
              ? l.aiPlatformService
              : config.model
        : l.statusNotConfigured;
    Widget row(
      PluginGroup group, {
      required IconData icon,
      required String description,
      required String value,
    }) => SettingsRow(
      key: ValueKey('plugin-group-${group.name}'),
      icon: icon,
      title: group.label,
      description: description,
      chevron: true,
      control: Text(value),
      onTap: () => showGroup(group),
    );
    return AppPage(
      pageContext: const PageContextData(pageType: 'plugins'),
      title: Text(l.plugins),
      body: SettingsListView(
        children: [
          SettingsSection(
            children: [
              row(
                PluginGroup.model,
                icon: AppIcons.assistant,
                description: l.plgGroupModelDescription,
                value: modelValue,
              ),
            ],
          ),
          SettingsSection(
            children: [
              row(
                PluginGroup.external,
                icon: AppIcons.server,
                description: l.plgGroupExternalDescription,
                value: l.plgCount(_setup.registry.services.length),
              ),
              row(
                PluginGroup.builtIn,
                icon: AppIcons.tool,
                description: l.plgGroupBuiltInDescription,
                value: l.plgCount(_builtInCount()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One group's page: the model settings form, the external services, or
/// the read-only built-in capabilities. Phones use list → detail; wide
/// windows show list and detail side by side.
class PluginGroupPage extends StatefulWidget {
  const PluginGroupPage({
    super.key,
    required this.group,
    required this.manager,
    required this.setup,
    this.sources,
    this.openEditor,
    this.assistantStore,
    this.initialSelected,
  });
  final PluginGroup group;
  final PluginManager manager;
  final ExternalServiceSetup setup;
  final SourceManager? sources;
  final PluginEditorOpener? openEditor;
  final AssistantStore? assistantStore;
  final String? initialSelected;

  @override
  State<PluginGroupPage> createState() => _PluginGroupPageState();
}

class _PluginGroupPageState extends State<PluginGroupPage> {
  static const _ext = 'ext:';
  late String? _selected = widget.initialSelected;
  StreamSubscription<void>? _externalChanges;

  PluginGroup get _group => widget.group;
  PluginManager get manager => widget.manager;
  ExternalServiceSetup get _setup => widget.setup;

  @override
  void initState() {
    super.initState();
    manager.addListener(_changed);
    _externalChanges = _setup.registry.changes.stream.listen((_) => _changed());
  }

  @override
  void dispose() {
    manager.removeListener(_changed);
    _externalChanges?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  // Deprecated plugins are not shown at all.
  bool _matches(PluginSnapshot s) =>
      !s.definition.deprecated && PluginGroup.of(s.definition) == _group;

  Future<void> _open(BuildContext context, PluginSnapshot s, bool wide) async {
    if (wide) {
      setState(() => _selected = s.id);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'AppPage'),
        builder: (_) => AppPage(
          pageContext: PageContextData(
            pageType: 'plugin_detail',
            entity: {'plugin_id': s.id},
          ),
          title: Text(s.definition.name),
          body: PluginDetailView(
            manager: manager,
            pluginId: s.id,
            sources: widget.sources,
            openEditor: widget.openEditor,
          ),
        ),
      ),
    );
  }

  Future<void> _configureExternal(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'ExternalServiceConfigPage'),
        builder: (_) => ExternalServiceConfigPage(setup: _setup),
      ),
    );
    _changed();
  }

  Future<void> _openExternal(
    BuildContext context,
    ExternalService s,
    bool wide,
  ) async {
    if (wide) {
      setState(() => _selected = '$_ext${s.id}');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'AppPage'),
        builder: (route) => AppPage(
          pageContext: PageContextData(
            pageType: 'external_service_detail',
            entity: {'service_id': s.id},
          ),
          title: Text(s.displayName),
          body: ExternalServiceDetailView(
            setup: _setup,
            serviceId: s.id,
            onRemoved: () => Navigator.of(route).pop(),
          ),
        ),
      ),
    );
  }

  Widget _externalRow(BuildContext context, ExternalService s, bool wide) =>
      SettingsRow(
        key: ValueKey('external-service-${s.id}'),
        title: s.displayName,
        description: [
          if (s.label.isNotEmpty && s.label != s.displayName) s.label,
          appStrings.extToolCount(s.tools.length),
        ].join(' · '),
        accent: wide && _selected == '$_ext${s.id}',
        chevron: !wide,
        onTap: () => _openExternal(context, s, wide),
        control: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge(label: appStrings.statusConfigured, positive: true),
            const SizedBox(width: AppSpacing.xs),
            StatusBadge(
              label: s.available
                  ? appStrings.statusAvailable
                  : appStrings.statusUnavailable,
              positive: s.available,
            ),
          ],
        ),
      );

  Widget _row(BuildContext context, PluginSnapshot s, bool wide) {
    final d = s.definition;
    final instances = d.multiInstance
        ? appStrings.plgInstanceCount(s.instances.length)
        : null;
    return SettingsRow(
      key: ValueKey('plugin-row-${s.id}'),
      icon: pluginIcon(d),
      title: d.name,
      description: [
        d.summary,
        ?instances,
        if (!s.available) unavailableReason(s),
      ].join(' · '),
      accent: wide && _selected == s.id,
      chevron: !wide,
      onTap: () => _open(context, s, wide),
      control: PluginStatusBadges(snapshot: s),
    );
  }

  static Map<PluginCategory, List<PluginSnapshot>> _byCategory(
    List<PluginSnapshot> snapshots,
  ) {
    final groups = <PluginCategory, List<PluginSnapshot>>{};
    for (final s in snapshots) {
      (groups[s.definition.category] ??= []).add(s);
    }
    return groups;
  }

  Widget _hint(BuildContext context, String text) => Padding(
    padding: const EdgeInsetsDirectional.only(
      start: AppSpacing.lg,
      end: AppSpacing.lg,
      bottom: AppSpacing.md,
    ),
    child: Text(text, style: ShadTheme.of(context).textTheme.muted),
  );

  List<Widget> _external(BuildContext context, bool wide) => [
    _hint(context, appStrings.plgExternalHint),
    SettingsSection(
      key: const ValueKey('external-services'),
      children: [
        for (final s in _setup.registry.services)
          _externalRow(context, s, wide),
      ],
    ),
  ];

  /// Header button (top right, next to the assistant), same look as the
  /// 来源 page's add button.
  Widget _configureExternalButton(BuildContext context) => Tooltip(
    message: appStrings.extConfigureTitle,
    child: Semantics(
      label: appStrings.extConfigureTitle,
      button: true,
      excludeSemantics: true,
      child: ShadIconButton.ghost(
        key: const ValueKey('external-configure'),
        width: 40,
        height: 40,
        icon: const Icon(AppIcons.add),
        onPressed: () => _configureExternal(context),
      ),
    ),
  );

  /// Shown in the middle of the page while no external service exists.
  Widget _emptyExternal(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShadButton(
            key: const ValueKey('external-configure-empty'),
            onPressed: () => _configureExternal(context),
            leading: const Icon(AppIcons.add),
            child: Text(appStrings.extConfigureTitle),
          ),
        ],
      ),
    ),
  );

  List<Widget> _builtIn(BuildContext context, bool wide) {
    final visible = manager.snapshots.where(_matches).toList();
    return [
      // Counted per catalog entry: connections and tools never inflate it.
      _hint(context, appStrings.plgBuiltInHint(visible.length)),
      if (manager.snapshots.isEmpty)
        const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (visible.isEmpty)
        SettingsSection(
          children: [
            SettingsRow(title: appStrings.plgGroupEmpty(_group.label)),
          ],
        )
      else
        for (final entry in _byCategory(visible).entries)
          SettingsSection(
            key: ValueKey('plugin-builtin-${entry.key.name}'),
            title: entry.key.label,
            children: [for (final s in entry.value) _row(context, s, wide)],
          ),
    ];
  }

  Widget _modelSettings() {
    final store = widget.assistantStore;
    if (store == null) {
      return SettingsSection(
        children: [SettingsRow(title: appStrings.plgNoAssistant)],
      );
    }
    return AssistantModelSettings(
      key: const ValueKey('plugin-model-settings'),
      store: store,
      onSaved: manager.refresh,
    );
  }

  Widget _list(BuildContext context, bool wide) =>
      _group == PluginGroup.external && _setup.registry.services.isEmpty
      ? _emptyExternal(context)
      : SettingsListView(
          children: switch (_group) {
            PluginGroup.model => [_modelSettings()],
            PluginGroup.external => _external(context, wide),
            PluginGroup.builtIn => _builtIn(context, wide),
          },
        );

  Widget _detail(BuildContext context) {
    final selected = manager.snapshot(_selected ?? '');
    final external = _selected?.startsWith(_ext) == true
        ? _setup.registry.get(_selected!.substring(_ext.length))
        : null;
    if (external != null && _group == PluginGroup.external) {
      return ExternalServiceDetailView(
        key: ValueKey('external-detail-${external.id}'),
        setup: _setup,
        serviceId: external.id,
        onRemoved: () => setState(() => _selected = null),
      );
    }
    if (selected == null || PluginGroup.of(selected.definition) != _group) {
      return Center(
        key: const ValueKey('plugin-detail-empty'),
        child: Text(
          AppLocalizations.of(context).plgSelectForDetail,
          style: ShadTheme.of(context).textTheme.muted,
        ),
      );
    }
    return PluginDetailView(
      key: ValueKey('plugin-detail-${selected.id}'),
      manager: manager,
      pluginId: selected.id,
      sources: widget.sources,
      openEditor: widget.openEditor,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= AppMetrics.wideBreakpoint;
      final title = Text(_group.label);
      final trailing = [
        if (_group == PluginGroup.external) _configureExternalButton(context),
      ];
      // The model form needs no detail pane.
      if (!wide || _group == PluginGroup.model) {
        return AppPage(
          pageContext: PageContextData(
            pageType: 'plugin_group',
            state: {'group': _group.name, 'selectedId': _selected},
          ),
          title: title,
          trailing: trailing,
          body: _list(context, wide),
        );
      }
      return AppPage(
        pageContext: PageContextData(
          pageType: 'plugin_group',
          state: {'group': _group.name, 'selectedId': _selected},
        ),
        title: title,
        trailing: trailing,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 400, child: _list(context, true)),
            const VerticalDivider(width: 1),
            Expanded(child: _detail(context)),
          ],
        ),
      );
    },
  );
}

/// Whether one instance can run now.
bool instanceAvailable(PluginInstanceView i) =>
    i.enabled &&
    const {
      PluginRuntimeState.ready,
      PluginRuntimeState.validating,
      PluginRuntimeState.starting,
    }.contains(i.state);

/// Why a plugin is not available, in one short phrase.
String unavailableReason(PluginSnapshot s) {
  if (!s.platformSupported) return s.reason ?? appStrings.plgDeviceUnsupported;
  return s.reason ??
      (s.enabled
          ? appStrings.plgTemporarilyUnavailable
          : appStrings.plgDisabled);
}

/// The two status dimensions: configured or not, available or not. Text carries
/// the state, so it never relies on color alone.
class PluginStatusBadges extends StatelessWidget {
  const PluginStatusBadges({super.key, required this.snapshot});
  final PluginSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (s.platformSupported) ...[
          StatusBadge(
            key: ValueKey('plugin-configured-${s.id}'),
            label: s.configured
                ? appStrings.statusConfigured
                : appStrings.statusNotConfigured,
            positive: s.configured,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        StatusBadge(
          key: ValueKey('plugin-available-${s.id}'),
          label: s.available
              ? appStrings.statusAvailable
              : appStrings.statusUnavailable,
          positive: s.available,
        ),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.positive});
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final semantic = AppSemanticColors.of(context);
    final (fg, bg) = positive
        ? (semantic.success, semantic.successSurface)
        : (colors.mutedForeground, colors.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        label,
        style: ShadTheme.of(context).textTheme.small
            .copyWith(color: fg, fontSize: 12),
      ),
    );
  }
}

/// Icon of a plugin, chosen by the view (the catalog holds no UI).
IconData pluginIcon(PluginDefinition d) => switch (d.sourceKind) {
  final kind? => kind.files ? AppIcons.folder : AppIcons.server,
  null => switch (d.id) {
    'metadata.nfo' => AppIcons.info,
    'metadata.tmdb' => AppIcons.movie,
    'media.ffmpeg' => AppIcons.openFile,
    'asr.whisper' => AppIcons.captions,
    'model.llm' => AppIcons.assistant,
    _ => AppIcons.plugins,
  },
};

void showPluginError(BuildContext context, String message) =>
    showAppToast(context, message, kind: FeedbackKind.error);
