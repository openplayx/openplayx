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
import '../../../ui/tokens/app_spacing.dart';
import '../../sources/source_instance_form.dart';
import 'plugin_management_page.dart';

/// One plugin: overview & capabilities, instances, AI scope, permissions and
/// runtime diagnostics. Source instances are edited with the same form and
/// configuration service as the Sources page; other plugins open their
/// dedicated editors, so configuration is never stored twice.
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
        ShadToaster.maybeOf(context)?.show(ShadToast(description: Text(done)));
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

  // ---- Instance actions (sources share the Sources page flow) ----

  Future<void> _addInstance(PluginSnapshot s) async {
    final kind = s.definition.sourceKind;
    final sources = widget.sources;
    if (kind != null && sources != null) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              SourceInstanceForm(manager: sources, initialKind: kind),
        ),
      );
      await manager.refresh();
      return;
    }
    await _openEditor(s);
  }

  Future<void> _openEditor(PluginSnapshot s) async {
    final open = widget.openEditor;
    if (open == null) return;
    await open(context, s.id);
    await manager.refresh();
  }

  Future<void> _editSource(PluginInstanceView i) async {
    final sources = widget.sources!;
    final config = sources.configs.where((c) => c.id == i.id).firstOrNull;
    if (config == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SourceInstanceForm(manager: sources, initial: config),
      ),
    );
    await manager.refresh();
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showShadDialog<bool>(
        context: context,
        builder: (context) => ShadDialog(
          title: Text(title),
          actions: [
            ShadButton.ghost(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ShadButton(
              key: const ValueKey('plugin-action-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
          child: Text(body),
        ),
      ) ==
      true;

  Future<void> _toggleSource(PluginInstanceView i, bool enabled) async {
    if (!enabled && i.busy) {
      final impact = manager.impact(i.pluginId, instanceId: i.id);
      if (!await _confirm('停用「${i.name}」？', impactText(impact), '停用')) {
        return;
      }
    }
    await _run(() => widget.sources!.setEnabled(i.id, enabled));
  }

  Future<void> _removeSource(PluginInstanceView i) async {
    if (i.enabled) {
      showPluginError(context, '请先停用实例并等待播放或请求结束，再移除。');
      return;
    }
    if (i.busy) {
      showPluginError(context, '实例仍有播放或请求在使用连接，请稍后再移除。');
      return;
    }
    if (!await _confirm(
      '移除「${i.name}」？',
      '只移除 App 中的连接配置与凭据；不会删除原媒体文件、字幕、播放历史或服务器上的数据。',
      '移除',
    )) {
      return;
    }
    await _run(() => widget.sources!.remove(i.id));
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
          control: PluginStateBadge(
            state: s.unconfigured ? PluginRuntimeState.disabled : s.state,
            label: s.unconfigured ? '未配置' : null,
          ),
        ),
        if (s.reason != null) SettingsRow(title: '当前状态', description: s.reason),
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
        SettingsRow(title: '版本与来源', description: '${d.version} · 随 App 内置'),
        SettingsRow(
          title: '执行位置',
          description: switch (d.location) {
            ExecutionLocation.device => '在本机运行',
            ExecutionLocation.network => 'App 在本机连接你配置的存储服务',
            ExecutionLocation.selfHosted => 'App 在本机运行适配器，实际工作在你配置的服务器上进行',
            ExecutionLocation.cloudApi => 'App 在本机调用云端 API',
          },
        ),
        SettingsRow(
          title: '平台支持',
          description: s.platformSupported ? '当前设备支持' : s.reason ?? '当前设备不支持',
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

  String _capabilityStatus(PluginSnapshot s, PluginCapabilityInfo c) {
    if (!s.platformSupported) return '当前设备不支持';
    if (!manager.pluginEnabled(s.id)) {
      return s.enabled ? '依赖不可用' : '插件已停用';
    }
    final providers = manager.capabilities
        .forPlugin(s.id)
        .where((r) => r.capabilityId == c.id)
        .toList();
    if (providers.isEmpty) {
      return s.definition.multiInstance ? '没有可用实例' : '尚未就绪';
    }
    final names = s.definition.multiInstance
        ? '：${providers.map((p) => p.instanceName).join('、')}'
        : '';
    return '可用$names';
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
              _capabilityStatus(s, c),
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

  Widget _instancesSection(PluginSnapshot s) {
    final d = s.definition;
    final isSource = d.sourceKind != null && widget.sources != null;
    final rows = <Widget>[
      for (final i in s.instances)
        SettingsRow(
          key: ValueKey('plugin-instance-${i.id}'),
          title: i.name,
          description: <String>{
            i.state.label,
            if (i.health != InstanceHealth.unchecked ||
                i.state != PluginRuntimeState.validating)
              i.health.label,
            ?i.detail,
            if (i.busy) '使用中：播放 ${i.playing} · 请求 ${i.running}',
          }.join(' · '),
          control: isSource
              ? ShadSwitch(
                  key: ValueKey('plugin-instance-switch-${i.id}'),
                  value: i.enabled,
                  onChanged: _busy ? null : (v) => _toggleSource(i, v),
                )
              : null,
        ),
      if (isSource)
        for (final i in s.instances)
          Wrap(
            key: ValueKey('plugin-instance-actions-${i.id}'),
            spacing: AppSpacing.xs,
            children: [
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: _busy ? null : () => _editSource(i),
                child: Text('编辑「${i.name}」'),
              ),
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: _busy || !i.enabled
                    ? null
                    : () => _run(
                        () => widget.sources!.testConnection(i.id),
                        done: '「${i.name}」连接正常',
                      ),
                child: const Text('连接测试'),
              ),
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: _busy ? null : () => _removeSource(i),
                child: const Text('移除'),
              ),
            ],
          ),
      if (s.instances.isEmpty)
        SettingsRow(
          title: d.multiInstance ? '尚未添加实例' : '不可用',
          description: s.platformSupported ? null : s.reason,
        ),
      if (s.platformSupported && d.multiInstance)
        SettingsRow(
          key: const ValueKey('plugin-add-instance'),
          title: '添加实例',
          description: '为 ${d.name} 配置一个新的连接（新实例默认不向 AI 开放）',
          accent: true,
          onTap: _busy ? null : () => _addInstance(s),
        ),
      if (!isSource && widget.openEditor != null && s.platformSupported)
        SettingsRow(
          key: const ValueKey('plugin-open-editor'),
          title: d.multiInstance ? '编辑实例与连接' : '打开设置',
          chevron: true,
          onTap: _busy ? null : () => _openEditor(s),
        ),
    ];
    return SettingsSection(
      key: const ValueKey('plugin-instances'),
      title: d.multiInstance ? '实例与连接配置' : '实例',
      children: rows,
    );
  }

  Widget _aiSection(PluginSnapshot s) {
    final d = s.definition;
    final ai = manager.policy.aiFor(s.id);
    final aiCaps = d.capabilities.where((c) => c.hasAiTools).toList();
    if (aiCaps.isEmpty) {
      return SettingsSection(
        key: const ValueKey('plugin-ai'),
        title: 'AI 调用',
        children: [
          SettingsRow(
            title: '没有 AI 工具',
            description: d.id == 'model.llm'
                ? '此插件为 AI 助手提供模型，本身不作为工具暴露。'
                : '此插件当前只在传统页面中使用，AI 助手无法直接调用。',
          ),
        ],
      );
    }
    final uploads = aiCaps.any((c) => c.uploads);
    final writes = aiCaps.any((c) => c.writes);
    return SettingsSection(
      key: const ValueKey('plugin-ai'),
      title: 'AI 调用',
      footer: [
        '关闭后传统页面仍可使用此插件。AI 能用的工具 = 已实现 ∩ 平台支持 ∩ 已启用插件与实例 ∩ 此处授权；执行前会再次检查。',
        if (uploads) '上传仍需在每个实例上单独授权，此开关不能代替上传授权。',
        if (writes) '会改变状态的操作（创建任务、删除）仍需你在对话中逐次确认。',
      ].join('\n'),
      children: [
        SettingsRow(
          title: '允许 AI 使用',
          description: ai.allowed
              ? 'AI 可用 ${s.aiCapabilities.length}/${aiCaps.length} 项能力'
              : 'AI 无法调用此插件',
          control: ShadSwitch(
            key: const ValueKey('plugin-ai-switch'),
            value: ai.allowed,
            onChanged: (v) => _run(() async => manager.setAiAllowed(s.id, v)),
          ),
        ),
        if (ai.allowed && d.multiInstance)
          for (final i in s.instances)
            SettingsRow(
              key: ValueKey('plugin-ai-instance-${i.id}'),
              title: '实例：${i.name}',
              description: i.enabled ? null : '实例已停用',
              control: ShadSwitch(
                key: ValueKey('plugin-ai-instance-switch-${i.id}'),
                value: ai.instances.contains(i.id),
                onChanged: (v) =>
                    _run(() async => manager.setAiInstance(s.id, i.id, v)),
              ),
            ),
        if (ai.allowed && aiCaps.length > 1)
          for (final c in aiCaps)
            SettingsRow(
              key: ValueKey('plugin-ai-capability-${c.id}'),
              title: '能力：${c.label}',
              description: [
                if (c.optIn) '需单独开启',
                if (c.uploads) '会上传数据',
                if (c.writes) '会改变状态',
              ].join(' · ').ifEmpty(null),
              control: ShadSwitch(
                value: c.optIn
                    ? ai.grantedCapabilities.contains(c.id)
                    : !ai.deniedCapabilities.contains(c.id),
                onChanged: (v) =>
                    _run(() async => manager.setAiCapability(s.id, c.id, v)),
              ),
            ),
      ],
    );
  }

  Widget _permissionsSection(PluginSnapshot s) {
    final d = s.definition;
    final targets = {
      for (final i in s.instances)
        if (i.networkTarget != null && i.networkTarget!.isNotEmpty)
          i.networkTarget!,
    };
    return SettingsSection(
      key: const ValueKey('plugin-permissions'),
      title: '权限与数据范围',
      children: [
        if (d.dataNote != null)
          SettingsRow(title: '数据范围', description: d.dataNote),
        SettingsRow(
          title: '网络目标',
          description: targets.isEmpty
              ? (d.location == ExecutionLocation.device ? '不访问网络' : '尚未配置')
              : targets.join('、'),
        ),
        if (d.sourceKind?.files == true &&
            d.location == ExecutionLocation.device)
          SettingsRow(
            title: '授权目录',
            description: s.instances.isEmpty
                ? '尚未授权任何文件夹'
                : '${s.instances.length} 个文件夹，可在实例编辑中重新选择',
          ),
        for (final i in s.instances)
          if (i.uploadAuthorized != null)
            SettingsRow(
              key: ValueKey('plugin-upload-${i.id}'),
              title: '上传授权：${i.name}',
              description: i.uploadAuthorized!
                  ? '已允许上传音频到 ${i.networkTarget}'
                  : '未授权；首次识别时会请求授权',
              control: i.uploadAuthorized!
                  ? ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => manager.revokeUploadConsent(i.id),
                              done: '已撤销上传授权',
                            ),
                      child: const Text('撤销'),
                    )
                  : null,
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
              ShadToaster.maybeOf(context)
                  ?.show(const ShadToast(description: Text('已复制诊断信息')));
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
        _aiSection(s),
        _permissionsSection(s),
        _runtimeSection(s),
      ],
    );
  }
}

extension on String {
  String? ifEmpty(String? fallback) => isEmpty ? fallback : this;
}
