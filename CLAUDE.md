# CLAUDE.md — DigDug

Project rules for Claude Code. **Canonical source is [AGENTS.md](./AGENTS.md)** — read it first; it carries the build/run/test commands, key paths, durable docs, and the always / ask-first / never boundaries. This file exists so Claude Code loads project rules and the docs that point here resolve.

Your global `~/.claude/CLAUDE.md` defaults still apply (commit only when asked, ask before destructive commands, etc.).

## Fast facts
- Build app: `bash scripts/make_app.sh` (`--install` copies to `/Applications` — ask first).
- Run: `swift run DigDug`.
- Test: `swift run DigDugTestRunner` — **never `swift test`** (silently skips under CLT-only; see `learnings.md`).
- Chat tests: `bash scripts/test_chat_ui.sh`; see README for the current SDK fallback and pasteboard access requirement.
- Installed app: `/Applications/DigDug.app`; project builds and temporary review apps are separate copies.
- Chat: Enter sends; Shift+Enter inserts a newline. Responses copy as plain text, code copies verbatim, and scrolling up pauses following.
- Latest verified tests: 35 Core + 8 native chat tests (2026-10-25).
- Ollama API base: `http://localhost:11434/api`; chat uses `/chat`, discovery uses `/tags`.
- Default model: `gemma4:e4b`; the UI lists installed local completion models and their advertised capabilities.

Everything else: see [AGENTS.md](./AGENTS.md).
