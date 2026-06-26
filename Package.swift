// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "LocalTranscriber",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "LocalTranscriber",
            targets: ["LocalTranscriber"]
        )
    ],
    targets: [
        .target(
            name: "LocalTranscriberCore"
        ),
        .executableTarget(
            name: "LocalTranscriber",
            dependencies: ["LocalTranscriberCore"]
        ),
        .testTarget(
            name: "LocalTranscriberCoreTests",
            dependencies: ["LocalTranscriberCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
