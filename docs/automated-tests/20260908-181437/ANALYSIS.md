# Analysis — 20260908-181437

- **Addon:** WhatGroup 1.3.0
- **Verdict:** green
- **Commit:** e735453 (`feat/2026-09-07-audit-review-remediation`), clean
- **Previous run:** [`20260825-103505`](../20260825-103505/)

## Headline

Three suites pass and one is a permanent skip. Lint 0/0 over 40 files, 554 cases with none failed and
none skipped, `lizard` warns on nothing at max CCN 15 across 1044 functions, and `perf` skips because
this repository ships no `tests/perf.lua`.

Two firsts in this bundle. It is the first written by test-kit revision 15, and the first whose
`RESULTS.md` came out of the runner end to end rather than being typed. And this repository now has
**a file in the `layout-§1` band for the first time** — `tests/test_frame.lua` at 1063, where the
record it replaces said flatly *"No file is within 250 lines of the 1000-LOC threshold."*

## Suites

| Suite | Status | Result | Artifact | Moved since `20260825-103505` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 40 files | [`lint.txt`](lint.txt) | 16 → 40 files; 0/0 unchanged |
| tests | pass | 554 passed, 0 skipped, 0 failed, 554 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 485 → 554 |
| perf | skip | no `tests/perf.lua` | — | Unchanged, and permanent |
| complexity | pass | 0 warnings, max CCN 15 | [`complexity.txt`](complexity.txt) | Totals up; band 0 → 1 file |

**On the `perf` skip.** The first of `automated-tests-§3`'s two sanctioned reasons — *nothing to
run* — not a ratified `performance-§12` exemption. The record is **silent about runtime cost**, and
at the tag a skip is NOT EVALUATED rather than passed.

**Complexity in full.**

| Metric | `20260825-103505` | This run |
|---|---|---|
| Total NLOC | 6377 | 7702 |
| Functions | 906 | 1044 |
| Avg NLOC / function | 6.4 | 6.5 |
| Avg CCN | 1.7 | 1.8 |
| Max CCN | 15 | 15 |
| Avg tokens / function | 46.7 | 48.0 |
| Warnings (CCN > 15) | 0 | 0 |
| Files 1000–1500 | 0 | 1 |
| Files over 1500 | 0 | 0 |

Totals up 21% and 15% — the largest proportional growth of any repository in the collection this
cycle — with the averages moving by a decimal each.

## The ceiling, which is where this addon's whole margin sits

`WhatGroup:LFG_LIST_APPLICATION_STATUS_UPDATED` (`core/WhatGroup.lua@759-821`) is at **CCN 15**: at
the release gate's cap, not over it, so it passes by one point and is not a watch-list entry. It has
been the addon's ceiling since it was named at [`20260807-121935`](../20260807-121935/), where it was
reported at `@634-697`; the function has moved down the file and its score has not moved at all.

That is worth restating on every run, because it has no seam of the kind that made the previous
entries easy to retire. It is one event handler doing one job. The next branch added to it warns, and
a warning blocks the tag.

The two next-highest are both 13: `WhatGroup@702-770` (`modules/Frame.lua`) and
`Compat.GetSpellCooldownRemaining` (`core/Compat.lua@83-100`).

## What moved

- **lint** — 16 → 40 files at 0/0, `M4-11` bringing the test tree into scope.
- **tests** — 485 → 554. `docs/test-cases.md` and the README badge already read 554, and the
  bundle's [`test-cases.md`](test-cases.md) is byte-identical to `docs/test-cases.md` at HEAD, so no
  count claim moves in this commit.
- **Band** — from nothing to one. `tests/test_frame.lua` was 627 lines at the previous run's commit,
  crossed at 987 with `M2-21`'s combat-start re-ask, and reached 1063 with `M2-28`. It is now the
  largest file in the repository, ahead of `core/WhatGroup.lua` at 870, and 293 lines longer than
  the 770-line module it covers. That ratio is the thing worth watching rather than the count.
- **complexity** — nothing warned, and nothing crossed. The empty warnings table is a result here
  rather than an absent section.

## What this run removed from the record, deliberately

The regeneration dropped a hand-written history the runner does not produce. It is kept here because
it is the most useful thing this repository's record has ever contained:

**Every entry this watch list has ever held was retired by splitting the function, and not one by
renewing an *Accepted*.** `WhatGroup:CaptureGroupInfo` (22), `WhatGroup:ShowNotification` (22) and
`Helpers.BuildMainContent` (17) at the [`20260804-182231`](../20260804-182231/) baseline, then
`ConfigureTeleportButton` (20), carried as *peel next* and never as *accepted* until `b1511f6` split
it into five functions — `deferTeleportUntilCombatEnds` (2), `resolveTeleportState` (11),
`applyTeleportNote` (3), `applyTeleportAction` (4) and `ConfigureTeleportButton` itself (6). Four of
four. No entry in this repository's history has aged into the `automated-tests-§4` shelf-life problem.

**And the diagnosis worth keeping, because the obvious one was wrong.** `ConfigureTeleportButton`'s
CCN 20 was read at the time as `and`/`or` defaulting with two nested closures inflating the score. It
was neither: `lizard` scores Lua closures as **separate functions**, so the `PLAYER_REGEN_ENABLED`
handler and the ticker contributed nothing to the parent. The 20 was 12 genuine top-level branches
doing five separable jobs, and the extraction order proves it — pulling the combat deferral out moved
the score not at all (20 → 20), while pulling the state resolution out took it to 11. Anyone reaching
for "it is just defaulting" on a future entry should check the token counts first.

## The `ANALYSIS.md` gap, noted once

Three of nine bundles here carry no `ANALYSIS.md`: `20260807-110421`, `20260825-103505`, and until
this file, this one. The first two are not getting one. An analysis written today into a folder
stamped in August would date a reading to a day nobody took it, which is worse than a gap, because a
gap is legible. Fixed forward. Collection-wide the gap stands at 37 of 95 bundles.

## Actions

None. One new band entry with a re-check trigger, one ceiling function that is named on every run
because it has no easy seam, and no disposition due for conversion — every manifest here carries
`"release": null`, so the three-consecutive-release-runs clock has never started.
