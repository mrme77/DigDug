import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var followsLatest = true

    var body: some View {
        VStack(spacing: 0) {
            header
            ModelControlsView(viewModel: viewModel)
            messageList
            statusBanner
            inputBar
        }
        .frame(minWidth: 480, minHeight: 580)
        .background(backdrop)
        .preferredColorScheme(.dark)
        .tint(Palette.accent)
        .task { await viewModel.loadModels() }
        .sheet(item: $viewModel.pendingConfirmation) { request in
            ConfirmationSheet(
                request: request,
                cancel: { viewModel.resolveConfirmation(approved: false) },
                confirm: { viewModel.resolveConfirmation(approved: true) }
            )
        }
    }

    private var backdrop: some View {
        Palette.bg.overlay(alignment: .top) {
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

    private var header: some View {
        HStack(spacing: 11) {
            // The app icon (Resources/DigDug.png) is the same art shown in the README.
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .shadow(color: Palette.accent.opacity(0.45), radius: 9, y: 2)
                .accessibilityHidden(true)

            Text("Dig Dug")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.ink)

            Spacer()

            Button(action: viewModel.clearChat) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.inkDim)
            }
            .buttonStyle(.plain)
            .help("Clear conversation")
            .disabled(viewModel.isSending || viewModel.messages.count <= 1)
            .opacity(viewModel.messages.count <= 1 ? 0.35 : 1)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 13)
        .background(
            Palette.bg.opacity(0.6)
                .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .bottom)
        )
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        ChatBubble(
                            message: message,
                            isSending: viewModel.isSending,
                            typewriter: message.id == viewModel.messages.first?.id
                                && !viewModel.greetingAnimated,
                            onTypewriterComplete: { viewModel.markGreetingAnimated() }
                        )
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))

                        if message.id == viewModel.lastUserMessageID,
                           !viewModel.toolActivities.isEmpty {
                            AgentStatusView(activities: viewModel.toolActivities)
                                .id("agent-status")
                            if let report = viewModel.organizationReport {
                                OrganizationReportView(report: report)
                                    .id("organization-report")
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .background(TranscriptScrollObserver(followsLatest: $followsLatest))
            }
            .overlay(alignment: .bottomTrailing) {
                if !followsLatest {
                    Button("Jump to latest") {
                        followsLatest = true
                        if let last = viewModel.messages.last { scroll(to: last.id, using: proxy) }
                    }
                    .buttonStyle(.bordered)
                    .padding(12)
                }
            }
            .onChange(of: viewModel.lastUserMessageID) { _ in
                followsLatest = true
                if let last = viewModel.messages.last { scroll(to: last.id, using: proxy) }
            }
            .onChange(of: viewModel.messages) { messages in
                guard followsLatest, let last = messages.last else { return }
                scroll(to: last.id, using: proxy)
            }
            .onChange(of: viewModel.toolActivities) { _ in
                if followsLatest { scroll(to: "agent-status", using: proxy) }
            }
            .onChange(of: viewModel.organizationReport) { report in
                if followsLatest, report != nil { scroll(to: "organization-report", using: proxy) }
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let statusMessage = viewModel.statusMessage {
            Label(statusMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Palette.accentSoft)
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                MessageComposer(text: $viewModel.prompt, isEnabled: !viewModel.isSending,
                                send: viewModel.sendMessage)
                    .frame(height: 76)
                    .background(Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topLeading) {
                        if viewModel.prompt.isEmpty {
                            Text("Message DigDug…")
                                .font(.system(size: Metrics.bodySize))
                                .foregroundStyle(Palette.inkDim)
                                .padding(.leading, 13)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.border))
                Text("Enter to send · Shift+Enter for a new line")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkDim)
            }

            SendOrStopButton(
                isSending: viewModel.isSending,
                isEnabled: viewModel.canSend,
                send: viewModel.sendMessage,
                stop: viewModel.cancelTask
            )
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(
            Palette.bg.opacity(0.6)
                .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .top)
        )
    }

    private func scroll<ID: Hashable>(
        to id: ID,
        using proxy: ScrollViewProxy
    ) {
        proxy.scrollTo(id, anchor: .bottom)
    }
}

private struct SendOrStopButton: View {
    let isSending: Bool
    let isEnabled: Bool
    let send: () -> Void
    let stop: () -> Void

    var body: some View {
        Button(action: isSending ? stop : send) {
            Circle()
                .fill(buttonStyle)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: isSending ? "stop.fill" : "arrow.up")
                        .font(.system(size: isSending ? 12 : 15, weight: .bold))
                        .foregroundStyle(isSending || isEnabled ? .white : Palette.inkDim)
                )
                .shadow(
                    color: isSending || isEnabled ? Palette.accent.opacity(0.5) : .clear,
                    radius: 8,
                    y: 2
                )
        }
        .buttonStyle(.plain)
        .disabled(!isSending && !isEnabled)
        .help(isSending ? "Stop task" : "Send message")
        .accessibilityLabel(isSending ? "Stop task" : "Send message")
        .animation(.easeOut(duration: 0.15), value: isSending)
    }

    private var buttonStyle: AnyShapeStyle {
        if isSending { return AnyShapeStyle(Palette.danger) }
        if isEnabled { return AnyShapeStyle(Palette.accentGradient) }
        return AnyShapeStyle(Palette.surface)
    }
}
