#!/bin/bash
set -euo pipefail

tag="v${VERSION:?Missing release version}"
release=(gh release)
assets=(dist/"Lulu-${VERSION}-macos-arm64.zip" dist/"Lulu-${VERSION}-macos-arm64.dmg"
        dist/Lulu-macos-arm64.dmg dist/"Lulu-${VERSION}-macos-x86_64.zip"
        dist/"Lulu-${VERSION}-macos-x86_64.dmg" dist/Lulu-macos-x86_64.dmg
        dist/SHA256SUMS dist/appcast-arm64.xml dist/appcast-x86_64.xml)

retry() {
  local attempt
  for attempt in 1 2 3 4 5; do
    if "$@"; then return 0; fi
    if (( attempt < 5 )); then sleep "$((attempt * 5))"; fi
  done
  return 1
}

for asset in "${assets[@]}"; do
  test -s "$asset"
done

latest=$(retry "${release[@]}" view --json tagName --jq .tagName)
python3 - "$tag" "$latest" <<'PY'
import sys

def parts(tag):
    return tuple(map(int, tag.removeprefix("v").split(".")))

candidate, latest = sys.argv[1:]
if parts(candidate) < parts(latest):
    raise SystemExit(f"Refusing to release {candidate} behind {latest}")
PY

verify_assets() {
  local uploaded comparison=$1
  uploaded=$("${release[@]}" view "$tag" --json assets --jq .assets) || return
  python3 - "$uploaded" "$comparison" "${assets[@]}" <<'PY'
import json
import sys
from pathlib import Path

sizes = {item["name"]: item["size"] for item in json.loads(sys.argv[1])}
comparison = sys.argv[2]
for asset in map(Path, sys.argv[3:]):
    size = sizes.get(asset.name, 0)
    if size <= 0 or (comparison == "exact" and size != asset.stat().st_size):
        raise SystemExit(f"Missing or incomplete release asset: {asset.name}")
PY
}

ensure_draft() {
  if "${release[@]}" view "$tag" --json isDraft >/dev/null 2>&1; then return 0; fi
  "${release[@]}" create "$tag" --draft --target "${GITHUB_SHA:?Missing commit SHA}" \
    --title "Lulu ${VERSION}" --generate-notes --notes \
    "Requires macOS 14 or later. MLX requires Apple Silicon. Intel Macs can run GGUF models with llama.cpp. Installers are Developer ID signed and notarized by Apple."
}

retry ensure_draft
draft=$(retry "${release[@]}" view "$tag" --json isDraft --jq .isDraft)
if [[ "$draft" == true ]]; then
  for asset in "${assets[@]}"; do
    retry "${release[@]}" upload "$tag" "$asset" --clobber
  done
  retry verify_assets exact
  retry "${release[@]}" edit "$tag" --draft=false --latest
else
  retry verify_assets present
fi
test "$(retry "${release[@]}" view --json tagName --jq .tagName)" = "$tag"
