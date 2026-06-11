import Foundation

public struct DependencyStatus: Equatable {
    public let macFUSEInstalled: Bool
    public let macFUSELoaded: Bool
    public let ntfs3gPath: String?
    public let brewPath: String?

    public init(macFUSEInstalled: Bool, ntfs3gPath: String?, brewPath: String?, macFUSELoaded: Bool = false) {
        self.macFUSEInstalled = macFUSEInstalled
        self.macFUSELoaded = macFUSELoaded
        self.ntfs3gPath = ntfs3gPath
        self.brewPath = brewPath
    }

    public var isReady: Bool {
        macFUSEInstalled && ntfs3gPath != nil
    }

    public var isBrewInstalled: Bool {
        brewPath != nil
    }

    public var missingItems: [String] {
        var items: [String] = []
        if !macFUSEInstalled { items.append("macFUSE") }
        if ntfs3gPath == nil { items.append("ntfs-3g") }
        return items
    }

    public var summaryTitle: String {
        if !isReady { return "需要安装依赖" }
        return macFUSELoaded ? "环境已就绪" : "环境基本就绪"
    }

    public var summaryText: String {
        if isReady {
            if macFUSELoaded {
                return "macFUSE 与 ntfs-3g 已可用，可以尝试只读或可写挂载。"
            }

            return "读写组件已安装。首次挂载时 macOS 可能会要求允许 macFUSE 扩展，按系统提示允许并重启即可。"
        }

        if !isBrewInstalled {
            return "未检测到 Homebrew。请先安装 Homebrew，再运行 scripts/install-deps-macos.sh。"
        }

        let prefix = "缺少 \(missingItems.joined(separator: "、"))。请先运行 scripts/install-deps-macos.sh。"
        if !macFUSEInstalled {
            return "\(prefix) 安装 macFUSE 后，还需要在系统设置中允许扩展，并按提示重启 Mac。"
        }

        return prefix
    }
}

public final class DependencyChecker {
    private let runner: CommandRunning
    private let fileManager: FileManager

    public init(runner: CommandRunning = Shell(), fileManager: FileManager = .default) {
        self.runner = runner
        self.fileManager = fileManager
    }

    public func check() async -> DependencyStatus {
        async let macFUSE = isMacFUSEInstalled()
        async let macFUSELoaded = isMacFUSELoaded()
        async let ntfs3g = findExecutable(named: "ntfs-3g")
        async let brew = findExecutable(named: "brew")

        return DependencyStatus(
            macFUSEInstalled: await macFUSE,
            ntfs3gPath: await ntfs3g,
            brewPath: await brew,
            macFUSELoaded: await macFUSELoaded
        )
    }

    private func isMacFUSEInstalled() async -> Bool {
        if fileManager.fileExists(atPath: "/Library/Filesystems/macfuse.fs") {
            return true
        }

        let result = try? await runner.run("/usr/sbin/pkgutil", arguments: ["--pkg-info", "io.macfuse.pkg.Core"])
        return result?.exitCode == 0
    }

    private func isMacFUSELoaded() async -> Bool {
        let kmutil = try? await runner.run("/usr/bin/kmutil", arguments: ["showloaded"])
        if kmutil?.combinedOutput.localizedCaseInsensitiveContains("macfuse") == true {
            return true
        }

        let kextstat = try? await runner.run("/usr/sbin/kextstat", arguments: [])
        return kextstat?.combinedOutput.localizedCaseInsensitiveContains("macfuse") == true
    }

    private func findExecutable(named name: String) async -> String? {
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/opt/homebrew/sbin/\(name)",
            "/usr/local/sbin/\(name)",
            "/opt/local/bin/\(name)"
        ]

        if let path = candidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) {
            return path
        }

        let result = try? await runner.run("/usr/bin/which", arguments: [name])
        guard result?.exitCode == 0 else { return nil }
        let path = result?.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return path?.isEmpty == false ? path : nil
    }
}
