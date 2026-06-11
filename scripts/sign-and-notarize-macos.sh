#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_PATH="${1:-dist/MacNTFSWriter.app}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
ENTITLEMENTS_PATH="${ENTITLEMENTS_PATH:-}"
NOTARIZE="${NOTARIZE:-0}"

if [ ! -d "$APP_PATH" ]; then
  echo "App not found: $APP_PATH" >&2
  exit 1
fi

if [ -z "$ENTITLEMENTS_PATH" ] && [ -f "Resources/MacNTFSWriter.entitlements" ]; then
  ENTITLEMENTS_PATH="Resources/MacNTFSWriter.entitlements"
fi

SIGN_ARGS=(--force --deep)
if [ -n "$ENTITLEMENTS_PATH" ]; then
  SIGN_ARGS+=(--entitlements "$ENTITLEMENTS_PATH")
fi

if [ -n "$CODESIGN_IDENTITY" ]; then
  echo "Signing with Developer ID identity: $CODESIGN_IDENTITY"
  SIGN_ARGS+=(--options runtime --timestamp --sign "$CODESIGN_IDENTITY")
else
  echo "CODESIGN_IDENTITY is empty. Using ad-hoc signing for local builds."
  SIGN_ARGS+=(--sign -)
fi

codesign "${SIGN_ARGS[@]}" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH" || true

if [ "$NOTARIZE" != "1" ]; then
  echo "Skipping notarization. Set NOTARIZE=1 and provide Apple credentials to notarize."
  exit 0
fi

if [ -z "$CODESIGN_IDENTITY" ]; then
  echo "Notarization requires a Developer ID Application signing identity." >&2
  exit 1
fi

if [ -z "${APPLE_ID:-}" ] || [ -z "${APPLE_TEAM_ID:-}" ] || [ -z "${APPLE_APP_PASSWORD:-}" ]; then
  echo "Set APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_PASSWORD before notarizing." >&2
  exit 1
fi

ZIP_PATH="${APP_PATH%.app}.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait

xcrun stapler staple "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH"

echo "Signed and notarized $APP_PATH"
