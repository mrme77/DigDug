# AGENTS.md — DigDug

Native macOS floating chat panel (SwiftUI/AppKit) that streams from a **local Ollama** model. Onboarding for agents: read this first, then the durable docs below.

## What it is
Always-on-top `NSPanel` you summon over other apps, ask a question, read a markdown/code answer, copy, dismiss. See `PRODUCT.md` for design intent, `docs/spec.md` for the contract.

## Canonical commands
| Goal | Command | Notes |
|---|---|---|
| Run app (dev) | `swift run DigDug` | Launches the panel directly |
| Build `.app` bundle | `bash scripts/make_app.sh` | → `build/DigDug.app`; add `--install` to copy to `/Applications`. Generates icon, writes Info.plist, ad-hoc signs. No Xcode needed. |
| **Run tests** | `swift run DigDugTestRunner` | **NOT `swift test`** — see below |
| Core typecheck | `swift build --target DigDugCore` | Covers the complete core module. |

**`swift test` is broken here and lies.** This machine is Command Line Tools only (no Xcode.app). CLT has no `xctest` host, so `swift test` compiles then **silently skips** — exit 0 even on failure. Always use `swift run DigDugTestRunner` (swift-testing entry point, runs for real). Full details + recovery in `learnings.md`.

## Runtime dependency: Ollama
- API base: `http://localhost:11434/api`; streaming chat uses `/chat`, model discovery uses `/tags`.
- Model: **`gemma4:e4b`** (default in `Sources/DigDugCore/Services/OllamaService.swift`). This is the single source of truth — match it everywhere.
- Preflight: `curl http://localhost:11434/api/tags` ; install model with `ollama pull gemma4:e4b`.
- Only local completion models are selectable. Entries with `remote_host` are filtered out.

## Key paths
- `Sources/DigDugCore/` — chat/organization models, `OllamaService`, `AgentRunner`, organizer policy, typed file tools, transactional plan executor, registry, and path safety policy (`Sendable`; streaming via `AsyncThrowingStream`).
- `Sources/DigDugApp/` — `App/` (`DigDugApp.swift`, `FloatingPanel.swift`), `UI/` (`ContentView.swift`, `Theme.swift` = design tokens).
- `scripts/` — `make_app.sh`, icon generators.
- `Package.swift` — Swift 6, macOS 13+, dep `swift-markdown-ui` 2.4.x. Carries CLT-only `unsafeFlags` for the test runner; don't strip without reading the comment.

## Durable docs
- `docs/spec.md` — intent, acceptance criteria, constraints, non-goals (the contract).
- `PRODUCT.md` — design register / anchor for the `impeccable` skill.
- `docs/decisions.md` — architectural decisions (ADR).
- `docs/validation.md` — verification checklist + last run.
- `docs/reference-index.md` — external doc links.
- `plan.md` / `progress.md` / `TASKS.md` — live work state.
- `learnings.md` — fragile commands, toolchain traps. **Read before debugging build/test.**

## Skills (`.agents/skills/`, mirrored to `.claude/skills/`)
- `setup-and-run` — procedural: build, launch, smoke-test app + Ollama.
- `digdug-domain-reference` — knowledge: data model + module map.
- `impeccable` — community frontend/design skill (anchored to `PRODUCT.md`).

## Boundaries
**Always**
- Run `swift run DigDugTestRunner` after touching `Sources/`; never trust `swift test`.
- Keep `OllamaService` properties immutable `Sendable` (Swift 6 strict concurrency).
- Keep tool arguments `Codable` and `Sendable`; do not replace `JSONValue` with `[String: Any]`.
- Preserve confirmation for cross-directory moves and all delete operations.
- Preserve the organizer boundary: one typed batch confirmation, no deletes, maximum 100 mappings, canonical root checks, collision rejection, and rollback.
- Update the relevant durable doc when you learn a non-obvious fact.

**Ask first**
- Adding a dependency or bumping `swift-markdown-ui`.
- Changing the model, endpoint, or window/activation policy.
- Editing `Package.swift` `unsafeFlags`.

**Never**
- Commit secrets, or add cloud LLM providers (local-only is a hard constraint — `docs/spec.md`).
- `bash scripts/make_app.sh --install` without explicit ask (writes to `/Applications`).
- Touch `.claude/` / `.agents/` `impeccable/` vendor skill internals.
