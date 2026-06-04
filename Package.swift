// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DigDug",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DigDug", targets: ["DigDugApp"]),
        .executable(name: "DigDugTestRunner", targets: ["DigDugTests"])
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0")
    ],
    targets: [
        .target(
            name: "DigDugCore",
            path: "Sources/DigDugCore"
        ),
        .executableTarget(
            name: "DigDugApp",
            dependencies: [
                "DigDugCore",
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Sources/DigDugApp"
        ),
        // Built as an executable, not a testTarget: Command Line Tools (no full
        // Xcode) can compile an .xctest bundle but has no `xctest` host to run it,
        // so `swift test` silently skips execution. This runner calls swift-testing's
        // entry point directly, so `swift run DigDugTestRunner` actually runs tests.
        .executableTarget(
            name: "DigDugTests",
            dependencies: ["DigDugCore"],
            path: "Tests",
            // Command Line Tools ships swift-testing under the Frameworks dir,
            // but SwiftPM doesn't add that search path automatically without Xcode.
            swiftSettings: [
                .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    // Testing.framework depends on lib_TestingInterop.dylib, which lives here.
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
                ])
            ]
        )
    ]
)
