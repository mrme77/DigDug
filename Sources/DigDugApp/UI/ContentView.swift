import DigDugCore
@preconcurrency import MarkdownUI
import SwiftUI

struct ContentView: View {
    @State private var prompt = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(sender: .assistant, text: "Hello! I am **DigDug**. Ask me anything.")
    ]
    @State private var isSending = false
    @State private var statusMessage: String?
    @FocusState private var inputFocused: Bool
    private let ollamaService = OllamaService()

    var body: some View {
        VStack(spacing: 0) {
            header
            messageList
            statusBanner
            inputBar
        }
        .frame(minWidth: 480, minHeight: 580)
        .background(backdrop)
        .preferredColorScheme(.dark)
        .tint(Palette.accent)
    }

    // MARK: Backdrop

    private var backdrop: some View {
        Palette.bg.overlay(alignment: .top) {
            // Subtle amber glow at the top for depth, not decoration.
            RadialGradient(
                colors: [Palette.accent.opacity(0.10), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 280
            )
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Palette.accentGradient)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "shovel")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                )
                .shadow(color: Palette.accent.opacity(0.45), radius: 9, y: 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("DigDug")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 5) {
                    Circle()
                        .fill(Palette.online)
                        .frame(width: 6, height: 6)
                    Text("AI Assistant")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.inkDim)
                }
            }

            Spacer()

            Button(action: clearChat) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.inkDim)
            }
            .buttonStyle(.plain)
            .help("Clear conversation")
            .disabled(isSending || messages.count <= 1)
            .opacity(messages.count <= 1 ? 0.35 : 1)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 13)
        .background(
            Palette.bg.opacity(0.6)
                .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .bottom)
        )
    }

    // MARK: Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(messages) { message in
                        ChatBubble(message: message, isSending: isSending)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }
            .onChange(of: messages) { updated in
                guard let last = updated.last else { return }
                withAnimation(.easeOut(duration: 0.22)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: Status

    @ViewBuilder
    private var statusBanner: some View {
        if let statusMessage {
            Label(statusMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Palette.accentSoft)
        }
    }

    // MARK: Input

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message DigDug…", text: $prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: Metrics.bodySize))
                .foregroundStyle(Palette.ink)
                .lineLimit(1...6)
                .focused($inputFocused)
                .disabled(isSending)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(inputFocused ? Palette.accent.opacity(0.7) : Palette.border,
                                      lineWidth: inputFocused ? 1.5 : 1)
                )
                .onSubmit(sendMessage)

            SendButton(isSending: isSending, isEnabled: canSend, action: sendMessage)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(
            Palette.bg.opacity(0.6)
                .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .top)
        )
    }

    private var canSend: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    // MARK: Actions

    private func sendMessage() {
        let userPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userPrompt.isEmpty, !isSending else { return }

        statusMessage = nil
        isSending = true
        withAnimation(.easeOut(duration: 0.2)) {
            messages.append(ChatMessage(sender: .user, text: userPrompt))
        }

        let assistantMessage = ChatMessage(sender: .assistant, text: "")
        withAnimation(.easeOut(duration: 0.2)) {
            messages.append(assistantMessage)
        }
        prompt = ""

        Task {
            do {
                for try await chunk in ollamaService.generateResponseStream(prompt: userPrompt) {
                    await MainActor.run { append(chunk, to: assistantMessage.id) }
                }
                await MainActor.run {
                    isSending = false
                    if messages.first(where: { $0.id == assistantMessage.id })?.text.isEmpty == true {
                        append("No response received.", to: assistantMessage.id)
                    }
                }
            } catch let error as OllamaServiceError {
                await MainActor.run { show(error, in: assistantMessage.id) }
            } catch {
                await MainActor.run { show(.ollamaError(error.localizedDescription), in: assistantMessage.id) }
            }
        }
    }

    private func append(_ chunk: String, to messageID: ChatMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].text.append(chunk)
    }

    private func show(_ error: OllamaServiceError, in messageID: ChatMessage.ID) {
        isSending = false
        statusMessage = error.recoverySuggestion
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].sender = .system
        messages[index].text = error.localizedDescription
    }

    private func clearChat() {
        statusMessage = nil
        withAnimation(.easeOut(duration: 0.2)) {
            messages = [
                ChatMessage(sender: .assistant, text: "Hello! I am **DigDug**. Ask me anything.")
            ]
        }
    }
}

// MARK: - Send button

private struct SendButton: View {
    let isSending: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isEnabled ? AnyShapeStyle(Palette.accentGradient)
                                    : AnyShapeStyle(Palette.surface))
                    .frame(width: 36, height: 36)
                    .shadow(color: isEnabled ? Palette.accent.opacity(0.5) : .clear, radius: 8, y: 2)

                if isSending {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isEnabled ? .white : Palette.inkDim)
                }
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: [])
        .disabled(!isEnabled)
        .animation(.easeOut(duration: 0.15), value: isEnabled)
    }
}

// MARK: - Chat bubble

private struct ChatBubble: View {
    let message: ChatMessage
    let isSending: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.sender == .user { Spacer(minLength: 52) }

            bubble
                .frame(maxWidth: message.sender == .user ? 340 : .infinity,
                       alignment: message.sender == .user ? .trailing : .leading)

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
                if message.text.isEmpty {
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
                .background(Color.red.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: Metrics.bubbleRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.bubbleRadius, style: .continuous)
                        .strokeBorder(Color.red.opacity(0.3))
                )
        }
    }
}

// MARK: - Typing indicator

private struct TypingIndicator: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Palette.inkDim)
                    .frame(width: 7, height: 7)
                    .opacity(opacity(for: i))
                    .offset(y: offset(for: i))
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
        let p = (phase + Double(index) * 0.4).truncatingRemainder(dividingBy: 3)
        return 0.35 + 0.65 * max(0, 1 - abs(p - 1))
    }

    private func offset(for index: Int) -> CGFloat {
        let p = (phase + Double(index) * 0.4).truncatingRemainder(dividingBy: 3)
        return -2.5 * max(0, 1 - abs(p - 1))
    }
}
