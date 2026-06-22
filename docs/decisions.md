# Decision Log

All architectural and design decisions.

## [2026-06-02] Initial Project Structure
**Context**: Setting up the repository to support both humans and AI agents, following "agentic development" principles.
**Decision**: Adopted a structured hierarchy with `docs/` for durable truth, `.agents/skills/` (mirrored to `.claude/skills/`) for procedural/knowledge skills, and `AGENTS.md` as the always-on entry point.
**Reason**: Enables progressive disclosure for agents, reducing context-window noise while providing high-fidelity instructions when needed.
**Status**: Accepted

## [2026-06-02] Local-only inference via Ollama
**Context**: The app needs an LLM backend.
**Decision**: Talk only to a local Ollama instance (`http://localhost:11434/api`). Agent chat streams through `/api/chat`; model discovery uses `/api/tags`. The default model remains `gemma4:e4b` in `OllamaService.swift`.
**Reason**: Privacy, zero cost, no network dependency. Cloud providers are an explicit non-goal (`docs/spec.md`).
**Status**: Accepted

## [2026-06-22] Typed local agent loop and capability-aware model controls
**Context**: File organization requires Ollama tool calls, multi-turn tool results, destructive-action confirmation, cancellation, and model-specific thinking controls.
**Decision**: Use a `Sendable` `JSONValue` instead of `[String: Any]`; stream chat and tool calls through `AgentRunner`; inject async confirmation; cap tool rounds at 10; and filter model discovery to local completion models. The UI enables tools and reasoning only when Ollama advertises those capabilities. Reasoning traces are retained for Ollama history but not displayed as chain-of-thought.
**Reason**: This preserves Swift 6 concurrency guarantees, the local-only product contract, visible streaming, and explicit control over filesystem mutations.
**Status**: Accepted

## [2026-06-22] Centralized file path safety
**Context**: Every file tool must expand home paths and resolve symlinks before access checks, without duplicating security logic.
**Decision**: Route tool paths through `PathPolicy`. Deny writes to macOS/Unix system roots, deny reads from common credential directories, reject relative paths, and require confirmation for deletion and cross-directory moves.
**Reason**: Canonical checks prevent simple path and symlink bypasses while still allowing useful work in the user home directory and mounted volumes.
**Status**: Accepted

## [2026-06-04] Test runner instead of `swift test`
**Context**: This machine is Command Line Tools only (no Xcode.app); `swift test` compiles then silently skips (no `xctest` host).
**Decision**: Ship `DigDugTests` as an executable target (`DigDugTestRunner`) that calls the swift-testing entry point directly, with `Package.swift` `unsafeFlags` pointing at the CLT Frameworks dir.
**Reason**: Make tests actually run and report pass/fail. Revert to a plain `.testTarget` if full Xcode is installed.
**Status**: Accepted — details in `learnings.md`.

## [2026-06-04] Published as a public GitHub repo
**Context**: Ready to share the project and its agentic operating surface.
**Decision**: Publish to <https://github.com/mrme77/DigDug> (public). Remove the copyrighted `course-reader.txt` from the tree/history and gitignore it; credit Eleanor Berger's *Elite AI-Assisted Coding* course as inspiration in the README.
**Reason**: Share the work without redistributing third-party copyrighted material.
**Status**: Accepted — see `learnings.md` for the history-reconciliation details.

## [2026-06-04] MCP choice: `fetch`, not Playwright
**Context**: The course homework defaults to Playwright MCP, but that drives a browser.
**Decision**: DigDug is a native macOS app with no browser surface, so Playwright doesn't apply. Use the `fetch` MCP (`opencode.json`) for runtime HTTP/doc retrieval — including hitting the Ollama API (`/api/tags`) and Apple/Ollama docs.
**Reason**: Pick an MCP that matches the actual workflow rather than the default recommendation.
**Status**: Accepted
