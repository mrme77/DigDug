# Project Plan

## Current Objective
Implement and validate a review-first, transactional file organizer on top of DigDug's local agent tools.

## Intended Sequence of Work
1. Add read-only metadata and SHA-256 inspection tools.
2. Add typed organization plans, canonical preflight, deterministic execution, and rollback.
3. Add one batch-review sheet and structured completion/rollback report.
4. Add safety and failure-injection tests.
5. Build, test, document, and publish a draft PR for human review.

## Main Checkpoints
- [x] Core tool infrastructure and eleven tools implemented (eight core file tools, plus metadata, hash, and organize tools).
- [x] Streaming agent loop, confirmation, cancellation, and loop guard implemented.
- [x] Model discovery, capability-aware reasoning, and agent UI implemented.
- [x] Deterministic tool, safety, schema, confirmation, and loop tests authored.
- [x] Product-native organizer policy, metadata, SHA-256, typed batch plan, and rollback implemented.
- [x] Plan preview and structured execution report implemented.
- [x] Full app build and 29 authoritative tests pass with the restricted-runner flags documented in `learnings.md`.
- [x] Opened feature branch as a draft PR with Sasamen co-author trailer; merged to main as PR #1 (2026-06-22).
- [ ] Manual native-panel organizer smoke test.
