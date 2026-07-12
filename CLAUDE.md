# CLAUDE.md — Ka0s WhatGroup

**Tier 1 (Flat).** A single-folder retail WoW addon: flat source layout, Ace3
vendored under `libs/`, one shared AceDB profile.

This addon adheres to the **Ka0s WoW Addon Standard** —
<https://github.com/tusharsaxena/WowAddonStandards>.

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
