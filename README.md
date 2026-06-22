# DigDug

<p align="center">
  <img src="Resources/DigDug.png" alt="DigDug app icon" width="128" height="128">
</p>

A lightweight, always-on-top macOS agent that talks to **local Ollama** models. It can stream answers and organize files through confirmed, sandboxed tool calls. No cloud models are listed or used, and inference stays on your machine.

Built with Swift 6 / SwiftUI + AppKit (`NSPanel`). Markdown rendered via `swift-markdown-ui`.

## Screenshots

<p align="center">
  <img src="Resources/screenshot-chat.png" alt="DigDug chat panel answering a question with the local Gemma model" width="460">
</p>

<p align="center">
  <img src="Resources/screenshot-dock.png" alt="DigDug in the macOS Dock" width="200">
  <br>
  <em>Floating chat panel (left); lives in the Dock and menu bar (right).</em>
</p>

## Requirements
- macOS 13+
- Swift toolchain (Command Line Tools is enough — full Xcode not required)
- [Ollama](https://ollama.com) running locally with the model pulled:
  ```sh
  ollama pull gemma4:e4b
  ollama serve   # or the menu-bar app; listens on http://localhost:11434
  ```

DigDug discovers installed local chat models from Ollama. The default remains `gemma4:e4b`; models advertise whether tool calling and reasoning controls are available.

## Agent features

- Select any installed local completion model from the panel.
- Set reasoning effort for models that advertise thinking support.
- List, search, read, create, copy, move, rename, trash, or delete files.
- Review live tool activity, confirm destructive actions, or stop the task.
- Block system writes and credential-directory reads after resolving symlinks.
- Organize up to 100 files through one reviewable mapping plan; uncertain and duplicate files remain untouched.
- Verify exact duplicates with local SHA-256 hashing and roll completed moves back if a later move fails.

## Run
```sh
swift run DigDug                 # launch the panel directly
# or build a double-clickable app:
bash scripts/make_app.sh         # → build/DigDug.app
bash scripts/make_app.sh --install   # also copies to /Applications
```

## Test
```sh
swift run DigDugTestRunner       # ✅ runs swift-testing for real
# swift test                     # ❌ silently skips under CLT-only — do not use
```
Why: Command Line Tools has no `xctest` host, so `swift test` exits 0 without running. The `DigDugTestRunner` executable calls the swift-testing entry point directly. See `learnings.md`.

## Layout
| Path | Purpose |
|---|---|
| `Sources/DigDugCore/` | Ollama chat client, agent loop, typed tools, and safety policy |
| `Sources/DigDugApp/` | App lifecycle, floating panel, SwiftUI views, `Theme.swift` tokens |
| `scripts/` | `make_app.sh`, icon generation |
| `Tests/` | swift-testing suites + `Runner.swift` |
| `docs/` | spec, decisions, validation, reference index |

## AI operating surface
This repo is set up for agentic development (per *Elite AI-Assisted Coding*):

| Surface | File / location |
|---|---|
| Rules (always-on) | [`AGENTS.md`](./AGENTS.md) — canonical; [`CLAUDE.md`](./CLAUDE.md) defers to it |
| Spec (the contract) | [`docs/spec.md`](./docs/spec.md) |
| Design intent | [`PRODUCT.md`](./PRODUCT.md) |
| Decisions (ADR) | [`docs/decisions.md`](./docs/decisions.md) |
| Validation | [`docs/validation.md`](./docs/validation.md) |
| Reference index | [`docs/reference-index.md`](./docs/reference-index.md) |
| Live work state | `plan.md`, `progress.md`, `TASKS.md` |
| Learnings / traps | [`learnings.md`](./learnings.md) |
| Skills | `.agents/skills/` (`setup-and-run`, `digdug-domain-reference`, `impeccable`) |
| MCP | `opencode.json` → `fetch` server (runtime HTTP / doc access) |

Tool used: [opencode](https://opencode.ai) with a local Ollama coding model, and Claude Code.

## Acknowledgments
The agentic operating surface in this repo (rules, spec, skills, MCP, living docs) was inspired by **Eleanor Berger**'s *Elite AI-Assisted Coding* course. The structure here is my own application of those ideas; the course material itself is not included.
