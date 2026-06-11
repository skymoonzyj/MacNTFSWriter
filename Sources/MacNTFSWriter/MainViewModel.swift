import Foundation
import MacNTFSWriterCore

@MainActor
final class MainViewModel: ObservableObject {
    @Published var volumes: [NTFSVolume] = []
    @Published var selectedVolumeID: NTFSVolume.ID? {
        didSet {
            guard oldValue != selectedVolumeID else { return }
            volumeHealthStatus = .notChecked
            lastError = nil
            lastWarning = nil
        }
    }
    @Published var dependencies = DependencyStatus(macFUSEInstalled: false, ntfs3gPath: nil, brewPath: nil)
    @Published var volumeHealthStatus = VolumeHealthStatus.notChecked
    @Published var statusText = "正在检查环境..."
    @Published var isBusy = false
    @Published var lastError: String?
    @Published var lastWarning: String?
    @Published var installLog: String?
    @Published var operationLog: [String] = []

    private let diskutilService: DiskutilService
    private let dependencyChecker: DependencyChecker
    private let dependencyInstaller: DependencyInstaller
    private let mountService: MountService

    init(
        diskutilService: DiskutilService = DiskutilService(),
        dependencyChecker: DependencyChecker = DependencyChecker(),
        dependencyInstaller: DependencyInstaller = DependencyInstaller(),
        mountService: MountService = MountService()
    ) {
        self.diskutilService = diskutilService
        self.dependencyChecker = dependencyChecker
        self.dependencyInstaller = dependencyInstaller
        self.mountService = mountService
    }

    var selectedVolume: NTFSVolume? {
        guard let selectedVolumeID else { return volumes.first }
        return volumes.first { $0.id == selectedVolumeID }
    }

    var dependencyActionTitle: String {
        dependencies.isBrewInstalled ? "打开安装窗口" : "安装 Homebrew"
    }

    func start() {
        Task {
            await refreshAll()
        }
    }

    func refreshAll() async {
        isBusy = true
        lastError = nil
        statusText = "正在扫描 NTFS 磁盘..."
        async let dependencyTask = dependencyChecker.check()

        dependencies = await dependencyTask
        do {
            let scannedVolumes = try await diskutilService.scanNTFSVolumes()
            volumes = scannedVolumes
            if selectedVolumeID == nil || !volumes.contains(where: { $0.id == selectedVolumeID }) {
                selectedVolumeID = volumes.first?.id
            }
            statusText = scannedVolumes.isEmpty ? "没有发现 NTFS 分区。" : "已发现 \(scannedVolumes.count) 个 NTFS 分区。"
            appendLog(statusText)
        } catch {
            lastError = error.localizedDescription
            volumes = []
            selectedVolumeID = nil
            statusText = "磁盘扫描失败，但依赖状态已更新。"
            appendLog("扫描失败：\(error.localizedDescription)")
        }

        isBusy = false
    }

    func mountSelectedVolume() {
        mountSelectedVolumeWritable()
    }

    func checkSelectedVolumeHealth() {
        guard let volume = selectedVolume else { return }
        Task {
            isBusy = true
            lastError = nil
            lastWarning = nil
            statusText = "正在请求管理员授权并检查磁盘状态..."
            appendLog("开始检查 \(volume.displayName)")

            let health = await mountService.checkHealth(volume, mode: .writable)
            volumeHealthStatus = health
            statusText = health.title
            if let rawOutput = health.rawOutput {
                appendLog("检查结果：\(health.title)\n\(rawOutput)")
            } else {
                appendLog("检查结果：\(health.title)")
            }

            isBusy = false
        }
    }

    func mountSelectedVolumeReadOnly() {
        mountSelectedVolume(mode: .readOnly)
    }

    func mountSelectedVolumeWritable() {
        mountSelectedVolume(mode: .writable)
    }

    func repairAndMountSelectedVolume() {
        mountSelectedVolume(mode: .forcedWritable)
    }

    private func mountSelectedVolume(mode: MountMode) {
        guard let volume = selectedVolume else { return }
        Task {
            isBusy = true
            lastError = nil
            lastWarning = nil
            statusText = "正在请求管理员授权..."
            appendLog("开始\(mode.displayName)：\(volume.displayName)")
            do {
                let result: MountResult
                switch mode {
                case .readOnly:
                    result = try await mountService.mountReadOnly(volume)
                case .writable:
                    result = try await mountService.mountWritable(volume)
                case .forcedWritable:
                    result = try await mountService.repairAndMountForcedWritable(volume)
                }

                if let warning = result.warning {
                    lastWarning = warning
                    statusText = "已挂载，但写入测试未通过。"
                    volumeHealthStatus = VolumeHealthStatus.fromOutput(warning, fallbackTitle: "写入测试未通过")
                    appendLog("挂载完成但有警告：\(warning)")
                } else {
                    statusText = result.writeTestSucceeded == true
                        ? "已挂载并通过写入测试：\(result.mountPoint)"
                        : "已挂载到 \(result.mountPoint)"
                    volumeHealthStatus = VolumeHealthStatus(
                        state: .healthy,
                        title: result.writeTestSucceeded == true ? "写入测试通过" : "已只读打开",
                        message: result.writeTestSucceeded == true
                            ? "NTFS Writer for Mac 已完成可写挂载，并成功创建/删除测试文件。"
                            : "这块 NTFS 分区已按只读方式打开，不会修改磁盘内容。",
                        rawOutput: nil
                    )
                    appendLog(statusText)
                    try? await mountService.openInFinder(result.mountPoint)
                }
                await refreshAll()
                if result.warning == nil {
                    statusText = result.writeTestSucceeded == true
                        ? "已挂载并通过写入测试：\(result.mountPoint)"
                        : "已挂载到 \(result.mountPoint)"
                }
            } catch {
                lastError = error.localizedDescription
                statusText = "挂载失败。"
                volumeHealthStatus = VolumeHealthStatus.fromOutput(error.localizedDescription, fallbackTitle: "挂载失败")
                appendLog("挂载失败：\(error.localizedDescription)")
            }
            isBusy = false
        }
    }

    func performDependencyAction() {
        if dependencies.isBrewInstalled {
            installDependencies()
        } else {
            openHomebrewWebsite()
        }
    }

    func installDependencies() {
        guard !isBusy else { return }
        Task {
            isBusy = true
            lastError = nil
            lastWarning = nil
            installLog = nil
            statusText = "正在打开安装窗口..."
            appendLog("打开依赖安装窗口")

            do {
                let scriptPath = try installerScriptPath()
                _ = try await dependencyInstaller.startInteractiveInstall(usingScriptAt: scriptPath)
                installLog = "安装窗口已打开。请按窗口提示完成安装；如果 macFUSE 要求允许扩展，请到系统设置中允许并重启 Mac。完成后回到这里点击刷新。"
                statusText = "安装窗口已打开。完成后请刷新。"
                isBusy = false
            } catch {
                lastError = error.localizedDescription
                installLog = error.localizedDescription
                statusText = "安装失败。"
                isBusy = false
            }
        }
    }

    func unmountSelectedVolume() {
        guard let volume = selectedVolume else { return }
        let target = volume.mountPoint ?? volume.deviceNode
        Task {
            isBusy = true
            lastError = nil
            lastWarning = nil
            statusText = "正在卸载..."
            appendLog("开始卸载 \(target)")
            do {
                if let mountPoint = volume.mountPoint, mountPoint.hasPrefix("/Volumes/MacNTFSWriter") {
                    try await mountService.unmount(mountPoint)
                } else {
                    try await diskutilService.unmount(volume)
                }
                statusText = "已卸载 \(target)"
                appendLog(statusText)
                await refreshAll()
            } catch {
                lastError = error.localizedDescription
                statusText = "卸载失败。"
                appendLog("卸载失败：\(error.localizedDescription)")
            }
            isBusy = false
        }
    }

    func openSelectedVolume() {
        guard let mountPoint = selectedVolume?.mountPoint else { return }
        Task {
            try? await mountService.openInFinder(mountPoint)
        }
    }

    private func openHomebrewWebsite() {
        Task {
            statusText = "已打开 Homebrew 安装页面。安装完成后请返回这里刷新。"
            appendLog(statusText)
            try? await mountService.openInFinder("https://brew.sh")
        }
    }

    private func appendLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        operationLog.insert("[\(formatter.string(from: Date()))] \(message)", at: 0)
        if operationLog.count > 12 {
            operationLog.removeLast(operationLog.count - 12)
        }
    }

    private func installerScriptPath() throws -> String {
        if let bundledPath = Bundle.main.path(forResource: "install-deps-macos", ofType: "sh") {
            return bundledPath
        }

        let sourcePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/install-deps-macos.sh")
            .path

        guard FileManager.default.fileExists(atPath: sourcePath) else {
            throw DependencyInstallError.scriptNotFound(sourcePath)
        }

        return sourcePath
    }
}
