# Analysis — 20260804-215056

- **Addon:** WhatGroup 1.3.0
- **Verdict:** green
- **Commit:** 9f3c069f92de (feat/fix-ccn), dirty
- **Started:** 2026-08-04T21:50:56+05:30
- **Previous run:** [`20260804-182231`](../20260804-182231/) — the adoption baseline

## Headline

The first run recorded on `feat/fix-ccn`, the branch whose whole purpose is the last section of
this record: **`lizard` warns on nothing.** The three functions that were over the CCN 15 cap at
the baseline — `WhatGroup:CaptureGroupInfo` (22), `WhatGroup:ShowNotification` (22) and
`Helpers.BuildMainContent` (17) — are each split into named units, and neither they nor anything
they were split into warns now. Both gating suites stay clean: `luacheck` 0 warnings / 0 errors
across 14 files, and the harness passes 422 of 422 cases, up from 415 because the branch pinned
behavior that nothing pinned before. The offline perf runner is still absent, so this record still
says nothing about runtime cost.

## Suites

| Suite | Status | Result | Artifact | Moved since previous run |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 14 files | [`lint.txt`](lint.txt) | unchanged — 0/0 across the same 14 files |
| tests | pass | 422 passed, 0 failed, 422 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +7 cases (415 → 422), still 0 failures |
| perf | skip | — | — (not run) | unchanged — still no `tests/perf.lua` |
| complexity | pass | 0 warnings (was 3) | [`complexity.txt`](complexity.txt) | see below |

### Complexity in full

Every field of `lizard`'s footer, plus the two derived file counts. The **averages** are what make
this run comparable to the previous one across a change in size: a total that rises because the
addon grew is a different fact from an average that rises because it got denser, and only the
second is a complexity signal. Here the totals rose and the averages did not, which is the reading
a split-into-named-helpers refactor plus seven new test cases should produce.

| Metric | This run | Previous (`20260804-182231`) | Moved |
|---|---|---|---|
| Total NLOC | 5573 | 5417 | +156 |
| Functions | 808 | 787 | +21 |
| Avg NLOC / function | 6.3 | 6.2 | +0.1 |
| Avg CCN | 1.7 | 1.7 | — |
| Max CCN **among warned functions** | 0 (none warned) | 22 | −22 |
| Avg tokens / function | 45.6 | 45.5 | +0.1 |
| Warnings (CCN > 15) | 0 | 3 | −3 |
| Warning rate — `Fun Rt` / `nloc Rt` | 0.00 / 0.00 | 0.0 / 0.03 | −0.03 on `nloc Rt` |
| Files in the 1000–1500 band | 0 | 0 | — |
| Files over the 1500 cap | 0 | 0 | — |

Two of those rows need a caveat rather than a celebration.

**"Max CCN 0" is an artifact of the field's definition, not a claim that nothing branches.** That
row and the manifest's `maxCcn` both report the maximum over *warned* functions, and there are
none. Re-measured with `lizard -C 1`, the addon's actual highest function is
`WhatGroup:_TryFireJoinNotify` at **CCN 13** (`core/WhatGroup.lua:533-573`), then
`ConfigureTeleportButton` at 12 (`modules/Frame.lua:184-261`) and
`WhatGroup:LFG_LIST_APPLICATION_STATUS_UPDATED` at 12 (`core/WhatGroup.lua:619-673`). Nothing on
the branch touched any of the three; they were under the cap before and are under it now.

**+21 functions and +156 NLOC is most of what "0 warnings" cost.** The refactor did not delete
branches so much as move them behind names: `buildCapture` (10) and `applyActivityInfo` (10) carry
the `or` chains `CaptureGroupInfo` (now 4) used to hold inline; `teleportValue` (5) and the five
`NOTIFY_ROWS` closures (1–3 each) carry what `ShowNotification` (now 12) used to hold inline;
`justifyLeft` (3), `addLogo` (1), `addNotesLine` (6) and `addCommandRows` (4) carry what
`BuildMainContent` (now 3) used to hold inline. `lizard` scores each of those separately, so part
of the drop is attribution rather than removal. `justifyLeft` is the one place a branch genuinely
disappeared: the same two-line justify guard was written out twice and is now written once.

`tests/perf.lua` is absent — this addon ships no offline scenarios, so nothing was measured there.
That is a **skip, not a pass**: it is recorded as one in `manifest.json`, and it means this run
says nothing about the addon's runtime cost.

## What moved

- **Complexity warnings 3 → 0.** The point of the branch, and the only structural change here.
- **Tests 415 → 422.** Seven cases, each pinning behavior the refactor could have broken silently
  and that nothing pinned before: `false`-takes-the-default for both field groups, the stored-zero
  counterpart that records why `0` was never the value at risk, the Leader row still printing with
  a `nil` leaderName, its Playstyle/Teleport suppression counterpart, the landing page's widget
  order and left-justification, and the dirty-page re-render that keeps a second logo off the
  scroll.
- **Lint unchanged**, at 0/0 across the same 14 files.
- **Perf unchanged**, and still absent.

## Complexity watch list

### Functions `lizard` warned on

**None.**

### Files by `layout-§1` band

None — no file reaches 1000 LOC. The largest by raw line count is `core/WhatGroup.lua` at 718,
then `tests/test_libka0s.lua` at 645 and `tests/test_panel.lua` at 566.

## Actions

None arising from this run. The three dispositions the baseline carried — `CaptureGroupInfo`
**Accepted**, `ShowNotification` **Accepted**, `BuildMainContent` **Peel next** — are retired
rather than carried forward: all three functions are now under the cap, so there is nothing left
to accept or to peel.
