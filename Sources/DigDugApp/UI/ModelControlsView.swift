import DigDugCore
import SwiftUI

struct ModelControlsView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        HStack(spacing: 8) {
            modelMenu
            reasoningMenu
            Spacer(minLength: 0)
            capabilityLabel
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Palette.bg.opacity(0.72))
        .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .bottom)
    }

    private var modelMenu: some View {
        Menu {
            ForEach(viewModel.availableModels) { model in
                Button {
                    viewModel.selectModel(model.name)
                } label: {
                    if model.name == viewModel.selectedModelName {
                        Label(model.name, systemImage: "checkmark")
                    } else {
                        Text(model.name)
                    }
                }
            }
            if !viewModel.availableModels.isEmpty { Divider() }
            Button("Refresh Models", systemImage: "arrow.clockwise") {
                Task { await viewModel.loadModels() }
            }
        } label: {
            ControlLabel(
                title: viewModel.selectedModelName,
                systemImage: "cpu",
                isLoading: viewModel.isLoadingModels
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(viewModel.isSending)
        .help("Select an installed local Ollama model")
    }

    private var reasoningMenu: some View {
        Menu {
            ForEach(ReasoningEffort.allCases) { effort in
                Button {
                    viewModel.reasoningEffort = effort
                } label: {
                    if effort == viewModel.reasoningEffort {
                        Label(effort.displayName, systemImage: "checkmark")
                    } else {
                        Text(effort.displayName)
                    }
                }
            }
        } label: {
            ControlLabel(
                title: viewModel.supportsThinking
                    ? "Reasoning: \(viewModel.reasoningEffort.displayName)"
                    : "Reasoning Unavailable",
                systemImage: "brain"
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(viewModel.isSending || !viewModel.supportsThinking)
        .help(viewModel.supportsThinking
              ? "Set the model's reasoning effort"
              : "This model does not advertise thinking support")
    }

    @ViewBuilder
    private var capabilityLabel: some View {
        if !viewModel.supportsTools {
            Label("Chat only", systemImage: "text.bubble")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.inkDim)
                .help("This model does not advertise tool support")
        }
    }
}

private struct ControlLabel: View {
    let title: String
    let systemImage: String
    var isLoading = false

    var body: some View {
        HStack(spacing: 6) {
            if isLoading {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: systemImage)
            }
            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Palette.inkDim)
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Palette.border)
        )
        .frame(maxWidth: 220)
    }
}
