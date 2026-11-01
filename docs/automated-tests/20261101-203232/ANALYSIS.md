# Analysis — 20261101-203232

- **Addon:** WhatGroup 1.6.0
- **Verdict:** green
- **Commit:** ff48679b0e8c413c5565cc9b6b2504e9594d9ec2 (feat/2026-11-01-full-skinning), clean
- **Previous run:** [`20261101-142923`](../20261101-142923/)

## Headline

All four suites pass on the re-cut local LibKa0s v1.85.0 at kit revision 50, with both of the kit's skin gates adopted and the teleport icon's edge on `S.IconBorder`'s Texture support. Every perf scenario holds its api/iter and bytes/iter. Smoke checks SKIN-1, SKIN-10, SKIN-32 and SKIN-33 are still owed in game.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-142923 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 76 files | [`lint.txt`](lint.txt) | no |
| tests | pass | 1082 passed, 1 skipped, 0 failed, 1083 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +29 cases, same skip |
| perf | pass | 8 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | api/iter and bytes/iter hold in all 8; only ms/iter moved |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | +97 NLOC, +39 functions; avg CCN and max hold |

**Complexity in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 16422 |
| Functions | 2228 |
| Avg NLOC / function | 6.9 |
| Avg CCN | 1.9 |
| Max CCN | 15 |
| Avg tokens / function | 53.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests** is a pass with one skip, the same case as the previous run: the kit's diagnostics-contract arm for an addon that opts out of turning logging on. WhatGroup keeps the default. The skip is counted in the total and not in `passed`, and at the release gate it is not evaluated rather than passed.

The other three suites are clean passes. The manifest names no skipped suite.

## What moved

This run measures `ff48679`, two commits past the previous row's `1b18cf4` record: the pins of `71900b2` and `FS-WG-GATE`.

**lint: did not move.** 0/0 over 76 files.

**tests: 1054 → 1083.** `tests/test_skin_literals.lua` (3 cases) is deleted in favor of the kit's `test_skin_values` (3 cases), with three rows, all chat output under cause L13. The kit's `test_skin_switch` adds 25 cases over the thirteen surfaces `tests/skin_surfaces.lua` declares. The other four are in `tests/test_frame_skin.lua`, from those two commits.

**perf: api/iter and bytes/iter did not move in any of the 8 scenarios.** The icon's edge is painted at build and on a skin switch, and neither is a measured scenario. Only `ms/iter` moved, as [`perf.txt`](perf.txt) warns it will: `showFrameRepeat` 0.01736 → 0.01062 and `combatGateFlipping` 0.00669 → 0.00447 fell. Timings are for orientation only.

**complexity: grew with the tests, not denser.** 16325 → 16422 NLOC and 2189 → 2228 functions, most of them the small closures in `tests/skin_surfaces.lua`. Avg CCN 1.9 and max CCN 15 hold; avg NLOC went 7.0 → 6.9 and avg tokens 54.3 → 53.8. No warning, no blind or crashed file.

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

None here. The owner's smoke of SKIN-1, SKIN-10, SKIN-32 and SKIN-33 is owed before merge. SKIN-32's expected edge moved in `FS-WG-GATE`; it held no pass mark.
