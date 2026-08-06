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
choose. (See the frozen compliance snapshot in `docs/audits/2026-08-04/`.)

## The `docs/` set — there is no `agent-context.md`

The canonical `docs/` set is exactly three files: **`ARCHITECTURE.md`** (what this addon is),
**`testing.md`** (how to verify) and **`smoke-tests.md`** (in-game checks) — plus the generated
`test-cases.md`, and the topic-detail docs — Tier 1 (`scope.md`, `module-map.md`, `schema.md`, `settings-panel.md`, `data-flow.md`, `common-tasks.md`) is always present, and `ARCHITECTURE.md` → `## Documentation map` lists the rest.

**`docs/agent-context.md` does not exist in this repo and MUST NOT be created.** The standard
deleted it in **v2.17.0**; shipping it is **anti-pattern #49**. It held `NEW_ADDON_CONTEXT.md` —
the scaffolding pack — which is fetched at runtime and never stored: a copy in the repo describes
the addon on the day it was born, forever, and because it loads as *working context* a stale copy
does not go quiet, it gets **followed** (documentation-§3). This root `CLAUDE.md` is the repo's
only agent brief.

Older audit bundles, review bundles, ledgers and plans under `docs/` predate v2.17.0 and still
name the file, and some describe a four-file or a pre-v2.3.0 `agent-context.md`-based set. Those
are **frozen history** — never treat them as a live requirement, and never "restore" the file.

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
- **Never edit `libs/` or `tests/_kit/`.** Both are whole-folder, byte-identical copies of
  `../LibKa0s`'s ship folders. A library problem is a finding to fix **upstream** and
  re-vendor — a local patch is a fork nobody knows about, and the next re-vendor silently
  reverts it. The addon takes four of LibKa0s's five majors (Core, DebugLog, Options,
  Slash) through the four seam files `core/CoreSetup.lua`, `core/DebugLogSetup.lua`,
  `settings/OptionsSetup.lua` and `settings/Slash.lua`; **Perf is declined** on structural
  grounds (`docs/pending/LEDGER.md`, `LIBKA0S-15`).

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
  debug console, frame, WoW quirks, common tasks, smoke tests) sits alongside them —
  including the generated **[docs/automated-tests/RESULTS.md](docs/automated-tests/RESULTS.md)**, refreshed at
  every release and never hand-edited (performance-§10).
- **[DEPENDENCIES.md](DEPENDENCIES.md)** — the root toolchain contract (documentation-§7):
  what to install to build, run, test or release this addon, with WSL2/Ubuntu commands.

Green gate before every commit: `lua tests/run.lua` and `luacheck .` (0/0), plus the
**vendor gate** — `diff -r --strip-trailing-cr` and plain `diff -r` of `../LibKa0s/LibKa0s`
against `libs/LibKa0s` and of `../LibKa0s/testkit` against `tests/_kit`; a non-empty
*content* diff is a real fork, a bytes-only one is a line-ending divergence
([docs/testing.md](docs/testing.md)). Plus the
in-game [smoke tests](docs/smoke-tests.md) before tagging a release, after an
`## Interface:` bump, or after a `libs/` refresh.
