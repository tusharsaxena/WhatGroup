# Analysis — 20260910-234511

- **Addon:** WhatGroup 1.3.0 → 1.4.0
- **Verdict:** green
- **Commit:** 53da4438d59a (master), clean
- **Previous run:** [`20260908-181437`](../20260908-181437/)

## Headline

The release run for **1.4.0**. Lint, tests and complexity are green with zero functions above CCN 15; **perf did not run** — no `tests/perf.lua` ships here. Fourteen new test cases and 363 more NLOC, which is the combat-safety work on Show/Close and the visibility gate. This is the smallest addon in the collection by NLOC and it stays that way.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260908-181437` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 41 files | [`lint.txt`](lint.txt) | see below |
| tests | pass | 568 passed, 0 skipped, 0 failed, 568 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | see below |
| perf | skip | not measured — no `tests/perf.lua` in this addon | — | not measured in either run |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | see below |

| Metric | Value |
|---|---|
| Total NLOC | 8065 |
| Functions | 1063 |
| Avg NLOC / function | 6.7 |
| Avg CCN | 1.8 |
| Max CCN | 15 |
| Avg tokens / function | 48.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |

**perf is the one suite that is not a clean pass, and it is a skip rather than a failure.** `manifest.json` records the reason verbatim: *"no tests/perf.lua — this addon ships no offline scenarios"*. Nothing ran, so nothing was measured — this is a pre-existing condition of the addon, not a regression in this run, and it is stated in the release notes as well as here. The release gate's perf condition is satisfied by the no-scenarios exception, which means this tag rests on three measured suites.

## What moved

- **lint** — 41 files, up one from 40. Still 0 warnings / 0 errors.
- **tests** — 568 passed, up 14 from 554 — proportionally the largest test growth of the nine. No skips, no failures.
- **perf** — skipped in both runs: no `tests/perf.lua`. Not measured.
- **complexity** — NLOC 7702 → 8065 (+363) over 1044 → 1063 functions (+19). Avg NLOC 6.5 → 6.7 and avg tokens 48.0 → 48.6, both tracking the 19 new functions. Avg CCN flat at 1.8, max CCN flat at 15, zero warnings. One band file in both runs, none over the cap.

## Complexity watch list

Both tables are maintained in [`RESULTS.md`](../RESULTS.md), which the runner regenerates whole on every run; the **Disposition** column there is the authored half and is current as of this run.

### Functions `lizard` warned on

None. Zero functions above CCN 15 is what the release gate required, and it is what this run measured — max CCN 15.

### Files by `layout-§1` band

1 file(s) in the 1000–1500 on-notice band, 0 over the 1500 cap. Each carries a disposition in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band). The band is not part of the release gate.

## Actions

None. `tests/test_frame.lua` is the repository's only band entry and carries a current disposition.
