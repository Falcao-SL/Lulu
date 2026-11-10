#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-2.0.0}"
BUILD="${BUILD:-0}"
ARCH="${ARCH:-arm64}"
case "$ARCH" in arm64|x86_64) ;; *) echo "Arquitetura inválida: $ARCH" >&2; exit 1;; esac
export VERSION BUILD ARCH

./Scripts/build.sh

APP="build/Lulu.app"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  codesign --force --sign - "${APP}"
else
  keychain="${LULU_SIGNING_KEYCHAIN:?Missing signing keychain}"
  sparkle="${APP}/Contents/Frameworks/Sparkle.framework"
  sign=(codesign --force --sign "$SIGNING_IDENTITY" --keychain "$keychain" --options runtime --timestamp)
  "${sign[@]}" "$sparkle/Versions/B/XPCServices/Installer.xpc"
  "${sign[@]}" --preserve-metadata=entitlements "$sparkle/Versions/B/XPCServices/Downloader.xpc"
  "${sign[@]}" "$sparkle/Versions/B/Autoupdate"
  "${sign[@]}" "$sparkle/Versions/B/Updater.app"
  "${sign[@]}" "$sparkle"
  "${sign[@]}" "$APP"
fi
codesign --verify --deep --strict --verbose=2 "${APP}"

mkdir -p dist
ZIP="dist/Lulu-${VERSION}-macos-${ARCH}.zip"
DMG="dist/Lulu-${VERSION}-macos-${ARCH}.dmg"
ditto -c -k --keepParent "${APP}" "${ZIP}"

STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT
cp -R "${APP}" "${STAGE}/"
ln -s /Applications "${STAGE}/Applications"
hdiutil create -volname "Lulu" -srcfolder "${STAGE}" -ov -format UDZO "${DMG}"
cp "${DMG}" "dist/Lulu-macos-${ARCH}.dmg"

echo "==> Packaged ${ZIP} and ${DMG}"
