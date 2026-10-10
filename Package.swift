// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SheetQL",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SheetQL", targets: ["SheetQL"])],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .executableTarget(name: "SheetQL", dependencies: ["CSQLite"], resources: [.process("Resources")]),
        .testTarget(name: "SheetQLTests", dependencies: ["SheetQL"])
    ]
)
