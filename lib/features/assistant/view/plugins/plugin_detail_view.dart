import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../settings/app_theme_controller.dart';
import '../../../../core/capabilities/source_capability.dart';
import '../../../../capabilities/sources/source_manager.dart';
import '../../../../assistant/plugins/plugin_catalog.dart';
import '../../../../assistant/plugins/plugin_manager.dart';
import '../../../../ui/components/settings/settings_section.dart';
import 'plugin_management_page.dart';
import '../../../../ui/components/feedback/app_feedback.dart';
import '../../../../l10n/l10n.dart';

/// One plugin: overview & capabilities, instances and runtime diagnostics.
/// Enabled capabilities are AI-callable. Source writes have an explicit
/// per-instance opt-in because they change remote storage.
class PluginDetailView extends StatefulWidget {
  const PluginDetailView({
    super.key,
    required this.manager,
    required this.pluginId,
    this.sources,
    this.openEditor,
  });
  final PluginManager manager;
  final String pluginId;
  final SourceManager? sources;
  final PluginEditorOpener? openEditor;

  @override
  State<PluginDetailView> createState() => _PluginDetailViewState();
}

class _PluginDetailViewState extends State<PluginDetailView> {
  bool _busy = false;
  PluginManager get manager => widget.manager;

  @override
  void initState() {
    super.initState();
    manager.addListener(_changed);
  }

  @override
  void dispose() {
    manager.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (done != null && mounted) {
        showAppToast(context, done, kind: FeedbackKind.success);
      }
    } on PluginException catch (e) {
      manager.reloadPolicy();
      if (mounted) showPluginError(context, e.message);
    } catch (_) {
      if (mounted) showPluginError(context, appStrings.actionFailedRetry);
    } finally {
      await manager.refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditor(PluginSnapshot s) async {
    final open = widget.openEditor;
    if (open == null) return;
    await open(context, s.id);
    await manager.refresh();
  }

  // ---- Sections ----

  Widget _overview(PluginSnapshot s) {
    final d = s.definition;
    return SettingsSection(
      key: const ValueKey('plugin-overview'),
      title: appStrings.detailOverview,
      children: [
        SettingsRow(
          icon: pluginIcon(d),
          title: d.name,
          description: d.summary,
          control: PluginStatusBadges(snapshot: s),
        ),
        if (!s.available)
          SettingsRow(
            title: appStrings.plgUnavailableReason,
            description: unavailableReason(s),
          ),
        if (d.toggleNote != null)
          SettingsRow(title: appStrings.plgSwitch, description: d.toggleNote),
        SettingsRow(
          title: appStrings.plgLocation,
          description: switch (d.location) {
            ExecutionLocation.device => appStrings.plgLocationDevice,
            ExecutionLocation.network => appStrings.plgLocationNetwork,
            ExecutionLocation.selfHosted => appStrings.plgLocationSelfHosted,
            ExecutionLocation.cloudApi => appStrings.plgLocationCloudApi,
          },
        ),
        if (d.dependsOn.isNotEmpty)
          SettingsRow(
            title: appStrings.plgDependencies,
            description: [
              for (final dep in d.dependsOn)
                appStrings.plgDependency(
                  manager.catalog[dep]!.name,
                  manager.pluginEnabled(dep)
                      ? appStrings.statusAvailable
                      : appStrings.statusUnavailable,
                ),
            ].join(appStrings.listSeparator),
          ),
      ],
    );
  }

  Widget _capabilitiesSection(PluginSnapshot s) {
    final developer = AppAppearance.of(context).developerMode;
    return SettingsSection(
      key: const ValueKey('plugin-capabilities'),
      title: appStrings.plgCapabilities,
      footer: appStrings.plgCapabilitiesFooter,
      children: [
        for (final c in s.definition.capabilities)
          SettingsRow(
            title: c.label,
            description: [
              c.description,
              if (developer) c.id,
              if (developer && c.tools.isNotEmpty)
                'tools: ${c.tools.join(', ')}',
              if (developer && c.routedTools.isNotEmpty)
                'routed: ${c.routedTools.join(', ')}',
            ].join(' · '),
          ),
      ],
    );
  }

  /// Read-only: how many instances there are and their status. Instances
  /// are created where their service is configured (Sources, the external
  /// capability setup button, the dedicated settings), never added here.
  Widget _instancesSection(PluginSnapshot s) {
    final d = s.definition;
    final editable =
        d.sourceKind == null &&
        PluginGroup.of(d) == PluginGroup.builtIn &&
        widget.openEditor != null &&
        s.platformSupported;
    return SettingsSection(
      key: const ValueKey('plugin-instances'),
      title: appStrings.plgInstancesTitle(s.instances.length),
      children: [
        for (final i in s.instances)
          SettingsRow(
            key: ValueKey('plugin-instance-${i.id}'),
            title: i.name,
            description: [
              i.configured
                  ? appStrings.statusConfigured
                  : appStrings.statusNotConfigured,
              instanceAvailable(i)
                  ? appStrings.statusAvailable
                  : appStrings.statusUnavailable,
              ?i.detail,
              if (i.busy) appStrings.plgInstanceBusy(i.playing, i.running),
            ].join(' · '),
          ),
        if (s.instances.isEmpty)
          SettingsRow(
            title: appStrings.plgNoInstances,
            description: s.platformSupported ? null : s.reason,
          ),
        if (editable)
          SettingsRow(
            key: const ValueKey('plugin-open-editor'),
            title: appStrings.plgOpenSettings,
            chevron: true,
            onTap: _busy ? null : () => _openEditor(s),
          ),
      ],
    );
  }

  Widget _writeSection(PluginSnapshot s) => SettingsSection(
    key: const ValueKey('plugin-source-write'),
    title: appStrings.catSourceWrite,
    children: [
      for (final instance in s.instances)
        SettingsRow(
          key: ValueKey('plugin-source-write-${instance.id}'),
          title: instance.name,
          description: appStrings.catSourceWriteDesc,
          control: ShadSwitch(
            key: ValueKey('source-write-switch-${instance.id}'),
            value: manager.sourceWriteGranted(instance.id),
            onChanged: _busy
                ? null
                : (value) => _run(() async {
                    manager.setSourceWrite(instance.id, value);
                  }),
          ),
        ),
    ],
  );

  Widget _runtimeSection(PluginSnapshot s) {
    final developer = AppAppearance.of(context).developerMode;
    return SettingsSection(
      key: const ValueKey('plugin-runtime'),
      title: appStrings.plgRuntime,
      children: [
        for (final i in s.instances)
          if (i.savedRevision != null || i.busy || i.errorCode != null)
            SettingsRow(
              title: i.name,
              description: [
                if (i.savedRevision != null)
                  appStrings.plgRevisions(
                    '${i.savedRevision}',
                    i.appliedRevision == null
                        ? appStrings.plgNotApplied
                        : '${i.appliedRevision}',
                  ),
                if (i.pendingApply) appStrings.plgPendingApply,
                appStrings.plgActivity(i.playing, i.running),
                if (i.errorCode != null) appStrings.plgLastError(i.errorCode!),
              ].join(' · '),
            ),
        SettingsRow(
          title: appStrings.plgRefreshStatus,
          accent: true,
          onTap: _busy ? null : () => _run(() async {}),
        ),
        SettingsRow(
          key: const ValueKey('plugin-copy-diagnostics'),
          title: appStrings.plgCopyDiagnostics,
          description: developer ? appStrings.plgCopyDiagnosticsHint : null,
          onTap: () async {
            await Clipboard.setData(
              ClipboardData(
                text: const JsonEncoder.withIndent('  ')
                    .convert(manager.diagnostics(s.id)),
              ),
            );
            if (mounted) {
              showAppToast(
                context,
                appStrings.plgDiagnosticsCopied,
                kind: FeedbackKind.success,
              );
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = manager.snapshot(widget.pluginId);
    if (s == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SettingsListView(
      children: [
        _overview(s),
        _capabilitiesSection(s),
        _instancesSection(s),
        if (s.definition.capability('source.write') != null) _writeSection(s),
        _runtimeSection(s),
      ],
    );
  }
}
