#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=2.10.1
sha=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
root="${SPARKLE_DIR:-$PWD/build/sparkle-$version}"
if [[ ! -f "$root/Sparkle.framework/Versions/B/Sparkle" || ! -x "$root/bin/sign_update" ]]; then
  archive=$(mktemp)
  tmp=$(mktemp -d)
  trap 'rm -f "$archive"; rm -rf "$tmp"' EXIT
  curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-$version.tar.xz" -o "$archive"
  actual=$(shasum -a 256 "$archive" | awk '{print $1}')
  [[ "$actual" == "$sha" ]] || { echo 'Sparkle checksum mismatch' >&2; exit 1; }
  tar -xJf "$archive" -C "$tmp"
  mkdir -p "$root"
  ditto "$tmp/Sparkle.framework" "$root/Sparkle.framework"
  ditto "$tmp/bin" "$root/bin"
fi
printf '%s\n' "$root"
