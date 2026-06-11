@testable import MacNTFSWriterCore
import XCTest

final class DependencyStatusTests: XCTestCase {
    func testSummaryMentionsHomebrewWhenMissing() {
        let status = DependencyStatus(macFUSEInstalled: false, ntfs3gPath: nil, brewPath: nil)

        XCTAssertEqual(status.summaryTitle, "需要安装依赖")
        XCTAssertTrue(status.summaryText.contains("Homebrew"))
        XCTAssertTrue(status.summaryText.contains("install-deps-macos.sh"))
    }

    func testSummaryMentionsApprovalWhenMacFUSEMissing() {
        let status = DependencyStatus(
            macFUSEInstalled: false,
            ntfs3gPath: "/usr/local/bin/ntfs-3g",
            brewPath: "/usr/local/bin/brew"
        )

        XCTAssertTrue(status.summaryText.contains("允许扩展"))
        XCTAssertTrue(status.summaryText.contains("重启"))
    }
}
