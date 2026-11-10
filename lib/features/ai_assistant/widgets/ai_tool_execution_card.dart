import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/conversations/conversation_coordinator.dart';
import '../../../ui/icons/app_icons.dart';
import '../models/ai_chat_part.dart';

typedef OpenChatMedia = Future<void> Function(Map<String, dynamic> media);

class AiToolExecutionCard extends StatefulWidget {
  const AiToolExecutionCard({
    super.key,
    required this.part,
    required this.coordinator,
    this.onOpenMedia,
    this.onFavorite,
  });
  final AiChatPart part;
  final ConversationCoordinator coordinator;
  final OpenChatMedia? onOpenMedia;
  final Future<bool> Function(String id)? onFavorite;
  @override
  State<AiToolExecutionCard> createState() => _AiToolExecutionCardState();
}

class _AiToolExecutionCardState extends State<AiToolExecutionCard> {
  bool _acting = false;
  final _favorites = <String, bool>{};
  String _safe(Object? value) {
    final text = '$value'.replaceAll(RegExp(r'https?://\S+'), '…');
    return text.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(text)
        ? text.replaceAll('\\', '/').split('/').last
        : text.substring(0, text.length.clamp(0, 200));
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> data) {
    final result = <Map<String, dynamic>>[];
    if (data['media_id'] is String && data['title'] is String) result.add(data);
    for (final key in [
      'media',
      'library',
      'entries',
      'progress',
      'libraries',
      'resources',
    ]) {
      final list = data[key];
      if (list is List) {
        result.addAll(
          list.whereType<Map>().map((r) => Map<String, dynamic>.from(r)),
        );
      }
    }
    if (data['sources'] case final List sources) {
      for (final source in sources.whereType<Map>()) {
        if (source['entries'] case final List entries) {
          result.addAll(
            entries.whereType<Map>().map(
              (e) => {
                ...Map<String, dynamic>.from(e),
                'source_id': source['source_id'],
              },
            ),
          );
        }
      }
    }
    return result.take(20).toList();
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: Text(AppLocalizations.of(context).aiActionExpired),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.part,
        l = AppLocalizations.of(context),
        theme = ShadTheme.of(context);
    final phase = p.phase!;
    final label = switch (phase) {
      AiToolPhase.preparing => l.aiToolPreparing,
      AiToolPhase.running => l.aiToolRunning,
      AiToolPhase.waiting => l.aiToolWaiting,
      AiToolPhase.success => l.aiToolSucceeded,
      AiToolPhase.failed => l.aiToolFailed,
      AiToolPhase.cancelled => l.aiToolCancelled,
    };
    final rows = _rows(p.data), pending = p.confirmation;
    final description =
        widget.coordinator.gateway.registry[p.tool ?? '']?.description;
    final failures = (p.data['sources'] as List? ?? [])
        .whereType<Map>()
        .where((s) => s['error_code'] != null)
        .toList();
    return ShadCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                phase == AiToolPhase.failed
                    ? AppIcons.error
                    : phase == AiToolPhase.success
                    ? AppIcons.success
                    : AppIcons.preferences,
                size: 18,
              ),
              Text(l.aiToolResult, style: theme.textTheme.small),
              ShadBadge.secondary(child: Text(label)),
            ],
          ),
          if (pending != null) ...[
            const SizedBox(height: 12),
            Text(l.aiConfirmAction, style: theme.textTheme.large),
            if (description != null) Text(description),
            if (pending.targetLabel != null) Text(_safe(pending.targetLabel)),
            if (pending.arguments['favorite'] is bool)
              Text(
                pending.arguments['favorite'] == true
                    ? l.favorite
                    : l.unfavorite,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ShadButton(
                  enabled:
                      !pending.decision.isCompleted &&
                      identical(widget.coordinator.confirmation, pending),
                  onPressed: () => setState(
                    () => widget.coordinator.decide(
                      true,
                      confirmationId: pending.id,
                    ),
                  ),
                  child: Text(l.aiApprove),
                ),
                ShadButton.outline(
                  enabled:
                      !pending.decision.isCompleted &&
                      identical(widget.coordinator.confirmation, pending),
                  onPressed: () => setState(
                    () => widget.coordinator.decide(
                      false,
                      confirmationId: pending.id,
                    ),
                  ),
                  child: Text(l.cancel),
                ),
              ],
            ),
          ] else if (phase == AiToolPhase.running ||
              phase == AiToolPhase.preparing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l.aiToolSummary, style: theme.textTheme.muted),
            ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _safe(row['title'] ?? row['name'] ?? l.media),
                    style: theme.textTheme.small,
                  ),
                  if (row['source_id'] != null)
                    Text(_safe(row['source_id']), style: theme.textTheme.muted),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (widget.onOpenMedia != null &&
                          row['is_folder'] != true &&
                          (row['media_id'] is String ||
                              row['resource_id'] is String ||
                              row['ref'] is String))
                        ShadButton.outline(
                          enabled: !_acting,
                          leading: const Icon(AppIcons.play, size: 16),
                          onPressed: () =>
                              _action(() => widget.onOpenMedia!(row)),
                          child: Text(l.play),
                        ),
                      if (widget.onFavorite != null &&
                          row['media_id'] is String)
                        ShadButton.ghost(
                          enabled: !_acting,
                          onPressed: () => _action(() async {
                            final value = await widget.onFavorite!(
                              row['media_id'] as String,
                            );
                            if (mounted) {
                              setState(
                                () => _favorites[row['media_id'] as String] =
                                    value,
                              );
                            }
                          }),
                          child: Text(
                            (_favorites[row['media_id']] ?? row['favorite']) ==
                                    true
                                ? l.unfavorite
                                : l.favorite,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (failures.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${l.aiPartialFailure} · ${failures.map((s) => _safe(s['source_id'])).join(', ')}',
              ),
            ),
          if (p.data['task_id'] is String)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l.aiTaskSubmitted),
            ),
          if (p.data['next_offset'] != null ||
              p.data['library_next_offset'] != null)
            Text(l.aiMoreResults, style: theme.textTheme.muted),
          if (phase == AiToolPhase.failed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l.aiToolFailed, style: theme.textTheme.muted),
            ),
        ],
      ),
    );
  }
}
