import DigDugCore
import SwiftUI

struct AgentStatusView: View {
    let activities: [ToolActivity]
    @State private var isExpanded = true

    private var isRunning: Bool {
        activities.contains { $0.state == .running }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(activities) { activity in
                    activityRow(activity)
                }
            }
            .padding(.top, 10)
        } label: {
            Label(
                isRunning ? "Working with files" : "File actions (\(activities.count))",
                systemImage: isRunning ? "gearshape.2" : "checkmark.circle"
            )
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isRunning ? Palette.accent : Palette.inkDim)
        }
        .padding(11)
        .background(Palette.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Palette.border)
        )
        .onChange(of: isRunning) { running in
            if !running {
                withAnimation(.easeOut(duration: 0.2)) { isExpanded = false }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func activityRow(_ activity: ToolActivity) -> some View {
        HStack(alignment: .top, spacing: 8) {
            statusIcon(activity.state)
                .frame(width: 14, height: 16)
            VStack(alignment: .leading, spacing: 3) {
                Text(invocationText(activity))
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.ink)
                    .textSelection(.enabled)
                if let result = activity.result {
                    Text(activity.name == "organize_files" ? organizationResult(activity.state) : result)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.inkDim)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func organizationResult(_ state: ToolActivity.State) -> String {
        state == .completed ? "Batch report available below." : "Batch stopped; review the report below."
    }

    @ViewBuilder
    private func statusIcon(_ state: ToolActivity.State) -> some View {
        switch state {
        case .running:
            ProgressView().controlSize(.mini).tint(Palette.accent)
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.online)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.danger)
        }
    }

    private func invocationText(_ activity: ToolActivity) -> String {
        let arguments = activity.arguments.keys.sorted().map { key in
            "\(key): \(display(activity.arguments[key] ?? .null))"
        }
        return "\(activity.name)(\(arguments.joined(separator: ", ")))"
    }

    private func display(_ value: JSONValue) -> String {
        switch value {
        case .string(let string): "\"\(string)\""
        case .integer(let integer): String(integer)
        case .double(let double): String(double)
        case .boolean(let boolean): String(boolean)
        case .array: "[…]"
        case .object: "{…}"
        case .null: "null"
        }
    }
}
