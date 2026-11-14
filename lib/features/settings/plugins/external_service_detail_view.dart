import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../services/ai_tools/json_schema_lite.dart';
import '../../../services/external/external_service_registry.dart';
import '../../../services/external/external_service_setup.dart';
import '../../../ui/components/feedback/app_feedback.dart';
import '../../../ui/components/settings/settings_section.dart';
import 'plugin_management_page.dart';

/// One custom external capability: what the service is, its tools, and
/// re-check / remove. Read-only otherwise; re-adding the same address from
/// 配置 updates it.
class ExternalServiceDetailView extends StatefulWidget {
  const ExternalServiceDetailView({
    super.key,
    required this.setup,
    required this.serviceId,
    this.onRemoved,
  });
  final ExternalServiceSetup setup;
  final String serviceId;
  final VoidCallback? onRemoved;

  @override
  State<ExternalServiceDetailView> createState() =>
      _ExternalServiceDetailViewState();
}

class _ExternalServiceDetailViewState extends State<ExternalServiceDetailView> {
  bool _busy = false;
  String? _error;

  ExternalServiceRegistry get registry => widget.setup.registry;

  Future<void> _recheck(ExternalService s) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.setup.recheck(s);
      if (mounted) showAppToast(context, '连接正常', kind: FeedbackKind.success);
    } on ExternalServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(ExternalService s) async {
    final ok = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog(
        title: Text('移除「${s.name}」？'),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ShadButton(
            key: const ValueKey('external-remove-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
        child: const Text('只移除 App 中的地址和令牌，不会影响服务器上的数据。'),
      ),
    );
    if (ok != true) return;
    await registry.remove(s.id);
    widget.onRemoved?.call();
  }

  /// Why a listed tool is not offered to the AI, or its description.
  static String? _toolNote(ExternalService s, String tool) {
    final def = s.toolDefs.where((d) => d['name'] == tool).firstOrNull;
    if (def == null) return '需要重新检测';
    final schema = def['inputSchema'] is Map
        ? def['inputSchema'] as Map
        : const {'type': 'object'};
    final problem = JsonSchemaLite.unsupported(schema);
    if (problem != null) return 'AI 暂不可用：$problem';
    final readOnly =
        def['annotations'] is Map &&
        (def['annotations'] as Map)['readOnlyHint'] == true;
    final text = def['description'] as String?;
    return [?text, if (!readOnly) '调用前需要你确认'].join(' · ');
  }

  static String _aiSummary(ExternalService s) {
    if (!s.available) return '服务当前不可用，AI 暂时无法调用';
    if (s.toolDefs.isEmpty && s.tools.isNotEmpty) {
      return '请点“重新检测”以获取工具定义';
    }
    final usable = s.toolDefs.where((d) {
      final schema = d['inputSchema'] is Map
          ? d['inputSchema'] as Map
          : const {'type': 'object'};
      return JsonSchemaLite.unsupported(schema) == null;
    }).length;
    return 'AI 可直接调用 $usable / ${s.tools.length} 个工具；会改变状态的操作会先请你确认';
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: registry.changes.stream,
    builder: (context, _) {
      final s = registry.get(widget.serviceId);
      if (s == null) {
        return const Center(child: Text('这个外部能力已移除'));
      }
      return SettingsListView(
        children: [
          if (_error != null)
            AppAlert.error(
              key: const ValueKey('external-error'),
              title: _error!,
            ),
          SettingsSection(
            key: const ValueKey('external-overview'),
            title: '概览',
            children: [
              SettingsRow(
                title: s.name,
                description: [
                  if (s.label.isNotEmpty) s.label,
                  if (s.version.isNotEmpty) '版本 ${s.version}',
                ].join(' · '),
                control: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const StatusBadge(label: '已配置', positive: true),
                    const SizedBox(width: 4),
                    StatusBadge(
                      label: s.available ? '可用' : '不可用',
                      positive: s.available,
                    ),
                  ],
                ),
              ),
              SettingsRow(title: '地址', description: s.endpoint),
              SettingsRow(
                key: const ValueKey('external-ai'),
                title: 'AI 调用',
                description: _aiSummary(s),
              ),
            ],
          ),
          SettingsSection(
            key: const ValueKey('external-tools'),
            title: '工具（${s.tools.length} 个）',
            children: [
              for (final t in s.tools)
                SettingsRow(title: t, description: _toolNote(s, t)),
              if (s.tools.isEmpty) const SettingsRow(title: '没有工具'),
            ],
          ),
          SettingsSection(
            children: [
              SettingsRow(
                key: const ValueKey('external-recheck'),
                title: '重新检测',
                accent: true,
                onTap: _busy ? null : () => _recheck(s),
              ),
              SettingsRow(
                key: const ValueKey('external-remove'),
                title: '移除',
                destructive: true,
                onTap: _busy ? null : () => _remove(s),
              ),
            ],
          ),
        ],
      );
    },
  );
}
