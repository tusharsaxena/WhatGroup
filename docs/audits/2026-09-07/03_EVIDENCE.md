# 03 — Evidence (2026-09-07)

Every command below was **run on this machine, today**, from
`/mnt/d/Profile/Users/Tushar/Documents/GIT/WhatGroup`, and its **real** output is pasted. Every
`file:line` was re-read and the cited text is quoted beside it. No number in this bundle is retyped
from an earlier run or from memory.

---

## Part 1 — Mechanical checks

### 1.1 Lint

```
$ luacheck .
Total: 0 warnings / 0 errors in 16 files
```

**Scope:** `.luacheckrc:9` sets `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "tests/" }`,
so the 16 files are the addon's shipped source only. `libs/` (vendored), the frozen audit and review
bundles, and the whole `tests/` tree (22 files) are **outside** this gate. That is a standing fact
about the config, not this run's news.

### 1.2 Headless suite

```
$ lua tests/run.lua
…
  PASS  libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
  PASS  tests/_kit is the test kit that shipped with that release

528 passed, 0 failed, 0 skipped, 528 total
```

**Scope:** all 15 `tests/test_*.lua` suites plus the harness. The two vendored-payload cases
**passed** rather than skipped, because `../LibKa0s` is present on this machine.

`docs/test-cases.md:609` — `| **Total** | **528** |` — agrees, and so does `README.md:7`
(`Tests-528%2F528_passing`).

### 1.3 Complexity — the standard's invocation, verbatim

```
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
      7047       6.4     1.8       47.0     1004            0      0.00    0.00
```

`lizard` is installed (`/home/tushar/.local/bin/lizard`). The invocation is the section's exact
string — no extra flag, no narrowed path, no re-tuned threshold.

**Drift against the latest committed bundle** (`docs/automated-tests/20260825-103505/complexity.txt`,
last 6 lines):

```
      6377       6.4     1.7       46.7      906            0      0.00    0.00
```

| Metric | Recorded 2026-08-25 | Measured today | Drift |
|---|---|---|---|
| NLOC | 6377 | **7047** | +670 |
| Functions | 906 | **1004** | +98 |
| Avg CCN | 1.7 | **1.8** | +0.1 |
| Warnings | 0 | **0** | — |
| Files in `layout-§1` band | 0 | **0** | — |

**Nothing crossed a threshold** and no file entered the 1000–1500 LOC band (largest addon file:
`core/WhatGroup.lua`, 787 lines). The drift is size, from the settings-revamp merge `ce572a3`
(2026-09-03), which the 2026-08-25 bundle predates by 9 days. Evidence for **WG-48**.

### 1.4 Watch list read as a decision record

`docs/automated-tests/RESULTS.md:134`:

> `| *(none)* | — | — | No function in the addon is above CCN 15. |`

**Zero entries, and therefore zero carrying an *Accepted* disposition.** `git log --oneline --
docs/automated-tests/RESULTS.md` shows the list has never renewed an *Accepted*: every entry it has
ever held — three at the `20260804-182231` baseline and `ConfigureTeleportButton` at CCN 20 — was
retired by splitting the function. Anti-pattern #53's three-consecutive-release-runs clock has never
started. **No finding.**

`RESULTS.md:167-169` records the addon's ceiling as `WhatGroup@634-697@core/WhatGroup.lua` at
**CCN 15** — at the release-gate cap, not over it. That location has moved with the tree: today's
run reports the same function as `WhatGroup@675-738@core/WhatGroup.lua`, **still CCN 15**, and
`core/WhatGroup.lua:675` reads
`function WhatGroup:LFG_LIST_APPLICATION_STATUS_UPDATED(event, appID, newStatus)` — one event
handler doing one job. Its CCN is **genuine control flow** (status branches plus the
queued-vs-fresh selection), not `and`/`or` defaulting, so the standard's Lua caveat does not soften
it. The moved line is further evidence for **WG-48**; the *number* is unchanged, which is why no
watch-list entry is owed.

**Complexity-refactor audit (`performance-§11`).** The one refactor in the record, `b1511f6`
(*split ConfigureTeleportButton, CCN 20 → 6*), produces five **named** functions —
`deferTeleportUntilCombatEnds`, `resolveTeleportState`, `applyTeleportNote`, `applyTeleportAction` —
not a `part2`/`doTheRest` dump (#52 clear); introduces no in-function dispatch or defaults table
(#43 clear); and needed **no** test change, which `RESULTS.md:53-58` demonstrates by the
byte-identical `test-cases.md` (testing-§13 satisfied by prior coverage). A repo-wide grep for
`or C.` / `or NS.C.` / `or D.` over `core/ defaults/ modules/ settings/` returns **nothing**, so #54
was not introduced.

### 1.5 Line endings

```
$ test -f .gitattributes || echo "MISSING"          # (a)  → present
$ grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes    # (b)
26:* text=auto eol=crlf
$ grep -n '^\*\.sh text eol=lf$' .gitattributes     # (c)
34:*.sh text eol=lf
$ grep -c ' binary$' .gitattributes                 # (d)
20
```

(b) is the correct pin for the repo's **kind**: `WhatGroup.toc` exists, so it is client-bound and
pins CRLF. This is not the `line-endings-§1` near-miss — the pin is present *above* the `*.sh`
carve-out, not instead of it.

(e), the `AUDIT.md` one-liner run **verbatim** (asks git for `text` as well as `eol`, counts bytes):

```
$ git ls-files -z | xargs -0 -I{} sh -c '
    set -- $(git check-attr text eol -- "{}" | sed "s/.*: //")
    [ "$1" = unset ] && exit
    cr=$(tr -dc "\r" < "{}" | wc -c); lf=$(tr -dc "\n" < "{}" | wc -c)
    case "$2" in crlf) [ "$lf" -gt 0 ] && [ "$cr" -ne "$lf" ] && echo "{}";;
                 lf)   [ "$cr" -gt 0 ] && echo "{}";; esac' 2>/dev/null | wc -l
6
```

**6.** Scope: every tracked file in the repo; binaries skipped by the `text=unset` guard, so the 20
marked types and the six image assets do not inflate it. Reported as one rolled-up finding
(**WG-46**) and deliberately not enumerated — the fix is `git add --renormalize .` plus a
re-checkout, one action. Expect this to be **far lower** than any pre-v2.28.1 bundle reported for
this repo; those bundles are frozen and are not edited to reconcile.

### 1.6 Packaging — dot-entry sweep

```
$ for e in .luacheckrc .gitignore .gitattributes .claude .superpowers docs tests _dev; do
    grep -q "^  - $e\b" .pkgmeta || echo "NOT IGNORED — $e"; done
NOT IGNORED — .superpowers

$ for e in .[!.]*; do [ -e "$e" ] || continue
    grep -q "^  - $e\b" .pkgmeta || echo "UNACCOUNTED — $e"; done
UNACCOUNTED — .git
UNACCOUNTED — .pkgmeta
```

`.git` is the one entry the packager never sees and needs no row. `.superpowers` and `.pkgmeta` are
**WG-58**. `.pkgmeta:6-19` is the ignore list as it stands; there is no `externals:` block anywhere
in the file.

### 1.7 Vendored Ka0s-owned library — both diffs

Provenance, read from the file the gate reads:

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md
69:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.25.0 (MIT). That line is the
$ grep -n 'Bundles \[LibKa0s\]' README.md
                                                    (no output)
$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md
                                                    (no output)
$ grep -n 'WoW_Addon_Standard' README.md
6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
```

The badge is the **bare** `![Standard](…)`, not wrapped in a link. Anti-patterns #58 and #59 are
clear, and `documentation-§1`'s badge MUST NOT is met.

Diffed against the **tag `CLAUDE.md` names**, not the sibling's `HEAD` (which happens to be the same
commit — `v1.25.0` is the newest tag — but the tag is what was checked out):

```
$ git -C ../LibKa0s archive v1.25.0 | tar -x -C $T
$ diff -r $T/LibKa0s     ./libs/LibKa0s   ; echo "exit=$?"
exit=0
$ diff -r $T/testkit     ./tests/_kit     ; echo "exit=$?"
exit=0
```

**Both empty.** No anti-pattern #45 drift and no #48 partial vendoring: the ship folder is whole
(Core, DebugLog, Env, Item, LICENSE, LibKa0s.xml, Media, Options, OptionsCompose, OptionsScroll,
OptionsWidgets, Perf, PerfPanel, Pool, Slash, Widgets, `media/`), the TOC lists the aggregate
`libs\LibKa0s\LibKa0s.xml` **once** (`WhatGroup.toc:25`) and no individual module `.lua`, and the
harness sits under `tests/_kit/`, never `libs/`.

```
$ git ls-files -s tests/_kit/run-automated-tests.sh
100755 c35d423… 0	tests/_kit/run-automated-tests.sh
```

Recorded executable, as `automated-tests-§2` requires. The **assertion** of that fact is missing from
the gate — **WG-51**:

```
$ grep -n '100755\|ls-files\|executable' tests/_kit/vendor_sync.lua
                                                    (no output)
```

### 1.8 The recorded-deviation register and the issue store

```
$ gh issue list --state all --limit 200 --json number,title,state,labels
14|CLOSED|state:will-not-do severity:low |LibKa0s-Pool-1.0: declined — a one-shot singleton window with a fixed field set
13|CLOSED|state:will-not-do severity:low |LibKa0s-Item-1.0: declined — LFG metadata and spell IDs, no items
12|CLOSED|state:will-not-do severity:low |LibKa0s-Widgets-1.0: declined — no control in this addon wants it
11|CLOSED|state:will-not-do severity:low |LIBKA0S-05: DebugLog console window position not persisted (library gap)
10|CLOSED|state:will-not-do severity:low |LIBKA0S-08: global reset stays host-owned as Helpers.RestoreAllDefaults
 9|CLOSED|state:will-not-do severity:low |LIBKA0S-09: Helpers.InlineButton stays host-owned
 8|CLOSED|state:done        severity:low |LIBKA0S-13: Slash convergence #1 adopted — /wg reset resets one row by path
 7|CLOSED|state:will-not-do severity:low |LIBKA0S-15: Perf declined — ratified in ARCHITECTURE Documented deviations
 6|CLOSED|state:done        severity:low |PLAN-02: audit 2026-07-18 · WG-28
 5|CLOSED|state:will-not-do severity:low |Add an `X-Wago-ID` to `WhatGroup.toc` or ratify a Curse-only deviation
 4|OPEN  |state:triaged     severity:low |Source the Uldaman mapID in defaults/TeleportSpells.lua
 3|CLOSED|enhancement state:done severity:medium |WG Config Panel Not Available On Load
 2|OPEN  |state:triaged  severity:medium |Validate the MapIDs and SpellIDs
 1|OPEN  |state:triaged     severity:low |Add role to the pop
```

Every issue carries a `state:` label and a `severity:` label. **No `[status]` title prefix** —
anti-pattern #62 clear. No `docs/pending/` directory and no `LEDGER.md` — anti-pattern #60 clear
(`find` over the repo returns neither).

**The inverse rule — a decline recorded only as an issue, with no register row.** Eight issues are
`state:will-not-do`. Seven of them decline something the standard makes **optional**, so no register
row is owed and none is a finding:

- #14, #13, #12 decline **LibKa0s modules** (`Pool`, `Item`, `Widgets`). `library-stack-§7` makes
  wiring a module a per-addon choice; a module vendored-and-unwired is not a deviation.
- #11, #10, #9 are **library gaps / ownership calls**, not rule declines.
- #5 declines `X-Wago-ID`, which `toc-file-§1` states is a **MAY**: *"`X-Wago-ID` and `X-WoWI-ID` are
  **optional** (**MAY**) — include each only when the addon is actually listed on that platform."*

The eighth, **#7 (Perf declined)**, *is* in the register, twice, at `docs/ARCHITECTURE.md:348` and
`:349`, and the Why cells cite it by number. So the missing-row case does **not** arise here.

Register rows re-read verbatim today:

- `docs/ARCHITECTURE.md:348` — Rule cell `` `performance-§12` ``; Re-check trigger reads
  *"**FIRED 2026-08-06** — the cooldown countdown ticker (`modules/Frame.lua:275`) is a repeating
  ticker."*
- `docs/ARCHITECTURE.md:349` — Rule cell `` `performance-§12` (re-check fired) ``; Decided
  `2026-08-06`; two stated triggers, neither fired (see §2.6 below).
- `docs/ARCHITECTURE.md:350` — `` `localization-§3` ``, Decided `2026-08-05`, trigger *"the first
  non-English locale file"* — `ls locales/` shows only `enUS.lua`, so unfired.
- `docs/ARCHITECTURE.md:351` — `` `events-frames-taint-§8` ``, Decided `2026-08-05`.
- `docs/ARCHITECTURE.md:352` — `` `standalone-windows-§33` `` — **the citation does not resolve**,
  evidence for **WG-52** (§2.4 below).

**No register row cites a rule the standard has since changed** such that the behavior is now
mandated or permitted: `performance-§12`, `localization-§3` and `events-frames-taint-§8` all read in
v2.38.0 as their rows describe them, and `standalone-windows`'s wide-action-button rule is still a
SHOULD.

### 1.9 The close-button grep (`standalone-windows`, MUST)

```
$ grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'
core/CoreSetup.lua:100:    function NS.MakeCloseButton() return nil end
core/CoreSetup.lua:136:    return lib.MakeCloseButton(parent, onClick, addonName)
```

Two lines, and both are the sanctioned shapes: `:136` is the **one** wrapper in the
`LibKa0s-Core-1.0` setup file supplying `addonName` from the file's own first vararg, and `:100` is
its degraded twin. There is no direct two-argument `lib.MakeCloseButton(…)`, no
`Core.MakeCloseButton(…)`, and no `NS.DebugLog.MakeCloseButton(…)` in a decoration hook. Anti-pattern
#65 clear. There is also **no perf panel and therefore no `decorate` hook** — the addon does not wire
`LibKa0s-Perf-1.0`.

### 1.10 Shared media — private copy and one-off mark sweeps

```
$ ls -R media
media:      logos  screenshots
media/logos:        whatgroup.logo.jpg  whatgroup.logo.png  whatgroup.logo.tga
media/screenshots:  whatgroup.screenshot.01.png … .03.png
```

No `fonts/`, no `icons/`, no `textures/` — nothing that also exists under `libs/LibKa0s/media/`.
What remains is the logo and the screenshots, which is exactly what `library-stack-§8` says
legitimately stays. Anti-pattern #63 clear.

```
$ grep -rn 'SetAtlas\|Interface\\\\' --include='*.lua' core/ modules/ settings/ defaults/ locales/
core/CoreSetup.lua:94:            bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
settings/Panel.lua:87:local MAIN_LOGO_TEXTURE   = "Interface\\AddOns\\WhatGroup\\media\\logos\\whatgroup.logo.tga"
```

`:94` is the degraded-branch backdrop (the shipped white pixel, not a mark); `:87` is the addon's own
logo. Neither is a one-off where the catalog has an entry. No `SetAtlas` anywhere.

Seam fed the **folder** name, once:

- `core/MediaSetup.lua:49` — `local Media = LibStub and LibStub("LibKa0s-Media-1.0", true)`
- `core/MediaSetup.lua:92` — `if Media then Media.RegisterLSM(addonName) end`

`addonName` is the file's own first vararg (`core/MediaSetup.lua:47`), not a frame-name prefix, a
hand-typed constant or the DebugLog descriptor's `name`. The console is told too:
`core/DebugLogSetup.lua:133` — `addonName = addonName,` — which `debug-logging-§13` requires.

---

## Part 2 — Evidence per deviation

### 2.1 WG-46 — line-ending stragglers

Command and count in §1.5. One number, one action.

### 2.2 WG-47 — unannotated load-bearing TOC positions

TOC lines, re-read:

- `WhatGroup.toc:44` — `core\DebugLogSetup.lua` (no comment above it)
- `WhatGroup.toc:47` — `defaults\Profile.lua`
- `WhatGroup.toc:53` — `# Settings` (no conventional/load-bearing note)
- `WhatGroup.toc:54` — `settings\Schema.lua`
- `WhatGroup.toc:55` — `settings\OptionsSetup.lua`
- `WhatGroup.toc:56` — `settings\Panel.lua`

What resolves at load, quoted:

- `core/DebugLogSetup.lua:120` — `NS.DebugLog = lib:New({` — **file scope**, and
  `core/DebugLogSetup.lua:139` — `    font  = resolveConsoleFont(NS.FONT_MONO),` — reads a value
  assigned at `core/WhatGroup.lua:115`:
  `NS.FONT_MONO = NS.MediaFont and NS.MediaFont(NS.FONT_MONO_NAME) or _G.STANDARD_TEXT_FONT`.
- `settings/Schema.lua:27` — `local C         = NS.C` — file scope; `settings/Schema.lua:149`
  (`section = "notify",  group = "Chat",  subgroup = "Timing",`) is inside an `add{}` executed at
  load whose `default = C.notify.delay` dereferences it.
- `settings/Panel.lua:204` — `local MASTER_ROWS, MASTER_TAIL = Helpers.MasterControls{` — file
  scope. The addon's own comment at `settings/Panel.lua:193-195` states the dependency:
  *"the composer is a member of the LibKa0s instance, and the instance does not exist until
  settings/OptionsSetup.lua has run — which is the file immediately before this one in the TOC."*
  That reason lives in the Lua file; `toc-file-§5` requires it at the TOC line.
- `settings/Panel.lua:262` — `for i = #MASTER_ROWS, 1, -1 do` … `:264` — `end` — splices into
  `Settings.Schema` at file scope, which `settings/Schema.lua` must already have created.

Contrast, for the SHOULD half: `WhatGroup.toc:30-31`, `:33-34` and `:38-40` do carry the annotation,
in the right vocabulary — `:34` reads *"so this slot is load-bearing, not conventional"* and `:40`
*"so this slot is conventional, not load-bearing"*.

### 2.3 WG-48 / WG-49 — the automated-test record

Drift table in §1.3. The stale standing sections, quoted:

- `docs/automated-tests/RESULTS.md:23` —
  `| [\`20260825-103505\`](20260825-103505/) | 1.3.0 | 0/0 | 16 | 485/485 | skip | 6377 | 906 | 6.4 | 1.7 | 15 | 0 | **green** |`
- `:47` — *"Current state as of [`20260807-121935`](20260807-121935/): **462 cases**…"*
- `:72` — *"Current state as of [`20260807-121935`]…: clean over **14 files**…"*
- `:98` — *"Current state as of [`20260807-121935`]…: **skip — zero scenarios**…"*
- `:126` — *"Current state as of [`20260807-121935`] — not that run's diff."*
- `:109` — *"`b1511f6` moved that ticker from `modules/Frame.lua:327` to `:146`…"*

That last citation is verifiably stale: `git show b1511f6:modules/Frame.lua | grep -n
ScheduleRepeatingTimer` → `146:`, but today `grep -n ScheduleRepeatingTimer modules/Frame.lua` →
`275:        cooldownTimer = WhatGroup:ScheduleRepeatingTimer(function()`.

Bundles missing `ANALYSIS.md` (WG-49), by listing:

```
$ for d in docs/automated-tests/2026*/; do [ -f "$d/ANALYSIS.md" ] || echo "$d"; done
docs/automated-tests/20260807-110421/
docs/automated-tests/20260825-103505/
```

Both manifests carry `"release": null`, which is why this is the SHOULD and not the MUST.

### 2.4 WG-52 — the unciteable Rule cell

`docs/ARCHITECTURE.md:352` opens:

> `| `standalone-windows-§33` | The popup's footer **Close** button (`modules/Frame.lua`, `UIPanelButtonTemplate`, 90×24) carries **no mark beside its label** …`

Against the fetched section file:

```
$ grep -c '^### ' standards/standards/standalone-windows.md
1
$ grep -n '§' standards/standards/standalone-windows.md | head -1
1:> Part of the **[Ka0s WoW Addon Standard](../STANDARDS.md)** … Cross-references use the `filename-§N` form
```

The file's single `###` is *The Ka0s window edge*; there is no `§33`, and no numbered subsection at
all. `documentation-§5/§6` and `AUDIT.md` step 5 both say such a section is referenced by **bare
filename**.

### 2.5 WG-53 — a fired Tier 2 trigger under a *Not applicable* row

The row, re-read at `docs/ARCHITECTURE.md:316`:

> `| \`compat-layer.md\` | Not applicable | \`core/Compat.lua\` normalizes LFG and unit APIs with no addon-specific shim to document separately |`

The trigger, evaluated **against the code**:

```
$ grep -n '^function Compat\.' core/Compat.lua
24:function Compat.GetSpellName(spellID)
40:function Compat.GetSpellTexture(spellID)
52:function Compat.GetSpellLink(spellID)
62:function Compat.IsSpellKnown(spellID)
83:function Compat.GetSpellCooldownRemaining(spellID)
105:function Compat.GetSpellCooldownTimes(spellID)
125:function Compat.GetActivityInfoTable(activityID)
```

Seven shims. And LibKa0s supplies none of them — the ship folder holds no Compat major:

```
$ ls libs/LibKa0s
Core.lua  DebugLog.lua  Env.lua  Item.lua  LICENSE  LibKa0s.xml  Media.lua
Options.lua  OptionsCompose.lua  OptionsScroll.lua  OptionsWidgets.lua
Perf.lua  PerfPanel.lua  Pool.lua  Slash.lua  Widgets.lua  media
```

`core/Compat.lua:7-9` says the same in the addon's own words: *"Compat is the SOLE caller of the
variant APIs (C_Spell.\*, the global GetSpell\* fallbacks, IsSpellKnown,
C_LFGList.GetActivityInfoTable)."*

### 2.6 WG-57 — the fired second trigger of `architecture-§4`

```
$ grep -rn 'RegisterEvent' --include='*.lua' core/ modules/ settings/
core/WhatGroup.lua:186:    self:RegisterEvent("GROUP_ROSTER_UPDATE")
core/WhatGroup.lua:187:    self:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
modules/Frame.lua:318:    f:RegisterEvent("PLAYER_REGEN_ENABLED")
modules/Frame.lua:635:            waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
```

`modules/` is the feature-module folder and it holds one file, `Frame.lua`, which registers a game
event at two sites. The recorded rationale, `docs/ARCHITECTURE.md:107-108`:

> *"**There is none, because** WhatGroup is a single-addon capture pipeline with no cross-module
> publish/subscribe need…"*

— addresses the module-count half of the condition and not the event-registration half.

Also verified, so the finding stays where it is: the bus hazard itself cannot arise.
`grep -rn 'SendMessage\|RegisterMessage' core/ modules/ settings/ defaults/` returns **nothing**, so
there is no same-target clobber (anti-pattern #32) and no message to document.

### 2.7 WG-54 — British spellings, with the scope stated

```
$ grep -rniE 'colour|grey|behaviour|centre|cancelled' --include='*.lua' core/ defaults/ locales/ modules/ settings/ | wc -l
3
$ grep -rniE 'colour|grey|behaviour|centre|cancelled' docs/*.md | wc -l
8
$ grep -rniE 'colour|grey|behaviour|centre|cancelled' --include='*.lua' tests/ | grep -v 'tests/_kit' | wc -l
9
$ grep -rniE 'colour|grey|behaviour|centre|cancelled' README.md CLAUDE.md DEPENDENCIES.md | wc -l
0
```

**Swept:** the five shipped source folders, the live `docs/*.md` pages, `tests/` excluding the
vendored kit, and the three root docs. **Not swept, deliberately:** `libs/` and `tests/_kit/`
(vendored, not this repo's to fix) and `docs/audits/`, `docs/reviews/`, `docs/superpowers/`,
`docs/automated-tests/`, `docs/revendor/` (frozen bundles, never edited).

Cited sites, re-read:

- `modules/Frame.lua:267` — `-- explains the grey icon. A ready teleport needs no explanation…`
- `settings/Schema.lua:115` — `-- and so is a behaviour toggle above two size sliders.…`
- `settings/OptionsSetup.lua:92` — `-- colour block to compose -- and they are stubbed for…`
- `tests/test_settings.lua:676` — `test("settings: every colour row is followed by its class-colour companion, and none is disabled",`
- `docs/test-cases.md:225` — `- settings: every colour row is followed by its class-colour companion, and none is disabled`
  — the generated echo of the line above, which is why renaming the case is part of the fix.

Zero hits in `locales/enUS.lua`, and zero in any string the player reads.

### 2.8 WG-55 / WG-56 — README

- `README.md:21` — *"The chat message and popup now appear **instantly** when you join a group.
  Prefer a short pause? Set a delay under **Chat**."*
- `README.md:121` — *"| 1.3.0 | 2026-07-12 | … (add a delay under **Notify** if you prefer)…"*
- `settings/Schema.lua:149` — `    section = "notify",  group = "Chat",  subgroup = "Timing",`
  — the tab is `Chat`; `Notify` is not a tab on the strip.
- `README.md:69` — `| Tab | Covers |`, followed by three rows (`:71` Master controls, `:72` Chat,
  `:73` Popup) and three prose paragraphs. The addon registers **one** subcategory:
  `settings/Panel.lua:340` — `Helpers.RegisterOptionsPage("general", "General", buildGeneralPage)`.

### 2.9 WG-58 / WG-59 — config files

- `.pkgmeta:6-19` — the ignore list, quoted in §1.6's sweep. No `.superpowers` row; no `.pkgmeta`
  row and no comment justifying its absence.
- `.luacheckrc:9` — `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "tests/" }` —
  against `.pkgmeta:12` — `  - _dev        # the scratch dir packaging reserves; ignored whether or not it exists today`.

### 2.10 WG-60 — the documentation map's shape

`docs/ARCHITECTURE.md:292` — `## Documentation map`, and its table headings:
`:297` `### Required (documentation-§3, Tier 1)`, `:308` `### Conditional (documentation-§3, Tier 2)`,
`:320` `### Verification and record`, `:331` `### Addon-specific (documentation-§3, Tier 3)`.

Four tables where `documentation-§3` specifies three, and `ARCHITECTURE.md` itself appears in none of
them. Coverage is otherwise exact: every other `.md` under `docs/` appears once, and every row points
at a file that exists (checked by listing `docs/*.md` and `docs/automated-tests/{README,RESULTS}.md`
against the four tables — no orphan, no dangling row). Frozen directories are named once each and
never enumerated per run (`:294-295`).

---

## Part 3 — Compliance claims, sourced

These are the claims `02_DEVIATIONS.md`'s closing section makes. Each cites the descriptor or the
seam, never the library's own source.

| Claim | Evidence |
|---|---|
| Options toolkit consumed, not hand-rolled | `settings/OptionsSetup.lua` LibStub lookup + descriptor; no widget-maker or flow-engine file exists in the repo |
| Debug console consumed | `core/DebugLogSetup.lua:20` `LibStub("LibKa0s-DebugLog-1.0", true)`; descriptor `:120-160`; stub `:54-118`; `addonName` at `:133` |
| Slash dispatcher consumed | `settings/Slash.lua:64` lookup; `:150` `commands = COMMANDS,`; stub `:69-118` answering all ten members the addon calls |
| Core printer/skin consumed | `core/CoreSetup.lua:39` lookup; `:147` `local printer = lib:New({`; stub `:41-101` |
| Test harness vendored, not hand-written | `tests/_kit/{framework,loader,mock_base,vendor_sync}.lua` + `run-automated-tests.sh`, byte-identical to `../LibKa0s/testkit` at v1.25.0 |
| Master controls composed, not written | `settings/Panel.lua:204` `Helpers.MasterControls{`; `defaults/Profile.lua:26-30` supplies this addon's values; `settings/Panel.lua:262-264` splices at the head |
| Every page draws a strip | `settings/Schema.lua:149,173,182,190,198,206,214,222,234,255,265` — three distinct `group` values in declaration order; `tests/test_panel.lua:238` pins *"the strip draws one tab per schema group, in declaration order"* |
| One chrome block, not boxed twice | no `InlineGroup` anywhere in `settings/`; the two `SimpleGroup` uses (`settings/Panel.lua:47,114`) are the landing page's command row and logo, not a band wrapper |
| Global reset is one act, verbatim wording | `settings/Schema.lua:511` `function Helpers.RestoreAllDefaults()` → single `db:ResetProfile()`; `:582` carries the mandated string verbatim; no `afterRestoreAll`, no `ResetPositions` seam (grep returns only a comment at `settings/OptionsSetup.lua:184`) |
| No `or`-defaulting of user-falsy state | `grep -rn '\bor C\.\|or NS\.C\.\|or D\.' core/ defaults/ modules/ settings/` → no output |
| Migration seam present | `core/Database.lua:16` `NS.SCHEMA_VERSION = 1`; `:23` `function NS:RunMigrations()`, idempotent, body deliberately empty |
| `WG-44` (2026-08-05) closed | `core/WhatGroup.lua:691` `if not (self.db and self.db.profile and self.db.profile.enabled) then` — the gate that did not exist; `tests/test_capture.lua:83` `test("capture: master switch off blocks the inviteaccepted fresh fetch too", …)` with the search result left live |
| `WG-40` (2026-08-05) closed | `settings/Panel.lua:358` `function Settings.Register()` — no `InCombatLockdown()` early return; `:355-356` records why it went |
| `WG-43` (2026-08-05) closed | `grep -rnE '§[0-9]+\.[0-9]+'` over the live tree (excluding `libs/`, `tests/_kit/`, and the frozen `docs/` bundle directories) → **0 hits** |
| No retired docs | no `docs/complexity.md`, no `docs/file-index.md`, no `docs/conventions.md`, no `docs/perf-runs/`, no `docs/agent-context.md`, no `docs/pending/`, no `TODO.md` |
