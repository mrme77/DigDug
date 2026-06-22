import Foundation

struct ValidatedOrganizationMapping: Sendable {
    let source: URL
    let destination: URL
    let reason: String
}

struct ValidatedOrganizationPlan: Sendable {
    let plan: OrganizationPlan
    let sourceRoot: URL
    let destinationRoot: URL
    let mappings: [ValidatedOrganizationMapping]
}

/// Canonicalizes and preflights an entire organization plan before approval or execution.
enum OrganizationPlanValidator {
    static func validate(_ plan: OrganizationPlan) throws -> ValidatedOrganizationPlan {
        let summary = plan.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else {
            throw AgentToolError.invalidArgument("Organization plan summary cannot be empty.")
        }
        guard (1...OrganizationPlan.maximumMappings).contains(plan.mappings.count) else {
            throw AgentToolError.invalidArgument(
                "Organization plans must contain between 1 and \(OrganizationPlan.maximumMappings) mappings."
            )
        }
        guard plan.reviewItems.count <= OrganizationPlan.maximumMappings else {
            throw AgentToolError.invalidArgument(
                "Organization plans can contain at most \(OrganizationPlan.maximumMappings) review items."
            )
        }

        let sourceRoot = try validatedSourceRoot(plan.sourceDirectory)
        let destinationRoot = try validatedDestinationRoot(plan.destinationDirectory)
        var sources = Set<String>()
        var destinations = Set<String>()
        var mappings: [ValidatedOrganizationMapping] = []

        for mapping in plan.mappings {
            let source = try validatedSource(mapping.source, within: sourceRoot)
            let destination = try validatedDestination(
                mapping.destination,
                within: destinationRoot
            )
            guard source != destination else {
                throw AgentToolError.invalidArgument("Source and destination are identical: \(source.path)")
            }
            guard sources.insert(source.path.lowercased()).inserted else {
                throw AgentToolError.invalidArgument("Source appears more than once: \(source.path)")
            }
            guard destinations.insert(destination.path.lowercased()).inserted else {
                throw AgentToolError.invalidArgument("Destination appears more than once: \(destination.path)")
            }
            let reason = mapping.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reason.isEmpty else {
                throw AgentToolError.invalidArgument("Every file mapping requires a reason.")
            }
            mappings.append(
                ValidatedOrganizationMapping(source: source, destination: destination, reason: reason)
            )
        }

        var reviewSources = Set<String>()
        let reviewItems = try plan.reviewItems.map { item -> OrganizationReviewItem in
            let url = try PathPolicy.validateRead(item.source)
            guard PathPolicy.contains(url, within: sourceRoot) else {
                throw AgentToolError.pathViolation(
                    "Review item is outside the source directory: \(url.path)"
                )
            }
            try PathPolicy.requireExistingItem(at: url)
            guard reviewSources.insert(url.path.lowercased()).inserted else {
                throw AgentToolError.invalidArgument("Review item appears more than once: \(url.path)")
            }
            let reason = item.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reason.isEmpty else {
                throw AgentToolError.invalidArgument("Every review item requires a reason.")
            }
            return OrganizationReviewItem(source: url.path, reason: reason)
        }

        let normalizedPlan = OrganizationPlan(
            summary: summary,
            sourceDirectory: sourceRoot.path,
            destinationDirectory: destinationRoot.path,
            mappings: mappings.map {
                OrganizationMapping(
                    source: $0.source.path,
                    destination: $0.destination.path,
                    reason: $0.reason
                )
            },
            reviewItems: reviewItems
        )
        return ValidatedOrganizationPlan(
            plan: normalizedPlan,
            sourceRoot: sourceRoot,
            destinationRoot: destinationRoot,
            mappings: mappings
        )
    }

    private static func validatedSourceRoot(_ path: String) throws -> URL {
        let root = try PathPolicy.validateRead(path)
        _ = try PathPolicy.validateWrite(root.path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw AgentToolError.operationFailed("Source directory does not exist: \(root.path)")
        }
        return root
    }

    private static func validatedDestinationRoot(_ path: String) throws -> URL {
        let root = try PathPolicy.validateWrite(path)
        _ = try PathPolicy.validateRead(root.path)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
           !isDirectory.boolValue {
            throw AgentToolError.operationFailed("Destination root is not a directory: \(root.path)")
        }
        return root
    }

    private static func validatedSource(_ path: String, within root: URL) throws -> URL {
        let unresolved = try PathPolicy.expandedURL(for: path)
        try PathPolicy.requireExistingItem(at: unresolved)
        guard try !PathPolicy.isSymbolicLink(path) else {
            throw AgentToolError.pathViolation("Symbolic links require manual review: \(path)")
        }
        let url = try PathPolicy.validateRead(path)
        _ = try PathPolicy.validateWrite(url.path)
        guard PathPolicy.contains(url, within: root) else {
            throw AgentToolError.pathViolation("Source is outside the source directory: \(url.path)")
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw AgentToolError.operationFailed("Only regular files can be organized: \(url.path)")
        }
        return url
    }

    private static func validatedDestination(_ path: String, within root: URL) throws -> URL {
        let url = try PathPolicy.validateWrite(path)
        _ = try PathPolicy.validateRead(url.path)
        guard PathPolicy.contains(url, within: root) else {
            throw AgentToolError.pathViolation(
                "Destination is outside the destination directory: \(url.path)"
            )
        }
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw AgentToolError.operationFailed("Destination already exists: \(url.path)")
        }
        return url
    }
}
