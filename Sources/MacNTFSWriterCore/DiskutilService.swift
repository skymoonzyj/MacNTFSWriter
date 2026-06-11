import Foundation

public enum DiskutilError: LocalizedError {
    case diskutilFailed(CommandResult)
    case invalidPlist

    public var errorDescription: String? {
        switch self {
        case .diskutilFailed(let result):
            let output = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            return output.isEmpty ? "diskutil 执行失败。" : output
        case .invalidPlist:
            return "无法读取 macOS 返回的磁盘信息。"
        }
    }
}

public final class DiskutilService {
    private let runner: CommandRunning

    public init(runner: CommandRunning = Shell()) {
        self.runner = runner
    }

    public func scanNTFSVolumes() async throws -> [NTFSVolume] {
        let listResult = try await runner.run("/usr/sbin/diskutil", arguments: ["list", "-plist"])
        guard listResult.exitCode == 0 else { throw DiskutilError.diskutilFailed(listResult) }

        guard
            let plistData = listResult.stdout.data(using: .utf8),
            let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any]
        else {
            throw DiskutilError.invalidPlist
        }

        var volumes: [NTFSVolume] = []
        let currentMounts = await currentMountsByDeviceIdentifier()
        for identifier in Self.deviceIdentifiers(fromListPlist: plist) {
            let infoResult = try await runner.run("/usr/sbin/diskutil", arguments: ["info", "-plist", identifier])
            guard infoResult.exitCode == 0 else { continue }
            guard
                let infoData = infoResult.stdout.data(using: .utf8),
                let info = try? PropertyListSerialization.propertyList(from: infoData, options: [], format: nil) as? [String: Any],
                Self.isNTFS(info),
                let volume = Self.volume(fromInfoPlist: info, currentMounts: currentMounts)
            else {
                continue
            }
            volumes.append(volume)
        }

        return volumes.sorted {
            if $0.isMounted != $1.isMounted {
                return $0.isMounted && !$1.isMounted
            }
            return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    public func unmount(_ volume: NTFSVolume) async throws {
        let target = volume.mountPoint ?? volume.deviceNode
        let result = try await runner.run("/usr/sbin/diskutil", arguments: ["unmount", target])
        guard result.exitCode == 0 else { throw DiskutilError.diskutilFailed(result) }
    }

    static func deviceIdentifiers(fromListPlist plist: [String: Any]) -> [String] {
        var identifiers: [String] = []
        var seen = Set<String>()

        func append(_ value: Any?) {
            guard let identifier = value as? String, !seen.contains(identifier) else { return }
            seen.insert(identifier)
            identifiers.append(identifier)
        }

        if let disks = plist["AllDisksAndPartitions"] as? [[String: Any]] {
            for disk in disks {
                append(disk["DeviceIdentifier"])
                if let partitions = disk["Partitions"] as? [[String: Any]] {
                    for partition in partitions {
                        append(partition["DeviceIdentifier"])
                    }
                }
            }
        }

        if let disks = plist["AllDisks"] as? [String] {
            for disk in disks {
                append(disk)
            }
        }

        return identifiers
    }

    static func volume(fromInfoPlist info: [String: Any]) -> NTFSVolume? {
        volume(fromInfoPlist: info, currentMounts: [:])
    }

    static func volume(fromInfoPlist info: [String: Any], currentMounts: [String: MountedVolumeInfo]) -> NTFSVolume? {
        guard let deviceIdentifier = string(info, "DeviceIdentifier") else { return nil }
        let deviceNode = string(info, "DeviceNode") ?? "/dev/\(deviceIdentifier)"
        let name = string(info, "VolumeName") ?? string(info, "MediaName") ?? deviceIdentifier
        let mountInfo = currentMounts[deviceIdentifier]
        let mountPoint = string(info, "MountPoint") ?? mountInfo?.mountPoint
        let isReadOnly = bool(info, "ReadOnlyVolume") ?? mountInfo?.isReadOnly ?? false
        let isWritable = mountInfo == nil ? bool(info, "WritableVolume") : (mountInfo?.isReadOnly == true ? false : nil)

        return NTFSVolume(
            deviceIdentifier: deviceIdentifier,
            deviceNode: deviceNode,
            name: name,
            fileSystemName: string(info, "FilesystemName") ?? string(info, "FileSystemName") ?? "NTFS",
            content: string(info, "Content"),
            mediaName: string(info, "MediaName"),
            mountPoint: mountPoint,
            totalSize: int64(info, "TotalSize") ?? int64(info, "Size"),
            isMounted: mountPoint != nil || (bool(info, "Mounted") ?? false),
            isReadOnly: isReadOnly,
            isWritable: isWritable
        )
    }

    func currentMountsByDeviceIdentifier() async -> [String: MountedVolumeInfo] {
        guard let result = try? await runner.run("/sbin/mount", arguments: []), result.exitCode == 0 else {
            return [:]
        }

        var mounts: [String: MountedVolumeInfo] = [:]
        for line in result.stdout.split(separator: "\n").map(String.init) {
            guard let mount = Self.mountedVolumeInfo(fromMountLine: line) else { continue }
            mounts[mount.deviceIdentifier] = mount
        }
        return mounts
    }

    static func isNTFS(_ info: [String: Any]) -> Bool {
        let keys = [
            "FilesystemName",
            "FileSystemName",
            "FileSystemType",
            "FileSystemPersonality",
            "TypeName",
            "Content"
        ]

        return keys
            .compactMap { string(info, $0)?.lowercased() }
            .contains { $0.contains("ntfs") || $0.contains("windows_nt") }
    }

    private static func string(_ dictionary: [String: Any], _ key: String) -> String? {
        guard let value = dictionary[key] as? String else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
    }

    private static func bool(_ dictionary: [String: Any], _ key: String) -> Bool? {
        if let value = dictionary[key] as? Bool { return value }
        if let value = dictionary[key] as? NSNumber { return value.boolValue }
        return nil
    }

    private static func int64(_ dictionary: [String: Any], _ key: String) -> Int64? {
        if let value = dictionary[key] as? Int64 { return value }
        if let value = dictionary[key] as? Int { return Int64(value) }
        if let value = dictionary[key] as? NSNumber { return value.int64Value }
        return nil
    }
}

struct MountedVolumeInfo: Equatable {
    let deviceIdentifier: String
    let mountPoint: String
    let isReadOnly: Bool
}

extension DiskutilService {
    static func mountedVolumeInfo(fromMountLine line: String) -> MountedVolumeInfo? {
        guard let onRange = line.range(of: " on "),
              let optionsStart = line.range(of: " (", range: onRange.upperBound..<line.endIndex),
              line.hasPrefix("/dev/")
        else {
            return nil
        }

        let device = String(line[..<onRange.lowerBound])
        var identifier = URL(fileURLWithPath: device).lastPathComponent
        if identifier.hasPrefix("rdisk") {
            identifier = "disk" + String(identifier.dropFirst("rdisk".count))
        }

        let mountPoint = decodeMountEscapes(String(line[onRange.upperBound..<optionsStart.lowerBound]))
        let optionsText = String(line[optionsStart.upperBound..<line.index(before: line.endIndex)])
        let options = Set(optionsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })

        return MountedVolumeInfo(
            deviceIdentifier: identifier,
            mountPoint: mountPoint,
            isReadOnly: options.contains("read-only") || options.contains("rdonly") || options.contains("ro")
        )
    }

    private static func decodeMountEscapes(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\040", with: " ")
            .replacingOccurrences(of: "\\011", with: "\t")
            .replacingOccurrences(of: "\\012", with: "\n")
    }
}
