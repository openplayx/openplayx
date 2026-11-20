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
        settings.load().validate();
        if ((await settings.key()).isEmpty) {
          throw const VoiceFailure('settings');
        }
      } catch (_) {
        throw const VoiceFailure('settings');
      }
      if (generation != _generation) return;
      await recorder.start();
      if (generation != _generation) return;
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
      try {
        await recorder.cancel();
      } catch (_) {}
      error = e is VoiceFailure ? e.code : 'recording';
      state = VoiceInputState.idle;
    }
    _notify();
  }

  Future<void> _stop() async {
    final generation = _generation;
    _limit?.cancel();
    state = VoiceInputState.transcribing;
    _notify();
    try {
      final audio = await recorder.stop();
      if (generation != _generation) return;
      final config = settings.load()..validate();
      final key = await settings.key();
      if (generation != _generation) return;
      if (key.isEmpty) throw const VoiceFailure('settings');
      final text = await transcriber.transcribe(config, key, audio);
      if (generation != _generation || _conversation != conversationId()) {
        return;
      }
      if (text.trim().isEmpty) throw const VoiceFailure('empty');
      final existing = draft.text;
      final joined =
          '$existing${existing.isEmpty || existing.endsWith(' ') || existing.endsWith('\n') ? '' : '\n'}$text';
      draft.value = TextEditingValue(
        text: joined,
        selection: TextSelection.collapsed(offset: joined.length),
      );
    } catch (e) {
      if (generation == _generation) {
        try {
          await recorder.cancel();
        } catch (_) {}
        if (generation != _generation) return;
        error = e is VoiceFailure ? e.code : 'transcription';
      }
    } finally {
      if (generation == _generation) {
        state = VoiceInputState.idle;
        _notify();
      }
    }
  }

  Future<void> cancel() async {
    if (!busy || state == VoiceInputState.cancelling) return;
    ++_generation;
    _limit?.cancel();
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
    _limit?.cancel();
    transcriber.cancel();
    unawaited(() async {
      await _starting;
      try {
        await recorder.dispose();
      } catch (_) {}
    }());
    super.dispose();
  }
}
