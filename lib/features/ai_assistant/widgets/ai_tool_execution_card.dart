import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/conversations/conversation_coordinator.dart';
import '../../../ui/icons/app_icons.dart';
import '../models/ai_chat_part.dart';
import '../models/ai_tool_labels.dart';
import 'ai_activity.dart';
import 'ai_disclosure.dart';
import '../../../ui/tokens/app_semantic_colors.dart';
import '../../../ui/components/feedback/app_feedback.dart';

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
        showAppToast(
          context,
          AppLocalizations.of(context).aiActionExpired,
          kind: FeedbackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Widget _section(String title, List<Widget> children, ShadThemeData theme) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.muted.copyWith(
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      );

  /// Status glyph before the label, as in the header of a tool step.
  Widget _statusIcon(AiToolPhase phase, ShadThemeData theme) {
    final colors = theme.colorScheme;
    return switch (phase) {
      AiToolPhase.preparing || AiToolPhase.running => const AiSpinner(),
      AiToolPhase.success => Icon(
        AppIcons.success,
        size: 15,
        color: AppSemanticColors.of(context).success,
      ),
      AiToolPhase.failed => Icon(
        AppIcons.failed,
        size: 15,
        color: colors.destructive,
      ),
      AiToolPhase.cancelled => Icon(
        AppIcons.failed,
        size: 15,
        color: colors.destructive.withValues(alpha: 0.7),
      ),
      AiToolPhase.waiting => Icon(
        AppIcons.tool,
        size: 13,
        color: colors.mutedForeground,
      ),
    };
  }

  static final _sensitiveKey = RegExp(
    r'secret|token|passw|api_?key|authorization|cookie|credential',
    caseSensitive: false,
  );
  static const _previewLimit = 10000;
  bool _showAll = false;

  /// Unwraps JSON that may be encoded more than once; plain text stays text.
  static Object? _decode(String text) {
    Object? value = text;
    while (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        break;
      }
    }
    return value;
  }

  /// Masks values under credential-like keys, at any depth.
  static Object? _redact(Object? value) => switch (value) {
    Map() => {
      for (final e in value.entries)
        '${e.key}': _sensitiveKey.hasMatch('${e.key}')
            ? '••••••'
            : _redact(e.value),
    },
    List() => value.map(_redact).toList(),
    _ => value,
  };

  TextStyle _mono(ShadThemeData theme) => theme.textTheme.small.copyWith(
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.w400,
    fontFamily: 'Menlo',
    fontFamilyFallback: const [
      'SF Mono',
      'Consolas',
      'Roboto Mono',
      'monospace',
    ],
    color: theme.colorScheme.foreground.withValues(alpha: 0.8),
  );

  /// What was called, with which input, and what came back, as exchanged
  /// with the model. Built only once the user opens the step.
  Widget? _details(AiChatPart p, ShadThemeData theme) {
    final colors = theme.colorScheme;
    final muted = theme.textTheme.muted.copyWith(fontSize: 12);
    final mono = _mono(theme);
    final args = _redact(_decode(p.rawArguments));
    final hasArgs = switch (args) {
      Map() => args.isNotEmpty,
      String() => args.trim().isNotEmpty,
      null => false,
      _ => true,
    };
    final hasResult = p.rawResult.isNotEmpty;
    if (p.tool == null && !hasArgs && !hasResult) return null;

    Widget codeBox(String text) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText(text, style: mono),
      ),
    );

    final input = <Widget>[
      if (args case final Map map)
        for (final e in map.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e.key}', style: muted),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    e.value is String ? e.value as String : jsonEncode(e.value),
                    style: mono,
                  ),
                ),
              ],
            ),
          )
      else if (hasArgs)
        codeBox(
          args is String
              ? args
              : const JsonEncoder.withIndent('  ').convert(args),
        ),
    ];

    final output = <Widget>[];
    if (hasResult) {
      final result = _redact(_decode(p.rawResult));
      if (result is Map || result is List) {
        output.add(codeBox(const JsonEncoder.withIndent('  ').convert(result)));
      } else {
        final text = '$result';
        final cut = text.length > _previewLimit && !_showAll;
        output.add(
          SelectableText(
            cut ? text.substring(0, _previewLimit) : text,
            style: mono,
          ),
        );
        if (cut) {
          output.add(
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ShadButton.link(
                padding: EdgeInsets.zero,
                height: 24,
                textStyle: muted,
                onPressed: () => setState(() => _showAll = true),
                child: Text(
                  AiToolLabels.showAll(context, text.length),
                  style: muted,
                ),
              ),
            ),
          );
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.tool != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: SelectableText(p.tool!, style: mono),
            ),
          if (input.isNotEmpty)
            _section(AiToolLabels.toolInput(context), input, theme),
          if (input.isNotEmpty && output.isNotEmpty) const SizedBox(height: 8),
          if (output.isNotEmpty)
            _section(AiToolLabels.toolOutput(context), output, theme),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.part,
        l = AppLocalizations.of(context),
        theme = ShadTheme.of(context);
    final phase = p.phase!;
    final name = p.tool == null
        ? l.aiToolResult
        : AiToolLabels.tool(context, p.tool);
    final rows = _rows(p.data), pending = p.confirmation;
    final description =
        widget.coordinator.gateway.registry[p.tool ?? '']?.description;
    final failures = (p.data['sources'] as List? ?? [])
        .whereType<Map>()
        .where((s) => s['error_code'] != null)
        .toList();
    final muted = theme.textTheme.muted;
    final small = theme.textTheme.small.copyWith(fontSize: 12);

    // Result cards the user can act on, built from the tool's record.
    final results = <Widget>[
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _safe(row['title'] ?? row['name'] ?? l.media),
                style: theme.textTheme.small,
              ),
              if (row['source_id'] != null)
                Text(_safe(row['source_id']), style: muted),
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
                      size: ShadButtonSize.sm,
                      height: 30,
                      enabled: !_acting,
                      leading: const Icon(AppIcons.play, size: 16),
                      onPressed: () => _action(() => widget.onOpenMedia!(row)),
                      child: Text(l.play),
                    ),
                  if (widget.onFavorite != null && row['media_id'] is String)
                    ShadButton.ghost(
                      size: ShadButtonSize.sm,
                      height: 30,
                      enabled: !_acting,
                      onPressed: () => _action(() async {
                        final value = await widget.onFavorite!(
                          row['media_id'] as String,
                        );
                        if (mounted) {
                          setState(
                            () => _favorites[row['media_id'] as String] = value,
                          );
                        }
                      }),
                      child: Text(
                        (_favorites[row['media_id']] ?? row['favorite']) == true
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
            style: small,
          ),
        ),
      if (p.data['task_id'] is String)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            p.data['wait_timed_out'] == true
                ? '${AiToolLabels.stillRunning(context)} · ${AiToolLabels.progress(context, p.data)}'
                : p.data['status'] is String
                ? AiToolLabels.progress(context, p.data)
                : l.aiTaskSubmitted,
            style: small,
          ),
        ),
      if (p.tool == 'media_save_to_source' && p.data['name'] is String)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${p.data['folder'] ?? 'OpenPlayX'}/${_safe(p.data['name'])}',
            style: small,
          ),
        ),
      if (p.data['next_offset'] != null ||
          p.data['library_next_offset'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(l.aiMoreResults, style: muted),
        ),
      if (phase == AiToolPhase.failed)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            p.text.isEmpty
                ? l.aiToolFailed
                : '${l.aiToolFailed} · ${_safe(p.text)}',
            style: small,
          ),
        ),
    ];

    final body = _details(p, theme);

    final canDecide =
        pending != null &&
        !pending.decision.isCompleted &&
        identical(widget.coordinator.confirmation, pending);
    final decide = pending == null
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShadButton.secondary(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: theme.textTheme.small.copyWith(fontSize: 12),
                enabled: canDecide,
                onPressed: () => setState(
                  () => widget.coordinator.decide(
                    true,
                    confirmationId: pending.id,
                  ),
                ),
                child: Text(l.aiApprove),
              ),
              const SizedBox(width: 4),
              ShadButton.ghost(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: theme.textTheme.small.copyWith(fontSize: 12),
                enabled: canDecide,
                onPressed: () => setState(
                  () => widget.coordinator.decide(
                    false,
                    confirmationId: pending.id,
                  ),
                ),
                child: Text(l.cancel),
              ),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AiDisclosure(
          fill: true,
          active:
              phase == AiToolPhase.preparing || phase == AiToolPhase.running,
          leading: _statusIcon(phase, theme),
          label: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: AiToolLabels.toolStep(context, phase, name)),
                if (phase == AiToolPhase.running)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6),
                      child: AiElapsed(
                        since: p.turn.activitySince,
                        style: muted.copyWith(fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          trailing: decide,
          body: body,
        ),
        if (results.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 21, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: results,
            ),
          ),
        // What the confirmation will act on is always visible.
        if (pending != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 21, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.aiConfirmAction, style: theme.textTheme.small),
                if (description != null) Text(description, style: muted),
                if (pending.targetLabel != null)
                  Text(_safe(pending.targetLabel), style: muted),
                if (pending.arguments['favorite'] is bool)
                  Text(
                    pending.arguments['favorite'] == true
                        ? l.favorite
                        : l.unfavorite,
                    style: muted,
                  ),
              ],
            ),
          ),
        // Live progress of a running task stays under the header.
        if (phase == AiToolPhase.running && p.progress != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 21, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(AiToolLabels.progress(context, p.progress!), style: muted),
                const SizedBox(height: 4),
                ShadProgress(
                  value: (p.progress!['progress'] as num?)?.toDouble(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
