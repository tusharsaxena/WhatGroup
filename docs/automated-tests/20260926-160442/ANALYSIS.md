# Analysis — 20260926-160442

- **Addon:** WhatGroup 1.4.0
- **Verdict:** green
- **Commit:** 54ef2f130d72d25c984f8030c41a2fe612dafdf5 (master), clean
- **Previous run:** [`20260924-111851`](../20260924-111851/)

## Headline

All four suites pass on a clean `master`: lint 0/0 over 54 files, 823 headless cases with nothing
skipped, 8 perf scenarios with no ceiling tripped, and 0 functions above CCN 15. The run follows the
diagnostics rollout (DR-WG-01..07, LibKa0s v1.60.0) and the nav-rail re-vendor (NR-WG-01, LibKa0s
v1.61.0), 21 commits after the previous record. Max CCN rose 13 → 15: the new read-only
`NS.FrameSnapshot` in `modules/Frame.lua` sits **at** the warning threshold, not over it. Nothing
gates; the two band dispositions whose figures went stale are updated in
[`../RESULTS.md`](../RESULTS.md).

## Suites

| Suite | Status | Result | Artifact | Moved since 20260924-111851 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 54 files | [`lint.txt`](lint.txt) | 50 → 54 files; still 0/0 |
| tests | pass | 823 passed, 0 skipped, 0 failed, 823 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 775 → 823 (+48) |
| perf | pass | 8 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 8 → 8; api/iter and bytes/iter identical; ms/iter higher on all 8 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings, unchanged; max CCN 13 → 15 |

**Complexity in full**, from `manifest.json`'s `suites.complexity` and the footer in
[`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 12141 |
| Functions | 1589 |
| Avg NLOC / function | 6.7 |
| Avg CCN | 1.8 |
| Max CCN | 15 |
| Avg tokens / function | 50.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |

Every suite passed cleanly and none was skipped. No case reported a `Kit.skip`: passed and total
are both 823 (`manifest.json` → `suites.tests`), so the row claims no coverage that was not
exercised. `perf` is a `pass` with `"failures": []` in [`perf.json`](perf.json); the
`performance-§12` register row does not claim the exemption, so the suite ran.

## What moved

**lint: 50 → 54 files, still 0/0.** The four new files, from a diff of the two runs' `lint.txt`
file lists: `modules/Diagnostics.lua`, `tests/mock_menu.lua`, `tests/test_diagnostics.lua` and
`tests/test_snapshot.lua`. `.luacheckrc`'s six exclusions are unchanged (see
[`../RESULTS.md`](../RESULTS.md) → `## Lint`).

**tests: 775 → 823 (+48).** From the two runs' `test-cases.md` `## Totals` tables: three suites are
new — `test_diagnostics` (18), `test_snapshot` (9) and `test_diagnostics_contract` (7); `test_launcher`
grew 24 → 36 (the left-settings / right-menu click model and tooltip states), `test_slash` 59 → 60 and
`test_doc_structure` 8 → 9. No suite lost a case. `test_frame` stayed at 90.

**perf: 8 scenarios, no ceiling tripped.** API calls and bytes per iteration are identical to the
previous run on all eight scenarios (`cooldownTick` still 2 API / 240.4 bytes per tick). Every
`ms/iter` figure is higher (for example `showFrameRepeat` 0.01243 → 0.02691, `combatGateFlipping`
0.00603 → 0.00930). With the allocation and API counts unchanged, this reads as host load rather
than a code change; [`perf.txt`](perf.txt) itself says timings are for orientation only.

**complexity: grew in size, flat in density.** Total NLOC 11285 → 12141 (+856), functions
1471 → 1589 (+118). Avg NLOC per function held at 6.7 and avg CCN at 1.8; avg tokens per function
49.7 → 50.0. Warnings stayed at 0. Max CCN rose 13 → 15 because of one new function,
`NS.FrameSnapshot@1168-1187@./modules/Frame.lua` (NLOC 20, CCN 15), added by `c0ce81c` (DR-WG-02) for
the diagnostics report. It is a single table constructor with one loop; the score is almost
entirely `(x and y) and true or false` / `x ~= nil` boolean coercion across its fields —
dense guarding, not tangled control flow. It is at the threshold (the tool warns on CCN > 15), so it
is not on the functions table, but one more coerced field would put it there.

**Band files: 3 → 3, none over the cap.** `core/WhatGroup.lua` 1143 → 1161, `modules/Frame.lua`
1173 → 1206, `tests/test_frame.lua` 1422 → 1422. All three remain below their shared 1450 re-check
line.

**Record note.** Of the 14 bundles in `docs/automated-tests/`, two carry no `ANALYSIS.md`
(`20260807-110421`, `20260825-103505`); per `automated-tests-§5` they are not backfilled.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None: 0 functions above CCN 15 (`manifest.json` → `suites.complexity.warnings`), and
[`complexity.txt`](complexity.txt) reads `No thresholds exceeded`.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/WhatGroup.lua` | 1161 | **Accepted, with a trigger: re-check at 1450** (carried; figures refreshed). See [`../RESULTS.md`](../RESULTS.md) |
| 1000–1500 (on notice) | `modules/Frame.lua` | 1206 | **Accepted, with a trigger: re-check at 1450** (re-stated; worst function now CCN 15). See [`../RESULTS.md`](../RESULTS.md) |
| 1000–1500 (on notice) | `tests/test_frame.lua` | 1422 | **Accepted, with a trigger: re-check at 1450, then split** (ruling stands, unchanged). See [`../RESULTS.md`](../RESULTS.md) |

No entry is new; the runner carried all three dispositions forward. Two carried cells quoted figures
this run no longer supports (`modules/Frame.lua`'s "worst function CCN 13" and both files' line
counts), so their Disposition cells in `RESULTS.md` were brought up to this run's figures without
changing the ruling. Only one release run (`20260910-234511`, 1.4.0) exists in the record, so no
entry has been *Accepted* across three consecutive release runs and `automated-tests-§4`'s shelf
life has not expired for any of them.

## Actions

1. **None gating.** No suite failed and no function warned.
2. **New here: `NS.FrameSnapshot` at CCN 15** (`modules/Frame.lua:1168`). At the threshold, not
   over. If a field is added to the snapshot, fold the `and ... or false` coercions into a small
   helper first so the next field does not produce the addon's first warning since
   `20260807-114405`. Untracked: no issue or review finding names it.
3. **Standing: the 1450 re-check line on three files** (`WHATGROUP-R-14`). Unchanged from the
   previous run.
4. **Not a release.** No `--release` stamp; a release run through `/wow-addon:bump-version` is the
   owner's call.
