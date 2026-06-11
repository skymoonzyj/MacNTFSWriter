// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MacNTFSWriter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "MacNTFSWriterCore", targets: ["MacNTFSWriterCore"]),
        .executable(name: "MacNTFSWriter", targets: ["MacNTFSWriter"])
    ],
    targets: [
        .target(
            name: "MacNTFSWriterCore",
            path: "Sources/MacNTFSWriterCore"
        ),
        .executableTarget(
            name: "MacNTFSWriter",
            dependencies: ["MacNTFSWriterCore"],
            path: "Sources/MacNTFSWriter"
        ),
        .testTarget(
            name: "MacNTFSWriterCoreTests",
            dependencies: ["MacNTFSWriterCore"],
            path: "Tests/MacNTFSWriterCoreTests"
        )
    ]
)
