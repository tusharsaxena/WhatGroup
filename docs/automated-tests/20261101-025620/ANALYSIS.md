# Analysis — 20261101-025620

- **Addon:** WhatGroup 1.6.0
- **Verdict:** green
- **Commit:** 1540bd8990f2cfcf5024ee0d5c37101e5befab57 (feat/2026-10-31-findings-remediation), clean
- **Previous run:** [`20261101-001230`](../20261101-001230/)

## Headline

All four suites pass on the re-cut LibKa0s v1.84.0, and this is the final run before merge. Lint, the
test list and results, complexity and the band files match the previous run exactly, and every perf
scenario holds its api/iter and bytes/iter. Nothing here needs acting on; smoke check SKIN-31 is the
owner's to run in game.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-001230 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 76 files | [`lint.txt`](lint.txt) | no |
| tests | pass | 1046 passed, 1 skipped, 0 failed, 1047 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | no; same case list, same skip |
| perf | pass | 8 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | api/iter and bytes/iter hold in all 8; only ms/iter moved |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | no; totals, averages and max all hold |

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

This run measures `1540bd8`, three commits past the previous run's `dbf4b39`: that run's own record
(`a8977ac`), the re-vendor of the re-cut v1.84.0 (`03cfdc7`), and smoke check SKIN-31 (`1540bd8`). The
re-vendor rewrote six `libs/LibKa0s/` files. The only authored source change is a comment in
`tests/loader.lua` updating the skin major's key.

**lint: did not move.** 0/0 over 76 files; [`lint.txt`](lint.txt) matches the previous run's.

**tests: did not move.** 1046 passed, 1 skipped, 0 failed, 1047 total, and both
[`tests.txt`](tests.txt) and [`test-cases.md`](test-cases.md) are identical to the previous run's.
`RESULTS.md` now reports the count flat at 1047 across the last 3 runs. Here that is expected: those
runs added no WhatGroup behavior to test, only the library. The one-picker change this addon received
has no case in this repo's suite; SKIN-31 in `docs/smoke-tests.md` covers it in game, and that result
is not recorded yet.

**perf: api/iter and bytes/iter did not move in any of the 8 scenarios.** Only `ms/iter` moved, in both
directions: the largest rises were `formatDurationShort` 0.00040 → 0.00070 and `cooldownTick`
0.00187 → 0.00265, and the largest fall was `combatGateFlipping` 0.00761 → 0.00560. None of these
scenarios' api or allocation counts changed, and [`perf.txt`](perf.txt) says timings are for
orientation only.

**complexity: did not move.** 16190 NLOC, 2171 functions, avg NLOC 7.0, avg CCN 1.9, max CCN 15, avg
tokens 54.2, warnings 0, blind and crashed files 0. The re-vendored `libs/` are outside the measured
tree, and the one authored edit was a comment.

**Band files: 3 → 3, none over the cap, none newly crossed.** `core/WhatGroup.lua` holds at 1233,
`modules/Frame.lua` at 1256 and `tests/test_libka0s.lua` at 1070.

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
| 1000–1500 (on notice) | `tests/test_libka0s.lua` | 1070 | Accepted, carried. Case count, not tangle; 1 of 3 release runs; re-check at 1300 |

All three dispositions carried forward with no blank cell, so no new ruling was owed. This is not a
release run, so no shelf-life count moved. The full dispositions are in
[`../RESULTS.md`](../RESULTS.md).

## Actions

None.
