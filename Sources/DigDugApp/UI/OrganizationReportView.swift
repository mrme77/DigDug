import DigDugCore
import SwiftUI

struct OrganizationReportView: View {
    let report: OrganizationExecutionReport
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text(report.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.ink)
                if let failure = report.failureMessage {
                    Text(failure)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.danger)
                        .textSelection(.enabled)
                }
                if !report.createdFolders.isEmpty {
                    detail("Folders created", value: String(report.createdFolders.count))
                }
                if !report.reviewItems.isEmpty {
                    detail("Manual review", value: String(report.reviewItems.count))
                }
                if !report.rollbackFailures.isEmpty {
                    Text(report.rollbackFailures.joined(separator: "\n"))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.danger)
                        .textSelection(.enabled)
                }
            }
            .padding(.top, 9)
        } label: {
            Label(statusTitle, systemImage: statusIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(statusColor)
        }
        .padding(11)
        .background(Palette.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Palette.border)
        )
    }

    private var statusTitle: String {
        switch report.status {
        case .completed:
            "Organized \(report.processedCount) files"
        case .rolledBack:
            "Changes reverted after a failure"
        case .rollbackFailed:
            "Organization needs attention"
        }
    }

    private var statusIcon: String {
        switch report.status {
        case .completed: "checkmark.circle.fill"
        case .rolledBack: "arrow.uturn.backward.circle.fill"
        case .rollbackFailed: "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch report.status {
        case .completed: Palette.online
        case .rolledBack: Palette.accent
        case .rollbackFailed: Palette.danger
        }
    }

    private func detail(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Palette.inkDim)
            Spacer()
            Text(value).foregroundStyle(Palette.ink)
        }
        .font(.system(size: 11.5, weight: .medium))
    }
}
