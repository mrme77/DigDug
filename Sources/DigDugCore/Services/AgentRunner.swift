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
    /// Absolute round cap including deduped no-op rounds, so an all-dedup loop still halts.
    public static let maximumTotalRounds = 20

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
        var totalRounds = 0
        var lastFailureSignature: String?
        var lastFailureMessage = ""
        // Identical read-only calls already run this turn. Small models (gemma4:e4b) loop
        // on list_directory and never advance, burning every round; short-circuit the repeat.
        var executedReadSignatures: Set<String> = []

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
            // Two ceilings: productive rounds (real tool work) and an absolute round cap that also
            // counts deduped no-op rounds, so an all-dedup loop still terminates.
            guard toolRounds < Self.maximumToolRounds, totalRounds < Self.maximumTotalRounds else {
                let message = "I was unable to complete the task within a safe number of steps. Please try a more specific instruction."
                continuation.yield(.loopLimitReached(message))
                return
            }
            totalRounds += 1
            var didRealWork = false

            for call in toolCalls {
                try Task.checkCancellation()
                let invocation = AgentToolInvocation(
                    name: call.function.name,
                    arguments: call.function.arguments
                )

                // ponytail: dedup identical read-only repeats by exact args. Safe because the
                // organize workflow performs no moves until organize_files ends the chain. Ceiling:
                // a future list → move_item → re-list of the same dir would wrongly dedup; revisit
                // (clear the set after any mutating tool) only if such a flow is added.
                let signature = failureSignature(for: invocation)
                if Self.readOnlyToolNames.contains(invocation.name),
                   !executedReadSignatures.insert(signature).inserted {
                    let nudge = """
                    You already called \(invocation.name) with these exact arguments and the result \
                    has not changed. Do not call it again. Use the information you already have to \
                    proceed — for an organization request, submit the plan with organize_files now.
                    """
                    continuation.yield(.toolStarted(invocation))
                    continuation.yield(
                        .toolFinished(id: invocation.id, result: nudge, succeeded: true)
                    )
                    messages.append(
                        OllamaMessage(role: "tool", content: nudge, toolName: invocation.name)
                    )
                    lastFailureSignature = nil
                    continue
                }

                didRealWork = true
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

                // organize_files is a one-shot batch: one plan, one approval. Once it succeeds the
                // work is done — end the turn so the model can't re-propose the same plan and pop
                // the approval sheet round after round.
                if invocation.name == "organize_files", result.succeeded { return }

                guard !result.succeeded else {
                    lastFailureSignature = nil
                    continue
                }
                if signature == lastFailureSignature {
                    let message = """
                    Stopped after the same tool call failed twice in a row with identical arguments.
                    Last error: \(lastFailureMessage)
                    """
                    continuation.yield(.loopLimitReached(message))
                    return
                }
                lastFailureSignature = signature
                lastFailureMessage = result.text
            }

            // Deduped-only rounds don't spend the productive budget; the absolute cap bounds them.
            if didRealWork { toolRounds += 1 }
        }
    }

    /// Read-only tools whose identical repeats can be safely short-circuited within a turn.
    private static let readOnlyToolNames: Set<String> = [
        "list_directory", "read_file", "search_files", "get_file_metadata", "hash_file"
    ]

    private func failureSignature(for invocation: AgentToolInvocation) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let argumentsData = try? encoder.encode(invocation.arguments)
        let argumentsKey = argumentsData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return "\(invocation.name)|\(argumentsKey)"
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
