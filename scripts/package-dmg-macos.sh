#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="${APP_NAME:-MacNTFSWriter}"
DISPLAY_NAME="${DISPLAY_NAME:-NTFS Writer for Mac}"
VERSION="${VERSION:-0.1.0}"
SIGN_APP="${SIGN_APP:-1}"
export COPYFILE_DISABLE=1

./scripts/package-app-macos.sh

mkdir -p dist
DMG_PATH="dist/$APP_NAME.dmg"
STAGING_DIR="dist/dmg-staging"
APP_PATH="dist/$APP_NAME.app"

if [ "$SIGN_APP" = "1" ]; then
  ./scripts/sign-and-notarize-macos.sh "$APP_PATH"
fi

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
ditto --noextattr --norsrc "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
xattr -cr "$STAGING_DIR/$APP_NAME.app" 2>/dev/null || true

ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$DISPLAY_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGING_DIR"

if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG_PATH"
fi

echo "Created $DMG_PATH"
