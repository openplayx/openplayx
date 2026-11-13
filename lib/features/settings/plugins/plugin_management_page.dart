import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/plugins/source_capability.dart';
import '../../../data/sources/source_manager.dart';
import '../../../services/plugins/plugin_catalog.dart';
import '../../../services/plugins/plugin_manager.dart';
import '../../../ui/adaptive/app_page.dart';
import '../../../ui/components/settings/settings_section.dart';
import '../../../ui/icons/app_icons.dart';
import '../../../ui/tokens/app_metrics.dart';
import '../../../ui/tokens/app_semantic_colors.dart';
import '../../../ui/tokens/app_spacing.dart';
import 'plugin_detail_view.dart';

/// Opens the dedicated editor of a non-source plugin (TMDB, ASR, Torrent,
/// model). Those forms stay the single place their configuration is edited.
typedef PluginEditorOpener = Future<void> Function(
  BuildContext context,
  String pluginId,
);

enum _Scope { all, enabled, attention }

/// Settings → 插件管理: every plugin this build contains, its instances,
/// AI scope and runtime state. Phones use list → detail; wide windows show
/// list and detail side by side.
class PluginManagementPage extends StatefulWidget {
  const PluginManagementPage({
    super.key,
    required this.manager,
    this.sources,
    this.openEditor,
    this.initialPlugin,
  });
  final PluginManager manager;
  final SourceManager? sources;
  final PluginEditorOpener? openEditor;
  final String? initialPlugin;

  @override
  State<PluginManagementPage> createState() => _PluginManagementPageState();
}

class _PluginManagementPageState extends State<PluginManagementPage> {
  var _scope = _Scope.all;
  PluginCategory? _category;
  var _query = '';
  String? _selected;

  PluginManager get manager => widget.manager;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialPlugin;
    manager.addListener(_changed);
    manager.refresh();
  }

  @override
  void dispose() {
    manager.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  bool _matches(PluginSnapshot s) {
    final d = s.definition;
    if (_category != null && d.category != _category) return false;
    switch (_scope) {
      case _Scope.enabled:
        if (!s.enabled || s.state == PluginRuntimeState.disabled) return false;
      case _Scope.attention:
        if (!s.needsAttention) return false;
      case _Scope.all:
        break;
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      d.name,
      d.summary,
      d.location.label,
      d.category.label,
      for (final c in d.capabilities) ...[c.label, c.id],
    ].any((t) => t.toLowerCase().contains(q));
  }

  Future<void> _open(BuildContext context, PluginSnapshot s, bool wide) async {
    if (wide) {
      setState(() => _selected = s.id);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppPage(
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

  Widget _filters(BuildContext context) {
    Widget scope(_Scope value, String label) {
      final selected = _scope == value;
      final count = switch (value) {
        _Scope.all => manager.snapshots.length,
        _Scope.enabled =>
          manager.snapshots
              .where((s) => s.enabled && s.state != PluginRuntimeState.disabled)
              .length,
        _Scope.attention =>
          manager.snapshots.where((s) => s.needsAttention).length,
      };
      final child = Text('$label $count');
      return selected
          ? ShadButton.secondary(
              key: ValueKey('plugin-scope-${value.name}'),
              size: ShadButtonSize.sm,
              onPressed: () {},
              child: child,
            )
          : ShadButton.ghost(
              key: ValueKey('plugin-scope-${value.name}'),
              size: ShadButtonSize.sm,
              onPressed: () => setState(() => _scope = value),
              child: child,
            );
    }

    Widget category(PluginCategory? value) {
      final label = value?.label ?? '全部分类';
      return _category == value
          ? ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed: () {},
              child: Text(label),
            )
          : ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: () => setState(() => _category = value),
              child: Text(label),
            );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShadInput(
            key: const ValueKey('plugin-search'),
            placeholder: const Text('按名称、能力或执行位置搜索'),
            leading: Icon(AppIcons.search, size: 16),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              scope(_Scope.all, '全部'),
              scope(_Scope.enabled, '已启用'),
              scope(_Scope.attention, '需处理'),
            ],
          ),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              category(null),
              for (final c in PluginCategory.values) category(c),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(PluginSnapshot s, bool enabled) =>
      togglePlugin(context, manager, s, enabled);

  Widget _row(BuildContext context, PluginSnapshot s, bool wide) {
    final d = s.definition;
    final instances = d.multiInstance
        ? '已启用 ${s.enabledInstances}/${s.instances.length} 个实例'
        : null;
    final ai = d.aiCapabilityCount == 0
        ? null
        : 'AI 可用 ${s.aiCapabilities.length}/${d.aiCapabilityCount}';
    return SettingsRow(
      key: ValueKey('plugin-row-${s.id}'),
      icon: d.icon,
      title: d.name,
      description: [
        d.summary,
        ?instances,
        ?ai,
        if (s.reason != null && s.needsAttention) s.reason!,
      ].join(' · '),
      accent: wide && _selected == s.id,
      chevron: !wide,
      onTap: () => _open(context, s, wide),
      control: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PluginStateBadge(
            state: s.unconfigured ? PluginRuntimeState.disabled : s.state,
            label: s.unconfigured ? '未配置' : null,
          ),
          if (d.toggleable && s.platformSupported) ...[
            const SizedBox(width: AppSpacing.sm),
            ShadSwitch(
              key: ValueKey('plugin-switch-${s.id}'),
              value: s.enabled,
              onChanged: (v) => _toggle(s, v),
            ),
          ],
        ],
      ),
    );
  }

  Widget _list(BuildContext context, bool wide) {
    final visible = manager.snapshots.where(_matches).toList();
    final groups = <PluginCategory, List<PluginSnapshot>>{};
    for (final s in visible) {
      (groups[s.definition.category] ??= []).add(s);
    }
    return SettingsListView(
      children: [
        _filters(context),
        if (manager.snapshots.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (visible.isEmpty)
          const SettingsSection(children: [SettingsRow(title: '没有符合条件的插件')]),
        for (final entry in groups.entries)
          SettingsSection(
            key: ValueKey('plugin-group-${entry.key.name}'),
            title: entry.key.label,
            children: [for (final s in entry.value) _row(context, s, wide)],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= AppMetrics.wideBreakpoint;
      if (!wide) {
        return AppPage(title: const Text('插件管理'), body: _list(context, false));
      }
      final selected =
          manager.snapshot(_selected ?? '') ?? manager.snapshots.firstOrNull;
      return AppPage(
        title: const Text('插件管理'),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 400, child: _list(context, true)),
            const VerticalDivider(width: 1),
            Expanded(
              child: selected == null
                  ? const SizedBox.shrink()
                  : PluginDetailView(
                      key: ValueKey('plugin-detail-${selected.id}'),
                      manager: manager,
                      pluginId: selected.id,
                      sources: widget.sources,
                      openEditor: widget.openEditor,
                    ),
            ),
          ],
        ),
      );
    },
  );
}

/// Distinct marks for error / missing configuration / disabled, so a
/// blocked plugin never looks merely "off".
class PluginStateBadge extends StatelessWidget {
  const PluginStateBadge({super.key, required this.state, this.label});
  final PluginRuntimeState state;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final semantic = AppSemanticColors.of(context);
    final (fg, bg) = switch (state) {
      PluginRuntimeState.ready => (semantic.success, semantic.successSurface),
      PluginRuntimeState.validating ||
      PluginRuntimeState.starting => (semantic.info, semantic.infoSurface),
      PluginRuntimeState.blocked || PluginRuntimeState.draining => (
        semantic.warning,
        semantic.warningSurface,
      ),
      PluginRuntimeState.error => (
        colors.destructiveForeground,
        colors.destructive,
      ),
      PluginRuntimeState.disabled => (colors.mutedForeground, colors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        label ?? state.label,
        style: ShadTheme.of(context).textTheme.small
            .copyWith(color: fg, fontSize: 12),
      ),
    );
  }
}

/// Plugin switch with the impact panel when playback or tasks are active.
Future<void> togglePlugin(
  BuildContext context,
  PluginManager manager,
  PluginSnapshot s,
  bool enabled,
) async {
  if (!enabled) {
    final impact = manager.impact(s.id);
    if (!impact.isEmpty) {
      final accepted = await showShadDialog<bool>(
        context: context,
        builder: (context) => ShadDialog(
          title: Text('停用「${s.definition.name}」？'),
          actions: [
            ShadButton.ghost(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ShadButton(
              key: const ValueKey('plugin-disable-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('停用'),
            ),
          ],
          child: Text(impactText(impact)),
        ),
      );
      if (accepted != true) return;
    }
  }
  try {
    manager.setPluginEnabled(s.id, enabled);
  } on PluginException catch (e) {
    manager.reloadPolicy();
    if (context.mounted) showPluginError(context, e.message);
  }
}

String impactText(PluginImpact impact) => [
  '停用后立即阻止新的调用；实例配置、已生成的字幕和历史记录都会保留。',
  if (impact.playing > 0) '${impact.playing} 个正在播放的会话会继续到播放结束后再释放连接。',
  if (impact.running > 0) '${impact.running} 个进行中的请求会在完成后释放。',
  if (impact.instances.isNotEmpty) '受影响的实例：${impact.instances.join('、')}。',
  if (impact.remoteTasks) '服务器上的下载任务不会因此停止；如需停止，请先在任务中取消。',
].join('\n');

void showPluginError(BuildContext context, String message) =>
    ShadToaster.maybeOf(context)
        ?.show(ShadToast.destructive(description: Text(message)));
