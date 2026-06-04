# Project Specification: Floating Chatbot

## Intent
Provide a lightweight, non-intrusive interface for interacting with local LLMs via Ollama, floating above the active workspace.

## Acceptance Criteria
_All met — author-confirmed 2026-06-04 (see `docs/validation.md`)._
- [x] A window appears on launch, floating above all other macOS windows.
- [x] User can type a prompt and receive a response from Ollama.
- [x] Chat history is displayed in the window.
- [x] Window can be minimized or closed (X hides to Dock/menu bar by design).
- [x] Response streaming is visible.

## Constraints
- **Local Only**: Must use local Ollama instance.
- **Performance**: Minimal CPU/RAM footprint; should not impact host system performance.
- **UI**: Must not obstruct primary work; must be easily dismissible.
- **Platform**: macOS only (Swift/SwiftUI).

## Non-Goals
- Cloud-based LLM integration (OpenAI, Anthropic, etc.).
- Complex plugin system or external integrations.
- Feature-rich markdown rendering (keep it simple/plain text initially).
