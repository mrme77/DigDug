# Project Progress

## Completed
- [x] Setup coordination files
- [x] Added Ollama streaming support, targeted error UI, chat bubbles, clear chat, and SwiftPM scaffolding.
- [x] Validated local Ollama connectivity and streaming generation.
- [x] Built and installed `DigDug.app`; author confirmed it launches via Spotlight (Cmd+Space → "DigDug") on 2026-06-04.
- [x] Pre-publish audit (2026-06-04): no secrets, no dead Swift code, markdown links resolve; removed orphaned `pdf_to_txt.sh`; app is local-only (`localhost:11434`, no external calls).
- [x] Confirmed in-app UI behaviors: floating-above, minimize/close, live streaming render — author-confirmed 2026-06-04.
- [x] Measured CPU/RAM: fresh idle ~91 MB / ~0–2% CPU (passes minimal-footprint).
- [x] Published to GitHub: <https://github.com/mrme77/DigDug> (public, 2026-06-04). `course-reader.txt` kept out of history; Eleanor Berger credited in README. Added app icon + chat/dock screenshots to README.
- [x] Added typed, Sendable tool schemas and eight sandboxed file tools (2026-06-22).
- [x] Added streaming Ollama chat/tool loop with confirmations, cancellation, and 10-round guard.
- [x] Added local model discovery, capability-aware model/reasoning menus, tool activity, confirmation sheet, and stop action.
- [x] Added deterministic tests for file operations, safety paths, request schemas, confirmations, and loop guard.

## In Flight
- [ ] Root-cause ~13% CPU seen with a used conversation (idle baseline is fine).
- [ ] Resolve `swift test` path (use `swift run DigDugTestRunner` meanwhile).
- [ ] Run the new authoritative test suite and app smoke test after repairing the Command Line Tools compiler/SDK mismatch.

## Blocked
- `swift test` still skips silently under Command Line Tools (no `xctest` host). Not a launch blocker — the app builds and runs via `scripts/make_app.sh`.
- On 2026-06-22, all Swift files passed parser validation, but compilation is blocked before source type checking because CLT's compiler is `swiftlang-6.3.2.1.108` while its SDK modules were built with `swiftlang-6.3.2.1.2`.
