---
name: digdug-domain-reference
description: Use to answer questions about DigDug's data model, module structure, and how a prompt flows from UI to Ollama and back. Triggers on "how does the chat work", "where is X handled", "what's the data model", "how does streaming work", "which file owns the window", or before making a structural change. Knowledge/reference only — for building or running use setup-and-run; for design use impeccable.
---

# digdug-domain-reference

Knowledge skill: the map of what lives where and how a message moves through the app.

## Domain object
`ChatMessage` (`Sources/DigDugCore/Models/ChatMessage.swift`) — a single turn (role + text + identity). The chat is an ordered list of these; the assistant message is appended empty and filled as tokens stream.

`OllamaMessage` and `JSONValue` carry Sendable chat/tool history inside Core. `ChatViewModel` owns the display transcript, Ollama history, model selection, active task, tool activity, and pending confirmation.

## Modules
- **`DigDugCore`** (no UI, `Sendable`) — pure logic, unit-tested.
  - `Models/ChatMessage.swift`, `Models/OllamaModels.swift`
  - `Services/OllamaService.swift` — local HTTP client. Uses `/api/chat` for streamed messages/tool calls and `/api/tags` for installed model discovery. The default remains `gemma4:e4b`; cloud-backed model entries are filtered out.
  - `Services/AgentRunner.swift` — multi-turn tool loop, confirmation callback, cancellation, 30 productive / 60 total round budgets, read-only deduplication, and repeated-failure guards.
  - `Services/OrganizationPlanValidator.swift`, `OrganizationPlanExecutor.swift` — typed batch preflight, execution, and rollback.
  - `Skills/FileOrganizerSkill.swift` — concise model workflow for inventory, metadata, hashing, review, and one batch submission.
  - `Tools/` — typed protocol/JSON schema, file inspection and mutation tools, organizer batch tool, registry, and canonical path safety.
- **`DigDugApp`** (executable, depends on Core + `MarkdownUI`).
  - `App/DigDugApp.swift` — app entry, `.regular` activation policy, menu-bar item, reopen handling.
  - `App/FloatingPanel.swift` — the always-on-top `.floating` `NSPanel`.
  - `UI/ChatViewModel.swift` — owns agent state, isolates callbacks/confirmations by turn identity, and bridges Core events to SwiftUI. A stopped turn cannot modify a newer turn.
  - `UI/ContentView.swift` — panel composition, model controls, transcript, and input.
  - `UI/AgentStatusView.swift`, `ConfirmationSheet.swift`, `OrganizationPlanPreviewView.swift`, `OrganizationReportView.swift` — activity, batch review, safety approval, and result reporting.
  - `UI/MessageComposer.swift` — native `NSTextView`: Enter sends, Shift+Enter inserts a newline, and no global Return shortcut triggers Stop.
  - `UI/CopyResponseButton.swift` — MarkdownUI plain-text response copying and verbatim code-block copying.
  - `UI/TranscriptScrollObserver.swift` — native user-scroll observation; scrolling away pauses following, Jump to latest resumes it.
  - `UI/Theme.swift` — design tokens (`Palette`, `Metrics`, `Theme.digDug`); `@MainActor` (not `Sendable` under Swift 6).
- **`DigDugTests`** (executable runner, not a test target — see `learnings.md`): Core suites in `Tests/`.
- **`UITests/`** — native chat interaction suites; `scripts/test_chat_ui.sh` links the actual app objects into the standalone runner without changing package boundaries.

The transcript/history are in memory only. Tool activities and the organization report remain visible until the next turn or clear; they are not archived per turn.

## Prompt round-trip
1. `ChatViewModel` appends the user turn and starts `AgentRunner` with Ollama history plus selected model/reasoning capabilities.
2. `OllamaService.chatStream` posts messages and schemas to `/api/chat` with `stream: true`.
3. Content chunks render immediately. Tool calls become status events, execute through `ToolRegistry`, and return `role: tool` messages to Ollama.
4. Single moves/deletion await `ConfirmationRequest`; multi-file organization submits one typed plan for one batch approval and deterministic execution.
5. The loop ends on a plain assistant response, completed organization, a repeated-failure guard, or the 30 productive / 60 total round budgets. Errors become targeted system messages.

## Key constraints (from `docs/spec.md`)
- **Local only** — no cloud providers, ever.
- Minimal CPU/RAM; must not obstruct primary work; easily dismissible.
- macOS only; plain-ish markdown (no heavy plugin system).

## Where to look next
- Design/register decisions → `PRODUCT.md`, `learnings.md` (UI design system).
- Toolchain traps → `learnings.md`.
- Decisions/why → `docs/decisions.md`.
