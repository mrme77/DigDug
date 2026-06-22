import DigDugCore
@preconcurrency import MarkdownUI
import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    let isSending: Bool

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
            Group {
                if message.text.isEmpty && isSending {
                    TypingIndicator()
                } else {
                    Markdown(message.text)
                        .markdownTheme(.digDug)
                        .textSelection(.enabled)
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

private struct TypingIndicator: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Palette.inkDim)
                    .frame(width: 7, height: 7)
                    .opacity(opacity(for: index))
                    .offset(y: offset(for: index))
            }
        }
        .frame(height: 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: false)) {
                phase = 3
            }
        }
        .accessibilityLabel("DigDug is typing")
    }

    private func opacity(for index: Int) -> Double {
        let position = (phase + Double(index) * 0.4).truncatingRemainder(dividingBy: 3)
        return 0.35 + 0.65 * max(0, 1 - abs(position - 1))
    }

    private func offset(for index: Int) -> CGFloat {
        let position = (phase + Double(index) * 0.4).truncatingRemainder(dividingBy: 3)
        return -2.5 * max(0, 1 - abs(position - 1))
    }
}
