import Foundation

/// A Sendable representation of any JSON value used by Ollama tool arguments.
public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

/// One JSON-schema property accepted by an agent tool.
public struct ToolParameter: Codable, Equatable, Sendable {
    public let type: String
    public let description: String

    public init(type: String, description: String) {
        self.type = type
        self.description = description
    }
}

/// Type-safe access to a tool call's decoded arguments.
public struct ToolArguments: Equatable, Sendable {
    public let values: [String: JSONValue]

    public init(_ values: [String: JSONValue]) {
        self.values = values
    }

    /// Returns a required string argument or throws a descriptive validation error.
    public func requiredString(_ name: String) throws -> String {
        guard case .string(let value) = values[name] else {
            throw AgentToolError.invalidArgument("Missing or invalid string '\(name)'.")
        }
        return value
    }

    /// Returns an optional string argument.
    public func optionalString(_ name: String) throws -> String? {
        guard let value = values[name], value != .null else { return nil }
        guard case .string(let string) = value else {
            throw AgentToolError.invalidArgument("Invalid string '\(name)'.")
        }
        return string
    }

    /// Returns a boolean argument, falling back to the supplied default.
    public func boolean(_ name: String, default defaultValue: Bool) throws -> Bool {
        guard let value = values[name] else { return defaultValue }
        guard case .boolean(let boolean) = value else {
            throw AgentToolError.invalidArgument("Invalid boolean '\(name)'.")
        }
        return boolean
    }

    /// Returns an integer argument, falling back to the supplied default.
    public func integer(_ name: String, default defaultValue: Int) throws -> Int {
        guard let value = values[name] else { return defaultValue }
        guard case .integer(let integer) = value else {
            throw AgentToolError.invalidArgument("Invalid integer '\(name)'.")
        }
        return integer
    }
}

/// A user decision required before a destructive tool can execute.
public struct ConfirmationRequest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let toolName: String
    public let title: String
    public let detail: String
    public let confirmLabel: String
    public let arguments: [String: JSONValue]

    public init(
        id: UUID = UUID(),
        toolName: String,
        title: String,
        detail: String,
        confirmLabel: String,
        arguments: [String: JSONValue]
    ) {
        self.id = id
        self.toolName = toolName
        self.title = title
        self.detail = detail
        self.confirmLabel = confirmLabel
        self.arguments = arguments
    }
}

/// A file or system operation that can be selected and invoked by the local model.
public protocol AgentTool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameters: [String: ToolParameter] { get }
    var requiredParameters: [String] { get }
    var requiresConfirmation: Bool { get }

    func confirmationRequest(arguments: ToolArguments) throws -> ConfirmationRequest?
    func execute(arguments: ToolArguments) async throws -> String
}

public extension AgentTool {
    var requiresConfirmation: Bool { false }

    /// Returns no confirmation by default; destructive tools override this method.
    func confirmationRequest(arguments: ToolArguments) throws -> ConfirmationRequest? {
        nil
    }

    /// Serializes this tool into Ollama's function-tool JSON schema.
    func ollamaSchema() -> OllamaToolSchema {
        OllamaToolSchema(
            type: "function",
            function: OllamaFunctionSchema(
                name: name,
                description: description,
                parameters: OllamaParametersSchema(
                    type: "object",
                    required: requiredParameters,
                    properties: parameters
                )
            )
        )
    }
}

/// A descriptive tool validation or execution failure.
public enum AgentToolError: LocalizedError, Equatable, Sendable {
    case invalidArgument(String)
    case pathViolation(String)
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidArgument(let message),
             .pathViolation(let message),
             .operationFailed(let message):
            return message
        }
    }
}

/// Ollama's outer tool schema object.
public struct OllamaToolSchema: Codable, Equatable, Sendable {
    public let type: String
    public let function: OllamaFunctionSchema
}

/// Ollama metadata for one callable function.
public struct OllamaFunctionSchema: Codable, Equatable, Sendable {
    public let name: String
    public let description: String
    public let parameters: OllamaParametersSchema
}

/// JSON-schema object definition for a function's arguments.
public struct OllamaParametersSchema: Codable, Equatable, Sendable {
    public let type: String
    public let required: [String]
    public let properties: [String: ToolParameter]
}
