# CLAUDE.md — DigDug

Project rules for Claude Code. **Canonical source is [AGENTS.md](./AGENTS.md)** — read it first; it carries the build/run/test commands, key paths, durable docs, and the always / ask-first / never boundaries. This file exists so Claude Code loads project rules and the docs that point here resolve.

Your global `~/.claude/CLAUDE.md` defaults still apply (commit only when asked, ask before destructive commands, etc.).

## Fast facts
- Build app: `bash scripts/make_app.sh` (`--install` copies to `/Applications` — ask first).
- Run: `swift run DigDug`.
- Test: `swift run DigDugTestRunner` — **never `swift test`** (silently skips under CLT-only; see `learnings.md`).
- Model: `gemma4:e4b` at `http://localhost:11434/api/generate` (source of truth: `Sources/DigDugCore/Services/OllamaService.swift`).

Everything else: see [AGENTS.md](./AGENTS.md).
