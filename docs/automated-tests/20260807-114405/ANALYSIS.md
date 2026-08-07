# Analysis — 20260807-114405

- **Addon:** WhatGroup 1.3.0
- **Verdict:** green
- **Commit:** `4a32cbef035ace557250225ada862b3b3ebf9486` (main), clean
- **Previous run:** [`20260807-110421`](../20260807-110421/)

## Headline

Green: both gating suites passed — lint clean over 14 files, 462 of 462 cases passing with none
skipped. Every measured figure is byte-identical to the previous run, which is the expected result
and not a stale reading: the only commit between the two runs (`4a32cbe`, a `.gitattributes` body
re-sync) touches no Lua, so an unchanged tree measuring unchanged is the confirmation. The one thing
to act on is unchanged too — `ConfigureTeleportButton` still sits at CCN 20, above the release
gate's 15, and it is dispositioned *peel next* rather than accepted.

This run is also the first bundle in this repo written by the **revision 10** kit (vendored at
`17d0ad7`, LibKa0s v1.8.2), whose `normalize_eol` pass writes the bundle with the line ending
`.gitattributes` declares instead of always LF. See *What moved*.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click. A
skipped suite links nothing — there is no artifact — and says what was not measured.

| Suite | Status | Result | Artifact | Moved since 20260807-110421 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 14 files | [`lint.txt`](lint.txt) | No change (0/0 over 14). |
| tests | pass | 462 passed, 0 skipped, 0 failed, 462 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | No change; `test-cases.md` is byte-identical to the previous run's. |
| perf | skip | 0 scenarios — no `tests/perf.lua` | *(none — nothing ran)* | No change; a standing skip, not a tooling gap. |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | No change on any field; `complexity.txt` is byte-identical to the previous run's. |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every value below is from [`manifest.json`](manifest.json)'s `suites.complexity`, and the raw
footer it was read from is at the end of [`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 6095 |
| Functions | 866 |
| Avg NLOC / function | 6.4 |
| Avg CCN | 1.7 |
| Max CCN | 20 |
| Avg tokens / function | 47.1 |
| Warnings (CCN > 15) | 1 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.01 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |

**`perf` — skipped, and nothing was measured.** The suite did not run because the addon ships no
`tests/perf.lua`; the record is therefore silent about WhatGroup's runtime cost, and
`performance-§9`'s zero-overhead evidence does not exist for it. This is a standing fact about the
addon rather than a missing tool. The manifest records the first of `automated-tests-§3`'s two
sanctioned reasons (*ships no `tests/perf.lua`*); the second and more informative one also applies
and is not in the manifest — see *Actions*.

**`complexity` — pass with one warned function.** `lizard` warns on
`ConfigureTeleportButton@240-396@./modules/Frame.lua` at CCN 20
([`complexity.txt`](complexity.txt), Warnings block). `complexity` does not gate this run or a
commit; it does gate the **tag**, and at CCN 20 this function would block a release as it stands.

## What moved

Nothing measured moved. Per suite, against [`20260807-110421`](../20260807-110421/):

- **lint** — 0/0 over 14 files, unchanged. Same 14 shipped source files, same result.
- **tests** — 462 passed / 0 skipped / 462 total, unchanged. `test-cases.md` is byte-identical
  between the two bundles, so the inventory did not merely hold its count, it held its exact
  contents.
- **perf** — `skip`, unchanged, same `skipReason`.
- **complexity** — every field unchanged: NLOC 6095, 866 functions, avg NLOC 6.4, avg CCN 1.7, max
  CCN 20, avg tokens 47.1, 1 warning, 0 band files, 0 over-cap files. `complexity.txt` is
  byte-identical between the two bundles.

The tree did change between the runs — `8d05986` to `4a32cbe` — but the only commits in that span
are the revision 10 re-vendor (`17d0ad7`) and a `.gitattributes` body re-sync (`4a32cbe`), neither
of which alters addon Lua. Identical figures are the correct outcome, and the byte-identical
artifacts make that a measurement rather than an assumption.

**Line endings — what this run proves.** The revision 10 kit added a `normalize_eol` pass so the
bundle is written with the line ending `.gitattributes` declares. This repo is CRLF-pinned
(`* text=auto eol=crlf`), and every file in this bundle carries equal CR and LF byte counts:
`complexity.txt` 916/916, `lint.txt` 16/16, `manifest.json` 19/19, `test-cases.md` 535/535,
`tests.txt` 464/464. That is the runner's own output and nothing else — this bundle is **untracked**
at the time of writing, so its bytes have never passed through a git checkout filter. The previous
bundles read CRLF on disk too, but they were committed and checked back out, so their line endings
prove nothing about the tool that wrote them; this one does.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `ConfigureTeleportButton` | 20 | `modules/Frame.lua:240-396` | **Peel next.** Carried unchanged from [`20260807-022625`](../20260807-022625/), where it newly crossed. Genuine control flow, not `or`-defaulting. Above CCN 15, so it blocks the release gate as it stands. Not accepted. |

Nothing newly crossed at this run. The disposition is carried forward rather than re-argued: it is
still true, and its reasoning stands where it was first written. The short form is that the usual
Lua reading of a large CCN — *this function defaults a lot of fields*, because `lizard` scores every
`and`/`or` short-circuit as a decision — does **not** apply here. Three defaulting expressions in
the whole function; the rest is a combat-lockdown bail, a no-spell teardown bail, a three-way note
state machine, a ready-vs-not attribute branch and a `known` tooltip branch nested inside it. It
wants decomposition, and `performance-§11` bounds what that refactor may do.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| — | — | — | **None.** |

No file reaches the 1000-LOC on-notice threshold — [`manifest.json`](manifest.json) records
`bandFiles: 0` and `overCapFiles: 0`. The largest is `core/WhatGroup.lua` at 746 lines, roughly 254
below the band.

## Actions

1. **`modules/Frame.lua` — decompose `ConfigureTeleportButton` (CCN 20).** Peel the three-way note
   state machine and the attribute-arming branch into named units. This is a release blocker, not a
   run blocker: `/wow-addon:bump-version` refuses a tag while any function is above CCN 15. It has
   no owner in this addon's tracking yet — it is carried only by this watch list, and it has now
   been carried across three consecutive runs (`20260807-022625`, `20260807-110421`,
   `20260807-114405`), none of which was a release run.
2. **`perf` `skipReason` under-reports what is known.** `automated-tests-§3` sanctions two reasons
   and says the `performance-§12` no-combat-path exemption **MUST** be recorded when it applies.
   WhatGroup holds one — the `performance-§12 (re-check fired)` row in
   [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)'s `## Documented deviations` — but the manifest
   carries only the bare *ships no `tests/perf.lua`*. The runner cannot know about the register, so
   this is a kit-or-standard question (how a repo declares its exemption to the runner), not a
   defect in this repo and not something to hand-edit into a frozen bundle.
3. **The previous run has no `ANALYSIS.md`.** [`20260807-110421`](../20260807-110421/) carries none.
   `automated-tests-§5` makes it a SHOULD for a non-release run whose numbers moved, and that run's
   numbers did not move, so this is a note rather than a violation — but the gap is worth knowing
   about when reading the trend line.
