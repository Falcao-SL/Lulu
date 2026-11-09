#!/bin/bash
set -e

APP_NAME="Local LLM Manager"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "==> Building ${APP_NAME}..."
mkdir -p "${BUILD_DIR}"
swiftc -parse-as-library -O -target arm64-apple-macosx14.0 \
  -framework SwiftUI -framework AppKit \
  Sources/LocalLLMManager/main.swift \
  -o "${BUILD_DIR}/LocalLLMManager"

echo "==> Packaging ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/LocalLLMManager" "${APP_BUNDLE}/Contents/MacOS/LocalLLMManager"
chmod +x "${APP_BUNDLE}/Contents/MacOS/LocalLLMManager"

cat << 'PLIST' > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>LocalLLMManager</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.llmmanager</string>
    <key>CFBundleName</key>
    <string>Local LLM Manager</string>
    <key>CFBundleDisplayName</key>
    <string>Local LLM Manager</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Build complete: ${APP_BUNDLE}"
