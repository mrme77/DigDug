# Project Plan

## Current Objective
Implement and validate DigDug's local file-agent workflow with model selection, reasoning controls, confirmations, cancellation, and durable documentation.

## Intended Sequence of Work
1. Implement typed file tools, safety policy, and registry.
2. Migrate inference to streaming `/api/chat` with a guarded multi-turn tool loop.
3. Add model/reasoning controls, tool status, confirmation, and cancellation UI.
4. Add deterministic unit tests and run the authoritative runner.
5. Smoke-test Ollama and the native panel; update validation.

## Main Checkpoints
- [x] Core tool infrastructure and eight file tools implemented.
- [x] Streaming agent loop, confirmation, cancellation, and loop guard implemented.
- [x] Model discovery, capability-aware reasoning, and agent UI implemented.
- [x] Deterministic tool, safety, schema, confirmation, and loop tests authored.
- [ ] Authoritative build/test run blocked by the local compiler/SDK mismatch recorded in `learnings.md`.
- [ ] Native panel and real tool-call smoke test pending a healthy Command Line Tools installation and running Ollama.
