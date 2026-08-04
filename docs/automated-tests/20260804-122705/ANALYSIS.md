# Analysis — 20260804-122705

- **Addon:** WhatGroup 1.3.0
- **Verdict:** green
- **Commit:** f883274efb2b (main), dirty
- **Previous run:** none — this is the first recorded run

## Headline

The first automated-test record for this addon, produced while adopting `automated-tests`
(standard v2.19.0). Both gating suites are clean: `luacheck` reports 0 warnings / 0 errors across
14 files and the headless harness passes 415 of 415 cases. The offline perf runner is absent (see below). Every figure below is a **baseline** —
there is no previous run to diff against, so nothing here is a regression and nothing is an
improvement.

## Suites

| Suite | Status | Result | Artifact | Moved since previous run |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 14 files | [`lint.txt`](lint.txt) | — first run |
| tests | pass | 415 passed, 0 failed, 415 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | — first run |
| perf | skip | — | — (not run) | — first run |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | — first run |

### Complexity in full

Every field of `lizard`'s footer, plus the two derived file counts. The **averages** are what make
this run comparable to the next one across a change in size: a total that rises because the addon
grew is a different fact from an average that rises because it got denser, and only the second is a
complexity signal.

| Metric | Value |
|---|---|
| Total NLOC | 5417 |
| Functions | 787 |
| Avg NLOC / function | 6.2 |
| Avg CCN | 1.7 |
| Max CCN | 22 |
| Avg tokens / function | 45.5 |
| Warnings (CCN > 15) | 3 |
| Warning rate — `Fun Rt` / `nloc Rt` | 0.0 / 0.03 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |

`tests/perf.lua` is absent — this addon ships no offline scenarios, so nothing was measured there. That is a **skip, not a pass**: it is recorded as one in `manifest.json`, and it means this run says nothing about the addon's runtime cost.

## What moved

**First run — nothing to diff against; every figure above is a baseline reading.** The next run is
the first one that can say something moved, and this record is what it will be read against.

## Complexity watch list

| `WhatGroup:CaptureGroupInfo` | 22 | `core/WhatGroup.lua` | **Accepted.** Twenty-odd `or` fallbacks in one flat table constructor — breadth, not depth. |
| `WhatGroup:ShowNotification` | 22 | `core/WhatGroup.lua` | **Accepted.** Nine independent toggle guards mapping 1:1 onto the Notifications panel. |
| `Helpers.BuildMainContent` | 17 | `settings/Panel.lua` | **Peel next** — the lowest-value of the three; the logo and description blocks lift out cleanly. |

**Files in the 1000–1500 band:** None.

## Actions

None arising from this run. The dispositions above are carried forward from the complexity reports
written against the same measurements earlier today; each was recorded with its evidence at the
time, and none is new here.
