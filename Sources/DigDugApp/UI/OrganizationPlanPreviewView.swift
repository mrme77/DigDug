import DigDugCore
import SwiftUI

struct OrganizationPlanPreviewView: View {
    let plan: OrganizationPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(plan.summary)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Palette.ink)

            HStack(spacing: 8) {
                pathLabel(plan.sourceDirectory, icon: "folder")
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.inkDim)
                pathLabel(plan.destinationDirectory, icon: "folder.badge.plus")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(plan.mappings.enumerated()), id: \.element.id) { index, mapping in
                        mappingRow(mapping)
                        if index < plan.mappings.count - 1 {
                            Divider().overlay(Palette.border)
                        }
                    }

                    if !plan.reviewItems.isEmpty {
                        Divider().overlay(Palette.border).padding(.vertical, 10)
                        Label("Manual review (\(plan.reviewItems.count))", systemImage: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                            .padding(.bottom, 7)
                        ForEach(plan.reviewItems) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.source)
                                    .font(.system(size: 11.5, design: .monospaced))
                                    .foregroundStyle(Palette.ink)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(item.reason)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Palette.inkDim)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(maxHeight: 330)
            .background(Palette.codeBg)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Palette.border)
            )

            Label("No files will be deleted. The batch stops and rolls back if a move fails.", systemImage: "arrow.uturn.backward.circle")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.inkDim)
        }
    }

    private func mappingRow(_ mapping: OrganizationMapping) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Text(relative(mapping.source, root: plan.sourceDirectory))
                    .foregroundStyle(Palette.inkDim)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                Text(relative(mapping.destination, root: plan.destinationDirectory))
                    .foregroundStyle(Palette.ink)
            }
            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
            .lineLimit(1)
            .truncationMode(.middle)
            .help("\(mapping.source) → \(mapping.destination)")

            Text(mapping.reason)
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.inkDim)
        }
        .padding(.vertical, 9)
    }

    private func pathLabel(_ path: String, icon: String) -> some View {
        Label(path, systemImage: icon)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Palette.inkDim)
            .lineLimit(1)
            .truncationMode(.middle)
            .help(path)
    }

    private func relative(_ path: String, root: String) -> String {
        guard path.hasPrefix(root + "/") else { return path }
        return String(path.dropFirst(root.count + 1))
    }
}
