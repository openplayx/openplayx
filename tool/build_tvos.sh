#!/usr/bin/env bash
# Builds a sideloadable Apple TV IPA. Re-sign with a tvOS provisioning profile
# before installing on hardware; this is not an App Store/TestFlight export.
set -euo pipefail
cd "$(dirname "$0")/.."
tvos_bin="${FLUTTER_TVOS_BIN:-flutter-tvos}"
version="$(sed -n 's/^version: \([^+]*\).*/\1/p' pubspec.yaml)"
number="$(sed -n 's/^version: .*+\(.*\)/\1/p' pubspec.yaml)"
revision="$(git rev-parse --short=10 HEAD)"
output="${OPX_DIST_DIR:-$PWD/build/tvos-artifacts}"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
# flutter-tvos stages Flutter assets in build/tvos. Keeping previous IPAs or
# debug snapshots there would embed them into the next application's assets.
case "$output" in
  "$PWD/build/tvos"|"$PWD/build/tvos/"*) echo 'Use an artifact directory outside build/tvos' >&2; exit 1 ;;
esac
rm -rf build/tvos
bash tool/prepare_tvos_models.sh
"$tvos_bin" build tvos --release --no-codesign -t lib/main.dart \
  --build-name="$version" --build-number="$number"
app="build/tvos/Release-appletvos/Runner.app"
/usr/libexec/PlistBuddy -c 'Print :CFBundleSupportedPlatforms:0' "$app/Info.plist" | grep -qx AppleTVOS
# Fail packaging if any engine silently disappeared or an iOS framework leaked in.
for library in openplayx_ffmpeg openplayx_whisper; do
  test -f "$app/Frameworks/$library.framework/$library"
done
nm -gU "$app/Frameworks/openplayx_ffmpeg.framework/openplayx_ffmpeg" | grep ' _opx_media_probe$' >/dev/null
nm -gU "$app/Frameworks/openplayx_whisper.framework/openplayx_whisper" | grep ' _opx_asr_model_open$' >/dev/null
nm -gU "$app/Runner" | grep ' _opx_remote_start$' >/dev/null
for framework in "$app"/Frameworks/*.framework; do
  binary="$framework/$(basename "$framework" .framework)"
  xcrun vtool -show-build "$binary" | grep -E 'platform TVOS$|cmd LC_VERSION_MIN_TVOS$' >/dev/null
done
actual="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Info.plist")"
[ "$actual" = "$version" ] || { echo "wrong build version: $actual" >&2; exit 1; }
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/Payload"
ditto "$app" "$work/Payload/OpenPlayX.app"
mkdir -p "$work/Payload/OpenPlayX.app/Licenses"
cp LICENSE "$work/Payload/OpenPlayX.app/Licenses/OpenPlayX-LICENSE.txt"
cp packages/vlc_player_tvos/LICENSE "$work/Payload/OpenPlayX.app/Licenses/vlc_player-LICENSE.txt"
cp tvos/Pods/TVVLCKit/COPYING.txt "$work/Payload/OpenPlayX.app/Licenses/TVVLCKit-COPYING.txt"
cp -R ../ffmpeg-package/LICENSES "$work/Payload/OpenPlayX.app/Licenses/FFmpeg-codecs"
cp ../package-whisper/LICENSE "$work/Payload/OpenPlayX.app/Licenses/openplayx-whisper-LICENSE.txt"
cp ../package-whisper/third_party/whisper/src/whisper.cpp-1.9.5/LICENSE "$work/Payload/OpenPlayX.app/Licenses/whisper.cpp-LICENSE.txt"
cp native/remote_access/LICENSE "$work/Payload/OpenPlayX.app/Licenses/remote-LICENSE.txt"
cp native/remote_access/COPYING "$work/Payload/OpenPlayX.app/Licenses/remote-COPYING.txt"
cp docs/tvos.md "$work/Payload/OpenPlayX.app/Licenses/tvos-build.md"
name="openplayx-${version}-tvos-arm64-${revision}.ipa"
(cd "$work" && ditto -c -k --norsrc --keepParent Payload "$output/$name")
unzip -Z1 "$output/$name" | grep -x 'Payload/OpenPlayX.app/Info.plist' >/dev/null
(cd "$output" && shasum -a 256 "$name" > "$name.sha256")
echo "Built $output/$name (unsigned; re-sign before installing)"

if [ -n "${OPX_TVOS_SIGNING_BUNDLE:-${OPX_SIGNING_FILE:-}}" ]; then
  python3 tool/sign_tvos.py --credentials "${OPX_TVOS_SIGNING_BUNDLE:-$OPX_SIGNING_FILE}" --output "$output/appstore-export"
  cp "$output/appstore-export/openplayx.ipa" "$output/openplayx-${version}-tvos-appstore-arm64-${revision}.ipa"
  (cd "$output" && shasum -a 256 "openplayx-${version}-tvos-appstore-arm64-${revision}.ipa" > "openplayx-${version}-tvos-appstore-arm64-${revision}.ipa.sha256")
fi
