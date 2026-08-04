# Analysis — 20260804-233335

- **Addon:** WhatGroup 1.3.0
- **Verdict:** green
- **Commit:** 2111c54d9a50 (feat/fix-ccn), dirty
- **Started:** 2026-08-04T23:33:35+05:30
- **Previous run:** [`20260804-215056`](../20260804-215056/)

## Headline

This is the run that closes the CCN work: **zero functions over CCN 15, and an instrument that can
say so.** The code measured here is the same code the previous run measured — identical NLOC,
function count and every average, to the digit — but that run's `Max CCN` column read `0` because
the runner it was recorded with took the figure from `lizard`'s warnings block, which empties out
the moment an addon reaches zero warnings. LibKa0s v1.7.0's testkit takes the maximum over every
function instead, so the column now carries the true figure: **13**. Both gating suites stay clean —
`luacheck` 0/0 across 14 files, 422 of 422 cases pass — and `perf` is still a skip, because this
addon ships no `tests/perf.lua`.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260804-215056` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 14 files | [`lint.txt`](lint.txt) | unchanged — 0/0 across the same 14 files |
| tests | pass | 422 passed, 0 failed, 422 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged — same 422 cases, still 0 failures |
| perf | skip | — (not run: no `tests/perf.lua`) | — no artifact | unchanged — still absent |
| complexity | pass | 0 warnings, max CCN 13 | [`complexity.txt`](complexity.txt) | see below — the code is identical, the instrument is not |

### Complexity in full

Every field of `lizard`'s footer as [`manifest.json`](manifest.json) records it, plus the two
derived file counts. The averages are the point: they are what make a run comparable to its
predecessor across a change in size, and here they say plainly that nothing about the code moved
between the two runs.

| Metric | This run | Previous (`20260804-215056`) | Moved |
|---|---|---|---|
| Total NLOC | 5573 | 5573 | — |
| Functions | 808 | 808 | — |
| Avg NLOC / function | 6.3 | 6.3 | — |
| Avg CCN | 1.7 | 1.7 | — |
| Max CCN | 13 | 0 (reported; true value 13) | instrument, not code |
| Avg tokens / function | 45.6 | 45.6 | — |
| Warnings (CCN > 15) | 0 | 0 | — |
| Warning rate — `Fun Rt` / `nloc Rt` | 0.00 / 0.00 | 0.00 / 0.00 | — |
| Files in the 1000–1500 band | 0 | 0 | — |
| Files over the 1500 cap | 0 | 0 | — |

**The one row that moved is the one that was never a measurement.** The previous run's `maxCcn: 0`
was a kit fault, not a reading: `CCN_MAX` was parsed out of `lizard`'s `!!!! Warnings` block, and
with zero warnings there was nothing to parse. The true figure was in that run's own evidence the
whole time — [`../20260804-215056/complexity.txt`](../20260804-215056/complexity.txt) lists
`WhatGroup@533-573@./core/WhatGroup.lua` at CCN 13, the same function and the same value this
bundle's [`complexity.txt`](complexity.txt) reports. The re-vendored kit reads the maximum over
every `@`-tagged function row, so the column is populated whether or not anything warned.

The highest function in this run is `WhatGroup:_TryFireJoinNotify` at **CCN 13**
(`core/WhatGroup.lua:533-573`), then four at 12: `ConfigureTeleportButton`
(`modules/Frame.lua:184-261`), `WhatGroup:LFG_LIST_APPLICATION_STATUS_UPDATED`
(`core/WhatGroup.lua:619-673`), `WhatGroup:ShowNotification` (`core/WhatGroup.lua:445-477`) and
`WhatGroup:InitSummary` (`core/WhatGroup.lua:174-189`).
None of the five is a watch-list entry — all sit well under the cap, and none was touched by the
refactor that got the addon here. They are headroom figures, and this run's footer line agrees:
`No thresholds exceeded`.

`perf` is a **skip, not a pass.** `tests/perf.lua` does not exist in this addon, so nothing about
runtime cost was measured, and this bundle carries no `perf.txt` or `perf.json` to link.
[`manifest.json`](manifest.json) records the status as `skip` with that reason.

## What moved

- **`Max CCN` 0 → 13, with no code change behind it.** The re-vendored testkit measures the maximum
  over all functions rather than over warned functions only. Same tree, readable column.
- **Complexity warnings unchanged at 0**, which is the state the branch was opened to reach and the
  first run that can be read as such without a caveat.
- **Lint unchanged**, 0 warnings / 0 errors across the same 14 files.
- **Tests unchanged**, 422 passed / 0 failed / 422 total — the seven cases the previous run added
  are all still green.
- **Perf unchanged**, and still absent.
- **Every complexity total and every average unchanged.** Worth saying out loud rather than leaving
  to silence: the two runs bracket a documentation-and-vendoring change, not a code change, and the
  numbers agree.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|
| — | — | — | **None.** |

Nothing warned. The three entries carried at the [`20260804-182231`](../20260804-182231/) baseline —
`WhatGroup:CaptureGroupInfo` at 22, `WhatGroup:ShowNotification` at 22 and
`Helpers.BuildMainContent` at 17 — were each split into named units on this branch, and are retired
rather than carried forward.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| — | — | — | **None.** |

No file reaches the 1000-LOC on-notice threshold. The largest by raw line count is
`core/WhatGroup.lua` at 718, then `tests/test_libka0s.lua` at 645 and `tests/test_panel.lua` at 566.

## Actions

None arising from this run. The one thing it changes is that `RESULTS.md`'s `Max CCN` column is
trustworthy from here on; the historical `0` in the [`20260804-215056`](../20260804-215056/) row
stands as recorded — it is what the instrument of the day said — and `RESULTS.md`'s standing prose
names it as an instrument fault and points at that bundle's `complexity.txt` for the true 13.
