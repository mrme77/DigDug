import Foundation

/// Submits one complete file organization batch for preview, approval, and safe execution.
public struct OrganizeFilesTool: AgentTool {
    public let name = "organize_files"
    public let description = "Submit a complete multi-file move plan for one user approval. Never deletes files."
    public let parameters: [String: ToolParameter]
    public let requiredParameters = [
        "summary", "source_directory", "destination_directory", "mappings", "review_items"
    ]
    public let requiresConfirmation = true

    public init() {
        let mapping = ToolParameter(
            type: "object",
            description: "One exact file move.",
            properties: [
                "source": ToolParameter(type: "string", description: "Existing absolute source file path."),
                "destination": ToolParameter(type: "string", description: "Exact absolute destination file path."),
                "reason": ToolParameter(type: "string", description: "Short classification or naming reason.")
            ],
            required: ["source", "destination", "reason"]
        )
        let reviewItem = ToolParameter(
            type: "object",
            description: "An uncertain file that will not be changed.",
            properties: [
                "source": ToolParameter(type: "string", description: "Existing file path."),
                "reason": ToolParameter(type: "string", description: "Why manual review is required.")
            ],
            required: ["source", "reason"]
        )
        parameters = [
            "summary": ToolParameter(type: "string", description: "Concise description of the organization strategy."),
            "source_directory": ToolParameter(type: "string", description: "Root containing every source file."),
            "destination_directory": ToolParameter(type: "string", description: "Root containing every destination."),
            "mappings": ToolParameter(
                type: "array",
                description: "All proposed source-to-destination mappings, maximum 100.",
                items: mapping
            ),
            "review_items": ToolParameter(
                type: "array",
                description: "Uncertain or duplicate files excluded from automatic changes. Use an empty array when none.",
                items: reviewItem
            )
        ]
    }

    public func confirmationRequest(arguments: ToolArguments) throws -> ConfirmationRequest? {
        let plan = try OrganizationPlanValidator.validate(
            arguments.decode(OrganizationPlan.self)
        ).plan
        return ConfirmationRequest(
            toolName: name,
            title: "Apply this organization plan?",
            detail: "\(plan.mappings.count) files\n\(plan.sourceDirectory)\n→ \(plan.destinationDirectory)",
            confirmLabel: "Organize Files",
            arguments: arguments.values,
            organizationPlan: plan
        )
    }

    public func execute(arguments: ToolArguments) async throws -> String {
        let plan = try arguments.decode(OrganizationPlan.self)
        let report = try await OrganizationPlanExecutor.execute(plan)
        return try JSONOutput.encode(report)
    }
}
