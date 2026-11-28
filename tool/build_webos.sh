#!/usr/bin/env bash
set -euo pipefail
app_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v ares-package >/dev/null 2>&1; then
  echo 'Missing webOS CLI. Install @webos-tools/cli, then retry.' >&2
  exit 1
fi
output="${1:-$app_root/build/webos}"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
ares-package "$app_root/webos" --outdir "$output" --no-minify
