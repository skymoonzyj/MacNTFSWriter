@testable import MacNTFSWriterCore
import XCTest

final class VolumeHealthStatusTests: XCTestCase {
    func testDetectsWindowsHibernation() {
        let status = VolumeHealthStatus.fromOutput("The NTFS partition is hibernated. Please resume Windows and turn it off properly.")

        XCTAssertEqual(status.state, .windowsHibernated)
        XCTAssertTrue(status.message.contains("快速启动"))
    }

    func testDetectsDirtyVolume() {
        let status = VolumeHealthStatus.fromOutput("Metadata kept in Windows cache, refused to mount. Please run chkdsk /f.")

        XCTAssertEqual(status.state, .windowsHibernated)
        XCTAssertTrue(status.message.contains("快速启动"))
    }

    func testDetectsPermissionDenied() {
        let status = VolumeHealthStatus.fromOutput("Error opening '/dev/rdisk4s2': Permission denied")

        XCTAssertEqual(status.state, .permissionDenied)
        XCTAssertTrue(status.message.contains("macFUSE"))
    }

    func testDetectsInvalidArgumentWriteFailure() {
        let status = VolumeHealthStatus.fromOutput("bash: WRITECHK.TXT: Invalid argument")

        XCTAssertEqual(status.state, .needsWindowsRepair)
        XCTAssertTrue(status.title.contains("写入"))
    }
}
