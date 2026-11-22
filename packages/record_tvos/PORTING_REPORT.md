# OpenPlayX record tvOS adapter

Based on record_ios 1.2.0, upstream license preserved. The original native recording
implementation is compiled for tvOS 17+, not the automatic porter's disabled
regions. Input discovery, permissions, AVAudioRecorder/AVAudioEngine, amplitude,
file/stream recording, cancellation and audio-session management are retained.

Two iPhone-only audio-routing options are intentionally mapped to no override:
`defaultToSpeaker` and `overrideMutedMicrophoneInterruption`. Apple TV uses its
system output route and does not expose these enum values. The app presents
AVContinuityDevicePickerViewController before voice recording, so users can
connect an iPhone/iPad microphone. Physical input requires compatible hardware;
the simulator has no continuity microphone.
