// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "ColumnFit",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ColumnFit",
            path: "Sources/ColumnFit"
        )
    ],
    swiftLanguageVersions: [.v5]
)
