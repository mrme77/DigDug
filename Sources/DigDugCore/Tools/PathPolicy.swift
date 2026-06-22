import Foundation

/// Centralizes path expansion, symlink resolution, and protected-location checks.
enum PathPolicy {
    private static let blockedWriteRoots = [
        "/System", "/Library", "/usr", "/bin", "/sbin", "/private"
    ]

    /// Expands `~`, requires an absolute path, and resolves symlinks before validation.
    static func normalizedURL(for path: String) throws -> URL {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AgentToolError.invalidArgument("Path cannot be empty.")
        }

        let expanded: String
        if trimmed == "~" {
            expanded = FileManager.default.homeDirectoryForCurrentUser.path
        } else if trimmed.hasPrefix("~/") {
            expanded = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(String(trimmed.dropFirst(2)))
                .path
        } else {
            expanded = trimmed
        }

        guard expanded.hasPrefix("/") else {
            throw AgentToolError.invalidArgument("Path must be absolute or start with '~'.")
        }

        return URL(fileURLWithPath: expanded)
            .standardizedFileURL
            .resolvingSymlinksInPath()
    }

    /// Rejects reads from known credential stores after canonicalizing the path.
    static func validateRead(_ path: String) throws -> URL {
        let url = try normalizedURL(for: path)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let blockedRoots = [
            "\(home)/Library/Keychains",
            "\(home)/.ssh",
            "\(home)/.gnupg",
            "\(home)/.aws"
        ]

        if blockedRoots.contains(where: { contains(url.path, root: $0) }) {
            throw AgentToolError.pathViolation(
                "Access denied: '\(url.path)' is inside a protected credential directory."
            )
        }
        return url
    }

    /// Rejects writes to macOS and Unix system roots after canonicalizing the path.
    static func validateWrite(_ path: String) throws -> URL {
        let url = try normalizedURL(for: path)
        if url.path == "/" || blockedWriteRoots.contains(where: { contains(url.path, root: $0) }) {
            throw AgentToolError.pathViolation(
                "Write denied: '\(url.path)' is inside a protected system location."
            )
        }
        return url
    }

    /// Verifies that an item exists at the URL.
    static func requireExistingItem(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AgentToolError.operationFailed("Item does not exist: \(url.path)")
        }
    }

    /// Verifies that the destination parent exists and is a directory.
    static func requireExistingParent(of url: URL) throws {
        let parent = url.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw AgentToolError.operationFailed(
                "Destination parent does not exist: \(parent.path)"
            )
        }
    }

    private static func contains(_ path: String, root: String) -> Bool {
        path == root || path.hasPrefix(root + "/")
    }
}
