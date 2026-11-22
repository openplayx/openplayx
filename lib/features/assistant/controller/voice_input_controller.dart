import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../assistant/voice/voice_service.dart';
import '../../../assistant/voice/voice_settings.dart';

enum VoiceInputState { idle, starting, recording, transcribing, cancelling }

class VoiceInputController extends ChangeNotifier {
  VoiceInputController({
    required this.settings,
    required this.draft,
    required this.conversationId,
    VoiceRecorder? recorder,
    VoiceTranscriber? transcriber,
  }) : recorder = recorder ?? DeviceVoiceRecorder(),
       transcriber = transcriber ?? OpenAiVoiceTranscriber();
  final VoiceSettings settings;
  final TextEditingController draft;
  final String Function() conversationId;
  final VoiceRecorder recorder;
  final VoiceTranscriber transcriber;
  VoiceInputState state = VoiceInputState.idle;
  String? error;
  bool _disposed = false;
  int _generation = 0;
  String? _conversation;
  Future<void>? _starting;
  Timer? _limit;
  StreamSubscription<double>? _levelSub;

  /// Number of level samples kept for the composer waveform.
  static const levelHistory = 64;

  /// Recent input levels (oldest first), updated while recording.
  final levels = ValueNotifier<List<double>>(const []);

  /// Time spent in the current recording.
  final elapsed = Stopwatch();
  bool get busy => state != VoiceInputState.idle;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> toggle() async {
    if (_disposed) return;
    if (state == VoiceInputState.recording) {
      await _stop();
    } else if (!busy) {
      final pending = _start();
      _starting = pending;
      await pending;
      _starting = null;
    }
  }

  Future<void> _start() async {
    final generation = ++_generation;
    state = VoiceInputState.starting;
    error = null;
    _conversation = conversationId();
    _notify();
    try {
      if (!recorder.supported) throw const VoiceFailure('unsupported');
      try {
        final config = settings.load()..validate();
        if (!config.usePlatform && (await settings.key()).isEmpty) {
          throw const VoiceFailure('settings');
        }
      } catch (_) {
        throw const VoiceFailure('settings');
      }
      if (generation != _generation) return;
      levels.value = const [];
      await _levelSub?.cancel();
      _levelSub = recorder.levels.listen((level) {
        final next = [...levels.value, level];
        levels.value = next.length > levelHistory
            ? next.sublist(next.length - levelHistory)
            : next;
      });
      await recorder.start();
      if (generation != _generation) return;
      elapsed
        ..reset()
        ..start();
      state = VoiceInputState.recording;
      // Bound temporary audio size and avoid unattended recordings.
      _limit = Timer(const Duration(minutes: 5), () async {
        await cancel();
        if (!_disposed) {
          error = 'tooLarge';
          _notify();
        }
      });
    } catch (e) {
      if (generation != _generation) return;
      _endRecording();
      try {
        await recorder.cancel();
      } catch (_) {}
      error = e is VoiceFailure ? e.code : 'recording';
      state = VoiceInputState.idle;
    }
    _notify();
  }

  /// Stops recording and appends the transcript to the draft. Returns whether
  /// text was added, so callers can send it right away.
  Future<bool> stop() async {
    if (state != VoiceInputState.recording) return false;
    return _stop();
  }

  void _endRecording() {
    _limit?.cancel();
    elapsed.stop();
    unawaited(_levelSub?.cancel());
    _levelSub = null;
  }

  Future<bool> _stop() async {
    final generation = _generation;
    _endRecording();
    var added = false;
    state = VoiceInputState.transcribing;
    _notify();
    try {
      final audio = await recorder.stop();
      if (generation != _generation) return false;
      final config = settings.load()..validate();
      final key = config.usePlatform ? 'platform' : await settings.key();
      if (generation != _generation) return false;
      if (key.isEmpty) throw const VoiceFailure('settings');
      final text = await transcriber.transcribe(config, key, audio);
      if (generation != _generation || _conversation != conversationId()) {
        return false;
      }
      if (text.trim().isEmpty) throw const VoiceFailure('empty');
      final existing = draft.text;
      final joined =
          '$existing${existing.isEmpty || existing.endsWith(' ') || existing.endsWith('\n') ? '' : '\n'}$text';
      draft.value = TextEditingValue(
        text: joined,
        selection: TextSelection.collapsed(offset: joined.length),
      );
      added = true;
    } catch (e) {
      if (generation == _generation) {
        try {
          await recorder.cancel();
        } catch (_) {}
        if (generation != _generation) return false;
        error = e is VoiceFailure ? e.code : 'transcription';
      }
    } finally {
      if (generation == _generation) {
        state = VoiceInputState.idle;
        _notify();
      }
    }
    return added;
  }

  Future<void> cancel() async {
    if (!busy || state == VoiceInputState.cancelling) return;
    ++_generation;
    _endRecording();
    state = VoiceInputState.cancelling;
    transcriber.cancel();
    _notify();
    try {
      await _starting;
      await recorder.cancel();
    } catch (_) {
      error = 'recording';
    } finally {
      state = VoiceInputState.idle;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _endRecording();
    transcriber.cancel();
    levels.dispose();
    unawaited(() async {
      await _starting;
      try {
        await recorder.dispose();
      } catch (_) {}
    }());
    super.dispose();
  }
}
