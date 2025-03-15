// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Lumos",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Lumos", targets: ["Lumos"]),
        .library(name: "TreePrinter", targets: ["TreePrinter"]),
    ],
    targets: [
        .target(name: "TreePrinter"),
        // 仅在 #if DEBUG 中才会依赖使用 TreePrinter
        .target(name: "Lumos", dependencies: ["TreePrinter"]),
        .testTarget(name: "LumosTests", dependencies: ["Lumos", "TreePrinter"]),
        .testTarget(name: "TreePrinterTests", dependencies: ["TreePrinter"]),
    ]
)
