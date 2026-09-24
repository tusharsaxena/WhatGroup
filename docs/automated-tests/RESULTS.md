# Automated test results

<!-- Regenerated whole by tests/_kit/run-automated-tests.sh on every run. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->
<!-- Everything here is generated EXCEPT the watch list's Disposition column. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate the run and gate the commit** (`testing-§4`).
**`perf` and `complexity` never fail a run and never block a commit** — they are recorded,
read and compared, not thresholded (`performance-§9`, `performance-§10`).

**The tag is gated on all four suites at `pass`, plus zero functions above CCN 15**
(`automated-tests-§3`, *The release gate*), evaluated by `/wow-addon:bump-version` from the
`manifest.json` the release run writes — not by this script, whose exit code is unchanged.

A `skip` is a suite that did not run at all. It is never a pass, and at the release gate it is
**NOT EVALUATED** rather than passed: install the tool and re-run. A `—` is a suite that was
not selected, which is a different fact again.

The **Tests** cell reads `passed/skipped/total`.

**Commit** is the short sha the run measured and **Tree** is whether that tree was clean at the
time. Both are read from git by the runner; neither is ever typed. A **dirty** row measured bytes
that no sha can bring back, so it is kept as an experiment honestly labeled rather than dropped —
and a release record is refused outright on a dirty tree, so no release row can be one.

A row reading `unknown` in both cells was recorded before the runner emitted them. That is what
the record holds about those runs — it is not `clean`, and it is not reconstructed from git
archaeology, for the same reason a skip is never a pass (`automated-tests-§4`).

| Run | Commit | Tree | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260924-111851`](20260924-111851/) | `011b39c` | clean | 1.4.0 | 0/0 | 50 | 775/0/775 | pass | 11285 | 1471 | 6.7 | 1.8 | 13 | 0 | **green** |
| [`20260916-184548`](20260916-184548/) | unknown | unknown | 1.4.0 | 0/0 | 45 | 667/0/667 | pass | 9903 | 1298 | 6.7 | 1.8 | 15 | 0 | **green** |
| [`20260916-094455`](20260916-094455/) | unknown | unknown | 1.4.0 | 0/0 | 42 | 632/0/632 | skip | 9129 | 1199 | 6.8 | 1.8 | 15 | 0 | **green** |
| [`20260910-234511`](20260910-234511/) | unknown | unknown | 1.3.0 → 1.4.0 | 0/0 | 41 | 568/0/568 | skip | 8065 | 1063 | 6.7 | 1.8 | 15 | 0 | **green** |
| [`20260908-181437`](20260908-181437/) | unknown | unknown | 1.3.0 | 0/0 | 40 | 554/0/554 | skip | 7702 | 1044 | 6.5 | 1.8 | 15 | 0 | **green** |
| [`20260825-103505`](20260825-103505/) | unknown | unknown | 1.3.0 | 0/0 | 16 | 485/485 | skip | 6377 | 906 | 6.4 | 1.7 | 15 | 0 | **green** |
| [`20260807-121935`](20260807-121935/) | unknown | unknown | 1.3.0 | 0/0 | 14 | 462/462 | skip | 6114 | 870 | 6.4 | 1.7 | 15 | 0 | **green** |
| [`20260807-114405`](20260807-114405/) | unknown | unknown | 1.3.0 | 0/0 | 14 | 462/462 | skip | 6095 | 866 | 6.4 | 1.7 | 20 | 1 | **green** |
| [`20260807-110421`](20260807-110421/) | unknown | unknown | 1.3.0 | 0/0 | 14 | 462/462 | skip | 6095 | 866 | 6.4 | 1.7 | 20 | 1 | **green** |
| [`20260807-022625`](20260807-022625/) | unknown | unknown | 1.3.0 | 0/0 | 14 | 462/462 | skip | 6095 | 866 | 6.4 | 1.7 | 20 | 1 | **green** |
| [`20260804-233335`](20260804-233335/) | unknown | unknown | 1.3.0 | 0/0 | 14 | 422/422 | skip | 5573 | 808 | 6.3 | 1.7 | 13 | 0 | **green** |
| [`20260804-215056`](20260804-215056/) | unknown | unknown | 1.3.0 | 0/0 | 14 | 422/422 | skip | 5573 | 808 | 6.3 | 1.7 | 0 | 0 | **green** |
| [`20260804-182231`](20260804-182231/) | unknown | unknown | 1.3.0 | 0/0 | 14 | 415/415 | skip | 5417 | 787 | 6.2 | 1.7 | 22 | 3 | **green** |

## Test suite

**775 cases** — 775 passed, 0 failed, 0 skipped. The generated inventory
[`20260924-111851/test-cases.md`](20260924-111851/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **667 → 775** since the previous run.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 50 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` excludes 6 path(s) from it — `libs/`, `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `_dev/`, `tests/_kit/` —
so nothing under them is in the count above. A `0/0` that never moves is partly a statement about
what was never looked at, which is why the exclusions are NAMED here on every run rather than left
to whoever thinks to open `.luacheckrc`.

## Perf

**8 scenarios** from `tests/perf.lua`; the measurements are in
[`20260924-111851/perf.json`](20260924-111851/perf.json).

| `scenario` | `iters` | `ms/iter` | `api/iter` | `bytes/iter` |
|---|---|---|---|---|
| `cooldownTick` | 2000 | 0.00194 | 2.0 | 240.4 |
| `formatDurationLong` | 2000 | 0.00048 | 0.0 | 34.5 |
| `formatDurationShort` | 2000 | 0.00040 | 0.0 | 0.8 |
| `combatGateSteady` | 2000 | 0.00019 | 0.0 | 0.0 |
| `combatGateFlipping` | 2000 | 0.00603 | 7.0 | 1000.0 |
| `showFrameRepeat` | 500 | 0.01243 | 18.0 | 1744.1 |
| `applyScale` | 500 | 0.00029 | 1.0 | 0.0 |
| `applyAlpha` | 500 | 0.00022 | 1.0 | 0.0 |

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20260924-111851`](20260924-111851/) — **this run's measurement, not its diff.** Max CCN **13** across 1471
functions, **0** of them warned on; 3 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/WhatGroup.lua` | 1143 | **Accepted, with a trigger — new to the band.** First recorded here at 1143 (it was 1099 when the 2026-09-23 review found it undispositioned, `WHATGROUP-R-14`; the stand-down, combat-end replay and status-handler work of that plan's WG-01..WG-29 added the rest). Length, not tangle: 45 functions at avg CCN 4.6, the worst the capture-status handler `WhatGroup@1017-1085` at CCN 13, none warned. No seam is split along today — the file is the AceAddon shell plus the capture pipeline it drives. **Re-check at 1450**, or on the first function in the file above CCN 15, whichever comes first; at 1450 the answer is a split (capture pipeline out of the shell), not another carry. |
| 1000–1500 (on notice) | `modules/Frame.lua` | 1173 | **Accepted, with a trigger — re-stated.** 1063 at `20260916-184548`, 1173 here (+110, the teleport-deferral, soft-hide alpha and combat-end replay work of the 2026-09-23 plan). Shape unchanged: small local functions plus one long flat builder (`buildFrame@618-882`, CCN 2 over 265 lines); the file's worst function is CCN 13 (`WhatGroup@1037-1090`), none warned. The previous 1250 trigger is superseded by the plan's single **re-check at 1450** (`WHATGROUP-R-14`), or when `buildFrame` is peeled out, whichever comes first. No release run has carried it, so `automated-tests-§4`'s three-release shelf life has not begun to run. |
| 1000–1500 (on notice) | `tests/test_frame.lua` | 1422 | **Accepted, with a trigger — the ruling stands.** 1421 at `20260916-184548`, 1422 here (+1); the 108 cases the plan added landed in other suites, `test_frame_secure.lua` (7 new) among them rather than here. Still a flat list of 100 independent cases (avg CCN 1.3), so the length is case count. **Re-check at 1450** (`WHATGROUP-R-14`): at that point the file splits along module seams (visibility, teleport, test mode) the way `test_frame_secure.lua` already split off the secure cases — the 1500 cap is not waited for. One release run (`bed07dd`, Release 1.4.0) has carried it, one of three against `automated-tests-§4`'s shelf life. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

