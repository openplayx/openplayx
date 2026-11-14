import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme/app_theme_controller.dart';
import '../../../core/plugins/source_capability.dart';
import '../../../data/sources/source_manager.dart';
import '../../../services/plugins/plugin_catalog.dart';
import '../../../services/plugins/plugin_manager.dart';
import '../../../ui/components/settings/settings_section.dart';
import 'plugin_management_page.dart';
import '../../../ui/components/feedback/app_feedback.dart';

/// One plugin: overview & capabilities, instances and runtime diagnostics.
/// Every capability of an enabled plugin is AI-callable, so there is no
/// separate AI or permission section. Instances are only listed here.
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
      if (mounted) showPluginError(context, '操作失败，请重试。');
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
      title: '概览',
      children: [
        SettingsRow(
          icon: d.icon,
          title: d.name,
          description: d.summary,
          control: PluginStatusBadges(snapshot: s),
        ),
        if (!s.available)
          SettingsRow(title: '不可用原因', description: unavailableReason(s)),
        SettingsRow(
          title: '插件开关',
          description: d.toggleable
              ? (s.enabled ? '允许承接新的业务调用' : '已阻止新的调用；实例配置保留')
              : d.toggleNote,
          control: d.toggleable && s.platformSupported
              ? ShadSwitch(
                  key: const ValueKey('plugin-detail-switch'),
                  value: s.enabled,
                  onChanged: (v) => togglePlugin(context, manager, s, v),
                )
              : null,
        ),
        SettingsRow(
          title: '执行位置',
          description: switch (d.location) {
            ExecutionLocation.device => '在本机运行',
            ExecutionLocation.network => 'App 在本机连接你配置的存储服务',
            ExecutionLocation.selfHosted => 'App 在本机运行适配器，实际工作在你配置的服务器上进行',
            ExecutionLocation.cloudApi => 'App 在本机调用云端 API',
          },
        ),
        if (d.dependsOn.isNotEmpty)
          SettingsRow(
            title: '依赖',
            description: [
              for (final dep in d.dependsOn)
                '${manager.catalog[dep]!.name}（${manager.pluginEnabled(dep) ? '可用' : '不可用'}）',
            ].join('、'),
          ),
      ],
    );
  }

  Widget _capabilitiesSection(PluginSnapshot s) {
    final developer = AppAppearance.of(context).developerMode;
    return SettingsSection(
      key: const ValueKey('plugin-capabilities'),
      title: '能力',
      footer: '只列出此插件真实实现的方法；未实现的能力不会显示。',
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
  /// are created where their service is configured (来源, the 外部能力
  /// 配置 button, the dedicated settings), never added here.
  Widget _instancesSection(PluginSnapshot s) {
    final d = s.definition;
    final editable =
        d.sourceKind == null &&
        PluginGroup.of(d) == PluginGroup.builtIn &&
        widget.openEditor != null &&
        s.platformSupported;
    return SettingsSection(
      key: const ValueKey('plugin-instances'),
      title: '实例（${s.instances.length} 个）',
      children: [
        for (final i in s.instances)
          SettingsRow(
            key: ValueKey('plugin-instance-${i.id}'),
            title: i.name,
            description: [
              i.configured ? '已配置' : '未配置',
              instanceAvailable(i) ? '可用' : '不可用',
              ?i.detail,
              if (i.busy) '使用中：播放 ${i.playing} · 请求 ${i.running}',
            ].join(' · '),
          ),
        if (s.instances.isEmpty)
          SettingsRow(
            title: '暂无实例',
            description: s.platformSupported ? null : s.reason,
          ),
        if (editable)
          SettingsRow(
            key: const ValueKey('plugin-open-editor'),
            title: '打开设置',
            chevron: true,
            onTap: _busy ? null : () => _openEditor(s),
          ),
      ],
    );
  }

  Widget _runtimeSection(PluginSnapshot s) {
    final developer = AppAppearance.of(context).developerMode;
    return SettingsSection(
      key: const ValueKey('plugin-runtime'),
      title: '运行状态与诊断',
      children: [
        for (final i in s.instances)
          if (i.savedRevision != null || i.busy || i.errorCode != null)
            SettingsRow(
              title: i.name,
              description: [
                if (i.savedRevision != null)
                  '已保存修订 ${i.savedRevision} · 实际生效 ${i.appliedRevision ?? '尚未生效'}',
                if (i.pendingApply) '新配置待生效，旧修订仍在服务进行中的调用',
                '活动播放 ${i.playing} · 进行中请求 ${i.running}',
                if (i.errorCode != null) '最近错误：${i.errorCode}',
              ].join(' · '),
            ),
        SettingsRow(
          title: '刷新状态',
          accent: true,
          onTap: _busy ? null : () => _run(() async {}),
        ),
        SettingsRow(
          key: const ValueKey('plugin-copy-diagnostics'),
          title: '复制脱敏诊断信息',
          description: developer ? '不含地址、账号、路径或密钥' : null,
          onTap: () async {
            await Clipboard.setData(
              ClipboardData(
                text: const JsonEncoder.withIndent('  ')
                    .convert(manager.diagnostics(s.id)),
              ),
            );
            if (mounted) {
              showAppToast(context, '已复制诊断信息', kind: FeedbackKind.success);
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
        _runtimeSection(s),
      ],
    );
  }
}
