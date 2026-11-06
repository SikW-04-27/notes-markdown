// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotesMarkdown",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "NotesMarkdown", targets: ["NotesMarkdown"])],
    targets: [
        .target(name: "MarkdownCore"),
        .executableTarget(name: "NotesMarkdown", dependencies: ["MarkdownCore"]),
        .testTarget(name: "MarkdownCoreTests", dependencies: ["MarkdownCore"])
    ]
)
