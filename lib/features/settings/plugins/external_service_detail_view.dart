import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../services/ai_tools/json_schema_lite.dart';
import '../../../services/external/external_service_registry.dart';
import '../../../services/external/external_service_setup.dart';
import '../../../ui/components/feedback/app_feedback.dart';
import '../../../ui/components/settings/settings_section.dart';
import 'plugin_management_page.dart';
import '../../../l10n/l10n.dart';

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
      if (mounted) {
        showAppToast(
          context,
          appStrings.extConnectionOk,
          kind: FeedbackKind.success,
        );
      }
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
        title: Text(appStrings.extRemoveConfirmTitle(s.displayName)),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.pop(context, false),
            child: Text(appStrings.cancel),
          ),
          ShadButton(
            key: const ValueKey('external-remove-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(appStrings.remove),
          ),
        ],
        child: Text(appStrings.extRemoveConfirmMessage),
      ),
    );
    if (ok != true) return;
    await registry.remove(s.id);
    widget.onRemoved?.call();
  }

  /// Why a listed tool is not offered to the AI, or its description.
  static String? _toolNote(ExternalService s, String tool) {
    final def = s.toolDefs.where((d) => d['name'] == tool).firstOrNull;
    if (def == null) return appStrings.extNeedsRecheck;
    final schema = def['inputSchema'] is Map
        ? def['inputSchema'] as Map
        : const {'type': 'object'};
    final problem = JsonSchemaLite.unsupported(schema);
    if (problem != null) return appStrings.extToolAiUnavailable(problem);
    final readOnly =
        def['annotations'] is Map &&
        (def['annotations'] as Map)['readOnlyHint'] == true;
    final text = def['description'] as String?;
    return [?text, if (!readOnly) appStrings.extToolNeedsConfirm].join(' · ');
  }

  static String _aiSummary(ExternalService s) {
    if (!s.available) return appStrings.extAiServiceUnavailable;
    if (s.toolDefs.isEmpty && s.tools.isNotEmpty) {
      return appStrings.extAiNeedsRecheck;
    }
    final usable = s.toolDefs.where((d) {
      final schema = d['inputSchema'] is Map
          ? d['inputSchema'] as Map
          : const {'type': 'object'};
      return JsonSchemaLite.unsupported(schema) == null;
    }).length;
    return appStrings.extAiSummary(usable, s.tools.length);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: registry.changes.stream,
    builder: (context, _) {
      final s = registry.get(widget.serviceId);
      if (s == null) {
        return Center(child: Text(appStrings.extRemoved));
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
            title: appStrings.detailOverview,
            children: [
              SettingsRow(
                title: s.displayName,
                description: [
                  if (s.label.isNotEmpty) s.label,
                  if (s.version.isNotEmpty) appStrings.extVersion(s.version),
                ].join(' · '),
                control: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusBadge(
                      label: appStrings.statusConfigured,
                      positive: true,
                    ),
                    const SizedBox(width: 4),
                    StatusBadge(
                      label: s.available
                          ? appStrings.statusAvailable
                          : appStrings.statusUnavailable,
                      positive: s.available,
                    ),
                  ],
                ),
              ),
              SettingsRow(title: appStrings.address, description: s.endpoint),
              SettingsRow(
                key: const ValueKey('external-ai'),
                title: appStrings.extAiCalls,
                description: _aiSummary(s),
              ),
            ],
          ),
          SettingsSection(
            key: const ValueKey('external-tools'),
            title: appStrings.extToolsTitle(s.tools.length),
            children: [
              for (final t in s.tools)
                SettingsRow(title: t, description: _toolNote(s, t)),
              if (s.tools.isEmpty) SettingsRow(title: appStrings.extNoTools),
            ],
          ),
          SettingsSection(
            children: [
              SettingsRow(
                key: const ValueKey('external-recheck'),
                title: appStrings.extRecheck,
                accent: true,
                onTap: _busy ? null : () => _recheck(s),
              ),
              SettingsRow(
                key: const ValueKey('external-remove'),
                title: appStrings.remove,
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
