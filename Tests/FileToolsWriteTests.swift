import Foundation
import Testing
@testable import DigDugCore

@Suite struct FileToolsWriteTests {
    @Test func createFolderHonorsIntermediateOption() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let nested = root.appendingPathComponent("one/two")

        let result = try await CreateFolderTool().execute(arguments: arguments([
            "path": .string(nested.path),
            "create_intermediates": .boolean(true)
        ]))

        #expect(FileManager.default.fileExists(atPath: nested.path))
        #expect(result == "Created: \(nested.path)")
    }

    @Test func createFolderRejectsSystemPath() async {
        await #expect(throws: AgentToolError.self) {
            try await CreateFolderTool().execute(arguments: arguments([
                "path": .string("/System/DigDugTests")
            ]))
        }
    }

    @Test func copyMoveAndRenamePreserveExpectedItems() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.txt")
        let copy = root.appendingPathComponent("copy.txt")
        let destinationFolder = root.appendingPathComponent("Destination", isDirectory: true)
        let moved = destinationFolder.appendingPathComponent("copy.txt")
        try writeText("content", to: source)
        try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: false)

        _ = try await CopyItemTool().execute(arguments: arguments([
            "source": .string(source.path), "destination": .string(copy.path)
        ]))
        _ = try await MoveItemTool().execute(arguments: arguments([
            "source": .string(copy.path), "destination": .string(moved.path)
        ]))
        _ = try await RenameItemTool().execute(arguments: arguments([
            "path": .string(source.path), "new_name": .string("renamed.txt")
        ]))

        #expect(FileManager.default.fileExists(atPath: moved.path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("renamed.txt").path))
        #expect(!FileManager.default.fileExists(atPath: copy.path))
    }

    @Test func moveResolvesNarrowNoBreakSpaceWhenModelSendsPlainSpace() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        // Real macOS screenshot name carries U+202F before "AM"; models echo it as a plain space.
        let realName = "Screenshot 2026-06-15 at 11.27.51\u{202F}AM.png"
        let real = root.appendingPathComponent(realName)
        try writeText("png", to: real)
        let destination = root.appendingPathComponent("moved.png")
        let plainSpaceSource = root.appendingPathComponent(
            realName.replacingOccurrences(of: "\u{202F}", with: " ")
        )
        #expect(!FileManager.default.fileExists(atPath: plainSpaceSource.path))

        _ = try await MoveItemTool().execute(arguments: arguments([
            "source": .string(plainSpaceSource.path), "destination": .string(destination.path)
        ]))

        #expect(FileManager.default.fileExists(atPath: destination.path))
        #expect(!FileManager.default.fileExists(atPath: real.path))
    }

    @Test func moveRequiresExistingDestinationParent() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.txt")
        try writeText("content", to: source)

        await #expect(throws: AgentToolError.self) {
            try await MoveItemTool().execute(arguments: arguments([
                "source": .string(source.path),
                "destination": .string(root.appendingPathComponent("missing/item.txt").path)
            ]))
        }
    }

    @Test func moveConfirmationOnlyAppliesAcrossDirectories() throws {
        let root = FileManager.default.temporaryDirectory
        let source = root.appendingPathComponent("one.txt")
        let sameFolder = root.appendingPathComponent("two.txt")
        let otherFolder = root.appendingPathComponent("Other/two.txt")
        let tool = MoveItemTool()

        let sameRequest = try tool.confirmationRequest(arguments: arguments([
            "source": .string(source.path), "destination": .string(sameFolder.path)
        ]))
        let otherRequest = try tool.confirmationRequest(arguments: arguments([
            "source": .string(source.path), "destination": .string(otherFolder.path)
        ]))

        #expect(sameRequest == nil)
        #expect(otherRequest?.confirmLabel == "Move Item")
    }

    @Test func deletePermanentlyRemovesConfirmedTemporaryFile() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("delete-me.txt")
        try writeText("temporary", to: file)
        let tool = DeleteItemTool()
        let values: [String: JSONValue] = ["path": .string(file.path), "permanent": .boolean(true)]

        let request = try tool.confirmationRequest(arguments: arguments(values))
        let result = try await tool.execute(arguments: arguments(values))

        #expect(request?.confirmLabel == "Delete Permanently")
        #expect(result == "Deleted: \(file.path)")
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func renameRejectsPathComponentsInNewName() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("file.txt")
        try writeText("content", to: file)

        await #expect(throws: AgentToolError.self) {
            try await RenameItemTool().execute(arguments: arguments([
                "path": .string(file.path), "new_name": .string("../escape.txt")
            ]))
        }
    }
}
