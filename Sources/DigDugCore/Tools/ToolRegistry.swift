import Foundation

/// Thread-safe registry of tools available to the local model.
public final class ToolRegistry: @unchecked Sendable {
    public static let shared = ToolRegistry()

    private let lock = NSLock()
    private var tools: [String: any AgentTool] = [:]

    public init() {}

    /// Adds or replaces a tool by its stable function name.
    public func register(_ tool: any AgentTool) {
        lock.withLock {
            tools[tool.name] = tool
        }
    }

    /// Registers the complete built-in file tool catalog.
    public func registerFileTools() {
        let tools: [any AgentTool] = [
            ListDirectoryTool(),
            CreateFolderTool(),
            MoveItemTool(),
            CopyItemTool(),
            DeleteItemTool(),
            RenameItemTool(),
            ReadFileTool(),
            SearchFilesTool(),
            GetFileMetadataTool(),
            HashFileTool(),
            OrganizeFilesTool()
        ]
        tools.forEach(register)
    }

    /// Returns the tool registered under a function name.
    public func tool(named name: String) -> (any AgentTool)? {
        lock.withLock { tools[name] }
    }

    /// Returns all tools in deterministic name order.
    public func allTools() -> [any AgentTool] {
        lock.withLock {
            tools.values.sorted { $0.name < $1.name }
        }
    }

    /// Serializes all registered tools into Ollama function schemas.
    public func ollamaSchema() -> [OllamaToolSchema] {
        allTools().map { $0.ollamaSchema() }
    }
}
