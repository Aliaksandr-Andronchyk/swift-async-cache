// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AsyncCache",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "AsyncCache", targets: ["AsyncCache"])
    ],
    targets: [
        .target(name: "AsyncCache"),
        .testTarget(name: "AsyncCacheTests", dependencies: ["AsyncCache"]),
    ]
)
