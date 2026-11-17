import 'package:openplayx_playback/playback.dart';

import '../controller/player_controller.dart';
import '../model/subtitle_state.dart';

/// The player as the AI assistant sees it: a JSON snapshot of the state and
/// the `playback_*` commands, translated to the same controller calls the
/// UI uses.
class PlayerAssistant {
  PlayerAssistant({required this.player, required this.stop});

  final PlayerController player;

  /// Stops playback the way the UI does (also resets the player screen).
  final Future<bool> Function() stop;

  PlayerBackend get _backend => player.backend;
  String? get _session => player.history.session.sessionId;

  /// Speeds the assistant may set.
  static const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0, 4.0];

  Map<String, dynamic> snapshot() {
    final value = _backend.value;
    final state = player.state;
    return {
      'session_id': state.busy || state.closing ? null : _session,
      'resource_id': player.history.session.resourceId,
      'status': value.status.name,
      'position_ms': value.position.inMilliseconds,
      'duration_ms': value.duration.inMilliseconds,
      'can_seek': value.canSeek,
      'speed': value.speed,
      'volume': value.volume,
      'subtitle': _subtitleSnapshot(),
    };
  }

  /// The shown subtitle: `default` (the player's own choice, unknown),
  /// `off`, or the chosen `embedded`/`external` track by name or
  /// `recognized` subtitle by binding id.
  Map<String, dynamic> _subtitleSnapshot() {
    final state = player.subtitles.state;
    return switch (state.selection) {
      SubtitleDefault() => {'kind': 'default'},
      SubtitleOff() => {'kind': 'off'},
      SubtitleChosen() => switch (state.selected?.source) {
        EmbeddedSubtitle() => {
          'kind': 'embedded',
          'name': state.selected!.name,
        },
        ExternalSubtitle() => {
          'kind': 'external',
          'name': state.selected!.name,
        },
        RecognizedSubtitleSource(:final saved) => {
          'kind': 'recognized',
          'binding_id': saved.bindingId,
        },
        null => {'kind': 'default'},
      },
    };
  }

  /// Runs [command] for the session in `args['session_id']`; throws a
  /// [StateError] naming the reason when it cannot.
  Future<Map<String, dynamic>> control(
    String command,
    Map<String, dynamic> args,
  ) async {
    final state = player.state;
    if (state.busy ||
        state.closing ||
        _session == null ||
        args['session_id'] != _session) {
      throw StateError('staleSession');
    }
    final session = _session;
    switch (command) {
      case 'pause':
        await _backend.pause();
      case 'resume':
        await _backend.play();
      case 'stop':
        if (!await stop()) throw StateError('stopFailed');
      case 'seek':
        final position = args['position_ms'] as int;
        if (!_backend.value.canSeek ||
            position > _backend.value.duration.inMilliseconds) {
          throw StateError('invalidPosition');
        }
        await _backend.seek(Duration(milliseconds: position));
      case 'set_speed':
        final speed = (args['speed'] as num).toDouble();
        if (!speeds.contains(speed)) throw StateError('unsupportedSpeed');
        await _backend.setSpeed(speed);
        player.tools.speedChanged(speed);
      case 'set_volume':
        await _backend.setVolume(args['volume'] as int);
      case 'set_subtitle':
        await _subtitle(args['binding_id'] as String?, args['off'] == true);
      default:
        throw StateError('unsupportedCommand');
    }
    if (command != 'stop' && session != _session) {
      throw StateError('staleSession');
    }
    player.history.checkpoint(force: true);
    return snapshot();
  }

  /// A saved recognised subtitle of the current resource (newest when
  /// [bindingId] is null), or off.
  Future<void> _subtitle(String? bindingId, bool off) async {
    // Right after opening, the native player may not accept a subtitle yet.
    for (var i = 0; i < 100 && !player.disposed; i++) {
      final status = _backend.value.status;
      if (status == PlaybackStatus.playing || status == PlaybackStatus.paused) {
        break;
      }
      if (status == PlaybackStatus.error || status == PlaybackStatus.ended) {
        throw StateError('playbackNotActive');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final subtitles = player.subtitles;
    if (off) {
      if (!await subtitles.turnOff()) throw StateError('subtitleFailed');
      return;
    }
    final saved = await subtitles.savedSubtitles();
    if (saved.isEmpty) throw StateError('noSavedSubtitle');
    final choice = bindingId == null
        ? saved.first
        : saved.where((s) => s.bindingId == bindingId).firstOrNull ??
              (throw StateError('subtitleNotFound'));
    if (!await subtitles.chooseRecognized(choice)) {
      throw StateError('subtitleFailed');
    }
  }
}
