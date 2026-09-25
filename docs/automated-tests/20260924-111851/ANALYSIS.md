# Analysis — 20260924-111851

- **Addon:** WhatGroup 1.4.0
- **Verdict:** green
- **Commit:** 011b39c2d11b69b3763adfddca7b2b125ffca7b6 (feat/2026-09-23-review-audit-remediation), clean
- **Previous run:** [`20260916-184548`](../20260916-184548/)

## Headline

All four suites pass on a clean tree: lint 0/0 over 50 files, 775 headless cases with nothing
skipped, 8 perf scenarios with no ceiling tripped, and 0 functions above CCN 15. Max CCN fell from
15 to 13. This is the first run since the 2026-09-23 remediation plan (WG-01..WG-29, the LibKa0s
v1.56.0 / kit revision 26 re-vendor, and WG-DOCS's doc sync), 67 commits after the previous record.
One file newly entered the `layout-§1` band, `core/WhatGroup.lua` at 1143 lines. It is ruled on
below and in [`../RESULTS.md`](../RESULTS.md) (`WHATGROUP-R-14`). Nothing else needs action.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260916-184548 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 50 files | [`lint.txt`](lint.txt) | 45 → 50 files; still 0/0 |
| tests | pass | 775 passed, 0 skipped, 0 failed, 775 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 667 → 775 (+108) |
| perf | pass | 8 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 8 → 8 scenarios; two byte figures fell |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings, unchanged; max CCN 15 → 13 |

**Complexity in full**, from `manifest.json`'s `suites.complexity` and the footer in
[`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 11285 |
| Functions | 1471 |
| Avg NLOC / function | 6.7 |
| Avg CCN | 1.8 |
| Max CCN | 13 |
| Avg tokens / function | 49.7 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |

Every suite passed cleanly, so no suite needs a failure paragraph. No suite was skipped, and no case
reported a `Kit.skip`: passed and total are both 775, so the row claims no coverage that was not
exercised.

**perf is a `pass`, not a register-derived skip.** `manifest.json` → `suites.perf` has
`"status": "pass"` and no `skipReason`. Kit revision 26's runner (LK-09) now reads the
`## Documented deviations` register and records skip reason (2) for a `performance-§12` row.
WhatGroup has such a row, keyed `performance-§12 (the exemption is not claimed)`, but it also ships
`tests/perf.lua`, so the suite ran and the skip branch was never reached. That is the result the
plan expected, so nothing is filed upstream against LK-09.

## What moved

**lint: 45 → 50 files, still 0/0.** The five new files, from a diff of the two runs' `lint.txt`
file lists: `core/LifecycleSetup.lua`, `settings/SchemaSetup.lua`, `tests/prose_waivers.lua`,
`tests/test_disabled.lua` and `tests/test_frame_secure.lua`. The scope is restated in
[`../RESULTS.md`](../RESULTS.md)'s `## Lint` section. `.luacheckrc` now also excludes
`docs/revendor/` (WG-18), so six paths are outside this 0/0.

**tests: 667 → 775 (+108).** Per suite, from the two runs' `test-cases.md` `## Totals` tables:
four suites are new since the previous run: `test_disabled` (18), `test_prose` (15),
`test_layout_cap` (13) and `test_frame_secure` (7). The rest grew: `test_debuglog` 34 → 49,
`test_compat` 31 → 42, `test_libka0s` 48 → 54, `test_harness` 12 → 17, `test_surface_parity`
4 → 9, `test_capture` 32 → 35, `test_launcher` 21 → 24, `test_database` 9 → 11, `test_lintconfig`
4 → 6, and `test_eol`, `test_lifecycle` and `test_panel` by one each. No suite lost a case.
`test_frame` stayed at 90, so the case growth did not land in the band file.

**perf: 8 scenarios, no ceiling tripped (`"failures": []`).** Six scenarios read the same as last
time, to the byte. Two allocate less:

| Scenario | api/iter | bytes/iter, previous → now |
|---|---|---|
| `combatGateFlipping` | 7 → 7 | 1064.1 → 1000.0 |
| `showFrameRepeat` | 18 → 18 | 1872.5 → 1744.1 |

`cooldownTick`, the scenario behind the `performance-§12` register row, is unchanged at 2 API calls
and 240.4 bytes per tick. The two falls sit on the popup's show and combat-edge paths, which
WG-04 (soft-hide through `ApplyFrameAlpha`) and WG-15 (teleport handlers defined once at file
scope) touched. API counts are unchanged, so no behavior was traded for the bytes.

**complexity: the addon grew; per-function density stayed flat.** Total NLOC went 9903 → 11285
(+1382) and functions 1298 → 1471 (+173), mostly tests. Avg NLOC per function held at 6.7 and avg
CCN at 1.8. Avg tokens per function rose slightly, 49.1 → 49.7. Max CCN fell 15 → 13, and warnings
stayed at 0. The densest functions now are `LFG_LIST_APPLICATION_STATUS_UPDATED`
(`WhatGroup@1017-1085@./core/WhatGroup.lua`) and `ShowFrame` (`WhatGroup@1037-1090@./modules/Frame.lua`),
both at CCN 13. Band files went from 2 to 3 because `core/WhatGroup.lua` crossed 1000. No file is
over the cap.

**Non-suite context.** The previous row has no Commit and Tree cells. The runner emits those as of
kit revision 26, so every earlier row reads `unknown` in both. This run is the first with a
recorded sha.

## Complexity watch list

### Functions the complexity tool warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None: 0 functions above CCN 15 (`manifest.json` → `suites.complexity.warnings`), and
[`complexity.txt`](complexity.txt) reads `No thresholds exceeded`.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/WhatGroup.lua` | 1143 | **Accepted, with a trigger: re-check at 1450** (new to the band). See [`../RESULTS.md`](../RESULTS.md) |
| 1000–1500 (on notice) | `modules/Frame.lua` | 1173 | **Accepted, with a trigger: re-check at 1450** (was 1250). See [`../RESULTS.md`](../RESULTS.md) |
| 1000–1500 (on notice) | `tests/test_frame.lua` | 1422 | **Accepted, with a trigger: re-check at 1450, then split** (ruling stands). See [`../RESULTS.md`](../RESULTS.md) |

`core/WhatGroup.lua` is the one new entry, and the one `WHATGROUP-R-14` found undispositioned. Its
45 functions average CCN 4.6 and the worst is 13, so the length reflects the AceAddon shell and
the capture pipeline in one file. It is not tangle. `modules/Frame.lua` grew 1063 → 1173, and
`buildFrame` is still a flat builder (CCN 2 over 265 lines, now at 618–882). `tests/test_frame.lua`
moved by one line. All three now share one re-check line at 1450, below the 1500 cap. None has been
carried as *Accepted* across three consecutive release runs, so `automated-tests-§4`'s shelf life has
not expired for any of them.

## Actions

1. **None gating.** No suite failed and no function warned. The one new band entry has its
   disposition.
2. **Standing: the 1450 re-check line on three files.** Whichever change takes `core/WhatGroup.lua`,
   `modules/Frame.lua` or `tests/test_frame.lua` past 1450 owes the split named in its disposition,
   not another carry-forward. Tracked by `WHATGROUP-R-14` (the 2026-09-23 review); there is no
   GitHub issue yet.
3. **Not a release.** This bundle has no `--release` stamp, and no version bump or tag goes with
   it. A release run through `/wow-addon:bump-version` is the owner's call.
