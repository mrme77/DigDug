import Foundation
@testable import DigDugCore

/// Creates an isolated directory that tests can safely modify and remove.
func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("DigDugTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// Writes UTF-8 text for file-tool test setup.
func writeText(_ text: String, to url: URL) throws {
    try text.write(to: url, atomically: true, encoding: .utf8)
}

/// Builds typed tool arguments from JSON values.
func arguments(_ values: [String: JSONValue]) -> ToolArguments {
    ToolArguments(values)
}
