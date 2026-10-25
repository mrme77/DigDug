# Agent Context

## Current Delivery
- Chat improvements merged through PR #10 on 2026-10-25, revision `e6bd22a`: Enter/Shift+Enter, plain-text/code copying, scroll following, and isolated cancellation.
- Latest verified tests: 35 Core + 8 native chat tests; debug/release builds passed. Installed `/Applications/DigDug.app`, build `20261025.1447`, has verified ad-hoc signature and matching release executable hash. Post-install launch/live chat remains unverified.

## Essential Constraints
- Local-only Ollama; default model `gemma4:e4b` is defined in `OllamaService.swift`.
- Agent budgets are 30 productive / 60 total rounds. File organization uses typed review, root checks, no deletes, a 100-mapping limit, and rollback.
- `ChatViewModel` rejects callbacks from obsolete turns. Chat is in memory; tool/report history is replaced on the next turn.
- Keep `OllamaService` immutable/Sendable and tool arguments Codable/Sendable.

## Build and Test
- Core tests: `swift run DigDugTestRunner`; chat tests: `bash scripts/test_chat_ui.sh`. Never trust `swift test` on this CLT-only host.
- Default macOS 27 SDK lacks `SwiftUIMacros`. Use macOS 26.5 SDK/native-build-system flags from README and `learnings.md`, plus a writable Clang cache in the sandbox.
- Standard packaging does not accept `DIGDUG_SDK_PATH`; sandboxed icon generation also failed. See the recorded packaging workaround before rebuilding a bundle.

Canonical rules and permission boundaries are in [AGENTS.md](../AGENTS.md). Current evidence is in [docs/validation.md](../docs/validation.md); remaining work is in [TASKS.md](../TASKS.md).
