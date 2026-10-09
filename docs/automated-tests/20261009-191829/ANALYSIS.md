# Analysis — 20261009-191829

- **Addon:** WhatGroup 1.5.0 → 1.6.0 (release run; `manifest.json` stamps `"release": "1.6.0"` on a tree still at `addonVersion` 1.5.0, because the gate runs before any version string is edited)
- **Verdict:** green
- **Commit:** 22838c3953e18a64f2389b71d26ad2db1ef689af (master), clean
- **Previous run:** [`20260927-031637`](../20260927-031637/)

## Headline

The release run for **1.6.0**, and the release gate passed on all six conditions: lint 0/0 over 59
files, 933 of 934 headless cases passed with none failed and one kit case skipped, 8 perf scenarios
with no ceiling tripped, complexity ran sighted (`blindFiles` 0), and 0 functions above CCN 15. It
is the first sighted run in this record (the kit reached revision 35 after the 1.5.0 release), so
the complexity figures are not a clean diff against the previous row. Two production files in the
1000–1500 band reach their second Accepted release run and are owed a split or a deviation ID at the
next release.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260927-031637 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 59 files | [`lint.txt`](lint.txt) | 56 → 59 files, still 0/0 |
| tests | pass | 933 passed, 1 skipped, 0 failed, 934 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 824 → 934; first skip |
| perf | pass | 8 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 8 → 8; `showFrameRepeat` api/iter 18.0 → 19.0, `combatGateFlipping` bytes/iter 1000.0 → 960.0 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | first sighted run; max CCN 13 → 15 (newly measured) |

**Complexity in full**, from `manifest.json`'s `suites.complexity` and the footer in
[`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 13733 |
| Functions | 1829 |
| Avg NLOC / function | 7.1 |
| Avg CCN | 1.9 |
| Max CCN | 15 |
| Avg tokens / function | 54.5 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

**tests** is a pass with one skip, and the skip is not coverage lost. The skipped case is the kit's
diagnostics-contract arm for an addon that opts out of turning logging on
([`tests.txt`](tests.txt), line 923). WhatGroup keeps the default, so its report does turn logging on
and the case above it holds that. The skip is counted in the total and not in `passed`.

**complexity** is sighted for the first time. Every earlier row was written by a kit older than
revision 35, whose `lizard` pass dropped the functions it was blind in; this run's `blindFiles` is 0,
so every function was measured. The one function at the CCN 15 ceiling, `encode@336-366` in
`tests/perf.lua`, is absent from the previous run's [`complexity.txt`](../20260927-031637/complexity.txt)
although `tests/perf.lua` did not change between the runs: it is **newly measured**, not a regression.

### Release gate

Evaluated from `manifest.json` by `/dev-copilot:bump-version` (`automated-tests-§3`):

| Gate | Result | Detail |
|---|---|---|
| Lint | PASS | `suites.lint.status` pass, 0 warnings / 0 errors in 59 files |
| Tests | PASS | `suites.tests.status` pass, failed 0 of 934 (933 passed, 1 skipped) |
| Perf | PASS | `suites.perf.status` pass, 8 scenarios measured |
| Complexity | PASS | `suites.complexity.status` pass, lizard 1.24.0 ran |
| CCN <= 15 | PASS | `suites.complexity.warnings` 0, max CCN 15 |
| Sighted | PASS | `suites.complexity.blindFiles` 0 |

## What moved

**lint: 56 → 59 files, still 0/0.** The three new files are `settings/Profiles.lua`,
`tests/test_library_lines.lua` and `tests/test_profiles.lua` ([`lint.txt`](lint.txt)).

**tests: 824 → 934 (+110).** The new cases come with the release's features and fixes: the Profiles
page and `/wg profile`, the signed-up role, the library's debug lines, the secret teleport cooldown
and the test-preview fixes. [`test-cases.md`](test-cases.md) is the authority on which cases exist.

**perf: 8 scenarios, no ceiling tripped.** Two scenarios moved in a counted figure, and both are
explained in `docs/performance.md`'s re-measure of 2026-10-07 (WG-05). `showFrameRepeat` api/iter
18.0 → 19.0 was bisected to the popup's Role row (GI-WG-01), which adds one `SetText` to every
populate; its bytes/iter is 1744.1 → 1744.2. `combatGateFlipping` bytes/iter 1000.0 → 960.0 was
recorded as a re-measure and not bisected. The other six scenarios hold api/iter and bytes/iter.
`ms/iter` moved both ways (for example `showFrameRepeat` 0.01039 → 0.00973, `cooldownTick` 0.00171
→ 0.00182); [`perf.txt`](perf.txt) says timings are for orientation only.

**complexity: 12183 → 13733 NLOC (+1550), 1591 → 1829 functions (+238).** Part of each rise is
growth (62 commits since the 1.5.0 tag) and part is functions the unsighted runs never counted;
this record cannot separate the two. The averages rose a little: avg NLOC 6.7 → 7.1, avg CCN 1.8 →
1.9, avg tokens 50.0 → 54.5. Max CCN 13 → 15 is the newly measured `encode` above. Production code
tops out at CCN 13: `WhatGroup.LFG_LIST_APPLICATION_STATUS_UPDATED@1199-1267` and
`WhatGroup.ShowNotification@884-920` in `core/WhatGroup.lua`, and `S.SetMany@170-185` in
`settings/SchemaSetup.lua`.

**Band files: 3 → 3, none over the cap, one newly crossed.** `core/WhatGroup.lua` 1161 → 1340 and
`modules/Frame.lua` 1211 → 1384. `tests/test_libka0s.lua` (978 at the 1.5.0 release) **newly
crossed** at 1037. `tests/test_frame.lua` left the band at the split recorded in
`20260927-031637`.

## Complexity watch list

**Functions warned on (CCN > 15):**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. A passing release gate makes this table empty by construction.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/WhatGroup.lua` | 1340 | Accepted, with a trigger. +179 since 1.5.0 (role capture, debug-coverage fill, profile callbacks, test-preview fix); 2 of 3 release runs; 110 under the 1450 trigger (`WHATGROUP-R-14`) |
| 1000–1500 (on notice) | `modules/Frame.lua` | 1384 | Accepted, with a trigger. +173 since 1.5.0 (debug-coverage fill, one-shot preview, secret-cooldown state); 2 of 3 release runs; 66 under the 1450 trigger (`WHATGROUP-R-14`) |
| 1000–1500 (on notice) | `tests/test_libka0s.lua` | 1037 | Accepted, newly crossed. Case count, not tangle (69 functions, avg CCN 2.0); 1 of 3 release runs; re-check at 1300 |

The full dispositions are in [`../RESULTS.md`](../RESULTS.md).

## Actions

1. `core/WhatGroup.lua` and `modules/Frame.lua` reach their third Accepted release run at the next
   release. Before then each needs its fix (the capture pipeline out of the shell; `buildFrame`
   peeled out of `modules/Frame.lua`) or a tracked deviation ID. New here: neither has an issue yet.
2. `tests/test_libka0s.lua` newly entered the band. No action until it nears 1300 or the next
   adoption adds cases; then split it by LibKa0s module.
