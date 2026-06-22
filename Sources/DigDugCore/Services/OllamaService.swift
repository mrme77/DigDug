import Foundation

/// A client capable of streaming Ollama chat responses.
public protocol OllamaChatClient: Sendable {
    func chatStream(
        messages: [OllamaMessage],
        model: String,
        reasoning: ReasoningEffort,
        tools: [OllamaToolSchema]
    ) -> AsyncThrowingStream<OllamaChatChunk, Error>
}

/// Calls the local Ollama API for model discovery and streaming chat.
public final class OllamaService: OllamaChatClient, Sendable {
    public static let defaultModel = "gemma4:e4b"
    /// Far above Ollama's default num_ctx so tool schemas, skill instructions, and
    /// multi-round tool-call history don't get silently truncated mid-task.
    public static let contextWindow = 16_384

    public let model: String
    private let baseURL: URL
    private let session: URLSession

    public init(
        baseURL: URL = URL(string: "http://localhost:11434/api")!,
        model: String = OllamaService.defaultModel,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.model = model
        self.session = session
    }

    /// Fetches installed, local completion models and their capabilities.
    public func availableModels() async throws -> [OllamaModel] {
        var request = URLRequest(url: baseURL.appendingPathComponent("tags"))
        request.httpMethod = "GET"

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaServiceError.invalidResponse
            }
            guard httpResponse.statusCode == 200 else {
                throw mapHTTPError(statusCode: httpResponse.statusCode, model: model)
            }
            let payload = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
            return payload.models
                .filter { $0.isLocal && $0.supportsCompletion }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch let error as OllamaServiceError {
            throw error
        } catch let error as URLError where Self.isUnavailableError(error) {
            throw OllamaServiceError.ollamaUnavailable
        } catch is DecodingError {
            throw OllamaServiceError.invalidResponse
        } catch {
            throw error
        }
    }

    /// Streams newline-delimited chat chunks, including content, thinking, and tool calls.
    public func chatStream(
        messages: [OllamaMessage],
        model: String,
        reasoning: ReasoningEffort,
        tools: [OllamaToolSchema]
    ) -> AsyncThrowingStream<OllamaChatChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeChatRequest(
                        messages: messages,
                        model: model,
                        reasoning: reasoning,
                        tools: tools
                    )
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw OllamaServiceError.invalidResponse
                    }
                    guard httpResponse.statusCode == 200 else {
                        throw mapHTTPError(statusCode: httpResponse.statusCode, model: model)
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            continue
                        }
                        let chunk = try Self.decodeChatChunk(from: line)
                        if let errorMessage = chunk.error {
                            throw mapOllamaError(errorMessage, model: model)
                        }
                        continuation.yield(chunk)
                        if chunk.done == true { break }
                    }
                    continuation.finish()
                } catch let error as OllamaServiceError {
                    continuation.finish(throwing: error)
                } catch let error as URLError where Self.isUnavailableError(error) {
                    continuation.finish(throwing: OllamaServiceError.ollamaUnavailable)
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func decodeChatChunk(from line: String) throws -> OllamaChatChunk {
        guard let data = line.data(using: .utf8) else {
            throw OllamaServiceError.invalidResponse
        }
        return try JSONDecoder().decode(OllamaChatChunk.self, from: data)
    }

    private func makeChatRequest(
        messages: [OllamaMessage],
        model: String,
        reasoning: ReasoningEffort,
        tools: [OllamaToolSchema]
    ) throws -> URLRequest {
        let payload = OllamaChatRequest(
            model: model,
            messages: messages,
            tools: tools.isEmpty ? nil : tools,
            stream: true,
            think: reasoning.ollamaValue,
            options: OllamaChatOptions(numCtx: Self.contextWindow)
        )
        var request = URLRequest(url: baseURL.appendingPathComponent("chat"))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func mapHTTPError(statusCode: Int, model: String) -> OllamaServiceError {
        switch statusCode {
        case 404: .modelMissing(model)
        case 500...599: .ollamaUnavailable
        default: .requestFailed(statusCode: statusCode)
        }
    }

    private func mapOllamaError(_ message: String, model: String) -> OllamaServiceError {
        let lowercasedMessage = message.lowercased()
        if lowercasedMessage.contains("model") && lowercasedMessage.contains("not found") {
            return .modelMissing(model)
        }
        return .ollamaError(message)
    }

    private static func isUnavailableError(_ error: URLError) -> Bool {
        switch error.code {
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost,
             .notConnectedToInternet, .timedOut:
            true
        default:
            false
        }
    }
}

/// A user-facing Ollama failure with enough detail for targeted UI copy.
public enum OllamaServiceError: LocalizedError, Equatable, Sendable {
    case invalidResponse
    case modelMissing(String)
    case ollamaUnavailable
    case ollamaError(String)
    case requestFailed(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Ollama returned a response the app could not read."
        case .modelMissing(let model):
            "Ollama is running, but the model '\(model)' is not installed."
        case .ollamaUnavailable:
            "Ollama is not reachable at localhost:11434."
        case .ollamaError(let message):
            message
        case .requestFailed(let statusCode):
            "Ollama request failed with status code \(statusCode)."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .modelMissing(let model): "Install it with: ollama pull \(model)"
        case .ollamaUnavailable: "Start Ollama, then try again."
        case .invalidResponse, .ollamaError, .requestFailed: nil
        }
    }
}
