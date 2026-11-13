import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/conversations/conversation_coordinator.dart';
import '../../../ui/icons/app_icons.dart';
import '../../settings/torrent_service_settings_page.dart'
    show torrentHoldLabel, torrentStateLabel;
import '../models/ai_chat_part.dart';
import '../models/ai_tool_labels.dart';
import 'ai_activity.dart';

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

  /// Server-side BitTorrent tasks from torrent_* tools.
  List<Map<String, dynamic>> _torrentRows(Map<String, dynamic> data) => [
    if (data['torrent_task'] case final Map t) Map<String, dynamic>.from(t),
    if (data['task'] case final Map t when t['location'] == 'server')
      Map<String, dynamic>.from(t),
    if (data['torrent_tasks'] case final List list)
      ...list.whereType<Map>().take(20).map(Map<String, dynamic>.from),
  ];

  Widget _torrentCard(Map<String, dynamic> t, ShadThemeData theme) {
    final progress = (t['progress'] as num? ?? 0).toDouble().clamp(0.0, 1.0);
    final state = t['state'] as String? ?? '';
    final l = AppLocalizations.of(context);
    String speed(Object? v) =>
        '${((v as num? ?? 0) / (1 << 20)).toStringAsFixed(1)} MB/s';
    final status = [
      '${l.torrentServerDownload} · ${_safe(t['server_name'] ?? '')}',
      torrentStateLabel(l, state) ?? state,
      if (torrentHoldLabel(l, t['hold_reason']) case final String hold) hold,
      '${(progress * 100).toStringAsFixed(1)}%',
      if ((t['download_speed'] as num? ?? 0) > 0)
        '↓${speed(t['download_speed'])}',
      if ((t['upload_speed'] as num? ?? 0) > 0) '↑${speed(t['upload_speed'])}',
      if (t['stale'] == true) l.torrentStatusStale,
      if (t['error_code'] != null) _safe(t['error_code']),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_safe(t['name']), style: theme.textTheme.small),
          Text(status, style: theme.textTheme.muted),
          const SizedBox(height: 4),
          ShadProgress(value: progress),
          if (t['selected_files_complete'] == true)
            Text(l.torrentServerOnlyComplete, style: theme.textTheme.muted),
        ],
      ),
    );
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
              Text(
                p.tool == null
                    ? l.aiToolResult
                    : AiToolLabels.tool(context, p.tool),
                style: theme.textTheme.small,
              ),
              ShadBadge.secondary(child: Text(label)),
              if (phase == AiToolPhase.running)
                AiElapsed(
                  since: p.turn.activitySince,
                  style: theme.textTheme.muted,
                ),
            ],
          ),
          if (AiToolLabels.arguments(context, p.arguments)
              case final String args when args.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(args, style: theme.textTheme.muted),
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
          ] else if (phase == AiToolPhase.running && p.progress != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AiToolLabels.progress(context, p.progress!),
                    style: theme.textTheme.muted,
                  ),
                  const SizedBox(height: 4),
                  ShadProgress(
                    value: (p.progress!['progress'] as num?)?.toDouble(),
                  ),
                ],
              ),
            )
          else if (phase == AiToolPhase.running ||
              phase == AiToolPhase.preparing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const AiTypingDots(size: 4),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l.aiToolSummary, style: theme.textTheme.muted),
                  ),
                ],
              ),
            ),
          for (final t in _torrentRows(p.data)) _torrentCard(t, theme),
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
              child: Text(
                p.data['wait_timed_out'] == true
                    ? '${AiToolLabels.stillRunning(context)} · ${AiToolLabels.progress(context, p.data)}'
                    : p.data['status'] is String
                    ? AiToolLabels.progress(context, p.data)
                    : l.aiTaskSubmitted,
              ),
            ),
          if (p.tool == 'media_save_to_source' && p.data['name'] is String)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${p.data['folder'] ?? 'OpenPlayX'}/${_safe(p.data['name'])}',
                style: theme.textTheme.small,
              ),
            ),
          if (p.data['next_offset'] != null ||
              p.data['library_next_offset'] != null)
            Text(l.aiMoreResults, style: theme.textTheme.muted),
          if (phase == AiToolPhase.failed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                p.text.isEmpty
                    ? l.aiToolFailed
                    : '${l.aiToolFailed} · ${_safe(p.text)}',
                style: theme.textTheme.muted,
              ),
            ),
        ],
      ),
    );
  }
}
