# Project Plan

## Current Objective
Keep the documentation and handoff state consistent with the merged chat improvements and installed release. No application source changes are needed for this documentation pass.

## Completed Delivery
- [x] Transactional organizer and safety UI shipped through PR #1 (2026-06-22).
- [x] Enter/Shift+Enter composition, plain-text/code copying, scroll following, and cancellation isolation merged through [PR #10](https://github.com/mrme77/DigDug/pull/10) (2026-10-25).
- [x] Full debug and release builds passed with this host's macOS 26.5 SDK/native-build-system workaround.
- [x] 35 Core tests and 8 native chat interaction tests passed.
- [x] Installed merged revision `e6bd22a` at `/Applications/DigDug.app` with explicit approval; signature and executable hash verified.

## Documentation Pass
1. Reconcile the README, product contract, decisions, validation, and live task state with the code and completed installation.
2. Synchronize project-owned domain/setup skills and agent handoff notes.
3. Check local links, mirrored guides, stale claims, and whitespace.
4. Prepare the documentation branch for review; obtain commit approval before publishing its PR.

## Remaining Product Work
- Manually verify post-install live chat and disposable-file organization in the native panel.
- Investigate the historical ~13% used-conversation CPU observation.
- Fix standard packaging for this host's current toolchain and icon-generation constraints.
- Preserve per-turn tool/report history and refresh deduplicated reads after mutations.

See [TASKS.md](TASKS.md) for the checklist and [docs/validation.md](docs/validation.md) for evidence and unverified checks.
