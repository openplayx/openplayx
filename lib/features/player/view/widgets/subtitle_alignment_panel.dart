import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../ui/icons/app_icons.dart';
import '../../controller/subtitle_alignment_controller.dart';
import '../../controller/subtitle_controller.dart';
import '../../model/playback_tools_state.dart';
import '../../model/subtitle_state.dart';
import 'player_widgets.dart';

/// The desktop dock and mobile sheet share feature content, not navigation.
/// The footer stays visible while the body scrolls, including in landscape.
class SubtitleAlignmentPanel extends StatefulWidget {
  const SubtitleAlignmentPanel({
    super.key,
    required this.controller,
    required this.subtitles,
    required this.pickReference,
    required this.addSubtitle,
    required this.seek,
    required this.close,
    required this.supportsDelay,
  });
  final SubtitleAlignmentController controller;
  final SubtitleController subtitles;
  final Future<Uri?> Function() pickReference;
  final VoidCallback addSubtitle, close;
  final Future<void> Function(Duration) seek;
  final bool supportsDelay;

  @override
  State<SubtitleAlignmentPanel> createState() => _SubtitleAlignmentPanelState();
}

class _SubtitleAlignmentPanelState extends State<SubtitleAlignmentPanel> {
  int _tab = 0;
  bool _picking = false, _pickerFailed = false;
  AppLocalizations get l => AppLocalizations.of(context);
  SubtitleAlignmentController get c => widget.controller;
  bool get locked => c.running || c.changing || c.previewing || c.applied;

  Future<void> _pick() async {
    if (_picking || locked) return;
    final token = c.generation;
    setState(() {
      _picking = true;
      _pickerFailed = false;
    });
    try {
      final file = await widget.pickReference();
      if (mounted && token == c.generation && file != null) {
        c.setReference(file);
      }
    } catch (_) {
      if (mounted) setState(() => _pickerFailed = true);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: PlayerStyle.muted,
        fontSize: 12,
        height: 1.6,
      ),
    ),
  );
  Widget _box(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: PlayerStyle.hover,
      border: Border.all(color: PlayerStyle.glassStroke),
      borderRadius: BorderRadius.circular(8),
    ),
    child: child,
  );
  Widget _metric(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: PlayerStyle.muted, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: PlayerStyle.accent(context),
            fontFeatures: PlayerStyle.tabular,
          ),
        ),
      ],
    ),
  );

  String _error(String code) => switch (code) {
    'choose_files' => l.alignChooseFiles,
    'insufficient_evidence' => l.alignInsufficient,
    'apply_failed' => l.alignApplyFailed,
    'source_changed' => l.alignSourceChanged,
    _ => l.alignReadFailed,
  };

  Widget _automatic() {
    final result = c.result;
    final selected = widget.subtitles.state.selected;
    final file = SubtitleAlignmentController.fileOf(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.alignSource,
          style: const TextStyle(color: PlayerStyle.muted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        if (widget.subtitles.state.options.isNotEmpty)
          DropdownButton<String>(
            key: const Key('alignment-source'),
            value: selected?.key,
            isExpanded: true,
            hint: Text(l.alignNoSource, maxLines: 2),
            dropdownColor: PlayerStyle.glass,
            items: [
              for (final o in widget.subtitles.state.options)
                DropdownMenuItem(
                  value: o.key,
                  child: Text(
                    o.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: locked
                ? null
                : (key) {
                    if (key != null) unawaited(widget.subtitles.choose(key));
                  },
          ),
        if (file == null) _note(l.alignNoSource),
        ShadButton.outline(
          key: const Key('alignment-add'),
          onPressed: locked ? null : widget.addSubtitle,
          child: Text(l.plLoadSubtitle),
        ),
        if (c.running) ...[
          const SizedBox(height: 22),
          const LinearProgressIndicator(),
          _note(
            c.phase == AlignmentPhase.reading
                ? l.alignReading
                : l.alignMatching,
          ),
          _note(l.alignRetained),
          TextButton(onPressed: widget.close, child: Text(l.alignCollapse)),
        ] else if (result != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                result.safe ? AppIcons.check : AppIcons.warning,
                color: result.safe
                    ? PlayerStyle.accent(context)
                    : PlayerStyle.remote,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.applied
                      ? l.alignApplied
                      : c.previewing
                      ? l.alignPreviewing
                      : result.safe
                      ? l.alignResult
                      : l.alignReview,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _box(
            Column(
              children: [
                _metric(
                  l.alignCoverage,
                  '${(result.matchCoverage * 100).toStringAsFixed(1)}%',
                ),
                _metric(l.alignError, '${result.p95Ms.round()} ms'),
                _metric(
                  l.alignOffset,
                  formatDelay(
                    Duration(milliseconds: result.mapping.offsetMs.round()),
                  ),
                ),
                _metric(
                  l.alignScale,
                  '${result.mapping.scale.toStringAsFixed(6)}×',
                ),
                _metric(l.alignInvalid, '${result.invalidCues}'),
              ],
            ),
          ),
          if (!result.safe) _note(l.alignReviewHelp),
          if (!c.sourceUnchanged) _note(l.alignSourceChanged),
          if (result.safe) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ShadButton.outline(
                  key: const Key('alignment-preview'),
                  onPressed: c.canApply && !c.previewing && !c.applied
                      ? () => unawaited(c.useCandidate())
                      : null,
                  child: Text(l.alignPreview),
                ),
                ShadButton.outline(
                  key: const Key('alignment-original'),
                  onPressed: c.canUndo ? () => unawaited(c.restore()) : null,
                  child: Text(l.alignOriginal),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l.alignPreviewAnchor,
              style: const TextStyle(color: PlayerStyle.muted, fontSize: 12),
            ),
            for (final a in result.validation.take(3))
              TextButton(
                key: ValueKey('alignment-anchor-${a.sourceMs}'),
                onPressed: () async {
                  await widget.seek(
                    Duration(
                      milliseconds: c.previewing || c.applied
                          ? a.targetMs
                          : a.sourceMs,
                    ),
                  );
                  if (mounted) widget.close();
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${_time(a.sourceMs)} → ${_time(a.targetMs)}'),
                ),
              ),
          ],
          _note(l.alignEvidence),
          if (!locked)
            TextButton(
              onPressed: () => unawaited(c.start()),
              child: Text(l.retry),
            ),
        ] else ...[
          const SizedBox(height: 16),
          _note(l.alignIntro),
          const SizedBox(height: 12),
        ],
        if (!c.running && !c.previewing && !c.applied) ...[
          ShadButton.outline(
            key: const Key('alignment-reference'),
            onPressed: _picking || c.changing ? null : () => unawaited(_pick()),
            child: Text(l.alignReference),
          ),
          if (c.reference case final ref?) _note(ref.pathSegments.last),
          for (final o in widget.subtitles.state.recognized)
            if (o.source case RecognizedSubtitleSource(:final saved)
                when !saved.partial && saved.format.toLowerCase() == 'srt')
              TextButton(
                onPressed: c.changing
                    ? null
                    : () => c.setReference(Uri.file(saved.path)),
                child: Text(
                  '${l.alignReferenceSaved} · ${saved.language ?? o.name}',
                ),
              ),
        ],
        if (_pickerFailed) _note(l.alignReadFailed),
        if (c.error case final code?) _note(_error(code)),
      ],
    );
  }

  String _time(int ms) =>
      '${(ms ~/ 60000).toString().padLeft(2, '0')}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}.${(ms % 1000).toString().padLeft(3, '0')}';

  Widget _manual() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _note(l.alignDelayHelp),
      const SizedBox(height: 24),
      Center(
        child: Text(
          formatDelay(widget.subtitles.state.delay),
          key: const Key('alignment-delay-value'),
          style: TextStyle(
            fontSize: 32,
            color: PlayerStyle.accent(context),
            fontFeatures: PlayerStyle.tabular,
          ),
        ),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          for (final sign in [-1, 1])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: ShadButton.outline(
                  key: Key('alignment-delay-$sign'),
                  onPressed: widget.supportsDelay && !locked
                      ? () => unawaited(
                          c.setManualDelay(
                            widget.subtitles.state.delay +
                                Duration(milliseconds: sign * 250),
                          ),
                        )
                      : null,
                  child: Text(sign < 0 ? '− 0.25 s' : '+ 0.25 s'),
                ),
              ),
            ),
        ],
      ),
      ShadButton.outline(
        onPressed: widget.supportsDelay && !locked
            ? () => unawaited(c.setManualDelay(Duration.zero))
            : null,
        child: Text(l.alignReset),
      ),
      if (c.canRestoreManual)
        TextButton(
          onPressed: () => unawaited(c.restoreManual()),
          child: Text(l.alignOriginal),
        ),
    ],
  );

  Widget _history() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _note(l.alignHistorySession),
      const SizedBox(height: 16),
      if (c.history.isEmpty && c.manualHistory.isEmpty)
        _note(l.alignHistoryEmpty),
      for (final t in c.history.reversed)
        _box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.alignApplied),
              _note(t.toLocal().toString().split('.').first),
            ],
          ),
        ),
      for (final entry in c.manualHistory.reversed)
        _box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l.alignManual} · ${formatDelay(entry.$2)}'),
              _note(entry.$1.toLocal().toString().split('.').first),
            ],
          ),
        ),
      if (c.canRestoreManual)
        ShadButton.outline(
          onPressed: () => unawaited(c.restoreManual()),
          child: Text(l.alignOriginal),
        ),
      if (c.canUndo)
        ShadButton.outline(
          onPressed: () => unawaited(c.restore()),
          child: Text(l.alignOriginal),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([c, widget.subtitles]),
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Icon(
                AppIcons.assistant,
                color: PlayerStyle.accent(context),
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  l.alignTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                key: const Key('alignment-close'),
                tooltip: l.alignCollapse,
                onPressed: widget.close,
                icon: const Icon(AppIcons.close, size: 18),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final entry in [
                l.alignAuto,
                l.alignManual,
                l.alignHistory,
              ].indexed)
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => _tab = entry.$1),
                    child: Text(
                      entry.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: _tab == entry.$1
                            ? PlayerStyle.accent(context)
                            : PlayerStyle.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('alignment-body'),
            padding: const EdgeInsets.all(16),
            child: switch (_tab) {
              1 => _manual(),
              2 => _history(),
              _ => _automatic(),
            },
          ),
        ),
        if (_tab == 0)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PlayerStyle.glassStroke)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShadButton(
                  key: const Key('alignment-primary'),
                  onPressed: c.changing
                      ? null
                      : c.running
                      ? c.cancel
                      : c.applied
                      ? c.canUndo
                            ? () => unawaited(c.restore())
                            : null
                      : c.result?.safe == true
                      ? c.canApply
                            ? () => unawaited(c.useCandidate(accept: true))
                            : null
                      : SubtitleAlignmentController.fileOf(
                                  widget.subtitles.state.selected,
                                ) !=
                                null &&
                            c.reference != null
                      ? () => unawaited(c.start())
                      : null,
                  child: Text(
                    c.running
                        ? l.cancel
                        : c.applied
                        ? l.alignOriginal
                        : c.result?.safe == true
                        ? l.alignApply
                        : l.alignStart,
                  ),
                ),
                _note(l.alignRetained),
              ],
            ),
          ),
      ],
    ),
  );
}
