# Automated test results

<!-- The newest run is prepended by tests/_kit/run-automated-tests.sh. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate the run and gate the commit** (`testing-§4`).
**`perf` and `complexity` never fail a run and never block a commit** — they are recorded,
read and compared, not thresholded (`performance-§9`, `performance-§10`).

**The tag is gated on all four suites at `pass`, plus zero functions above CCN 15**
(`automated-tests-§3`, *The release gate*), evaluated by `/wow-addon:bump-version` from the
`manifest.json` the release run writes — not by the runner, whose exit code is unchanged.

A `skip` is a suite that did not run at all. It is never a pass, and at the release gate it is
**NOT EVALUATED** rather than passed: install the tool and re-run. A `—` is a suite that was
not selected, which is a different fact again.

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260807-121935`](20260807-121935/) | 1.3.0 | 0/0 | 14 | 462/462 | skip | 6114 | 870 | 6.4 | 1.7 | 15 | 0 | **green** |
| [`20260807-114405`](20260807-114405/) | 1.3.0 | 0/0 | 14 | 462/462 | skip | 6095 | 866 | 6.4 | 1.7 | 20 | 1 | **green** |
| [`20260807-110421`](20260807-110421/) | 1.3.0 | 0/0 | 14 | 462/462 | skip | 6095 | 866 | 6.4 | 1.7 | 20 | 1 | **green** |
| [`20260807-022625`](20260807-022625/) | 1.3.0 | 0/0 | 14 | 462/462 | skip | 6095 | 866 | 6.4 | 1.7 | 20 | 1 | **green** |
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

Current state as of [`20260807-121935`](20260807-121935/): **462 cases**, all passing, **none
skipped** — across capture, labels, notifications, lifecycle, the settings surface, the teleport
button and the vendored-payload gate. The generated inventory
[`20260807-121935/test-cases.md`](20260807-121935/test-cases.md) is the authority on exactly which
cases exist.

The count has held at 462 across four consecutive runs, and this run is the one that shows why that
is not a coverage gap. `b1511f6` split `ConfigureTeleportButton` into five functions — a real change
to the file the teleport cases exercise — and `test-cases.md` came out **byte-identical** to the
previous run's. That is the correct outcome for a pure extraction and it is the strongest statement
this suite makes all record: the 20 teleport cases in `tests/test_frame.lua` (combat defer and
rebuild, unlearned, on-cooldown, ready, swipe arming, the ticker counting down and re-arming the
cast at zero, stale-macro clearing) were sufficient to verify the refactor without one case being
added, renamed or adjusted to fit it. A suite that has to change shape to accept a refactor was
testing the implementation; this one was testing the behaviour.

The count last moved at [`20260807-022625`](20260807-022625/) (422 → 462, +40), when the WG-31
teleport cooldown states, the ticker's single-handle lifecycle and the re-vendored kit's own seams
were pinned. The next thing that should move it is a feature, not a refactor.

A skipped case is reported as a skip and folded into neither figure (`testing-§5`, `testing-§11`);
this run has none, so `462 passed` and `462 total` are the same set.

## Lint

Current state as of [`20260807-121935`](20260807-121935/): clean over **14 files**, 0 warnings and
0 errors ([`20260807-121935/lint.txt`](20260807-121935/lint.txt)). Scope matters as much as the
result, and here it is narrower than the `0/0` suggests: `.luacheckrc` sets
`exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "tests/" }`, so the 14 files are the
addon's shipped source only — `core/Compat.lua`, `core/CoreSetup.lua`, `core/Database.lua`,
`core/DebugLogSetup.lua`, `core/Util.lua`, `core/WhatGroup.lua`, `defaults/Profile.lua`,
`defaults/TeleportSpells.lua`, `locales/enUS.lua`, `modules/Frame.lua`,
`settings/OptionsSetup.lua`, `settings/Panel.lua`, `settings/Schema.lua`, `settings/Slash.lua`.

The file count did not move across `b1511f6` and would not: the refactor added four functions inside
`modules/Frame.lua`, not four files. Lint counts files, so a `0/0 over 14` is silent about a change
of this shape — which is exactly why the complexity suite exists beside it.

The vendored `libs/` and the frozen audit and review bundles are excluded because they are not this
repo's to fix. **`tests/` is excluded too**, which puts **7212 lines of Lua across 22 files**
permanently outside the lint gate — the 15 `test_*.lua` suites (`capture`, `compat`, `database`,
`debuglog`, `frame`, `harness`, `labels`, `libka0s`, `lifecycle`, `notify`, `panel`, `settings`,
`slash`, `util`, `vendor_sync`), the runner pair `run.lua` / `loader.lua`, the `wow_mock.lua` API
stub, and the four vendored kit files `_kit/framework.lua`, `_kit/loader.lua`, `_kit/mock_base.lua`
and `_kit/vendor_sync.lua`. That is a standing fact about the config
([`../testing.md`](../testing.md)'s "Lint scope" says the same), not this run's news — but it is
worth restating that the excluded tree is **larger than the linted one**: 7212 lines outside the
gate against 6114 total NLOC measured across the whole repo.

## Perf

Current state as of [`20260807-121935`](20260807-121935/): **skip — zero scenarios, nothing
measured.** This addon ships no `tests/perf.lua`, so the `perf` column is a permanent `skip` rather
than a transient tooling gap, and every bundle records it as a `skip` with that reason rather than
as a pass. Two things follow, and both are standing facts rather than this run's news: the record
says **nothing** about the addon's runtime cost, and `performance-§9`'s zero-overhead evidence —
that bracketed instrumentation is free when capture is off — does not exist for it.

The reason it ships none is ratified rather than incidental. The original `performance-§12`
no-combat-path exemption **fired** on 2026-08-06 when the teleport cooldown ticker landed, and the
wiring was still declined — reasoned and recorded as the `performance-§12 (re-check fired)` row in
[`../ARCHITECTURE.md`](../ARCHITECTURE.md)'s `## Documented deviations`, which carries its own two
re-check triggers. `b1511f6` moved that ticker from `modules/Frame.lua:327` to `:146` and left its
lifecycle untouched — one handle, replaced not stacked, cancelled from the popup's `OnHide`, from
the top of every `ConfigureTeleportButton` run and by the tick that reaches zero — so neither
re-check trigger fired and the row stands as written. The citations in that row, in
[`../performance.md`](../performance.md), [`../frame.md`](../frame.md) and
[`../module-map.md`](../module-map.md) were re-anchored to the new line in the same commit.

One gap is worth naming, and it is the kit's rather than this repo's: `automated-tests-§3` sanctions
**two** `perf` skip reasons and says the `performance-§12` exemption **MUST** be recorded when it
applies. It applies here, but the manifest carries only the bare *ships no `tests/perf.lua`*,
because the runner has no way to read the deviation register. A reader of the bundle alone therefore
cannot tell this addon's ratified exemption from a suite somebody forgot to write — the register
above is the only place that distinction lives. Raising it upstream is
[`20260807-121935/ANALYSIS.md`](20260807-121935/ANALYSIS.md)'s action 2, carried unchanged.

## Complexity watch list

Current state as of [`20260807-121935`](20260807-121935/) — not that run's diff.
Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC
on-notice threshold, each with a one-line disposition.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|
| *(none)* | — | — | No function in the addon is above CCN 15. |

**The list is empty for the first time in this record, and it emptied by fix.**
`ConfigureTeleportButton` was carried at CCN 20 from [`20260807-022625`](20260807-022625/) through
[`20260807-114405`](20260807-114405/), dispositioned *Peel next* and never *Accepted*. `b1511f6`
split it into five functions — `deferTeleportUntilCombatEnds` (CCN 2), `resolveTeleportState` (11),
`applyTeleportNote` (3), `applyTeleportAction` (4) and `ConfigureTeleportButton` itself (**6**) —
and the entry is **retired**, not carried forward.

That makes three of three: every entry this watch list has ever held —
`WhatGroup:CaptureGroupInfo` at 22, `WhatGroup:ShowNotification` at 22 and
`Helpers.BuildMainContent` at 17 at the [`20260804-182231`](20260804-182231/) baseline, then
`ConfigureTeleportButton` at 20 — was resolved by splitting the function, and none by renewing an
*Accepted*. No entry in this repo's history has aged into the `automated-tests-§4` /
anti-pattern #53 problem, and the shelf-life clock (three consecutive **release** runs) has still
never started, because no run in this record is a release run.

**Diagnosis worth keeping, because the obvious one was wrong.** The CCN 20 was read at the time as
`and`/`or` defaulting plus two nested closures inflating the score. It was neither: `lizard` scores
Lua closures as **separate functions**, so the `PLAYER_REGEN_ENABLED` handler and the ticker
contributed nothing to the parent. The 20 was 12 genuine top-level branches doing five separable
jobs. The extraction order proves it — pulling out the combat deferral moved the score not at all
(20 → 20), while pulling out the state resolution took it to 11. Anyone reaching for "it's just
defaulting" on a future entry should confirm it against the token counts first.

### Files at or above the `layout-§1` on-notice threshold

| Band | File | LOC | Disposition |
|---|---|---|---|
| *(none)* | — | — | `bandFiles` 0, `overCapFiles` 0. |

No file is within 250 lines of the 1000-LOC threshold; the largest is `core/WhatGroup.lua` at 746.

### Not warned, but at the ceiling

`WhatGroup@634-697@core/WhatGroup.lua` (the `LFG_LIST_APPLICATION_STATUS_UPDATED` handler) sits at
**CCN 15** — at the release gate's cap, not over it, so it passes by one point and is not a watch-
list entry. It is now the addon's ceiling. Worth naming because it has no seam of the kind that made
`ConfigureTeleportButton` easy to split: it is one event handler doing one job, so the next branch
added to it is a harder problem than the one just solved, and it blocks a tag the moment it lands.
