# Analysis — 20260916-184548

- **Addon:** WhatGroup 1.4.0
- **Verdict:** green
- **Commit:** d64656bba234b790b690659f86cd0b8e428c65ee (master), clean
- **Previous run:** [`20260916-094455`](../20260916-094455/)

## Headline

All four suites pass: lint 0/0 over 45 files, 667 headless cases with nothing skipped, and — for the
first time in this repo's record — `perf` reports a real figure instead of a skip, because
`tests/perf.lua` landed in commit `1e11d4c` after the previous run. Complexity is flat where it
matters: 0 functions above CCN 15, max CCN still 15, average CCN still 1.8, and average NLOC per
function actually *fell* from 6.8 to 6.7 while the addon grew by 774 NLOC and 99 functions — growth,
not densification. Nothing newly crossed a threshold; the one stale item is `modules/Frame.lua`'s
band disposition, which is re-argued below and in [`../RESULTS.md`](../RESULTS.md).

## Suites

| Suite | Status | Result | Artifact | Moved since 20260916-094455 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 45 files | [`lint.txt`](lint.txt) | 42 → 45 files; still 0/0 |
| tests | pass | 667 passed, 0 skipped, 0 failed, 667 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 632 → 667 (+35) |
| perf | pass | 8 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | **skip → pass**; 0 → 8 scenarios |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings, unchanged |

**Complexity in full**, from `manifest.json`'s `suites.complexity` and the `lizard` footer in
[`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 9903 |
| Functions | 1298 |
| Avg NLOC / function | 6.7 |
| Avg CCN | 1.8 |
| Max CCN | 15 |
| Avg tokens / function | 49.1 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 2 |
| Files over the 1500 cap | 0 |

Every suite is a clean pass, so there is no non-pass paragraph to write. Nothing was skipped this
run, and no individual case reported a `Kit.skip` — passed and total agree at 667, so the row claims
no coverage that was not exercised.

## What moved

**lint — 42 → 45 files, still 0/0.** The three new files are `core/LauncherSetup.lua`,
`tests/perf.lua` and `tests/test_launcher.lua` (diff of the two runs' `lint.txt` file lists). The
scope is what [`../RESULTS.md`](../RESULTS.md)'s `## Lint` section restates: `.luacheckrc` excludes
`libs/`, `docs/audits/`, `docs/reviews/`, `_dev/` and `tests/_kit/`, so the vendored launcher
libraries that arrived in `0c015bd` are not part of this 0/0.

**tests — 632 → 667 (+35).** The delta is entirely three suites, from the two runs'
[`test-cases.md`](test-cases.md) inventories: `test_launcher.lua` is new at 21 cases,
`test_slash.lua` went 46 → 59 (+13, the `/wg enable` / `/wg disable` reserved pair in `745e15e` and
the disabled-addon verb gate in `631d222`), and `test_lifecycle.lua` 44 → 45 (+1). No suite lost a
case.

**perf — skip → pass, 0 → 8 scenarios.** The previous run recorded
`"skipReason": "no tests/perf.lua — this addon ships no offline scenarios"`, which was
`automated-tests-§3`'s first sanctioned reason: the record was silent about runtime cost. Commit
`1e11d4c` ended that. The harness is deliberately outside the green gate and asserts only
deterministic quantities — API calls on the addon's own frames, and bytes allocated per iteration,
each isolated by a full collect either side — with timings printed for orientation only. It measures
in two passes: pass one counts API calls with a vararg counting shim installed, pass two re-runs the
identical work with the real methods back in place for the honest byte figure, because the shim's own
vararg call allocates (it inflated `combatGateFlipping` from 492 to 1080 bytes/iter). This run's
figures, from [`perf.json`](perf.json):

| Scenario | api/iter | bytes/iter | What it pins |
|---|---|---|---|
| `cooldownTick` | 2.0 | 240.4 | The one repeating timer in the addon, driven through the addon's own queued closure — the exact claim the `performance-§12` deviation row rests on |
| `formatDurationLong` | 0.0 | 34.5 | The `h > 0` branch of the formatter the tick calls every second — the branch a long teleport cooldown takes |
| `formatDurationShort` | 0.0 | 0.8 | The same formatter's sub-minute branch |
| `combatGateSteady` | 0.0 | 0.0 | A combat edge that changes nothing: the addon's whole combat-path cost in the common case. The one **hard** ceiling (24 bytes) — it must allocate nothing |
| `combatGateFlipping` | 7.0 | 1064.1 | The worst case, `visibility = inCombat`, where each edge genuinely flips the popup. Asserted `<= 8` API calls/edge: the property is that it is *constant*, so the cost does not accumulate across a pull |
| `showFrameRepeat` | 18.0 | 1872.5 | A group capture arriving — repopulate and show, the addon's busiest single act, once per group join |
| `applyScale` | 1.0 | 0.0 | A slider drag: full scale reapply, allocating nothing |
| `applyAlpha` | 1.0 | 0.0 | A slider drag: full alpha reapply, allocating nothing |

Every byte ceiling is the measured figure + 24 bytes, which is smaller than the cheapest regression
it exists to catch (one extra table costs 64 bytes under this interpreter). `"failures": []` — no
ceiling was tripped. These are baseline readings: there is no previous perf run to diff against.

**complexity — grew, did not densify.** Total NLOC 9129 → 9903 (+774) and functions 1199 → 1298
(+99), which is the launcher, the perf harness and three new suites arriving. The averages are the
signal and they did not degrade: avg NLOC/function 6.8 → **6.7**, avg tokens/function 49.6 → **49.1**,
avg CCN 1.8 → 1.8 unchanged, max CCN 15 → 15 unchanged, warned functions 0 → 0. Band files 2 → 2,
over-cap files 0 → 0. A total that rose because the addon grew is not a complexity signal; an average
that rose because it got denser would be, and neither average rose.

**Non-suite context.** Commit `d64656b`, earlier the same day, corrected eight stale `file:line`
source citations, and `dbfa65f` added the check that keeps them honest — documentation work with no
suite figure attached to it, which is why nothing in the table moved on its account.

## Complexity watch list

### Functions `lizard` warned on

None. 0 functions above CCN 15 (`manifest.json` → `suites.complexity.warnings`), and
[`complexity.txt`](complexity.txt)'s footer reads `No thresholds exceeded`. The densest function in
the tree sits exactly *at* 15, not above it: `WhatGroup@865-933@./core/WhatGroup.lua` (the
`LFG_LIST_APPLICATION_STATUS_UPDATED` neighbourhood, 37 NLOC). Worth naming because it is the one
that would warn first — and, read with `lizard`'s habit of scoring every `and`/`or` short-circuit as
a decision, it is status dispatch and guarding rather than tangled control flow.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Frame.lua` | 1063 | **Accepted, carried and re-stated** — see [`../RESULTS.md`](../RESULTS.md) |
| 1000–1500 (on notice) | `tests/test_frame.lua` | 1421 | **Accepted, unchanged from the previous run** — see [`../RESULTS.md`](../RESULTS.md) |

`modules/Frame.lua` moved 1035 → 1063 (+28) and stays well inside its 1250 re-check trigger; its
worst function is still CCN 13 (`WhatGroup@967-1036`) and `buildFrame` is still the long flat builder
it was, now at lines 566–830 with CCN 2 over 265 lines. `tests/test_frame.lua` did not move at all
this run: 1421 both times. Neither has been carried as *Accepted* across three consecutive **release**
runs — only one release run (`bed07dd`, Release 1.4.0) has carried `tests/test_frame.lua`, and
`modules/Frame.lua` first appeared at the previous run — so `automated-tests-§4`'s shelf life has not
expired for either. `tests/test_frame.lua` is, however, on its stated last acceptance: the next band
boundary is the 1500 cap.

## Actions

1. **None gating.** No suite failed, nothing newly crossed, and no disposition is owed.
2. **Standing, not new: `tests/test_frame.lua` at 1421 / 1500.** The previous run declared that its
   last acceptance; it did not grow this run, so nothing is owed yet. If it moves again, the answer
   recorded there is a split along module seams (visibility, teleport, test mode), not another
   carry-forward. Owner: the next change that adds a case to that file.
3. **Standing, not new: `perf` now has a baseline but no trend.** These eight figures can only be
   compared from the *next* run onward. The ceilings in `tests/perf.lua` are the enforcement in the
   meantime.
