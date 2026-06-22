# Project Tasks

## TODO
- [x] Implement Floating Chatbot App (Complete)
- [x] Decompose implementation into sub-tasks (Complete)
- [x] Implement response streaming for Ollama (Complete)
- [x] Add error handling for Ollama connectivity (Complete)
- [ ] Implement chat history persistence (Deferred — not needed; chat is in-memory by design)
- [x] Add UI/UX polish: chat bubbles and clear button (Complete)
- [x] Verify implementation against `docs/validation.md` (UI/streaming/Ollama/idle-perf confirmed)
- [ ] Investigate ~13% CPU with a used conversation (idle baseline is fine); profile with `sample`
- [x] Implement typed Ollama tool schemas and file tool registry.
- [x] Implement eleven tools (eight core file tools, plus metadata, hash, and organize tools) with canonical path safety checks.
- [x] Implement streamed multi-turn agent loop, confirmation, cancellation, and loop guard.
- [x] Add local model and reasoning effort selectors.
- [x] Add tool status and destructive-action confirmation UI.
- [x] Add unit and fake-client agent tests.
- [x] Run `DigDugTestRunner` and the full app build with the restricted-runner SwiftPM flags.
- [x] Add metadata and SHA-256 duplicate inspection tools.
- [x] Add typed organization plans with one batch confirmation and no delete representation.
- [x] Add deterministic execution, collision checks, and rollback.
- [x] Add organizer plan preview and execution report UI.
- [x] Add organizer happy-path, safety, hash, schema, and injected rollback tests.
- [ ] Manually smoke-test disposable-file organization in the installed app.
- [ ] Open a draft PR with the Sasamen contribution trailer.
