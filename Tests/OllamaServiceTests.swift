import Testing
@testable import DigDugCore

@Suite struct OllamaServiceTests {
    @Test func decodeChunkReturnsStreamingResponseText() throws {
        let chunk = try OllamaService.decodeChunk(from: #"{"response":"Hello","done":false}"#)

        #expect(chunk == GenerateResponseChunk(response: "Hello", done: false))
    }

    @Test func modelMissingErrorIncludesRecoverySuggestion() {
        let error = OllamaServiceError.modelMissing("gemma4:e4b")

        #expect(error.localizedDescription == "Ollama is running, but the model 'gemma4:e4b' is not installed.")
        #expect(error.recoverySuggestion == "Install it with: ollama pull gemma4:e4b")
    }

    @Test func decodeChunkAcceptsOllamaErrorOnlyResponse() throws {
        let chunk = try OllamaService.decodeChunk(from: #"{"error":"model 'missing' not found"}"#)

        #expect(chunk == GenerateResponseChunk(error: "model 'missing' not found"))
    }
}
