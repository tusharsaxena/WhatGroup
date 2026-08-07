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

Current state as of [`20260807-022625`](20260807-022625/): **462 cases**, all passing, **none
skipped** — across capture, labels, notifications, lifecycle, the settings surface, the teleport
button and the vendored-payload gate. The count moved with the code this cycle
(422 → 462, +40): the new cases pin the WG-31 teleport cooldown states — unlearned, recharging and
ready — the ticker's single-handle lifecycle, and the re-vendored test kit's own seams. The
generated inventory [`20260807-022625/test-cases.md`](20260807-022625/test-cases.md) is the
authority on exactly which cases exist at that point.

A skipped case is reported as a skip and folded into neither figure (`testing-§5`, `testing-§11`);
this run has none, so `462 passed` and `462 total` are the same set.

## Lint

Current state as of [`20260807-022625`](20260807-022625/): clean over **14 files**, 0 warnings and
0 errors ([`20260807-022625/lint.txt`](20260807-022625/lint.txt)). Scope matters as much as the
result, and here it is narrower than the `0/0` suggests: `.luacheckrc` sets
`exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "tests/" }`, so the 14 files are the
addon's shipped source only — `core/Compat.lua`, `core/CoreSetup.lua`, `core/Database.lua`,
`core/DebugLogSetup.lua`, `core/Util.lua`, `core/WhatGroup.lua`, `defaults/Profile.lua`,
`defaults/TeleportSpells.lua`, `locales/enUS.lua`, `modules/Frame.lua`,
`settings/OptionsSetup.lua`, `settings/Panel.lua`, `settings/Schema.lua`, `settings/Slash.lua`.
The vendored `libs/` and the frozen audit and review bundles are excluded because they are not this
repo's to fix; **`tests/` is excluded too**, which puts **7212 lines of Lua across 22 files**
permanently outside the lint gate — the 15 `test_*.lua` suites (`capture`, `compat`, `database`,
`debuglog`, `frame`, `harness`, `labels`, `libka0s`, `lifecycle`, `notify`, `panel`, `settings`,
`slash`, `util`, `vendor_sync`), the runner pair `run.lua` / `loader.lua`, the `wow_mock.lua` API
stub, and the four vendored kit files `_kit/framework.lua`, `_kit/loader.lua`, `_kit/mock_base.lua`
and `_kit/vendor_sync.lua`. That is a standing fact about the config
([`../testing.md`](../testing.md)'s "Lint scope" says the same), not this run's news — though the
excluded tree has grown by over a thousand lines since it was last stated here.

## Perf

Current state as of [`20260807-022625`](20260807-022625/): **skip — zero scenarios, nothing
measured.** This addon ships no `tests/perf.lua`, so the `perf` column is a permanent `skip` rather
than a transient tooling gap, and every bundle records it as a `skip` with that reason rather than
as a pass. Two things follow, and both are standing facts rather than this run's news: the record
says **nothing** about the addon's runtime cost, and `performance-§9`'s zero-overhead evidence —
that bracketed instrumentation is free when capture is off — does not exist for it.

The reason it ships none is ratified rather than incidental. The original `performance-§12`
no-combat-path exemption **fired** on 2026-08-06 when the teleport cooldown ticker landed, and the
wiring was still declined — reasoned and recorded as the `performance-§12 (re-check fired)` row in
[`../ARCHITECTURE.md`](../ARCHITECTURE.md)'s `## Documented deviations`, which carries its own two
re-check triggers. Adding scenarios is the only thing that changes the `perf` column, and per that
row it is an upstream amendment or a ticker that outgrows its window which changes the decision.

## Complexity watch list

Current state as of [`20260807-022625`](20260807-022625/) — not that run's diff.
Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC
on-notice threshold, each with a one-line disposition.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `ConfigureTeleportButton` | 20 | `modules/Frame.lua:240-396` | **Peel next — NEWLY CROSSED at [`20260807-022625`](20260807-022625/).** Genuine control flow, not `or`-defaulting. Above CCN 15, so it blocks the release gate as it stands. Not accepted. |

**This is the first warned entry since the list emptied**, and it is deliberately not dispositioned
as *Accepted*: a disposition has a shelf life, and an `Accepted` written on an entry's first
appearance is how a watch list becomes a backlog (`automated-tests-§4`, anti-pattern #53). The
three entries the list carried at the [`20260804-182231`](20260804-182231/) baseline —
`WhatGroup:CaptureGroupInfo` at 22, `WhatGroup:ShowNotification` at 22 and `Helpers.BuildMainContent`
at 17 — were each split into named units and are retired, not carried forward; none of them is this
one.

The cause is known and local. `ConfigureTeleportButton` measured **CCN 12** at
[`20260804-233335`](20260804-233335/) and **CCN 20** now, roughly doubling on NLOC (40 → 72), tokens
(296 → 486) and length (78 → 157) as the WG-31 cooldown states landed inside it. `lizard` counts
every `and`/`or` short-circuit as a decision, so the usual Lua reading is "this function defaults a
lot of fields" — that reading does **not** apply here. There are three defaulting expressions in the
whole function; the rest is a combat-lockdown stash-and-bail, a no-spell teardown-and-bail, a
three-way note state machine (unlearned / on cooldown / ready), a ready-vs-not attribute arming
branch and a `known`-vs-unknown tooltip branch nested inside it. It wants decomposition, not a
defaulting rewrite, and `performance-§11` bounds what that refactor may do.

The next four functions are headroom rather than watch-list entries: `WhatGroup:_TryFireJoinNotify`
at 13, then three at 12. See
[`20260807-022625/complexity.txt`](20260807-022625/complexity.txt) for the full per-function table.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| — | — | — | **None.** |

No file reaches 1000 LOC — [`20260807-022625/manifest.json`](20260807-022625/manifest.json)
records `bandFiles: 0` and `overCapFiles: 0`. The three largest by raw line count are
`core/WhatGroup.lua` at 746, `tests/test_libka0s.lua` at 716 and `tests/test_frame.lua` at 627, so
the closest file sits roughly 254 lines below the on-notice threshold.
