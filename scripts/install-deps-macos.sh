#!/usr/bin/env bash
set -euo pipefail

find_brew() {
  local candidates=(
    "/opt/homebrew/bin/brew"
    "/usr/local/bin/brew"
  )

  local path
  for path in "${candidates[@]}"; do
    if [ -x "$path" ]; then
      printf '%s\n' "$path"
      return 0
    fi
  done

  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  return 1
}

find_tool() {
  local name="$1"
  local candidates=(
    "/opt/homebrew/bin/$name"
    "/usr/local/bin/$name"
    "/opt/homebrew/sbin/$name"
    "/usr/local/sbin/$name"
    "/opt/local/bin/$name"
  )

  local path
  for path in "${candidates[@]}"; do
    if [ -x "$path" ]; then
      printf '%s\n' "$path"
      return 0
    fi
  done

  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi

  return 1
}

echo "Checking Homebrew..."
if ! BREW_BIN="$(find_brew)"; then
  echo "Homebrew is required: https://brew.sh"
  echo "Tip: if brew is already installed, check your shell config for an incorrect brew path."
  exit 1
fi
echo "Using Homebrew at: $BREW_BIN"

BREW_PREFIX="$("$BREW_BIN" --prefix)"
export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$PATH"

if "$BREW_BIN" config 2>/dev/null | grep -E 'HOMEBREW_(API_)?DOMAIN|BOTTLE_DOMAIN|github.com' >/dev/null; then
  echo "Homebrew network configuration detected:"
  "$BREW_BIN" config | grep -E 'HOMEBREW_(API_)?DOMAIN|BOTTLE_DOMAIN|github.com' || true
else
  cat <<'TIP'
Tip for users in China mainland:
  If Homebrew downloads are slow or stuck, configure a trusted mirror first.
  Common choices are Tsinghua, USTC, or Tencent mirrors. See their official Homebrew mirror docs.
TIP
fi

echo "Installing macFUSE if needed..."
if [ ! -d "/Library/Filesystems/macfuse.fs" ] && ! pkgutil --pkg-info io.macfuse.pkg.Core >/dev/null 2>&1; then
  "$BREW_BIN" install --cask macfuse
else
  echo "macFUSE is already installed."
fi

echo "Installing NTFS-3G for macOS if needed..."
if ! NTFS3G_BIN="$(find_tool ntfs-3g)"; then
  "$BREW_BIN" tap gromgit/fuse
  "$BREW_BIN" install gromgit/fuse/ntfs-3g-mac
else
  echo "ntfs-3g is already installed at $NTFS3G_BIN."
fi

echo
echo "Dependency check complete."
echo "If macOS asks you to approve macFUSE in System Settings, approve it and restart before mounting NTFS volumes."
