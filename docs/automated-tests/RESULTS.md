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

**Reading the `Max CCN` column: the `0` in the [`20260804-215056`](20260804-215056/) row is an
instrument fault, not a measurement.** Runs recorded before the LibKa0s v1.7.0 testkit (revision 6)
was vendored — [`20260804-182231`](20260804-182231/) and [`20260804-215056`](20260804-215056/) —
read `Max CCN` out of `lizard`'s `!!!! Warnings` block, which is empty once nothing warns, so the
field collapsed to `0` the moment this addon reached zero warnings. The true figure was always in
that same bundle's own `complexity.txt`: for `20260804-215056` it is **13**
(`WhatGroup@533-573@./core/WhatGroup.lua`, in
[`20260804-215056/complexity.txt`](20260804-215056/complexity.txt)) — identical to the 13 the
[`20260804-233335`](20260804-233335/) row reports for the same tree. The `22` in the
`20260804-182231` row is sound, because that run did have warned functions to take a maximum over.
The rows stand as recorded (`performance-§10`): a hand-corrected number reads as measured, and this
note is how the correction is made instead.

## Test suite

Current state as of [`20260804-233335`](20260804-233335/): **422 cases** across capture, labels,
notifications, lifecycle and the settings surface. The count moved with the code this cycle
(415 → 422 at [`20260804-215056`](20260804-215056/)): the seven new cases pin the `or`-defaulting
and Leader-row behavior that the CCN refactor could otherwise have broken silently, plus the
landing page's widget order and its dirty-page re-render. The generated inventory
[`20260804-233335/test-cases.md`](20260804-233335/test-cases.md) is the authority on exactly which
cases exist at that point; the README badge tracks the same number.

## Lint

Current state as of [`20260804-233335`](20260804-233335/): clean over **14 files**, 0 warnings and
0 errors ([`20260804-233335/lint.txt`](20260804-233335/lint.txt)). Scope matters as much as the
result, and here it is narrower than the `0/0` suggests: `.luacheckrc` sets
`exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "tests/" }`, so the 14 files are the
addon's shipped source only — `core/Compat.lua`, `core/CoreSetup.lua`, `core/Database.lua`,
`core/DebugLogSetup.lua`, `core/Util.lua`, `core/WhatGroup.lua`, `defaults/Profile.lua`,
`defaults/TeleportSpells.lua`, `locales/enUS.lua`, `modules/Frame.lua`,
`settings/OptionsSetup.lua`, `settings/Panel.lua`, `settings/Schema.lua`, `settings/Slash.lua`.
The vendored `libs/` and the frozen audit and review bundles are excluded because they are not this
repo's to fix; **`tests/` is excluded too**, which puts 6098 lines of Lua across 20 files
permanently outside the lint gate — the 14 `test_*.lua` suites (`capture`, `compat`, `database`,
`debuglog`, `frame`, `harness`, `labels`, `libka0s`, `lifecycle`, `notify`, `panel`, `settings`,
`slash`, `util`), the runner pair `run.lua` / `loader.lua`, the `wow_mock.lua` API stub, and the
three vendored kit files `_kit/framework.lua`, `_kit/loader.lua` and `_kit/mock_base.lua`. That is
a standing fact about the config (`docs/testing.md`'s "Lint scope" says the same), not this run's
news.

## Perf

Current state as of [`20260804-233335`](20260804-233335/): **skip — zero scenarios, nothing
measured.** This addon ships no `tests/perf.lua`, so the `perf` column is a permanent `skip` rather
than a transient tooling gap, and every bundle records it as a `skip` with that reason rather than
as a pass. Two things follow, and both are standing facts rather than this run's news: the record
says **nothing** about the addon's runtime cost, and `performance-§9`'s zero-overhead evidence —
that bracketed instrumentation is free when capture is off — does not exist for it. Adding
scenarios is the only thing that changes either.

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

The five highest functions are all headroom figures rather than watch-list entries, and none was
touched by that work: `WhatGroup:_TryFireJoinNotify` at **13** (`core/WhatGroup.lua:533-573`), then
four at **12** — `ConfigureTeleportButton` (`modules/Frame.lua:184-261`),
`WhatGroup:LFG_LIST_APPLICATION_STATUS_UPDATED` (`core/WhatGroup.lua:619-673`),
`WhatGroup:ShowNotification` (`core/WhatGroup.lua:445-477`) and `WhatGroup:InitSummary`
(`core/WhatGroup.lua:174-189`). See
[`20260804-233335/complexity.txt`](20260804-233335/complexity.txt) for the full per-function table.
The `0` one row above in the `Max CCN` column is the instrument fault described under the table, not
a different tree.

### Files by `layout-§1` band

**None.** No file reaches 1000 LOC — [`20260804-233335/manifest.json`](20260804-233335/manifest.json)
records `bandFiles: 0` and `overCapFiles: 0`. The three largest by raw line count are
`core/WhatGroup.lua` at 718, `tests/test_libka0s.lua` at 645 and `tests/test_panel.lua` at 566, so
the closest file sits roughly 280 lines below the on-notice threshold.
