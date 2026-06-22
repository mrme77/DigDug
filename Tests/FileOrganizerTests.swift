import Foundation
import Testing
@testable import DigDugCore

@Suite struct FileOrganizerTests {
    @Test func metadataReturnsCanonicalFileFacts() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("notes.txt")
        try writeText("hello", to: file)

        let output = try await GetFileMetadataTool().execute(
            arguments: arguments(["paths": .array([.string(file.path)])])
        )
        let results = try JSONDecoder().decode(
            [FileMetadataResult].self,
            from: #require(output.data(using: .utf8))
        )

        #expect(results.count == 1)
        let metadata = try #require(results.first?.metadata)
        #expect(metadata.path == file.path)
        #expect(metadata.name == "notes.txt")
        #expect(metadata.type == "file")
        #expect(metadata.size == 5)
    }

    @Test func hashFileReturnsKnownSHA256() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("hello.txt")
        try writeText("hello", to: file)

        let output = try await HashFileTool().execute(
            arguments: arguments(["paths": .array([.string(file.path)])])
        )
        let results = try JSONDecoder().decode(
            [FileHashItemResult].self,
            from: #require(output.data(using: .utf8))
        )

        #expect(results.count == 1)
        let result = try #require(results.first?.result)
        #expect(result.algorithm == "sha256")
        #expect(result.hash == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
        #expect(result.size == 5)
    }

    @Test func organizeToolPublishesNestedMappingSchema() {
        let tool = OrganizeFilesTool()
        let mappings = tool.parameters["mappings"]

        #expect(mappings?.type == "array")
        #expect(mappings?.items?.type == "object")
        #expect(mappings?.items?.required == ["source", "destination", "reason"])
        #expect(mappings?.items?.properties?["destination"]?.type == "string")
    }

    @Test func confirmationContainsCanonicalTypedPlan() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("report.txt")
        try writeText("report", to: file)
        let plan = makePlan(root: root, files: [file])

        let request = try OrganizeFilesTool().confirmationRequest(
            arguments: toolArguments(for: plan)
        )

        #expect(request?.confirmLabel == "Organize Files")
        #expect(request?.organizationPlan?.mappings.count == 1)
        #expect(request?.organizationPlan?.sourceDirectory == root.path)
    }

    @Test func validatorRejectsSourceOutsideDeclaredRoot() throws {
        let root = try makeTemporaryDirectory()
        let other = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: other)
        }
        let outside = other.appendingPathComponent("outside.txt")
        try writeText("outside", to: outside)
        let plan = OrganizationPlan(
            summary: "Invalid plan",
            sourceDirectory: root.path,
            destinationDirectory: root.appendingPathComponent("Sorted").path,
            mappings: [
                OrganizationMapping(
                    source: outside.path,
                    destination: root.appendingPathComponent("Sorted/outside.txt").path,
                    reason: "Test"
                )
            ]
        )

        #expect(throws: AgentToolError.self) {
            try OrganizationPlanValidator.validate(plan)
        }
    }

    @Test func validatorRejectsDestinationCollision() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.txt")
        let destinationRoot = root.appendingPathComponent("Sorted")
        let destination = destinationRoot.appendingPathComponent("source.txt")
        try writeText("source", to: source)
        try FileManager.default.createDirectory(at: destinationRoot, withIntermediateDirectories: true)
        try writeText("existing", to: destination)
        let plan = OrganizationPlan(
            summary: "Collision",
            sourceDirectory: root.path,
            destinationDirectory: destinationRoot.path,
            mappings: [
                OrganizationMapping(source: source.path, destination: destination.path, reason: "Test")
            ]
        )

        #expect(throws: AgentToolError.self) {
            try OrganizationPlanValidator.validate(plan)
        }
    }

    @Test func executorCreatesFoldersAndMovesEveryFile() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first.txt")
        let second = root.appendingPathComponent("second.txt")
        try writeText("first", to: first)
        try writeText("second", to: second)
        let plan = makePlan(root: root, files: [first, second])

        let report = try await OrganizationPlanExecutor.execute(plan)

        #expect(report.status == .completed)
        #expect(report.processedCount == 2)
        #expect(!FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: plan.mappings[0].destination))
        #expect(FileManager.default.fileExists(atPath: plan.mappings[1].destination))
    }

    @Test func executorRollsBackFirstMoveWhenSecondFails() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first.txt")
        let second = root.appendingPathComponent("second.txt")
        try writeText("first", to: first)
        try writeText("second", to: second)
        let plan = makePlan(root: root, files: [first, second])

        let report = try await OrganizationPlanExecutor.execute(
            plan,
            fileManager: FailingMoveFileManager(failAtMove: 2)
        )

        #expect(report.status == .rolledBack)
        #expect(report.processedCount == 1)
        #expect(FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
        #expect(!FileManager.default.fileExists(atPath: plan.mappings[0].destination))
    }
}

private func makePlan(root: URL, files: [URL]) -> OrganizationPlan {
    let destinationRoot = root.appendingPathComponent("Sorted", isDirectory: true)
    return OrganizationPlan(
        summary: "Sort text files",
        sourceDirectory: root.path,
        destinationDirectory: destinationRoot.path,
        mappings: files.map { file in
            OrganizationMapping(
                source: file.path,
                destination: destinationRoot.appendingPathComponent("Text/\(file.lastPathComponent)").path,
                reason: "Plain-text document"
            )
        }
    )
}

private func toolArguments(for plan: OrganizationPlan) throws -> ToolArguments {
    let data = try JSONEncoder().encode(plan)
    return ToolArguments(try JSONDecoder().decode([String: JSONValue].self, from: data))
}

private final class FailingMoveFileManager: OrganizationFileManaging, @unchecked Sendable {
    private let lock = NSLock()
    private let failAtMove: Int
    private var moveCount = 0
    private let local = LocalOrganizationFileManager()

    init(failAtMove: Int) {
        self.failAtMove = failAtMove
    }

    func fileExists(at url: URL) -> Bool { local.fileExists(at: url) }
    func isDirectory(at url: URL) -> Bool { local.isDirectory(at: url) }
    func createDirectory(at url: URL) throws { try local.createDirectory(at: url) }
    func directoryContents(at url: URL) throws -> [String] { try local.directoryContents(at: url) }
    func removeItem(at url: URL) throws { try local.removeItem(at: url) }

    func moveItem(at source: URL, to destination: URL) throws {
        let shouldFail = lock.withLock {
            moveCount += 1
            return moveCount == failAtMove
        }
        if shouldFail {
            throw AgentToolError.operationFailed("Injected move failure.")
        }
        try local.moveItem(at: source, to: destination)
    }
}
