import 'package:flutter/widgets.dart';

import 'ai_chat_part.dart';

/// Human labels for tool cards and the activity row. Built on the host from
/// tool names and validated arguments, never from model text.
abstract final class AiToolLabels {
  static bool _zh(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'zh';

  static const _zhNames = {
    'context_get': '读取当前页面',
    'source_list': '列出媒体来源',
    'source_browse': '浏览文件夹',
    'library_query': '查询媒体库',
    'media_get': '查看媒体详情',
    'search_media': '搜索媒体',
    'progress_query': '查看观看进度',
    'media_set_favorite': '设置收藏',
    'playback_get': '读取播放状态',
    'playback_open': '打开播放',
    'playback_pause': '暂停',
    'playback_resume': '继续播放',
    'playback_stop': '停止播放',
    'playback_seek': '跳转',
    'playback_set_speed': '设置倍速',
    'playback_set_volume': '设置音量',
    'playback_set_subtitle': '设置字幕',
    'media_processing_capabilities': '查询媒体处理能力',
    'media_probe': '分析媒体',
    'media_transcode': '转码 / 截取片段',
    'media_extract_audio': '提取音频',
    'media_snapshot': '截图',
    'media_save_to_source': '存回媒体来源',
    'task_get': '查询处理任务',
    'task_list': '列出处理任务',
    'task_cancel': '取消处理任务',
    'task_retry': '重试处理任务',
    'speech_recognition_status': '查询语音识别状态',
    'subtitle_generate': '识别字幕',
    'transcript_generate': '生成转录',
    'subtitle_task_get': '查询字幕任务',
    'subtitle_task_cancel': '取消字幕任务',
    'subtitle_save': '保存字幕',
    'plugin_status': '查看插件状态',
  };

  /// English falls back to a readable form of the tool name.
  static String tool(BuildContext context, String? name) {
    if (name == null) return '';
    if (_zh(context)) return _zhNames[name] ?? name;
    final words = name.split('_');
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
    final zh = _zh(context);
    String cut(Object v) {
      final t = '$v';
      return t.length > 40 ? '${t.substring(0, 40)}…' : t;
    }

    ({String label, String value}) row(String zhLabel, String en, String v) =>
        (label: zh ? zhLabel : en, value: v);
    return [
      if (a['query'] case final String q) row('关键词', 'Query', '“${cut(q)}”'),
      if (a['start_ms'] is num || a['end_ms'] is num)
        row(
          '范围',
          'Range',
          '${_clock(a['start_ms'] as num? ?? 0)}–${a['end_ms'] is num ? _clock(a['end_ms'] as num) : (zh ? '结尾' : 'end')}',
        ),
      if (a['whole_media'] == true)
        row('范围', 'Range', zh ? '整部' : 'whole media'),
      if (a['time_ms'] case final num t) row('时间', 'Time', _clock(t)),
      if (a['position_ms'] case final num t) row('位置', 'Position', _clock(t)),
      if (a['preset_id'] case final String p) row('预设', 'Preset', p),
      if (a['language'] case final String l) row('语言', 'Language', l),
      if (a['format'] case final String f) row('格式', 'Format', f),
      if (a['speed'] case final num s) row('倍速', 'Speed', '${s}x'),
      if (a['volume'] case final num v) row('音量', 'Volume', '$v%'),
      if (a['off'] == true) row('开关', 'Switch', zh ? '关闭' : 'off'),
      if (a['favorite'] case final bool f)
        row(
          '收藏',
          'Favorite',
          f ? (zh ? '收藏' : 'favorite') : (zh ? '取消收藏' : 'unfavorite'),
        ),
      if (a['wait_seconds'] case final num w when w > 0)
        row('等待', 'Wait', zh ? '最多等 ${w}s' : 'wait ≤${w}s'),
    ];
  }

  /// One-line header of a tool step, by phase.
  static String toolStep(BuildContext context, AiToolPhase phase, String name) {
    final zh = _zh(context);
    return switch (phase) {
      AiToolPhase.preparing => zh ? '准备调用 $name…' : 'Preparing $name...',
      AiToolPhase.running => zh ? '正在执行 $name…' : 'Executing $name...',
      AiToolPhase.waiting => zh ? '允许执行 $name？' : 'Allow $name?',
      AiToolPhase.success => name,
      AiToolPhase.failed => zh ? '$name 失败' : '$name failed',
      AiToolPhase.cancelled => zh ? '已取消 $name' : 'Cancelled $name',
    };
  }

  static String toolInput(BuildContext context) =>
      _zh(context) ? '输入' : 'INPUT';
  static String showAll(BuildContext context, int characters) => _zh(context)
      ? '显示全部（$characters 个字符）'
      : 'Show all ($characters characters)';
  static String toolOutput(BuildContext context) =>
      _zh(context) ? '输出' : 'OUTPUT';

  static String activity(BuildContext context, String activity, String? tool) {
    final zh = _zh(context);
    final name = AiToolLabels.tool(context, tool);
    return switch (activity) {
      'thinking' when tool != null => zh ? '准备调用：$name' : 'Preparing: $name',
      'thinking' => zh ? '正在思考' : 'Thinking',
      'answering' => zh ? '正在回复' : 'Replying',
      'tool' => zh ? '正在执行：$name' : 'Running: $name',
      'confirm' => zh ? '等待你确认：$name' : 'Waiting for you: $name',
      _ => zh ? '运行中' : 'Running',
    };
  }

  static String step(BuildContext context, int step) =>
      _zh(context) ? '第 $step 步' : 'step $step';

  /// "Thinking…" while streaming, then how long it took when that is known
  /// (reasoning reloaded from history has no timing).
  static String reasoning(
    BuildContext context, {
    required bool streaming,
    Duration? duration,
  }) {
    final zh = _zh(context);
    if (streaming) return zh ? '思考中…' : 'Thinking...';
    if (duration == null) return zh ? '已思考' : 'Thought';
    final s = duration.inSeconds;
    if (s < 1) return zh ? '思考了不到 1 秒' : 'Thought for less than a second';
    if (s < 60) return zh ? '思考了 $s 秒' : 'Thought for $s seconds';
    final m = (s / 60).round();
    return zh
        ? '思考了 $m 分钟'
        : 'Thought for ${m == 1 ? 'a minute' : '$m minutes'}';
  }

  /// Live task progress from `ToolExecution.report`.
  static String progress(BuildContext context, Map<String, dynamic> p) {
    final zh = _zh(context);
    const zhStatus = {
      'queued': '排队中',
      'preparing': '准备中',
      'running': '处理中',
      'cancelling': '取消中',
      'succeeded': '已完成',
      'failed': '失败',
      'cancelled': '已取消',
      'interrupted': '已中断',
    };
    const zhStage = {
      'extracting': '提取音频',
      'uploading': '上传',
      'queued': '排队',
      'transcribing': '识别',
      'formatting': '整理字幕',
    };
    final status = p['status'] as String?;
    final stage = p['stage'] as String?;
    return [
      if (status != null) zh ? zhStatus[status] ?? status : status,
      if (stage != null && stage != status)
        zh ? zhStage[stage] ?? stage : stage,
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

  static String stillRunning(BuildContext context) => _zh(context)
      ? '等待超时，任务仍在后台运行（未失败、未停止）'
      : 'Wait timed out; the task is still running in the background';
}
