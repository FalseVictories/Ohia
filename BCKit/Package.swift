// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BCKit",
    platforms: [
      .macOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "BCKit",
            targets: ["BCKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/cezheng/Fuzi", from: "3.1.3"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/tayloraswift/swift-json", from: "0.5.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "BCKit",
            dependencies: [
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Fuzi", package: "Fuzi"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
        .testTarget(
            name: "BCKitTests",
            dependencies: ["BCKit"]
        ),
    ]
)
