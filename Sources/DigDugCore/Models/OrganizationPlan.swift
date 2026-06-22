import Foundation

/// A complete, reviewable proposal for moving files without deleting them.
public struct OrganizationPlan: Codable, Equatable, Sendable {
    public static let maximumMappings = 100

    public let summary: String
    public let sourceDirectory: String
    public let destinationDirectory: String
    public let mappings: [OrganizationMapping]
    public let reviewItems: [OrganizationReviewItem]

    public init(
        summary: String,
        sourceDirectory: String,
        destinationDirectory: String,
        mappings: [OrganizationMapping],
        reviewItems: [OrganizationReviewItem] = []
    ) {
        self.summary = summary
        self.sourceDirectory = sourceDirectory
        self.destinationDirectory = destinationDirectory
        self.mappings = mappings
        self.reviewItems = reviewItems
    }

    private enum CodingKeys: String, CodingKey {
        case summary, mappings
        case sourceDirectory = "source_directory"
        case destinationDirectory = "destination_directory"
        case reviewItems = "review_items"
    }
}

/// One source-to-destination file mapping with the model's reason.
public struct OrganizationMapping: Codable, Equatable, Identifiable, Sendable {
    public let source: String
    public let destination: String
    public let reason: String

    public var id: String { source }

    public init(source: String, destination: String, reason: String) {
        self.source = source
        self.destination = destination
        self.reason = reason
    }
}

/// A file intentionally excluded from automatic changes for manual review.
public struct OrganizationReviewItem: Codable, Equatable, Identifiable, Sendable {
    public let source: String
    public let reason: String

    public var id: String { source }

    public init(source: String, reason: String) {
        self.source = source
        self.reason = reason
    }
}

/// Final state of a deterministic organization batch.
public enum OrganizationExecutionStatus: String, Codable, Equatable, Sendable {
    case completed
    case rolledBack = "rolled_back"
    case rollbackFailed = "rollback_failed"
}

/// Structured result returned to both the UI and the model after batch execution.
public struct OrganizationExecutionReport: Codable, Equatable, Sendable {
    public let status: OrganizationExecutionStatus
    public let summary: String
    public let plannedCount: Int
    public let processedCount: Int
    public let createdFolders: [String]
    public let reviewItems: [OrganizationReviewItem]
    public let failureMessage: String?
    public let rollbackFailures: [String]

    public init(
        status: OrganizationExecutionStatus,
        summary: String,
        plannedCount: Int,
        processedCount: Int,
        createdFolders: [String],
        reviewItems: [OrganizationReviewItem],
        failureMessage: String? = nil,
        rollbackFailures: [String] = []
    ) {
        self.status = status
        self.summary = summary
        self.plannedCount = plannedCount
        self.processedCount = processedCount
        self.createdFolders = createdFolders
        self.reviewItems = reviewItems
        self.failureMessage = failureMessage
        self.rollbackFailures = rollbackFailures
    }

    private enum CodingKeys: String, CodingKey {
        case status, summary
        case plannedCount = "planned_count"
        case processedCount = "processed_count"
        case createdFolders = "created_folders"
        case reviewItems = "review_items"
        case failureMessage = "failure_message"
        case rollbackFailures = "rollback_failures"
    }
}
