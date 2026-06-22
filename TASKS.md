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
- [x] Implement eight file tools with canonical path safety checks.
- [x] Implement streamed multi-turn agent loop, confirmation, cancellation, and loop guard.
- [x] Add local model and reasoning effort selectors.
- [x] Add tool status and destructive-action confirmation UI.
- [x] Add unit and fake-client agent tests.
- [ ] Repair the local CLT compiler/SDK pairing, then run `swift run DigDugTestRunner` and native smoke checks.
