# CLAUDE.md — Ka0s WhatGroup

**Ka0s WoW addon.** A retail WoW addon: Ace3 vendored under `libs/`, one shared
AceDB profile.

## Standards compliance (read first)

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
   SHOULD-justification comment, as the existing accepted deviations do, and
   note it where relevant), or
2. a **change to the standard definition** itself (a PR/edit to the
   WowAddonStandards repo).

Do not resolve a standards conflict on your own — surface it and let the user
choose. (See the frozen compliance snapshot in `docs/audits/2026-07-18/`.)

## Hard rules

- **Never auto-stage, auto-commit, or auto-push.** Leave edits modified-but-unstaged and
  describe them. Only an explicit instruction in the *current* turn authorizes `git add` /
  `commit` / `push` — a prior approval does not carry forward. Invoking `/wow-addon:commit`
  (or plainly saying "commit this") IS that instruction, for that turn only.
- **Never bump the version** — TOC `## Version:`, `WhatGroup.VERSION`, the README badge or
  Version History — without being told to in the current turn. Refactors and doc changes
  don't justify a bump; mention it in the summary and leave the edit to the user.
- **Observation-only, direct `hooksecurefunc` only. No AceHook** — its wrappers taint the
  secure-execute chain and break Logout. See the invariants in `docs/ARCHITECTURE.md`.

## Response style

Terse — state the change, not the deliberation. Cite `file_path:line_number`. Don't write
summaries the diff already shows, don't create docs or planning files unless asked, and
only comment the non-obvious *why*.

This root file is a **stub** (documentation-§2). The real detail lives in `docs/`:

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — what this addon is: design
  overview, subsystem map, invariants, working environment, load order. **Read first.**
- **[docs/testing.md](docs/testing.md)** — how to verify: the green gate, mock fidelity,
  the generated `docs/test-cases.md` inventory and the README `tests` badge.
- Topic detail (file index, scope, capture pipeline, settings system, slash dispatch,
  debug console, frame, WoW quirks, common tasks, smoke tests) sits alongside them.

Green gate before every commit: `lua tests/run.lua` and `luacheck .` (0/0), plus the
in-game [smoke tests](docs/smoke-tests.md) before tagging a release, after an
`## Interface:` bump, or after a `libs/` refresh.
