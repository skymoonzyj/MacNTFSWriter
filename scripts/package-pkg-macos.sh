#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="${APP_NAME:-MacNTFSWriter}"
BUNDLE_ID="${BUNDLE_ID:-com.macntfswriter.app}"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGN_APP="${SIGN_APP:-1}"
INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-}"
export COPYFILE_DISABLE=1

APP_PATH="dist/$APP_NAME.app"
PKG_ROOT="dist/pkg-root"
PKG_COMPONENT="dist/$APP_NAME-component.pkg"
PKG_PATH="dist/$APP_NAME.pkg"

./scripts/package-app-macos.sh

if [ "$SIGN_APP" = "1" ]; then
  ./scripts/sign-and-notarize-macos.sh "$APP_PATH"
fi

rm -rf "$PKG_ROOT" "$PKG_COMPONENT" "$PKG_PATH"
mkdir -p "$PKG_ROOT/Applications"
ditto --noextattr --norsrc "$APP_PATH" "$PKG_ROOT/Applications/$APP_NAME.app"
xattr -cr "$PKG_ROOT" 2>/dev/null || true

pkgbuild \
  --root "$PKG_ROOT" \
  --identifier "$BUNDLE_ID.pkg" \
  --version "$VERSION.$BUILD_NUMBER" \
  --install-location "/" \
  "$PKG_COMPONENT"

PRODUCTBUILD_ARGS=(--package "$PKG_COMPONENT")
if [ -n "$INSTALLER_IDENTITY" ]; then
  PRODUCTBUILD_ARGS=(--sign "$INSTALLER_IDENTITY" "${PRODUCTBUILD_ARGS[@]}")
fi

productbuild "${PRODUCTBUILD_ARGS[@]}" "$PKG_PATH"

rm -rf "$PKG_ROOT" "$PKG_COMPONENT"

pkgutil --check-signature "$PKG_PATH" || true
spctl --assess --type install --verbose=2 "$PKG_PATH" || true

echo "Created $PKG_PATH"
