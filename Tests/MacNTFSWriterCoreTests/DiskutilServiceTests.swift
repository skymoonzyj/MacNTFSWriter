@testable import MacNTFSWriterCore
import XCTest

final class DiskutilServiceTests: XCTestCase {
    func testCollectsDiskAndPartitionIdentifiersInOrder() {
        let plist: [String: Any] = [
            "AllDisksAndPartitions": [
                [
                    "DeviceIdentifier": "disk4",
                    "Partitions": [
                        ["DeviceIdentifier": "disk4s1"],
                        ["DeviceIdentifier": "disk4s2"]
                    ]
                ]
            ],
            "AllDisks": ["disk4", "disk5"]
        ]

        XCTAssertEqual(
            DiskutilService.deviceIdentifiers(fromListPlist: plist),
            ["disk4", "disk4s1", "disk4s2", "disk5"]
        )
    }

    func testRecognizesNTFSFromFilesystemName() {
        let info: [String: Any] = [
            "DeviceIdentifier": "disk4s1",
            "DeviceNode": "/dev/disk4s1",
            "VolumeName": "WORK",
            "FilesystemName": "Windows NT File System (NTFS)",
            "TotalSize": NSNumber(value: 1_000_000_000),
            "Mounted": false
        ]

        XCTAssertTrue(DiskutilService.isNTFS(info))
        let volume = DiskutilService.volume(fromInfoPlist: info)
        XCTAssertEqual(volume?.displayName, "WORK")
        XCTAssertEqual(volume?.totalSize, 1_000_000_000)
    }

    func testRejectsNonNTFSVolume() {
        let info: [String: Any] = [
            "DeviceIdentifier": "disk2s1",
            "FilesystemName": "ExFAT"
        ]

        XCTAssertFalse(DiskutilService.isNTFS(info))
    }

    func testEmptyMountPointDoesNotCountAsMounted() {
        let info: [String: Any] = [
            "DeviceIdentifier": "disk4s2",
            "DeviceNode": "/dev/disk4s2",
            "VolumeName": "WORK",
            "FilesystemName": "NTFS",
            "MountPoint": ""
        ]

        let volume = DiskutilService.volume(fromInfoPlist: info)

        XCTAssertEqual(volume?.mountPoint, nil)
        XCTAssertEqual(volume?.isMounted, false)
    }

    func testParsesMacFUSEMountLine() throws {
        let mount = try XCTUnwrap(DiskutilService.mountedVolumeInfo(
            fromMountLine: "/dev/rdisk4s2 on /Volumes/MacNTFSWriter/WORK-disk4s2 (macfuse, local, synchronous)"
        ))

        XCTAssertEqual(mount.deviceIdentifier, "disk4s2")
        XCTAssertEqual(mount.mountPoint, "/Volumes/MacNTFSWriter/WORK-disk4s2")
        XCTAssertFalse(mount.isReadOnly)
    }

    func testMergesMacFUSEMountWhenDiskutilMountPointIsEmpty() {
        let info: [String: Any] = [
            "DeviceIdentifier": "disk4s2",
            "DeviceNode": "/dev/disk4s2",
            "VolumeName": "WORK",
            "FilesystemName": "NTFS",
            "MountPoint": "",
            "Mounted": false,
            "WritableVolume": false
        ]
        let mounts = [
            "disk4s2": MountedVolumeInfo(
                deviceIdentifier: "disk4s2",
                mountPoint: "/Volumes/MacNTFSWriter/WORK-disk4s2",
                isReadOnly: false
            )
        ]

        let volume = DiskutilService.volume(fromInfoPlist: info, currentMounts: mounts)

        XCTAssertEqual(volume?.mountPoint, "/Volumes/MacNTFSWriter/WORK-disk4s2")
        XCTAssertEqual(volume?.isMounted, true)
        XCTAssertEqual(volume?.isWritable, nil)
    }
}
