# 04 — Execution plan

Every step ran the green gate (`lua tests/run.lua`, `luacheck .` 0/0) and made CR count equal LF
count in every file it edited. B-1 and B-2 share the write seam and one test file, so they land in one
commit.

## Re-vendor

- Copy both payloads whole from `git archive v1.32.0 LibKa0s testkit`; the runner stays `100755`.
- Roll `CLAUDE.md`'s provenance line and `docs/testing.md`'s sibling-state note to v1.32.0 in the
  same commit, with `01_DELTA.md`.
- Proof: 589 / 0 / 589, `test_vendor_sync` green against v1.32.0.

## B-1 + B-2 — the reset line and the defensive bracket

- **Red first.** In `tests/test_debuglog.lua`, flip "RestoreAllDefaults coalesces to one [Reset], zero
  [Set] (debug-logging-§9)" to one `[Set] reset profile 'Default' to defaults (N rows)` line and zero
  `[Reset]`, and rewrite its comment, which argued against a count. Add cases for a reset straight at
  the db, the library's page reset, and `info.profileReset` silence. The first draft counted schema
  rows: five cases red, 588 / 5. After the correction the cases were rewritten against the
  changed-row rule, adding: a pristine reset counts 0, an all-default page reset logs `: 0 rows`, a
  nested bracket logs once at the outermost close with the summed tally, and a nested profile reset
  silences the outer line. These corrected cases were written in the same step as the code
  correction, so they were not run red on their own; the red step on record is the first draft's.
- **Change.**
  - `settings/Schema.lua`: the seam tallies changed writes while bracketed and mutes its `[Set]`;
    `Settings.Bulk` holds `begin` / `finish`; `RestoreAllDefaults` counts changed profile rows before
    `db:ResetProfile()` and no longer logs `[Reset]`; `Settings.ConsumeResetCount` hands the count over.
  - `core/WhatGroup.lua`: `OnProfileReset` logs the line, then reloads.
  - `settings/OptionsSetup.lua`: `bulkBegin` / `bulkEnd` forward to `Settings.Bulk`.
  - Retarget the reset-related `debug-logging-§9` citations to §10. `core/WhatGroup.lua`'s
    apply→capture summary is a real §9 citation and stays.
- **Kept valid, unedited:** `test_settings.lua` "RestoreAllDefaults skips per-row onChange (F3)" and
  "refreshes once, not once per row".
- **Docs.** `ARCHITECTURE.md`, `settings-panel.md`, `module-map.md`, `common-tasks.md`, `debug.md`,
  `smoke-tests.md` 2.8d; regenerate `docs/test-cases.md`; README badge.
- **Proof.** 597 / 0 / 597, luacheck 0 / 0, lizard clean.
