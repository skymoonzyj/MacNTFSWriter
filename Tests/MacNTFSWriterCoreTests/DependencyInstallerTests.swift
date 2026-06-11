@testable import MacNTFSWriterCore
import XCTest

final class DependencyInstallerTests: XCTestCase {
    func testRunsInstallScriptWithBash() async throws {
        let scriptURL = try makeTemporaryScript()
        let runner = RecordingRunner(result: CommandResult(exitCode: 0, stdout: "ok", stderr: ""))
        let installer = DependencyInstaller(runner: runner)

        let result = try await installer.install(usingScriptAt: scriptURL.path)

        XCTAssertEqual(result.stdout, "ok")
        XCTAssertEqual(runner.executable, "/bin/bash")
        XCTAssertEqual(runner.arguments, [scriptURL.path])
    }

    func testThrowsInstallOutputWhenScriptFails() async throws {
        let scriptURL = try makeTemporaryScript()
        let runner = RecordingRunner(result: CommandResult(exitCode: 1, stdout: "", stderr: "missing brew"))
        let installer = DependencyInstaller(runner: runner)

        do {
            _ = try await installer.install(usingScriptAt: scriptURL.path)
            XCTFail("Expected install failure")
        } catch {
            XCTAssertEqual(error.localizedDescription, "missing brew")
        }
    }

    func testStartsInteractiveInstallInTerminal() async throws {
        let scriptURL = try makeTemporaryScript()
        let runner = RecordingRunner(result: CommandResult(exitCode: 0, stdout: "", stderr: ""))
        let installer = DependencyInstaller(runner: runner)

        _ = try await installer.startInteractiveInstall(usingScriptAt: scriptURL.path)

        XCTAssertEqual(runner.executable, "/usr/bin/open")
        let commandPath = try XCTUnwrap(runner.arguments?.last)
        XCTAssertTrue(commandPath.hasSuffix(".command"))
        let command = try String(contentsOfFile: commandPath)
        XCTAssertTrue(command.contains(scriptURL.path))
        XCTAssertTrue(command.contains("NTFS Writer for Mac 正在安装读写组件"))
    }

    private func makeTemporaryScript() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sh")
        try "#!/usr/bin/env bash\n".write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

private final class RecordingRunner: CommandRunning {
    private(set) var executable: String?
    private(set) var arguments: [String]?
    let result: CommandResult

    init(result: CommandResult) {
        self.result = result
    }

    func run(_ executable: String, arguments: [String]) async throws -> CommandResult {
        self.executable = executable
        self.arguments = arguments
        return result
    }
}
