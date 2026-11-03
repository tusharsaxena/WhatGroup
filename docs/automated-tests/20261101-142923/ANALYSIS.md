# Analysis — 20261101-142923

- **Addon:** WhatGroup 1.6.0
- **Verdict:** green
- **Commit:** 677fa0ad5ce461bc95e507e0b618a3a36d38ceb4 (feat/2026-11-01-full-skinning), clean
- **Previous run:** [`20261101-025620`](../20261101-025620/)

## Headline

All four suites pass on the local LibKa0s v1.85.0 with the popup's title bar and teleport icon edge on the skin. Seven new cases cover those two. Every perf scenario holds its api/iter and bytes/iter, so the look moved nothing on a repeated show. Smoke checks SKIN-1, SKIN-10, SKIN-32 and SKIN-33 are owed in game.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-025620 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 76 files | [`lint.txt`](lint.txt) | no |
| tests | pass | 1053 passed, 1 skipped, 0 failed, 1054 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +7 cases, same skip |
| perf | pass | 8 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | api/iter and bytes/iter hold in all 8; only ms/iter moved |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | +135 NLOC, +18 functions; avg CCN and max hold |

**Complexity in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 16325 |
| Functions | 2189 |
| Avg NLOC / function | 7.0 |
| Avg CCN | 1.9 |
| Max CCN | 15 |
| Avg tokens / function | 54.3 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests** is a pass with one skip, the same case as the previous run: the kit's diagnostics-contract arm for an addon that opts out of turning logging on. WhatGroup keeps the default. The skip is counted in the total and not in `passed`, and at the release gate it is not evaluated rather than passed.

The other three suites are clean passes. The manifest names no skipped suite.

## What moved

This run measures `677fa0a`, on the full skinning branch: the re-vendor of v1.85.0 with kit revision 49 (`ca3ad1c`), the title bar and icon edge (`e560277`) and the docs (`677fa0a`). `FS-WG-FLIP` has no commit, because this addon has no D2 to D7 rows.

**lint: did not move.** 0/0 over 76 files.

**tests: 1047 → 1054.** Six cases in `tests/test_frame_skin.lua` pin the title bar and the edge on the live library, and one pins the degraded popup's 30px bar. The skin-switch cases write to the drawing setters: the bar's height and anchor are put back by the replay, and the edge's `SetWidth` goes 2 to 1 and back. That is needed because `title.height` and `icon.border` do not change between skins.

**perf: api/iter and bytes/iter did not move in any of the 8 scenarios.** The paint runs once at build and on a skin switch, and neither is a measured scenario. Only `ms/iter` moved: `showFrameRepeat` 0.01156 → 0.01736 and `combatGateFlipping` 0.00560 → 0.00669 rose, and `applyAlpha` 0.00027 → 0.00022 fell. [`perf.txt`](perf.txt) says timings are for orientation only.

**complexity: grew with the code, not denser.** 16190 → 16325 NLOC and 2171 → 2189 functions, nearly all of it test code. Avg NLOC 7.0, avg CCN 1.9 and max CCN 15 hold; avg tokens went 54.2 → 54.3. No warning, no blind or crashed file.

**Band files: 3 → 3, none over the cap, none newly crossed.** `core/WhatGroup.lua` holds at 1233, `modules/Frame.lua` at 1256 and `tests/test_libka0s.lua` at 1070.

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

All three dispositions carried forward with no blank cell, so no new ruling was owed. This is not a release run, so no shelf-life count moved. The full dispositions are in [`../RESULTS.md`](../RESULTS.md).

## Actions

None here. The owner's smoke of SKIN-1, SKIN-10, SKIN-32 and SKIN-33 is owed before merge.
