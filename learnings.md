# Project Learnings

(Capture awkward local truths, fragile commands, and integration quirks here.)

## Current Learnings

### UI design system (impeccable, product register)
- Committed **dark** theme, single **amber→ember** accent (matches the icon). Tokens
  live in `Sources/DigDugApp/UI/Theme.swift` (`Palette`, `Metrics`, `Theme.digDug`
  markdown theme). `ContentView` forces `.preferredColorScheme(.dark)`.
- Accent carries user bubbles + primary action + focus/active state only (restrained).
  Body text 15pt, near-white ink on charcoal (contrast ≥4.5:1). Code blocks are
  near-black with a hairline border, 13pt mono.
- Subtitle is **"AI Assistant"** (not "Local Ollama chat"). Animated three-dot typing
  indicator shows while the model streams an empty assistant message.
- `PRODUCT.md` at repo root is the impeccable design anchor. Theme objects from
  MarkdownUI need `@MainActor` under Swift 6 (Theme isn't Sendable).

### Building the double-clickable app
- `bash scripts/make_app.sh` → `build/DigDug.app`. Add `--install` to also copy to
  `/Applications`. It builds the release binary, generates the icon
  (`scripts/generate_icon.swift` → iconset → `AppIcon.icns`), writes `Info.plist`,
  and ad-hoc code-signs. No Xcode required.
- App is a **regular Dock app** (`.regular` policy): Dock icon = reopen (click it to
  re-show the window via `applicationShouldHandleReopen`). Also has a menu-bar shovel
  icon (left-click toggle, right-click menu) and keeps a `.floating` always-on-top
  panel that overlaps other apps. Closing the window hides it; the app keeps running
  (`applicationShouldTerminateAfterLastWindowClosed` = false). Quit from the menu-bar
  right-click menu.
- Markdown in chat is rendered via **swift-markdown-ui** (`MarkdownUI`), pinned
  `from: 2.4.0` (resolved 2.4.1). `import` needs `@preconcurrency`, and the custom
  `Theme.digDug` must be `@MainActor` (Theme isn't Sendable under Swift 6).


### Tests: use `swift run DigDugTestRunner`, not `swift test`
- This machine has **Command Line Tools only** (no full Xcode.app). CLT has no `xctest`
  host, so `swift test` compiles the test bundle but **silently skips execution** —
  exit 0, no output, even when an assertion fails. Do not trust a green `swift test`.
- Tests use swift-testing (`import Testing`). `DigDugTests` is an `executableTarget`
  (product `DigDugTestRunner`) whose `Tests/Runner.swift` calls
  `Testing.__swiftPMEntryPoint()` directly, so it actually runs and reports pass/fail.
- `Package.swift` adds `-F`/rpath unsafeFlags pointing at
  `/Library/Developer/CommandLineTools/Library/Developer/Frameworks` (plus
  `.../Developer/usr/lib` for `lib_TestingInterop.dylib`) because SwiftPM doesn't add
  swift-testing's search paths without Xcode.
- If full **Xcode.app** is ever installed (`sudo xcode-select -s
  /Applications/Xcode.app/Contents/Developer`), revert to a plain `.testTarget`,
  drop the runner product / `Runner.swift` / unsafeFlags, and use `swift test`.

### "Invalid manifest" link error after a Swift toolchain update
- Symptom: `swift build`/`test` fails while linking `Package.swift` with
  `Undefined symbols ... PackageDescription.Package.__allocating_init(... swiftLanguageVersions ...)`.
- Cause: a partially-updated/corrupt CLT — stale `libPackageDescription.dylib` vs the
  PackageDescription module. Fix: reinstall CLT
  (`sudo rm -rf /Library/Developer/CommandLineTools && sudo xcode-select --install`),
  then `rm -rf .build && swift package reset`.

### Swift 6 strict concurrency
- `OllamaService` is marked `Sendable` so its `Task` closure can capture `self` inside
  the `AsyncThrowingStream`. Keep all stored properties immutable Sendable types.
