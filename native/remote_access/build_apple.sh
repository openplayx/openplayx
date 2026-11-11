#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
output="${PODS_CONFIGURATION_BUILD_DIR:?}/libopenplayx_remote.a"
archives=()
for arch in ${ARCHS:?}; do
  sdk="${SDKROOT:?}"
  target="$arch"
  export GOARCH="$arch"
  [[ "$arch" != x86_64 ]] || export GOARCH=amd64
  export GOOS=darwin
  flags="-arch $arch -isysroot $sdk"
  if [[ "${PLATFORM_NAME}" == iphone* ]]; then
    export GOOS=ios
    if [[ "${PLATFORM_NAME}" == iphonesimulator ]]; then
      flags="$flags -target $arch-apple-ios15.0-simulator"
    else
      flags="$flags -target $arch-apple-ios15.0"
    fi
  fi
  archive="${DERIVED_FILE_DIR:?}/remote-$arch.a"
  export CGO_CFLAGS="$flags" CGO_LDFLAGS="$flags" CC="$(xcrun --find clang)"
  CGO_ENABLED=1 go build -trimpath -tags with_reality,with_utls -buildmode=c-archive -o "$archive" .
  archives+=("$archive")
done
xcrun lipo -create "${archives[@]}" -output "$output"
