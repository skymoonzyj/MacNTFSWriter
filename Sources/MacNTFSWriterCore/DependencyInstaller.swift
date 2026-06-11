import Foundation

public enum DependencyInstallError: LocalizedError {
    case scriptNotFound(String)
    case failed(CommandResult)

    public var errorDescription: String? {
        switch self {
        case .scriptNotFound(let path):
            return "找不到安装脚本：\(path)"
        case .failed(let result):
            let output = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            return output.isEmpty ? "安装失败，退出码：\(result.exitCode)" : output
        }
    }
}

public final class DependencyInstaller {
    private let runner: CommandRunning
    private let fileManager: FileManager

    public init(runner: CommandRunning = Shell(), fileManager: FileManager = .default) {
        self.runner = runner
        self.fileManager = fileManager
    }

    public func install(usingScriptAt scriptPath: String) async throws -> CommandResult {
        guard fileManager.fileExists(atPath: scriptPath) else {
            throw DependencyInstallError.scriptNotFound(scriptPath)
        }

        let result = try await runner.run("/bin/bash", arguments: [scriptPath])
        guard result.exitCode == 0 else {
            throw DependencyInstallError.failed(result)
        }
        return result
    }

    public func startInteractiveInstall(usingScriptAt scriptPath: String) async throws -> CommandResult {
        guard fileManager.fileExists(atPath: scriptPath) else {
            throw DependencyInstallError.scriptNotFound(scriptPath)
        }

        let commandURL = fileManager.temporaryDirectory
            .appendingPathComponent("MacNTFSWriter-Install-\(UUID().uuidString)")
            .appendingPathExtension("command")

        let command = """
        #!/bin/bash
        clear
        echo "NTFS Writer for Mac 正在安装读写组件..."
        echo
        /bin/bash \(scriptPath.shellQuoted)
        status=$?
        echo
        if [ "$status" -eq 0 ]; then
          echo "安装流程已完成。请回到 NTFS Writer for Mac 点击刷新。"
        else
          echo "安装失败，退出码：$status"
        fi
        echo
        read -r -n 1 -p "按任意键关闭窗口..."
        exit "$status"
        """

        try command.write(to: commandURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: commandURL.path)

        let result = try await runner.run("/usr/bin/open", arguments: [commandURL.path])
        guard result.exitCode == 0 else {
            throw DependencyInstallError.failed(result)
        }
        return result
    }
}
