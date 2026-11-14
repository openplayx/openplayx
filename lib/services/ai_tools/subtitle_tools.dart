import '../../core/plugins/plugin_gate.dart';
import '../subtitles/asr_backend_config.dart';
import '../subtitles/subtitle_format.dart';
import '../subtitles/subtitle_generation_service.dart';
import 'media_processing_tools.dart';
import 'task_wait.dart';
import 'tool_registry.dart';

/// `subtitle_generate` / `transcript_generate` (AI tool design) over the
/// host subtitle workflow. The model picks a resource and an explicit range;
/// the host picks the recognition backend (on-device or the user's service),
/// which the model never sees, nor file paths, service URLs or tokens. Tasks return at once; results are unbound
/// artifacts until `subtitle_save`.
class SubtitleTools {
  SubtitleTools({
    required this.registry,
    required this.service,
    required this.media,
    this.canExecute,
  }) {
    _register();
  }

  final ToolRegistry registry;
  final SubtitleGenerationService service;

  /// Shares resource and `track_ref` resolution with the media tools.
  final MediaProcessingTools media;
  final bool Function()? canExecute;

  static const _ms = ToolField('integer', minimum: 0, maximum: 86400000);
  static const _id = ToolField('string', required: true, maxLength: 64);

  bool get _active => ToolExecution.active && (canExecute?.call() ?? true);

  Future<Map<String, dynamic>> _wait(String taskId, Object? seconds) =>
      TaskWait.until(
        taskId: taskId,
        read: () => service.task(taskId),
        changes: service.changes,
        seconds: seconds as int? ?? TaskWait.defaultSeconds,
      );

  static bool _aiBackend(AsrBackendConfig c) => PluginGate.ai(
    c.pluginId,
    instanceId: c.id,
    capability: 'speech.transcribe',
  );

  /// The backend the host uses: the first available one, on-device first.
  /// Returns (config, null) or (null, reason).
  Future<(AsrBackendConfig?, String?)> _pickBackend() async {
    final candidates = service.backends.list().where(_aiBackend).toList()
      ..sort(
        (a, b) =>
            (a.kind == 'embedded' ? 0 : 1) - (b.kind == 'embedded' ? 0 : 1),
      );
    if (candidates.isEmpty) return (null, 'backend_not_configured');
    String? reason;
    for (final c in candidates) {
      final s = await service.backends.backend(c.id).status();
      if (s.available) return (c, null);
      reason ??= s.reason;
    }
    return (null, reason ?? 'speech_recognition_unavailable');
  }

  Future<Map<String, dynamic>> _guard(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    try {
      return await action();
    } on SubtitleException catch (e) {
      throw ToolFailure(e.code);
    }
  }

  void _add(
    String name,
    String description,
    Map<String, ToolField> fields,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>) execute, {
    bool readOnly = true,
    Duration? timeout,
  }) => registry.register(
    RegisteredTool(
      name,
      description,
      fields,
      (a) => _guard(() => execute(a)),
      readOnly: readOnly,
      timeout: timeout,
      available: () => service.media.available,
    ),
  );

  Future<Map<String, dynamic>> _generate(
    Map<String, dynamic> a, {
    required bool subtitles,
  }) async {
    if (!_active) throw const ToolFailure('cancelled');
    final (ref, name) = media.resource(a['resource_ref'] as String);
    final whole = a['whole_media'] == true;
    final start = a['start_ms'] as int? ?? 0;
    final end = a['end_ms'] as int?;
    if (!whole && end == null) throw const ToolFailure('end_ms_required');
    final (config, unavailable) = await _pickBackend();
    if (config == null) {
      throw ToolFailure(unavailable ?? 'speech_recognition_unavailable');
    }
    final backendId = config.id;
    String? trackRef;
    final index = media.trackIndex(a['audio_track_ref'], ref);
    if (index != null) {
      final info = await service.inspect(ref);
      trackRef = info.tracks.where((t) => t.index == index).firstOrNull?.ref;
      if (trackRef == null) throw const ToolFailure('staleReference');
    }
    final run = service.start(
      SubtitleRequest(
        resource: ref,
        resourceName: name,
        caller: SubtitleCaller.ai,
        trackRef: trackRef,
        startMs: start,
        endMs: end,
        wholeMedia: whole,
        backendId: backendId,
        language: a['language'] as String?,
        subtitleOutput: subtitles,
      ),
    );
    final task = await _wait(run.taskId, a['wait_seconds']);
    return {
      ...task,
      if (task['status'] == 'succeeded')
        'next': 'Not attached to the video until subtitle_save.',
    };
  }

  void _register() {
    _add(
      'speech_recognition_status',
      'Whether speech recognition can run now, and its limits.',
      {},
      (_) async {
        final (config, reason) = await _pickBackend();
        return {
          'available': config != null,
          'reason': ?reason,
          'default_language': ?config?.language,
          'limits': {
            'translation': false,
            'timestamp_level': 'segment',
            'language_format': 'ISO 639-1 (e.g. en, zh) or auto; not media track codes such as eng or zho',
          },
        };
      },
    );
    final fields = {
      'resource_ref': const ToolField('string', required: true),
      'language': const ToolField('string', maxLength: 8),
      'audio_track_ref': const ToolField('string', maxLength: 64),
      'start_ms': _ms,
      'end_ms': _ms,
      'whole_media': const ToolField('boolean'),
      'wait_seconds': TaskWait.field,
    };
    _add(
      'subtitle_generate',
      'Generate subtitles (original language, no translation) for an explicit range of a resource (start_ms/end_ms, or whole_media=true). Omit language for automatic detection, or use ISO 639-1 (en, zh), never track codes such as eng. Returns task_id; on success the task lists subtitle_artifact_ref and transcript_artifact_ref.',
      fields,
      (a) => _generate(a, subtitles: true),
      readOnly: false,
      timeout: TaskWait.toolTimeout,
    );
    _add(
      'transcript_generate',
      'Generate a timestamped transcript for an explicit range of a resource. Omit language for automatic detection, or use ISO 639-1 (en, zh), never track codes such as eng. Returns task_id; on success the task lists transcript_artifact_ref.',
      fields,
      (a) => _generate(a, subtitles: false),
      readOnly: false,
      timeout: TaskWait.toolTimeout,
    );
    _add(
      'subtitle_task_get',
      'Get a subtitle/transcript task: status, stage, error, artifact refs. wait_seconds (max 120) waits for it to finish; the task keeps running if the wait ends first.',
      {'task_id': _id, 'wait_seconds': TaskWait.field},
      (a) async => _wait(a['task_id'] as String, a['wait_seconds'] ?? 0),
      timeout: TaskWait.toolTimeout,
    );
    _add(
      'subtitle_task_cancel',
      'Request cancellation of a subtitle/transcript task.',
      {'task_id': _id},
      (a) async => service.cancel(a['task_id'] as String),
      readOnly: false,
    );
    _add(
      'subtitle_save',
      'Save a finished task\'s subtitle and bind it to its resource version as a new subtitle (never overwrites). Only when the user asked to keep it.',
      {
        'task_id': _id,
        'format': const ToolField('string', values: ['srt', 'vtt']),
      },
      (a) async {
        if (!_active) throw const ToolFailure('cancelled');
        return service.save(
          a['task_id'] as String,
          format: a['format'] == 'vtt'
              ? SubtitleFormat.vtt
              : SubtitleFormat.srt,
        );
      },
      readOnly: false,
    );
  }
}
