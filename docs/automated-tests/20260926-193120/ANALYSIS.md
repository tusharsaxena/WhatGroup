# Analysis — 20260926-193120

- **Addon:** WhatGroup 1.4.0
- **Verdict:** green
- **Commit:** a6e144b30552cdd9d510476eb5491b0db714b9b7 (feat/2026-09-26-automated-tests-sweep), clean
- **Previous run:** [`20260926-160442`](../20260926-160442/)

## Headline

All four suites pass on a clean tree: lint 0/0 over 54 files, 824 headless cases with nothing
skipped, 8 perf scenarios with no ceiling tripped, and 0 functions above CCN 15. This is the closing
run of the 2026-09-26 automated-tests sweep, three commits after the previous record (the
`WG-ATS-00` record itself, the LibKa0s v1.62.0 re-vendor `WG-ATS-RV`, and the `WG-ATS-01` peel). Max
CCN fell 15 → 13: `NS.FrameSnapshot` is no longer at the warning threshold. Nothing to act on; the
three band dispositions are refreshed to today's figures in [`../RESULTS.md`](../RESULTS.md).

## Suites

| Suite | Status | Result | Artifact | Moved since 20260926-160442 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 54 files | [`lint.txt`](lint.txt) | unchanged: same 54 files, 0/0 |
| tests | pass | 824 passed, 0 skipped, 0 failed, 824 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 823 → 824 (+1) |
| perf | pass | 8 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 8 → 8; api/iter and bytes/iter identical; ms/iter lower on all 8 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings, unchanged; max CCN 15 → 13 |

**Complexity in full**, from `manifest.json`'s `suites.complexity` and the footer in
[`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 12164 |
| Functions | 1591 |
| Avg NLOC / function | 6.7 |
| Avg CCN | 1.8 |
| Max CCN | 13 |
| Avg tokens / function | 50.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |

Every suite passed cleanly and none was skipped. No case reported a `Kit.skip`: passed and total
are both 824 (`manifest.json` → `suites.tests`), so the row claims no coverage that was not
exercised. `perf` is a `pass` with `"failures": []` in [`perf.json`](perf.json).

## What moved

**lint: 54 → 54 files, still 0/0.** The two runs' `lint.txt` file lists are identical. The
re-vendored LibKa0s files sit under `libs/`, which `.luacheckrc` excludes (see
[`../RESULTS.md`](../RESULTS.md) → `## Lint`).

**tests: 823 → 824 (+1).** From the two runs' `test-cases.md` `## Totals` tables, the only change
is `test_snapshot` 9 → 10: the characterization case `a6e144b` (WG-ATS-01) added to pin every coerced
snapshot flag as a strict boolean before the refactor. No suite lost a case; `test_frame` stays at
90.

**perf: 8 scenarios, no ceiling tripped.** API calls and bytes per iteration are identical to the
previous run on all eight scenarios (`cooldownTick` still 2 API / 240.4 bytes per tick). Every
`ms/iter` figure is lower (for example `showFrameRepeat` 0.02691 → 0.01016, `combatGateFlipping`
0.00930 → 0.00475). None of the benchmarked paths changed, so this is host load moving the other
way, not a speed-up; [`perf.txt`](perf.txt) says timings are for orientation only.

**complexity: flat in size and density; the max came down.** Total NLOC 12141 → 12164 (+23),
functions 1589 → 1591 (+2). Avg NLOC per function 6.7, avg CCN 1.8 and avg tokens 50.0 all held.
Warnings stayed at 0. Max CCN fell 15 → 13: `a6e144b` routed `NS.FrameSnapshot`'s two visibility
coercions through `isShownFlag@1166-1168@./modules/Frame.lua` (CCN 4), leaving
`NS.FrameSnapshot@1173-1192` at CCN 9. The addon's worst functions are now three at CCN 13:
`WhatGroup@1035-1103@./core/WhatGroup.lua`, `WhatGroup@1038-1091@./modules/Frame.lua` and
`identity@62-71@./modules/Diagnostics.lua`.

**Band files: 3 → 3, none over the cap.** `core/WhatGroup.lua` 1161 → 1161, `modules/Frame.lua`
1206 → 1211 (+5, the helper), `tests/test_frame.lua` 1422 → 1422. All three remain below their
shared 1450 re-check line. Nothing entered or left the band.

## Complexity watch list

**Functions warned on (CCN > 15):**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/WhatGroup.lua` | 1161 | Accepted, with a trigger — carried; unchanged this run; re-check at 1450 (`WHATGROUP-R-14`) |
| 1000–1500 (on notice) | `modules/Frame.lua` | 1211 | Accepted, with a trigger — re-stated; the at-the-threshold note is retired now `NS.FrameSnapshot` is CCN 9; re-check at 1450 (`WHATGROUP-R-14`) |
| 1000–1500 (on notice) | `tests/test_frame.lua` | 1422 | Accepted, with a trigger — the ruling stands; 90 cases, unchanged; re-check at 1450 (`WHATGROUP-R-14`) |

The full dispositions are in [`../RESULTS.md`](../RESULTS.md). No entry newly crossed a threshold.

## Actions

None.
