import Foundation
import Testing
@testable import DigDugCore

@Suite struct AgentRunnerTests {
    @Test func loopGuardStopsAfterTenToolRounds() async throws {
        let registry = ToolRegistry()
        registry.register(EchoTool())
        let runner = AgentRunner(client: RepeatingToolClient(), registry: registry)
        var startedCount = 0
        var limitMessage: String?

        let stream = runner.run(
            userMessage: "keep calling",
            history: [],
            configuration: testConfiguration
        ) { _ in true }
        for try await event in stream {
            if case .toolStarted = event { startedCount += 1 }
            if case .loopLimitReached(let message) = event { limitMessage = message }
        }

        #expect(startedCount == AgentRunner.maximumToolRounds)
        #expect(limitMessage?.contains("safe number of steps") == true)
    }

    @Test func identicalRepeatedFailureStopsBeforeRoundLimit() async throws {
        let registry = ToolRegistry()
        registry.register(AlwaysFailingTool())
        let runner = AgentRunner(client: RepeatingFailingToolClient(), registry: registry)
        var startedCount = 0
        var limitMessage: String?

        let stream = runner.run(
            userMessage: "keep failing",
            history: [],
            configuration: testConfiguration
        ) { _ in true }
        for try await event in stream {
            if case .toolStarted = event { startedCount += 1 }
            if case .loopLimitReached(let message) = event { limitMessage = message }
        }

        #expect(startedCount == 2)
        #expect(limitMessage?.contains("failed twice in a row") == true)
    }

    @Test func declinedConfirmationReturnsErrorThenContinues() async throws {
        let registry = ToolRegistry()
        registry.register(ConfirmingTool())
        let client = SequenceChatClient(responses: [toolCallChunk(name: "confirming"), contentChunk("Done")])
        let runner = AgentRunner(client: client, registry: registry)
        var toolSucceeded: Bool?
        var content = ""

        let stream = runner.run(
            userMessage: "confirm something",
            history: [],
            configuration: testConfiguration
        ) { _ in false }
        for try await event in stream {
            if case .toolFinished(_, _, let succeeded) = event { toolSucceeded = succeeded }
            if case .responseChunk(let fragment) = event { content.append(fragment) }
        }

        #expect(toolSucceeded == false)
        #expect(content == "Done")
    }
}

private let testConfiguration = AgentConfiguration(
    model: "test",
    supportsTools: true,
    supportsThinking: false,
    reasoning: .off
)

private struct EchoTool: AgentTool {
    let name = "echo"
    let description = "Echo a value."
    let parameters = ["value": ToolParameter(type: "string", description: "Value")]
    let requiredParameters = ["value"]

    func execute(arguments: ToolArguments) async throws -> String {
        try arguments.requiredString("value")
    }
}

private struct AlwaysFailingTool: AgentTool {
    let name = "always_fail"
    let description = "Always fails with the same error."
    let parameters: [String: ToolParameter] = [:]
    let requiredParameters: [String] = []

    func execute(arguments: ToolArguments) async throws -> String {
        throw AgentToolError.operationFailed("This tool always fails.")
    }
}

private struct ConfirmingTool: AgentTool {
    let name = "confirming"
    let description = "Always requires confirmation."
    let parameters: [String: ToolParameter] = [:]
    let requiredParameters: [String] = []
    let requiresConfirmation = true

    func confirmationRequest(arguments: ToolArguments) throws -> ConfirmationRequest? {
        ConfirmationRequest(
            toolName: name,
            title: "Confirm?",
            detail: "Test",
            confirmLabel: "Confirm",
            arguments: arguments.values
        )
    }

    func execute(arguments: ToolArguments) async throws -> String { "Executed" }
}

private struct RepeatingToolClient: OllamaChatClient {
    func chatStream(
        messages: [OllamaMessage],
        model: String,
        reasoning: ReasoningEffort,
        tools: [OllamaToolSchema]
    ) -> AsyncThrowingStream<OllamaChatChunk, Error> {
        singleChunkStream(toolCallChunk(name: "echo", arguments: ["value": .string("ok")]))
    }
}

private struct RepeatingFailingToolClient: OllamaChatClient {
    func chatStream(
        messages: [OllamaMessage],
        model: String,
        reasoning: ReasoningEffort,
        tools: [OllamaToolSchema]
    ) -> AsyncThrowingStream<OllamaChatChunk, Error> {
        singleChunkStream(toolCallChunk(name: "always_fail", arguments: [:]))
    }
}

private final class SequenceChatClient: OllamaChatClient, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [OllamaChatChunk]

    init(responses: [OllamaChatChunk]) {
        self.responses = responses
    }

    func chatStream(
        messages: [OllamaMessage],
        model: String,
        reasoning: ReasoningEffort,
        tools: [OllamaToolSchema]
    ) -> AsyncThrowingStream<OllamaChatChunk, Error> {
        let response = lock.withLock { responses.removeFirst() }
        return singleChunkStream(response)
    }
}

private func singleChunkStream(_ chunk: OllamaChatChunk) -> AsyncThrowingStream<OllamaChatChunk, Error> {
    AsyncThrowingStream { continuation in
        continuation.yield(chunk)
        continuation.finish()
    }
}

private func toolCallChunk(
    name: String,
    arguments: [String: JSONValue] = [:]
) -> OllamaChatChunk {
    OllamaChatChunk(
        message: OllamaMessage(
            role: "assistant",
            content: "",
            toolCalls: [OllamaToolCall(function: OllamaToolFunction(name: name, arguments: arguments))]
        ),
        done: true
    )
}

private func contentChunk(_ content: String) -> OllamaChatChunk {
    OllamaChatChunk(message: OllamaMessage(role: "assistant", content: content), done: true)
}
