import Darwin
import Foundation

public enum MountMode: Equatable {
    case readOnly
    case writable
    case forcedWritable

    public var displayName: String {
        switch self {
        case .readOnly:
            return "只读打开"
        case .writable:
            return "挂载为可写"
        case .forcedWritable:
            return "强制修复并挂载"
        }
    }

    fileprivate var probeArgument: String {
        switch self {
        case .readOnly:
            return "--readonly"
        case .writable, .forcedWritable:
            return "--readwrite"
        }
    }
}

public enum VolumeHealthState: Equatable {
    case notChecked
    case healthy
    case windowsHibernated
    case needsWindowsRepair
    case permissionDenied
    case bitLocker
    case missingDependency
    case unsupported
    case unknown
}

public struct VolumeHealthStatus: Equatable {
    public let state: VolumeHealthState
    public let title: String
    public let message: String
    public let rawOutput: String?

    public init(state: VolumeHealthState, title: String, message: String, rawOutput: String?) {
        self.state = state
        self.title = title
        self.message = message
        self.rawOutput = rawOutput
    }

    public static let notChecked = VolumeHealthStatus(
        state: .notChecked,
        title: "尚未检查磁盘状态",
        message: "点击“检查状态”可以让 NTFS Writer for Mac 用 ntfs-3g 预检查这块盘是否适合可写挂载。",
        rawOutput: nil
    )

    public static func missingDependency(_ items: [String]) -> VolumeHealthStatus {
        VolumeHealthStatus(
            state: .missingDependency,
            title: "缺少读写组件",
            message: "需要先安装 \(items.joined(separator: "、"))，然后再检查或挂载 NTFS 分区。",
            rawOutput: nil
        )
    }

    public static func fromProbeResult(_ result: CommandResult, mode: MountMode) -> VolumeHealthStatus {
        if result.exitCode == 0 {
            return VolumeHealthStatus(
                state: .healthy,
                title: mode == .readOnly ? "可以只读打开" : "可以尝试可写挂载",
                message: mode == .readOnly
                    ? "ntfs-3g 没有发现阻止只读挂载的问题。"
                    : "ntfs-3g 没有发现明显的休眠或脏盘标记。挂载后 NTFS Writer for Mac 还会做一次真实写入测试。",
                rawOutput: cleanedOutput(result.combinedOutput)
            )
        }

        return fromOutput(result.combinedOutput, fallbackTitle: "磁盘状态需要处理")
    }

    public static func fromOutput(_ output: String, fallbackTitle: String = "操作失败") -> VolumeHealthStatus {
        let cleaned = cleanedOutput(output)
        let lowercased = output.lowercased()

        if lowercased.contains("bitlocker") {
            return VolumeHealthStatus(
                state: .bitLocker,
                title: "暂不支持 BitLocker 加密盘",
                message: "这块盘看起来启用了 BitLocker。请先在 Windows 中解锁或关闭 BitLocker，再回到 Mac 使用。",
                rawOutput: cleaned
            )
        }

        if lowercased.contains("hibernat")
            || lowercased.contains("unsafe state")
            || lowercased.contains("fast startup")
            || lowercased.contains("remove_hiberfile")
            || lowercased.contains("hiberfil")
            || lowercased.contains("metadata kept in windows cache") {
            return VolumeHealthStatus(
                state: .windowsHibernated,
                title: "Windows 休眠或快速启动未关闭",
                message: "这块 NTFS 盘还保留着 Windows 休眠/快速启动缓存。只运行 chkdsk /f 不一定会清掉这个状态；请在 Windows 管理员终端运行 powercfg /h off，再执行 shutdown /s /t 0 完全关机并重新插盘。如果只想在 Mac 继续处理，可以使用“强制修复并挂载”，它会尝试删除休眠文件，可能丢失 Windows 未保存状态。",
                rawOutput: cleaned
            )
        }

        if lowercased.contains("dirty")
            || lowercased.contains("chkdsk")
            || lowercased.contains("unclean") {
            return VolumeHealthStatus(
                state: .needsWindowsRepair,
                title: "磁盘需要 Windows 修复",
                message: "NTFS 元数据标记为未干净关闭。建议在 Windows 管理员终端运行 chkdsk /f；如果你已经运行过 chkdsk /f，还需要关闭休眠/快速启动：powercfg /h off，然后 shutdown /s /t 0 完全关机。",
                rawOutput: cleaned
            )
        }

        if lowercased.contains("invalid argument") {
            return VolumeHealthStatus(
                state: .needsWindowsRepair,
                title: "写入被 NTFS/FUSE 拒绝",
                message: "底层返回 Invalid argument。它不一定表示磁盘坏；也可能是 ntfs-3g 与当前设备路径或挂载参数不兼容。请先使用最新版重新挂载；如果仍失败，再回 Windows 运行 powercfg /h off、chkdsk /f 和 shutdown /s /t 0 完全关机。",
                rawOutput: cleaned
            )
        }

        if lowercased.contains("operation not permitted")
            || lowercased.contains("permission denied")
            || lowercased.contains("not permitted") {
            return VolumeHealthStatus(
                state: .permissionDenied,
                title: "macOS 拒绝访问磁盘",
                message: "请确认已在“系统设置 > 隐私与安全性”允许 macFUSE 扩展，必要时重启 Mac；如果仍失败，把 NTFS Writer for Mac 加入“完全磁盘访问权限”后再试。",
                rawOutput: cleaned
            )
        }

        if lowercased.contains("not an ntfs")
            || lowercased.contains("unknown filesystem")
            || lowercased.contains("unsupported") {
            return VolumeHealthStatus(
                state: .unsupported,
                title: "暂不支持这个分区",
                message: "ntfs-3g 没能把这个分区识别为可处理的 NTFS 卷。请确认它不是加密盘、损坏盘或非 NTFS 分区。",
                rawOutput: cleaned
            )
        }

        return VolumeHealthStatus(
            state: .unknown,
            title: fallbackTitle,
            message: cleaned ?? "ntfs-3g 没有返回可识别的诊断信息。可以先尝试只读打开；写入前建议确认 Windows 已完全关机并正常弹出硬盘。",
            rawOutput: cleaned
        )
    }

    private static func cleanedOutput(_ output: String) -> String? {
        let cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}

public struct MountResult: Equatable {
    public let mountPoint: String
    public let mode: MountMode
    public let writeTestSucceeded: Bool?
    public let warning: String?
}

public enum MountError: LocalizedError {
    case dependencyMissing([String])
    case toolMissing(String)
    case mountFailed(CommandResult, MountMode)
    case invalidMountPoint

    public var errorDescription: String? {
        switch self {
        case .dependencyMissing(let items):
            return "缺少依赖：\(items.joined(separator: "、"))"
        case .toolMissing(let name):
            return "缺少工具：\(name)。请重新安装 ntfs-3g 后再试。"
        case .mountFailed(let result, _):
            let output = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            let health = VolumeHealthStatus.fromOutput(output, fallbackTitle: "挂载失败")
            if health.state != .unknown {
                if let rawOutput = health.rawOutput {
                    return "\(health.title)\n\n\(health.message)\n\n原始信息：\n\(rawOutput)"
                }
                return "\(health.title)\n\n\(health.message)"
            }
            return output.isEmpty ? "挂载失败，退出码：\(result.exitCode)" : output
        case .invalidMountPoint:
            return "挂载目录无效。"
        }
    }
}

public final class MountService {
    private let runner: CommandRunning
    private let dependencyChecker: DependencyChecker
    private let fileManager: FileManager
    private let mountRoot: String

    public init(
        runner: CommandRunning = Shell(),
        dependencyChecker: DependencyChecker? = nil,
        fileManager: FileManager = .default,
        mountRoot: String = "/Volumes/MacNTFSWriter"
    ) {
        self.runner = runner
        self.dependencyChecker = dependencyChecker ?? DependencyChecker(runner: runner)
        self.fileManager = fileManager
        self.mountRoot = mountRoot
    }

    public func checkHealth(_ volume: NTFSVolume, mode: MountMode = .writable) async -> VolumeHealthStatus {
        let dependencies = await dependencyChecker.check()
        guard dependencies.isReady, let ntfs3gPath = dependencies.ntfs3gPath else {
            return .missingDependency(dependencies.missingItems)
        }

        let deviceNode = mountDeviceNode(for: volume.deviceNode)
        if let ntfsfixPath = findTool(named: "ntfsfix", near: ntfs3gPath) {
            let shellScript = "\(ntfsfixPath.shellQuoted) -n \(deviceNode.shellQuoted)"
            if let result = try? await runPrivilegedShellScript(shellScript) {
                if result.exitCode == 0 {
                    return VolumeHealthStatus(
                        state: .healthy,
                        title: "基础检查通过",
                        message: "ntfsfix 只读检查没有发现需要立即修复的问题。可以尝试挂载，NTFS Writer for Mac 会在挂载后做真实写入测试。",
                        rawOutput: result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }

                return VolumeHealthStatus.fromOutput(result.combinedOutput, fallbackTitle: "磁盘状态需要处理")
            }
        }

        guard let probePath = findTool(named: "ntfs-3g.probe", near: ntfs3gPath) else {
            return .missingDependency(["ntfs-3g.probe"])
        }

        let shellScript = "\(probePath.shellQuoted) \(mode.probeArgument) \(deviceNode.shellQuoted)"
        do {
            let result = try await runPrivilegedShellScript(shellScript)
            return VolumeHealthStatus.fromProbeResult(result, mode: mode)
        } catch {
            return VolumeHealthStatus(
                state: .unknown,
                title: "检查状态失败",
                message: error.localizedDescription,
                rawOutput: nil
            )
        }
    }

    public func mountReadOnly(_ volume: NTFSVolume) async throws -> MountResult {
        try await mount(volume, mode: .readOnly, repairBeforeMount: false)
    }

    public func mountWritable(_ volume: NTFSVolume) async throws -> MountResult {
        try await mount(volume, mode: .writable, repairBeforeMount: false)
    }

    public func repairAndMountForcedWritable(_ volume: NTFSVolume) async throws -> MountResult {
        try await mount(volume, mode: .forcedWritable, repairBeforeMount: true)
    }

    private func mount(_ volume: NTFSVolume, mode: MountMode, repairBeforeMount: Bool) async throws -> MountResult {
        let dependencies = await dependencyChecker.check()
        guard dependencies.isReady, let ntfs3gPath = dependencies.ntfs3gPath else {
            throw MountError.dependencyMissing(dependencies.missingItems)
        }

        let ntfsfixPath: String?
        if repairBeforeMount {
            guard let foundPath = findTool(named: "ntfsfix", near: ntfs3gPath) else {
                throw MountError.toolMissing("ntfsfix")
            }
            ntfsfixPath = foundPath
        } else {
            ntfsfixPath = nil
        }

        let mountPoint = makeMountPoint(for: volume)
        guard mountPoint.hasPrefix("/Volumes/") else { throw MountError.invalidMountPoint }
        if await isMounted(at: mountPoint) {
            return await resultForMountedVolume(at: mountPoint, mode: mode)
        }

        let deviceNode = mountDeviceNode(for: volume.deviceNode)
        var commands = [
            "/bin/mkdir -p \(mountPoint.shellQuoted)",
            "(/usr/sbin/diskutil unmount \(volume.deviceNode.shellQuoted) >/dev/null 2>&1 || true)"
        ]

        if repairBeforeMount, let ntfsfixPath {
            commands.append("\(ntfsfixPath.shellQuoted) -d \(deviceNode.shellQuoted)")
        }

        let optionsArgument = "-o" + mountOptions(for: volume, mode: mode).joined(separator: ",")
        commands.append("\(ntfs3gPath.shellQuoted) \(deviceNode.shellQuoted) \(mountPoint.shellQuoted) \(optionsArgument.shellQuoted)")

        let result = try await runPrivilegedShellScript(commands.joined(separator: " && "))
        guard result.exitCode == 0 else { throw MountError.mountFailed(result, mode) }
        return await resultForMountedVolume(at: mountPoint, mode: mode)
    }

    public func unmount(_ mountPoint: String) async throws {
        guard mountPoint.hasPrefix("/Volumes/") else { throw MountError.invalidMountPoint }
        let shellScript = "/usr/sbin/diskutil unmount \(mountPoint.shellQuoted)"
        let result = try await runPrivilegedShellScript(shellScript)
        guard result.exitCode == 0 else { throw MountError.mountFailed(result, .writable) }
    }

    public func openInFinder(_ path: String) async throws {
        _ = try await runner.run("/usr/bin/open", arguments: [path])
    }

    private func resultForMountedVolume(at mountPoint: String, mode: MountMode) async -> MountResult {
        guard mode != .readOnly else {
            return MountResult(mountPoint: mountPoint, mode: mode, writeTestSucceeded: nil, warning: nil)
        }

        let verification = await verifyWritable(at: mountPoint)
        if verification.exitCode == 0 {
            return MountResult(mountPoint: mountPoint, mode: mode, writeTestSucceeded: true, warning: nil)
        }

        let health = VolumeHealthStatus.fromOutput(verification.combinedOutput, fallbackTitle: "写入测试失败")
        let raw = verification.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawSuffix = raw.isEmpty ? "" : "\n\n原始信息：\n\(raw)"
        return MountResult(
            mountPoint: mountPoint,
            mode: mode,
            writeTestSucceeded: false,
            warning: "\(health.title)\n\n已挂载到 \(mountPoint)，但真实写入测试没有通过。\(health.message)\(rawSuffix)"
        )
    }

    private func runPrivilegedShellScript(_ shellScript: String) async throws -> CommandResult {
        let appleScript = "do shell script \"\(shellScript.appleScriptStringEscaped)\" with administrator privileges"
        return try await runner.run("/usr/bin/osascript", arguments: ["-e", appleScript])
    }

    private func verifyWritable(at mountPoint: String) async -> CommandResult {
        let testPath = "\(mountPoint)/.macntfswriter-write-test-\(UUID().uuidString)"
        let shellScript = "printf %s macntfswriter > \(testPath.shellQuoted) && /bin/rm -f \(testPath.shellQuoted)"
        do {
            return try await runner.run("/bin/sh", arguments: ["-c", shellScript])
        } catch {
            return CommandResult(exitCode: 127, stdout: "", stderr: error.localizedDescription)
        }
    }

    private func isMounted(at mountPoint: String) async -> Bool {
        let result = try? await runner.run("/sbin/mount", arguments: [])
        guard result?.exitCode == 0 else { return false }
        return result?.stdout
            .split(separator: "\n")
            .contains { line in
                line.contains(" on \(mountPoint) ") || line.contains(" on \(mountPoint) (")
            } == true
    }

    private func makeMountPoint(for volume: NTFSVolume) -> String {
        let safeName = sanitizePathComponent(volume.displayName)
        return "\(mountRoot)/\(safeName)-\(volume.deviceIdentifier)"
    }

    private func mountOptions(for volume: NTFSVolume, mode: MountMode) -> [String] {
        var options: [String]
        switch mode {
        case .readOnly:
            options = ["ro", "local", "allow_other", "streams_interface=none"]
        case .writable:
            options = writableMountOptions()
        case .forcedWritable:
            options = writableMountOptions() + ["recover", "remove_hiberfile"]
        }

        options.append("volname=\(sanitizeVolumeName(volume.displayName))")
        return options
    }

    private func writableMountOptions() -> [String] {
        [
            "local",
            "allow_other",
            "uid=\(getuid())",
            "gid=\(getgid())",
            "umask=000",
            "streams_interface=none"
        ]
    }

    private func mountDeviceNode(for deviceNode: String) -> String {
        // ntfs-3g-mac is more reliable with the block device on current macFUSE builds.
        // Using /dev/rdisk... can make valid NTFS volumes fail with Invalid argument.
        deviceNode
    }

    private func findTool(named name: String, near ntfs3gPath: String) -> String? {
        let siblingDirectory = URL(fileURLWithPath: ntfs3gPath).deletingLastPathComponent().path
        let candidates = [
            "\(siblingDirectory)/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/opt/homebrew/sbin/\(name)",
            "/usr/local/sbin/\(name)"
        ]

        return candidates.first { fileManager.isExecutableFile(atPath: $0) }
    }

    private func sanitizePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._- "))
        let result = value.unicodeScalars
            .map { allowed.contains($0) ? String($0) : "-" }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? "NTFS" : result
    }

    private func sanitizeVolumeName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = trimmed
            .replacingOccurrences(of: ",", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return sanitized.isEmpty ? "NTFS" : String(sanitized.prefix(64))
    }
}
