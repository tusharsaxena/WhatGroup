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
| [`20260804-182231`](20260804-182231/) | 1.3.0 | 0/0 | 14 | 415/415 | skip | 5417 | 787 | 6.2 | 1.7 | 22 | 3 | **green** |

## Test suite

415 cases across capture, labels, notifications, lifecycle and the settings surface. The generated inventory `test-cases.md` in each bundle is the authority on what exists at that point; the README badge tracks the same number.

## Lint

Clean over 14 files: 0 warnings, 0 errors. `luacheck .` runs over the addon's own source and its `tests/`; the vendored `libs/` and `tests/_kit/` are out of scope by config, since neither is this repo's to fix.

## Perf

This addon ships no `tests/perf.lua`, so the `perf` column is a permanent `skip` rather than a transient tooling gap. Two things follow, and both are standing facts rather than this run's news: the record says **nothing** about the addon's runtime cost, and `performance-§9`'s zero-overhead evidence — that bracketed instrumentation is free when capture is off — does not exist for it. Adding scenarios is the only thing that changes either.

## Complexity watch list

Current state as of [`20260804-182231`](20260804-182231/) — not that run's diff. Every function `lizard` warned on and every file in `layout-§1`'s 1000–1500 on-notice band, each with a one-line disposition.

| `WhatGroup:CaptureGroupInfo` | 22 | `core/WhatGroup.lua` | **Accepted.** Twenty-odd `or` fallbacks in one flat table constructor — breadth, not depth. |
| `WhatGroup:ShowNotification` | 22 | `core/WhatGroup.lua` | **Accepted.** Nine independent toggle guards mapping 1:1 onto the Notifications panel. |
| `Helpers.BuildMainContent` | 17 | `settings/Panel.lua` | **Peel next** — the lowest-value of the three; the logo and description blocks lift out cleanly. |

**Files in the 1000–1500 band:** None.
