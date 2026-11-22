#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
model=packages/tvos_services/tvos/Resources/ggml-tiny.bin
expected=be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21
mkdir -p "$(dirname "$model")"
if [ ! -f "$model" ]; then
  cached="$HOME/.cache/openplayx-asr-models/ggml-tiny.bin"
  if [ -f "$cached" ]; then cp "$cached" "$model"; else
    curl -fL --retry 3 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin' -o "$model.part"
    mv "$model.part" "$model"
  fi
fi
actual="$(shasum -a 256 "$model")"
[ "${actual%% *}" = "$expected" ] || { echo 'Bundled Whisper model checksum mismatch' >&2; exit 1; }

coreml=packages/tvos_services/tvos/Resources/ggml-tiny-encoder.mlmodelc
archive=build/tvos-model-cache/tiny-coreml.zip
if [ ! -d "$coreml" ]; then
  mkdir -p "$(dirname "$archive")"
  if [ ! -f "$archive" ]; then curl -fL --retry 3 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny-encoder.mlmodelc.zip' -o "$archive"; fi
  actual="$(shasum -a 256 "$archive")"
  [ "${actual%% *}" = c88cbd2648e1f5415092bcf5256add463a0f19943e6938f46e8d4ffdebd47739 ] || { echo 'Core ML model checksum mismatch' >&2; exit 1; }
  unzip -q "$archive" -d packages/tvos_services/tvos/Resources/
fi

licenses=packages/tvos_services/tvos/Resources/Licenses
mkdir -p "$licenses"
cp LICENSE "$licenses/OpenPlayX-LICENSE.txt"
cp packages/vlc_player_tvos/LICENSE "$licenses/vlc_player-LICENSE.txt"
cp packages/posthog_flutter_tvos/LICENSE "$licenses/PostHog-Flutter-LICENSE.txt"
cp packages/sentry_flutter_tvos/LICENSE "$licenses/Sentry-Flutter-LICENSE.txt"
cp packages/record_tvos/LICENSE "$licenses/record-LICENSE.txt"
mkdir -p "$licenses/FFmpeg-codecs"
cp -R ../ffmpeg-package/LICENSES/. "$licenses/FFmpeg-codecs/"
cp ../package-whisper/LICENSE "$licenses/openplayx-whisper-LICENSE.txt"
cp ../package-whisper/LICENSES/whisper.cpp-LICENSE.txt "$licenses/whisper.cpp-LICENSE.txt"
cp native/remote_access/LICENSE "$licenses/remote-LICENSE.txt"
cp native/remote_access/COPYING "$licenses/remote-COPYING.txt"
