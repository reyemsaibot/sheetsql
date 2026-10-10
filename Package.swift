// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SheetSQL",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SheetSQL", targets: ["SheetSQL"])],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .executableTarget(name: "SheetSQL", dependencies: ["CSQLite"], resources: [.process("Resources")]),
        .testTarget(name: "SheetSQLTests", dependencies: ["SheetSQL"])
    ]
)
