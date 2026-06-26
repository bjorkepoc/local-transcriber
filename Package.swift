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
        .executableTarget(
            name: "LocalTranscriber"
        ),
        .testTarget(
            name: "LocalTranscriberTests",
            dependencies: ["LocalTranscriber"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
