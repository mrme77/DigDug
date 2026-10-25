import DigDugCore
@preconcurrency import MarkdownUI
import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    let isSending: Bool
    var typewriter: Bool = false
    var onTypewriterComplete: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.sender == .user { Spacer(minLength: 52) }
            bubble
                .frame(
                    maxWidth: message.sender == .user ? 340 : .infinity,
                    alignment: message.sender == .user ? .trailing : .leading
                )
            if message.sender != .user { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var bubble: some View {
        switch message.sender {
        case .user:
            Text(message.text)
                .font(.system(size: Metrics.bodySize))
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Palette.accentGradient)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.bubbleRadius, style: .continuous))
                .shadow(color: Palette.accentDeep.opacity(0.3), radius: 8, y: 3)

        case .assistant:
            VStack(alignment: .leading, spacing: 8) {
                if message.text.isEmpty && isSending {
                    TypingIndicator()
                } else if typewriter {
                    TypewriterText(text: message.text, onComplete: onTypewriterComplete)
                } else {
                    Markdown(message.text)
                        .markdownTheme(.digDug)
                        .textSelection(.enabled)
                }
                if !message.text.isEmpty {
                    CopyResponseButton(text: message.text)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.bubbleRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.bubbleRadius, style: .continuous)
                    .strokeBorder(Palette.border)
            )

        case .system:
            Markdown(message.text)
                .markdownTheme(.digDug)
                .textSelection(.enabled)
                .padding(.vertical, 11)
                .padding(.horizontal, 14)
                .background(Palette.danger.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: Metrics.bubbleRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.bubbleRadius, style: .continuous)
                        .strokeBorder(Palette.danger.opacity(0.3))
                )
        }
    }
}

/// Reveals text one character at a time, like it is being typed.
private struct TypewriterText: View {
    let text: String
    var onComplete: () -> Void = {}
    @State private var visible = ""

    var body: some View {
        Markdown(visible)
            .markdownTheme(.digDug)
            .textSelection(.enabled)
            .task(id: text) {
                visible = ""
                for character in text {
                    visible.append(character)
                    try? await Task.sleep(nanoseconds: 28_000_000)
                }
                if !Task.isCancelled { onComplete() }
            }
    }
}

private struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Palette.inkDim)
                    .frame(width: 7, height: 7)
                    .opacity(animating ? 1 : 0.35)
                    .offset(y: animating ? -2.5 : 0)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .frame(height: 16)
        .onAppear { animating = true }
        .accessibilityLabel("DigDug is typing")
    }
}
