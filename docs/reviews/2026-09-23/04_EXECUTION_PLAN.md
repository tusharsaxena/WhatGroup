# WhatGroup — execution plan for the 2026-09-23 review

Implements `02_PROPOSED_CHANGES.md`. The finding and change IDs match `01_FINDINGS.md` and `02`. The
gate before every commit is the one this repo's `CLAUDE.md` names: `lua tests/run.lua`,
`luacheck .` at 0/0, and the vendor gate. All runs go through `ka0s-bounded`.

## Milestone U: upstream (cross-repo hand-off; lands before any local change that depends on it)

There are **no LibKa0s code changes**, and so **no re-vendor** is triggered by this review.
Nothing below edits `libs/` or `tests/_kit/`.

| Task | Owner role | Findings | Repo | Work |
|---|---|---|---|---|
| U-1 | standards-editor | F-003 | WowAddonStandards | Amend the `savedvariables-§1` template to declare the pre-versioning stamp (0) and explain AceDB's `removeDefaults` strip, then bump the standard's minor |
| U-2 | standards-editor | F-015 | WowAddonStandards | Rule on a shown-polarity CLI alias for the Minimap button row (`launcher-§3`, `options-ui-§15`). If adopted, open a LibKa0s issue for the composer/CLI field |

**Done when:** U-1 is merged, or explicitly declined, in WowAddonStandards. U-2 is ruled on (adopt
or decline) and, if adopted, has a tracked LibKa0s issue. **C-003 does not wait for U-1**: it
already satisfies the MUST as written, and U-1 only changes the template literal.
**If U-2 is adopted:** its exit criterion in *this* repo is a **separate re-vendor commit** of the
whole `libs/LibKa0s/` folder at the new tag, together with the `CLAUDE.md` provenance line (the
vendor gate reads it). It is never folded into a code task.

## Milestone 1: combat-path fixes (High)

| Task | Owner role | Changes (findings) | Files |
|---|---|---|---|
| 1.1 | lua-refactorer | C-002 (F-002), plus its F-006 cases | `modules/Frame.lua` (`ApplyFrameAlpha`, hoisting the `softHidden`/`pendingHide` locals), `tests/test_frame.lua` |
| 1.2 | lua-refactorer | C-001 (F-001), plus its F-006 case | `modules/Frame.lua` (`PopulateFields`, `deferTeleportUntilCombatEnds`, `ConfigureTeleportButton` replay), `tests/test_frame.lua` |
| 1.3 | test-inventory | the count move for 1.1 and 1.2 | `docs/test-cases.md` (regenerated), `README.md` badge |

**Serialize 1.1 → 1.2 → 1.3.** All three touch `modules/Frame.lua` and/or `tests/test_frame.lua`.
Write each new case red first, against the unfixed code: `testing-§12`, plus a `-- red under:`
comment on each.
**Done when:** the three new `frame:` cases are green, 0 cases fail, luacheck is 0/0, and the
inventory and badge agree with `--list`.
**Checkpoint A (human):** run `03_SMOKE_TESTS.md` S-001 and S-002 in the client before continuing.
These are the only fixes with taint exposure.

## Milestone 2: data and degraded-path correctness (Medium)

| Task | Owner role | Changes (findings) | Files |
|---|---|---|---|
| 2.1 | lua-refactorer | C-003 (F-003) | `settings/Schema.lua` (`BuildDefaults`), `core/Database.lua`, `tests/test_database.lua` |
| 2.2 | lua-refactorer | C-004 (F-004) | `settings/OptionsSetup.lua` (the degraded branch), `tests/test_libka0s.lua` |
| 2.3 | test-inventory | the count move | `docs/test-cases.md`, `README.md` |

**Parallelizable:** 2.1 and 2.2 have disjoint file sets. 2.3 runs after both.
**Done when:** the stamp case goes red under a default equal to `SCHEMA_VERSION` and green after the
change, the degraded `resetall` case is green, and the full suite and luacheck are green.
**Checkpoint B (human):** S-003 (log out fully and inspect SavedVariables) and S-004 (degraded
install).

## Milestone 3: debug-sink discipline and allocation (Medium/Low)

| Task | Owner role | Changes (findings) | Files |
|---|---|---|---|
| 3.1 | lua-refactorer | C-005 (F-005): the `core/` and `settings/` sites | `core/Database.lua`, `core/WhatGroup.lua`, `settings/Schema.lua` |
| 3.2 | lua-refactorer | C-005 (F-005): the `modules/` sites, and C-006 (F-016) | `modules/Frame.lua` |
| 3.3 | perf-recorder | re-run `tests/perf.lua`, update `showFrameRepeat` in `docs/performance.md` and its ceiling in `tests/perf.lua` | `docs/performance.md`, `tests/perf.lua` |

**Parallelizable:** 3.1 alongside 3.2. **3.2 must follow Milestone 1**, because it touches the same
file. 3.3 follows 3.2.
**Characterization first (`testing-§13`):** before 3.1 and 3.2, confirm that every rewritten log
line is already pinned by a `tests/test_debuglog.lua`/`test_capture.lua` assertion. If one is not,
add the pin, green on the old code, then refactor.
**Done when:** a re-run of the F-005 census reports 0 pre-built sites, every pinned log line is
byte-identical, and `showFrameRepeat` is re-measured and recorded.

## Milestone 4: hygiene (Low)

| Task | Owner role | Changes (findings) | Files |
|---|---|---|---|
| 4.1 | docs-cleanup | C-007 (F-007, F-008, F-009) | `modules/Frame.lua`, `core/WhatGroup.lua`, `core/Util.lua`, `settings/Schema.lua`, `settings/Panel.lua`, `defaults/Profile.lua`, `core/LauncherSetup.lua` |
| 4.2 | ux-cleanup | C-008 (F-010) | `locales/enUS.lua` |
| 4.3 | lint-cleanup | C-009 (F-011) | `.luacheckrc` |
| 4.4 | lua-refactorer | C-010 (F-012), **after** S-008 has recorded the real status strings | `core/WhatGroup.lua`, `tests/test_capture.lua`, `docs/test-cases.md`, `README.md` |
| 4.5 | lua-refactorer | C-011 (F-013) | `settings/Panel.lua`, `tests/test_panel.lua` |

**Serialization:**
- 4.1 touches `modules/Frame.lua` and `core/WhatGroup.lua`, so it runs after M1 and M3.
- 4.4 touches `core/WhatGroup.lua`, so it runs after 4.1.
- 4.5 touches `settings/Panel.lua`, so it runs after 4.1.
- 4.2 and 4.3 have disjoint file sets and are **parallelizable** with everything in M4.

**Done when:** the suite, luacheck and the vendor gate are all green, and the inventory and badge
agree with `--list`.
**Checkpoint C (human):** S-005 to S-008, the regression suite, and the cross-addon dispatch check.

## Deferred

- **F-014:** the `RESULTS.md` disposition is recorded by the next release run
  (`/wow-addon:bump-version`). It is not run here, and no complexity gate is introduced.

## Critical path

M1 (1.1 → 1.2 → 1.3) → Checkpoint A → M3.2 → M4.1 → M4.4/M4.5 → Checkpoint C. M2 runs beside M1,
since its files are disjoint from M1's, and M3.1 runs any time after M2.1, because both touch
`core/Database.lua`. So serialize 2.1 → 3.1.

## Commit strategy (one commit per task; never `--no-verify`)

1. `Keep a soft-hidden popup at alpha 0 until something may really show it` (1.1)
2. `Defer the teleport button's clear in combat like its configure` (1.2)
3. `Record the combat-reopen cases in the inventory` (1.3). This may be folded into 1.1 and 1.2 if
   each commit moves its own count, which is preferred (`testing-§5`: the inventory moves **with**
   the change).
4. `Declare the schema stamp at its pre-versioning value so it persists` (2.1)
5. `Keep the host reset real in the Options degradation stub` (2.2)
6. `Hand NS.Debug its format arguments instead of a built string` (3.1, 3.2)
7. `Build the teleport button's scripts once` (3.2, the C-006 part) and
   `Re-measure showFrameRepeat` (3.3)
8. `Make the comments agree with the code` (4.1), `Drop the orphaned locale key` (4.2),
   `Stop granting globals no file reads` (4.3), `End the application on every terminal status`
   (4.4), `Drop the unread settings-category handles` (4.5)

Each commit carries its own inventory and badge move where the count changed. None bumps the
version: this repo's `CLAUDE.md` forbids that without an explicit instruction.
