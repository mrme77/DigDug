import Foundation

protocol OrganizationFileManaging: Sendable {
    func fileExists(at url: URL) -> Bool
    func isDirectory(at url: URL) -> Bool
    func createDirectory(at url: URL) throws
    func moveItem(at source: URL, to destination: URL) throws
    func directoryContents(at url: URL) throws -> [String]
    func removeItem(at url: URL) throws
}

struct LocalOrganizationFileManager: OrganizationFileManaging {
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    }

    func moveItem(at source: URL, to destination: URL) throws {
        try FileManager.default.moveItem(at: source, to: destination)
    }

    func directoryContents(at url: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: url.path)
    }

    func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}

/// Applies a preflighted organization plan and rolls back prior moves on failure.
enum OrganizationPlanExecutor {
    static func execute(
        _ plan: OrganizationPlan,
        fileManager: any OrganizationFileManaging = LocalOrganizationFileManager()
    ) async throws -> OrganizationExecutionReport {
        let validated = try OrganizationPlanValidator.validate(plan)
        var createdFolders: [URL] = []
        var movedItems: [(source: URL, destination: URL)] = []

        do {
            for directory in try missingDirectories(for: validated, fileManager: fileManager) {
                try Task.checkCancellation()
                try fileManager.createDirectory(at: directory)
                createdFolders.append(directory)
            }

            for mapping in validated.mappings {
                try Task.checkCancellation()
                guard !fileManager.fileExists(at: mapping.destination) else {
                    throw AgentToolError.operationFailed(
                        "Destination appeared after approval: \(mapping.destination.path)"
                    )
                }
                try fileManager.moveItem(at: mapping.source, to: mapping.destination)
                movedItems.append((mapping.source, mapping.destination))
            }

            return OrganizationExecutionReport(
                status: .completed,
                summary: validated.plan.summary,
                plannedCount: validated.mappings.count,
                processedCount: movedItems.count,
                createdFolders: createdFolders.map(\.path),
                reviewItems: validated.plan.reviewItems
            )
        } catch {
            let rollbackFailures = rollback(
                movedItems: movedItems,
                createdFolders: createdFolders,
                fileManager: fileManager
            )
            return OrganizationExecutionReport(
                status: rollbackFailures.isEmpty ? .rolledBack : .rollbackFailed,
                summary: validated.plan.summary,
                plannedCount: validated.mappings.count,
                processedCount: movedItems.count,
                createdFolders: createdFolders.map(\.path),
                reviewItems: validated.plan.reviewItems,
                failureMessage: error.localizedDescription,
                rollbackFailures: rollbackFailures
            )
        }
    }

    private static func missingDirectories(
        for plan: ValidatedOrganizationPlan,
        fileManager: any OrganizationFileManaging
    ) throws -> [URL] {
        let parents = Set(plan.mappings.map { $0.destination.deletingLastPathComponent() } + [plan.destinationRoot])
        var missing: [String: URL] = [:]

        for parent in parents {
            var candidate = parent
            while !fileManager.fileExists(at: candidate) {
                missing[candidate.path] = candidate
                let next = candidate.deletingLastPathComponent()
                guard next != candidate else { break }
                candidate = next
            }
            guard fileManager.isDirectory(at: candidate) else {
                throw AgentToolError.operationFailed(
                    "Destination ancestor is not a directory: \(candidate.path)"
                )
            }
        }

        return missing.values.sorted {
            $0.pathComponents.count == $1.pathComponents.count
                ? $0.path < $1.path
                : $0.pathComponents.count < $1.pathComponents.count
        }
    }

    private static func rollback(
        movedItems: [(source: URL, destination: URL)],
        createdFolders: [URL],
        fileManager: any OrganizationFileManaging
    ) -> [String] {
        var failures: [String] = []
        for item in movedItems.reversed() {
            do {
                guard fileManager.fileExists(at: item.destination),
                      !fileManager.fileExists(at: item.source) else {
                    throw AgentToolError.operationFailed(
                        "Could not restore \(item.source.path) because paths changed during rollback."
                    )
                }
                try fileManager.moveItem(at: item.destination, to: item.source)
            } catch {
                failures.append(error.localizedDescription)
            }
        }

        for directory in createdFolders.reversed() {
            do {
                let contents = try fileManager.directoryContents(at: directory)
                if contents.isEmpty {
                    try fileManager.removeItem(at: directory)
                } else {
                    failures.append("Left non-empty folder during rollback: \(directory.path)")
                }
            } catch {
                failures.append("Could not clean up \(directory.path): \(error.localizedDescription)")
            }
        }
        return failures
    }
}
