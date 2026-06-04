# Validation Procedures

Procedures to verify that the application meets its specifications and constraints.

## Latest Run: 2026-06-04 (smoke test)

### Backend round-trip (machine-verified)
- [x] **Server reachable**: `curl http://localhost:11434/api/tags` → REACHABLE.
- [x] **Model installed**: `gemma4:e4b` present in `ollama list`.
- [x] **Streaming generate**: `POST /api/generate` (`gemma4:e4b`, `stream:true`) → 5 chunks, assembled `SMOKE_OK`. This is the exact path `OllamaService` uses.
- [x] **App launches**: `open -a /Applications/DigDug.app` → process stays alive (PID confirmed).
- [x] **In-UI checks**: not machine-verifiable from the CLI (Screen Recording + Accessibility not granted), but author-confirmed manually — floating-window, live streaming render, and minimize/close all pass. See Manual Checks.

## Earlier Run: 2026-06-03

### Automated Checks
- [x] **Core Typecheck**: `swiftc -typecheck Sources/DigDugCore/Models/ChatMessage.swift Sources/DigDugCore/Services/OllamaService.swift` passed.
- [x] **App Typecheck**: `swiftc -typecheck -I /private/tmp Sources/DigDugApp/App/FloatingPanel.swift Sources/DigDugApp/UI/ContentView.swift Sources/DigDugApp/App/DigDugApp.swift` passed.
- [ ] **SwiftPM Tests**: `swift test` is blocked before source compilation by the local CommandLineTools/PackageDescription linker mismatch.
- [ ] **XCTest Typecheck**: Direct `swiftc` test typecheck is blocked because XCTest module discovery requires SwiftPM/Xcode in this environment.

### Ollama Checks
- [x] **Connectivity**: `curl http://localhost:11434/api/tags` returned installed model metadata.
- [x] **Prompt Execution**: Streaming `POST /api/generate` with `gemma4:e4b` returned non-empty streamed text.
- [x] **Installed Model**: `ollama list` confirms `gemma4:e4b` is installed.
- [x] **Missing Model Shape**: Ollama returns `{"error":"model '...' not found"}` for an unavailable model; the decoder accepts error-only chunks.

### Manual Checks
- [x] Launch: author runs the installed `DigDug.app` via Spotlight (Cmd+Space → "DigDug"), 2026-06-04.
- [x] `NSPanel` floats above other windows — author-confirmed 2026-06-04.
- [x] Streaming render + markdown/code in-UI — author-confirmed 2026-06-04.
- [x] Close (X) hides, app stays in Dock, reopen restores the in-memory chat — author-confirmed; by design (`windowShouldClose` → `orderOut`, `applicationShouldTerminateAfterLastWindowClosed` = false). Real quit = menu-bar → Quit.
- [x] CPU/RAM measured 2026-06-04. **Fresh untouched launch: ~91 MB RAM, ~0–2% CPU idle** (8 samples; `sample` shows the runloop parked in `runApp`) — meets the minimal-footprint constraint. Note: an instance with an active/used conversation showed a steady ~13% CPU / ~126 MB; not root-caused (see open item below).

## UI & Windowing
- [x] **Floating Window**: `NSPanel` stays above other windows — author-confirmed 2026-06-04.
- [x] **Visibility**: window visible, does not obscure critical elements — author-confirmed.
- [x] **Minimization**: minimize/close without crashing (X hides, app stays alive) — author-confirmed.

## Ollama Integration
- [x] **Connectivity**: app reaches `localhost:11434` — confirmed (`/api/tags` + live use).
- [x] **Prompt Execution**: a simple prompt returns non-empty streamed text — confirmed (`SMOKE_OK`).
- [ ] **Error Handling**: "Ollama not running" graceful path — decode-level tested; live failure UI not yet exercised.

## Performance
- [x] **Resource Usage** (2026-06-04): fresh idle ~91 MB / ~0–2% CPU ✅ minimal-footprint met.
- [ ] **Used-state CPU**: an instance with an active conversation held ~13% CPU steadily. Characterize and root-cause (suspect continuous redraw of a loaded transcript / gradient, or a lingering animation). Profile with `sample <pid>` while a conversation is loaded.
