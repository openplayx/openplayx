#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
ndk="${ANDROID_NDK_HOME:?Set ANDROID_NDK_HOME to the Flutter-pinned Android NDK}"
case "$(uname -s)" in
 Darwin) host=darwin-x86_64;;
 Linux) host=linux-x86_64;;
 *) echo 'Build Android on Linux or macOS' >&2; exit 1;;
esac
for abi in arm64-v8a armeabi-v7a x86_64; do
 case "$abi" in
  arm64-v8a) arch=arm64; target=aarch64-linux-android;;
  armeabi-v7a) arch=arm; target=armv7a-linux-androideabi;;
  x86_64) arch=amd64; target=x86_64-linux-android;;
 esac
 mkdir -p "build/android/$abi"
 GOOS=android GOARCH="$arch" GOARM=7 CGO_ENABLED=1 \
 CC="$ndk/toolchains/llvm/prebuilt/$host/bin/${target}29-clang" \
 go build -trimpath -tags with_reality,with_utls -buildmode=c-shared -o "build/android/$abi/libopenplayx_remote.so" .
done
