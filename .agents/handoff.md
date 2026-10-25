# Agent Handoff

## Latest Completed Delivery
[PR #10](https://github.com/mrme77/DigDug/pull/10) merged on 2026-10-25 as `e6bd22a`. It adds native Enter/Shift+Enter handling, plain-text response and verbatim code copying, user-controlled stream following, and isolation from stale cancelled turns. Debug/release builds, 35 Core tests, and 8 native chat tests passed.

Installed the approved merged release at `/Applications/DigDug.app`, build `20261025.1447`, with matching executable hash and verified ad-hoc signature. Two older processes were still running; the user received stop/reopen commands. Post-install launch and a live-model round-trip have not been independently verified. See [validation](../docs/validation.md).

## Current Documentation Work
The documentation branch reconciles README, product/specification, decisions, validation, plan/progress/tasks, learnings, and project-owned agent guides with that release. Check the working tree for its uncommitted updates; commit and publish only with user approval. Vendor `impeccable` guides are unchanged.

## Remaining Work
- Manual post-install chat/streaming-scroll and disposable-file organizer smoke tests.
- Standard packaging compatibility with the host's SDK/plugin and icon-generation restrictions.
- Historical ~13% CPU with a used conversation; profile before claiming a fix.
- Per-turn tool/report archival and invalidation of deduplicated reads after mutations.
- Chat persistence remains deferred; cloud providers remain excluded by the specification.

## Operational Notes
- Use `DigDugTestRunner`, not `swift test`; use the UI runner for chat interaction changes.
- Current host needs macOS 26.5 SDK/native-build-system flags and a writable Clang module cache. `make_app.sh` does not read `DIGDUG_SDK_PATH`; details are in [learnings](../learnings.md).
- `/Applications/DigDug.app`, `build/DigDug.app`, and temporary review apps are separate copies. Hiding is not quitting, and installing does not restart a running process.
- Installation and `/Applications` writes require approval. Preserve file-operation confirmations and Package.swift's CLT runner flags.
- Keep copyrighted `course-reader.txt` and secrets out of commits. Attribute AI contributions to Sasamen in commits and PR bodies.
