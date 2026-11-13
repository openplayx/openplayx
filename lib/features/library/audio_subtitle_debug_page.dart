import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/plugins/source_capability.dart';
import '../../core/plugins/speech_recognition_capability.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/subtitles/asr_backend_config.dart';
import '../settings/asr_settings_section.dart';
import '../../ui/components/settings/settings_section.dart';
import '../../services/subtitles/subtitle_format.dart';
import '../../services/subtitles/subtitle_generation_service.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/tokens/app_spacing.dart';

/// What the detail page resolved before opening: one episode/movie and one
/// concrete resource version. Never a whole series.
class AudioSubtitleTarget {
  const AudioSubtitleTarget({
    required this.resource,
    required this.title,
    required this.resourceName,
    this.episodeLabel,
    this.versionLabel,
  });
  final ResourceRef resource;
  final String title;
  final String resourceName;

  /// e.g. `S1E3 · Episode title`.
  final String? episodeLabel;

  /// Source/version label without any URL or credential.
  final String? versionLabel;
}

/// Developer-mode page (design §3): extract audio and recognise subtitles
/// for one selected resource without the LLM. Nothing runs until a button
/// is pressed; leaving cancels unfinished work and discards unsaved output.
class AudioSubtitleDebugPage extends StatefulWidget {
  const AudioSubtitleDebugPage({
    super.key,
    required this.service,
    required this.target,
  });
  final SubtitleGenerationService? service;
  final AudioSubtitleTarget target;

  @override
  State<AudioSubtitleDebugPage> createState() => _AudioSubtitleDebugPageState();
}

class _AudioSubtitleDebugPageState extends State<AudioSubtitleDebugPage> {
  AppLocalizations get l => AppLocalizations.of(context);
  SubtitleGenerationService? get _service => widget.service;
  DebugSubtitleSession? _session;

  ResourceAudioInfo? _info;
  String? _inspectError;
  String? _trackRef;
  final _start = TextEditingController(text: '0');
  final _end = TextEditingController();
  bool _whole = false;
  String? _rangeError;

  List<AsrBackendConfig> _backends = const [];
  String? _backendId;
  final _status = <String, AsrBackendStatus>{};

  SubtitleRun? _run;
  SubtitleRunState? _state;
  StreamSubscription<SubtitleRunState>? _sub;
  SubtitleFormat _preview = SubtitleFormat.srt;
  Map<String, dynamic>? _saved;
  String? _notice;

  bool get _busy => _state != null && !_state!.status.terminal;

  @override
  void initState() {
    super.initState();
    final service = _service;
    if (service == null) return;
    _session = DebugSubtitleSession(service, widget.target.resource);
    _backends = service.backends.list();
    _backendId = _backends.firstOrNull?.id;
    unawaited(_inspect());
    unawaited(_refreshBackends());
  }

  @override
  void dispose() {
    // Late events must not reach a disposed page; the session then cancels
    // and discards in the background (native work is awaited there).
    unawaited(_sub?.cancel());
    unawaited(_session?.close());
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _inspect() async {
    try {
      final info = await _service!.inspect(widget.target.resource);
      if (!mounted) return;
      final duration = info.durationMs;
      setState(() {
        _info = info;
        _trackRef = info.defaultTrack?.ref;
        _end.text = _formatSeconds(
          duration == null
              ? SubtitleGenerationService.defaultRangeMs
              : duration.clamp(0, SubtitleGenerationService.defaultRangeMs),
        );
      });
    } on SubtitleException catch (e) {
      if (mounted) setState(() => _inspectError = e.code);
    } catch (_) {
      if (mounted) setState(() => _inspectError = 'internal_error');
    }
  }

  Future<void> _refreshBackends() async {
    final service = _service!;
    setState(() {
      _backends = service.backends.list();
      if (!_backends.any((c) => c.id == _backendId)) {
        _backendId = _backends.firstOrNull?.id;
      }
      _status.clear();
    });
    for (final c in _backends) {
      final s = await _service!.backends.backend(c.id).status();
      if (!mounted) return;
      setState(() => _status[c.id] = s);
    }
  }

  // ------------------------------------------------------------- helpers

  static String _formatSeconds(int ms) {
    final s = ms / 1000;
    return s == s.roundToDouble() ? '${s.round()}' : s.toStringAsFixed(3);
  }

  /// `90`, `1:30`, `00:01:30.5` → milliseconds.
  static int? _parseTime(String text) {
    final parts = text.trim().split(':');
    if (parts.isEmpty || parts.length > 3) return null;
    var seconds = 0.0;
    for (final p in parts) {
      final v = double.tryParse(p);
      if (v == null || v < 0) return null;
      seconds = seconds * 60 + v;
    }
    return (seconds * 1000).round();
  }

  static String clock(int ms) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(ms ~/ 3600000)}:${two(ms ~/ 60000 % 60)}:${two(ms ~/ 1000 % 60)}.${(ms % 1000).toString().padLeft(3, '0')}';
  }

  static String bytes(int n) {
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    if (n < 1024 * 1024 * 1024)
      return '${(n / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(n / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String _stageLabel(AsrStage s) => switch (s) {
    AsrStage.preparing => l.asrStagePreparing,
    AsrStage.extracting => l.asrStageExtracting,
    AsrStage.uploading => l.asrStageUploading,
    AsrStage.queued => l.asrStageQueued,
    AsrStage.transcribing => l.asrStageTranscribing,
    AsrStage.formatting => l.asrStageFormatting,
  };

  /// Readable text for the short error/reason codes (unknown codes shown raw).
  String _reason(String code) => switch (code) {
    'no_audio_track' => l.asrErrorNoAudio,
    'duration_unknown' => l.asrErrorDurationUnknown,
    'model_not_installed' => l.asrErrorModelMissing,
    'engine_unavailable' => l.asrErrorEngineUnavailable,
    'ffmpeg_unavailable' => l.ffmpegUnavailable,
    'backend_unreachable' || 'backend_timeout' => l.asrErrorUnreachable,
    'backend_unauthorized' => l.asrErrorUnauthorized,
    'upload_not_authorized' => l.asrErrorUploadConsent,
    'tls_verification_failed' => l.asrErrorTls,
    'remote_stream_requires_download' => l.asrErrorRemoteStream,
    'audio_track_changed' => l.asrErrorTrackChanged,
    'cancelled' => l.asrCancelled,
    _ => code,
  };

  (int, int?)? _range() {
    if (_whole) return (0, null);
    final start = _parseTime(_start.text);
    final end = _parseTime(_end.text);
    final duration = _info?.durationMs;
    if (start == null || end == null || end <= start) return null;
    if (duration != null && start >= duration) return null;
    return (start, end);
  }

  /// Model install/selection without leaving the debug flow (design §6):
  /// downloads still only start from an explicit action on that page.
  Future<void> _openModelSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AppPage(
          title: Text(l.asrSettingsTitle),
          body: SettingsListView(
            children: [AsrSettingsSection(registry: _service!.backends)],
          ),
        ),
      ),
    );
    if (mounted) await _refreshBackends();
  }

  // ------------------------------------------------------------- actions

  Future<void> _go({required bool transcribe}) async {
    final session = _session;
    final info = _info;
    if (session == null || info == null || _busy) return;
    final range = _range();
    if (range == null) {
      setState(() => _rangeError = l.asrRangeInvalid);
      return;
    }
    setState(() => _rangeError = null);
    final config = transcribe ? _service!.backends.get(_backendId ?? '') : null;
    if (transcribe && config == null) return;
    if (_whole && !await _confirmWhole(info)) return;
    if (config != null && config.uploads && config.uploadConsentAt == null) {
      if (!await _confirmUpload(config, range)) return;
      _service!.backends.grantUploadConsent(config.id);
    }
    if (!mounted) return;
    final SubtitleRun run;
    try {
      run = session.start(
        SubtitleRequest(
          resource: widget.target.resource,
          resourceName: widget.target.resourceName,
          caller: SubtitleCaller.debug,
          trackRef: _trackRef,
          startMs: range.$1,
          endMs: range.$2,
          wholeMedia: _whole,
          backendId: config?.id,
          transcribe: transcribe,
        ),
      );
    } on SubtitleException catch (e) {
      setState(() => _notice = _reason(e.code));
      return;
    }
    await _sub?.cancel();
    setState(() {
      _run = run;
      _state = run.current;
      _saved = null;
      _notice = null;
    });
    _sub = run.updates.listen((s) {
      if (mounted && _run == run) setState(() => _state = s);
    });
  }

  Future<bool> _confirmWhole(ResourceAudioInfo info) async {
    final duration = info.durationMs!;
    final ok = await showShadDialog<bool>(
      context: context,
      builder: (c) => ShadDialog(
        title: Text(l.asrWholeTitle),
        description: Text(
          l.asrWholeBody(
            clock(duration),
            bytes(SubtitleGenerationService.estimateWavBytes(duration)),
          ),
        ),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cancel),
          ),
          ShadButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.asrContinue),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<bool> _confirmUpload(AsrBackendConfig c, (int, int?) range) async {
    final end = range.$2 ?? _info?.durationMs ?? 0;
    final ok = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog(
        title: Text(l.asrUploadTitle),
        description: Text(
          l.asrUploadBody(
            c.host,
            '${clock(range.$1)} – ${clock(end)}',
            c.url!.startsWith('http://') ? l.asrUploadInsecure : '',
          ),
        ),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          ShadButton(
            key: const ValueKey('asr-upload-allow'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.asrUploadAllow),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _save() async {
    final state = _state;
    final session = _session;
    if (state == null || session == null) return;
    try {
      final saved = await session.save(state.taskId, _preview);
      if (mounted) setState(() => _saved = saved);
    } on SubtitleException catch (e) {
      if (mounted) setState(() => _notice = _reason(e.code));
    }
  }

  /// Writes outside the app only through the system save dialog.
  Future<void> _export() async {
    final state = _state;
    if (state == null) return;
    final text = _service!.subtitleText(state.taskId, _preview);
    final base = widget.target.resourceName
        .replaceAll('\\', '/')
        .split('/')
        .last;
    final location = await getSaveLocation(
      suggestedName:
          '${base.replaceAll(RegExp(r'\.[^.]+$'), '')}.${state.transcript!.language}.${_preview.extension}',
    );
    if (location == null) return;
    await File(location.path).writeAsString(text);
    if (mounted) setState(() => _notice = l.asrExported);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final service = _service;
    final Widget body;
    if (service == null || !service.media.available) {
      body = Center(
        child: Text(l.ffmpegUnavailable, style: theme.textTheme.muted),
      );
    } else {
      body = ListView(
        padding: AppSpacing.page(context),
        children: [
          _section(l.asrSectionResource, _resource()),
          _section(l.asrSectionInput, _input()),
          _section(l.asrSectionBackend, _backendPicker()),
          _section(l.asrSectionActions, _actions()),
          if (_state != null) _section(l.asrSectionStatus, _progress()),
          if (_state?.audio != null) _section(l.asrSectionAudio, _audio()),
          if (_state?.transcript != null)
            _section(l.asrSectionSubtitles, _subtitles()),
          if (_state != null) _section(l.asrSectionDebug, _debug()),
        ],
      );
    }
    return AppPage(title: Text(l.asrDebugTitle), body: body);
  }

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: ShadCard(
      title: Text(title, style: ShadTheme.of(context).textTheme.large),
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: child,
      ),
    ),
  );

  Widget _kv(String k, String v, {Key? key}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(k, style: ShadTheme.of(context).textTheme.muted),
        ),
        Expanded(child: SelectableText(v, key: key)),
      ],
    ),
  );

  Widget _resource() {
    final t = widget.target;
    final d = _info?.durationMs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _kv(l.asrTitle, t.title),
        if (t.episodeLabel != null) _kv(l.asrEpisode, t.episodeLabel!),
        _kv(l.asrVersion, t.versionLabel ?? t.resourceName.split('/').last),
        _kv(
          l.asrDuration,
          _info == null
              ? '…'
              : d == null
              ? l.asrUnknown
              : clock(d),
        ),
        if (_inspectError != null)
          Text(
            _reason(_inspectError!),
            key: const ValueKey('asr-inspect-error'),
            style: TextStyle(
              color: ShadTheme.of(context).colorScheme.destructive,
            ),
          ),
      ],
    );
  }

  Widget _input() {
    final info = _info;
    if (info == null) {
      return _inspectError == null
          ? const ShadProgress()
          : const SizedBox.shrink();
    }
    if (info.tracks.isEmpty) return Text(l.asrErrorNoAudio);
    String trackLabel(AudioTrackChoice t) => [
      '#${t.index}',
      if (t.title.isNotEmpty) t.title,
      if (t.language.isNotEmpty) t.language,
      t.codec,
      l.asrChannels(t.channels),
      if (!t.decodable) l.asrNotDecodable,
    ].join(' · ');
    final wholeAllowed = info.durationMs != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShadSelect<String>(
          key: const ValueKey('asr-track'),
          initialValue: _trackRef,
          enabled: !_busy,
          options: [
            for (final t in info.tracks)
              ShadOption(value: t.ref, child: Text(trackLabel(t))),
          ],
          selectedOptionBuilder: (_, v) =>
              Text(trackLabel(info.tracks.firstWhere((t) => t.ref == v))),
          onChanged: (v) => setState(() => _trackRef = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 140,
              child: ShadInput(
                key: const ValueKey('asr-start'),
                controller: _start,
                enabled: !_busy && !_whole,
                placeholder: Text(l.asrStart),
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9:.]')),
                ],
              ),
            ),
            SizedBox(
              width: 140,
              child: ShadInput(
                key: const ValueKey('asr-end'),
                controller: _end,
                enabled: !_busy && !_whole,
                placeholder: Text(l.asrEnd),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9:.]')),
                ],
              ),
            ),
            ShadCheckbox(
              key: const ValueKey('asr-whole'),
              value: _whole,
              enabled: !_busy && wholeAllowed,
              label: Text(l.asrWhole),
              onChanged: (v) => setState(() => _whole = v),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          wholeAllowed ? l.asrRangeHint : l.asrWholeUnavailable,
          style: ShadTheme.of(context).textTheme.muted,
        ),
        if (_rangeError != null)
          Text(
            _rangeError!,
            style: TextStyle(
              color: ShadTheme.of(context).colorScheme.destructive,
            ),
          ),
      ],
    );
  }

  Widget _backendPicker() {
    if (_backends.isEmpty) return Text(l.asrNoBackends);
    String label(AsrBackendConfig c) => c.kind == 'embedded'
        ? '${l.asrEmbedded} · ${c.modelId}'
        : '${l.asrHttp} · ${c.name} · ${c.modelId}';
    final status = _status[_backendId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShadSelect<String>(
          key: const ValueKey('asr-backend'),
          initialValue: _backendId,
          enabled: !_busy,
          options: [
            for (final c in _backends)
              ShadOption(value: c.id, child: Text(label(c))),
          ],
          selectedOptionBuilder: (_, v) =>
              Text(label(_backends.firstWhere((c) => c.id == v))),
          onChanged: (v) => setState(() => _backendId = v),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          status == null
              ? l.asrChecking
              : status.available
              ? l.asrBackendReady(
                  status.engineVersion ?? '',
                  status.modelRevision ?? '',
                )
              : l.asrBackendUnavailable(
                  _reason(status.reason ?? 'unavailable'),
                ),
          key: const ValueKey('asr-backend-status'),
          style: ShadTheme.of(context).textTheme.muted,
        ),
        if (status != null && !status.available) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (_backends.firstWhere((c) => c.id == _backendId).kind ==
                  'embedded')
                ShadButton.outline(
                  key: const ValueKey('asr-install-model'),
                  size: ShadButtonSize.sm,
                  onPressed: _busy ? null : _openModelSettings,
                  child: Text(l.asrInstallModel),
                ),
              ShadButton.ghost(
                key: const ValueKey('asr-recheck'),
                size: ShadButtonSize.sm,
                onPressed: _busy ? null : _refreshBackends,
                child: Text(l.asrRecheck),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _actions() {
    final ready = _info != null && _info!.tracks.isNotEmpty;
    final backendReady = _status[_backendId]?.available == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ShadButton.outline(
              key: const ValueKey('asr-extract'),
              enabled: ready && !_busy,
              onPressed: () => _go(transcribe: false),
              child: Text(l.asrExtractOnly),
            ),
            ShadButton(
              key: const ValueKey('asr-transcribe'),
              enabled: ready && !_busy && backendReady,
              onPressed: () => _go(transcribe: true),
              child: Text(l.asrExtractAndTranscribe),
            ),
            ShadButton.ghost(
              key: const ValueKey('asr-cancel'),
              enabled: _busy && _state!.status != SubtitleRunStatus.cancelling,
              onPressed: () => _run?.cancel(),
              child: Text(l.cancel),
            ),
          ],
        ),
        if (ready && !_busy && !backendReady && _status[_backendId] != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              l.asrTranscribeBlocked(
                _reason(_status[_backendId]!.reason ?? 'unavailable'),
              ),
              key: const ValueKey('asr-transcribe-blocked'),
              style: ShadTheme.of(context).textTheme.muted,
            ),
          ),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(_notice!, key: const ValueKey('asr-notice')),
          ),
      ],
    );
  }

  Widget _progress() {
    final s = _state!;
    final total = s.total;
    final processed = s.processed;
    final fraction = total != null && total > 0 && processed != null
        ? (processed / total).clamp(0.0, 1.0)
        : null;
    final statusText = switch (s.status) {
      SubtitleRunStatus.running => _stageLabel(s.stage),
      SubtitleRunStatus.cancelling => l.asrCancelling,
      SubtitleRunStatus.cancelled => l.asrCancelled,
      SubtitleRunStatus.succeeded => l.asrSucceeded,
      SubtitleRunStatus.failed => l.asrFailed(
        _reason(s.error ?? 'internal_error'),
      ),
      SubtitleRunStatus.interrupted => l.asrFailed('interrupted'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(statusText, key: const ValueKey('asr-status')),
        if (!s.status.terminal) ...[
          const SizedBox(height: AppSpacing.sm),
          // No invented overall percentage: stage progress when known.
          // Determinate and indeterminate bars need separate states.
          ShadProgress(key: ValueKey(fraction == null), value: fraction),
        ],
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final stage in AsrStage.values)
              if (s.stageMs.containsKey(stage.name) || s.stage == stage)
                ShadBadge.secondary(
                  child: Text(
                    '${_stageLabel(stage)} ${s.stageMs[stage.name] == null ? '…' : '${(s.stageMs[stage.name]! / 1000).toStringAsFixed(1)}s'}',
                  ),
                ),
          ],
        ),
      ],
    );
  }

  Widget _audio() {
    final a = _state!.audio!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _kv(l.asrAudioTrack, '#${a.trackIndex}'),
        _kv(
          l.asrAudioFormat,
          '${a.sampleRate} Hz · ${l.asrChannels(a.channels)} · PCM s16 WAV',
        ),
        _kv(
          l.asrDuration,
          clock(a.durationMs),
          key: const ValueKey('asr-audio-duration'),
        ),
        _kv(l.asrAudioSize, bytes(a.bytes)),
        if (a.reused) _kv('', l.asrAudioReused),
      ],
    );
  }

  Widget _subtitles() {
    final s = _state!;
    final t = s.transcript!;
    final theme = ShadTheme.of(context);
    if (t.segments.isEmpty) {
      return Text(l.asrNoSpeech, key: const ValueKey('asr-empty'));
    }
    final text = serialize(s.cues ?? buildCues(t.segments), _preview);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.wholeMedia
              ? l.asrWholeResult
              : l.asrPartialResult(clock(t.rangeStartMs), clock(t.rangeEndMs)),
          style: theme.textTheme.muted,
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: ListView(
            key: const ValueKey('asr-segments'),
            shrinkWrap: true,
            children: [
              for (final seg in t.segments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 210,
                        child: Text(
                          '${clock(seg.startMs)} → ${clock(seg.endMs)}',
                          style: theme.textTheme.muted.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      Expanded(child: SelectableText(seg.text)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final f in SubtitleFormat.values)
              f == _preview
                  ? ShadButton.secondary(
                      size: ShadButtonSize.sm,
                      onPressed: () {},
                      child: Text(f.extension.toUpperCase()),
                    )
                  : ShadButton.ghost(
                      key: ValueKey('asr-format-${f.extension}'),
                      size: ShadButtonSize.sm,
                      onPressed: () => setState(() => _preview = f),
                      child: Text(f.extension.toUpperCase()),
                    ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.border),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              key: const ValueKey('asr-preview'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ShadButton(
              key: const ValueKey('asr-save'),
              enabled: _saved == null,
              onPressed: _save,
              child: Text(l.asrSave),
            ),
            ShadButton.outline(
              key: const ValueKey('asr-export'),
              onPressed: _export,
              child: Text(l.asrExport),
            ),
            if (_saved != null)
              Text(
                _saved!['partial'] == true ? l.asrSavedPartial : l.asrSaved,
                key: const ValueKey('asr-saved'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(l.asrSaveHint, style: theme.textTheme.muted),
      ],
    );
  }

  Widget _debug() {
    final s = _state!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _kv(l.asrTaskId, s.taskId, key: const ValueKey('asr-task-id')),
        if (s.backend != null) _kv(l.asrBackendLabel, s.backend!),
        if (s.modelId != null) _kv(l.asrModel, s.modelId!),
        if (s.engineVersion != null) _kv(l.asrEngine, s.engineVersion!),
        if (s.transcript != null) _kv(l.asrLanguage, s.transcript!.language),
        if (s.remoteJobId != null) _kv(l.asrRemoteJob, s.remoteJobId!),
        for (final e in s.stageMs.entries) _kv(e.key, '${e.value} ms'),
        if (s.error != null) _kv(l.asrError, s.error!),
      ],
    );
  }
}
