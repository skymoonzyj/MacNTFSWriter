import Foundation

public struct NTFSVolume: Identifiable, Hashable {
    public let deviceIdentifier: String
    public let deviceNode: String
    public let name: String
    public let fileSystemName: String
    public let content: String?
    public let mediaName: String?
    public let mountPoint: String?
    public let totalSize: Int64?
    public let isMounted: Bool
    public let isReadOnly: Bool
    public let isWritable: Bool?

    public var id: String { deviceIdentifier }

    public var displayName: String {
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        if let mediaName, !mediaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return mediaName
        }
        return deviceIdentifier
    }

    public var formattedSize: String {
        guard let totalSize else { return "未知容量" }
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    public init(
        deviceIdentifier: String,
        deviceNode: String,
        name: String,
        fileSystemName: String,
        content: String?,
        mediaName: String?,
        mountPoint: String?,
        totalSize: Int64?,
        isMounted: Bool,
        isReadOnly: Bool,
        isWritable: Bool?
    ) {
        self.deviceIdentifier = deviceIdentifier
        self.deviceNode = deviceNode
        self.name = name
        self.fileSystemName = fileSystemName
        self.content = content
        self.mediaName = mediaName
        self.mountPoint = mountPoint
        self.totalSize = totalSize
        self.isMounted = isMounted
        self.isReadOnly = isReadOnly
        self.isWritable = isWritable
    }
}
