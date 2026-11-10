#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Lulu"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
VERSION="${VERSION:-2.0.0}"
BUILD="${BUILD:-0}"

echo "==> Building ${APP_NAME}..."
mkdir -p "${BUILD_DIR}"
swiftc -parse-as-library -O -target arm64-apple-macosx14.0 \
  -framework SwiftUI -framework AppKit -framework Security -lsqlite3 \
  Sources/LocalLLMManager/*.swift \
  -o "${BUILD_DIR}/Lulu"

echo "==> Rendering icon..."
swiftc -parse-as-library -target arm64-apple-macosx14.0 -framework AppKit \
  Sources/LocalLLMManager/CatGeometry.swift \
  Scripts/render-icon.swift \
  -o "${BUILD_DIR}/render-icon"
"${BUILD_DIR}/render-icon" "${BUILD_DIR}/AppIcon.iconset"
iconutil -c icns "${BUILD_DIR}/AppIcon.iconset" -o "${BUILD_DIR}/AppIcon.icns"

echo "==> Packaging ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
cp "${BUILD_DIR}/Lulu" "${APP_BUNDLE}/Contents/MacOS/Lulu"
cp "${BUILD_DIR}/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
mkdir -p "${APP_BUNDLE}/Contents/Resources/clients"
cp Resources/clients/*.png "${APP_BUNDLE}/Contents/Resources/clients/"
cp ThirdParty/Lucide/LICENSE "${APP_BUNDLE}/Contents/Resources/Lucide-LICENSE.txt"
chmod +x "${APP_BUNDLE}/Contents/MacOS/Lulu"

cat << PLIST > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Lulu</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.falcaosl.lulu</string>
    <key>CFBundleName</key>
    <string>Lulu</string>
    <key>CFBundleDisplayName</key>
    <string>Lulu</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Build complete: ${APP_BUNDLE}"
