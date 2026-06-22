# Project Specification: Floating Local Agent

## Intent
Provide a lightweight, non-intrusive interface for interacting with local LLMs via Ollama and safely organizing files, floating above the active workspace.

## Acceptance Criteria
_All met — author-confirmed 2026-06-04 (see `docs/validation.md`)._
- [x] A window appears on launch, floating above all other macOS windows.
- [x] User can type a prompt and receive a response from Ollama.
- [x] Chat history is displayed in the window.
- [x] Window can be minimized or closed (X hides to Dock/menu bar by design).
- [x] Response streaming is visible.
- [x] Installed local completion models can be selected in the panel.
- [x] Reasoning effort is selectable when the model advertises thinking support.
- [x] Tool-capable models can list, search, read, create, copy, move, rename, trash, and delete files.
- [x] Tool activity is visible and remains reviewable after completion.
- [x] Cross-directory moves and all delete operations require user confirmation.
- [x] The active agent task can be cancelled from the input bar.
- [x] Agent turns stop after 10 tool-call rounds.
- [x] Protected system writes and credential-directory reads are rejected after path canonicalization.

## Constraints
- **Local Only**: Must use local Ollama instance.
- **Performance**: Minimal CPU/RAM footprint; should not impact host system performance.
- **UI**: Must not obstruct primary work; must be easily dismissible.
- **Platform**: macOS only (Swift/SwiftUI).

## Non-Goals
- Cloud-based LLM integration (OpenAI, Anthropic, etc.).
- External plugin marketplace or arbitrary third-party tool loading.
- Feature-rich markdown rendering (keep it simple/plain text initially).
