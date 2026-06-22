import Foundation
import UniformTypeIdentifiers

/// Lists the immediate contents of a directory as a JSON array.
public struct ListDirectoryTool: AgentTool {
    public let name = "list_directory"
    public let description = "List files and folders in a directory before acting on them."
    public let parameters = [
        "path": ToolParameter(type: "string", description: "Absolute path or a path beginning with ~.")
    ]
    public let requiredParameters = ["path"]

    public init() {}

    public func execute(arguments: ToolArguments) async throws -> String {
        let url = try PathPolicy.validateRead(try arguments.requiredString("path"))
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey
        ]
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: []
            )
            let entries = try urls.map { itemURL -> DirectoryEntry in
                let values = try itemURL.resourceValues(forKeys: keys)
                let type = values.isSymbolicLink == true
                    ? "symlink"
                    : (values.isDirectory == true ? "directory" : "file")
                return DirectoryEntry(
                    name: itemURL.lastPathComponent,
                    type: type,
                    size: values.fileSize ?? 0,
                    modified: values.contentModificationDate
                )
            }
            return try JSONOutput.encode(entries.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
        } catch let error as AgentToolError {
            throw error
        } catch {
            throw AgentToolError.operationFailed("Could not list '\(url.path)': \(error.localizedDescription)")
        }
    }
}

/// Reads a bounded amount of plain-text file content.
public struct ReadFileTool: AgentTool {
    public let name = "read_file"
    public let description = "Read a plain-text file, with a byte limit to avoid loading large files."
    public let parameters = [
        "path": ToolParameter(type: "string", description: "Absolute path or a path beginning with ~."),
        "max_bytes": ToolParameter(type: "integer", description: "Maximum bytes to read. Defaults to 4096.")
    ]
    public let requiredParameters = ["path"]

    public init() {}

    public func execute(arguments: ToolArguments) async throws -> String {
        let url = try PathPolicy.validateRead(try arguments.requiredString("path"))
        let maxBytes = try arguments.integer("max_bytes", default: 4_096)
        guard (1...1_048_576).contains(maxBytes) else {
            throw AgentToolError.invalidArgument("'max_bytes' must be between 1 and 1048576.")
        }
        try PathPolicy.requireExistingItem(at: url)

        let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey, .isRegularFileKey])
        guard resourceValues.isRegularFile == true else {
            throw AgentToolError.operationFailed("Not a regular file: \(url.path)")
        }
        guard resourceValues.contentType?.conforms(to: .text) == true else {
            throw AgentToolError.operationFailed("Only plain-text files can be read: \(url.path)")
        }

        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: maxBytes + 1) ?? Data()
            let truncated = data.count > maxBytes
            let content = String(decoding: data.prefix(maxBytes), as: UTF8.self)
            return truncated ? "\(content)\n\n[Truncated at \(maxBytes) bytes]" : content
        } catch {
            throw AgentToolError.operationFailed("Could not read '\(url.path)': \(error.localizedDescription)")
        }
    }
}

/// Recursively searches a directory for matching file names.
public struct SearchFilesTool: AgentTool {
    public let name = "search_files"
    public let description = "Recursively search a directory for file names and an optional extension."
    public let parameters = [
        "directory": ToolParameter(type: "string", description: "Directory to search."),
        "name_contains": ToolParameter(type: "string", description: "Case-insensitive text required in the file name."),
        "extension": ToolParameter(type: "string", description: "Optional file extension without a leading dot.")
    ]
    public let requiredParameters = ["directory", "name_contains"]

    public init() {}

    public func execute(arguments: ToolArguments) async throws -> String {
        let directory = try PathPolicy.validateRead(try arguments.requiredString("directory"))
        let needle = try arguments.requiredString("name_contains")
        let requestedExtension = try arguments.optionalString("extension")?
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw AgentToolError.operationFailed("Directory does not exist: \(directory.path)")
        }

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else {
            throw AgentToolError.operationFailed("Could not search: \(directory.path)")
        }

        var matches: [String] = []
        for case let url as URL in enumerator {
            try Task.checkCancellation()
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true,
                  url.lastPathComponent.localizedCaseInsensitiveContains(needle) else { continue }
            if let requestedExtension, !requestedExtension.isEmpty,
               url.pathExtension.caseInsensitiveCompare(requestedExtension) != .orderedSame {
                continue
            }
            matches.append(url.path)
        }
        return try JSONOutput.encode(matches.sorted())
    }
}

private struct DirectoryEntry: Encodable {
    let name: String
    let type: String
    let size: Int
    let modified: Date?
}

enum JSONOutput {
    /// Encodes deterministic, human-readable JSON for returning to the model.
    static func encode<Value: Encodable>(_ value: Value) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw AgentToolError.operationFailed("Could not encode tool output.")
        }
        return string
    }
}
