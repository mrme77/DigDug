# Agent Handoff

## Last Completed Task
Aligned the AI operating surface with the *Elite AI-Assisted Coding* course rubric: operational `AGENTS.md`, project `CLAUDE.md`, `README.md`, two project skills (`setup-and-run`, `digdug-domain-reference`), `fetch` MCP, resolved model name to `gemma4:e4b`, filled decision log.

## Next Task
Run the fresh-session validation loop (`docs/validation.md`): from a clean session ask which model/build/test commands to use, where durable docs live, which skill smoke-tests the app, and what is out of bounds. Then resolve the SwiftPM/Xcode toolchain blocker so `swift run DigDugTestRunner` and a real app launch can be verified end-to-end. Implement chat-history persistence (`TASKS.md`).

## Warnings/Notes for Next Agent
- Never trust `swift test` here — use `swift run DigDugTestRunner`.
- Don't add cloud LLM providers (hard non-goal) or strip `Package.swift` `unsafeFlags`.
- `bash scripts/make_app.sh --install` writes to `/Applications` — ask first.
