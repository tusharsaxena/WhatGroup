# WhatGroup — final summary (written assuming every check in `03_SMOKE_TESTS.md` passes)

## Headline

This cycle closes the last two ways the WhatGroup popup could misbehave in combat. Reopening a
popup that was closed mid-fight with no group info no longer asks the client to hide the protected
teleport button. A popup the "Only out of combat" setting had taken off screen stays off screen
until combat ends, and the minimap button and Escape keep working. The cycle also makes the
SavedVariables version stamp actually persist, so the first real data migration will run for
existing users. On a partial install missing LibKa0s, "reset all settings" now really resets. The
remaining changes are behavior-neutral: debug-log hygiene, fewer allocations when the popup
opens, and comments, locale entries and lint config corrected to match the code.

## Counts

Critical fixed: 0 · High fixed: 2 (F-001, F-002) · Medium fixed: 4 (F-003, F-004, F-005, F-006) ·
Low fixed: 8 (F-007, F-008, F-009, F-010, F-011, F-012, F-013, F-016; F-012 contingent on S-008) of 10 raised.

**Deferred:**

- **F-014:** the complexity disposition belongs to the next release run's `RESULTS.md`.
- **F-015:** a WowAddonStandards ruling. The path is mandated, so there is no local change.
- **The F-003 template:** an upstream WowAddonStandards amendment (U-1). The local fix already
  conforms.

## Changes by theme

### T1. One combat-safe path onto and off the screen

- **What changed:** the alpha seam now respects the combat soft-hide. When there is no group info to
  show, the popup's teleport button is cleared through the same combat-deferred path as when there
  is.
- **Why it mattered:** both paths bypassed the seams this file built to avoid
  `ADDON_ACTION_BLOCKED`. One of them raised the blocked-action error. The other made a hidden
  popup reappear mid-fight in a state the launcher and Escape could not close.
- **Findings:** F-001, F-002, F-006. **Changes:** C-001, C-002.
- **Files:** `modules/Frame.lua`, `tests/test_frame.lua`, `docs/test-cases.md`, `README.md`.

### T2. A stamp that persists

- **What changed:** `global.schemaVersion` is declared at its pre-versioning value, so the stored
  stamp differs from the default and survives AceDB's logout strip.
- **Why it mattered:** a stamp equal to its default is never written to disk, so the first release
  to bump `SCHEMA_VERSION` would have skipped its own migration for every existing user.
- **Findings:** F-003. **Changes:** C-003.
- **Files:** `settings/Schema.lua`, `core/Database.lua`, `tests/test_database.lua`,
  `docs/test-cases.md`, `README.md`.

### T3. A degradation stub that adds and never replaces

- **What changed:** the Options stub no longer overwrites the host's `RestoreAllDefaults`.
- **Why it mattered:** on an install missing LibKa0s, `/wg resetall` reported success while
  resetting nothing.
- **Findings:** F-004. **Changes:** C-004.
- **Files:** `settings/OptionsSetup.lua`, `tests/test_libka0s.lua`, `docs/test-cases.md`,
  `README.md`.

### T4. Debug sink discipline

- **What changed:** the 16 debug calls that pre-built their message now pass format arguments. The
  teleport button's three script handlers are built once.
- **Why it mattered:** `debug-logging-§4` requires a zero-allocation sink when debug is off, and the
  popup's configure path allocated three closures per show.
- **Findings:** F-005, F-016. **Changes:** C-005, C-006.
- **Files:** `core/Database.lua`, `core/WhatGroup.lua`, `modules/Frame.lua`, `settings/Schema.lua`,
  `docs/performance.md`, `tests/perf.lua`.

### T5. Hygiene

- **What changed:** comments now agree with the code. A dead locale key is gone, the lint
  `read_globals` list is trimmed, terminal LFG statuses end an application, and two unread
  settings-category fields are gone.
- **Why it mattered:** two of the comments misstated a taint rule to the next editor, and the lint
  config would have waved a removed spell global through.
- **Findings:** F-007 to F-013. **Changes:** C-007 to C-011.
- **Files:** `modules/Frame.lua`, `core/WhatGroup.lua`, `core/Util.lua`, `core/LauncherSetup.lua`,
  `settings/Schema.lua`, `settings/Panel.lua`, `defaults/Profile.lua`, `locales/enUS.lua`,
  `.luacheckrc`, `tests/test_capture.lua`, `tests/test_panel.lua`.

## API / behavior changes

- **No slash verb is added, renamed or removed.** `/wg resetall` now works on a degraded install.
- **Popup:** under *Only out of combat*, `/wg show`, the chat link, the minimap button and
  `/wg set alpha` no longer reveal the popup during combat. It reappears once combat ends.
- **Debug output:** wording is unchanged, byte for byte. Values are now rendered by the sink.
- **Locale:** the key `"WhatGroup is disabled — |cffFFFF00/wg enable|r turns it back on"` is
  removed. It had no reader.
- **Deprecated API migrations:** none. No deprecated call was found in authored code: the spell
  ladder is LibKa0s-Compat's, and `GetAddOnMetadata` is only the last rung behind
  `C_AddOns.GetAddOnMetadata`.

## SavedVariables / migration notes

- **Old shape:** `global.schemaVersion` is declared with a default of 1 and is never stored.
- **New shape:** the default is 0, and 1 is stored on first login. `NS.SCHEMA_VERSION` stays 1.
- **Migration path:** every install, fresh or existing, reads 0 once, walks the (empty) `0 → 1` step
  and stores 1. The migration is automatic and needs no `/wg reset`. Every future step must be
  idempotent against a fresh default profile (documented in `core/Database.lua`).

## Performance impact

Only the offline scenarios are recorded here, and the "after" figure is whatever 3.3 measures. It
is not estimated.

| Scenario | Before (`tests/perf.lua`, 2026-09-23) | After |
|---|---|---|
| `showFrameRepeat` bytes/iter | 1872.5 | *(recorded by task 3.3)* |
| all other scenarios | unchanged by design | *(confirm on the same run)* |

## Test and complexity movement

- **Pass count:** 727 before. After: 727 + the new cases from C-001/C-002 (3), C-003 (1), C-004 (1)
  and C-010 (up to 3). `docs/test-cases.md` and the README `Tests` badge move in the **same**
  commits.
- **Watch list (for the next release run to confirm; not regenerated here):**
  - `modules/Frame.lua` (1144) and `core/WhatGroup.lua` (1099) stay in the `layout-§1` 1000–1500
    band. `core/WhatGroup.lua` is new to the band since `20260916-184548` and needs a disposition.
  - Max CCN (14, `WhatGroup:ShowFrame`) is not expected to move.

## Known follow-ups

- **U-1 (WowAddonStandards):** amend the `savedvariables-§1` template. Otherwise every addon copying
  it inherits F-003.
- **U-2 (WowAddonStandards, possibly LibKa0s):** the inverted Minimap CLI path (F-015). If LibKa0s
  gains a field, re-vendor the whole folder in its own commit.
- **F-014:** a disposition for `core/WhatGroup.lua` entering the on-notice band, at the next release
  run.

## Verification evidence

- `docs/reviews/2026-09-23/03_SMOKE_TESTS.md` with the sign-off table filled in.
- The commit range on `feat/2026-09-23-review-audit-remediation` implementing M1–M4. *(Fill in
  after landing.)*

## Suggested PR description

```
WhatGroup: close two combat-path popup bugs and harden SavedVariables/degraded paths

- F-001/C-001: reopening a soft-hidden popup in combat with no capture no longer calls Hide() on
  the secure teleport button (ADDON_ACTION_BLOCKED)
- F-002/C-002: the alpha seam honors the combat soft-hide, so "Only out of combat" holds, and the
  minimap button and Esc still close the popup
- F-003/C-003: global.schemaVersion is declared at its pre-versioning value so the stamp persists
  and the first real migration runs
- F-004/C-004: the Options degradation stub no longer replaces the host's RestoreAllDefaults
- F-005/C-005, F-016/C-006: NS.Debug takes format args (debug-logging-§4); teleport handlers are
  built once
- F-007..F-013/C-007..C-011: comment, locale, lint-config and dead-state hygiene

Tests: 727 -> <N>, docs/test-cases.md and the README badge moved in the same commits.
Review bundle: docs/reviews/2026-09-23/
```
