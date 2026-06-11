# NTFS Writer for Mac

NTFS Writer for Mac 是一个 macOS 桌面原型，用来发现 NTFS 分区，并通过 macFUSE + NTFS-3G 把它们挂载为可写卷。

它不是从零实现的 NTFS 文件系统驱动。真正的 NTFS 读写由成熟的 `ntfs-3g` 完成，NTFS Writer for Mac 负责用户界面、磁盘识别、依赖检查、管理员授权、挂载、卸载和安全提示。

目标体验是：用户从 GitHub 下载 App 后可以直接打开；如果本机缺少读写组件，App 会打开安装窗口引导安装。macFUSE 属于 macOS 系统扩展，系统要求用户手动允许并可能重启，这一步不能被任何普通 App 静默绕过。

## 功能

- 扫描本机外接或内置 NTFS 分区
- 显示容量、设备路径、当前挂载点和读写状态
- 检查 `Homebrew`、`macFUSE` 与 `ntfs-3g`
- 检查 macFUSE 是否已加载
- 在应用内打开读写组件安装窗口
- 检查 NTFS 磁盘健康状态，识别 Windows 休眠、快速启动、脏盘、权限拒绝等常见问题
- 支持“只读打开”、“挂载为可写”、“强制修复并挂载”
- 可写挂载后自动做真实写入测试
- 一键安全卸载
- 挂载后自动在 Finder 打开

## 系统要求

- macOS 13 或更新版本
- Xcode Command Line Tools
- Homebrew
- macFUSE
- NTFS-3G for macOS

macOS 自带 NTFS 读取能力，但完整、稳定的写入能力需要第三方文件系统层。本项目默认使用 macFUSE 与 NTFS-3G。

## 普通用户使用

从 GitHub Release 下载 `MacNTFSWriter.pkg`，双击安装后打开 NTFS Writer for Mac 即可扫描 NTFS 分区。

也可以下载 `MacNTFSWriter.dmg`，打开后把 `MacNTFSWriter.app` 拖到 Applications。

如果首次启动时提示缺少读写组件：

1. 点击应用里的“打开安装窗口”。
2. 按窗口提示安装 `macFUSE` 与 `ntfs-3g`。
3. 如果 macOS 提示允许 macFUSE 扩展，请到“系统设置”中允许，并按提示重启 Mac。
4. 回到 NTFS Writer for Mac 点击“刷新”，环境就绪后即可挂载为可写。

如果提示缺少 Homebrew，请先安装 Homebrew，再回到应用刷新。

首次扫描外接硬盘时，如果 macOS 提示“MacNTFSWriter 想访问可移除宗卷上的文件”，请选择“允许”。这是 macOS 隐私权限，不代表安装失败。

如果磁盘提示 Windows 休眠、快速启动或需要 chkdsk：

1. 最安全的做法是在 Windows 中关闭“快速启动”，运行 `chkdsk /f`，然后完全关机并正常弹出硬盘。
2. 只想先拷出文件时，可以点击“只读打开”。
3. 只有确认不需要保留 Windows 休眠状态时，才使用“强制修复并挂载”。它会尝试运行 `ntfsfix` 并使用 `remove_hiberfile`。

## 在 Mac 上运行

```bash
cd MacNTFSWriter
chmod +x scripts/*.sh
./scripts/install-deps-macos.sh
./scripts/run-macos.sh
```

如果 macFUSE 安装后提示需要在“系统设置”里批准扩展，请按系统提示批准，必要时重启一次。

## 打包成 app

```bash
cd MacNTFSWriter
./scripts/package-app-macos.sh
open dist/MacNTFSWriter.app
```

当前打包脚本生成的是本地开发版 `.app`，并会把 `scripts/install-deps-macos.sh` 放进 app 的 Resources 目录。

## 打包 GitHub Release

```bash
cd MacNTFSWriter
./scripts/prepare-github-release.sh 0.1.0
```

产物会放在 `dist/release-0.1.0/`：

- `MacNTFSWriter-0.1.0.dmg`
- `MacNTFSWriter-0.1.0.pkg`
- `SHA256SUMS.txt`
- `RELEASE_NOTES.md`
- `README.md`
- `THIRD_PARTY_NOTICES.md`

本项目是免费工具，默认不使用付费 Apple Developer ID 签名/公证。GitHub 下载版可能会被 macOS Gatekeeper 提示“无法验证开发者”。这是未签名免费软件的常见情况，不代表软件损坏。

如果 macOS 阻止打开：

1. 在 Finder 中右键点击 `MacNTFSWriter.app` 或 `MacNTFSWriter.pkg`。
2. 选择“打开”。
3. 在弹窗里再次选择“打开”。
4. 如果仍被阻止，进入“系统设置 > 隐私与安全性”，在安全提示处选择“仍要打开”。

将来如果项目有经费，可以再加入 Apple Developer ID、Developer ID Installer、Hardened Runtime 和 notarization。

也可以推送 tag 让 GitHub Actions 自动打包发布：

```bash
git tag v0.1.0
git push origin v0.1.0
```

第一次上传 GitHub 的命令见 `docs/GITHUB_UPLOAD.md`。签名、公证和发布检查清单见 `docs/RELEASE.md`。

## 测试

```bash
cd MacNTFSWriter
swift test
```

当前测试覆盖磁盘信息解析、shell 转义、依赖状态提示和依赖安装入口。真实挂载需要一台 Mac 和 NTFS 硬盘做人工验证。

## 已知限制

- BitLocker 加密盘不在当前范围内。
- Windows 休眠、快速启动或未正常弹出的 NTFS 盘可能会被 NTFS-3G 拒绝写入。
- “强制修复并挂载”可能删除 Windows 休眠文件，不应替代备份和 Windows 原生修复。
- 当前版本通过 AppleScript 请求管理员权限，适合原型；正式产品建议改成 macOS privileged helper。
- 当前可以引导安装依赖，但不能自动批准 macFUSE 系统扩展；这一步必须由用户在系统设置中确认。
- 未做签名、公证、自动更新、崩溃上报。

## 资料来源

- [macFUSE](https://macfuse.github.io/)
- [macFUSE GitHub Releases](https://github.com/macfuse/macfuse/releases)
- [Apple FSKit](https://developer.apple.com/documentation/fskit)
- [NTFS-3G](https://github.com/tuxera/ntfs-3g)
- [gromgit/homebrew-fuse ntfs-3g-mac](https://github.com/gromgit/homebrew-fuse/blob/main/Formula/ntfs-3g-mac.rb)
