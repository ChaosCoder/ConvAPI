// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "ConvAPI",
    platforms: [
        .iOS(.v11),
    ],
    products: [
        .library(name: "ConvAPI", targets: ["ConvAPI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mxcl/PromiseKit.git", from: "6.8.0"),
        .package(url: "https://github.com/PromiseKit/Foundation.git", from: "3.0.0"),
    ],
    targets: [
        .target(name: "ConvAPI", dependencies: [
            .product(name: "PromiseKit", package: "PromiseKit"),
            .product(name: "PMKFoundation", package: "Foundation"),
        ]),
        .testTarget(name: "ConvAPITests", dependencies: ["ConvAPI"]),
    ]
)
