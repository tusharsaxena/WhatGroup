# CLAUDE.md — Ka0s WhatGroup

**Ka0s WoW addon.** Adheres to the **Ka0s WoW Addon Standard** —
https://github.com/tusharsaxena/WowAddonStandards

## Standards compliance (read first)

This repo is built to the **Ka0s WoW Addon Standard** (URL above). All development here — features,
refactors, doc changes — MUST conform to it. The standard is the source of truth for layout, TOC
shape, the Ace substrate, schema-driven settings, slash/prefix conventions, locales, Compat,
tests/lint, and doc structure.

**If a change would deviate from the standard, STOP and flag the deviation explicitly.** Do not
silently deviate and do not silently "fix" to match. Surface it and let the user decide which of
two things it is:

1. **An accepted deviation** — this addon intentionally differs; record it as a row in
   `docs/ARCHITECTURE.md` -> `## Documented deviations`, shaped
   `| Rule | What differs | Why | Decided | Re-check trigger |`, where Rule is the `filename-§N`
   reference. That register is the single home: the reasoning may live in the issue-audit GitHub
   issue or an audit bundle and the row cites it, but a deviation not in the register is not ratified.
2. **A change to the standard itself** — the standard's definition should evolve; the update
   belongs upstream in the WowAddonStandards repo, after which this addon conforms to the new rule.

The newest frozen compliance snapshot is `docs/audits/2026-10-07/`.

When in doubt, treat standard conformance as a hard requirement and ask.

Start here, then read the docs:

- **`docs/ARCHITECTURE.md`** — what this addon is: module map, settings schema, slash surface,
  event wiring, taint notes, the invariants (observation-only, no AceHook), the working environment
  (never edit `libs/` or `tests/_kit/`), the LibKa0s majors it takes, known limitations and the
  documented deviations. **Read first.**
- **`docs/testing.md`** — how to verify: the headless harness, lint, the vendor gate, the generated
  `docs/test-cases.md` inventory and the README `tests` badge.
- Topic detail in `docs/` as needed (`scope.md`, `module-map.md`, `schema.md`, `settings-panel.md`,
  `data-flow.md`, `common-tasks.md`, `smoke-tests.md`, …), registered in `docs/ARCHITECTURE.md` ->
  `## Documentation map`.
- **`DEPENDENCIES.md`** — the toolchain contract: what to install to build, run, test or release.

Green gate before every commit: `lua tests/run.lua` and `luacheck .` (0/0); the suite includes the
vendor gate against the tag below (`tests/test_vendor_sync.lua`). Never auto-stage/commit/push and
never bump the version without an explicit instruction.

Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.71.0 (MIT).
