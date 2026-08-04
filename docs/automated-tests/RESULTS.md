# Automated test results

<!-- The newest run is prepended by tests/_kit/run-automated-tests.sh. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate. `perf` and `complexity` are recorded and never fail a run** —
they are read and compared, not thresholded. A `skip` is a suite that did not run at all,
which is never the same as a pass.

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260804-233335`](20260804-233335/) | 1.3.0 | 0/0 | 14 | 422/422 | skip | 5573 | 808 | 6.3 | 1.7 | 13 | 0 | **green** |
| [`20260804-215056`](20260804-215056/) | 1.3.0 | 0/0 | 14 | 422/422 | skip | 5573 | 808 | 6.3 | 1.7 | 0 | 0 | **green** |
| [`20260804-182231`](20260804-182231/) | 1.3.0 | 0/0 | 14 | 415/415 | skip | 5417 | 787 | 6.2 | 1.7 | 22 | 3 | **green** |

## Test suite

422 cases across capture, labels, notifications, lifecycle and the settings surface. The generated inventory `test-cases.md` in each bundle is the authority on what exists at that point; the README badge tracks the same number.

## Lint

Clean over 14 files: 0 warnings, 0 errors. `luacheck .` runs over the addon's own source and its `tests/`; the vendored `libs/` and `tests/_kit/` are out of scope by config, since neither is this repo's to fix.

## Perf

This addon ships no `tests/perf.lua`, so the `perf` column is a permanent `skip` rather than a transient tooling gap. Two things follow, and both are standing facts rather than this run's news: the record says **nothing** about the addon's runtime cost, and `performance-§9`'s zero-overhead evidence — that bracketed instrumentation is free when capture is off — does not exist for it. Adding scenarios is the only thing that changes either.

## Complexity watch list

Current state as of [`20260804-233335`](20260804-233335/) — not that run's diff.
Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC
on-notice threshold, each with a one-line disposition.

### Functions `lizard` warned on

**None.**

That is this run's result, not an omission. The three entries this table carried at the
[`20260804-182231`](20260804-182231/) baseline — `WhatGroup:CaptureGroupInfo` at 22,
`WhatGroup:ShowNotification` at 22 and `Helpers.BuildMainContent` at 17 — were all split into
named units, so their **Accepted** / **Peel next** dispositions are retired rather than carried
forward: there is nothing left to accept or to peel. `lizard` now warns on nothing in this addon.

The highest function is `WhatGroup:_TryFireJoinNotify` at **CCN 13** (`core/WhatGroup.lua`), well
under the cap and untouched by that work — a headroom figure, not a watch-list entry. The
[`20260804-233335`](20260804-233335/) row reports that 13 in its own `Max CCN` column; the
[`20260804-215056`](20260804-215056/) row above it reads 0 for the same tree, because the runner
read `Max CCN` out of `lizard`'s warnings block and so had no input once the warnings hit zero.
LibKa0s v1.7.0's testkit revision 6 measures it over every function instead, and re-vendoring it is
what made the column readable here. The two rows are the same code; only the measurement changed.

### Files by `layout-§1` band

None — no file reaches 1000 LOC. Refreshed against this run: the largest by raw line count is
`core/WhatGroup.lua` at 718, then `tests/test_libka0s.lua` at 645 and `tests/test_panel.lua` at
566. Nothing is close to the 1000-LOC on-notice threshold, and this branch moved the two source
files by a few dozen lines each.
