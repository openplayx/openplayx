import 'dart:math';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_manager.dart';
import '../library/library_service.dart';
import '../media_processing/media_processing_service.dart';
import 'media_tools.dart';
import 'tool_registry.dart';
import '../../core/plugins/plugin_gate.dart';

/// Structured media-processing tools over [MediaProcessingService]. The
/// model only picks host-defined presets and host-issued references; there
/// is no command string, free FFmpeg option, URL or output path parameter.
class MediaProcessingTools {
  MediaProcessingTools({
    required this.registry,
    required this.service,
    required this.library,
    required this.sources,
    required this.entryForReference,
    this.canExecute,
  }) {
    _register();
  }

  final ToolRegistry registry;
  final MediaProcessingService service;
  final LibraryService library;
  final SourceManager sources;
  final SourceEntry? Function(String) entryForReference;
  final bool Function()? canExecute;

  /// Opaque track references → (resource key, stream index).
  final _tracks = <String, (String, int)>{};

  static const _ref = ToolField('string', required: true);
  static const _presetId = ToolField('string', required: true, maxLength: 64);
  static const _revision = ToolField(
    'integer',
    required: true,
    minimum: 1,
    maximum: 1000,
  );
  static const _ms = ToolField('integer', minimum: 0, maximum: 86400000);
  static const _track = ToolField('string', maxLength: 64);

  static String _key(ResourceRef r) => '${r.instanceId}\u0000${r.id}';

  /// `resource_ref` is a ref from search/browse or a library resource_id.
  (ResourceRef, String) _resource(String value) {
    var entry = entryForReference(value);
    if (entry == null) {
      final rows = library.db.select('SELECT * FROM resources WHERE id=?', [
        value,
      ]);
      if (rows.isNotEmpty) {
        final r = rows.first;
        entry = SourceEntry(
          ResourceRef(r['source'] as String, r['item'] as String),
          r['name'] as String,
          isFolder: false,
        );
      }
    }
    if (entry == null || entry.isFolder) {
      throw const ToolFailure('staleReference');
    }
    final source = entry.ref.instanceId;
    if (source != '@local') {
      final config = sources.configs
          .where((c) => c.id == source && c.enabled)
          .firstOrNull;
      if (config == null) throw const ToolFailure('unavailable');
      // Reading media for processing is resolve access on that instance.
      if (!PluginGate.ai(
        config.pluginId,
        instanceId: source,
        capability: 'source.resolve',
      )) {
        throw const ToolFailure('permissionDenied');
      }
    }
    return (entry.ref, entry.name);
  }

  /// Resolves a `track_ref` issued by `media_probe` (shared with other
  /// host tools such as subtitle generation).
  int? trackIndex(Object? token, ResourceRef ref) => _trackIndex(token, ref);

  /// Resolves a `resource_ref` the same way the processing tools do.
  (ResourceRef, String) resource(String value) => _resource(value);

  int? _trackIndex(Object? token, ResourceRef ref) {
    if (token == null) return null;
    final t = _tracks[token];
    if (t == null || t.$1 != _key(ref)) {
      throw const ToolFailure('staleReference');
    }
    return t.$2;
  }

  String _issueTrack(ResourceRef ref, int index) {
    final existing = _tracks.entries
        .where((e) => e.value == (_key(ref), index))
        .firstOrNull;
    if (existing != null) return existing.key;
    if (_tracks.length >= 2000) _tracks.remove(_tracks.keys.first);
    final token = 'track-${Random.secure().nextInt(1 << 32)}-${_tracks.length}';
    _tracks[token] = (_key(ref), index);
    return token;
  }

  bool get _active => ToolExecution.active && (canExecute?.call() ?? true);

  Future<Map<String, dynamic>> _guard(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    try {
      return await action();
    } on MediaException catch (e) {
      throw ToolFailure(_code(e));
    }
  }

  /// Short, actionable codes; reasons are appended without paths or logs.
  static String _code(MediaException e) =>
      e.reason == null ? e.code.name : '${e.code.name}:${e.reason}';

  List<Map<String, dynamic>> _presets(
    MediaCapabilities caps, [
    MediaProbe? probe,
  ]) => [
    for (final a in MediaPlanner.availability(caps, probe: probe))
      {
        'preset_id': a.preset.id,
        'preset_revision': a.preset.revision,
        'operation': a.preset.operation.name,
        'summary': a.preset.summary,
        'available': a.available,
        'reason': ?a.reason,
      },
  ];

  void _add(
    String name,
    String description,
    Map<String, ToolField> fields,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>) execute, {
    bool readOnly = true,
    bool always = false,
  }) => registry.register(
    RegisteredTool(
      name,
      description,
      fields,
      (a) => _guard(() => execute(a)),
      readOnly: readOnly,
      available: always ? null : () => service.available,
    ),
  );

  void _register() {
    _add(
      'media_processing_capabilities',
      'Real on-device media processing capabilities: presets with revision and availability, hardware encoder, limits. Optional resource_ref filters to presets applicable to that media.',
      {'resource_ref': const ToolField('string')},
      (a) async {
        final caps = await service.capabilities();
        MediaProbe? probe;
        if (a['resource_ref'] != null && caps.available) {
          probe = await service.probe(
            _resource(a['resource_ref'] as String).$1,
          );
        }
        return {
          'available': caps.available,
          if (caps.available) 'ffmpeg_version': caps.ffmpegVersion,
          'operations': ['transcode', 'extract_audio', 'snapshot'],
          'presets': _presets(caps, probe),
          'hardware': {
            'video_encoder': ?caps.hardwareVideoEncoder,
            if (caps.hardwareVideoEncoder == null)
              'unavailable_reason': 'no_hardware_h264_encoder_opened',
          },
          'limits': {
            'concurrency': 1,
            'subtitle_burn_in': false,
            'hdr_tone_mapping': false,
          },
        };
      },
      always: true,
    );
    _add(
      'media_probe',
      'Probe a resource: duration, container, tracks with track_ref values to pass to processing tools, and applicable presets.',
      {'resource_ref': _ref},
      (a) async {
        final (ref, _) = _resource(a['resource_ref'] as String);
        final probe = await service.probe(ref);
        final caps = await service.capabilities();
        return {
          'container': probe.container,
          'duration_ms': probe.durationUs ~/ 1000,
          'tracks': [
            for (final s in probe.streams.take(24))
              if (s.isVideo || s.isAudio || s.isSubtitle)
                {
                  'track_ref': _issueTrack(ref, s.index),
                  'type': s.type,
                  'codec': s.codec,
                  'decodable': s.decodable,
                  if (s.isVideo) ...{
                    'width': s.width,
                    'height': s.height,
                    'fps': double.parse(s.fps.toStringAsFixed(3)),
                    'rotation': s.rotation,
                    'hdr': s.isHdr,
                    'variable_frame_rate': s.variableFrameRate,
                  },
                  if (s.isAudio) ...{
                    'sample_rate': s.sampleRate,
                    'channels': s.channels,
                  },
                  if (s.language.isNotEmpty) 'language': s.language,
                  if (s.title.isNotEmpty) 'title': MediaTools.safeText(s.title),
                  'default': s.isDefault,
                },
          ],
          'presets': _presets(caps, probe),
        };
      },
    );

    Map<String, dynamic> submit(
      Map<String, dynamic> a,
      MediaOperation operation,
    ) {
      if (!_active) throw const ToolFailure('cancelled');
      final (ref, name) = _resource(a['resource_ref'] as String);
      Duration? ms(String k) =>
          a[k] == null ? null : Duration(milliseconds: a[k] as int);
      final t = service.submit(
        ref: ref,
        resourceName: name,
        presetId: a['preset_id'] as String,
        presetRevision: a['preset_revision'] as int,
        operation: operation,
        request: PlanRequest(
          start: ms('start_ms'),
          end: ms('end_ms'),
          time: ms('time_ms'),
          audioStream: _trackIndex(a['audio_track_ref'], ref),
          subtitleStream: _trackIndex(a['subtitle_track_ref'], ref),
        ),
      );
      return {
        ...t,
        'note': 'Task runs in the background; its card shows progress. Do not claim completion until task_get reports succeeded.',
      };
    }

    _add(
      'media_transcode',
      'Create a background transcode/remux task with a preset from media_processing_capabilities (e.g. video.mobile.720p, video.remux.mp4). Returns task_id immediately; never re-encodes silently when remux is incompatible.',
      {
        'resource_ref': _ref,
        'preset_id': _presetId,
        'preset_revision': _revision,
        'start_ms': _ms,
        'end_ms': _ms,
        'audio_track_ref': _track,
        'subtitle_track_ref': _track,
      },
      (a) async => submit(a, MediaOperation.transcode),
      readOnly: false,
    );
    _add(
      'media_extract_audio',
      'Create a background audio extraction task (audio.extract.original copies, audio.speech.wav re-encodes). Returns task_id.',
      {
        'resource_ref': _ref,
        'preset_id': _presetId,
        'preset_revision': _revision,
        'audio_track_ref': _track,
        'start_ms': _ms,
        'end_ms': _ms,
      },
      (a) async => submit(a, MediaOperation.extractAudio),
      readOnly: false,
    );
    _add(
      'media_snapshot',
      'Create a task that saves one frame of the resource at time_ms as an image (preset image.preview). Independent of the current playback frame.',
      {
        'resource_ref': _ref,
        'time_ms': const ToolField(
          'integer',
          required: true,
          minimum: 0,
          maximum: 86400000,
        ),
        'preset_id': _presetId,
        'preset_revision': _revision,
      },
      (a) async => submit(a, MediaOperation.snapshot),
      readOnly: false,
    );
    _add(
      'task_get',
      'Get a media processing task: status, progress, error and artifact_ref.',
      {'task_id': const ToolField('string', required: true, maxLength: 64)},
      (a) async {
        final t = service.task(a['task_id'] as String);
        if (t == null) throw const ToolFailure('notFound');
        return t;
      },
    );
    _add(
      'task_list',
      'List recent media processing tasks.',
      {
        'offset': const ToolField('integer', minimum: 0, maximum: 10000),
        'limit': const ToolField('integer', minimum: 1, maximum: 20),
      },
      (a) async {
        final offset = a['offset'] as int? ?? 0;
        final limit = a['limit'] as int? ?? 10;
        final rows = service.tasks(offset: offset, limit: limit);
        return {
          'tasks': rows,
          'next_offset': rows.length == limit ? offset + limit : null,
        };
      },
    );
    _add(
      'task_cancel',
      'Request cancellation of a media processing task; it reports cancelling until processing has really stopped.',
      {'task_id': const ToolField('string', required: true, maxLength: 64)},
      (a) async => service.cancel(a['task_id'] as String),
      readOnly: false,
    );
    _add(
      'task_retry',
      'Retry a failed, cancelled or interrupted task as a new attempt after re-checking resource, preset and device capability.',
      {'task_id': const ToolField('string', required: true, maxLength: 64)},
      (a) async {
        if (!_active) throw const ToolFailure('cancelled');
        return service.retry(a['task_id'] as String);
      },
      readOnly: false,
    );
  }
}
