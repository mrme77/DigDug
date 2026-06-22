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

/// One file's metadata lookup outcome within a batch request.
public struct FileMetadataResult: Codable, Equatable, Sendable {
    public let path: String
    public let metadata: FileMetadata?
    public let error: String?
}

/// Reads filesystem metadata without opening file contents.
public struct GetFileMetadataTool: AgentTool {
    public let name = "get_file_metadata"
    public let description = "Get canonical path, type, size, dates, and content type for one or more files without reading their content."
    public let parameters = [
        "paths": ToolParameter(
            type: "array",
            description: "Existing absolute paths (or paths beginning with ~) to inspect in one call.",
            items: ToolParameter(type: "string", description: "Existing absolute path or a path beginning with ~.")
        )
    ]
    public let requiredParameters = ["paths"]

    public init() {}

    public func execute(arguments: ToolArguments) async throws -> String {
        let paths = try arguments.requiredStringArray("paths")
        let results = paths.map(metadataResult)
        return try encodeJSON(results)
    }

    private func metadataResult(for rawPath: String) -> FileMetadataResult {
        do {
            let url = try PathPolicy.validateRead(rawPath)
            try PathPolicy.requireExistingItem(at: url)
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
            return FileMetadataResult(path: rawPath, metadata: metadata, error: nil)
        } catch {
            return FileMetadataResult(path: rawPath, metadata: nil, error: error.localizedDescription)
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

/// One file's hash outcome within a batch request.
public struct FileHashItemResult: Codable, Equatable, Sendable {
    public let path: String
    public let result: FileHashResult?
    public let error: String?
}

/// Streams files through SHA-256 without loading them fully into memory.
public struct HashFileTool: AgentTool {
    public let name = "hash_file"
    public let description = "Calculate SHA-256 hashes for one or more files in one call, for exact duplicate detection."
    public let parameters = [
        "paths": ToolParameter(
            type: "array",
            description: "Existing file paths to hash in one call.",
            items: ToolParameter(type: "string", description: "Existing file path to hash.")
        )
    ]
    public let requiredParameters = ["paths"]

    public init() {}

    public func execute(arguments: ToolArguments) async throws -> String {
        let paths = try arguments.requiredStringArray("paths")
        var results: [FileHashItemResult] = []
        for rawPath in paths {
            try Task.checkCancellation()
            results.append(try await hashResult(for: rawPath))
        }
        return try encodeJSON(results)
    }

    private func hashResult(for rawPath: String) async throws -> FileHashItemResult {
        do {
            let url = try PathPolicy.validateRead(rawPath)
            try PathPolicy.requireExistingItem(at: url)
            guard !PathPolicy.isDirectory(at: url) else {
                throw AgentToolError.operationFailed("Only regular files can be hashed: \(url.path)")
            }
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
            let result = FileHashResult(path: url.path, algorithm: "sha256", hash: digest, size: size)
            return FileHashItemResult(path: rawPath, result: result, error: nil)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return FileHashItemResult(path: rawPath, result: nil, error: error.localizedDescription)
        }
    }
}
