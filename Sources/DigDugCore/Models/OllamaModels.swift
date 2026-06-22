import Foundation

/// A chat message exchanged with Ollama, including optional tool calls.
public struct OllamaMessage: Codable, Equatable, Sendable {
    public let role: String
    public let content: String?
    public let thinking: String?
    public let toolCalls: [OllamaToolCall]?
    public let toolName: String?

    public init(
        role: String,
        content: String? = nil,
        thinking: String? = nil,
        toolCalls: [OllamaToolCall]? = nil,
        toolName: String? = nil
    ) {
        self.role = role
        self.content = content
        self.thinking = thinking
        self.toolCalls = toolCalls
        self.toolName = toolName
    }

    private enum CodingKeys: String, CodingKey {
        case role, content, thinking
        case toolCalls = "tool_calls"
        case toolName = "tool_name"
    }
}

/// A function request returned by an Ollama chat model.
public struct OllamaToolCall: Codable, Equatable, Sendable {
    public let type: String?
    public let function: OllamaToolFunction

    public init(type: String? = nil, function: OllamaToolFunction) {
        self.type = type
        self.function = function
    }
}

/// The selected function and decoded JSON arguments in a tool call.
public struct OllamaToolFunction: Codable, Equatable, Sendable {
    public let index: Int?
    public let name: String
    public let arguments: [String: JSONValue]

    public init(index: Int? = nil, name: String, arguments: [String: JSONValue]) {
        self.index = index
        self.name = name
        self.arguments = arguments
    }
}

/// One newline-delimited chunk from Ollama's chat endpoint.
public struct OllamaChatChunk: Codable, Equatable, Sendable {
    public let message: OllamaMessage?
    public let done: Bool?
    public let error: String?

    public init(message: OllamaMessage? = nil, done: Bool? = nil, error: String? = nil) {
        self.message = message
        self.done = done
        self.error = error
    }
}

/// User-selectable reasoning effort sent through Ollama's `think` request field.
public enum ReasoningEffort: String, CaseIterable, Identifiable, Sendable {
    case off
    case low
    case medium
    case high

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.capitalized
    }

    var ollamaValue: JSONValue {
        switch self {
        case .off: .boolean(false)
        case .low, .medium, .high: .string(rawValue)
        }
    }
}

/// An installed local Ollama model and its advertised capabilities.
public struct OllamaModel: Codable, Equatable, Identifiable, Sendable {
    public let name: String
    public let model: String
    public let size: Int64
    public let details: OllamaModelDetails
    public let capabilities: [String]
    public let remoteHost: String?

    public var id: String { name }
    public var supportsCompletion: Bool { capabilities.contains("completion") }
    public var supportsTools: Bool { capabilities.contains("tools") }
    public var supportsThinking: Bool { capabilities.contains("thinking") }
    public var isLocal: Bool { remoteHost == nil }

    private enum CodingKeys: String, CodingKey {
        case name, model, size, details, capabilities
        case remoteHost = "remote_host"
    }
}

/// Display metadata for an installed Ollama model.
public struct OllamaModelDetails: Codable, Equatable, Sendable {
    public let family: String
    public let parameterSize: String
    public let quantizationLevel: String

    private enum CodingKeys: String, CodingKey {
        case family
        case parameterSize = "parameter_size"
        case quantizationLevel = "quantization_level"
    }
}

struct OllamaModelsResponse: Decodable, Sendable {
    let models: [OllamaModel]
}

struct OllamaChatRequest: Encodable, Sendable {
    let model: String
    let messages: [OllamaMessage]
    let tools: [OllamaToolSchema]?
    let stream: Bool
    let think: JSONValue?
    let options: OllamaChatOptions?
}

/// Runtime knobs sent alongside a chat request. Ollama otherwise defaults
/// num_ctx far below what models like gemma4:e4b (131072) actually support,
/// which silently truncates long tool-call histories and directory listings.
struct OllamaChatOptions: Encodable, Sendable {
    let numCtx: Int

    private enum CodingKeys: String, CodingKey {
        case numCtx = "num_ctx"
    }
}
