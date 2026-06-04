# Agent Handoff

## Last Completed Task
Shipped and published DigDug. Pre-publish audit (no secrets, no dead code, links resolve; removed orphaned `pdf_to_txt.sh`). Verified end-to-end: app builds/installs, floats, streams, hides-on-close; idle footprint ~91 MB / ~0–2% CPU. Published public to <https://github.com/mrme77/DigDug> (course-reader.txt kept out of history; Eleanor Berger credited). README has app icon + chat/dock screenshots. Living docs (progress/decisions/learnings/validation) updated.

## Next Task
Open items (none blocking):
- Root-cause the ~13% CPU seen with a used conversation (idle baseline is fine) — profile with `sample <pid>` while a conversation is loaded.
- Resolve the `swift test` path (currently use `swift run DigDugTestRunner`).
- Optional: OpenRouter provider — requires a spec change first (cloud is currently a hard non-goal). Chat persistence is **deferred by the author** (not needed).

## Warnings/Notes for Next Agent
- Never trust `swift test` here — use `swift run DigDugTestRunner`.
- Public repo: never commit `course-reader.txt` (gitignored, © Eleanor Berger).
- Don't add cloud LLM providers without a spec change; don't strip `Package.swift` `unsafeFlags`.
- `bash scripts/make_app.sh --install` writes to `/Applications` — ask first.
- macOS screenshot filenames contain a U+202F narrow no-break space (breaks `mv`/Markdown links) — rename via glob to a clean slug.
- After `--amend`, local/remote can diverge — reconcile with `git push --force-with-lease` (ask first).
