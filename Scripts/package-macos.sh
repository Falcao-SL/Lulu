#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-2.0.0}"
BUILD="${BUILD:-0}"
export VERSION BUILD

./Scripts/build.sh

APP="build/Lulu.app"
codesign --force --sign - "${APP}"
codesign --verify --verbose=2 "${APP}"

mkdir -p dist
rm -f dist/Lulu-*.zip dist/Lulu-*.dmg dist/SHA256SUMS

ZIP="dist/Lulu-${VERSION}-macos-arm64.zip"
DMG="dist/Lulu-${VERSION}-macos-arm64.dmg"
ditto -c -k --keepParent "${APP}" "${ZIP}"

STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT
cp -R "${APP}" "${STAGE}/"
ln -s /Applications "${STAGE}/Applications"
hdiutil create -volname "Lulu" -srcfolder "${STAGE}" -ov -format UDZO "${DMG}"
cp "${DMG}" dist/Lulu-macos-arm64.dmg

(
  cd dist
  shasum -a 256 "Lulu-${VERSION}-macos-arm64.zip" "Lulu-${VERSION}-macos-arm64.dmg" > SHA256SUMS
)

echo "==> Packaged ${ZIP} and ${DMG}"
