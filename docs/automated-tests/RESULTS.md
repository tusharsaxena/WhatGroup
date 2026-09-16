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
| [`20260916-184548`](20260916-184548/) | 1.4.0 | 0/0 | 45 | 667/0/667 | pass | 9903 | 1298 | 6.7 | 1.8 | 15 | 0 | **green** |
| [`20260916-094455`](20260916-094455/) | 1.4.0 | 0/0 | 42 | 632/0/632 | skip | 9129 | 1199 | 6.8 | 1.8 | 15 | 0 | **green** |
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

**667 cases** — 667 passed, 0 failed, 0 skipped. The generated inventory
[`20260916-184548/test-cases.md`](20260916-184548/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **632 → 667** since the previous run.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 45 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` sets `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }`, so those paths
are not in it. A `0/0` that never moves is partly a statement about what was never looked at, which
is why the exclusion is restated on every run.

## Perf

**8 scenarios** from `tests/perf.lua`; the measurements are in
[`20260916-184548/perf.json`](20260916-184548/perf.json).

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20260916-184548`](20260916-184548/) — **this run's measurement, not its diff.** Max CCN **15** across 1298
functions, **0** of them warned on; 2 file(s) in the 1000–1500 band and 0 over the 1500 cap
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
| 1000–1500 (on notice) | `modules/Frame.lua` | 1063 | **Accepted, carried and re-stated.** It crossed into the band at the previous run (1035, from 869 the run before); 1063 here, +28, and still well inside the 1250 re-check trigger set when it crossed. Shape unchanged: a flat sequence of ~30 small local functions plus one long builder (`buildFrame`, now lines 566–830 — CCN 2 over 265 lines), and the file's worst function is CCN 13, so this remains length rather than tangle. No cheap internal seam to split along today. Re-check at 1250, or when `buildFrame` is peeled out, whichever comes first. Second consecutive carry, and no release run has carried it yet, so `automated-tests-§4`'s three-release shelf life has not begun to run. |
| 1000–1500 (on notice) | `tests/test_frame.lua` | 1421 | **Accepted, carried forward — the ruling stands and the file did not move.** 1421 at the previous run and 1421 here; the +35 cases this run landed in `test_slash.lua`, `test_launcher.lua` and `test_lifecycle.lua`, not in this file. The earlier re-check trigger (1250) has already fired and was re-argued then: still a flat list of independent cases, so the length is case count rather than tangle, and it is 358 lines longer than the 1063-line `modules/Frame.lua` it covers — that ratio remains the thing to watch. This stays the last acceptance: the next band boundary is the 1500 cap, and at that point the answer is a split along module seams (visibility, teleport, test mode), not another carry-forward. One release run (`bed07dd`, Release 1.4.0) has carried it, so it is one of three against `automated-tests-§4`'s shelf life. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

