# Analysis — 20260916-094455

- **Addon:** WhatGroup 1.4.0
- **Verdict:** green
- **Commit:** 130676c0bc9c (master), clean
- **Previous run:** [`20260910-234511`](../20260910-234511/)

## Headline

The first run since the 1.4.0 release run, and it is green on the three suites that could run: lint
and tests both pass, complexity records zero functions above CCN 15. **perf did not run** — this
addon ships no `tests/perf.lua`, so nothing here says anything about runtime cost. The run's one
piece of new business is a second file entering the `layout-§1` on-notice band: `modules/Frame.lua`
crossed 1000 lines while the test-mode work landed, and it arrived with an empty disposition, ruled
below.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260910-234511` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 42 files | [`lint.txt`](lint.txt) | +1 file, figures unchanged |
| tests | pass | 632 passed, 0 skipped, 0 failed, 632 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +64 cases |
| perf | skip | not measured — no `tests/perf.lua` in this addon | — | skipped in both runs |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | see below |

| Metric | Value |
|---|---|
| Total NLOC | 9129 |
| Functions | 1199 |
| Avg NLOC / function | 6.8 |
| Avg CCN | 1.8 |
| Max CCN | 15 |
| Avg tokens / function | 49.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 2 |
| Files over the 1500 cap | 0 |

Every figure above is `manifest.json`'s `suites.complexity`, and the footer it was read from is the
last block of [`complexity.txt`](complexity.txt).

**perf is the one suite that is not a clean pass, and it is a skip, not a failure.**
`manifest.json` records the reason verbatim: *"no tests/perf.lua — this addon ships no offline
scenarios"*. That is the first of `automated-tests-§3`'s two sanctioned reasons — *nothing to run* —
and not a ratified `performance-§12` no-combat-path exemption. It is a standing fact about this
repository rather than anything this run did, and the consequence is worth stating plainly: this
record is **silent about runtime cost**. Nothing in this bundle claims the addon is cheap; the
question was not asked.

## What moved

- **lint** — 42 files, up one from 41. Still 0 warnings / 0 errors. The scope behind that figure has
  not changed: `.luacheckrc` still excludes `libs/`, `docs/audits/`, `docs/reviews/`, `_dev/` and
  `tests/_kit/`.
- **tests** — 568 → 632 passed, **+64**, the largest single-run jump this repository has recorded.
  Still zero skipped and zero failed, so passed and total agree and no case is claiming coverage it
  did not exercise. The growth is the test-mode work (`8af7636`, `18beaaa`) and the v1.37.0 /
  v1.38.0 re-vendors; [`test-cases.md`](test-cases.md) is the authority on which cases existed here.
- **perf** — skipped in both runs, same reason, nothing measured in either.
- **complexity** — NLOC 8065 → 9129 (**+1064**) over 1063 → 1199 functions (**+136**). The averages
  are the part that carries signal, and they barely moved: avg NLOC 6.7 → 6.8, avg tokens 48.6 →
  49.6, avg CCN flat at **1.8**, max CCN flat at **15**, warnings flat at **0**. So the addon grew
  by about 13% and did not get denser — the total rose because there is more of it, which is a
  different fact from a rising average and is not a complexity signal.
- **band files** — 1 → 2. `modules/Frame.lua` joined `tests/test_frame.lua` in the 1000–1500 band.
  Still nothing over the 1500 cap.

## Complexity watch list

Both tables are maintained in [`RESULTS.md`](../RESULTS.md), which the runner regenerates whole on
every run; the **Disposition** column there is the authored half and is current as of this run.

### Functions `lizard` warned on

None. Max CCN is 15 across 1199 functions, so nothing crossed. The densest functions in the tree are
`WhatGroup@857-925` in [`core/WhatGroup.lua`](../../../core/WhatGroup.lua) at CCN 15 and
`WhatGroup@966-1035` in [`modules/Frame.lua`](../../../modules/Frame.lua) at CCN 13, both visible in
[`complexity.txt`](complexity.txt). Neither is tangled control flow: they are defaulting and guarding
runs, which `lizard` scores as decisions because every `and`/`or` short-circuit counts as one.

### Files by `layout-§1` band

2 files in the 1000–1500 on-notice band, 0 over the 1500 cap. Both carry a disposition in
[`RESULTS.md`](../RESULTS.md#files-by-layout-1-band). The band is not part of the release gate.

**Newly crossed this run:** `modules/Frame.lua`, 869 lines at the previous run's commit and **1035**
here, pushed over by the test-mode checkbox and the `/wg test` split. Ruled **accepted** for now: it
is a flat sequence of about thirty small local functions with one long builder (`buildFrame`,
lines 558–830), its worst function sits at CCN 13, and the file has no internal seam that a split
would follow cheaply. Re-check at 1250, or when `buildFrame` is peeled out, whichever comes first.

**Re-check trigger fired:** `tests/test_frame.lua` carried a disposition saying to re-check at 1250
lines. It is **1421** this run, past that trigger, and it is now 386 lines longer than the 1035-line
module it covers. The disposition is re-argued rather than renewed: still accepted, still case count
rather than tangle, but the next crossing — 1500, the cap — is a split, not another acceptance.

## Actions

1. `modules/Frame.lua` — nothing due now; re-check the 1035-line count at 1250 or when `buildFrame`
   (lines 558–830) is peeled out. New here, with no deviation ID or review finding behind it.
2. `tests/test_frame.lua` — at 1421 it has one band left before the `layout-§1` cap. Plan the split
   along module seams (visibility, teleport, test mode) before it reaches 1500 rather than at it.
   New here; not tracked elsewhere.
3. `tests/perf.lua` — this addon still ships none, so four consecutive runs have said nothing about
   runtime cost. Either add scenarios or ratify a `performance-§12` exemption in
   `docs/ARCHITECTURE.md`'s deviations register, so the skip reads as a decision rather than a gap.
   Pre-existing, not new in this run.
