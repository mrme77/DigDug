# Project Progress

## Latest Delivery: 2026-10-25

- [x] Merged [PR #10](https://github.com/mrme77/DigDug/pull/10): native multiline composer, plain-text response copying, verbatim code copying, user-controlled scroll following, and request isolation after Stop.
- [x] Passed 35 Core tests and 8 native chat interaction tests; debug and release builds passed with the installed macOS 26.5 SDK and native build system.
- [x] Installed merged revision `e6bd22a` at `/Applications/DigDug.app`, local build `20261025.1447`, after explicit approval. Signature verification and release/installed executable hash comparison passed.
- [x] Inspected the review app layout and multiline pasting. Full post-install live chat and manual streaming-scroll checks remain pending.

## Earlier Completed Work
- [x] Setup coordination files
- [x] Added Ollama streaming support, targeted error UI, chat bubbles, clear chat, and SwiftPM scaffolding.
- [x] Validated local Ollama connectivity and streaming generation.
- [x] Built and installed `DigDug.app`; author confirmed it launches via Spotlight (Cmd+Space → "DigDug") on 2026-06-04.
- [x] Pre-publish audit (2026-06-04): no secrets, no dead Swift code, markdown links resolve; removed orphaned `pdf_to_txt.sh`; app is local-only (`localhost:11434`, no external calls).
- [x] Confirmed in-app UI behaviors: floating-above, minimize/close, live streaming render — author-confirmed 2026-06-04.
- [x] Measured CPU/RAM: fresh idle ~91 MB / ~0–2% CPU (passes minimal-footprint).
- [x] Published to GitHub: <https://github.com/mrme77/DigDug> (public, 2026-06-04). `course-reader.txt` kept out of history; Eleanor Berger credited in README. Added app icon + chat/dock screenshots to README.
- [x] Added typed, Sendable tool schemas and eleven tools including core file tools, metadata inspection, hash verification, and file organizer (2026-06-22).
- [x] Added streaming Ollama chat/tool loop with confirmations, cancellation, and an initial 10-round guard; current budgets are 30 productive / 60 total rounds.
- [x] Added local model discovery, capability-aware model/reasoning menus, tool activity, confirmation sheet, and stop action.
- [x] Added deterministic tests for file operations, safety paths, request schemas, confirmations, and loop guard.
- [x] Added `get_file_metadata` and streaming SHA-256 `hash_file` inspection tools.
- [x] Added a clean-room organizer policy that requires inventory, verified duplicates, and uncertain-item review.
- [x] Added typed batch plans with root containment, symlink/collision/duplicate checks, a 100-file limit, one approval, and rollback.
- [x] Added plan-preview and structured completion/rollback report UI.
- [x] Passed the complete app build and 29 authoritative tests on 2026-06-22, including injected rollback failure; latest counts are recorded above.
- [x] Opened feature branch as a draft PR for author review; merged to main as PR #1 (2026-06-22).

## In Flight
- [ ] Root-cause ~13% CPU seen with a used conversation (idle baseline is fine).
- [ ] Full post-install live chat/scroll verification and standard packaging compatibility on the current host.
- [ ] Per-turn tool/report retention and read-deduplication invalidation after mutations.
- [ ] Manually smoke-test the organizer against disposable files in the native panel.

## Blocked
- `swift test` still skips silently under Command Line Tools (no `xctest` host). Not a launch blocker — the app builds and runs via `scripts/make_app.sh`.
- The restricted automation sandbox requires `--disable-sandbox` plus a writable Clang module cache. The current macOS 27 SDK also lacks `SwiftUIMacros`; the installed macOS 26.5 SDK and native build system work. Standard packaging needs the same workaround and failed sandboxed icon generation. See `learnings.md`.
