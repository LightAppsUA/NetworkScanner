// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkScanner",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "NetworkScanner",
            targets: ["NetworkScanner"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "NetworkScanner",
            dependencies: [
                "NetworkScannerInternal",
            ]
        ),
        .target(
            name: "NetworkScannerInternal",
            dependencies: []
        ),
    ]
)
