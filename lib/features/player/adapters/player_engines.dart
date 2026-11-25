import 'package:openplayx_media/openplayx_media.dart';

/// Whether this device has a playback engine (libVLC or libmpv).
bool get playbackEngineSupported =>
    LibVlcBackend.isSupported || MpvBackend.isSupported;

/// The app's player: package-media's engine router, which picks libmpv or
/// libVLC for each media and falls back to the other engine when the first
/// cannot open it.
PlayerBackend createPlayerBackend() => RoutedPlayerBackend(
  router: EngineRouter(
    available: {
      if (LibVlcBackend.isSupported) MediaEngine.vlc,
      if (MpvBackend.isSupported) MediaEngine.mpv,
    },
  ),
);
