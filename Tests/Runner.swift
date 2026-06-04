import Testing

/// Standalone entry point so swift-testing runs under Command Line Tools
/// (no full Xcode `xctest` host). Invoke with `swift run DigDugTestRunner`.
@main
struct TestRunner {
    static func main() async {
        await Testing.__swiftPMEntryPoint() as Never
    }
}
