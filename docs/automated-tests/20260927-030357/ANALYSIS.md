# Analysis — 20260927-030357

- **Addon:** WhatGroup 1.4.0 → 1.5.0 (release run; `manifest.json` stamps `"release": "1.5.0"` on a tree still at `addonVersion` 1.4.0, because the gate runs before any version string is edited)
- **Verdict:** green
- **Commit:** 30c0b53aebd5172d777627d877ea2cfebcc70b32 (master), clean
- **Previous run:** [`20260926-193120`](../20260926-193120/)

## Headline

The release run for **1.5.0**, and the release gate passed on all five conditions: lint 0/0 over 54
files, 824 headless cases with none failed or skipped, 8 perf scenarios with no ceiling tripped,
complexity ran, and 0 functions above CCN 15 (max 13). Every figure except perf timing is identical to
the previous run: the six commits between them (`a6e144b..30c0b53`) touched no `.lua`, `.toc` or
`.xml` file, only the README and the docs. Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260926-193120 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 54 files | [`lint.txt`](lint.txt) | unchanged: same 54 files, 0/0 |
| tests | pass | 824 passed, 0 skipped, 0 failed, 824 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged: 824, inventory identical |
| perf | pass | 8 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 8 → 8; api/iter and bytes/iter identical; ms/iter drifted with host load |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | unchanged in every footer field |

**Complexity in full**, from `manifest.json`'s `suites.complexity` and the footer in
[`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 12164 |
| Functions | 1591 |
| Avg NLOC / function | 6.7 |
| Avg CCN | 1.8 |
| Max CCN | 13 |
| Avg tokens / function | 50.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |

Every suite passed cleanly and none was skipped. No case reported a `Kit.skip`: passed and total
are both 824 (`manifest.json` → `suites.tests`). `perf` ran, since the addon ships `tests/perf.lua`,
and is a `pass` with `"failures": []` in [`perf.json`](perf.json), so the perf gate is measured rather
than satisfied by the no-scenarios exception.

### Release gate

Evaluated from `manifest.json` by `/wow-addon:bump-version` (`automated-tests-§3`):

| Gate | Result | Detail |
|---|---|---|
| Lint | PASS | `suites.lint.status` pass, 0 warnings / 0 errors in 54 files |
| Tests | PASS | `suites.tests.status` pass, failed 0 of 824 |
| Perf | PASS | `suites.perf.status` pass, 8 scenarios measured |
| Complexity | PASS | `suites.complexity.status` pass, lizard 1.24.0 ran |
| CCN <= 15 | PASS | `suites.complexity.warnings` 0, max CCN 13 |

## What moved

**lint: 54 → 54 files, still 0/0.** The two runs' `lint.txt` file lists are identical.

**tests: 824 → 824.** The two runs' `test-cases.md` files are identical once line endings are set
aside, so no case was added, removed or renamed.

**perf: 8 scenarios, no ceiling tripped.** API calls and bytes per iteration are identical to the
previous run on all eight scenarios (`cooldownTick` still 2 API / 240.4 bytes per tick,
`showFrameRepeat` still 18 API / 1744.1 bytes). `ms/iter` rose on five scenarios, fell on two and held on `applyScale` (for
example `showFrameRepeat` 0.01016 → 0.01141, `combatGateFlipping` 0.00475 → 0.00560,
`formatDurationShort` 0.00040 → 0.00037). No benchmarked code changed between the runs, so this is
host load; [`perf.txt`](perf.txt) says timings are for orientation only.

**complexity: no change.** Total NLOC 12164, 1591 functions, avg NLOC 6.7, avg CCN 1.8, avg tokens
50.0, 0 warnings, max CCN 13, all as at `20260926-193120`. The worst functions are still three at CCN
13: `WhatGroup@1035-1103@./core/WhatGroup.lua`, `WhatGroup@1038-1091@./modules/Frame.lua` and
`identity@62-71@./modules/Diagnostics.lua`.

**Band files: 3 → 3, none over the cap.** `core/WhatGroup.lua` 1161, `modules/Frame.lua` 1211 and
`tests/test_frame.lua` 1422, each unchanged. Nothing entered or left the band.

## Complexity watch list

**Functions warned on (CCN > 15):**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. A passing release gate makes this table empty by construction.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/WhatGroup.lua` | 1161 | Accepted, with a trigger. Unchanged; first release run to carry it (1 of 3); re-check at 1450 (`WHATGROUP-R-14`) |
| 1000–1500 (on notice) | `modules/Frame.lua` | 1211 | Accepted, with a trigger. Unchanged; first release run to carry it (1 of 3); re-check at 1450 (`WHATGROUP-R-14`) |
| 1000–1500 (on notice) | `tests/test_frame.lua` | 1422 | Accepted, with a trigger. Unchanged; second release run to carry it (2 of 3, after 1.4.0); re-check at 1450 (`WHATGROUP-R-14`) |

The full dispositions are in [`../RESULTS.md`](../RESULTS.md). No entry newly crossed a threshold.
`tests/test_frame.lua` has one release left on `automated-tests-§4`'s three-release shelf life: if it
is still carried as Accepted at the next release, it is owed a split or a tracked deviation ID.

## Actions

None. One to watch: `tests/test_frame.lua` reaches its third Accepted release run at the next
release (see above).
