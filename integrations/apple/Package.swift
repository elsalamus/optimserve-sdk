// swift-tools-version: 5.7
import PackageDescription
let package = Package(
    name: "OptimServe",
    platforms: [.iOS(.v13), .tvOS(.v13), .macOS(.v10_15)],
    products: [.library(name: "OptimServe", targets: ["OptimServe"])],
    targets: [
        .target(name: "OptimServe", dependencies: ["SwarmCloudKit", "datachannel_wrapper"]),
        .binaryTarget(name: "SwarmCloudKit", path: "Vendor/SwarmCloudKit.xcframework"),
        .binaryTarget(name: "datachannel_wrapper", path: "Vendor/datachannel_wrapper.xcframework")
    ]
)
