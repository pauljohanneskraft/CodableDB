// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodableDB",
    products: [
        .library(
            name: "CodableDB",
            targets: ["CodableDB"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pauljohanneskraft/Sift", branch: "main")
    ],
    targets: [
        .target(
            name: "CodableDB",
            dependencies: [
                .product(name: "Sift", package: "Sift")
            ]
        ),
        .testTarget(
            name: "CodableDBTests",
            dependencies: ["CodableDB"]
        ),
    ]
)
