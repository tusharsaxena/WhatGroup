# Analysis — 20261101-001230

- **Addon:** WhatGroup 1.6.0
- **Verdict:** green
- **Commit:** dbf4b39bb418513bd11c5bb739ff5a0f5cd883e5 (feat/2026-10-31-findings-remediation), clean
- **Previous run:** [`20261031-212737`](../20261031-212737/)

## Headline

All four suites pass on LibKa0s v1.84.0, and the re-vendor moved no gate. Lint stays 0/0 over 76 files,
tests stay 1046 of 1047 with none failed and the same one skip, every perf scenario holds its api/iter
and bytes/iter, and complexity stays at 0 warnings and max CCN 15. Nothing here needs acting on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261031-212737 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 76 files | [`lint.txt`](lint.txt) | no |
| tests | pass | 1046 passed, 1 skipped, 0 failed, 1047 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | no; same case list, same skip |
| perf | pass | 8 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | api/iter and bytes/iter hold in all 8; only ms/iter moved |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 16177 → 16190 NLOC, 2170 → 2171 functions; averages and max hold |

**Complexity in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 16190 |
| Functions | 2171 |
| Avg NLOC / function | 7.0 |
| Avg CCN | 1.9 |
| Max CCN | 15 |
| Avg tokens / function | 54.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests** is a pass with one skip, the same case as the previous run: the kit's diagnostics-contract
arm for an addon that opts out of turning logging on ([`tests.txt`](tests.txt), line 1036). WhatGroup
keeps the default. The skip is counted in the total and not in `passed`, and at the release gate it is
not evaluated rather than passed.

The other three suites are clean passes. The manifest names no skipped suite.

## What moved

This run measures `dbf4b39`, three commits past the previous run's `64f2db9`: that run's own record,
then `bf7818e` and `dbf4b39` (XX-RV), the LibKa0s v1.84.0 re-vendor. The re-vendor rewrote `libs/` and
`tests/_kit/`. Its authored changes are one stub in `settings/OptionsSetup.lua`, the new files in
`tests/loader.lua`, and the expected file lists in `tests/test_libka0s.lua`.

**lint: did not move.** 0/0 over 76 files; [`lint.txt`](lint.txt) matches the previous run's.

**tests: did not move.** 1046 passed, 1 skipped, 0 failed, 1047 total, and
[`test-cases.md`](test-cases.md) is identical to the previous run's. The count holding is expected: the
re-vendor took on no new library surface and added no case.

**perf: api/iter and bytes/iter did not move in any of the 8 scenarios.** Only `ms/iter` moved. The
largest moves were `combatGateFlipping` 0.00440 → 0.00761 and `showFrameRepeat` 0.01762 → 0.01040, in
opposite directions, and `combatGateSteady` and `applyAlpha` held. [`perf.txt`](perf.txt) says timings
are for orientation only.

**complexity: 16177 → 16190 NLOC (+13), 2170 → 2171 functions (+1).** Avg NLOC holds at 7.0, avg CCN
at 1.9, max CCN at 15, avg tokens at 54.2, warnings at 0. The one new function is the
`H.PositionBlock` stub in `settings/OptionsSetup.lua`. Blind and crashed files hold at 0.

**Band files: 3 → 3, none over the cap, none newly crossed.** `tests/test_libka0s.lua` 1066 → 1070 from
the longer file lists; it added no case. `core/WhatGroup.lua` holds at 1233 and `modules/Frame.lua` at
1256.

## Complexity watch list

**Functions warned on (CCN > 15):**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/WhatGroup.lua` | 1233 | Accepted, with a trigger, carried. Tracked under the `layout-§1`, `automated-tests-§4` row of `docs/ARCHITECTURE.md`'s `## Documented deviations` |
| 1000–1500 (on notice) | `modules/Frame.lua` | 1256 | Accepted, with a trigger, carried. Same deviation row; under its 1450 trigger |
| 1000–1500 (on notice) | `tests/test_libka0s.lua` | 1070 | Accepted, carried. Case count, not tangle; 1 of 3 release runs; re-check at 1300. Its split-on-adoption clause did not fire, because this re-vendor added no case |

All three dispositions carried forward with no blank cell, so no new ruling was owed. This is not a
release run, so no shelf-life count moved. The full dispositions are in
[`../RESULTS.md`](../RESULTS.md).

## Actions

None.
