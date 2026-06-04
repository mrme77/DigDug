# Decision Log

All architectural and design decisions.

## [2026-06-02] Initial Project Structure
**Context**: Setting up the repository to support both humans and AI agents, following "agentic development" principles.
**Decision**: Adopted a structured hierarchy with `docs/` for durable truth, `.agents/skills/` (mirrored to `.claude/skills/`) for procedural/knowledge skills, and `AGENTS.md` as the always-on entry point.
**Reason**: Enables progressive disclosure for agents, reducing context-window noise while providing high-fidelity instructions when needed.
**Status**: Accepted

## [2026-06-02] Local-only inference via Ollama
**Context**: The app needs an LLM backend.
**Decision**: Talk only to a local Ollama instance (`http://localhost:11434/api/generate`, streaming) with default model `gemma4:e4b`. The model default lives in `OllamaService.swift` and is the single source of truth.
**Reason**: Privacy, zero cost, no network dependency. Cloud providers are an explicit non-goal (`docs/spec.md`).
**Status**: Accepted

## [2026-06-04] Test runner instead of `swift test`
**Context**: This machine is Command Line Tools only (no Xcode.app); `swift test` compiles then silently skips (no `xctest` host).
**Decision**: Ship `DigDugTests` as an executable target (`DigDugTestRunner`) that calls the swift-testing entry point directly, with `Package.swift` `unsafeFlags` pointing at the CLT Frameworks dir.
**Reason**: Make tests actually run and report pass/fail. Revert to a plain `.testTarget` if full Xcode is installed.
**Status**: Accepted — details in `learnings.md`.

## [2026-06-04] MCP choice: `fetch`, not Playwright
**Context**: The course homework defaults to Playwright MCP, but that drives a browser.
**Decision**: DigDug is a native macOS app with no browser surface, so Playwright doesn't apply. Use the `fetch` MCP (`opencode.json`) for runtime HTTP/doc retrieval — including hitting the Ollama API (`/api/tags`) and Apple/Ollama docs.
**Reason**: Pick an MCP that matches the actual workflow rather than the default recommendation.
**Status**: Accepted
