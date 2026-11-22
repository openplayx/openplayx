#!/usr/bin/env bash
# Builds a sideloadable Apple TV IPA. Re-sign with a tvOS provisioning profile
# before installing on hardware; this is not an App Store/TestFlight export.
set -euo pipefail
cd "$(dirname "$0")/.."
tvos_bin="${FLUTTER_TVOS_BIN:-flutter-tvos}"
version="$(sed -n 's/^version: \([^+]*\).*/\1/p' pubspec.yaml)"
number="$(sed -n 's/^version: .*+\(.*\)/\1/p' pubspec.yaml)"
revision="$(git rev-parse --short=10 HEAD)"
output="${OPX_DIST_DIR:-$PWD/build/tvos/dist}"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
"$tvos_bin" build tvos --release --no-codesign -t lib/main.dart \
  --build-name="$version" --build-number="$number" \
  --dart-define=SENTRY_DSN= --dart-define=POSTHOG_PROJECT_TOKEN=
app="build/tvos/Release-appletvos/Runner.app"
/usr/libexec/PlistBuddy -c 'Print :CFBundleSupportedPlatforms:0' "$app/Info.plist" | grep -qx AppleTVOS
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
cp docs/tvos.md "$work/Payload/OpenPlayX.app/Licenses/tvos-build.md"
name="openplayx-${version}-tvos-arm64-${revision}.ipa"
(cd "$work" && ditto -c -k --norsrc Payload "$output/$name")
(cd "$output" && shasum -a 256 "$name" > "$name.sha256")
echo "Built $output/$name (unsigned; re-sign before installing)"
