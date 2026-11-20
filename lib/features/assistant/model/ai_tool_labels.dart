import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'ai_chat_part.dart';

/// Human labels for tool cards and the activity row. Built on the host from
/// tool names and validated arguments, never from model text.
abstract final class AiToolLabels {
  /// Unknown tools (external MCP tools) fall back to a readable form of the
  /// tool name.
  static String tool(BuildContext context, String? name) {
    if (name == null) return '';
    final l = AppLocalizations.of(context);
    return switch (name) {
      'context_get' => l.aiToolContextGet,
      'source_list' => l.aiToolSourceList,
      'source_browse' => l.aiToolSourceBrowse,
      'library_query' => l.aiToolLibraryQuery,
      'media_get' => l.aiToolMediaGet,
      'search_media' => l.aiToolSearchMedia,
      'progress_query' => l.aiToolProgressQuery,
      'playback_get' => l.aiToolPlaybackGet,
      'playback_open' => l.aiToolPlaybackOpen,
      'playback_pause' => l.aiToolPlaybackPause,
      'playback_resume' => l.aiToolPlaybackResume,
      'playback_stop' => l.aiToolPlaybackStop,
      'playback_seek' => l.aiToolPlaybackSeek,
      'playback_set_speed' => l.aiToolPlaybackSetSpeed,
      'playback_set_volume' => l.aiToolPlaybackSetVolume,
      'playback_set_subtitle' => l.aiToolPlaybackSetSubtitle,
      'media_processing_capabilities' => l.aiToolMediaProcessingCapabilities,
      'media_probe' => l.aiToolMediaProbe,
      'media_transcode' => l.aiToolMediaTranscode,
      'media_extract_audio' => l.aiToolMediaExtractAudio,
      'media_snapshot' => l.aiToolMediaSnapshot,
      'external_file_save_to_source' => l.aiToolMediaSaveToSource,
      'media_save_to_source' => l.aiToolMediaSaveToSource,
      'task_get' => l.aiToolTaskGet,
      'task_list' => l.aiToolTaskList,
      'task_cancel' => l.aiToolTaskCancel,
      'task_retry' => l.aiToolTaskRetry,
      'speech_recognition_status' => l.aiToolSpeechRecognitionStatus,
      'subtitle_generate' => l.aiToolSubtitleGenerate,
      'transcript_generate' => l.aiToolTranscriptGenerate,
      'subtitle_task_get' => l.aiToolSubtitleTaskGet,
      'subtitle_task_cancel' => l.aiToolSubtitleTaskCancel,
      'subtitle_save' => l.aiToolSubtitleSave,
      'plugin_status' => l.aiToolPluginStatus,
      'mcp_tavily_web_search' => l.aiToolMcpTavilyWebSearch,
      'web_fetch' => l.aiToolWebFetch,
      _ => _readable(name),
    };
  }

  static String _readable(String name) {
    final words = name.split('_');
    // ExternalTools.alias keeps only the last six service-id characters,
    // so torrent becomes orrent. Restore the display name without changing
    // the alias used by stored calls and MCP routing.
    if (words.length > 2 && words[0] == 'mcp' && words[1] == 'orrent') {
      words[1] = 'Torrent';
    }
    return '${words.first[0].toUpperCase()}${words.first.substring(1)} ${words.skip(1).join(' ')}'
        .trim();
  }

  static String _clock(num ms) {
    final s = ms ~/ 1000;
    String two(int v) => v.toString().padLeft(2, '0');
    return s >= 3600
        ? '${s ~/ 3600}:${two(s ~/ 60 % 60)}:${two(s % 60)}'
        : '${two(s ~/ 60)}:${two(s % 60)}';
  }

  /// Short, safe summary of call arguments: ranges, presets, queries.
  /// Opaque refs and IDs are omitted.
  static String arguments(BuildContext context, Map<String, dynamic> a) =>
      argumentRows(context, a).map((r) => r.value).join(' · ');

  /// The same whitelisted arguments as label / value pairs.
  static List<({String label, String value})> argumentRows(
    BuildContext context,
    Map<String, dynamic> a,
  ) {
    final l = AppLocalizations.of(context);
    String cut(Object v) {
      final t = '$v';
      return t.length > 40 ? '${t.substring(0, 40)}…' : t;
    }

    ({String label, String value}) row(String label, String v) =>
        (label: label, value: v);
    return [
      if (a['query'] case final String q) row(l.aiArgQuery, '“${cut(q)}”'),
      if (a['url'] case final String u) row(l.aiArgUrl, cut(u)),
      if (a['start_ms'] is num || a['end_ms'] is num)
        row(
          l.aiArgRange,
          '${_clock(a['start_ms'] as num? ?? 0)}–${a['end_ms'] is num ? _clock(a['end_ms'] as num) : l.aiArgEnd}',
        ),
      if (a['whole_media'] == true) row(l.aiArgRange, l.aiArgWholeMedia),
      if (a['time_ms'] case final num t) row(l.aiArgTime, _clock(t)),
      if (a['position_ms'] case final num t) row(l.aiArgPosition, _clock(t)),
      if (a['preset_id'] case final String p) row(l.aiArgPreset, p),
      if (a['language'] case final String lang) row(l.aiArgLanguage, lang),
      if (a['format'] case final String f) row(l.aiArgFormat, f),
      if (a['speed'] case final num s) row(l.aiArgSpeed, '${s}x'),
      if (a['volume'] case final num v) row(l.aiArgVolume, '$v%'),
      if (a['off'] == true) row(l.aiArgSwitch, l.aiArgOff),
      if (a['wait_seconds'] case final num w when w > 0)
        row(l.aiArgWait, l.aiArgWaitValue('$w')),
    ];
  }

  /// One-line header of a tool step, by phase.
  static String toolStep(BuildContext context, AiToolPhase phase, String name) {
    final l = AppLocalizations.of(context);
    return switch (phase) {
      AiToolPhase.preparing => l.aiStepPreparing(name),
      AiToolPhase.running => l.aiStepRunning(name),
      AiToolPhase.waiting => l.aiStepWaiting(name),
      AiToolPhase.success => name,
      AiToolPhase.failed => l.aiStepFailed(name),
      AiToolPhase.cancelled => l.aiStepCancelled(name),
    };
  }

  static String toolInput(BuildContext context) =>
      AppLocalizations.of(context).aiToolInput;
  static String showAll(BuildContext context, int characters) =>
      AppLocalizations.of(context).aiShowAll(characters);
  static String toolOutput(BuildContext context) =>
      AppLocalizations.of(context).aiToolOutput;

  static String activity(BuildContext context, String activity, String? tool) {
    final l = AppLocalizations.of(context);
    final name = AiToolLabels.tool(context, tool);
    return switch (activity) {
      'thinking' when tool != null => l.aiActivityPreparingTool(name),
      'thinking' => l.aiActivityThinking,
      'answering' => l.aiActivityAnswering,
      'tool' => l.aiActivityTool(name),
      'confirm' => l.aiActivityConfirm(name),
      _ => l.aiActivityRunningDefault,
    };
  }

  static String step(BuildContext context, int step) =>
      AppLocalizations.of(context).aiStepNumber(step);

  /// "Thinking…" while streaming, then how long it took when that is known
  /// (reasoning reloaded from history has no timing).
  static String reasoning(
    BuildContext context, {
    required bool streaming,
    Duration? duration,
  }) {
    final l = AppLocalizations.of(context);
    if (streaming) return l.aiReasoningStreaming;
    if (duration == null) return l.aiReasoningDone;
    final s = duration.inSeconds;
    if (s < 1) return l.aiReasoningUnderSecond;
    if (s < 60) return l.aiReasoningSeconds(s);
    return l.aiReasoningMinutes((s / 60).round());
  }

  /// Live task progress from `ToolExecution.report`.
  static String progress(BuildContext context, Map<String, dynamic> p) {
    final l = AppLocalizations.of(context);
    String statusLabel(String status) => switch (status) {
      'queued' => l.aiStatusQueued,
      'preparing' => l.aiStatusPreparing,
      'running' => l.aiStatusRunning,
      'cancelling' => l.aiStatusCancelling,
      'succeeded' => l.aiStatusSucceeded,
      'failed' => l.aiStatusFailed,
      'cancelled' => l.aiStatusCancelled,
      'interrupted' => l.aiStatusInterrupted,
      _ => status,
    };
    String stageLabel(String stage) => switch (stage) {
      'extracting' => l.aiStageExtracting,
      'uploading' => l.aiStageUploading,
      'queued' => l.aiStageQueued,
      'transcribing' => l.aiStageTranscribing,
      'formatting' => l.aiStageFormatting,
      _ => stage,
    };
    final status = p['status'] as String?;
    final stage = p['stage'] as String?;
    return [
      if (status != null) statusLabel(status),
      if (stage != null && stage != status) stageLabel(stage),
      if (p['progress'] case final num v) '${(v * 100).round()}%',
      if (p['processed_ms'] case final num done when p['total_ms'] is num)
        '${_clock(done)} / ${_clock(p['total_ms'] as num)}',
    ].join(' · ');
  }

  static String elapsed(BuildContext context, Duration d) {
    final s = d.inSeconds;
    final text = s < 60
        ? '${s}s'
        : '${s ~/ 60}m${(s % 60).toString().padLeft(2, '0')}s';
    return text;
  }

  static String stillRunning(BuildContext context) =>
      AppLocalizations.of(context).aiStillRunning;
}
