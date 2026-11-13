import '../../core/plugins/plugin_gate.dart';
import '../subtitles/asr_backend_config.dart';
import '../subtitles/subtitle_format.dart';
import '../subtitles/subtitle_generation_service.dart';
import 'media_processing_tools.dart';
import 'tool_registry.dart';

/// `subtitle_generate` / `transcript_generate` (AI tool design) over the
/// host subtitle workflow. The model picks a resource, a configured backend
/// instance and an explicit range; it never sees `model.transcribe`, file
/// paths, service URLs or tokens. Tasks return at once; results are unbound
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

  static bool _aiBackend(AsrBackendConfig c) => PluginGate.ai(
    c.pluginId,
    instanceId: c.id,
    capability: 'speech.transcribe',
  );

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
  }) => registry.register(
    RegisteredTool(
      name,
      description,
      fields,
      (a) => _guard(() => execute(a)),
      readOnly: readOnly,
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
    final backendId = a['backend_id'] as String? ?? 'embedded';
    final config = service.backends.get(backendId);
    if (config == null) throw const ToolFailure('backend_not_configured');
    // Never silently switch to another backend or execution location.
    if (!_aiBackend(config)) throw const ToolFailure('permissionDenied');
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
    return {
      ...service.task(run.taskId)!,
      'note': 'Runs in the background. Poll subtitle_task_get sparingly (every 10 s or more). Results are not attached to the video until subtitle_save.',
    };
  }

  void _register() {
    _add(
      'speech_recognition_backends',
      'Configured speech recognition backends (on-device or the user\'s HTTP service): id, model, availability and whether uploads are authorised.',
      {},
      (_) async => {
        'backends': [
          for (final c in service.backends.list().where(_aiBackend))
            await () async {
              final s = await service.backends.backend(c.id).status();
              return {
                'backend_id': c.id,
                'kind': c.kind,
                'name': c.name,
                'model_id': c.modelId,
                'default_language': c.language,
                'available': s.available,
                'reason': ?s.reason,
                if (c.uploads) 'upload_authorized': c.uploadConsentAt != null,
              };
            }(),
        ],
        'limits': {'translation': false, 'timestamp_level': 'segment'},
      },
    );
    final fields = {
      'resource_ref': const ToolField('string', required: true),
      'backend_id': const ToolField('string', maxLength: 64),
      'language': const ToolField('string', maxLength: 8),
      'audio_track_ref': const ToolField('string', maxLength: 64),
      'start_ms': _ms,
      'end_ms': _ms,
      'whole_media': const ToolField('boolean'),
    };
    _add(
      'subtitle_generate',
      'Generate subtitles (original language, no translation) for an explicit range of a resource (start_ms/end_ms, or whole_media=true). Returns task_id; on success the task lists subtitle_artifact_ref and transcript_artifact_ref.',
      fields,
      (a) => _generate(a, subtitles: true),
      readOnly: false,
    );
    _add(
      'transcript_generate',
      'Generate a timestamped transcript for an explicit range of a resource. Returns task_id; on success the task lists transcript_artifact_ref.',
      fields,
      (a) => _generate(a, subtitles: false),
      readOnly: false,
    );
    _add(
      'subtitle_task_get',
      'Get a subtitle/transcript task: status, stage, error, artifact refs.',
      {'task_id': _id},
      (a) async =>
          service.task(a['task_id'] as String) ??
          (throw const ToolFailure('notFound')),
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
