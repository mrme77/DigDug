import Foundation

/// Creates a directory at a validated path.
public struct CreateFolderTool: AgentTool {
    public let name = "create_folder"
    public let description = "Create a folder at an exact path."
    public let parameters = [
        "path": ToolParameter(type: "string", description: "Folder path to create."),
        "create_intermediates": ToolParameter(type: "boolean", description: "Create missing parent folders. Defaults to false.")
    ]
    public let requiredParameters = ["path"]

    public init() {}

    public func execute(arguments: ToolArguments) async throws -> String {
        let url = try PathPolicy.validateWrite(try arguments.requiredString("path"))
        let intermediates = try arguments.boolean("create_intermediates", default: false)
        do {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: intermediates
            )
            return "Created: \(url.path)"
        } catch {
            throw AgentToolError.operationFailed("Could not create '\(url.path)': \(error.localizedDescription)")
        }
    }
}

/// Moves an item to an exact destination path.
public struct MoveItemTool: AgentTool {
    public let name = "move_item"
    public let description = "Move a file or folder to an exact destination path."
    public let parameters = FileTransferParameters.values
    public let requiredParameters = ["source", "destination"]
    public let requiresConfirmation = true

    public init() {}

    public func confirmationRequest(arguments: ToolArguments) throws -> ConfirmationRequest? {
        let source = try PathPolicy.normalizedURL(for: arguments.requiredString("source"))
        let destination = try PathPolicy.normalizedURL(for: arguments.requiredString("destination"))
        guard source.deletingLastPathComponent() != destination.deletingLastPathComponent() else {
            return nil
        }
        return ConfirmationRequest(
            toolName: name,
            title: "Move this item?",
            detail: "\(source.path)\n→ \(destination.path)",
            confirmLabel: "Move Item",
            arguments: arguments.values
        )
    }

    public func execute(arguments: ToolArguments) async throws -> String {
        let source = try PathPolicy.validateWrite(try arguments.requiredString("source"))
        _ = try PathPolicy.validateRead(source.path)
        let destination = try PathPolicy.validateWrite(try arguments.requiredString("destination"))
        try PathPolicy.requireExistingItem(at: source)
        try PathPolicy.requireExistingParent(of: destination)
        try PathPolicy.requireNotProtectedBundle(source)
        do {
            try FileManager.default.moveItem(at: source, to: destination)
            return "Moved: \(source.path) → \(destination.path)"
        } catch {
            throw AgentToolError.operationFailed("Could not move '\(source.path)': \(error.localizedDescription)")
        }
    }
}

/// Copies an item to an exact destination path.
public struct CopyItemTool: AgentTool {
    public let name = "copy_item"
    public let description = "Copy a file or folder to an exact destination path."
    public let parameters = FileTransferParameters.values
    public let requiredParameters = ["source", "destination"]

    public init() {}

    public func execute(arguments: ToolArguments) async throws -> String {
        let source = try PathPolicy.validateRead(try arguments.requiredString("source"))
        let destination = try PathPolicy.validateWrite(try arguments.requiredString("destination"))
        try PathPolicy.requireExistingItem(at: source)
        try PathPolicy.requireExistingParent(of: destination)
        try PathPolicy.requireNotProtectedBundle(source)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            return "Copied: \(source.path) → \(destination.path)"
        } catch {
            throw AgentToolError.operationFailed("Could not copy '\(source.path)': \(error.localizedDescription)")
        }
    }
}

/// Moves an item to Trash by default, or permanently deletes it after confirmation.
public struct DeleteItemTool: AgentTool {
    public let name = "delete_item"
    public let description = "Move an item to Trash, or permanently delete it when explicitly requested."
    public let parameters = [
        "path": ToolParameter(type: "string", description: "Item to remove."),
        "permanent": ToolParameter(type: "boolean", description: "Permanently delete instead of moving to Trash. Defaults to false.")
    ]
    public let requiredParameters = ["path"]
    public let requiresConfirmation = true

    public init() {}

    public func confirmationRequest(arguments: ToolArguments) throws -> ConfirmationRequest? {
        let path = try PathPolicy.normalizedURL(for: arguments.requiredString("path")).path
        let permanent = try arguments.boolean("permanent", default: false)
        return ConfirmationRequest(
            toolName: name,
            title: permanent ? "Permanently delete this item?" : "Move this item to Trash?",
            detail: path,
            confirmLabel: permanent ? "Delete Permanently" : "Move to Trash",
            arguments: arguments.values
        )
    }

    public func execute(arguments: ToolArguments) async throws -> String {
        let url = try PathPolicy.validateWrite(try arguments.requiredString("path"))
        let permanent = try arguments.boolean("permanent", default: false)
        try PathPolicy.requireExistingItem(at: url)
        guard url != FileManager.default.homeDirectoryForCurrentUser else {
            throw AgentToolError.pathViolation("Deleting the home directory is not allowed.")
        }
        do {
            if permanent {
                try FileManager.default.removeItem(at: url)
                return "Deleted: \(url.path)"
            }
            _ = try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return "Trashed: \(url.path)"
        } catch {
            throw AgentToolError.operationFailed("Could not remove '\(url.path)': \(error.localizedDescription)")
        }
    }
}

/// Renames an item without moving it to another directory.
public struct RenameItemTool: AgentTool {
    public let name = "rename_item"
    public let description = "Rename a file or folder within its current directory."
    public let parameters = [
        "path": ToolParameter(type: "string", description: "Existing item path."),
        "new_name": ToolParameter(type: "string", description: "New file or folder name only, without a path.")
    ]
    public let requiredParameters = ["path", "new_name"]

    public init() {}

    public func execute(arguments: ToolArguments) async throws -> String {
        let source = try PathPolicy.validateWrite(try arguments.requiredString("path"))
        let newName = try arguments.requiredString("new_name")
        guard !newName.isEmpty, newName != ".", newName != "..", !newName.contains("/") else {
            throw AgentToolError.invalidArgument("'new_name' must be a single valid file name.")
        }
        let destination = try PathPolicy.validateWrite(
            source.deletingLastPathComponent().appendingPathComponent(newName).path
        )
        try PathPolicy.requireExistingItem(at: source)
        do {
            try FileManager.default.moveItem(at: source, to: destination)
            return "Renamed to: \(newName)"
        } catch {
            throw AgentToolError.operationFailed("Could not rename '\(source.path)': \(error.localizedDescription)")
        }
    }
}

private enum FileTransferParameters {
    static let values = [
        "source": ToolParameter(type: "string", description: "Existing source path."),
        "destination": ToolParameter(type: "string", description: "Exact destination path, including the item name.")
    ]
}
