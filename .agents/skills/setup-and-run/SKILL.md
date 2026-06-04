---
name: setup-and-run
description: Use to build, launch, or smoke-test the DigDug macOS app and verify its local Ollama connection. Triggers on "run the app", "build DigDug", "make the .app", "does it still work", "smoke test", "the panel won't appear", or "Ollama isn't responding". Not for design/UI changes (use impeccable) or domain questions (use digdug-domain-reference).
---

# setup-and-run

Procedural skill: get DigDug running and prove the round-trip to Ollama works.

## When to use
A change touched `Sources/`, `Package.swift`, or `scripts/`, and you need to confirm the app still builds, launches, and talks to the model — or the user reports the panel/Ollama misbehaving.

## Preflight: Ollama
Inference is local-only. Confirm the server and model before launching the app.
```sh
curl -s http://localhost:11434/api/tags        # server up? lists installed models
ollama pull gemma4:e4b                          # ensure the default model exists
```
- No response → Ollama not running. Start `ollama serve` or the menu-bar app.
- Model missing → the app surfaces `model '...' is not installed`; pull it.

## Build & run
```sh
swift run DigDug                # fastest: launch the panel directly
bash scripts/make_app.sh        # double-clickable → build/DigDug.app
bash scripts/make_app.sh --install   # ASK FIRST — copies to /Applications
```

## Test (authoritative)
```sh
swift run DigDugTestRunner      # runs swift-testing for real
```
**Never** `swift test` — CLT has no `xctest` host; it compiles then silently skips (exit 0 even on failure). See `learnings.md`.

## Smoke test (manual)
1. Launch → floating `NSPanel` appears always-on-top over other apps.
2. Type a prompt → response **streams** in (typing dots, then text).
3. Markdown/code blocks render (not raw `*`/backticks).
4. Close the window → app stays alive (menu-bar shovel icon); click Dock icon re-shows it.
5. Stop Ollama, send a prompt → graceful error UI, no crash.

## Verification
Update `docs/validation.md` "Latest Run" with date + which checks passed. If you hit a new toolchain trap, append it to `learnings.md`.

## Boundaries
- `--install` and any `/Applications` write: ask first.
- Don't edit `Package.swift` `unsafeFlags` to "fix" tests — they're load-bearing for the runner.
