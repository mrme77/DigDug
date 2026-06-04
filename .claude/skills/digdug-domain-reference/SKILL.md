---
name: digdug-domain-reference
description: Use to answer questions about DigDug's data model, module structure, and how a prompt flows from UI to Ollama and back. Triggers on "how does the chat work", "where is X handled", "what's the data model", "how does streaming work", "which file owns the window", or before making a structural change. Knowledge/reference only — for building or running use setup-and-run; for design use impeccable.
---

# digdug-domain-reference

Knowledge skill: the map of what lives where and how a message moves through the app.

## Domain object
`ChatMessage` (`Sources/DigDugCore/Models/ChatMessage.swift`) — a single turn (role + text + identity). The chat is an ordered list of these; the assistant message is appended empty and filled as tokens stream.

## Modules
- **`DigDugCore`** (no UI, `Sendable`) — pure logic, unit-tested.
  - `Models/ChatMessage.swift`
  - `Services/OllamaService.swift` — HTTP client. `init(endpoint:model:)` defaults `http://localhost:11434/api/generate` + `gemma4:e4b`. Streams via `AsyncThrowingStream`; decodes per-chunk JSON; maps failures to `OllamaError` (`.notReachable`, `.modelMissing(name)`).
- **`DigDugApp`** (executable, depends on Core + `MarkdownUI`).
  - `App/DigDugApp.swift` — app entry, `.regular` activation policy, menu-bar item, reopen handling.
  - `App/FloatingPanel.swift` — the always-on-top `.floating` `NSPanel`.
  - `UI/ContentView.swift` — chat view, input, streaming render, forces `.dark`.
  - `UI/Theme.swift` — design tokens (`Palette`, `Metrics`, `Theme.digDug`); `@MainActor` (not `Sendable` under Swift 6).
- **`DigDugTests`** (executable runner, not a test target — see `learnings.md`).

## Prompt round-trip
1. User submits in `ContentView` → append user `ChatMessage` + an empty assistant one.
2. Call `OllamaService.stream(prompt:)` → `POST /api/generate` with `stream: true`.
3. Each decoded chunk appends text to the assistant message; UI re-renders live.
4. Error chunk or transport failure → `OllamaError` → targeted error UI (no crash).

## Key constraints (from `docs/spec.md`)
- **Local only** — no cloud providers, ever.
- Minimal CPU/RAM; must not obstruct primary work; easily dismissible.
- macOS only; plain-ish markdown (no heavy plugin system).

## Where to look next
- Design/register decisions → `PRODUCT.md`, `learnings.md` (UI design system).
- Toolchain traps → `learnings.md`.
- Decisions/why → `docs/decisions.md`.
