# Analysis — 20261104-042405

- **Addon:** WhatGroup 1.6.0
- **Verdict:** green
- **Commit:** a76ac321e061b5d2034d8798151517b9033c06db (feat/2026-11-01-full-skinning), clean
- **Previous run:** [`20261101-203232`](../20261101-203232/)

## Headline

All four suites pass at the head of round 6 of the full skinning run, on the round 6 re-cut of LibKa0s v1.85.0 (`550ef68`). The suite grew by 17 cases, mostly in the skin picker, the popup skin and the new launcher skin-entry test, and no perf scenario moved in api/iter or bytes/iter. Nothing is owed here. The round's in-game smoke checks are still the owner's to run.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-203232 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 77 files | [`lint.txt`](lint.txt) | +1 file (`tests/test_launcher_skin_entry.lua`), still 0/0 |
| tests | pass | 1099 passed, 1 skipped, 0 failed, 1100 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +17 cases, same skip |
| perf | pass | 8 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | api/iter and bytes/iter hold in all 8; only ms/iter moved |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | +311 NLOC, +47 functions; avg CCN and max hold |

**Complexity in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 16733 |
| Functions | 2275 |
| Avg NLOC / function | 6.9 |
| Avg CCN | 1.9 |
| Max CCN | 15 |
| Avg tokens / function | 53.7 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests** is a pass with one skip, the same case as the previous run: the kit's diagnostics-contract arm for an addon that opts out of turning logging on ([`tests.txt`](tests.txt)). WhatGroup keeps the default, so the case above it holds the contract. The skip is counted in the total and not in `passed`, and at the release gate it is not evaluated rather than passed.

The other three suites are clean passes. The manifest names no skipped suite, and the complexity run was sighted (`blindFiles` 0) and did not crash (`crashedFiles` 0).

## What moved

This run measures `a76ac32`, 26 commits past the previous row's `ff48679`: the skin-feedback fixes (SF-FIX, the launcher menu's Open skin selector and the combat-safe skin notice), the Friz-to-Ubuntu font move (R3-FRIZ), the teleport icon's zoom pin (R3-FIX), the popup's title band (R4-SEP, R5-WIN), the picker's test-mode preview (R6-PV), the README rename (R6-NAME) and a run of LibKa0s v1.85.0 re-cut re-vendors ending at R6-RV2.

**lint: 0/0 held, over 76 → 77 files.** The new file is `tests/test_launcher_skin_entry.lua`.

**tests: 1083 → 1100 (+17).** The added and changed cases sit in `tests/test_skin_picker.lua` (the test-mode preview and the popup mark on close), `tests/test_frame_skin.lua` (the title band and icon edge), the new `tests/test_launcher_skin_entry.lua`, `tests/test_database.lua` (the stored font picks) and `tests/test_panel.lua` (Master controls draws no Sim mode row, since WhatGroup has no simulation), plus whatever the re-vendored kit suites added. [`test-cases.md`](test-cases.md) is the authority on the list.

**perf: api/iter and bytes/iter did not move in any of the 8 scenarios** ([`perf.txt`](perf.txt)). None of this run's changes sit on a measured path. Only `ms/iter` moved, and [`perf.txt`](perf.txt) says timings are for orientation only: `cooldownTick` 0.00172 → 0.00289, `formatDurationShort` 0.00041 → 0.00062, `showFrameRepeat` 0.01062 → 0.01057.

**complexity: grew in size, not density.** 16422 → 16733 NLOC and 2228 → 2275 functions, mostly from `core/SkinSetup.lua` and the skin test files. Avg CCN 1.9, avg NLOC 6.9 and max CCN 15 hold, and avg tokens went 53.8 → 53.7. There are no warnings and no blind or crashed files.

**Band files: 3 → 3, none over the cap, none newly crossed.** None of the three files was touched by this run's commits, so `core/WhatGroup.lua` stays at 1233, `modules/Frame.lua` at 1256 and `tests/test_libka0s.lua` at 1070.

## Complexity watch list

**Functions warned on (CCN > 15):**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/WhatGroup.lua` | 1233 | Accepted, with a trigger, carried. Tracked under the `layout-§1`, `automated-tests-§4` row of `docs/ARCHITECTURE.md`'s `## Documented deviations` |
| 1000–1500 (on notice) | `modules/Frame.lua` | 1256 | Accepted, with a trigger, carried. Same deviation row; under its 1450 trigger |
| 1000–1500 (on notice) | `tests/test_libka0s.lua` | 1070 | Accepted, carried. Case count, not tangle; 1 of 3 release runs; re-check at 1300 |

The runner carried all three dispositions forward and left no cell blank, so no new ruling was owed. This is not a release run, so no shelf-life count moved. The full dispositions are in [`../RESULTS.md`](../RESULTS.md).

## Actions

None.
