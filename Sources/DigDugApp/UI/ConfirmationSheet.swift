import DigDugCore
import SwiftUI

struct ConfirmationSheet: View {
    let request: ConfirmationRequest
    let cancel: () -> Void
    let confirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: iconName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Palette.danger)
                    .frame(width: 38, height: 38)
                    .background(Palette.danger.opacity(0.14))
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(request.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(impactText)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.inkDim)
                }
            }

            Text(request.detail)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(Palette.ink)
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.codeBg)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            HStack(spacing: 10) {
                Spacer()
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button(request.confirmLabel, action: confirm)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.danger)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 440)
        .background(Palette.bg)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }

    private var iconName: String {
        request.toolName == "move_item" ? "folder.badge.questionmark" : "trash"
    }

    private var impactText: String {
        request.toolName == "move_item"
            ? "The item will leave its current folder."
            : "Review the path before allowing this action."
    }
}
