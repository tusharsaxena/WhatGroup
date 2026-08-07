# Analysis — 20260807-121935

- **Addon:** WhatGroup 1.3.0
- **Verdict:** green
- **Commit:** `b1511f67f50b410f0e067af927d047565109edec` (main), clean
- **Previous run:** [`20260807-114405`](../20260807-114405/)

## Headline

Green on both gating suites, and the run this repo's watch list has been waiting for: **the single
`lizard` warning is gone, retired by fix rather than by renewal.** `ConfigureTeleportButton` was
split at `b1511f6` and measures **CCN 6**; max CCN across the addon falls 20 → 15 and the warning
count 1 → 0. That was the last thing standing between this addon and a tag — the release gate
refuses zero-functions-above-CCN-15, and as of this run WhatGroup satisfies it.

Nothing else moved. Lint is clean over the same 14 files, the case count holds at 462, and
`test-cases.md` is byte-identical to the previous run's — the refactor changed no test's identity,
which is the point: it was a pure extraction, verified against the 20 teleport cases that already
existed rather than against new ones written to fit it.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click. A
skipped suite links nothing — there is no artifact — and says what was not measured.

| Suite | Status | Result | Artifact | Moved since 20260807-114405 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 14 files | [`lint.txt`](lint.txt) | No change (0/0 over 14). |
| tests | pass | 462 passed, 0 skipped, 0 failed, 462 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | No change; `test-cases.md` byte-identical. |
| perf | skip | 0 scenarios — no `tests/perf.lua` | *(none — nothing ran)* | No change; a standing skip, not a tooling gap. |
| complexity | pass | **0 warnings** (was 1) | [`complexity.txt`](complexity.txt) | **Max CCN 20 → 15; warnings 1 → 0.** See below. |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every value below is from [`manifest.json`](manifest.json)'s `suites.complexity`, and the raw
footer it was read from is at the end of [`complexity.txt`](complexity.txt).

| Metric | Value | Previous | Moved |
|---|---|---|---|
| Total NLOC | 6114 | 6095 | +19 |
| Functions | 870 | 866 | +4 |
| Avg NLOC / function | 6.4 | 6.4 | — |
| Avg CCN | 1.7 | 1.7 | — |
| Max CCN | **15** | 20 | **−5** |
| Avg tokens / function | 47.0 | 47.1 | −0.1 |
| Warnings (CCN > 15) | **0** | 1 | **−1** |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 | 0.00 / 0.01 | `nloc Rt` cleared |
| Files in the 1000–1500 band | 0 | 0 | — |
| Files over the 1500 cap | 0 | 0 | — |

**Read the totals and the averages together.** Total NLOC rose 19 and the function count rose 4,
which is the extraction's own cost: four new named functions, each with a signature line and a
comment block that used to be an inline comment. Average NLOC per function and average CCN did not
move at all, so the addon did not get denser — it got the same code distributed across more, smaller
units. A refactor that lowered max CCN while raising the *average* would be the shape to worry
about; this is the opposite.

**`perf` — skipped, and nothing was measured.** The suite did not run because the addon ships no
`tests/perf.lua`; the record is therefore silent about WhatGroup's runtime cost, and
`performance-§9`'s zero-overhead evidence does not exist for it. This is a standing fact about the
addon rather than a missing tool — `lua` 5.1.5, `luacheck` 1.2.0 and `lizard` 1.23.0 were all
present and the other three suites ran on them. The manifest records the first of
`automated-tests-§3`'s two sanctioned reasons (*ships no `tests/perf.lua`*); the second and more
informative one also applies and is still not in the manifest — see *Actions*.

**`complexity` — pass, with no warned function for the first time in this record.**
[`complexity.txt`](complexity.txt) carries an empty Warnings block. The highest-CCN function in the
addon is now `WhatGroup@634-697@core/WhatGroup.lua` at **CCN 15** — at the cap, not over it, so it
passes the release gate by one point.

## What moved

Against [`20260807-114405`](../20260807-114405/), one thing moved and it moved on purpose:

- **complexity** — `ConfigureTeleportButton` no longer appears in the Warnings block. It was
  measured at CCN 20 in every run since [`20260807-022625`](../20260807-022625/) and was
  dispositioned *Peel next* rather than *Accepted* throughout. Commit `b1511f6` split it into five
  functions:

  | Function | CCN | Job |
  |---|---|---|
  | `deferTeleportUntilCombatEnds` | 2 | the lockdown stash + `PLAYER_REGEN_ENABLED` retry |
  | `resolveTeleportState` | 11 | spell id, `known`, `remaining`, `ready`, name, texture |
  | `applyTeleportNote` | 3 | the three-state note and the 1s countdown ticker |
  | `applyTeleportAction` | 4 | macro-vs-cleared attributes, tooltip, PreClick trace |
  | `ConfigureTeleportButton` | **6** | the state machine the other four now serve |

  The diagnosis that drove the split is worth recording, because the obvious one was wrong. The
  earlier reading was that CCN 20 was inflated by `and`/`or` defaulting and by the two nested
  closures. It was not: `lizard` scores Lua closures as **separate functions**, so neither the
  `PLAYER_REGEN_ENABLED` handler nor the ticker contributed anything to the parent's score. The 20
  was 12 genuine top-level branches. The evidence is in the extraction order — pulling the combat
  deferral out moved the score not at all (20 → 20, one `if` traded for another), while pulling the
  state resolution out took it straight to 11. Extracting closures would have been wasted work.

- **lint** — 0/0 over 14 files, unchanged. The refactor added no file and removed none.
- **tests** — 462 / 0 / 462, unchanged, and `test-cases.md` is byte-identical between the two
  bundles, so the inventory held its exact contents and not merely its count. This is the load-
  bearing fact for a refactor: the 20 teleport cases in `tests/test_frame.lua` — combat defer and
  rebuild, unlearned, on-cooldown, ready, swipe arming, the ticker counting down and re-arming the
  cast at zero, stale-macro clearing — all passed before the split, after each of the four
  extractions, and after the last one, with no case added, renamed or adjusted to accommodate it.
- **perf** — `skip`, unchanged, same `skipReason`.
- **Total NLOC / function count** — +19 / +4, entirely the extraction. No feature landed between
  the two runs; the only commit is `b1511f6` itself.

## Complexity watch list

**Empty.** No function in the addon is above CCN 15, and no file is at or above `layout-§1`'s
1000-LOC on-notice threshold (`bandFiles` 0, `overCapFiles` 0; the largest file is
`core/WhatGroup.lua` at 746 LOC).

This is the first run in this record with an empty list. Two functions sit close enough to be worth
naming, neither of them a watch-list entry:

| Function | CCN | Location | Note |
|---|---|---|---|
| `WhatGroup` (`LFG_LIST_APPLICATION_STATUS_UPDATED`) | 15 | `core/WhatGroup.lua:634-697` | At the cap, not over it. One more branch blocks a tag. |
| `resolveTeleportState` | 11 | `modules/Frame.lua` | New this run. Mostly `and`/`or` defaulting, unlike the function it came out of. |

## Actions

1. **None blocking.** All four suites are in their terminal state for this addon: two passing, one
   passing with nothing warned, one skipped for a standing structural reason.
2. **Carried, unchanged from the previous run — the `perf` `skipReason` under-reports what is
   known.** `automated-tests-§3` sanctions two perf skip reasons and makes recording the
   `performance-§12` exemption a MUST when it applies. It applies to WhatGroup: the *re-check fired*
   row in [`ARCHITECTURE.md`](../../ARCHITECTURE.md)'s `## Documented deviations` is ratified. The
   manifest carries only the bare *no `tests/perf.lua`*, because the runner reads the filesystem and
   cannot read a deviation register. A reader of this bundle alone cannot tell a ratified exemption
   from a suite nobody wrote. This is a kit/standard question for `LibKa0s`, **not** a defect in this
   repo, and **not** something to hand-edit into a frozen bundle.
3. **Watch `core/WhatGroup.lua:634-697` at CCN 15.** It is the addon's new ceiling and it passes by
   one point. The next branch added to that handler blocks the release gate, and unlike
   `ConfigureTeleportButton` it has no obvious seam — it is one event handler, not five jobs.
