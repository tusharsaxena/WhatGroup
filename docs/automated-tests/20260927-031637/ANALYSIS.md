# Analysis — 20260927-031637

- **Addon:** WhatGroup 1.5.0
- **Verdict:** green
- **Commit:** 62680d3abce207c90cd4fc6ef101a75fdc7d9054 (master), clean
- **Previous run:** [`20260927-030357`](../20260927-030357/) (the 1.5.0 release run)

## Headline

All four suites pass: lint 0/0 over 56 files, 824 headless cases with none failed or skipped, 8 perf
scenarios, and 0 functions above CCN 15 (max 13). The one commit since the 1.5.0 release run,
`62680d3`, split `tests/test_frame.lua` (1422 lines) into `test_frame.lua` (756),
`test_frame_visibility.lua` (616) and a shared `tests/frame_fixture.lua` (85), and this run confirms
it: the 1000–1500 band drops from 3 files to 2, with `tests/test_frame.lua` gone from it. Nothing to
act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260927-030357 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 56 files | [`lint.txt`](lint.txt) | files 54 → 56 (the two new test files); still 0/0 |
| tests | pass | 824 passed, 0 skipped, 0 failed, 824 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged at 824; `test_frame.lua`'s 90 cases now read 54 + 36 (`test_frame_visibility.lua`) |
| perf | pass | 8 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 8 → 8; api/iter and bytes/iter identical; ms/iter drifted with host load |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +19, band 3 → 2; functions, averages and max CCN unchanged |

**Complexity in full**, from `manifest.json`'s `suites.complexity` and the footer in
[`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 12183 |
| Functions | 1591 |
| Avg NLOC / function | 6.7 |
| Avg CCN | 1.8 |
| Max CCN | 13 |
| Avg tokens / function | 50.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 2 |
| Files over the 1500 cap | 0 |

Every suite is a clean pass; there is no failure or skip to explain.

## What moved

- **lint** — 54 → 56 files in scope ([`manifest.json`](manifest.json) `suites.lint.files`): the split
  added `tests/test_frame_visibility.lua` and `tests/frame_fixture.lua`. Still 0 warnings / 0 errors.
- **tests** — 824 → 824, 0 skipped, 0 failed. The count is meant not to move: this was a file split,
  not new coverage. [`test-cases.md`](test-cases.md) shows `test_frame.lua (90)` in the previous
  inventory becoming `test_frame.lua (54)` plus `test_frame_visibility.lua (36)` here; no case was
  added or lost.
- **perf** — 8 → 8 scenarios, api/iter and bytes/iter identical per scenario
  ([`perf.json`](perf.json)). ms/iter moved both ways within host noise (for example
  `showFrameRepeat` 0.01141 → 0.01039, `applyScale` 0.00027 → 0.00028); no production `.lua` changed,
  so this is not a runtime signal.
- **complexity** — NLOC 12164 → 12183 (+19). Per [`complexity.txt`](complexity.txt), the three split
  files total 1047 NLOC (`test_frame.lua` 585, `test_frame_visibility.lua` 402, `frame_fixture.lua` 60)
  against 1029 for the old `test_frame.lua` (+18, per-file headers and the fixture module's
  plumbing), and `tests/run.lua` is 82 → 83 (+1, the new file's registration). Functions 1591 → 1591
  (the old file's 100 are now 57 + 37 + 6). Avg NLOC 6.7, avg CCN 1.8, max CCN 13, avg tokens 50.0
  and 0 warnings are all unchanged. **Band files 3 → 2** (`manifest.json`
  `suites.complexity.bandFiles`): `tests/test_frame.lua` has left the 1000–1500 band; over-cap files
  stay at 0.

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/WhatGroup.lua` | 1161 | Accepted, with a trigger — carried. Unchanged since `20260926-160442`; 1 of 3 release runs against the shelf life (this run is not a release run). Re-check at 1450. |
| 1000–1500 (on notice) | `modules/Frame.lua` | 1211 | Accepted, with a trigger — carried. Unchanged since `20260926-193120`; 1 of 3 release runs against the shelf life (this run is not a release run). Re-check at 1450. |

`tests/test_frame.lua`, 1422 at the previous run, is no longer on the list: it is now 756 lines, below
the band.

## Actions

None.
