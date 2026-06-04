# Project Progress

## Completed
- [x] Setup coordination files
- [x] Added Ollama streaming support, targeted error UI, chat bubbles, clear chat, and SwiftPM scaffolding.
- [x] Validated local Ollama connectivity and streaming generation.
- [x] Built and installed `DigDug.app`; author confirmed it launches via Spotlight (Cmd+Space → "DigDug") on 2026-06-04.
- [x] Pre-publish audit (2026-06-04): no secrets, no dead Swift code, markdown links resolve; removed orphaned `pdf_to_txt.sh`; app is local-only (`localhost:11434`, no external calls).

## In Flight
- [x] Confirm in-app UI behaviors: floating-above, minimize/close, live streaming render — author-confirmed 2026-06-04.
- [x] Measure CPU/RAM — fresh idle ~91 MB / ~0–2% CPU (passes minimal-footprint). Follow-up: ~13% CPU seen with a used conversation, not yet root-caused.
- [ ] Resolve `swift test` path (use `swift run DigDugTestRunner` meanwhile).

## Blocked
- `swift test` still skips silently under Command Line Tools (no `xctest` host). Not a launch blocker — the app builds and runs via `scripts/make_app.sh`.
