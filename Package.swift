// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "CodableDB",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(
            name: "CodableDB",
            targets: ["CodableDB"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pauljohanneskraft/Sift", branch: "main"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"602.0.0"),
    ],
    targets: [
        .macro(
            name: "CodableDBMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "CodableDB",
            dependencies: [
                .product(name: "Sift", package: "Sift"),
                "CodableDBMacros",
            ]
        ),
        .testTarget(
            name: "CodableDBTests",
            dependencies: ["CodableDB"]
        ),
    ]
)
