# 03 — Evidence (2026-10-07)

Every command below was run on `57a08e9` from the repo root during this audit. Every output is the
real output, trimmed only where marked `…`. Each census states its **scope**, meaning what it swept and
what it left out. Every `file:line` cited in this bundle was re-read before writing, and the cited text
is quoted beside it. Four citations were corrected in that pass.

Scope shorthand used below:
- **Authored Lua** = `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`, 59 files, `tests/`
  included (`layout-§1`'s denominator).
- **Shipped source** = authored Lua minus `tests/`: `core/ defaults/ locales/ modules/ settings/`, 21
  files.
- **Live docs** = `git ls-files` minus `libs/`, `tests/_kit/`, `media/` and the frozen and generated
  stores `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `docs/superpowers/` and
  `docs/automated-tests/<run>/`.

---

## §A — Mechanical runs

### A.1 Headless suite (bounded)

```
$ ~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua          # exit 0
…
  SKIP  diagnostics contract: an addon that opts out lands the report and leaves logging off — this addon keeps the default (Kit.diagnostics.enablesLogging is not false), so its report turns logging on; the case above holds it
…
  PASS  libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
  PASS  tests/_kit is the test kit that shipped with that release
…
914 passed, 0 failed, 1 skipped, 915 total
```

Inventory: `lua tests/run.lua --list` (bounded), diffed CR-stripped against `docs/test-cases.md`, is
**identical**. README badge `README.md:7`: `![Tests](https://img.shields.io/badge/Tests-914%2F914_passing-green)`.
That agrees: `testing-§5` keeps a skip out of both figures.

### A.2 Lint (bounded)

```
$ ~/.claude/dev-copilot/bin/ka0s-bounded luacheck .                 # exit 0
Total: 0 warnings / 0 errors in 59 files
```

Scope, from `.luacheckrc:18`:
`exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "docs/revendor/", "_dev/", "tests/_kit/" }`.
The test tree is in, and the harness globals sit in `files["tests/"]` (`.luacheckrc:68`). There is no
top-level `ignore`. Three per-file `212` stanzas name `<code>/<variable>` (`:103-105`, `:114-116`,
`:121-123`).

### A.3 Sighted complexity (bounded, verbatim, writes nothing)

```
$ ~/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle
WhatGroup 1.5.0 — automated tests — 20261007-160829
  complexity  pass  — 0 warnings (fun rate 0.00), 13412 NLOC / 1792 funcs, avg NLOC 7.0, avg CCN 1.9 (max 15), avg tokens 54.1 (recorded, non-gating)
  verdict: green
  record:  newest bundle 20260927-031637 measured 62680d3, 50 commit(s) behind HEAD — its figures describe a tree this one is no longer
```

Scope: the runner's own `find . -name '*.lua' -not -path './libs/*' -not -path './tests/_kit/*'`, which
is authored Lua including `tests/`.

To name the max-CCN function, the runner's shadow step was reproduced into the session scratchpad,
using the same `lizard_sighted.lua shadow`, the same fixed `lizard -l lua -L 1500 -x "./libs/*" -x
"./tests/_kit/*" .` and `lizard_sighted.lua parity`. Nothing was written to the repo.

```
      28     15    315      2      31 encode@336-366@./tests/perf.lua
      39     13    220      4      69 WhatGroup.LFG_LIST_APPLICATION_STATUS_UPDATED@1184-1252@./core/WhatGroup.lua
      26     13    153      1      54 WhatGroup.ShowFrame@1141-1194@./modules/Frame.lua
…
     13412       7.0     1.9       54.1     1792            0      0.00    0.00
parity: (no output — 0 blind files)
```

The top three are **guarding/defaulting** shape rather than tangled flow. `encode` is a JSON
encoder's type dispatch in an offline script. The status handler is one `if/elseif` per LFG status.
`ShowFrame` is the visibility and test-mode guard ladder.

Newest bundle, `docs/automated-tests/20260927-031637/manifest.json`:
- `:10` → `"git": { "sha": "62680d3abce207c90cd4fc6ef101a75fdc7d9054", "branch": "master", "dirty": false }`
- `:16` → `"complexity": { "status": "pass", … "maxCcn": 13, "nloc": 12183, "functions": 1591, … "bandFiles": 2, "overCapFiles": 0, … }`.
  There is **no** `blindFiles` key, because the bundle was written on kit 34.

`git rev-list --count 62680d3..HEAD` → `50`. Kit revision: `tests/_kit/framework.lua:20` →
`Kit.VERSION = 37`. Gate wiring: `tests/run.lua:192` →
`{ name = "test_lizard_sighted", dir = "tests/_kit/" },`.

The raw-`lizard` gate-line sweep (`grep -n 'lizard' CLAUDE.md docs/testing.md DEPENDENCIES.md`) finds
only the runner command (`docs/testing.md:413`) and `DEPENDENCIES.md:96-97`'s description of what the
runner runs over the shadow. No gate line quotes raw `lizard`. The same grep over
`tests/test_lintconfig.lua tests/prose_waivers.lua tests/test_doc_structure.lua` returns nothing, so
there is no local hazard scanner (#92).

Band census (authored Lua, `xargs wc -l | sort -n | tail`):
```
   1037 tests/test_libka0s.lua
   1313 core/WhatGroup.lua
   1319 modules/Frame.lua
```
Watch list `docs/automated-tests/RESULTS.md`: two **Accepted** band entries, each "1 of 3 against
`automated-tests-§4`'s shelf life". `RESULTS.md:15` → *"evaluated by `/wow-addon:bump-version` from
the"* (generated text).

### A.4 Vendored LibKa0s drift, against the provenance tag

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md
46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).
$ grep -n 'Bundles \[LibKa0s\]' README.md                       # (no output, rc=1)
$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md   # (no output)
$ grep -n 'WoW_Addon_Standard' README.md
6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
$ git -C ../LibKa0s archive v1.70.0 LibKa0s testkit | tar -x -C <scratch>/lk
$ diff -r <scratch>/lk/LibKa0s libs/LibKa0s      # (no output) rc=0
$ diff -r <scratch>/lk/testkit tests/_kit        # (no output) rc=0
```

`../LibKa0s` HEAD `353f286` (`v1.70.0-5-g353f286`), tag `v1.70.0` → `162a7fd`. Both payloads are
byte-identical to the tag. The TOC lists the aggregate once: `WhatGroup.toc:39` →
`libs\LibKa0s\LibKa0s.xml`.

### A.5 README cheap checks

```
$ grep -nE '^[[:space:]]*[0-9]+[.)][[:space:]]' README.md       # (no output) — no numbered list
$ grep -nE '!\[.*\]\(media/logos|<img' README.md               # (no output) — no logo
$ grep -n '^## ' README.md
13:## Screenshots  23:## Usage  38:## How it works  46:## FAQ  60:## Troubleshooting
74:## Reporting a bug  82:## Issues and feature requests  86:## Version History  97:## Credits
```
`README.md:76-78` carry the three `## Reporting a bug` bullets verbatim with `/wg`. `README.md:99-100` →
*"The debug console uses [JetBrains Mono](…), licensed under the SIL Open Font License 1.1. It ships
inside the bundled LibKa0s payload, with its license text beside it."*

### A.6 Line endings (`line-endings`)

```
$ test -f .gitattributes && echo present                        → present
$ grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes      → 26:* text=auto eol=crlf
$ grep -nE '^\*\.(sh|py) text eol=lf$' .gitattributes           → 36:*.sh text eol=lf / 37:*.py text eol=lf
$ grep -c ' binary$' .gitattributes                             → 20
$ wc -l .gitattributes                                          → 84
$ diff <(tr -d '\r' < .gitattributes | head -84) <canonical client-bound body, line-endings.md:166-249>   → (no output) rc=0
$ tr -d '\r' < .gitattributes | tail -n +85 | wc -l             → 0   (no appendix)
$ git ls-files -z | xargs -0 -I{} sh -c '…the (e) check, verbatim from AUDIT.md…' 2>/dev/null | wc -l
0
```
Scope: the whole tracked set with no exclusions (580 files). The kit gate is wired at `tests/run.lua:177`
→ `{ name = "test_eol", dir = "tests/_kit/" },`.

### A.7 Packaging (`packaging`), run under bash

```
(a) NOT IGNORED — (none)
(b) UNACCOUNTED — .git            (the packager never sees it; owes no row)
(c) FALSE CLAIM — (none)
```
`.pkgmeta:20-21` → *"# Tracked, and the only entries here that change a download. Three screenshots, /
# 880K, project-page art the CurseForge CDN already serves."* `git ls-files media/screenshots` → 2 files.
`du -sh media/screenshots` → `216K`. The ignore lines at `.pkgmeta:31-32` (`media/logos/*.png`,
`*.jpg`) also change a download. This is WG-77.

### A.8 Generators (`layout-§1`)

`git ls-files '*.py' '*.sh'` → `tests/_kit/run-automated-tests.sh` only (vendored, a runner). There is no
candidate.

### A.9 Logo (`toc-file-§1`, `layout-§4`)

```
$ od -A d -t u1 -N 18 media/logos/whatgroup.logo.128.tga
0000000   0   0   2   0   0   0   0   0   0   0   0   0 128   0 128   0
0000016  32   8
```
Type 2 (uncompressed), 128×128, 32 bpp. `WhatGroup.toc:6` names this file.

---

## §B — The register and the issue store

`docs/ARCHITECTURE.md:372` → `## Documented deviations`. The rows are at `:380`–`:385` (six).

| Row | Trigger evaluation (command → output) |
|---|---|
| `performance-§12` `:380` | `performance.md` §12 in v2.76.1: *"The first `OnUpdate` handler, repeating ticker, or in-combat event handler doing real work **re-arms the full wiring MUST**"*, so the amendment has not landed. The sweep `grep -rnE 'RegisterEvent\|SetScript\("OnUpdate"\|C_Timer\|ScheduleRepeatingTimer\|ScheduleTimer\|hooksecurefunc' core modules settings defaults locales` → **24 lines across 5 files**. One `ScheduleRepeatingTimer`, at `modules/Frame.lua:587` → `cooldownTimer = WhatGroup:ScheduleRepeatingTimer(function()`. `docs/performance.md:32` claims *"twenty-four lines across five files"*, which matches. |
| `localization-§1` `:381` | `ls locales` → `enUS.lua`. `docs/reviews/2026-08-05/01_FINDINGS.md:172` → `### F-006 — Five locale rows have no call site, …` |
| `events-frames-taint-§8` `:382` | `grep -rnE 'UnitGetTotalAbsorbs\|…\|"UNIT_AURA"' core defaults locales modules settings \| wc -l` → `0`. `core/WhatGroup.lua:189` → `WhatGroup._print = p`. `settings/Panel.lua:25-27` and `settings/Schema.lua:52-54` hold the `pout` fallbacks, and the TOC loads `core\WhatGroup.lua` before every `settings\` file. `docs/audits/2026-08-05/02_DEVIATIONS.md:113` → `### WG-37 — two settings-layer call sites fall back to the global print()`. The row's `:887`/`:895`/`:903` → `p("   - " .. colorize(NS.L["Group:"], GOLD), …)`, `p("   - " .. colorize(NS.L[row.label], GOLD), v)`, `p("   - " .. colorize(link(DETAILS_LINK, …` |
| `standalone-windows` `:383` | `modules/Frame.lua:906` → `local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")`. It is the footer's one wide button. |
| `standalone-windows` `:384` | `modules/Frame.lua:861` → `local teleportBtn = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")`. `:696` → `local ESC_PROXY_NAME = "WhatGroupFrameEscape"`. `standalone-windows.md:7`'s *"(Secure/action-button content is the exception …)"* is unchanged. |
| `options-ui-§1` `:385` | `options-ui.md:62` → *"**`enable` and `disable` SHOULD take route (a).** … WhatGroup takes it under its owner's ruling on WhatGroup#22."* #22 is `CLOSED enhancement,state:done,severity:medium`. |

Issue store (`gh issue list --state all --limit 200 --json number,title,state,labels,closedAt,url`, gh
CLI subcommand only):
```
1 CLOSED enhancement,state:done,severity:low | Add role to the pop
2 OPEN enhancement,state:triaged,severity:medium | Validate the MapIDs and SpellIDs
…
5 CLOSED state:will-not-do,severity:low | Add an `X-Wago-ID` to `WhatGroup.toc` or ratify a Curse-only deviation
7 CLOSED state:will-not-do,severity:low | LIBKA0S-15: Perf declined — ratified in ARCHITECTURE Documented deviations
9–14, 18, 21 CLOSED state:will-not-do …
22 CLOSED enhancement,state:done,severity:medium | LibKa0s-Schema-1.0: adopting the seam breaks the degraded enable and test verbs
```
22 issues. Each carries exactly one `state:` and one `severity:` label. No title has a `[status]` prefix.
`ls docs/pending` → `No such file or directory`.

---

## §C — Citation and inventory checks

### C.1 TOC line citations (all resolve)

```
core/WhatGroup.lua:108  → local ADDON_LINK_TYPE    = NS.Compat.AddOnLinkType()
core/WhatGroup.lua:220  → NS.FONT_MONO = NS.MediaFont and NS.MediaFont(NS.FONT_MONO_NAME) or _G.STANDARD_TEXT_FONT
core/DebugLogSetup.lua:142 → NS.DebugLog = lib:New({
settings/Slash.lua:132  → local CLI_MISSING = NS.LIBKA0S_MISSING .. ", so the settings CLI is unavailable."
core/CoreSetup.lua:34   → NS.LIBKA0S_MISSING = "The LibKa0s library is missing from this installation of Ka0s WhatGroup " ..
settings/Schema.lua:418 → local S = Settings.SchemaLib:New{
settings/Schema.lua:29  → local C         = NS.C
settings/Panel.lua:308  → NS.SchemaRuntime.AddRows(MASTER_ROWS, 1)
settings/OptionsSetup.lua:333 → Settings.Helpers = O
settings/Panel.lua:214  → local MASTER_ROWS, MASTER_TAIL = Helpers.MasterControls{
```

### C.2 `file:line` citations in live docs and comments

Scope: live docs (above) plus authored comments; pattern
`(core|modules|settings|defaults|locales|tests)/[A-Za-z_]+\.lua:[0-9]+`. That gives **48** citations in
`.luacheckrc` (4), `DEPENDENCIES.md` (4), `WhatGroup.toc` (8), `core/DebugLogSetup.lua` (1),
`docs/ARCHITECTURE.md` (5), `docs/frame.md` (1), `docs/module-map.md` (1), `docs/performance.md` (17),
`docs/slash-dispatch.md` (3) and `tests/test_surface_parity.lua` (4). Each was resolved, and three are
stale (WG-77):

| Citation | Claimed | What is at the line | Where it actually is |
|---|---|---|---|
| `.luacheckrc:71` → `tests/loader.lua:129` | "CLEARS it before each boot" | (blank line) | `tests/loader.lua:132` → `_G.WhatGroupDB = nil` |
| `.luacheckrc:102` → `:707` (in `core/WhatGroup.lua`) | "The sibling handler at :707 does read it" | `-- return the first list entry with isKnown=false so the popup at least` | `core/WhatGroup.lua:1080` → `function WhatGroup:OnCombatStateChanged(event)` |
| `DEPENDENCIES.md:46` → `tests/loader.lua:134` | "calls `setfenv(chunk, env)`" | `for _, src in ipairs(sources) do` | `tests/loader.lua:137` → `setfenv(chunk, env)` |

The other 45 resolve. Spot quotes: `core/WhatGroup.lua:381` →
`NS.SafeRegisterEvent(self, "PLAYER_REGEN_DISABLED", "OnCombatStateChanged", NS.RejectedEvents)`.
`core/WhatGroup.lua:436` → `self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnDisabledCombatEnded")`.
`core/Compat.lua:68-73` is `function Compat.GetSpellLink(spellID)` … `end`. `settings/OptionsSetup.lua:292`
→ `C_Timer.After(0, function() baseEnsureDefaultsBtn(panel) end)`.

### C.3 `filename-§N` citations

Scope: live docs and authored files. Pattern `[a-z-]+-§[0-9]+`, checked against each section file's
highest `### N.` heading.
```
total citations: 889 · unknown section: 0 · out of range: 0
retired dotted §N.M: 0 · malformed (-@N / bare -N): 0
```
The kit's `§`-less spellings (old WG-74):
`grep -noE '\b(localization|line-endings|layout|testing|automated-tests|documentation)-[0-9]+' tests/_kit/*.lua | wc -l` → `0`.

### C.4 Inventories re-derived from the tree (WG-77)

| Claim | Command | Result |
|---|---|---|
| Schema rows declared in `settings/Schema.lua` | `grep -nE '^\s*add\{' settings/Schema.lua` | **12** `add{` at `:152, :176, :185, :193, :201, :209, :217, :225, :234, :246, :268, :278`. Paths: `notify.delay`, `.enabled`, `.showInstance`, `.showType`, `.showLeader`, `.showPlaystyle`, `.showClickLink`, `.showTeleport`, `.showRole`, `frame.autoShow`, `.width`, `.height`. |
| Composed Master controls rows | `docs/ARCHITECTURE.md:81-88` table | 8 |
| Total / Chat | sum | **20** / **9** |
| Hub says | `docs/ARCHITECTURE.md:69` → *"Nineteen rows — sixteen profile-scoped, one **global** and two session-only — valued in"*. `:71` → *"stored. Eleven are declared in `settings/Schema.lua`; the other eight are the **Master controls**"*. `:76` → *"(8), **Chat** (8), **Popup** (3), detailed in"*. `:155` → *"over the nineteen rows above"* | |
| `module-map.md` says | `docs/module-map.md:24` → *"Eleven rows are declared here; … giving nineteen rows across three groups — **Master controls** (8), **Chat** (8), **Popup** (3)"* | |
| `settings-panel.md` says | `docs/settings-panel.md:346` → *"\| 2 \| **Chat** \| 9 \|"* | agrees with the tree |
| Compat shims | `grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua` | **9** (`:68, :83, :109, :124, :136, :159, :168, :175, :193`) |
| Hub says | `docs/ARCHITECTURE.md:349` → *"`core/Compat.lua` publishes six addon-specific shims, over the three-or-more threshold"* | |
| `compat-layer.md` says | `:16-17` → *"**Six shims**, counted the way `documentation-§3` counts them (`grep -cE '^\s*function\s+[A-Za-z_.]+\.' core/Compat.lua`)"*. That grep also answers 9. | |
| `module-map.md` says | `:127` → *"the nine `core/Compat.lua` shims"* | agrees |
| `core/Compat.lua:3` | *"addon consumes. Loaded first among the addon files (see WhatGroup.toc)"* | `WhatGroup.toc:46` CoreSetup, `:49` MediaSetup, `:51` Util, `:54` Compat |
| `module-map.md:130` | *"the `performance-§12` no-combat-path exemption + the committed whole-repo combat-path sweep"* | `docs/performance.md:5-7`: the exemption was claimed *"until **2026-08-06**"* and the wiring is *"**still declined** — now as a ratified deviation"* |
| Name-binding headers | `grep -m1 -nE '^local [A-Za-z_]+, *NS *= *\.\.\.'` over shipped source | 9 `addonName`, 12 `_`. The hub's *"the other twelve files"* (`docs/ARCHITECTURE.md:254`) is **correct**. |
| COMMANDS rows | `grep -nE '^\s*\{"[a-z]+"' settings/Slash.lua` | 15, which matches `docs/ARCHITECTURE.md:345` (*"15 verbs in the command table"*) |
| Setup files with a LibKa0s stub | read of the ten files | 10, which matches the hub's "Ten of those arrows" and "All ten wiring files" |

The cause of the count drift: `git log --format='%h %ad %s' --date=short -1 2ed2aa5` →
`2ed2aa5 2026-10-01 GI-WG-01: show the signed-up role in the popup and (toggle) chat (#1)`.

### C.5 Documentation map (`documentation-§3`)

Scope: `git ls-files 'docs/*.md'` minus `docs/(audits|reviews|revendor|superpowers|investigations)/` and
the dated `docs/automated-tests/<run>/` and `docs/perf-analysis/<run>/` bundles. For each file, count
its rows in `docs/ARCHITECTURE.md:325-370`:
```
0 ARCHITECTURE.md      (MAY — not filed either way)
1 automated-tests/README.md   1 automated-tests/RESULTS.md   1 common-tasks.md   1 compat-layer.md
1 data-flow.md   1 debug-content.md   1 debug.md   1 frame.md   1 midnight-quirks.md   1 module-map.md
1 performance.md   1 profiles.md   1 schema.md   1 scope.md   1 settings-panel.md   1 slash-dispatch.md
1 smoke-tests.md   1 stand-down.md   1 test-cases.md   1 testing.md
rows with no file: message-bus.md (Not applicable), perf-analysis/README.md (Not applicable)
```
The four tables are `:330`, `:341`, `:353` (`### Verification and record`, six rows) and `:364`.
`wc -l docs/ARCHITECTURE.md` → `393`. No `file-index.md`, `conventions.md`, `complexity.md` or
`docs/perf-runs/`.

### C.6 Re-vendor bundles (`audit-review-history`), `AUDIT.md`'s loop verbatim, under bash

```
horizon=2026-08-25
vendored: 51
recorded: 49
unrecorded:
v1.69.0
v1.70.0
```
Scope: every commit since `2026-08-25 00:00` that touches `libs/LibKa0s` or `tests/_kit`, with the tag
read from `CLAUDE.md` at that commit. On the recorded side, every `docs/revendor/*/` folder (span,
single-tag and bare-dated rules).

```
$ git show --stat 9677d99 | head -3
commit 9677d990f98cfe618afbef61c21de1267ad95dd9
Date:   Tue Oct 6 14:53:44 2026 +0530
    chore: re-vendor LibKa0s v1.69.0 (kit 37; adds the line chart widget)
$ git show --stat 3fd8a2f | head -3
commit 3fd8a2f356f4fde6fdfbe174fe4c24bdbc57901b
Date:   Wed Oct 7 11:39:17 2026 +0530
    chore: re-vendor LibKa0s v1.70.0
$ ls docs/revendor | tail -2
2026-10-02-v1.68.0
2026-10-04-v1.68.1
```

---

## §D — Code-shape checks

### D.1 Stand-down registration census (shipped source)

```
$ git ls-files '*.lua' ':!libs' ':!tests/_kit' | grep -v '^tests/' | xargs grep -nE 'Register(Unit)?Event|RegisterMessage|RegisterBucketEvent|RegisterCallback' (comment-only lines dropped)
core/CoreSetup.lua:112/113/136   (the SafeRegisterEvent stub and binding — registers nothing itself)
core/WhatGroup.lua:139   EventRegistry:RegisterCallback("SetItemRef", function(_, linkArg)
core/WhatGroup.lua:342-344  self.db.RegisterCallback(… "OnProfileChanged" / "OnProfileCopied" / "OnProfileReset")   (setup; survives by rule)
core/WhatGroup.lua:374   NS.SafeRegisterEvent(self, "GROUP_ROSTER_UPDATE", nil, NS.RejectedEvents)
core/WhatGroup.lua:375   NS.SafeRegisterEvent(self, "LFG_LIST_APPLICATION_STATUS_UPDATED", nil, NS.RejectedEvents)
core/WhatGroup.lua:381   NS.SafeRegisterEvent(self, "PLAYER_REGEN_DISABLED", "OnCombatStateChanged", NS.RejectedEvents)
core/WhatGroup.lua:382   NS.SafeRegisterEvent(self, "PLAYER_REGEN_ENABLED",  "OnCombatStateChanged", NS.RejectedEvents)
core/WhatGroup.lua:436   self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnDisabledCombatEnded")          ← WG-84
$ … | xargs grep -nE 'Unregister(All)?Events?|UnregisterMessage|UnregisterBucket|UnregisterCallback|CancelTimer|CancelAllTimers|:Cancel\(|SetScript\("OnUpdate", *nil\)'
core/WhatGroup.lua:417-420  self:UnregisterEvent(…) ×4
core/WhatGroup.lua:423   if ADDON_LINK_TYPE and EventRegistry then EventRegistry:UnregisterCallback("SetItemRef", WhatGroup) end
core/WhatGroup.lua:444   self:UnregisterEvent("PLAYER_REGEN_ENABLED")      (OnDisabledCombatEnded, first line)
core/WhatGroup.lua:457   self:UnregisterEvent("PLAYER_REGEN_ENABLED")      (StandUp)
core/WhatGroup.lua:1009, :1059  CancelTimer(self.notifyTimer)
modules/Frame.lua:490    WhatGroup:CancelTimer(cooldownTimer)              (stopCooldownTicker, called from NS.FrameStandDown :1253)
```
Every feature registration has its undo. The hub's claim at `docs/ARCHITECTURE.md:184-186` reads
*"The four event rows are registered through **`NS.SafeRegisterEvent`** … never a bare
`self:RegisterEvent`"*, and `:436` is the exception (WG-84). Rejections surface at
`core/WhatGroup.lua:510-512` (`[Init]`) and `modules/Diagnostics.lua:96`.

### D.2 Bus (`architecture-§4`, `naming-cheatsheet`)

```
$ grep -rnE '(Send|Register)Message\("Ka0s_' --include='*.lua' . | grep -v -e '/libs/' -e '/tests/_kit/'   → (none)
$ grep -rnoE '"Ka0s_[A-Za-z]+_[A-Za-z0-9_]+"' --include='*.lua' . | grep -v -e '/libs/' -e '/tests/_kit/' → (none)
```
Not applicable: the addon publishes no message.

### D.3 Write paths (`architecture-§5`), shipped source

```
core/Util.lua:69-70       db.global.windows = … / db.global.windows[name] = pt     (e) named: NS.Windows.Save
modules/Frame.lua:466     db.global.windows.popup = nil                              (e) named: ResetFramePosition
core/WhatGroup.lua:1062-1063, :1240-1241  wipe(capturesByResult / pendingApplications)   session tables, not SV
modules/Frame.lua:707     tinsert(UISpecialFrames, ESC_PROXY_NAME)                   Blizzard table, not SV
modules/Frame.lua:1268    wipe(combatEndQueue)                                       session
settings/SchemaSetup.lua:107  table.insert(rows, …)                                  the schema array, not SV
```
The hub names both (e) entries (`docs/ARCHITECTURE.md:109-119`).

### D.4 Settings panel greps

```
$ grep -n 'disabledIf' settings/*.lua                                        → (none)
$ grep -rn 'ScrollUp-Up\|ScrollDown-Up' --include='*.lua' settings/          → (none)
$ grep -rn 'LSM30_' settings/                                               → (none)
$ git ls-files '*.lua' ':!libs' ':!tests/_kit' | grep -v '^tests/' | xargs grep -nE 'SettingsPanel|HideUIPanel|ToggleGameMenu|OpenToCategory'
modules/Frame.lua:681:-- addon: `ADDON_ACTION_BLOCKED ... 'WhatGroupFrame:Hide()'` from ToggleGameMenu, 2026-09-12.   (comment)
$ … | xargs grep -n 'MakeCloseButton('
core/CoreSetup.lua:100:    function NS.MakeCloseButton() return nil end
core/CoreSetup.lua:164:    return lib.MakeCloseButton(parent, onClick, addonName)     (inside the wrapper at :163)
$ … | xargs grep -n 'SetMovable'  → modules/Frame.lua:718:    f:SetMovable(true)
```

### D.5 Shared-subsystem descriptors (cited, not the library)

- `core/DebugLogSetup.lua:142` → `NS.DebugLog = lib:New({`. `:155` → `addonName = addonName,`. The stub
  is the table opened at `:79` → `NS.DebugLog = {` and closed at `:137`. It carries `DebugOnce` (`:85`)
  and `RunDiagnostics` (`:126`).
- `settings/OptionsSetup.lua:195` → `addonName = addonName,`. `:198` →
  `debug = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,`.
- `settings/Slash.lua:275` → `debug   = function(tag, message) NS.Debug(tag, message) end,`.
  `core/LauncherSetup.lua:156` and `core/LifecycleSetup.lua:101` have the same shape. With no extra
  argument the library's `D.Debug` keeps `fmt` verbatim, so a `%` in a forwarded message cannot raise.
- `core/LauncherSetup.lua:130` → `label = "Ka0s WhatGroup",`. `:152-153` → `isEnabled`/`setEnabled`;
  `isLocked`/`toggleLock`, `isTestMode`/`toggleTestMode` and `isWindowShown`/`toggleWindow` follow.
  `:201` → `--   onTooltipShow -- since minor 3 it APPENDS …` (declined, comment).
- `settings/Slash.lua:81` → `{"diagnostics", L["Write the diagnostics report to the debug console"],`.
  `:495` → `if sub == "diagnostics" then`.
  `grep -rniE '"(diag|dump|dx)"' settings core modules` matches only `modules/Diagnostics.lua:31` →
  `local TAG = "Diag"`, which is a log tag and not a verb.
  `grep -n 'diagnosticsEnablesLogging' core/*.lua` → (none).
  `grep -n ':Clear()' modules/Diagnostics.lua` → (none).
- `core/MediaSetup.lua:48` → `local addonName, NS = ...`. `:93` →
  `if Media then Media.RegisterLSM(addonName) end`.

---

## §E — Closure evidence for the 2026-09-23 roots

| ID | Command / read | Output |
|---|---|---|
| WG-64/65/66 | `sed -n 423p core/WhatGroup.lua`; `docs/ARCHITECTURE.md:169-170`; `tests/test_disabled.lua:75`, `:150` | `EventRegistry:UnregisterCallback("SetItemRef", WhatGroup)`; *"the `EventRegistry` chat-link callback included"*; `--- THE WHOLE REGISTRATION SET: AceEvent, message and bucket registrations and the EventRegistry`; `-- red under: dropping the EventRegistry:UnregisterCallback in NS.StandDown` |
| WG-67 | D.1 | four helper calls, `NS.RejectedEvents` surfaced |
| WG-68 | `grep -n 'RegisterEvent' modules/Frame.lua` | none (only comments) |
| WG-69 | `grep -nE 'NS\.Debug\([^)]*[^.]\.\.[^.]'` over shipped source | none |
| WG-70 | `WhatGroup.toc` comments above `:51` and `:54` | annotated |
| WG-72 | `tests/test_surface_parity.lua:207`, `:223` | `T.assertSurfaceParity(degraded.Launcher, "LibKa0s-Launcher-1.0")`, `… "LibKa0s-Lifecycle-1.0")` |
| WG-73/74 | C.3 | 0 / 0 |
| WG-76 | `wc -l docs/ARCHITECTURE.md` | 393 |
| WG-78 | `docs/ARCHITECTURE.md:381` | Rule cell `` `localization-§1` `` |
| WG-79 | `DEPENDENCIES.md:203`, `:92` | *"**Python 3 + Pillow** — regenerate …"*, *"lizard — **optional per commit, required at release**"* |
| WG-80 | `settings/Panel.lua:96` | ``local MAIN_LOGO_TEXTURE   = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.tga")`` |
| WG-81 | `grep -n 'is disabled\.' core/*.lua` | none |
| WG-83 | `.luacheckrc:18` | includes `"docs/revendor/"` |
