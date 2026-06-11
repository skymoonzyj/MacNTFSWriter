import Foundation

public struct CommandResult: Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public var combinedOutput: String {
        [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

public protocol CommandRunning {
    func run(_ executable: String, arguments: [String]) async throws -> CommandResult
}

public enum CommandError: LocalizedError {
    case failedToStart(String)
    case failed(CommandResult)

    public var errorDescription: String? {
        switch self {
        case .failedToStart(let command):
            return "无法启动命令：\(command)"
        case .failed(let result):
            let output = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if output.isEmpty {
                return "命令执行失败，退出码：\(result.exitCode)"
            }
            return output
        }
    }
}

public final class Shell: CommandRunning {
    public init() {}

    public func run(_ executable: String, arguments: [String]) async throws -> CommandResult {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            do {
                try process.run()
            } catch {
                throw CommandError.failedToStart(([executable] + arguments).joined(separator: " "))
            }

            process.waitUntilExit()

            let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()

            return CommandResult(
                exitCode: process.terminationStatus,
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? ""
            )
        }.value
    }
}
