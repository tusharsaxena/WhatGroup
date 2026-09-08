# 03 — Evidence (2026-09-08)

Every `file:line` in this bundle was re-read and the cited text quoted beside it before it shipped.
Every count below was produced by the command printed with it, and every command carries its
**scope** — what it swept and what it did not.

**Repo state for all of it:** `git rev-parse HEAD` → `58bc2806de2539931153525784b94843e6b17a96`
(`58bc280`), branch `master`, `git status --short` empty.

---

## A. Resolving the standard

```console
$ curl -fsSL "$RAW/standards/STANDARDS.md" -o STANDARDS.md && head -1 STANDARDS.md
# Ka0s WoW Addon Standard (v2.39.0, 2026-09-07)
```

`RAW=https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`. `AUDIT.md` fetched
from the same ref (583 lines). The Sections list was parsed rather than hard-coded:

```console
$ grep -oE '\(standards/[a-z0-9-]+\.md\)' STANDARDS.md | tr -d '()' | sed 's|standards/||' | sort -u | wc -l
26
```

All 26 fetched from `$RAW/standards/standards/`. **A stale-copy hazard was caught and is recorded
because it would have invalidated this audit:** the scratchpad already held v2.38.0 copies from an
abandoned attempt, and a first fetch loop timed out mid-pass. Re-fetching all 26 in parallel into a
clean directory and comparing md5s found **14 stale**:

```console
$ for f in $(cat list.txt); do [ "$(md5sum < sec/$f)" = "$(md5sum < v239b/$f)" ] || echo "DIFFERS: $f"; done
DIFFERS: audit-review-history.md   DIFFERS: automated-tests.md   DIFFERS: documentation.md
DIFFERS: layout.md                 DIFFERS: library-stack.md     DIFFERS: line-endings.md
DIFFERS: lint.md                   DIFFERS: localization.md      DIFFERS: open-evolutions.md
DIFFERS: options-ui.md             DIFFERS: packaging.md         DIFFERS: slash-commands.md
DIFFERS: standalone-windows.md     DIFFERS: toc-file.md
```

Every rule quoted in this bundle is from the verified `v239b/` copies. `performance.md`,
`architecture.md`, `events-frames-taint.md` and `anti-patterns.md` are **unchanged** between
v2.38.0 and v2.39.0 — which is what lets §H say the three register rows' cited rules did not move.

## B. The gating suites

```console
$ luacheck .
…
Total: 0 warnings / 0 errors in 41 files
```

**Scope, read off `.luacheckrc:17` because `lint` now requires it:**
`exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }` — the
v2.39.0 template **verbatim**. The test tree is in scope, which is what moved the count from 16 to
41: `git ls-files '*.lua' | grep -vE '^libs/|^tests/'` → **16** source files, and
`git ls-files '*.lua' | grep '^tests/' | grep -v '^tests/_kit/'` → **25** test files.
The harness global is in a `files["tests/"]` stanza (`.luacheckrc:61`), not top-level
`read_globals`. There is **no** top-level `ignore` — `.luacheckrc:19` says so and
`tests/test_lintconfig.lua` gates it. Three per-file stanzas carry narrowed
`<code>/<variable>` entries only.

```console
$ lua tests/run.lua
…
  PASS  every deviation id the register cites is assigned by a bundle in docs/audits/
  PASS  libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
  PASS  tests/_kit is the test kit that shipped with that release
  PASS  eol: every tracked file carries the terminator .gitattributes declares for it

559 passed, 0 failed, 0 skipped, 559 total
```

`docs/test-cases.md`'s Totals row reads `| **Total** | **559** |` and `README.md:7` reads
`Tests-559%2F559_passing`. The three figures agree.

## C. Line endings (`line-endings`)

```console
$ test -f .gitattributes && echo present
present
$ grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes
26:* text=auto eol=crlf
$ grep -n '^\*\.sh text eol=lf$' .gitattributes
34:*.sh text eol=lf
$ grep -c ' binary$' .gitattributes
20
```

`(b)` matches the repo's **kind**: a `.toc` exists, so it is client-bound and pins CRLF.

**Canonical-body diff (`line-endings-§5`), which is a diff and not a reading.** The §5 client-bound
body was extracted from the fetched section file and compared against the repo's file with CRLF
stripped:

```console
$ wc -l canon_client.txt wg_gitattributes_lf.txt
81 canon_client.txt
81 wg_gitattributes_lf.txt
$ diff canon_client.txt wg_gitattributes_lf.txt && echo IDENTICAL
IDENTICAL
```

81 lines is §5's client-bound length, so there is no tail and no
`# --- line-endings-§5 appendix ---` block — and none is owed: the repo vendors no
extension-less binary.

**(e) the working tree against the declared pin**, run verbatim from `AUDIT.md` / `line-endings-§7`:

```console
$ git ls-files -z | xargs -0 -I{} sh -c '
    set -- $(git check-attr text eol -- "{}" | sed "s/.*: //")
    [ "$1" = unset ] && exit
    cr=$(tr -dc "\r" < "{}" | wc -c); lf=$(tr -dc "\n" < "{}" | wc -c)
    case "$2" in crlf) [ "$lf" -gt 0 ] && [ "$cr" -ne "$lf" ] && echo "{}";;
                 lf)   [ "$cr" -gt 0 ] && echo "{}";; esac' 2>/dev/null | wc -l
0
```

**Scope: every tracked file in the repo, no exclusions** — that is what `git ls-files` sweeps, and
files git marks `binary` are skipped by the `text=unset` guard rather than by a path filter. **0**
strays; the 2026-09-07 bundle reported 6 for the same command, and `M4-10` closed it. That frozen
bundle is not edited.

**The gate `line-endings-§7` newly MUSTs is present and green:** `tests/_kit/test_eol.lua` exists,
`tests/_kit/framework.lua:20` reads `Kit.VERSION = 15` — the revision §7 names — and its case is in
the run above.

## D. Vendored Ka0s-owned library drift

Provenance, read from the file the gate reads:

```console
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md
69:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.27.0 (MIT). That line is the
$ grep -n 'Bundles \[LibKa0s\]' README.md
$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md
$ grep -n 'WoW_Addon_Standard' README.md
6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
```

Three empty results and one hit in the **bare** `![Standard](…)` form. Anti-patterns #58 and #59
clear; `documentation-§1` #2's MUST NOT on a linked badge clear.

Both diffs are against **the tag `CLAUDE.md` names**, not the sibling's HEAD:

```console
$ git -C ../LibKa0s archive v1.27.0 | tar -x -C /tmp/lk127
$ diff -r /tmp/lk127/LibKa0s  ./libs/LibKa0s   && echo SHIP-EMPTY
SHIP-EMPTY
$ diff -r /tmp/lk127/testkit  ./tests/_kit     && echo KIT-EMPTY
KIT-EMPTY
```

Both **empty**: no #45 drift, no #48 partial vendoring. `libs/LibKa0s/` holds all **14** `.lua`
files `library-stack-§7` names for ten majors (`OptionsCompose.lua` included), plus `LICENSE`,
`LibKa0s.xml` and `media/`. `tests/_kit/` is under `tests/`, never `libs/`.

```console
$ git -C ../LibKa0s tag --list 'v1.*' | sort -V | tail -3
v1.25.0
v1.26.0
v1.27.0
```

v1.27.0 is the newest tag, so the pin is current and there is no re-vendor backlog to report as
scheduling drift.

## E. British spellings — WG-54

The gate is `localization-§5`'s **published** `BRITISH` and `ALLOWED` lists, copied **whole** (the
section MUSTs both, whole or not at all), `ALLOWED` removed as delimited whole words first, then
`BRITISH` matched as case-insensitive substrings.

**Scope swept:** the **65** tracked files the filter below matches — every `.lua`, `.md`, `.toc`
and `.yaml`, plus `.pkgmeta` and `.luacheckrc`.
**Excluded, each named rather than pattern-inferred** per §5: `libs/`, `tests/_kit/` (vendored,
MUST NOT edit), `docs/audits/`, `docs/reviews/`, `docs/automated-tests/<run>/`,
`docs/superpowers/`, `docs/revendor/` (frozen bundles), `locales/enGB.lua` (does not exist here).

```console
$ git ls-files | grep -vE '^libs/|^tests/_kit/|^docs/audits/|^docs/reviews/|^docs/automated-tests/[0-9]|^docs/superpowers/|^docs/revendor/|^locales/enGB\.lua$' \
    | grep -E '\.(lua|md|toc|yaml)$|^\.pkgmeta$|^\.luacheckrc$' > scope.txt && wc -l < scope.txt
65
$ lua brit.lua scope.txt
core/WhatGroup.lua:60: [travelled] -- forwarded them on, so `text`, `button` and two varargs travelled into handler bodies that read
core/WhatGroup.lua:740: [cancelled]     cancelled         = true,
core/WhatGroup.lua:779: [behaviour]         -- Deliberately empty, and the emptiness is the behaviour: "invited" is the client asking
docs/data-flow.md:56: [cancelled]         │                                     "declined_delisted" / "cancelled"
tests/test_capture.lua:433: [cancelled]     addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "cancelled")
TOTAL HITS: 5
```

**Five raw, two real.** The three `cancelled` hits are `C_LFGList`'s own application-status token,
which §5's *Blizzard and third-party symbols* exception requires be reproduced verbatim —
`core/WhatGroup.lua:736-741` is the `APPLICATION_ENDED` set whose keys **are** those tokens, and
`core/WhatGroup.lua:776` dispatches on them:

```lua
736:  local APPLICATION_ENDED = {
740:      cancelled         = true,
776:      elseif APPLICATION_ENDED[newStatus] then
```

The two real ones, quoted at the line:

```
core/WhatGroup.lua:60   -- forwarded them on, so `text`, `button` and two varargs travelled into handler bodies that read
core/WhatGroup.lua:779          -- Deliberately empty, and the emptiness is the behaviour: "invited" is the client asking
```

The three sites the 2026-09-07 bundle named are clean:

```console
$ grep -rniE 'colour|grey|behaviour|centre|cancelled|travelled' modules/Frame.lua settings/Schema.lua settings/OptionsSetup.lua
$
```

Both survivors were introduced on 2026-09-08 by `5f7272b` (`M4c-04`), which is the commit whose own
message is *"the blanket ignore goes, and fifteen of the twenty-four were real"*. **No repo-local
British-spelling gate exists** — `grep -rl 'BRITISH' tests/` is empty — so nothing here could have
caught them.

## F. Unresolvable standards citations — WG-62

The authority is `documentation-§6`: *"Range-check against the section file's own heading count,
which is the only authority — `grep -c '^### [0-9]' standards/standards/<file>`."*

**Scope swept:** all **66** tracked files after removing `libs/`, `tests/_kit/`, `docs/audits/`,
`docs/reviews/`, `docs/automated-tests/`, `docs/superpowers/`, `docs/revendor/` and `media/`. The
first four bundle directories are the exemption §6 states explicitly; `media/` holds no text.

```console
$ git ls-files | grep -vE '^libs/|^tests/_kit/|^docs/audits/|^docs/reviews/|^docs/automated-tests/|^docs/superpowers/|^docs/revendor/|^media/' | wc -l
66
$ # per-file heading counts, then range-check every extracted citation
$ … python3 range-check …
lint-§1                    x8    BARE-FILENAME SECTION
code-quality-§3            x2    NO SUCH SECTION FILE
total offending SITES: 10
```

`grep -c '^### [0-9]'` on the fetched sections returns **0** for `lint` (and for the other ten
files §6 names), and there is **no** `code-quality.md` in the Sections list at all. The ten sites,
re-read and quoted:

```
.luacheckrc:13                  -- linted (lint-§1). Under docs/ only the FROZEN evidence bundles are excluded; a blanket docs/
.luacheckrc:19                  -- NO TOP-LEVEL `ignore`, and none is coming back (lint-§1, `M4-11`). This file carried
.luacheckrc:73                  -- The narrowed 212s (lint-§1, `M4c-04`)
docs/testing.md:299             `tests/test_lintconfig.lua` is the four cases that hold it honest (lint-§1,
tests/test_lintconfig.lua:1     -- tests/test_lintconfig.lua — the "no blanket suppression" gate (lint-§1, `M4-11`).
tests/test_lintconfig.lua:131        .. "business producing it, so it reads as coverage and provides none (lint-§1, "
tests/test_lintconfig.lua:151        .. "lint-§1 refuses it for the same reason: it reaches every file in the repository "
tests/test_lintconfig.lua:262        .. "warning in the same scope is still reported (lint-§1)", 2)
core/WhatGroup.lua:744          -- complex function and sits at the `code-quality-§3` ceiling; the "inviteaccepted" arm is the
docs/module-map.md:17           …named rather than inlined so the function stays inside the `code-quality-§3` ceiling that…
```

The **SHOULD** half of §6 — retired dotted `§N.M` notation — is clean:

```console
$ grep -rEn '§[0-9]+\.[0-9]' . --exclude-dir=libs --exclude-dir=_kit \
    --exclude-dir=audits --exclude-dir=reviews --exclude-dir=automated-tests --exclude-dir=.git | wc -l
0
```

## G. Complexity — WG-48

Run **verbatim** from the repo root, as `automated-tests` specifies; no extra flag, no narrowed
path, no re-tuned threshold.

```console
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
…
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
      7913       6.6     1.8       48.2     1050            0      0.00    0.00
```

Compared against the **latest run bundle**, `docs/automated-tests/20260908-181437/`, whose
`manifest.json` records `"sha": "e735453…"` and `"nloc": 7702, "functions": 1044, "maxCcn": 15`,
and against the watch list at `docs/automated-tests/RESULTS.md:63-82`:

| Metric | Bundle `20260908-181437` (`e735453`) | HEAD `58bc280` | Drift |
|---|---|---|---|
| Total NLOC | 7702 | 7913 | +211 |
| Functions | 1044 | 1050 | +6 |
| Max CCN | 15 | 15 | — |
| `lizard` warnings | 0 | 0 | — |
| Files 1000–1500 | 1 | 1 | — |
| Files over 1500 | 0 | 0 | — |
| `luacheck` files | 40 | 41 | +1 |
| Test cases | 554 | 559 | +5 |

**Nothing crossed a `lizard` threshold and no file entered the `layout-§1` band since that run.**
The ceiling function is unchanged in score and has only moved in the file:

```console
$ grep -E '^ +[0-9]+ +[0-9]+ ' complexity.txt | sort -k2 -rn | head -3
      37     15    239      0      69 WhatGroup@772-840@./core/WhatGroup.lua
      38     13    214      0      69 WhatGroup@702-770@./modules/Frame.lua
      16     13    121      1      18 Compat.GetSpellCooldownRemaining@83-100@./core/Compat.lua
```

`WhatGroup:LFG_LIST_APPLICATION_STATUS_UPDATED` is CCN **15** — at the release gate's cap, not over
it. Read as **genuine control flow, not dense defaulting**: the bundle's own `ANALYSIS.md` records
that `lizard` scores Lua closures as separate functions and that this handler's score is top-level
branching, and the file confirms it — `core/WhatGroup.lua:776` dispatches a status string across
`APPLICATION_ENDED`, an `"invited"` arm and an `"inviteaccepted"` arm, none of which is an
`and`/`or` short-circuit.

**Watch-list disposition age (anti-pattern #53).** One entry, and it is new:

```console
$ git log --oneline -3 -- docs/automated-tests/RESULTS.md
d54a8dc M5-01: the record is regenerated, and the band table stops being empty
d3a3a2a automated-tests: record run 20260825-103505 — green, and a 3.19s gate
e617aa1 automated-tests: record run 20260807-121935 — the watch list is empty
```

`d54a8dc` is the first commit ever to write a band row (`RESULTS.md:82`), so its **Accepted**
disposition has carried for **one** run, not three. And every manifest carries `"release": null`,
so the three-consecutive-**release**-runs clock has not started at all.

**The artifact itself.** `tests/_kit/run-automated-tests.sh` is vendored and recorded executable —
`git ls-files -s` → `100755 f6cd8b0… tests/_kit/run-automated-tests.sh`.
`docs/automated-tests/README.md` and `RESULTS.md` both exist. No retired `docs/complexity.md`, no
`docs/perf-runs/`.

**No complexity refactor to audit against `performance-§11` this cycle:** `lizard` warned on
nothing at either end, the watch list's only entry is a *file-size* band row, and the diff since
2026-09-07 contains no watch-list-driven extraction.

## H. The recorded-deviation register — read first, and evaluated

`docs/ARCHITECTURE.md:351` `## Documented deviations`, four rows at `:368-371`.

**Issue store**, read with the `gh` CLI subcommands (never `gh api graphql`):

```console
$ gh issue list --state all --limit 200 --json number,title,state,labels
18 issues. Every one carries a state: label and a severity: label.
  OPEN    #1 state:triaged  #2 state:triaged  #4 state:triaged  #15 state:untriaged
  CLOSED  #3 #6 #8 #16 #17 state:done
  CLOSED  #5 #7 #9 #10 #11 #12 #13 #14 #18 state:will-not-do
```

No `[status]` title prefix (anti-pattern #62 clear). No `docs/pending/` and no `LEDGER.md`
(anti-pattern #60 clear). `docs/scope.md` and root `CLAUDE.md` were read for accepted-deviation
notes; neither carries one that is missing from the register.

**The inverse rule — a `state:will-not-do` issue with no register row.** Nine closed
`will-not-do` issues. #7 (`LIBKA0S-15: Perf declined`) **has** its row. #5 declines an
`X-Wago-ID`, which no section requires. #9–#14 decline a `LibKa0s` module the addon has no use for,
which `library-stack-§3`'s *vendor what you use* permits. #18 declines withdrawing a register row.
**None declines a standard rule, so none owes a row.**

**Every trigger evaluated against this tree:**

| Row | Trigger, as written | Measured today |
|---|---|---|
| `performance-§12` (`:368`) | *"(1) The upstream §12 amendment lands … (2) The ticker stops being window-bounded, or a second repeating timer appears"* | (1) `performance.md` is byte-identical v2.38.0→v2.39.0 (§A). (2) `grep -rn 'ScheduleRepeatingTimer\|NewTicker\|SetScript("OnUpdate"' core modules settings defaults locales` → one hit, `modules/Frame.lua:351` `cooldownTimer = WhatGroup:ScheduleRepeatingTimer(function()`, guarded three lines above by `modules/Frame.lua:347` `if not (f and f:IsShown()) then return end`. **Not fired.** |
| `localization-§3` (`:369`) | *"The first non-English locale file."* | `ls locales/` → `enUS.lua`. **Not fired.** |
| `events-frames-taint-§8` (`:370`) | *"(1) The first call to any API in §8's trigger set … (2) Anything that makes a `pout` fallback reachable — a TOC reorder putting a `settings/` file before `core/WhatGroup.lua`"* | (1) the row's own sweep re-run over `core defaults locales modules settings` → **0** hits. (2) `WhatGroup.toc:43` is `core\WhatGroup.lua`; the `settings/` files are `:64`, `:68`, `:69`, `:70`. **Not fired.** |
| `standalone-windows` (`:371`) | *"The footer gains a **second** wide action button"* | `modules/Frame.lua:586` `local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")` is the only footer control; the teleport control at `:541` is a 24×24 `SecureActionButtonTemplate` anchored `TOPLEFT` in the body (`:542-543`). **Not fired.** |

**Every evidence id resolved — and two do not.** This is the v2.39.0 MUST, and WG-61 is its output.
The register's own key, at `docs/ARCHITECTURE.md:360-364`:

> A `WG-NN` or `WG-A-NN` id in a **Why** cell is a deviation an audit filed and resolves in
> `docs/audits/`; a `WG-R-NN` id is a review finding and resolves in `docs/reviews/2026-09-07/` as
> `WHATGROUP-R-NN`.

| Id cited | Row | Resolves to | Verdict |
|---|---|---|---|
| cites `WG-22` | (in `core/CoreSetup.lua`'s prose, not a register row) | `docs/audits/2026-07-18/01_CURRENT_STATE.md:87` | resolves |
| cites `WG-52` | `standalone-windows` (`:371`) | `docs/audits/2026-09-07/02_DEVIATIONS.md` §*WG-52* | resolves |
| cites `WG-R-06` | `localization-§3` (`:369`) | Per the key: `docs/reviews/2026-09-07/01_FINDINGS.md:197` — *"### WHATGROUP-R-06 — `Compat.IsSpellKnown` is the one spell shim with no modern-namespace rung"* | **wrong finding.** The row's real evidence is `docs/reviews/2026-08-05/01_FINDINGS.md:172` — *"### F-006 — Five locale rows have no call site, and the settings surface they name is hardcoded English"* |
| cites `WG-A-08` | `events-frames-taint-§8` (`:370`) | `grep -rn 'WG-A-[0-9]' docs/audits/` → one line, `docs/audits/2026-09-07/02_DEVIATIONS.md:46`, which is that bundle **quoting this same register row** | **circular; resolves to nothing.** The row's real evidence is `docs/audits/2026-08-05/02_DEVIATIONS.md:113` — *"### WG-37 — two settings-layer call sites fall back to the global `print()`"*, which the 2026-09-07 bundle itself calls *"the former `WG-37`"* |

(The first column deliberately reads *cites `WG-…`* rather than leading with the id: an id
heading a table cell is exactly what `tests/test_register.lua`'s `isAssigned` accepts as an
**assignment**, and this bundle must not manufacture one for the two dead ids it is reporting —
which is WG-63's whole point, one document over.)

**Why the repo's own gate stayed green (WG-63).** `tests/test_register.lua` exists for this MUST
and passes:

- `tests/test_register.lua:94` — `if section:sub(pos - 1, pos - 1) ~= "-" and not id:find("%-R%-") and not seen[id] then` — skips `WG-R-06` by construction, a choice documented at `:44-48` as *"a whole-repo naming convention rather than a register defect"*.
- `tests/test_register.lua:59-77` — `isAssigned` accepts an id heading **any** table cell in **any** `docs/audits/*/*.md`, and the frozen bundle's *Recorded deviations* echo row is such a cell. Its own header comment at `:38-42` names the hazard: *"A bundle that REPORTS a dead citation quotes the dead id while doing so, so a substring search goes green on the very defect it was written for — `testing-§12`'s failure mode, sitting inside the gate for it."*

## I. Packaging — WG-58

```console
$ for e in .luacheckrc .pkgmeta .gitignore .gitattributes .claude .superpowers docs tests _dev; do
    grep -q "^  - $e\b" .pkgmeta || echo "NOT IGNORED — $e"; done
NOT IGNORED — .superpowers
$ for e in .[!.]*; do [ -e "$e" ] || continue; grep -q "^  - $e\b" .pkgmeta || echo "UNACCOUNTED — $e"; done
UNACCOUNTED — .git
$ ls -d .[!.]*
.claude  .git  .gitattributes  .gitignore  .luacheckrc  .pkgmeta
```

`.git` is the one entry the packager never sees. Check (b) is otherwise **clean**, which is the
half `M1-STD-13` closed by amending the template — `.pkgmeta:14` now reads
`  - .pkgmeta    # packager configuration: consumed before the zip is built, of no use inside it`,
`:12` reads `  - _dev`, and `:19` reads `  - .claude     # untracked; listed under packaging.md:28`.
No `externals:` block; `grep -n externals .pkgmeta` is empty.

## J. `docs/` shape — measured, not read

**Tier 1**, all six present:

```console
$ for f in scope module-map schema settings-panel data-flow common-tasks; do
    [ -f "docs/$f.md" ] && echo "OK docs/$f.md"; done
OK docs/scope.md  OK docs/module-map.md  OK docs/schema.md
OK docs/settings-panel.md  OK docs/data-flow.md  OK docs/common-tasks.md
```

**Tier 2 triggers, measured against the code:**

```console
$ grep -cE '^\s+\{"' settings/Slash.lua          # the COMMANDS entries, settings/Slash.lua:35-58
11
$ grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua   # documentation-§3's own grep
7
$ grep -rn 'SendMessage\|RegisterMessage' --include='*.lua' core modules settings defaults
$
```

11 ≥ 8 → `slash-dispatch.md` required, present. 7 ≥ **3** — v2.39.0's new count, whose worked
example names *"`WhatGroup/core/Compat.lua` (130 lines, 7 shims, at `:24`, `:40`, `:52`, `:62`,
`:83`, `:105`, `:125`)"* — → `compat-layer.md` required, present. 0 messages → `message-bus.md`
Not applicable, and the row is at `docs/ARCHITECTURE.md:329`. `profiles.md` Not applicable
(`:331`); `perf-analysis/README.md` Not applicable in `### Conditional` (`:332`), which is where
v2.39.0 says it registers **in both states**.

**The map (`documentation-§3`), four tables in the mandated order:**

```console
$ grep -n '^### ' docs/ARCHITECTURE.md | sed -n '1,4p'
311:### Required (documentation-§3, Tier 1)
322:### Conditional (documentation-§3, Tier 2)
334:### Verification and record
345:### Addon-specific (documentation-§3, Tier 3)
```

`### Verification and record` sits after Conditional and before Addon-specific, and holds **exactly**
the six rows the amendment names — `testing.md`, `smoke-tests.md`, `test-cases.md`,
`performance.md`, `automated-tests/README.md`, `automated-tests/RESULTS.md` — with no seventh and
no *Not applicable*. Every `.md` under `docs/` outside the frozen directories the map names once
(`docs/audits/`, `docs/reviews/`, `docs/automated-tests/`, `docs/revendor/`, `docs/superpowers/`)
appears in exactly one table; `docs/frame.md` is the single Tier 3 row. No row points at a missing
file. `ARCHITECTURE.md` itself carries no self-row, which v2.39.0 makes a **MAY** an audit may file
neither way.

**Non-canonical filenames and retired docs:**

```console
$ ls docs/*.md | grep -E 'data-model|saved-variables|pipeline|settings-system|wow-quirks|slash-commands|debug-console|file-index|conventions|complexity'
$ ls -d docs/perf-runs docs/agent-context.md 2>&1 | tail -1
ls: cannot access 'docs/perf-runs': No such file or directory
```

None. **Hub shape:** `wc -l docs/ARCHITECTURE.md` → **386**, under the ~400 SHOULD, and
`tests/test_doc_structure.lua`'s case *"every mandated hub section that has a topic doc has spilled
into it"* passes in §B.

## K. The shared subsystems — wiring, not absence

There is no addon-owned console, widget maker, dispatcher or test framework to find:

```console
$ ls core/DebugLog.lua modules/DebugLog.lua core/LSMPatch.lua 2>&1 | tail -1
ls: cannot access 'core/LSMPatch.lua': No such file or directory
```

What the addon owns, cited at the descriptor and the stub as `AUDIT.md` requires:

| Module | Lookup | Descriptor / wrapper | Degradation stub |
|---|---|---|---|
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua:39` | `NS.MakeCloseButton` wrapper at `:136` — `return lib.MakeCloseButton(parent, onClick, addonName)` | `core/CoreSetup.lua:41-102`, opening `if not lib then` and closing with `:100` `function NS.MakeCloseButton() return nil end` |
| `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua:20` | `:New{}` at file scope; `:124` `name = addonName`, `:133` `addonName = addonName` (debug-logging-§13) | `core/DebugLogSetup.lua:54-…`, one announcer per entry point, with the deliberate formatter omission reasoned at `:76-78` |
| `LibKa0s-Media-1.0` | `core/MediaSetup.lua` | `:92` `if Media then Media.RegisterLSM(addonName) end` — one call, the file's own first vararg; `NS.Icon` at `:64` | the `if Media` guard itself, with `NS.Icon` answering nil, reasoned at `:31` |
| `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua` | instance published as `Settings.Helpers` at `:273` | `:53-142` — **load-completing rather than member-answering**, which `options-ui-§1` names as the one documented exception and which v2.39.0 extends with the hollow-composer ruling. Not a finding. |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua:64` | descriptor at `:150`, `commands = COMMANDS` | `:67` `local CLI_MISSING = NS.LIBKA0S_MISSING .. ", so the settings CLI is unavailable."` |

The close-button MUST, run as the grep the section specifies:

```console
$ grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'
core/CoreSetup.lua:100:    function NS.MakeCloseButton() return nil end
core/CoreSetup.lua:136:    return lib.MakeCloseButton(parent, onClick, addonName)
```

The wrapper's definition and its degraded twin, and nothing else — no second factory, no direct
two-argument call, no `NS.DebugLog.MakeCloseButton`. There is no perf-panel `decorate` hook to
simplify (no harness is wired). The four-condition **reasoned decline** of `standalone-windows` is
not invoked here: the popup's title bar carries no close control at all, and the register row is
about the *footer button's mark*, a different bullet.

**Stub coverage** is gated rather than eyeballed: `tests/test_surface_parity.lua` produces the
degraded arm from a **real load** with the library's files omitted (`tests/test_surface_parity.lua:53`
`local NO_LIBKA0S = T.loadAddon.libFiles`), derives the live member list from a grep it names in
the comment, and exempts only members with the rule that makes them live-only — which is
`testing-§8` and anti-pattern #56 exactly.

## L. Settings content — the nine `options-ui` checks

- **(a) strip on every page.** One page: `settings/Panel.lua:367`
  `Helpers.RegisterOptionsPage("general", "General", buildGeneralPage)`, built through `:356`
  `Helpers.RenderTabbedSchema(c, "general", AFTER_GROUP)`. Distinct `group` values in declaration
  order: **Master controls** (spliced at the head, `settings/Panel.lua:268-270`), **Chat**
  (`settings/Schema.lua:149`), **Popup** (`:234`). The landing page (`buildMain`) and a Profiles
  sub-page are the two exempt cases; there is no Profiles page here.
- **(b) `Master controls` is first, and composed.** `settings/Panel.lua:204`
  `local MASTER_ROWS, MASTER_TAIL = Helpers.MasterControls{` — the library composer, not a
  hand-written block — with `afterGroup` keyed off the library's published constant at `:323-324`
  (`if Helpers.MASTER_GROUP then / AFTER_GROUP[Helpers.MASTER_GROUP] = MASTER_TAIL`) rather than
  a literal. All eight canonical rows are present and the addon has the state for all of them,
  because `modules/Frame.lua:415` `f:SetMovable(true)` proves a positionable frame.
  **The `General visibility` migration question does not arise:** `git show
  127baa1^:defaults/Profile.lua` carries neither `visibility` nor a *show only in combat* boolean,
  so no stored type changed and `core/Database.lua:16`'s `NS.SCHEMA_VERSION = 1` is correct.
- **(c)/(d) colour rows.** `grep -rn 'type *= *"color"\|classColorSource\|disabledIf' settings/ defaults/` → empty. Not engaged.
- **(e) ordering.** `grep -rn 'ScrollUp-Up\|ScrollDown-Up' --include='*.lua' settings/` → empty. No stored array is ordered by the user.
- **(f) media groups.** `grep -rn 'LSM30_Font\|LSM30_Border\|LSM30_Statusbar' --include='*.lua' settings/ core/ modules/ defaults/` → empty. No group to compare, and no broadcast meta row.
- **(g) chrome band.** `docs/settings-panel.md:335` records *"There is **no page banner** (`options-ui-§14`) and there cannot be one"* and why; no `InlineGroup`, backdropped `SimpleGroup` or hand-drawn border wraps the band.
- **(h) wrapped strip.** Three tabs; nothing wraps. The library reads the pitch from the **unselected** art — `libs/LibKa0s/OptionsWidgets.lua:436` *"How far apart two rows of tabs sit: the UNSELECTED tab art's own height"* — which is the compliant shape and is the library's to audit.
- **(i) secondary strip.** None exists; the two tabs that mix control kinds use `subgroup` headings declared by the rows (`settings/Schema.lua:149,173,234,255`), which is `options-ui-§7`, not a third level.

## M. Preview mode, public API, compat

`preview-mode`'s explicit-verb SHOULD is met: `/wg test` (`settings/Slash.lua:40-41`) injects
synthetic group info and runs the **same** notify + popup render path, and the same body is behind
the panel's Test button (`settings/Panel.lua:292-302`, `onClick` at `:298-300`), so there is one implementation, not a mock.
It is one-shot rather than a mode, so the MUST about clearing on re-lock has nothing to clear.

`public-api` is not engaged: `grep -rn 'NS.API\|_G\[addonName\]' --include='*.lua' core modules settings` is empty, and `docs/module-map.md:17` records **no `_G.WhatGroup`**.

`compat` — `core/Compat.lua` is the only file with a shim, seven of them at `:24`, `:40`, `:52`,
`:62`, `:83`, `:105`, `:125`; `grep -rn 'WOW_PROJECT_ID' --include='*.lua' .` outside `libs/` is
empty.
