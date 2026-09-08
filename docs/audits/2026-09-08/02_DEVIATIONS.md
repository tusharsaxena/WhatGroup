# 02 — Deviations (2026-09-08)

**Standard:** v2.39.0 (2026-09-07). **ID prefix:** `WG-` (stable since 2026-07-12). Recurring
deviations keep their IDs; new IDs this run begin at **`WG-61`**.

**Grading is by impact, not rule strength** (`AUDIT.md` step 5). A doc-only or config-only failure
is **Low** or **Info** even when the rule it fails is a MUST, and the entry names that MUST anyway.

## Tally — both numbers, with their basis

| | Count |
|---|---|
| **Headline tally (roots only)** | **7** |
| Derived dependents (`derived from …`, excluded above) | 1 |
| **Total including dependents** | **8** |

By impact grade, roots only:

| Grade | Count | IDs |
|---|---|---|
| **High** | **0** | — |
| **Medium** | **0** | — |
| **Low** | **5** | WG-51 · WG-54 · WG-58 · WG-61 · WG-62 |
| **Info** | **2** | WG-48 · WG-56 |

**MUST failures: 5 roots** (WG-51, WG-54, WG-58, WG-61, WG-62) — every one graded **Low**, because
none is reachable by a user, their SavedVariables or their session. The one dependent (WG-63) is a
MUST failure too (`testing-§12`) and is excluded from that count by the one-root rule. WG-48 and
WG-56 fail no MUST that is open against this repo: WG-48's checkpoint is release and no release has
been cut, and WG-56 is a defect in the standard's own text.

**Verdict: minor deviations.** Nothing a player can hit. Down from **14 roots / 15 total** on
2026-09-07 to **7 / 8**. Three of today's seven are the residue of findings this cycle set out to
close, one is an upstream item the cycle's work packet did not reach, and **two are new — both of
them introduced by this cycle's own commits, and both invisible to the audit that preceded them**.

---

## Recorded deviations — accepted, not re-filed

These match ratified rows in `docs/ARCHITECTURE.md` → `## Documented deviations` (`:351`, rows at `:368-371`) and
**do not count toward the tally or the MUST count** (`audit-review-history`). Every row's re-check
trigger was evaluated against this tree; none has fired. Evidence in 03 §H.

| Rule | Decided | Trigger evaluated today | Status |
|---|---|---|---|
| `performance-§12` (re-check fired 2026-08-06; wiring still declined) | 2026-08-06 | (1) `performance.md` is **byte-identical** between v2.38.0 and v2.39.0, so no upstream amendment landed. (2) `modules/Frame.lua:351` is still the only repeating timer; the arm is gated on `f:IsShown()` at `:347`. | **Confirmed, not fired.** |
| `localization-§3` (English-only) | 2026-08-05 | `ls locales/` → `enUS.lua` only. | **Confirmed, not fired.** Its **evidence id** does not resolve — see WG-61. |
| `events-frames-taint-§8` (pre-formatting; two unreachable `pout` fallbacks) | 2026-08-05 | Protected-API sweep returns **0**; TOC still loads `core\WhatGroup.lua` (`:43`) before every `settings/` file (`:64-70`). | **Confirmed, not fired.** Its **evidence id** does not resolve — see WG-61. |
| `standalone-windows` (footer **Close** carries no mark) | 2026-08-25 | The popup's footer holds exactly one wide action button (`modules/Frame.lua:586-589`); the teleport control is a 24×24 body icon (`:541-543`). | **Confirmed, not fired.** The `WG-52` citation defect is **closed**: the Rule cell now reads bare `standalone-windows`. |

**Rows whose cited rule the standard has since changed:** none. `performance-§12`, `localization-§3`
and `events-frames-taint-§8` are unchanged in v2.39.0; `standalone-windows` gained a
reasoned-decline bullet, which strengthens rather than retires this row (the decline here is of a
**SHOULD about a wide action button**, not of the `MakeCloseButton` wrapper, which the addon does
carry at `core/CoreSetup.lua:136`).

**`state:will-not-do` issues with no register row:** checked and none owed. The six closed
`will-not-do` issues (#5, #9–#14) decline a `LibKa0s` module the addon has no use for, or an
`X-Wago-ID` the standard does not require. None declines a standard rule, so none is a ratified
deviation missing its home.

## Examined and deliberately not filed

- **`architecture-§4`'s Message Bus rationale** (the former `WG-57`). The cycle's triage rejected
  `WHATGROUP-A-12` on the ground that `modules/Frame.lua`'s two `PLAYER_REGEN_ENABLED`
  registrations are transient combat-defer hops on throwaway frames, not a second bus party. That
  reading is re-measured and holds: the registrations are at `modules/Frame.lua:394` and `:733`,
  the second on a frame created one line above and released on fire, and `§4`'s own hazard — the
  CallbackHandler same-target clobber — cannot arise with no messages at all. `§4`'s applicability
  clause asks a sub-threshold addon to **record** that there is no bus and why; `docs/ARCHITECTURE.md:107-114`
  does. Not re-filed, and no register row is owed, because a rejected finding is not a ratified
  deviation.
- **`toc-file-§5` on `# Locales`.** `locales\enUS.lua` publishes `NS.L`, taken as a file-scope
  upvalue by three later files, and carries no comment. It is not filed: the position is already
  fixed by `toc-file-§5`'s own section-header-order MUST, and the section's reference block shows
  `# Locales` uncommented. Recorded in 01 rather than counted.
- **`ARCHITECTURE.md`'s own map row.** Absent. v2.39.0 makes this a **MAY** and forbids an audit
  from filing either state.
- **`options-ui-§13`(h), the wrapped-strip geometry.** No page here wraps (three tabs). The
  vendored library reads the wrapped-row pitch from the **unselected** tab art
  (`libs/LibKa0s/OptionsWidgets.lua:436-455`), which is the compliant shape, and is audited in its
  own repo.

---

## Low

### WG-54 — two British spellings in authored comments, both written by this cycle
**Section:** `localization-§5` (**MUST**), anti-pattern #46 · **Where:** `core/WhatGroup.lua:60`, `core/WhatGroup.lua:779` · *reopened (was closed by `M4-13`)*

Swept with v2.39.0's newly published canonical `BRITISH` / `ALLOWED` lists, taken **whole**, over
65 tracked files (03 §E names the scope and the exclusions). Five raw hits; three are the sanctioned
Blizzard-symbol exception — `"cancelled"` is a `C_LFGList` application-status token, reproduced
verbatim at `core/WhatGroup.lua:740`, `docs/data-flow.md:56` and `tests/test_capture.lua:433`. Two
are real:

- `core/WhatGroup.lua:60` — *"…two varargs **travelled** into handler bodies that read none of
  them…"*
- `core/WhatGroup.lua:779` — *"Deliberately empty, and the emptiness is the **behaviour**…"*

The three sites the 2026-09-07 run named are **gone** — `grep -rniE
'colour|grey|behaviour|centre|cancelled|travelled' modules/Frame.lua settings/Schema.lua
settings/OptionsSetup.lua` returns no output — and no live `docs/` or `tests/` hit survives; `M4-13`
did its sweep. (Their old line numbers are deliberately not repeated: the files have moved under
them.) Both survivors were written **after** it, by `5f7272b` (`M4c-04`) on 2026-09-08, into
the same file. `travelled` is additionally a word the 2026-09-07 grep
(`colour|grey|behaviour|centre|cancelled`) could not see; only the published list catches it, which
is the amendment doing its job.

Low: comment text, no locale key, no player-facing string. **Fix:** `travelled` → `traveled`,
`behaviour` → `behavior`. Then adopt the published lists as a repo gate so the next sweep is not
manual.

### WG-51 — the vendored-payload gate still does not assert the runner's recorded mode
**Section:** `automated-tests-§2` (**MUST**) · **Where:** `tests/_kit/vendor_sync.lua`, `tests/test_vendor_sync.lua` · **Scope: libka0s-upstream** · *carried from 2026-09-07, unclosed*

`automated-tests-§2` MUSTs that the consumer-side gate assert `run-automated-tests.sh` is recorded
as `100755` — *"the one property of the payload that no amount of reading the working tree can
confirm"*, because every repo here sits on DrvFs with `core.fileMode=false`.
`grep -rn '100755\|--chmod\|ls-files -s' tests/_kit/ tests/` returns **nothing**.

This is a **cycle miss, not a re-file.** `WHATGROUP-A-06` was mapped to `M1-LK-07`; that item
closed its sibling (`WHATGROUP-A-05`, the `skipped` key — see the closed list below) and did not add
this assertion. Confirmed upstream, not merely stale here: the sibling `LibKa0s` repo's `testkit/`
at HEAD carries no `100755` either, and WhatGroup is already on the newest tag (v1.27.0), so no
re-vendor would pick it up.

This repo's mode **is** correct today — `git ls-files -s tests/_kit/run-automated-tests.sh` →
`100755` — so the impact is a missing guard, not a broken file. `testing-§1` forbids editing the
vendored kit, so it is not fixable here. **Fix:** raise on `LibKa0s`; adopt at the next re-vendor.

### WG-58 — `.pkgmeta` still does not ignore `.superpowers`
**Section:** `packaging` (**MUST** — the named ignore list) · **Where:** `.pkgmeta:6-31` · *carried from 2026-09-07, half closed*

`AUDIT.md`'s check (a), run verbatim, prints one line: `NOT IGNORED — .superpowers`. Check (b) —
the strong form over every root dot-entry actually present — is **clean**, reporting only `.git`,
which is the one exemption.

The other half of the 2026-09-07 finding **is** closed, and by the standard rather than by the
repo: v2.39.0 amended `packaging`'s minimum template to add `.pkgmeta` to its own ignore list,
naming WhatGroup as one of the seven repos that *"failed the strong-form check below on a line this
section never gave them"*. `.pkgmeta:14` now carries it, and `_dev` (`:12`) and `.claude` (`:19`)
are there too.

What did **not** change is `.superpowers`, which v2.39.0 still names in both the template and the
MUST bullet, *"named here rather than left to the reader's judgment because the judgment call was
made wrong five times"*. The cycle's triage rejected this half on the ground that no `.superpowers`
path exists in the repo — true, and the reason the grade is Low: nothing ships today that should
not. But the weak-form list is written to be unconditional precisely so that the guard predates the
directory, and no register row records the decline. **Fix:** one line in `.pkgmeta`, or take the
unconditional-list question upstream and record the outcome in the register.

### WG-61 — two register rows cite evidence ids that resolve to nothing, and one resolves to a different finding
**Section:** `audit-review-history` (**MUST** — the third MUST, new in v2.39.0), `documentation-§3` · **Where:** `docs/ARCHITECTURE.md:369`, `docs/ARCHITECTURE.md:370` · *new*

v2.39.0 gave `audit-review-history` a third MUST: *"the ids a row cites in **Why** … **MUST**
resolve, the deviation id to a bundle under `docs/audits/`, the finding id to one under
`docs/reviews/`, the issue to the addon's own repo."* Two of the four rows fail it, and the register
supplies its own resolution key at `docs/ARCHITECTURE.md:360-364`, which is what makes both
checkable:

- **`localization-§3` (`:369`) cites `WG-R-06`.** The key says a `WG-R-NN` id *"is a review finding
  and resolves in `docs/reviews/2026-09-07/` as `WHATGROUP-R-NN`"*. `WHATGROUP-R-06` there is
  *"`Compat.IsSpellKnown` is the one spell shim with no modern-namespace rung"*
  (`docs/reviews/2026-09-07/01_FINDINGS.md:197`, open as issue #15) — a different subject entirely.
  The row's real evidence, matching its 2026-08-05 Decided date, is **`F-006`** at
  `docs/reviews/2026-08-05/01_FINDINGS.md:172`.
- **`events-frames-taint-§8` (`:370`) cites `WG-A-08`.** The key says a `WG-A-NN` id *"is a
  deviation an audit filed and resolves in `docs/audits/`"*. No bundle under `docs/audits/` assigns
  it; the only occurrence is the frozen 2026-09-07 bundle **quoting this same register row**
  (`docs/audits/2026-09-07/02_DEVIATIONS.md:46`), so the citation is circular. The row's real
  evidence is **`WG-37`** at `docs/audits/2026-08-05/02_DEVIATIONS.md:113`, which that very bundle
  names as the one this row absorbed.

Low — a reader cannot be harmed by a bad citation, only misled. But it is the exact failure the new
MUST was written for: *"an id that resolves to nothing … reads as evidence and leads to none, and
it survives every re-read by a maintainer who knows the shape of an id and never goes looking for
what it names."* **Fix:** `WG-R-06` → `F-006` (`docs/reviews/2026-08-05/`), `WG-A-08` → `WG-37`
(`docs/audits/2026-08-05/`), and extend the key at `:360-364` to cover the pre-2026-09-07 bundles'
id shapes.

#### WG-63 — the gate that should have caught WG-61 is green against it · *derived from WG-61*
**Section:** `testing-§12` (**MUST** — falsifiability), `audit-review-history` · **Where:** `tests/test_register.lua:51,59-77,94`

`tests/test_register.lua` exists for exactly this MUST and passes. It misses both rows, for two
separate reasons, and its own header comment predicts one of them:

- `WG-R-06` is **excluded by construction** — `tests/test_register.lua:94` skips any id matching
  `id:find("%-R%-")`, documented at `:44-48` as *"a whole-repo naming convention rather than a register
  defect"*. That was a defensible call before the third MUST existed; under it, a review-finding id
  is one of the three kinds the rule names.
- `WG-A-08` **passes** because `isAssigned` (`:59-77`) accepts an id heading any table cell in any
  bundle, and the frozen 2026-09-07 bundle's register-echo row is such a cell. The file's own
  comment at `:38-42` names this hazard — *"a bundle that REPORTS a dead citation quotes the dead id
  while doing so, so a substring search goes green on the very defect it was written for"* — and
  the cell test is a stricter substring search, not an escape from it.

Stays a dependent: both halves close in the same act as WG-61 (fix the rows, then tighten the gate
that let them through), and neither is reachable independently. It **graduates to a root** the
moment WG-61 is closed without the gate being tightened. **Fix:** resolve `WG-R-NN`/`F-NNN` ids
against `docs/reviews/` instead of skipping them, and exclude a bundle's *Recorded deviations*
echo table from `isAssigned`'s corpus.

### WG-62 — ten citations name a standards section that cannot be resolved
**Section:** `documentation-§6` (**MUST** — *"a malformed or out-of-range reference is a MUST fix"*) · **Where:** ten sites, two forms · *new*

The sweep is mechanical: extract every `filename-§N` token from the 66 tracked files that are not
vendored or frozen, and range-check each against `grep -c '^### [0-9]'` on the section file it
names — *"the only authority"*, per `documentation-§6`. Command, scope and output in 03 §F. Two
forms, **enumerated individually** because the rule requires it:

**(a) `lint-§1` — 8 sites.** `lint` is one of the **eleven** files `documentation-§6` names as
carrying no numbered subsections (`grep -c '^### [0-9]'` → `0`), so *"any `filename-§N` citation
against one of them is out-of-range by construction"*. It must be cited by bare filename.

| Site | Text |
|---|---|
| `.luacheckrc:13` | `-- linted (lint-§1). Under docs/ only the FROZEN evidence bundles are excluded;` |
| `.luacheckrc:19` | `-- NO TOP-LEVEL \`ignore\`, and none is coming back (lint-§1, \`M4-11\`).` |
| `.luacheckrc:73` | `-- The narrowed 212s (lint-§1, \`M4c-04\`)` |
| `docs/testing.md:299` | ``…is the four cases that hold it honest (lint-§1,`` |
| `tests/test_lintconfig.lua:1` | `-- tests/test_lintconfig.lua — the "no blanket suppression" gate (lint-§1, \`M4-11\`).` |
| `tests/test_lintconfig.lua:131` | `.. "business producing it, so it reads as coverage and provides none (lint-§1, "` |
| `tests/test_lintconfig.lua:151` | `.. "lint-§1 refuses it for the same reason: it reaches every file in the repository "` |
| `tests/test_lintconfig.lua:262` | `.. "warning in the same scope is still reported (lint-§1)", 2)` |

All eight were written on 2026-09-08 by `5abc522` (`M4-11`) and `5f7272b` (`M4c-04`) — the two
commits that adopted the `lint` amendment. The rule they cite is real and they cite it in the one
form that cannot resolve.

**(b) `code-quality-§3` — 2 sites.** There is no `code-quality.md` in the standard's Sections list
at all, so this is the worse grade `documentation-§6` describes: a reference that *"send[s] the
reader to a section that does not exist and looks current doing it."*

| Site | Text |
|---|---|
| `core/WhatGroup.lua:744` | `-- complex function and sits at the \`code-quality-§3\` ceiling; the "inviteaccepted" arm is the` |
| `docs/module-map.md:17` | `…named rather than inlined so the function stays inside the \`code-quality-§3\` ceiling…` |

The rule both mean is the CCN ceiling, which lives in `performance-§10` and is enforced at
`automated-tests-§3`'s release gate.

The retired dotted `§N.M` sweep — the **SHOULD** half of the same rule — returns **0**.

Low: comments and prose. The entry names the MUST anyway. **Fix:** `lint-§1` → `lint` (8 sites,
one sweep); `code-quality-§3` → `performance-§10` (2 sites). Consider a gate — the check is one
`grep -c '^### [0-9]'` per cited file.

---

## Info

### WG-48 — the regenerated automated-test record is already three commits behind HEAD
**Section:** `automated-tests-§1`, `automated-tests-§4` (**MUST**), anti-pattern #51 · **Where:** `docs/automated-tests/RESULTS.md:26,36,47,55,63` · *reduced from 2026-09-07*

`M5-01` did its job: the record was regenerated end-to-end by the runner at `20260908-181437`, the
Tests cell reads `554/0/554` in v2.39.0's mandated `passed/skipped/total` shape, the four standing
sections (`:36`, `:47`, `:55`, `:63`) are the runner's, and the watch list says
*"Current as of `20260908-181437`"* (`:65`), the watch-list band table is
populated with an authored `Disposition`, and the bundle carries an `ANALYSIS.md`. Every complaint
the 2026-09-07 entry made is answered.

What remains is arithmetic. The manifest records the run at `e735453`; three commits landed after
it (`5f7272b`, `13ae17a`, `58bc280`). Measured at HEAD today with the standard's **verbatim**
invocation (03 §G):

| | Recorded `20260908-181437` | HEAD `58bc280` |
|---|---|---|
| Total NLOC | 7702 | **7913** |
| Functions | 1044 | **1050** |
| Max CCN | 15 | 15 |
| `lizard` warnings | 0 | 0 |
| Files in the 1000–1500 band | 1 | 1 (`tests/test_frame.lua`, 1063) |
| `luacheck` files | 40 | **41** |
| Test cases | 554 | **559** |

Nothing crossed a threshold and no file entered or left the band, so the drift is size, not risk.
**Info rather than Low**, because `automated-tests`' checkpoint is **release**, no release has been
cut since 1.3.0, and `§6` does not require a bundle per commit — this is a note about where the
record stands, not an open failure. It becomes a finding if 1.3.1 is tagged from this record.
**Fix:** run `tests/_kit/run-automated-tests.sh` as part of the release, not before it.

The watch list is **not** an anti-pattern #53 case: one entry, first written today
(`git log -- docs/automated-tests/RESULTS.md` → `d54a8dc`), and every manifest carries
`"release": null`, so the three-consecutive-release-runs clock has never started. `lizard` warns on
nothing, so no CCN needs the dense-defaulting-versus-tangled reading.

### WG-56 — `documentation-§1` item 7 still names a `Tab | Covers` header while mandating page granularity
**Section:** `documentation-§1` item 7 · **Where:** `README.md:63-73` · **Scope: standards-upstream** · *reduced from 2026-09-07*

`M5-03` collapsed the table to one row per page, which is what §1's sentence mandates — *"one row
per settings subcategory… stays at page granularity"* — and `tests/test_doc_structure.lua` now
pins it. The README reads `| Page | Covers |` (`:69`) with a single **General** row (`:71`) and a link to
`docs/settings-panel.md` (`:73`), which carries the per-tab breakdown §1 says belongs there.

The residue is upstream and unchanged: the same sentence still calls the table a
*"**Tab | Covers** table"*, so the literal column name and the granularity it mandates contradict
each other, and `documentation`'s v2.39.0 diff does not touch item 7. Filed as **Info against the
standard's text**, not the repo — the repo made the only self-consistent choice available.
**Fix (upstream):** rename the header in §1 to `Page | Covers`, or say explicitly that the column
name is illustrative.

---

## Closed since 2026-09-07

Measured, not assumed. Eleven of the fourteen roots and the one dependent are gone.

| ID | Closed by | Evidence |
|---|---|---|
| WG-46 | `M4-10` | `AUDIT.md` (e) one-liner returns **0** (was 6). 03 §C. |
| WG-47 | `M4-12` | All four load-bearing TOC positions annotated; three groups gained conventional notes. 01, TOC table. |
| WG-49 | `M5-01` (fix-forward) | `20260908-181437/ANALYSIS.md` carries *"The `ANALYSIS.md` gap, noted once"*. v2.39.0 now **forbids** backfilling the two older bundles. |
| WG-50 | `M1-LK-07` | `RESULTS.md:26` reads `554/0/554`; the manifest's `tests` object carries `"skipped": 0`. |
| WG-52 | `M5-02` | `docs/ARCHITECTURE.md:371` Rule cell is bare `standalone-windows`. |
| WG-53 | `M5-04` | `docs/compat-layer.md` exists; `docs/ARCHITECTURE.md:330` reads *Present*, *"seven addon-specific shims, over the three-or-more threshold"* — and the threshold is v2.39.0's new count. |
| WG-55 | `M5-03` | `README.md:121` now reads *"add a delay under Chat"*, matching `:21`. |
| WG-57 | triage | Rejected as `WHATGROUP-A-12`; re-measured and the rejection holds. See *Examined and deliberately not filed*. |
| WG-59 | `M4-11` | `.luacheckrc:17` carries `"_dev/"`, and the whole `exclude_files` list is now v2.39.0's template verbatim. |
| WG-60 | `M1-STD-03` (rule change) | `documentation-§3` now MUSTs the fourth table; `docs/ARCHITECTURE.md:334` already had it. The hub's self-row is now a MAY an audit may not file either way. |
| WG-58 (`.pkgmeta` half) | `M1-STD-13` (rule change) + repo | `.pkgmeta:14`. The `.superpowers` half is open above. |
| WG-48 (record half) | `M5-01` | See the Info entry. |
| WG-54 (three original sites) | `M4-13` | `grep -rniE 'colour\|grey\|behaviour\|centre\|cancelled\|travelled' modules/Frame.lua settings/Schema.lua settings/OptionsSetup.lua` → **no output**; two new sites opened elsewhere. |

## Recorded as compliant, not as omissions

Measured and passing, so no row: `layout` (all three, including v2.39.0's stated cap denominator),
`toc-file` (§1–§5, including §5's amended MUST-denominator and its SHOULD), `library-stack`
(§1's amended *when used* table, §3's three-way reachability test, §5, §6, §8's shared media, and
**§9 / anti-pattern #76 — there is no `core/LSMPatch.lua`**), `architecture` (all seven),
`savedvariables` (all five), `options-ui` (§1–§18, including §1's amended hollow-composer ruling,
§13's strip on every non-exempt page, §14's single unboxed chrome band, §15's composed
`Master controls` first tab keyed off `Helpers.MASTER_GROUP`, and §16/§17/§18 which do not engage),
`standalone-windows` (including the amended one-wrapper MUST — the grep returns the wrapper and its
stub and nothing else — and its four-condition decline bullet, which this addon does not invoke),
`slash-commands`, `debug-logging` (including §13's `addonName` in the descriptor), `compat`,
`events-frames-taint` (§1–§7; §8 is a register row), `localization-§1`/`§2`/`§4` (§3 is a register
row; §5 is WG-54), `preview-mode` (`/wg test` is the explicit verb, through the same render path),
`public-api` (not engaged), `lint` (v2.39.0's amended template **exactly** — `tests/_kit/` only,
the harness global in a `files["tests/"]` stanza, no top-level `ignore`, and no
`debugprofilestop`/`WhatGroupPerfDB` under the `performance-§12` exemption; 0/0 over 41 files),
`testing` (§1–§14, including §8's stub-surface parity from a real degraded load, §11's
vendored-payload gate green, and §12), `automated-tests-§2` apart from WG-51 and `§3`/`§4`/`§5`
(including v2.39.0's *one boundary* on the `Disposition` column and its no-backfill MUST),
`performance-§1`–`§11` (§12 is a register row), `packaging` apart from WG-58, `versioning-git`,
`documentation-§1` apart from WG-56, `§2`, `§3` (all six tier-model checks, including the new
fourth table and the new `compat-layer.md` count), `§4`, `§5`, `§6` apart from WG-62, `§7`,
`naming-cheatsheet`, `line-endings-§1`–`§7` (canonical body byte-identical, tree clean, and §7's
new `tests/_kit/test_eol.lua` gate present and green), `audit-review-history` apart from WG-61 —
and the anti-pattern list apart from **#46** (WG-54), **#51** (WG-48) and **#56**'s gate half
(WG-63), with **#45, #47, #48, #49, #53, #58, #59, #60, #61, #62, #63, #64, #65, #66, #67,
#68–#76 all clear**.
