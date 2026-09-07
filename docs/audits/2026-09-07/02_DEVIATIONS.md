# 02 — Deviations (2026-09-07)

**Standard:** v2.38.0 (2026-09-02). **ID prefix:** `WG-` (stable since 2026-07-12). Recurring
deviations keep their IDs; new IDs this run begin at **`WG-46`**.

**Grading is by impact, not rule strength** (`AUDIT.md` step 5). A doc-only or config-only failure is
**Low** or **Info** even when the rule it fails is a MUST, and the entry names that MUST anyway.

## Tally — both numbers, with their basis

| | Count |
|---|---|
| **Headline tally (roots only)** | **14** |
| Derived dependents (`derived from …`, excluded above) | 1 |
| **Total including dependents** | **15** |

By impact grade, roots only:

| Grade | Count | IDs |
|---|---|---|
| **High** | **0** | — |
| **Medium** | **0** | — |
| **Low** | **12** | WG-46 · WG-47 · WG-48 · WG-50 · WG-51 · WG-52 · WG-53 · WG-54 · WG-55 · WG-56 · WG-57 · WG-58 |
| **Info** | **2** | WG-59 · WG-60 |

**MUST failures: 12 roots** (WG-46, 47, 48, 50, 51, 52, 53, 54, 55, 56, 57, 58) — every one of them
graded **Low**, because none is reachable by a user, their SavedVariables or their session. The one
dependent (WG-49) is a **SHOULD**. WG-59 and WG-60 fail no MUST.

**Verdict: minor deviations.** Nothing a player can hit. Every finding is a doc, a config file, a
record or a TOC comment. The 2026-08-05 run's entire open list has closed or been ratified into the
register; what remains is hygiene plus two upstream items and two the standard's own text is unclear
about.

## Recorded deviations — accepted, not re-filed

These match ratified rows in `docs/ARCHITECTURE.md` → `## Documented deviations` and **do not count
toward the tally or the MUST count** (`audit-review-history`). No new evidence contradicts any of
them, so none reopens.

| Rule | Decided | Issue | Status this run |
|---|---|---|---|
| `performance-§12` (exemption claimed) | 2026-08-02 | [#7](https://github.com/tusharsaxena/WhatGroup/issues/7) | Superseded by the row below; kept as record. Confirmed. |
| `performance-§12` (re-check fired, wiring still declined) | 2026-08-06 | [#7](https://github.com/tusharsaxena/WhatGroup/issues/7) | **Confirmed.** Neither re-check trigger has fired: `modules/Frame.lua:275` is still the only repeating timer and its handle is still popup-bounded. Absorbs the former `WG-30`–`WG-35`. |
| `localization-§3` (English-only; routing SHOULD met in part) | 2026-08-05 | `WG-R-06` | Confirmed. No `locales/<X>.lua` exists, so the trigger has not fired. |
| `events-frames-taint-§8` (pre-formatting; two unreachable `pout` fallbacks) | 2026-08-05 | `WG-A-08` | Confirmed. Absorbs the former `WG-37`. The zero-hit protected-API sweep still returns zero. |
| `standalone-windows-§33` (footer **Close** carries no mark) | 2026-08-25 | user decision on screenshot | Confirmed **as a decision**, but its *Rule* cell is unciteable — see **WG-52**. |

Also checked and **not** filed: no register row cites a rule the standard has since changed in a way
that would make the recorded behavior now mandated or permitted. `performance-§12`, `localization-§3`
and `events-frames-taint-§8` all read in v2.38.0 as the rows describe them.

---

## Low

### WG-46 — six tracked files disagree with the declared CRLF pin
**Section:** `line-endings-§1`, `line-endings-§7` (**MUST**) · **Where:** working tree, whole repo · *new*

`.gitattributes` is correct — present, `* text=auto eol=crlf`, `*.sh text eol=lf`, 20 binaries
marked — but the tree has not been renormalized against it. The `AUDIT.md` (e) one-liner, run
verbatim, reports **6**. Reported as **one** rolled-up finding, not enumerated: the fix is a single
action. **Fix:** `git add --renormalize .`, then delete and re-check-out the six so the working tree
follows, then commit.

### WG-47 — four load-bearing TOC positions carry no annotation, and three groups carry no conventional note
**Section:** `toc-file-§5` (**MUST** for the load-bearing half; **SHOULD** for the conventional half) · **Where:** `WhatGroup.toc:44,46-47,53-56` · *new*

The `# Core` block annotates three slots well (`:30-31`, `:33-34`, `:38-40`), which is what makes the
unannotated ones read as understood rather than unexamined. Four positions resolve **at file scope**
and say nothing:

- `core\DebugLogSetup.lua` (`:44`) must follow `core\WhatGroup.lua` — `lib:New{}` runs at file scope
  (`core/DebugLogSetup.lua:120`) and reads `NS.FONT_MONO`, which `core/WhatGroup.lua:115` assigns at
  load; the library validates `font` as a string at `:New` time, so above it the console gets `nil`.
- `defaults\Profile.lua` (`:47`) must precede `settings\Schema.lua` — `Schema.lua:27` takes
  `local C = NS.C` at file scope and every `add{}` dereferences it at load.
- `settings\OptionsSetup.lua` (`:55`) must precede `settings\Panel.lua` — `Panel.lua:204` calls
  `Helpers.MasterControls{…}` at file scope, and that member does not exist until `OptionsSetup` has
  moved the table onto the library instance. `Panel.lua:193-195` says so in a code comment; the TOC
  does not.
- `settings\Schema.lua` (`:54`) must precede `settings\Panel.lua` — `Panel.lua:262-264` splices into
  `Settings.Schema` at file scope.

Separately, `# Defaults`, `# Modules` and `# Settings` carry no *conventional* note, so every line in
them is ambiguous between "free to move" and "not yet understood" — the SHOULD half.

Low because nothing is broken today: the order is correct. The exposure is anti-pattern #66 — a
future reorder past a comment that was never written. **Fix:** one comment per load-bearing line
naming what resolves there, plus one *conventional* line per remaining group.

### WG-48 — the automated-test record is two runs behind the code, and its standing prose is three
**Section:** `automated-tests-§1`, `automated-tests-§4` (**MUST**), anti-pattern #51 · **Where:** `docs/automated-tests/RESULTS.md:23,47,72,98,109,126` · *new*

The newest bundle is `20260825-103505` (2026-08-25). Measured today against HEAD `ce572a3`
(2026-09-03): tests **528** vs the record's `485/485`, `luacheck` **16** files (matches), `lizard`
NLOC **7047** / **1004** functions vs the recorded **6377** / **906**. Nothing crossed a threshold —
`lizard` still reports zero warnings and the CCN ceiling is unchanged — so the **drift is size, not
risk**, but the record no longer describes the tree.

Worse, all four standing sections (`:47`, `:72`, `:98`, `:126`) still open *"Current state as of
`20260807-121935`"* — one run **behind the newest row in their own table**. And `:109` cites
`modules/Frame.lua:146` for the cooldown ticker, which was true at `b1511f6` and is `:275` today
(the register and `docs/performance.md` both cite `:275` correctly, so this is the only stale
citation in the repo).

**This is a finding about the release process, not about gating commits.** The checkpoint is
release, no release has been cut since 1.3.0, and `automated-tests-§6` does not require a bundle per
commit. What it does require is that the record not read as measured when it is not. **Fix:** run
`tests/_kit/run-automated-tests.sh` and roll the four standing sections forward with it; re-anchor
the `:146` citation.

#### WG-49 — two run bundles carry no `ANALYSIS.md` · *derived from WG-48*
**Section:** `automated-tests-§5` (**SHOULD** — neither run has `"release": null` set otherwise) · **Where:** `docs/automated-tests/20260807-110421/`, `docs/automated-tests/20260825-103505/`

Seven of nine bundles have one. Both manifests carry `"release": null`, so this is the SHOULD and
not the MUST. Stays a dependent: it closes in the same act as WG-48 (write the analysis with the
refreshed run) and is not independently reachable. **Fix:** write the two write-ups, or state in
`RESULTS.md` that an exploratory run does not get one.

### WG-50 — the `tests` column and the manifest fold skips into the pass count
**Section:** `automated-tests-§4` (**MUST**) · **Where:** `docs/automated-tests/RESULTS.md:23`, `docs/automated-tests/20260825-103505/manifest.json` · **Scope: libka0s-upstream** · *new*

§4 requires the tests column to carry **passed / skipped / total** and **MUST NOT** fold a skip into
either. The row reads `485/485`, and the manifest's `tests` object carries `passed`, `failed` and
`total` with no `skipped` key. That matters precisely here: `tests/test_vendor_sync.lua` **skips**
when the sibling `../LibKa0s` checkout is absent, so a machine without it produces a row claiming
coverage that never ran.

Both artifacts are runner-generated and `testing-§1` forbids editing the vendored kit, so this
repo cannot fix it. **Fix:** raise on `LibKa0s`; adopt on the next re-vendor.

### WG-51 — the vendored-payload gate does not assert the runner's recorded mode
**Section:** `automated-tests-§2` (**MUST**) · **Where:** `tests/_kit/vendor_sync.lua` (no `100755` assertion), `tests/test_vendor_sync.lua:23` · **Scope: libka0s-upstream** · *new*

§2 makes it a MUST that the consumer-side gate assert `run-automated-tests.sh` is recorded as
`100755` — the one property no amount of reading the working tree can confirm, because every repo
here sits on DrvFs with `core.fileMode=false`. `grep -n '100755\|ls-files\|executable'` over the kit
module returns nothing.

**This repo's mode is correct today** (`git ls-files -s` → `100755`), so the impact is a missing
guard rather than a broken file. Kit-owned; not fixable here. **Fix:** raise on `LibKa0s`.

### WG-52 — a register row cites `standalone-windows-§33`, which does not exist
**Section:** `documentation-§3` (**MUST** — *Rule is a `filename-§N` reference into this standard*), `audit-review-history` · **Where:** `docs/ARCHITECTURE.md:352` · *new*

`standards/standards/standalone-windows.md` carries **one** subsection heading (*The Ka0s window
edge*) and **no numbered `§N` subsections at all**, so `§33` resolves to nothing. Under
`documentation-§5/§6` a section with no numbered subsections is referenced by **bare filename**. The
rule the row means — *a wide action button keeps its label and gains a mark beside it (SHOULD)* — is
real and the decision behind the row is sound; only the citation is uncheckable, which is exactly
what §3 says a Rule cell must not be ("not a paraphrase, because a paraphrase cannot be checked
against the rule it claims to deviate from").

**Fix:** change the Rule cell to `standalone-windows` and quote the SHOULD's opening clause in
*What differs* so the row stays checkable.

### WG-53 — `compat-layer.md`'s *Not applicable* row asserts something false
**Section:** `documentation-§3`, Tier 2 (**MUST**) · **Where:** `docs/ARCHITECTURE.md:316`, `core/Compat.lua:24,40,52,62,83,105,125` · *new*

The trigger is *"`core/Compat.lua` carries **addon-specific** shims beyond what `LibKa0s` supplies"*.
It has fired: `core/Compat.lua` defines **seven** shims — `GetSpellName`, `GetSpellTexture`,
`GetSpellLink`, `IsSpellKnown`, `GetSpellCooldownRemaining`, `GetSpellCooldownTimes`,
`GetActivityInfoTable` — and LibKa0s ships no Compat major at all (`libs/LibKa0s/LibKa0s.xml` lists
Core, Env, Pool, Item, Media, Widgets, DebugLog, Slash, Options×3, Perf×2). The row nonetheless
reads *"no addon-specific shim to document separately"*.

This is the **aggravated** shape `AUDIT.md` step 4(b) names: an absent doc with a fired trigger *and*
a row asserting it is inapplicable is worse than the bare omission, because the row is what stops
anyone looking again. Graded Low on impact — no user reaches a doc — while failing the MUST.
**Fix:** write `docs/compat-layer.md` (the seven shims, the variant API each wraps, and the
degrade-to-nil contract the file header already states) and change the row to *Present*.

### WG-54 — British spellings in authored English
**Section:** `localization-§5` (**MUST**), anti-pattern #46 · **Where:** 20 sites, three scopes · *new*

Twenty hits for `colour|grey|behaviour|centre|cancelled`, all in comments, prose and one test-case
name — **none** in a locale key, a locale value or any player-facing string, which is what holds
this to Low:

- **shipped source, 3** — `modules/Frame.lua:267` (`grey`), `settings/Schema.lua:115`
  (`behaviour`), `settings/OptionsSetup.lua:92` (`colour`);
- **live `docs/`, 8** — `ARCHITECTURE.md:159,349`, `common-tasks.md:131`, `frame.md:95,97`,
  `performance.md:40`, `settings-panel.md:329`, `test-cases.md:225`;
- **`tests/` (excluding `_kit/`), 9** — including `tests/test_settings.lua:676`, whose case **name**
  carries `colour` and therefore reproduces into generated `docs/test-cases.md:225`.

Scope swept and excluded: `libs/`, `tests/_kit/`, `docs/audits/`, `docs/reviews/`,
`docs/superpowers/`, `docs/automated-tests/`, `docs/revendor/` — frozen or not this repo's to fix.
**Fix:** one sweep; regenerate `docs/test-cases.md` after renaming the test case.

### WG-55 — the top `## Version History` row and `## What's new` disagree about a tab name
**Section:** `documentation-§1` item 5 (**MUST** — *"the two MUST agree"*) · **Where:** `README.md:21` vs `README.md:121` · *new*

`:21` — *"Prefer a short pause? Set a delay under **Chat**."*
`:121` — *"…(add a delay under Notify if you prefer)."*

`Chat` is correct: `settings/Schema.lua:149` files `notify.delay` under `group = "Chat"`. `Notify`
was the tab's name before the retabbing and no longer exists on the strip, so the Version History row
sends a player to a tab that is not there. **Fix:** correct `:121` to `Chat`.

### WG-56 — the README's `### Settings panel` table is at tab granularity
**Section:** `documentation-§1` item 7 (**MUST**) · **Where:** `README.md:69-73` · **Scope: likely-cross-cutting** · *new*

§1 item 7 is explicit that this table is *"one row per settings subcategory… stays at page
granularity"* and that *"the per-tab breakdown that `options-ui-§13`'s strip makes derivable belongs
in `docs/settings-panel.md`, not here."* The README draws three rows — Master controls, Chat, Popup —
which are the General page's **tabs**, and follows them with three paragraphs of per-tab prose. The
addon has exactly one subcategory, so the page-granular table is one row.

Noted honestly: the column header §1 mandates is literally `Tab | Covers`, which reads against the
sentence beside it, and any addon that adopted the strip and then updated its README will have landed
here the same way. **Fix (or upstream):** collapse to one row per page and move the tab breakdown to
`docs/settings-panel.md:319-329`, which already carries it — or take the ambiguity upstream.

### WG-57 — the `## Message Bus` rationale answers only half of `architecture-§4`'s applicability condition
**Section:** `architecture-§4` (**MUST**) · **Where:** `docs/ARCHITECTURE.md:105-112`, `modules/Frame.lua:318,635` · *new*

§4's condition is *"two or more feature modules, **or any module that registers game events**"*, and
the section says crossing it *"is a real event, not a formality"*. `modules/Frame.lua` — the addon's
one feature module — registers `PLAYER_REGEN_ENABLED` twice (`:318` on the combat-blocked
secure-attribute path, `:635` on the deferred popup build). The recorded rationale addresses only
the first half (*"a single-addon capture pipeline with no cross-module publish/subscribe need"*) and
never mentions the second trigger.

Low, and deliberately so: the hazard §4 exists for — CallbackHandler's same-target clobber — cannot
arise with one receiver, so nothing is reachable today. But the *record* does not say why the fired
trigger does not bind, which is the whole job of that section under §4. **Fix:** extend the
`## Message Bus` paragraph to name both registrations and state the position — that a raw
`CreateFrame` event registration on the addon's only feature module is not the second party §4's
threshold is about — or, if that reading is wrong, take it upstream as a wording question.

### WG-58 — `.pkgmeta` accounts for neither `.superpowers` nor `.pkgmeta`
**Section:** `packaging` (**MUST**, both the named list and the strong form) · **Where:** `.pkgmeta:6-19` · *new*

`packaging` names `.superpowers` explicitly on the must-ignore list, *"named here rather than left to
the reader's judgment because the judgment call was made wrong five times"*. It is absent. It also
makes the strong form a MUST — every root dot-entry present in the repo either appears in `ignore:`
or is justified in a comment beside it — and the (b) enumeration reports `.pkgmeta` itself
unaccounted (`.git` is the one exemption).

Low: `.superpowers/` does not exist in this repo today, so nothing ships that should not; the failure
is the missing guard against the day a tool creates it. **Fix:** add `.superpowers` to the list and
either add `.pkgmeta` or a one-line comment saying the packager consumes and drops it.

---

## Info

### WG-59 — `.luacheckrc` omits `_dev/` from `exclude_files`
**Section:** `lint` (template; not stated as a MUST) · **Where:** `.luacheckrc:9` · *new*

The section's template excludes `{ "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/" }`;
this file has all but `_dev/`. `.pkgmeta:12` already reserves `_dev` as the scratch directory
*"whether or not it exists today"*, so the two config files disagree about a path one of them expects
to appear. **Fix:** add `"_dev/"`.

### WG-60 — the documentation map uses four tables, and does not cover the hub itself
**Section:** `documentation-§3` · **Where:** `docs/ARCHITECTURE.md:292-335` · **Scope: standards-upstream** · *new*

`documentation-§3` specifies **three** tables and says *"every `.md` under `docs/` appears in exactly
one of its three tables"*. It separately requires five **verification-and-record** docs that it says
belong to *"the testing and automated-test rules rather than by this section's tier model"* — and
never says which table holds them. This repo answered by adding a fourth, `### Verification and
record` (`:320`), which is coverage-complete, dangling-free and arguably the clearest reading; and it
leaves `ARCHITECTURE.md` itself, a `.md` under `docs/`, in no table at all.

Filed as Info against the **standard's text**, not the repo: there is no reading of §3 under which
both sentences can be satisfied. **Fix (upstream):** name a fourth table for the
verification-and-record five, or place them in a tier, and say whether the hub registers itself.

---

## Recorded as compliant, not as omissions

Measured and passing, so no row: `layout` (all three), `toc-file-§1`/`§2`/`§3`/`§4`,
`library-stack` (whole-folder vendoring, zero drift at v1.25.0, shared media consumed not
duplicated, one `MakeCloseButton` wrapper), `architecture-§1`/`§2`/`§3`/`§5`/`§6`/`§7`,
`savedvariables` (all five), `options-ui` (§1–§18 — including §12's one act and verbatim wording,
§13's strip on every non-exempt page, §14's single unboxed chrome block, §15's composed
`Master controls` first tab, and §16/§17/§18 which do not engage: no font/border/bar group, no color
row, no reorder list), `standalone-windows`, `slash-commands`, `debug-logging`, `compat`,
`events-frames-taint` (§1–§7; §8 is the recorded row), `localization-§1`/`§2`/`§4` (§3 is the
recorded row), `preview-mode` (not engaged), `public-api` (not engaged), `lint` (0/0), `testing`
(§1–§14, including §11's vendored-payload gate green and §12's falsifiability — the 2026-08-05
`WG-44` case is fixed and `tests/test_capture.lua:83` pins the real gate), `automated-tests-§3`
(gates and manifest `gates` object correct), `performance-§1`–`§11` (nothing bracketed; §12 is the
recorded row), `packaging` apart from WG-58, `versioning-git`, `documentation-§2`/`§4`/`§6`/`§7`,
`naming-cheatsheet`, `line-endings-§2`–`§6`, and the anti-pattern list apart from #46 (WG-54), #51
(WG-48) and #66's precondition (WG-47) — notably **#47, #48, #45, #49, #58, #59, #60, #62, #63,
#64, #65, #68–#75 all clear**.
