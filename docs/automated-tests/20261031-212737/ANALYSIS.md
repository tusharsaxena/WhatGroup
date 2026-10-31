# Analysis — 20261031-212737

- **Addon:** WhatGroup 1.6.0
- **Verdict:** green
- **Commit:** 64f2db9316d1207bc1bdd58efb9d868a98473af6 (feat/2026-10-31-findings-remediation), clean
- **Previous run:** [`20261031-202312`](../20261031-202312/)

## Headline

All four suites pass, so the amber on the previous run is cleared: `showFrameRepeat` fell from 3712.2
to 1648.2 bytes/iter and from 25.0 to 19.0 api/iter, and `perf.txt` reports no failed assertion. Lint
is 0/0 over 76 files and 1046 of 1047 cases passed, with none failed and the same one skip.
Complexity holds at 0 warnings and max CCN 15, and `modules/Frame.lua` is back under its 1450 re-check
trigger at 1256 lines. Nothing here needs acting on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261031-202312 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 76 files | [`lint.txt`](lint.txt) | 72 → 76 files, still 0/0 |
| tests | pass | 1046 passed, 1 skipped, 0 failed, 1047 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1046 → 1047; same one skip |
| perf | pass | 8 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | fail → pass; `showFrameRepeat` api/iter 25.0 → 19.0, bytes/iter 3712.2 → 1648.2 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 15 → 15; 0 warnings → 0 |

**Complexity in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 16177 |
| Functions | 2170 |
| Avg NLOC / function | 7.0 |
| Avg CCN | 1.9 |
| Max CCN | 15 |
| Avg tokens / function | 54.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests** is a pass with one skip, the same case as the previous run: the kit's diagnostics-contract
arm for an addon that opts out of turning logging on ([`tests.txt`](tests.txt), line 1036). WhatGroup
keeps the default, and the case above it holds that. The skip is counted in the total and not in
`passed`, and at the release gate it is not evaluated rather than passed.

The other three suites are clean passes. The manifest names no skipped suite.

## What moved

**lint: 72 → 76 files, still 0/0.** The four new files are `core/Labels.lua`, `core/TestPreview.lua`,
`modules/FrameBinding.lua` and `modules/FrameLayout.lua`, from `00ac519` (FX-WG-SIZE). The exclusions
did not change.

**tests: 1046 → 1047 (+1).** Passed 1045 → 1046, skipped 1 → 1, failed 0 → 0. The new case is in
`test_frame_skin.lua`: "popup skin: a repopulate paints only the values whose token moved, and the
look survives" ([`test-cases.md`](test-cases.md)).

**perf: fail → pass, 8 scenarios.** `showFrameRepeat` api/iter 25.0 → 19.0, bytes/iter 3712.2 → 1648.2.
`combatGateFlipping` bytes/iter 1056.0 → 912.0, api/iter holds at 7.0. The other six scenarios hold
api/iter and bytes/iter. `ms/iter` moved (for example `showFrameRepeat` 0.06611 → 0.01762,
`cooldownTick` 0.00172 → 0.00167); [`perf.txt`](perf.txt) says timings are for orientation only.

Read those two byte figures with their cause attached, because the instrument changed as well as the
addon. `9ccc7ce` (FX-WG-PERF) stopped `FrameSkin.Value` painting a string whose token has not moved,
and in the same commit `tests/wow_mock.lua` stopped building a fresh closure for each missed frame
method and `tests/perf.lua` re-pinned its ceilings. The second change is why `combatGateFlipping`
moved at all, so the two runs' byte figures are not a pure comparison of addon code. This bundle
measures the result and does not split it between the two; `docs/performance.md` records that split.

**complexity: 16125 → 16177 NLOC (+52), 2167 → 2170 functions (+3).** Avg NLOC holds at 7.0, avg CCN
at 1.9, max CCN at 15, warnings at 0; avg tokens 54.1 → 54.2. That is the extra file headers and
requires of the pure moves, not density. Blind and crashed files hold at 0.

**Band files: 3 → 3, none over the cap, none newly crossed.** `core/WhatGroup.lua` 1367 → 1233,
`modules/Frame.lua` 1467 → 1256, `tests/test_libka0s.lua` 1066 → 1066. Both production files shrank
without leaving the band.

## Complexity watch list

**Functions warned on (CCN > 15):**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/WhatGroup.lua` | 1233 | Accepted, with a trigger, carried. Peeled by FX-WG-SIZE; tracked under the `layout-§1`, `automated-tests-§4` row of `docs/ARCHITECTURE.md`'s `## Documented deviations`. 52 functions at avg CCN 4.6, worst CCN 13, none warned |
| 1000–1500 (on notice) | `modules/Frame.lua` | 1256 | Accepted, with a trigger, carried. Peeled by FX-WG-SIZE, so the 1450 trigger is cleared; same deviation row. 62 functions at avg CCN 4.2, worst CCN 11, none warned |
| 1000–1500 (on notice) | `tests/test_libka0s.lua` | 1066 | Accepted, carried. Case count, not tangle (69 functions, avg CCN 2.1); 1 of 3 release runs; re-check at 1300 |

All three dispositions carried forward with no blank cell, so no new ruling was owed. This is not a
release run, so no shelf-life count moved. The full dispositions are in
[`../RESULTS.md`](../RESULTS.md).

## Actions

None. The previous run's three are closed: `showFrameRepeat` passes (action 1), `buildFrame` is peeled
into `modules/FrameLayout.lua` (action 2), and both production files now carry the tracked deviation
row in `docs/ARCHITECTURE.md` (action 3).
