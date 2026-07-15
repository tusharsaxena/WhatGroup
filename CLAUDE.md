# CLAUDE.md — Ka0s WhatGroup

**Ka0s WoW addon.** A retail WoW addon: Ace3 vendored under `libs/`, one shared
AceDB profile.

## Standards adherence — read before any change

This addon is built to the **Ka0s WoW Addon Standard** —
<https://github.com/tusharsaxena/WowAddonStandards>. Treat that repo (its
`standards/STANDARDS.md`) as the source of truth for structure, conventions,
metadata, testing, and layout. **All development work in this repo is done
against the standard** — check every change against it as you go.

**Deviation rule (MUST).** If a change would deviate from the standard — or you
notice existing code/docs that already deviate — **stop and flag it to the
user.** Never silently conform and never silently deviate. The user decides
whether it should be:
1. an **accepted deviation** in this addon (record it with an in-code
   SHOULD-justification comment per §0, and note it where relevant), or
2. a **change to the standard definition** itself (a PR/edit to the
   WowAddonStandards repo).

Do not resolve a standards conflict on your own — surface it and let the user
choose. (See the frozen compliance snapshot in `docs/audits/2026-07-12/`.)

This root file is a **stub** (§15.2). The full agent brief — hard rules (taint
discipline, schema-first settings, slash-first commands, English-only, the
private-`NS` namespace, no version bump / no auto-commit), the working
environment notes, and the per-topic doc index — lives in **`docs/`**:

- **[docs/agent-context.md](docs/agent-context.md)** — the complete working
  notes: hard rules, invariants, and the topic-doc index. **Read this first
  before touching code.**
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — design overview,
  subsystem map, load order, and invariants.
- Topic detail (capture pipeline, settings system, slash dispatch, frame,
  WoW quirks, common tasks, smoke tests) lives alongside those under `docs/`.

Verification: headless tests (`lua tests/run.lua`), lint (`luacheck .`), and
the in-game smoke-test suite ([docs/smoke-tests.md](docs/smoke-tests.md)). Run
before tagging a release, after an `## Interface:` bump, or after a `libs/`
refresh.
