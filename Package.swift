// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Quill",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Quill", targets: ["Quill"])
    ],
    targets: [
        .executableTarget(
            name: "Quill",
            path: "Quill"
        )
    ]
)
