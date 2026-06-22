import Foundation
import Testing
@testable import DigDugCore

@Suite struct OllamaServiceTests {
    @Test func decodeChatChunkReturnsContentAndToolCall() throws {
        let json = #"{"message":{"role":"assistant","content":"Checking","tool_calls":[{"function":{"name":"list_directory","arguments":{"path":"~/Downloads"}}}]},"done":true}"#

        let chunk = try OllamaService.decodeChatChunk(from: json)

        #expect(chunk.message?.content == "Checking")
        #expect(chunk.message?.toolCalls?.first?.function.name == "list_directory")
        #expect(chunk.message?.toolCalls?.first?.function.arguments["path"] == .string("~/Downloads"))
        #expect(chunk.done == true)
    }

    @Test func decodeChatChunkAcceptsOllamaErrorOnlyResponse() throws {
        let chunk = try OllamaService.decodeChatChunk(from: #"{"error":"model 'missing' not found"}"#)

        #expect(chunk == OllamaChatChunk(error: "model 'missing' not found"))
    }

    @Test func modelMissingErrorIncludesRecoverySuggestion() {
        let error = OllamaServiceError.modelMissing("gemma4:e4b")

        #expect(error.localizedDescription == "Ollama is running, but the model 'gemma4:e4b' is not installed.")
        #expect(error.recoverySuggestion == "Install it with: ollama pull gemma4:e4b")
    }

    @Test func jsonValueRoundTripsNestedArguments() throws {
        let original: [String: JSONValue] = [
            "enabled": .boolean(true),
            "count": .integer(3),
            "items": .array([.string("one"), .null])
        ]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: data)

        #expect(decoded == original)
    }

    @Test func registryProducesDeterministicOllamaSchema() {
        let registry = ToolRegistry()
        registry.register(ReadFileTool())
        registry.register(ListDirectoryTool())

        let schema = registry.ollamaSchema()

        #expect(schema.map(\.function.name) == ["list_directory", "read_file"])
        #expect(schema[0].function.parameters.required == ["path"])
        #expect(schema[0].function.parameters.properties["path"]?.type == "string")
    }

    @Test func chatRequestEncodesReasoningLevelAndTools() throws {
        let request = OllamaChatRequest(
            model: "gemma4:e4b",
            messages: [OllamaMessage(role: "user", content: "Hello")],
            tools: [ListDirectoryTool().ollamaSchema()],
            stream: true,
            think: ReasoningEffort.high.ollamaValue
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["model"] as? String == "gemma4:e4b")
        #expect(object["stream"] as? Bool == true)
        #expect(object["think"] as? String == "high")
        #expect((object["tools"] as? [[String: Any]])?.count == 1)
    }
}
