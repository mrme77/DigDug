import Combine
import DigDugCore
import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var prompt = ""
    @Published private(set) var messages: [ChatMessage] = [
        ChatMessage(sender: .assistant, text: "Hello! I am **DigDug**. Ask me anything.")
    ]
    @Published private(set) var availableModels: [OllamaModel] = []
    @Published var selectedModelName = OllamaService.defaultModel
    @Published var reasoningEffort: ReasoningEffort = .medium
    @Published private(set) var isSending = false
    @Published private(set) var isLoadingModels = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var toolActivities: [ToolActivity] = []
    @Published private(set) var activeUserMessageID: ChatMessage.ID?
    @Published var pendingConfirmation: ConfirmationRequest?

    private let service: OllamaService
    private let runner: AgentRunner
    private var conversationHistory: [OllamaMessage] = []
    private var responseTask: Task<Void, Never>?
    private var confirmationContinuation: CheckedContinuation<Bool, Never>?

    init(service: OllamaService = OllamaService(), registry: ToolRegistry = .shared) {
        self.service = service
        self.runner = AgentRunner(client: service, registry: registry)
    }

    var selectedModel: OllamaModel? {
        availableModels.first { $0.name == selectedModelName }
    }

    var supportsThinking: Bool {
        selectedModel?.supportsThinking ?? selectedModelName == OllamaService.defaultModel
    }

    var supportsTools: Bool {
        selectedModel?.supportsTools ?? selectedModelName == OllamaService.defaultModel
    }

    var canSend: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    /// Refreshes the local-only completion models advertised by Ollama.
    func loadModels() async {
        guard !isLoadingModels else { return }
        isLoadingModels = true
        defer { isLoadingModels = false }
        do {
            availableModels = try await service.availableModels()
            if !availableModels.contains(where: { $0.name == selectedModelName }),
               let fallback = availableModels.first {
                selectedModelName = fallback.name
            }
            applySelectedModelCapabilities()
            statusMessage = availableModels.isEmpty ? "No local chat models are installed." : nil
        } catch let error as OllamaServiceError {
            statusMessage = error.recoverySuggestion ?? error.localizedDescription
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    /// Selects a model and resets unsupported reasoning settings.
    func selectModel(_ name: String) {
        selectedModelName = name
        applySelectedModelCapabilities()
    }

    /// Starts a cancellable agent turn using the selected local model.
    func sendMessage() {
        let userPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userPrompt.isEmpty, !isSending else { return }

        statusMessage = nil
        isSending = true
        toolActivities = []
        let userMessage = ChatMessage(sender: .user, text: userPrompt)
        let assistantMessage = ChatMessage(sender: .assistant, text: "")
        messages.append(userMessage)
        messages.append(assistantMessage)
        activeUserMessageID = userMessage.id
        prompt = ""

        let history = conversationHistory
        let configuration = AgentConfiguration(
            model: selectedModelName,
            supportsTools: supportsTools,
            supportsThinking: supportsThinking,
            reasoning: reasoningEffort
        )

        responseTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = runner.run(
                    userMessage: userPrompt,
                    history: history,
                    configuration: configuration
                ) { [weak self] request in
                    guard let self else { return false }
                    return await self.requestConfirmation(request)
                }
                for try await event in stream {
                    handle(event, assistantMessageID: assistantMessage.id)
                }
                finishTurn(
                    userPrompt: userPrompt,
                    assistantMessageID: assistantMessage.id
                )
            } catch is CancellationError {
                finishCancellation()
            } catch let error as OllamaServiceError {
                show(error, in: assistantMessage.id)
            } catch {
                show(.ollamaError(error.localizedDescription), in: assistantMessage.id)
            }
        }
    }

    /// Cancels the active concurrency task and declines any pending confirmation.
    func cancelTask() {
        guard isSending else { return }
        resolveConfirmation(approved: false)
        responseTask?.cancel()
        responseTask = nil
        isSending = false
        activeUserMessageID = nil
        markRunningToolsCancelled()
        messages.append(ChatMessage(sender: .system, text: "Task cancelled by user."))
    }

    /// Resolves the currently displayed destructive-action confirmation.
    func resolveConfirmation(approved: Bool) {
        let continuation = confirmationContinuation
        confirmationContinuation = nil
        pendingConfirmation = nil
        continuation?.resume(returning: approved)
    }

    /// Clears transcript and model history while retaining the current controls.
    func clearChat() {
        guard !isSending else { return }
        statusMessage = nil
        toolActivities = []
        activeUserMessageID = nil
        conversationHistory = []
        messages = [
            ChatMessage(sender: .assistant, text: "Hello! I am **DigDug**. Ask me anything.")
        ]
    }

    private func requestConfirmation(_ request: ConfirmationRequest) async -> Bool {
        await withCheckedContinuation { continuation in
            confirmationContinuation = continuation
            pendingConfirmation = request
        }
    }

    private func handle(_ event: AgentEvent, assistantMessageID: ChatMessage.ID) {
        switch event {
        case .reasoning:
            break
        case .responseChunk(let chunk):
            append(chunk, to: assistantMessageID)
        case .toolStarted(let invocation):
            toolActivities.append(ToolActivity(invocation: invocation))
        case .toolFinished(let id, let result, let succeeded):
            guard let index = toolActivities.firstIndex(where: { $0.id == id }) else { return }
            toolActivities[index].result = result
            toolActivities[index].state = succeeded ? .completed : .failed
        case .loopLimitReached(let message):
            append(message, to: assistantMessageID)
        }
    }

    private func finishTurn(userPrompt: String, assistantMessageID: ChatMessage.ID) {
        guard isSending else { return }
        isSending = false
        responseTask = nil
        guard let index = messages.firstIndex(where: { $0.id == assistantMessageID }) else { return }
        if messages[index].text.isEmpty {
            messages[index].text = "No response received."
        }
        conversationHistory.append(OllamaMessage(role: "user", content: userPrompt))
        conversationHistory.append(OllamaMessage(role: "assistant", content: messages[index].text))
    }

    private func finishCancellation() {
        responseTask = nil
        pendingConfirmation = nil
        confirmationContinuation = nil
    }

    private func append(_ chunk: String, to messageID: ChatMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].text.append(chunk)
    }

    private func show(_ error: OllamaServiceError, in messageID: ChatMessage.ID) {
        isSending = false
        responseTask = nil
        activeUserMessageID = nil
        statusMessage = error.recoverySuggestion
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].sender = .system
        messages[index].text = error.localizedDescription
    }

    private func applySelectedModelCapabilities() {
        if !supportsThinking {
            reasoningEffort = .off
        } else if reasoningEffort == .off {
            reasoningEffort = .medium
        }
    }

    private func markRunningToolsCancelled() {
        for index in toolActivities.indices where toolActivities[index].state == .running {
            toolActivities[index].state = .failed
            toolActivities[index].result = "Cancelled by user."
        }
    }
}

struct ToolActivity: Identifiable, Equatable {
    enum State: Equatable {
        case running
        case completed
        case failed
    }

    let id: UUID
    let name: String
    let arguments: [String: JSONValue]
    var state: State = .running
    var result: String?

    init(invocation: AgentToolInvocation) {
        id = invocation.id
        name = invocation.name
        arguments = invocation.arguments
    }
}
