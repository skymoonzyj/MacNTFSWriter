#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"
APP_NAME="${APP_NAME:-MacNTFSWriter}"
RELEASE_DIR="dist/release-$VERSION"

export VERSION
export APP_NAME

./scripts/package-dmg-macos.sh
./scripts/package-pkg-macos.sh

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

cp "dist/$APP_NAME.dmg" "$RELEASE_DIR/$APP_NAME-$VERSION.dmg"
cp "dist/$APP_NAME.pkg" "$RELEASE_DIR/$APP_NAME-$VERSION.pkg"
cp "README.md" "$RELEASE_DIR/README.md"
cp "THIRD_PARTY_NOTICES.md" "$RELEASE_DIR/THIRD_PARTY_NOTICES.md"

(
  cd "$RELEASE_DIR"
  shasum -a 256 "$APP_NAME-$VERSION.dmg" "$APP_NAME-$VERSION.pkg" > "SHA256SUMS.txt"
)

cat > "$RELEASE_DIR/RELEASE_NOTES.md" <<NOTES
# NTFS Writer for Mac $VERSION

推荐下载 \`$APP_NAME-$VERSION.pkg\`，双击安装到 Applications。

也可以下载 \`$APP_NAME-$VERSION.dmg\`，打开后把 NTFS Writer for Mac 拖到 Applications。

首次使用如果提示缺少读写组件，请在应用内点击“打开安装窗口”。安装过程中 macOS 可能要求用户在“系统设置 > 隐私与安全性”允许 NTFS 读写组件，并可能需要重启，这是正常流程。

## 注意

- Windows 休眠、快速启动或未正常弹出的 NTFS 盘，建议先回 Windows 完全关机并运行 chkdsk /f。
- “强制修复并挂载”会尝试移除 Windows 休眠文件，只应在确认不需要保留 Windows 休眠状态时使用。
- 这是免费未签名版本。macOS 如果提示“无法验证开发者”，请右键点击 App/PKG 选择“打开”，或到“系统设置 > 隐私与安全性”选择“仍要打开”。
- 如果 macOS 提示需要允许系统软件，请到“系统设置 > 隐私与安全性”手动允许，必要时重启。
NOTES

echo "Prepared $RELEASE_DIR"
echo "Upload these files to GitHub Release:"
find "$RELEASE_DIR" -maxdepth 1 -type f -print
