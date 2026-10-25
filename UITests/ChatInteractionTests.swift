import AppKit
import DigDugCore
import Foundation
import Testing
@testable import DigDugApp

/// Exercises the actual AppKit editor and view model without a live model server.
@Suite(.serialized) @MainActor
struct ChatInteractionTests {
    @Test func returnSendsAndShiftReturnInsertsNewlineAfterPastedText() throws {
        let editor = ComposerTextView()
        editor.isEditable = true
        editor.string = "pasted first line\npasted second line"
        editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        var sends = 0
        editor.send = { sends += 1 }
        editor.keyDown(with: try returnEvent(modifiers: .shift))
        #expect(sends == 0)
        #expect(editor.string == "pasted first line\npasted second line\n")
        editor.keyDown(with: try returnEvent())
        #expect(sends == 1)
        #expect(editor.string.hasSuffix("\n"))
    }

    @Test func disabledEditorDoesNotSendOrInsertNewlines() throws {
        let editor = ComposerTextView()
        editor.isEditable = false
        var sends = 0
        editor.send = { sends += 1 }
        editor.keyDown(with: try returnEvent())
        editor.keyDown(with: try returnEvent(modifiers: .shift))
        #expect(sends == 0)
        #expect(editor.string.isEmpty)
    }

    @Test func copyResponseRemovesMarkdownAndKeepsParagraphs() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        #expect(CopyResponseButton.copy("# Title\n\n**Hello** and `code`.\n\nNext paragraph.",
                                      isCode: false, to: board))
        let value = board.string(forType: .string) ?? ""
        #expect(value.contains("Hello and code."))
        #expect(value.contains("\n\n"))
        #expect(!value.contains("**"))
        #expect(!value.contains("# Title"))
    }

    @Test func copyCodePreservesWhitespaceAndMarkdownCharacters() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let code = "  let text = \"**literal**\"\n\tprint(text)\n"
        #expect(CopyResponseButton.copy(code, isCode: true, to: board))
        #expect(board.string(forType: .string) == code)
    }

    @Test func stoppingBeforeTaskStartsDoesNotInvalidateNextResponse() async throws {
        let client = ControlledChatClient()
        let model = ChatViewModel(client: client)
        model.prompt = "old"
        model.sendMessage()
        model.cancelTask()
        model.prompt = "new"
        model.sendMessage()
        try await waitUntil { client.count == 1 }
        client.complete(index: 0, text: "New answer")
        try await waitUntil { !model.isSending }
        #expect(model.messages.last?.text == "New answer")
        #expect(model.messages.filter { $0.text == "Task cancelled by user." }.count == 1)
    }

    @Test func oldStreamCompletionCannotEndNewTurn() async throws {
        let client = ControlledChatClient()
        let model = ChatViewModel(client: client)
        model.prompt = "old"
        model.sendMessage()
        try await waitUntil { client.count == 1 }
        model.cancelTask()
        model.prompt = "new"
        model.sendMessage()
        client.complete(index: 0, text: "Stale answer")
        try await waitUntil { client.count == 2 }
        #expect(model.isSending)
        client.complete(index: 1, text: "Current answer")
        try await waitUntil { !model.isSending }
        #expect(model.messages.last?.text == "Current answer")
        #expect(!model.messages.contains { $0.text.contains("Stale answer") })
    }

    @Test func blankPromptDoesNotStartRequest() {
        let client = ControlledChatClient()
        let model = ChatViewModel(client: client)
        model.prompt = " \n "
        model.sendMessage()
        #expect(!model.isSending)
        #expect(client.count == 0)
    }

    @Test func userScrollPausesFollowingAndBottomResumesIt() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                              styleMask: [], backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        let document = FlippedDocument(frame: NSRect(x: 0, y: 0, width: 300, height: 1000))
        let probe = TranscriptScrollObserver.ScrollProbe()
        var follows = true
        probe.onScroll = { follows = $0 }
        document.addSubview(probe)
        scroll.documentView = document
        window.contentView = scroll
        NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: scroll)
        #expect(!follows)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 800))
        #expect(!follows) // Programmatic updates alone must not change the user's choice.
        NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: scroll)
        #expect(follows)
        window.contentView = nil
    }

    /// Creates a real native Return event for the editor's keyboard handler.
    private func returnEvent(modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: modifiers, timestamp: 0, windowNumber: 0, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
    }

    /// Bounds asynchronous assertions so a regression fails rather than hanging.
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(condition())
    }
}

/// Matches SwiftUI's top-origin transcript coordinates.
@MainActor private final class FlippedDocument: NSView {
    override var isFlipped: Bool { true }
}

/// Holds streams open until a test deliberately completes a particular turn.
private final class ControlledChatClient: OllamaChatClient, @unchecked Sendable {
    private let lock = NSLock()
    private var streams: [AsyncThrowingStream<OllamaChatChunk, Error>.Continuation] = []
    var count: Int { lock.withLock { streams.count } }

    func chatStream(messages: [OllamaMessage], model: String, reasoning: ReasoningEffort,
                    tools: [OllamaToolSchema]) -> AsyncThrowingStream<OllamaChatChunk, Error> {
        AsyncThrowingStream { continuation in
            lock.withLock { streams.append(continuation) }
        }
    }

    /// Sends a final chunk, including to an already cancelled stream for race tests.
    func complete(index: Int, text: String) {
        let stream = lock.withLock { streams[index] }
        stream.yield(OllamaChatChunk(message: OllamaMessage(role: "assistant", content: text), done: true))
        stream.finish()
    }
}
