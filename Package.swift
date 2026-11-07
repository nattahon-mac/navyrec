// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NavyRec",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "NavyRec", targets: ["NavyRec"])],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", exact: "2.2.4"),
        .package(url: "https://github.com/lihaoyun6/AECAudioStream.git", revision: "0eab971c1dd0420ee84646c71172dd66fa59117c"),
        .package(url: "https://github.com/lihaoyun6/MatrixColorSelector.git", revision: "0853e68c0c9b205ffe6a963f2a56b26e6ceca51a"),
        .package(url: "https://github.com/hidden-spectrum/SwiftLAME.git", revision: "e8256a8151594f47f103c742f684253c6c44871d")
    ],
    targets: [.executableTarget(
        name: "NavyRec",
        dependencies: ["KeyboardShortcuts", "AECAudioStream", "MatrixColorSelector", "SwiftLAME"],
        path: "QuickRecorder",
        exclude: ["Assets.xcassets", "Info.plist", "QuickRecorder.entitlements"],
        resources: [.process("Resources"), .copy("Supports/Scriptable.sdef"), .copy("Supports/navyrec-post.sh")]
    )]
)
