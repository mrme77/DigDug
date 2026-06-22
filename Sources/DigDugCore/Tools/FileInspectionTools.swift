import CryptoKit
import Foundation
import UniformTypeIdentifiers

/// Stable metadata used to classify a file without reading its content.
public struct FileMetadata: Codable, Equatable, Sendable {
    public let path: String
    public let name: String
    public let type: String
    public let size: UInt64
    public let created: String?
    public let modified: String?
    public let contentType: String?

    private enum CodingKeys: String, CodingKey {
        case path, name, type, size, created, modified
        case contentType = "content_type"
    }
}

/// Reads filesystem metadata without opening file contents.
public struct GetFileMetadataTool: AgentTool {
    public let name = "get_file_metadata"
    public let description = "Get canonical path, type, size, dates, and content type without reading file content."
    public let parameters = [
        "path": ToolParameter(type: "string", description: "Existing absolute path or a path beginning with ~.")
    ]
    public let requiredParameters = ["path"]

    public init() {}

    public func execute(arguments: ToolArguments) async throws -> String {
        let url = try PathPolicy.validateRead(try arguments.requiredString("path"))
        try PathPolicy.requireExistingItem(at: url)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileType = attributes[.type] as? FileAttributeType
            let formatter = ISO8601DateFormatter()
            let metadata = FileMetadata(
                path: url.path,
                name: url.lastPathComponent,
                type: fileType == .typeDirectory ? "directory" : "file",
                size: (attributes[.size] as? NSNumber)?.uint64Value ?? 0,
                created: (attributes[.creationDate] as? Date).map(formatter.string),
                modified: (attributes[.modificationDate] as? Date).map(formatter.string),
                contentType: UTType(filenameExtension: url.pathExtension)?.identifier
            )
            return try encodeJSON(metadata)
        } catch {
            throw AgentToolError.operationFailed(
                "Could not inspect '\(url.path)': \(error.localizedDescription)"
            )
        }
    }
}

/// A SHA-256 result used for exact duplicate detection.
public struct FileHashResult: Codable, Equatable, Sendable {
    public let path: String
    public let algorithm: String
    public let hash: String
    public let size: UInt64
}

/// Streams a file through SHA-256 without loading it fully into memory.
public struct HashFileTool: AgentTool {
    public let name = "hash_file"
    public let description = "Calculate a SHA-256 hash for exact duplicate detection."
    public let parameters = [
        "path": ToolParameter(type: "string", description: "Existing file path to hash.")
    ]
    public let requiredParameters = ["path"]

    public init() {}

    public func execute(arguments: ToolArguments) async throws -> String {
        let url = try PathPolicy.validateRead(try arguments.requiredString("path"))
        try PathPolicy.requireExistingItem(at: url)
        guard !PathPolicy.isDirectory(at: url) else {
            throw AgentToolError.operationFailed("Only regular files can be hashed: \(url.path)")
        }

        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var hasher = SHA256()
            var size: UInt64 = 0
            while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
                try Task.checkCancellation()
                size += UInt64(data.count)
                hasher.update(data: data)
            }
            let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            return try encodeJSON(
                FileHashResult(path: url.path, algorithm: "sha256", hash: digest, size: size)
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AgentToolError.operationFailed(
                "Could not hash '\(url.path)': \(error.localizedDescription)"
            )
        }
    }
}
