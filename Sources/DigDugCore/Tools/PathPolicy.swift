import Foundation

/// Centralizes path expansion, symlink resolution, and protected-location checks.
enum PathPolicy {
    private static let blockedWriteRoots = [
        "/System", "/Library", "/usr", "/bin", "/sbin", "/private"
    ]

    /// Expands `~`, requires an absolute path, and resolves symlinks before validation.
    static func normalizedURL(for path: String) throws -> URL {
        try expandedURL(for: path).resolvingSymlinksInPath()
    }

    /// Expands `~` and standardizes an absolute path without following symlinks.
    static func expandedURL(for path: String) throws -> URL {
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

        return URL(fileURLWithPath: expanded).standardizedFileURL
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

    /// Verifies an item exists, returning the canonical URL. When the exact path is missing,
    /// retries against the parent directory folding Unicode spaces — local models routinely
    /// rewrite the U+202F in macOS screenshot names ("…10.29.08 AM.png") as a plain space.
    @discardableResult
    static func requireExistingItem(at url: URL) throws -> URL {
        if FileManager.default.fileExists(atPath: url.path) { return url }
        let parent = url.deletingLastPathComponent()
        let target = foldWhitespace(url.lastPathComponent)
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: parent.path)) ?? []
        let matches = entries.filter { foldWhitespace($0) == target }
        guard matches.count == 1 else {
            // ponytail: only auto-correct a unique whitespace-fold match; ambiguous or absent → fail.
            throw AgentToolError.operationFailed("Item does not exist: \(url.path)")
        }
        return parent.appendingPathComponent(matches[0])
    }

    /// Collapses every Unicode whitespace character to a plain space for tolerant name matching.
    private static func foldWhitespace(_ name: String) -> String {
        String(name.map { $0.isWhitespace ? " " : $0 })
    }

    /// Verifies that the destination parent exists and is a directory.
    static func requireExistingParent(of url: URL) throws {
        let parent = url.deletingLastPathComponent()
        guard isDirectory(at: parent) else {
            throw AgentToolError.operationFailed(
                "Destination parent does not exist: \(parent.path)"
            )
        }
    }

    /// Returns true when a filesystem item exists at the path and is a directory.
    static func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    /// Trims whitespace and rejects an empty result.
    static func requireNonBlank(_ value: String, fieldName: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AgentToolError.invalidArgument("\(fieldName) cannot be empty.")
        }
        return trimmed
    }

    /// Returns true when a canonical path is equal to or below a canonical root.
    static func contains(_ url: URL, within root: URL) -> Bool {
        contains(url.path, root: root.path)
    }

    /// Rejects hidden system files (dotfiles) and application bundles as move/copy/organize sources.
    static func requireNotProtectedBundle(_ url: URL) throws {
        guard !url.lastPathComponent.hasPrefix(".") else {
            throw AgentToolError.pathViolation("Hidden system files cannot be moved or copied: \(url.path)")
        }
        guard url.pathExtension.lowercased() != "app" else {
            throw AgentToolError.pathViolation("Application bundles cannot be moved or copied: \(url.path)")
        }
    }

    /// Returns true when the original path names a symbolic link.
    static func isSymbolicLink(_ path: String) throws -> Bool {
        let url = try expandedURL(for: path)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.type] as? FileAttributeType == .typeSymbolicLink
    }

    private static func contains(_ path: String, root: String) -> Bool {
        path == root || path.hasPrefix(root + "/")
    }
}
