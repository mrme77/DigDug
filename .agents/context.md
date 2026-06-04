# Agent Context

## Decisions Made
- Local-only Ollama, model `gemma4:e4b` (source of truth: `OllamaService.swift`).
- Tests run via `swift run DigDugTestRunner`, never `swift test` (CLT-only host limitation).
- App bundle built with `bash scripts/make_app.sh`; no Xcode required.

## Blockers
- `swift test` and SwiftPM manifest linking can fail under a partially-updated CLT — see `learnings.md` for the reinstall fix. Tracked in `progress.md`.

## Key Project Knowledge
- Canonical commands, paths, and boundaries live in `AGENTS.md` (read first).
- Toolchain traps and the UI design system live in `learnings.md`.
- `OllamaService` must stay `Sendable` with immutable stored properties (Swift 6 strict concurrency).
