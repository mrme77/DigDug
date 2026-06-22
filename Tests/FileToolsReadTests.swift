import Foundation
import Testing
@testable import DigDugCore

@Suite struct FileToolsReadTests {
    @Test func listDirectoryReturnsSortedMetadata() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeText("hello", to: root.appendingPathComponent("b.txt"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("a"), withIntermediateDirectories: false)

        let result = try await ListDirectoryTool().execute(arguments: arguments([
            "path": .string(root.path)
        ]))
        let data = try #require(result.data(using: .utf8))
        let entries = try JSONDecoder().decode([Entry].self, from: data)

        #expect(entries.map(\.name) == ["a", "b.txt"])
        #expect(entries.map(\.type) == ["directory", "file"])
        #expect(entries[1].size == 5)
    }

    @Test func listDirectoryRejectsCredentialPath() async {
        await #expect(throws: AgentToolError.self) {
            try await ListDirectoryTool().execute(arguments: arguments([
                "path": .string("~/.ssh")
            ]))
        }
    }

    @Test func readFileTruncatesPlainText() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("notes.txt")
        try writeText("abcdefghij", to: file)

        let result = try await ReadFileTool().execute(arguments: arguments([
            "path": .string(file.path),
            "max_bytes": .integer(4)
        ]))

        #expect(result.hasPrefix("abcd"))
        #expect(result.contains("Truncated at 4 bytes"))
    }

    @Test func readFileRejectsBinaryContent() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("data.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: file)

        await #expect(throws: AgentToolError.self) {
            try await ReadFileTool().execute(arguments: arguments(["path": .string(file.path)]))
        }
    }

    @Test func searchFilesFiltersNameAndExtension() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let nested = root.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try writeText("one", to: nested.appendingPathComponent("Report-final.md"))
        try writeText("two", to: nested.appendingPathComponent("Report-final.txt"))

        let result = try await SearchFilesTool().execute(arguments: arguments([
            "directory": .string(root.path),
            "name_contains": .string("report"),
            "extension": .string("md")
        ]))

        #expect(result.contains("Report-final.md"))
        #expect(!result.contains("Report-final.txt"))
    }

    @Test func searchFilesRejectsMissingDirectory() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        await #expect(throws: AgentToolError.self) {
            try await SearchFilesTool().execute(arguments: arguments([
                "directory": .string(root.appendingPathComponent("missing").path),
                "name_contains": .string("anything")
            ]))
        }
    }
}

private struct Entry: Decodable {
    let name: String
    let type: String
    let size: Int
}
