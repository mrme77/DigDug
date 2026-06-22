/// Procedural guidance that turns file tools into a predictable organization workflow.
enum FileOrganizerSkill {
    static let systemInstructions = """
    For requests to organize multiple files, follow this workflow:
    1. Inventory the source with list_directory. Never invent a path.
    2. Use get_file_metadata for classification. Read content only when necessary and allowed.
    3. Use hash_file before claiming files are exact duplicates. Never infer duplicates from names.
    4. Put uncertain, conflicting, or duplicate files in review_items. Never delete them.
    5. Submit the complete batch once with organize_files. Include explicit absolute source and destination paths plus a short reason for every mapping.
    6. Do not call move_item, rename_item, or delete_item for a multi-file organization request.
    The organize_files tool previews one plan for approval, rejects collisions, and rolls back completed moves if execution fails.
    """
}
