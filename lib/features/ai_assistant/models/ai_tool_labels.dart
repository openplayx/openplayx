import 'package:flutter/widgets.dart';

/// Human labels for tool cards and the activity row. Built on the host from
/// tool names and validated arguments, never from model text.
abstract final class AiToolLabels {
  static bool _zh(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'zh';

  static const _zhNames = {
    'context_get': '读取当前页面',
    'source_list': '列出媒体来源',
    'source_browse': '浏览文件夹',
    'library_list': '列出媒体库',
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
    'speech_recognition_backends': '查询语音识别服务',
    'subtitle_generate': '识别字幕',
    'transcript_generate': '生成转录',
    'subtitle_task_get': '查询字幕任务',
    'subtitle_task_cancel': '取消字幕任务',
    'subtitle_save': '保存字幕',
    'plugin_status': '查看插件状态',
    'torrent_service_info': '查看下载服务',
    'torrent_plan': '准备下载',
    'torrent_add': '创建下载',
    'torrent_list': '列出下载任务',
    'torrent_get': '查看下载任务',
    'torrent_files': '查看下载文件',
    'torrent_select_files': '选择下载文件',
    'torrent_set_limits': '设置限速',
    'torrent_remove_preview': '预览删除',
    'torrent_remove': '删除下载任务',
    'torrent_search_capabilities': '查看搜索服务',
    'torrent_search': '搜索种子',
    'torrent_search_detail': '查看种子详情',
    'torrent_search_browse': '浏览种子分类',
    'torrent_search_top': '查看热门种子',
    'torrent_search_recent': '查看最新种子',
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
  static String arguments(BuildContext context, Map<String, dynamic> a) {
    final zh = _zh(context);
    String cut(Object v) {
      final t = '$v';
      return t.length > 40 ? '${t.substring(0, 40)}…' : t;
    }

    return [
      if (a['query'] case final String q) '“${cut(q)}”',
      if (a['start_ms'] is num || a['end_ms'] is num)
        '${_clock(a['start_ms'] as num? ?? 0)}–${a['end_ms'] is num ? _clock(a['end_ms'] as num) : (zh ? '结尾' : 'end')}',
      if (a['whole_media'] == true) zh ? '整部' : 'whole media',
      if (a['time_ms'] case final num t) _clock(t),
      if (a['position_ms'] case final num t) _clock(t),
      if (a['preset_id'] case final String p) p,
      if (a['language'] case final String l) l,
      if (a['format'] case final String f) f,
      if (a['speed'] case final num s) '${s}x',
      if (a['volume'] case final num v) '$v%',
      if (a['off'] == true) zh ? '关闭' : 'off',
      if (a['favorite'] case final bool f)
        f ? (zh ? '收藏' : 'favorite') : (zh ? '取消收藏' : 'unfavorite'),
      if (a['wait_seconds'] case final num w when w > 0)
        zh ? '最多等 ${w}s' : 'wait ≤${w}s',
    ].join(' · ');
  }

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

  static String reasoning(BuildContext context, {required bool streaming}) =>
      _zh(context)
      ? (streaming ? '思考中' : '思考过程')
      : (streaming ? 'Thinking' : 'Reasoning');

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
