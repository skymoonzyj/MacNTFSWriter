#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="${APP_NAME:-MacNTFSWriter}"
DISPLAY_NAME="${DISPLAY_NAME:-NTFS Writer for Mac}"
BUNDLE_ID="${BUNDLE_ID:-com.macntfswriter.app}"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PWD/.build/clang-module-cache}"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

if [ ! -f "Resources/AppIcon.icns" ]; then
  ./scripts/generate-app-icon.swift
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_DIR/MacNTFSWriter" "$MACOS_DIR/$APP_NAME"
cp "scripts/install-deps-macos.sh" "$RESOURCES_DIR/install-deps-macos.sh"
cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
chmod +x "$RESOURCES_DIR/install-deps-macos.sh"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSRemovableVolumesUsageDescription</key>
  <string>NTFS Writer for Mac 需要访问外接 NTFS 磁盘，用于扫描分区、挂载卷并验证读写状态。</string>
</dict>
</plist>
PLIST

echo "Created $APP_DIR"
