# Analysis — 20261031-202312

- **Addon:** WhatGroup 1.6.0
- **Verdict:** amber
- **Commit:** 5ac907560a301cba6f6f448cc656e289ba08f490 (feat/2026-10-31-font-pickers-skin-faces), clean
- **Previous run:** [`20261009-191829`](../20261009-191829/)

## Headline

Lint and tests pass, so the run and the commit are clear: 0/0 over 72 files, 1045 of 1046 cases passed
with none failed and one skip. The verdict is amber because **perf failed**: `showFrameRepeat`
allocated 3712.2 bytes/iter against its pinned 1769-byte ceiling. That does not block a commit or a
merge, but it **does block the next tag** until it is resolved. Complexity is clean, with 0 functions
above CCN 15 and none over the 1500 cap, but `modules/Frame.lua` at 1467 has passed its recorded 1450
re-check trigger.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261009-191829 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 72 files | [`lint.txt`](lint.txt) | 59 → 72 files, still 0/0 |
| tests | pass | 1045 passed, 1 skipped, 0 failed, 1046 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 934 → 1046; same one skip |
| perf | **fail** | 8 scenarios, 1 assertion failed | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | pass → fail; `showFrameRepeat` api/iter 19.0 → 25.0, bytes/iter 1744.2 → 3712.2 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 15 → 15; 0 warnings → 0 |

**Complexity in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 16125 |
| Functions | 2167 |
| Avg NLOC / function | 7.0 |
| Avg CCN | 1.9 |
| Max CCN | 15 |
| Avg tokens / function | 54.1 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**perf** is a regression, and it is the only suite not at a clean pass. [`perf.txt`](perf.txt) reports
one failed assertion: `showFrameRepeat allocated 3712.2 bytes/iter, over its 1769-byte ceiling`.
`tests/perf.lua` pins that ceiling rather than deriving it from the run, and its comment says a rise
is the finding, so this is the assertion doing its job and not a noisy limit. The scenario is a group
capture arriving: the popup repopulated and shown once per group join. Its `api/iter` also rose, 19.0
→ 25.0. Re-running `tests/perf.lua` over exported commits outside this bundle puts the rises at three
commits, in order: `27befff` (WG-ZS, the layers table), `116b5a8` (WG-02, painting the popup through
the skin facade, which is the largest step and the only one that moved `api/iter`) and `7914b8c` (the
LibKa0s v1.81.0 re-vendor). Those are deliberate feature changes, and whether the new cost is accepted
is the owner's call. Nothing in this run changed code or the ceiling.

**tests** is a pass with one skip, the same case as the previous run: the kit's diagnostics-contract
arm for an addon that opts out of turning logging on ([`tests.txt`](tests.txt), line 1035). WhatGroup
keeps the default, and the case above it holds that. The skip is counted in the total and not in
`passed`.

## What moved

**lint: 59 → 72 files, still 0/0.** The exclusions did not change.

**tests: 934 → 1046 (+112).** Passed 933 → 1045, skipped 1 → 1, failed 0 → 0.
[`test-cases.md`](test-cases.md) is the authority on which cases exist.

**perf: pass → fail, 8 scenarios.** `showFrameRepeat` is above. `combatGateFlipping` bytes/iter 960.0
→ 1056.0, under a ceiling derived from the same run, so that ceiling cannot trip; its api/iter holds
at 7.0. The other six scenarios hold api/iter and bytes/iter. `ms/iter` moved (for example
`showFrameRepeat` 0.00973 → 0.06611, `cooldownTick` 0.00182 → 0.00172); [`perf.txt`](perf.txt) says
timings are for orientation only.

**complexity: 13733 → 16125 NLOC (+2392), 1829 → 2167 functions (+338).** That is growth, not density:
avg NLOC 7.1 → 7.0, avg tokens 54.5 → 54.1, avg CCN holds at 1.9. Max CCN holds at 15 and warnings at
0. Production code still tops out at CCN 13.

**Band files: 3 → 3, none over the cap, none newly crossed.** `core/WhatGroup.lua` 1340 → 1367,
`modules/Frame.lua` 1384 → 1467, `tests/test_libka0s.lua` 1037 → 1066.

## Complexity watch list

**Functions warned on (CCN > 15):**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/WhatGroup.lua` | 1367 | Accepted, with a trigger. 83 under the 1450 trigger; 2 of 3 release runs |
| 1000–1500 (on notice) | `modules/Frame.lua` | 1467 | **Peel next.** Past the 1450 trigger and 33 under the cap; `buildFrame@771-1040` is the seam; 2 of 3 release runs |
| 1000–1500 (on notice) | `tests/test_libka0s.lua` | 1066 | Accepted. Case count, not tangle (69 functions, avg CCN 2.1); 1 of 3 release runs; re-check at 1300 |

The full dispositions are in [`../RESULTS.md`](../RESULTS.md).

## Actions

1. `tests/perf.lua` and `docs/performance.md`: decide on `showFrameRepeat`. Either cut the allocation
   in the skin paint path, or re-measure and raise the pin at `tests/perf.lua` line 294 with the
   reason, then update the row in `docs/performance.md`, which still records the old figures. Perf must
   pass at the tag. New here: no issue or deviation ID tracks it.
2. `modules/Frame.lua`: peel `buildFrame` out before the next feature adds to the file. Tracked as
   `WHATGROUP-R-14`.
3. `core/WhatGroup.lua` and `modules/Frame.lua` reach their third Accepted release run at the next
   release, carried from the previous run's action 1: each is owed its fix or a tracked deviation ID.
