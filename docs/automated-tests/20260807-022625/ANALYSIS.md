# Analysis — 20260807-022625

- **Addon:** WhatGroup 1.3.0
- **Verdict:** green
- **Commit:** 4e99ba5b015c (main), clean
- **Started:** 2026-08-07T02:26:25+05:30
- **Previous run:** [`20260804-233335`](../20260804-233335/)

## Headline

Both gating suites are clean — `luacheck` 0/0 across 14 files, **462 of 462** cases pass with none
skipped — so the run is **green** and the commit gate is satisfied. The news is on the non-gating
side: `ConfigureTeleportButton` (`modules/Frame.lua`) has **newly crossed CCN 15, at 20**, the first
warned function this addon has carried since the CCN work closed on 2026-08-04. It is the only
warning, and it is the direct cost of the WG-31 cooldown state (`c7d8e2d`) landing inside an already
branch-dense function. Nothing blocks a commit; **a tag would be blocked**, because the release gate
is all four suites plus zero functions above CCN 15, so this is the one item to act on before 1.4.0.

## Suites

Every row links its artifact. `perf` links nothing, because a skipped suite produces no artifact.

| Suite | Status | Result | Artifact | Moved since `20260804-233335` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 14 files | [`lint.txt`](lint.txt) | unchanged — 0/0 over the same 14 files |
| tests | pass | 462 passed, 0 skipped, 0 failed, 462 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | **+40 cases** (422 → 462), still 0 failures and 0 skips |
| perf | skip | 0 scenarios — nothing measured | — no artifact | unchanged — still no `tests/perf.lua` |
| complexity | pass | 1 warning, max CCN 20 | [`complexity.txt`](complexity.txt) | **0 → 1 warning**; max CCN 13 → 20 |

### Complexity in full

Every field of `lizard`'s footer as [`manifest.json`](manifest.json) records it, plus the two derived
file counts. The averages are the point: the addon grew this cycle, so a total that rose is a size
fact, not a density fact — and here the averages say the density barely moved while one *individual*
function did.

| Metric | This run | Previous (`20260804-233335`) | Moved |
|---|---|---|---|
| Total NLOC | 6095 | 5573 | +522 |
| Functions | 866 | 808 | +58 |
| Avg NLOC / function | 6.4 | 6.3 | +0.1 |
| Avg CCN | 1.7 | 1.7 | — |
| Max CCN | 20 | 13 | +7 |
| Avg tokens / function | 47.1 | 45.6 | +1.5 |
| Warnings (CCN > 15) | 1 | 0 | +1 |
| Warning rate — `Fun Rt` / `nloc Rt` | 0.00 / 0.01 | 0.00 / 0.00 | nloc rate 0.00 → 0.01 |
| Files in the 1000–1500 band | 0 | 0 | — |
| Files over the 1500 cap | 0 | 0 | — |

**Read the averages against the totals before reading the warning.** Total NLOC rose 9.4% and the
function count rose 7.2%, while `Avg CCN` did not move at all and `Avg NLOC / function` rose by a
single tenth. That is an addon that got *bigger*, not one that got *denser* — the signal
`performance-§10` asks for is flat. The `Fun Rt` of 0.00 says the same thing from the other end: one
warned function out of 866 does not register as a rate.

**The one warning, in full**, from [`complexity.txt`](complexity.txt):

| NLOC | CCN | tokens | params | length | Location |
|---|---|---|---|---|---|
| 72 | 20 | 486 | 3 | 157 | `ConfigureTeleportButton@240-396@./modules/Frame.lua` |

At the previous run the same function measured **NLOC 40, CCN 12, 296 tokens, length 78** at
`@184-261` ([`../20260804-233335/complexity.txt`](../20260804-233335/complexity.txt), line 90). It
roughly doubled on every axis. This is **not** the Lua `or`-defaulting artefact that
`performance-§10` warns about — there are only three defaulting expressions in it (`or 134400`,
`or 0`, and the `known and … or 0` guard). The CCN is genuine control flow: a combat-lockdown
stash-and-bail, a no-spell teardown-and-bail, a three-way note state machine (unlearned / on
cooldown / ready), a ready-vs-not attribute arming branch, and a `known`-vs-unknown tooltip branch
nested inside it. Five real decisions plus a re-entrant timer callback, in one function.

`perf` is a **skip, not a pass.** [`manifest.json`](manifest.json) records `"status": "skip"` with
`"scenarios": 0` and the reason `no tests/perf.lua — this addon ships no offline scenarios`. Nothing
about this addon's runtime cost was measured by this run, and `performance-§9`'s zero-overhead
evidence does not exist for it. That is a standing fact, not a tooling gap: the wiring is declined
under the ratified `performance-§12 (re-check fired)` row in
[`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)'s `## Documented deviations`.

## What moved

- **Complexity warnings 0 → 1.** `ConfigureTeleportButton` crossed from CCN 12 to CCN 20. This is
  the first warned function since the 2026-08-04 CCN work retired the last three.
- **Max CCN 13 → 20**, and the holder of that maximum changed: it was
  `WhatGroup:_TryFireJoinNotify` at 13, it is now `ConfigureTeleportButton` at 20.
- **Tests 422 → 462, +40 cases**, all passing, none skipped. The additions track the teleport
  cooldown work and the re-vendored kit: `tests/test_frame.lua` alone now carries 49 functions
  across 505 NLOC ([`complexity.txt`](complexity.txt), per-file table).
- **Size grew:** total NLOC 5573 → 6095, functions 808 → 866, avg tokens/function 45.6 → 47.1.
- **Density did not:** `Avg CCN` flat at 1.7, `Avg NLOC / function` 6.3 → 6.4.
- **Lint unchanged** — 0 warnings / 0 errors over the same 14 files, the same scope as last run.
- **Perf unchanged** — still a skip, still zero scenarios, still no `tests/perf.lua`.
- **File bands unchanged** — `bandFiles: 0`, `overCapFiles: 0`; no file is near 1000 LOC.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `ConfigureTeleportButton` | 20 | `modules/Frame.lua:240-396` | **Peel next — NEWLY CROSSED this run.** Genuine control flow, not `or`-defaulting: the cooldown/unlearned/ready note machine and its re-entrant ticker callback are separable from the attribute arming. Above CCN 15, so it **blocks the release gate** as it stands. Not accepted. |

Deliberately **not** dispositioned as *Accepted*. It is the entry's first appearance, the cause is
known and local, and an `Accepted` written on day one is what turns a watch list into a backlog
(`automated-tests-§4`, anti-pattern #53).

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| — | — | — | **None.** |

No file reaches the 1000-LOC on-notice threshold — [`manifest.json`](manifest.json) records
`bandFiles: 0` and `overCapFiles: 0`. The largest by raw line count are `core/WhatGroup.lua` at 746,
`tests/test_libka0s.lua` at 716 and `tests/test_frame.lua` at 627, so the closest file sits roughly
254 lines below the threshold.

## Actions

1. **Peel `ConfigureTeleportButton` (`modules/Frame.lua:240-396`) back under CCN 15 before the next
   tag.** The release gate is all four suites plus zero functions above CCN 15, evaluated by
   `/wow-addon:bump-version` from a release run's `manifest.json`; at CCN 20 this function fails it.
   The natural seam is the note state machine — the unlearned / on-cooldown / ready branch and its
   `renderNote` ticker — which is already a named unit in all but name and is pinned by cases in
   `tests/test_frame.lua`. `performance-§11` bounds what such a refactor may do.
2. **This action is new here** — it has no owner in the addon's tracking yet. It is not one of the
   three entries retired at the 2026-08-04 baseline, and no row in `docs/ARCHITECTURE.md`'s
   `## Documented deviations` covers it. If it is not peeled before the tag, it needs a tracked
   deviation ID rather than a carried `Accepted`.
