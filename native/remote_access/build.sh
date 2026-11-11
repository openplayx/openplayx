#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
output="${1:-build/libopenplayx_remote.dylib}"
mkdir -p "$(dirname "$output")"
CGO_ENABLED=1 go build -trimpath -tags with_reality,with_utls -buildmode="${BUILD_MODE:-c-shared}" -o "$output" .
