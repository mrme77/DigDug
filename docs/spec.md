# Project Specification: Floating Local Agent

## Intent
Provide a lightweight, non-intrusive interface for interacting with local LLMs via Ollama and safely organizing files, floating above the active workspace.

## Acceptance Criteria
_Latest automated verification: 2026-10-25, with 35 Core tests and 8 native chat interaction tests. Manual checks and installation evidence are tracked in [validation.md](validation.md)._
- [x] A window appears on launch, floating above all other macOS windows.
- [x] User can type a prompt and receive a response from Ollama.
- [x] In-memory chat history is displayed in the window and survives hiding/reopening the panel, but not quitting the app.
- [x] Enter sends, Shift+Enter inserts a newline, and multiline pasted text remains editable without submission.
- [x] Assistant responses have plain-text copy controls; code blocks have controls that preserve code whitespace.
- [x] Scrolling up pauses following streamed output; Jump to latest resumes following.
- [x] Late events and completion from a cancelled turn cannot change the active turn.
- [x] Window can be minimized or closed (X hides to Dock/menu bar by design).
- [x] Response streaming is visible.
- [x] Installed local completion models can be selected in the panel.
- [x] Reasoning effort is selectable when the model advertises thinking support.
- [x] Tool-capable models can list, search, read, create, copy, move, rename, trash, and delete files.
- [x] Tool activity and organization reports remain reviewable after completion until the next turn or conversation clear; per-turn archival is not implemented.
- [x] Cross-directory moves and all delete operations require user confirmation.
- [x] The active agent task can be cancelled from the input bar.
- [x] Agent execution allows at most 30 productive tool-call rounds and 60 total rounds, including deduplicated rounds, with earlier guards for repeated failures.
- [x] Protected system writes and credential-directory reads are rejected after path canonicalization.
- [x] File organization inventories and inspects metadata before proposing mutations.
- [x] Exact duplicates require matching SHA-256 hashes; duplicates are never deleted automatically.
- [x] Multi-file organization is submitted as one typed mapping plan with reasons and manual-review items.
- [x] The complete plan is shown once before execution; approving it authorizes no deletions.
- [x] Plans reject source-root escapes, destination-root escapes, symlinks, existing destinations, duplicate mappings, and batches over 100 files.
- [x] Batch execution creates required folders, rolls prior moves back after a failure, and reports completion or rollback state.

## Constraints
- **Local Only**: Must use local Ollama instance.
- **Performance**: Minimal CPU/RAM footprint; should not impact host system performance.
- **UI**: Must not obstruct primary work; must be easily dismissible.
- **Platform**: macOS only (Swift/SwiftUI).

## Non-Goals
- Cloud-based LLM integration (OpenAI, Anthropic, etc.).
- External plugin marketplace or arbitrary third-party tool loading.
- Feature-rich markdown rendering (keep it simple/plain text initially).
