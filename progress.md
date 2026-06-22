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
- [x] Added `get_file_metadata` and streaming SHA-256 `hash_file` inspection tools.
- [x] Added a clean-room organizer policy that requires inventory, verified duplicates, and uncertain-item review.
- [x] Added typed batch plans with root containment, symlink/collision/duplicate checks, a 100-file limit, one approval, and rollback.
- [x] Added plan-preview and structured completion/rollback report UI.
- [x] Passed the complete app build and 29 authoritative tests, including injected rollback failure.

## In Flight
- [ ] Root-cause ~13% CPU seen with a used conversation (idle baseline is fine).
- [ ] Resolve `swift test` path (use `swift run DigDugTestRunner` meanwhile).
- [ ] Manually smoke-test the organizer against disposable files in the native panel.
- [ ] Open the feature branch as a draft PR for author review.

## Blocked
- `swift test` still skips silently under Command Line Tools (no `xctest` host). Not a launch blocker — the app builds and runs via `scripts/make_app.sh`.
- The restricted automation sandbox requires `--disable-sandbox` plus a writable Clang module cache for SwiftPM. Builds and tests pass with those flags; normal user Terminal sessions may use the canonical commands.
