// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConvAPI",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "ConvAPI", targets: ["ConvAPI"]),
    ],
    targets: [
        .target(name: "ConvAPI"),
        .testTarget(name: "ConvAPITests", dependencies: ["ConvAPI"]),
    ]
)
