import Foundation

/// A single message displayed in the chat transcript.
public struct ChatMessage: Identifiable, Equatable {
    public let id: UUID
    public var sender: ChatSender
    public var text: String

    public init(id: UUID = UUID(), sender: ChatSender, text: String) {
        self.id = id
        self.sender = sender
        self.text = text
    }
}

/// The origin of a chat message.
public enum ChatSender: Equatable {
    case assistant
    case user
    case system
}
