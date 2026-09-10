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

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260910-234511`](20260910-234511/) | 1.3.0 → 1.4.0 | 0/0 | 41 | 568/0/568 | skip | 8065 | 1063 | 6.7 | 1.8 | 15 | 0 | **green** |
| [`20260908-181437`](20260908-181437/) | 1.3.0 | 0/0 | 40 | 554/0/554 | skip | 7702 | 1044 | 6.5 | 1.8 | 15 | 0 | **green** |
| [`20260825-103505`](20260825-103505/) | 1.3.0 | 0/0 | 16 | 485/485 | skip | 6377 | 906 | 6.4 | 1.7 | 15 | 0 | **green** |
| [`20260807-121935`](20260807-121935/) | 1.3.0 | 0/0 | 14 | 462/462 | skip | 6114 | 870 | 6.4 | 1.7 | 15 | 0 | **green** |
| [`20260807-114405`](20260807-114405/) | 1.3.0 | 0/0 | 14 | 462/462 | skip | 6095 | 866 | 6.4 | 1.7 | 20 | 1 | **green** |
| [`20260807-110421`](20260807-110421/) | 1.3.0 | 0/0 | 14 | 462/462 | skip | 6095 | 866 | 6.4 | 1.7 | 20 | 1 | **green** |
| [`20260807-022625`](20260807-022625/) | 1.3.0 | 0/0 | 14 | 462/462 | skip | 6095 | 866 | 6.4 | 1.7 | 20 | 1 | **green** |
| [`20260804-233335`](20260804-233335/) | 1.3.0 | 0/0 | 14 | 422/422 | skip | 5573 | 808 | 6.3 | 1.7 | 13 | 0 | **green** |
| [`20260804-215056`](20260804-215056/) | 1.3.0 | 0/0 | 14 | 422/422 | skip | 5573 | 808 | 6.3 | 1.7 | 0 | 0 | **green** |
| [`20260804-182231`](20260804-182231/) | 1.3.0 | 0/0 | 14 | 415/415 | skip | 5417 | 787 | 6.2 | 1.7 | 22 | 3 | **green** |

## Test suite

**568 cases** — 568 passed, 0 failed, 0 skipped. The generated inventory
[`20260910-234511/test-cases.md`](20260910-234511/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **554 → 568** since the previous run.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 41 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` sets `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }`, so those paths
are not in it. A `0/0` that never moves is partly a statement about what was never looked at, which
is why the exclusion is restated on every run.

## Perf

**This repo ships no `tests/perf.lua`, so `perf` is a permanent `skip`** — the first of
`automated-tests-§3`'s two sanctioned reasons, *nothing to run*, rather than a ratified
`performance-§12` no-combat-path exemption. The record is therefore **silent about runtime
cost**: nothing in this file says this addon is fast or cheap, only that the question was
never asked.

## Complexity watch list

Current as of [`20260910-234511`](20260910-234511/) — **this run's measurement, not its diff.** Max CCN **15** across 1063
functions, **0** of them warned on; 1 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_frame.lua` | 1263 | **Accepted.** The first file this repository has ever had in the band, and the first entry this table has ever carried. 627 lines at the previous run's commit; it crossed at 987 with `M2-21`'s combat-start re-ask and reached 1063 with `M2-28`. It is the suite for `modules/Frame.lua`, which is 770 lines, so it is now 293 lines longer than the module it covers — that ratio, rather than the absolute count, is the thing to watch. A flat list of independent cases; length here is case count, not tangle. Re-check at 1250, or when `modules/Frame.lua` itself is peeled, whichever comes first. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

