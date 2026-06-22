import Foundation

/// Configuration for one agent turn.
public struct AgentConfiguration: Equatable, Sendable {
    public let model: String
    public let supportsTools: Bool
    public let supportsThinking: Bool
    public let reasoning: ReasoningEffort

    public init(
        model: String,
        supportsTools: Bool,
        supportsThinking: Bool,
        reasoning: ReasoningEffort
    ) {
        self.model = model
        self.supportsTools = supportsTools
        self.supportsThinking = supportsThinking
        self.reasoning = reasoning
    }
}

/// One concrete tool invocation shown in the UI while an agent turn runs.
public struct AgentToolInvocation: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let arguments: [String: JSONValue]

    public init(id: UUID = UUID(), name: String, arguments: [String: JSONValue]) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

/// Observable progress emitted while the agent streams and executes tools.
public enum AgentEvent: Equatable, Sendable {
    case reasoning
    case responseChunk(String)
    case toolStarted(AgentToolInvocation)
    case toolFinished(id: UUID, result: String, succeeded: Bool)
    case loopLimitReached(String)
}

/// Runs Ollama's multi-turn tool loop with confirmation, cancellation, and a hard round limit.
public final class AgentRunner: Sendable {
    public static let maximumToolRounds = 10

    private let client: any OllamaChatClient
    private let registry: ToolRegistry

    public init(client: any OllamaChatClient, registry: ToolRegistry = .shared) {
        self.client = client
        self.registry = registry
    }

    /// Starts one streamed agent turn and yields content plus tool progress events.
    public func run(
        userMessage: String,
        history: [OllamaMessage],
        configuration: AgentConfiguration,
        confirmationHandler: @escaping @Sendable (ConfirmationRequest) async -> Bool
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await performRun(
                        userMessage: userMessage,
                        history: history,
                        configuration: configuration,
                        confirmationHandler: confirmationHandler,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func performRun(
        userMessage: String,
        history: [OllamaMessage],
        configuration: AgentConfiguration,
        confirmationHandler: @escaping @Sendable (ConfirmationRequest) async -> Bool,
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) async throws {
        var messages = [OllamaMessage(role: "system", content: Self.systemPrompt)]
        messages.append(contentsOf: history)
        messages.append(OllamaMessage(role: "user", content: userMessage))

        let schemas = configuration.supportsTools ? registry.ollamaSchema() : []
        let reasoning = configuration.supportsThinking ? configuration.reasoning : .off
        var toolRounds = 0

        while true {
            try Task.checkCancellation()
            var content = ""
            var thinking = ""
            var indexedCalls: [Int: OllamaToolCall] = [:]
            var unindexedCalls: [OllamaToolCall] = []
            var emittedReasoning = false

            let stream = client.chatStream(
                messages: messages,
                model: configuration.model,
                reasoning: reasoning,
                tools: schemas
            )
            for try await chunk in stream {
                try Task.checkCancellation()
                guard let message = chunk.message else { continue }
                if let fragment = message.thinking, !fragment.isEmpty {
                    thinking.append(fragment)
                    if !emittedReasoning {
                        continuation.yield(.reasoning)
                        emittedReasoning = true
                    }
                }
                if let fragment = message.content, !fragment.isEmpty {
                    content.append(fragment)
                    continuation.yield(.responseChunk(fragment))
                }
                for call in message.toolCalls ?? [] {
                    if let index = call.function.index {
                        indexedCalls[index] = call
                    } else if !unindexedCalls.contains(call) {
                        unindexedCalls.append(call)
                    }
                }
            }

            let toolCalls = indexedCalls.keys.sorted().compactMap { indexedCalls[$0] } + unindexedCalls
            let assistantMessage = OllamaMessage(
                role: "assistant",
                content: content,
                thinking: thinking.isEmpty ? nil : thinking,
                toolCalls: toolCalls.isEmpty ? nil : toolCalls
            )
            messages.append(assistantMessage)

            guard !toolCalls.isEmpty else { return }
            guard toolRounds < Self.maximumToolRounds else {
                let message = "I was unable to complete the task within a safe number of steps. Please try a more specific instruction."
                continuation.yield(.loopLimitReached(message))
                return
            }
            toolRounds += 1

            for call in toolCalls {
                try Task.checkCancellation()
                let invocation = AgentToolInvocation(
                    name: call.function.name,
                    arguments: call.function.arguments
                )
                continuation.yield(.toolStarted(invocation))
                let result = await execute(
                    invocation: invocation,
                    confirmationHandler: confirmationHandler
                )
                continuation.yield(
                    .toolFinished(id: invocation.id, result: result.text, succeeded: result.succeeded)
                )
                messages.append(
                    OllamaMessage(role: "tool", content: result.text, toolName: invocation.name)
                )
            }
        }
    }

    private func execute(
        invocation: AgentToolInvocation,
        confirmationHandler: @escaping @Sendable (ConfirmationRequest) async -> Bool
    ) async -> (text: String, succeeded: Bool) {
        guard let tool = registry.tool(named: invocation.name) else {
            return ("Error: unknown tool '\(invocation.name)'.", false)
        }

        let arguments = ToolArguments(invocation.arguments)
        do {
            if let request = try tool.confirmationRequest(arguments: arguments),
               await confirmationHandler(request) == false {
                return ("Error: user declined '\(invocation.name)'.", false)
            }
            let result = try await tool.execute(arguments: arguments)
            return (result, true)
        } catch is CancellationError {
            return ("Error: task cancelled by user.", false)
        } catch {
            return ("Error: \(error.localizedDescription)", false)
        }
    }

    private static let systemPrompt = """
    You are DigDug, a macOS assistant with access to file system tools.
    When the user asks you to organize, move, rename, or search files, use the provided tools.
    Always tell the user what you are about to do before doing it.
    For destructive actions, explain the impact clearly.
    Never make up file paths. Always use list_directory first to confirm what exists.
    \(FileOrganizerSkill.systemInstructions)
    """
}
