import Foundation

/// Calls a local Ollama server and streams generated tokens.
public final class OllamaService: Sendable {
    public let model: String
    private let endpoint: URL
    private let session: URLSession

    public init(
        endpoint: URL = URL(string: "http://localhost:11434/api/generate")!,
        model: String = "gemma4:e4b",
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.model = model
        self.session = session
    }

    /// Generates a response from Ollama as an async stream of text chunks.
    public func generateResponseStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeGenerateRequest(prompt: prompt)
                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw OllamaServiceError.invalidResponse
                    }

                    guard httpResponse.statusCode == 200 else {
                        throw mapHTTPError(statusCode: httpResponse.statusCode)
                    }

                    for try await line in bytes.lines {
                        guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            continue
                        }

                        let chunk = try Self.decodeChunk(from: line)

                        if let errorMessage = chunk.error {
                            throw mapOllamaError(errorMessage)
                        }

                        if !chunk.response.isEmpty {
                            continuation.yield(chunk.response)
                        }

                        if chunk.done == true {
                            break
                        }
                    }

                    continuation.finish()
                } catch let error as OllamaServiceError {
                    continuation.finish(throwing: error)
                } catch let error as URLError where Self.isUnavailableError(error) {
                    continuation.finish(throwing: OllamaServiceError.ollamaUnavailable)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func makeGenerateRequest(prompt: String) throws -> URLRequest {
        let payload = GenerateRequest(model: model, prompt: prompt, stream: true)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func mapHTTPError(statusCode: Int) -> OllamaServiceError {
        switch statusCode {
        case 404:
            return .modelMissing(model)
        case 500...599:
            return .ollamaUnavailable
        default:
            return .requestFailed(statusCode: statusCode)
        }
    }

    private func mapOllamaError(_ message: String) -> OllamaServiceError {
        let lowercasedMessage = message.lowercased()
        if lowercasedMessage.contains("model") && lowercasedMessage.contains("not found") {
            return .modelMissing(model)
        }
        return .ollamaError(message)
    }

    private static func isUnavailableError(_ error: URLError) -> Bool {
        switch error.code {
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .timedOut:
            return true
        default:
            return false
        }
    }

    static func decodeChunk(from line: String) throws -> GenerateResponseChunk {
        guard let data = line.data(using: .utf8) else {
            throw OllamaServiceError.invalidResponse
        }
        return try JSONDecoder().decode(GenerateResponseChunk.self, from: data)
    }
}

/// A user-facing Ollama failure with enough detail for targeted UI copy.
public enum OllamaServiceError: LocalizedError, Equatable {
    case invalidResponse
    case modelMissing(String)
    case ollamaUnavailable
    case ollamaError(String)
    case requestFailed(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Ollama returned a response the app could not read."
        case .modelMissing(let model):
            return "Ollama is running, but the model '\(model)' is not installed."
        case .ollamaUnavailable:
            return "Ollama is not reachable at localhost:11434."
        case .ollamaError(let message):
            return message
        case .requestFailed(let statusCode):
            return "Ollama request failed with status code \(statusCode)."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .modelMissing(let model):
            return "Install it with: ollama pull \(model)"
        case .ollamaUnavailable:
            return "Start Ollama, then try again."
        case .invalidResponse, .ollamaError, .requestFailed:
            return nil
        }
    }
}

/// Request body for Ollama's generate endpoint.
struct GenerateRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
}

/// One newline-delimited response chunk from Ollama.
struct GenerateResponseChunk: Decodable, Equatable {
    let response: String
    let done: Bool?
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case response
        case done
        case error
    }

    init(response: String = "", done: Bool? = nil, error: String? = nil) {
        self.response = response
        self.done = done
        self.error = error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        response = try container.decodeIfPresent(String.self, forKey: .response) ?? ""
        done = try container.decodeIfPresent(Bool.self, forKey: .done)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
}
