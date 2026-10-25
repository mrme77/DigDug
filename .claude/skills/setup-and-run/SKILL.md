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

The installed app is `/Applications/DigDug.app`; `build/DigDug.app` and temporary review bundles are separate copies. After an approved installation, quit any older running instances and open the installed copy explicitly with `open /Applications/DigDug.app`. Closing the panel only hides it; quitting clears in-memory chat.

### Current host workaround
The default macOS 27 SDK lacks `SwiftUIMacros` required by NetworkImage. Use the installed macOS 26.5 SDK and native build system here:
```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/digdug-clang-cache swift build --disable-sandbox --build-system native --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk --product DigDug
```
Use the same flags for `swift run` and `-c release` builds. `make_app.sh` does not read `DIGDUG_SDK_PATH`, so setting that variable does not fix packaging. The latest local packaging required a temporary SDK-aware adaptation and reuse of the existing app icon after sandboxed `iconutil` failed. Read `learnings.md` before repeating packaging on this host; do not report an unverified install or launch as complete.

## Test (authoritative)
```sh
swift run DigDugTestRunner      # runs swift-testing for real
```
**Never** `swift test` — CLT has no `xctest` host; it compiles then silently skips (exit 0 even on failure). See `learnings.md`.

For app interaction changes, also run:
```sh
DIGDUG_SDK_PATH=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk bash scripts/test_chat_ui.sh
```
Omit `DIGDUG_SDK_PATH` on hosts whose default SDK works. Clipboard tests use named test pasteboards and require normal macOS pasteboard access. Latest verified counts (2026-10-25): 35 Core tests and 8 chat interaction tests.

## Smoke test (manual)
1. Launch → floating `NSPanel` appears always-on-top over other apps.
2. Type a prompt → response **streams** in (typing dots, then text).
3. Markdown/code blocks render (not raw `*`/backticks).
4. Close the window → app stays alive (menu-bar shovel icon); click Dock icon re-shows it.
5. Paste multiple lines, then Shift+Enter → another editable line; Enter → one submission. Return must not activate Stop.
6. Copy a prose response → plain text; copy code → original code and whitespace; verify copy feedback.
7. Scroll up during a response → reading position stays put; Jump to latest → following resumes.
8. Stop and immediately send another prompt → the new response remains active and receives no stale events or confirmations.
9. Exercise the unavailable-Ollama error path without disrupting a user's running server or active work.

## Verification
Update `docs/validation.md` "Latest Run" with date + which checks passed. If you hit a new toolchain trap, append it to `learnings.md`.

## Boundaries
- `--install` and any `/Applications` write: ask first.
- Don't edit `Package.swift` `unsafeFlags` to "fix" tests — they're load-bearing for the runner.
