# 03 — Evidence (2026-09-23)

Every `file:line` below was re-read at `1124ac4` and is quoted beside its citation. Every count comes
from a recorded command, and the command's **scope** is stated with it: which paths it swept and which
it excluded. Figures that appear in more than one artifact (16 debug sites, 25 tags, 6 shims, 533
lines, 29 commits, 727 cases) were reconciled across 02, 03 and 05.

**Default census scope** (`layout-§1`'s own denominator): `git ls-files '*.lua' | grep -vE
'^(libs/|tests/_kit/)'` returns **48** tracked authored Lua files, `tests/` included. Where a check
needs the **TOC-loaded** set instead (runtime claims), it says so. That set is `core/*.lua`,
`modules/*.lua`, `settings/*.lua`, `defaults/*.lua` and `locales/*.lua`, 18 files. The untracked
`docs/reviews/2026-09-23/` (a parallel review run) is outside every `git ls-files` census.

---

## §A — Standard, kind, repo state

```sh
RAW=https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master
curl -fsSL -m 60 $RAW/AUDIT.md -o AUDIT.md                       # exit 0, 86710 bytes
curl -fsSL -m 90 $RAW/standards/STANDARDS.md -o STANDARDS.md       # exit 0, 345786 bytes
grep -oE '\(standards/[A-Za-z0-9_-]+\.md\)' STANDARDS.md | sort -u # 27 section files, all fetched
curl -fsSL $RAW/standards/ADDONS.md -o ADDONS.md
head -1 STANDARDS.md   # "# Ka0s WoW Addon Standard (v2.64.0, 2026-09-23)"
```

- `ADDONS.md:29`: `| Ka0s WhatGroup | … | **(a)** the group popup |`. The kind is **Addon**, and the
  `.toc` is present.
- `git -C WhatGroup rev-parse --short HEAD` → `1124ac4`. `git status --short` → `?? docs/reviews/2026-09-23/` only.
- Section ranges (`grep -c '^### [0-9]' <file>` over the fetched section files), used by §F:
  `architecture 7 · automated-tests 7 · debug-logging 13 · documentation 9 · events-frames-taint 8 ·
  launcher 5 · layout 4 · library-stack 9 · line-endings 7 · localization 5 · options-ui 18 ·
  performance 12 · savedvariables 5 · slash-commands 8 · testing 15 · toc-file 5`. The other eleven
  files return 0.

## §B — Register, triggers, issue store (recorded deviations; WG-61, WG-63, WG-78)

- `docs/ARCHITECTURE.md:485` — `## Documented deviations`. Rows:
  - `:502` — `` | `performance-§12` (the exemption is not claimed) | **The no-combat-path exemption was claimed … ``
  - `:503` — `` | `localization-§3` | **English-only, and the routing SHOULD is met in part.** … ``, ends `` … `WG-R-06`. | 2026-08-05 | … ``
  - `:504` — `` | `events-frames-taint-§8` | … ``, whose Why cell ends `` … `WG-A-08`. | 2026-08-05 | … ``
  - `:505` — `` | `standalone-windows` | The popup's footer **Close** button … ``
  - `:506` — `` | `standalone-windows` | `UISpecialFrames` holds an unprotected proxy … ``
- Key `:494-496`: *"A `WG-NN` or `WG-A-NN` id in a **Why** cell is a deviation an audit filed and
  resolves in `docs/audits/`; a `WG-R-NN` id is a review finding and resolves in
  `docs/reviews/2026-09-07/` as `WHATGROUP-R-NN`."*
- WG-61 evidence:
  - `docs/reviews/2026-09-07/01_FINDINGS.md:197` — `### WHATGROUP-R-06 — \`Compat.IsSpellKnown\` is the one spell shim with no modern-namespace rung`.
  - `grep -rln -- 'WG-A-08' docs/audits docs/reviews` → only `docs/audits/2026-09-07/02_DEVIATIONS.md`
    and four `docs/audits/2026-09-08/*` files, all of which quote this row. No bundle defines it.
  - `grep -rln 'WG-37'` → `docs/audits/2026-08-04/*`, and the prior bundle names the 2026-08-05 run.
- WG-63 evidence:
  - `tests/test_register.lua:94` — `if section:sub(pos - 1, pos - 1) ~= "-" and not id:find("%-R%-") and not seen[id] then`.
  - `:59` — `local function isAssigned(id, files)`.
  - `git log --oneline -3 -- tests/test_register.lua` → `e735453 M5-02: …` is the latest.
- WG-78 evidence: the standard's `localization.md` §3 reads *"a row in its `## Documented deviations`
  register (documentation-§3) citing `localization-§1`"*. The row at `:503` cites `` `localization-§3` ``.

**Trigger evaluation** (TOC-loaded source scope):

```sh
git ls-files 'core/*.lua' 'modules/*.lua' 'settings/*.lua' 'defaults/*.lua' 'locales/*.lua' \
  | xargs grep -nE 'ScheduleRepeatingTimer|NewTicker|SetScript\("OnUpdate"'
# modules/Frame.lua:486:        cooldownTimer = WhatGroup:ScheduleRepeatingTimer(function()
grep -rnE 'UnitGetTotalAbsorbs|UnitGetTotalHealAbsorbs|UnitGetIncomingHeals|UnitHealth|UnitHealthMax|UnitThreatSituation|UnitDetailedThreatSituation|C_UnitAuras|GetPlayerAuraBySpellID|"UNIT_AURA"' core defaults locales modules settings | wc -l
# 0
ls locales      # enUS.lua
grep -n 'print(\.\.\.)' settings/*.lua
# settings/Panel.lua:27:    print(...)      settings/Schema.lua:52:    print(...)   (fallback branch, unreachable)
```

- `WhatGroup.toc:48` → `core\WhatGroup.lua`. The `settings\` files are at `:78`, `:82-84`. The popup
  still parents a secure child: `modules/Frame.lua:725` —
  `local teleportBtn = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")`. The single footer
  button is at `modules/Frame.lua:770` — `local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")`.
- Did a cited rule change since the row was decided? These commands ran in the local
  `../WowAddonStandards`, which was used for history only:
  - `git log --since=2026-09-08 -- standards/standards/performance.md` → `a773e97`, `ad9a66c`. Their
    hunks are at `@@ -138` (§6) and `@@ -272` (§10). §12 is untouched.
  - `git log -S 'Secure/action-button content is the exception' -- standards/standards/standalone-windows.md`
    → `070caf2 2026-07-13`, which predates the 2026-09-12 row.

**Issue store:**

```sh
gh issue list --state all --limit 200 --json number,title,state,labels,url   # 22 issues
```

- Open: #1, #2, #4, #22 (`state:triaged`).
- Closed will-not-do: #5, #7, #9, #10, #11, #12, #13, #14, #18, #21.
- Closed done: #3, #6, #8, #15, #16, #17, #19, #20.
- Every issue carries one `state:` and one `severity:` label. No title has a `[status]` prefix.
- `ls docs/pending` → *No such file or directory*.

## §C — Mechanical checks

### Lint

```sh
~/.claude/wow-addon/bin/ka0s-bounded luacheck .
# Total: 0 warnings / 0 errors in 48 files          (exit 0)
```

- **Scope:** `.luacheckrc:17` — `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }`.
  The tests are in scope, and the harness global is in `files["tests/"]` (`:62-71`). There is no
  top-level `ignore` (`:19` — `-- NO TOP-LEVEL \`ignore\`, and none is coming back (lint.md, …)`).
- WG-83: `.luacheckrc:13` — `-- linted (lint.md). Under docs/ only the FROZEN evidence bundles are excluded; a blanket docs/`.

### Headless suite

```sh
~/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua
# 727 passed, 0 failed, 0 skipped, 727 total        (EXIT=0)
/usr/bin/time -f 'wall=%e …' ~/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua
# wall=7.24 cpu_user=1.24 cpu_sys=0.69 maxrss_kb=21976
~/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua --list | diff -q - docs/test-cases.md   # identical (CR-stripped)
```

- `docs/test-cases.md` has `| **Total** | **727** |`, and `README.md:7` reads `Tests-727%2F727_passing`.

### Complexity, run verbatim

```sh
~/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
# No thresholds exceeded …
# Total nloc 10462  Avg.NLOC 6.7  AvgCCN 1.8  Avg.token 49.1  Fun Cnt 1368  Warning cnt 0
lizard --version   # 1.24.0
```

- Top CCN at HEAD: `14 WhatGroup@980-1055@./modules/Frame.lua`, then
  `13 WhatGroup@972-1041@./core/WhatGroup.lua` and `13 Helpers.Set@451-479@./settings/Schema.lua`.
- `docs/automated-tests/20260916-184548/complexity.txt` footer: `9903 6.7 1.8 49.1 1298 0`. Top CCN:
  `15 WhatGroup@865-933@./core/WhatGroup.lua`.
- Manifest `git`: `{'sha': 'd64656bba234…', 'branch': 'master', 'dirty': False}`.
  `git rev-list --count d64656bba234b790b690659f86cd0b8e428c65ee..HEAD` → **29**.
- Band at HEAD (default scope, `wc -l`): `1421 tests/test_frame.lua`, `1144 modules/Frame.lua`,
  `1099 core/WhatGroup.lua`. `RESULTS.md:69` says *"2 file(s) in the 1000–1500 band"* (WG-48).
- Watch list: `RESULTS.md:85` `modules/Frame.lua` *"… no release run has carried it yet …"*;
  `:86` `tests/test_frame.lua` *"… One release run (`bed07dd`, Release 1.4.0) has carried it …"*.
- Release run: `20260910-234511/manifest.json` → `release: '1.4.0'`, verdict green, perf `skip`
  (*"no tests/perf.lua — …"*), `ANALYSIS.md` present.

### `diff -r` of the vendored payloads, against the provenance tag

```sh
grep -n 'Bundles \[LibKa0s\]' CLAUDE.md
# 79:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.55.0 (MIT). That line is the
grep -n 'Bundles \[LibKa0s\]' README.md                                  # (no output, exit 1)
grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md   # (no output)
grep -n 'WoW_Addon_Standard' README.md
# 6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)       (bare, not linked)
grep -nE '!\[.*\]\(media/logos|<img' README.md                          # (no output)
git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C <scratch>/lk155
diff -r --strip-trailing-cr <scratch>/lk155/LibKa0s libs/LibKa0s   # (empty, exit 0)
diff -r --strip-trailing-cr <scratch>/lk155/testkit tests/_kit     # (empty, exit 0)
diff -rq <scratch>/lk155/LibKa0s libs/LibKa0s | wc -l              # 0  (bytes, too)
diff -rq <scratch>/lk155/testkit tests/_kit | wc -l                # 0
grep -c '<Script file=' libs/LibKa0s/LibKa0s.xml                   # 21
```

- `WhatGroup.toc:30` — `libs\LibKa0s\LibKa0s.xml`. It appears once, and no individual LibKa0s `.lua`
  is named.
- In-suite: `PASS libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles`,
  `PASS tests/_kit is the test kit that shipped with that release`,
  `PASS the automated-test runner is recorded executable (100755)`.
  `git ls-files -s tests/_kit/run-automated-tests.sh` → `100755 31ff9b3e… 0`.

### Line endings (`AUDIT.md` step 4, verbatim)

```sh
test -f .gitattributes                                   # present
grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes # 26:* text=auto eol=crlf
grep -nE '^\*\.(sh|py) text eol=lf$' .gitattributes      # 36:*.sh text eol=lf   37:*.py text eol=lf
grep -c ' binary$' .gitattributes                         # 20
git ls-files -z | xargs -0 -I{} sh -c '…(AUDIT.md (e) verbatim)…' 2>/dev/null | wc -l   # 0
diff <(head -n 84 .gitattributes | tr -d '\r') <(canonical client-bound body from line-endings-§5)   # empty
```

- Scope: the whole tracked set, with no exclusions. In-suite: `PASS eol: every tracked file carries
  the terminator …` and `PASS eol: .gitattributes is line-endings-5's canonical body …`.

### Packaging (`AUDIT.md` step 4, run under bash, where zsh would not word-split `$entries`)

```
(a) done                 — nothing printed: every named entry is ignored
UNACCOUNTED — .git       — (b): the one exempt entry
(c) done                 — nothing printed: no conditional entry claimed while absent
```

- `ls -a` at the root: `.claude .git .gitattributes .gitignore .luacheckrc .pkgmeta`.
  `git ls-files .claude` → 0 lines.
- `grep -n externals .pkgmeta` → `4:# declares NO externals: block …`. That is a comment, not a block.

### Logo TGA header

```python
d = open('media/logos/whatgroup.logo.128.tga','rb').read(18)
# type 2  w 128  h 128  bpp 32
```

`WhatGroup.toc:6` — `## IconTexture: Interface\AddOns\WhatGroup\media\logos\whatgroup.logo.128.tga`.

### Generators and the cap census

```sh
git ls-files '*.py' '*.sh'      # tests/_kit/run-automated-tests.sh   (vendored runner, out of scope)
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l | awk '$2!="total" && $1>1500'   # (none)
```

- `docs/ARCHITECTURE.md:523` — `### Files over the 1500-line cap`.
- `:529` — `Nothing is over the cap today. Measured 2026-09-23 with`.
- `tests/run.lua:148` — `{ name = "test_layout_cap", dir = "tests/_kit/" },`.

### Close-button grep (verbatim) and settings-window grep

```sh
grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'
# core/CoreSetup.lua:100:    function NS.MakeCloseButton() return nil end
# core/CoreSetup.lua:136:    return lib.MakeCloseButton(parent, onClick, addonName)
grep -rnE 'SettingsPanel|HideUIPanel|ToggleGameMenu|OpenToCategory' --include='*.lua' . | grep -v -e '/libs/' -e '/tests/_kit/'
# only modules/Frame.lua:547 (a comment quoting a past error) and tests/ fakes — no addon call
```

### Bus, options-content and media greps

```sh
grep -rnE '(Send|Register)Message\("Ka0s_' --include='*.lua' . | grep -v -e '/libs/' -e '/tests/_kit/'   # (none)
grep -rn 'ScrollUp-Up\|ScrollDown-Up' --include='*.lua' settings/        # (none)
grep -rn 'LSM30_' --include='*.lua' settings/                            # (none)
grep -rn 'disabledIf' --include='*.lua' settings/                        # (none)
grep -rn 'type *= *"color"' --include='*.lua' settings/                  # (none)
git ls-files 'core/*.lua' 'modules/*.lua' 'settings/*.lua' 'defaults/*.lua' 'locales/*.lua' | xargs grep -nE 'Interface\\\\'
# core/CoreSetup.lua:94   (degraded skin, Blizzard WHITE8x8)
# core/LauncherSetup.lua:54: local ICON = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.128.tga")
# settings/Panel.lua:87: local MAIN_LOGO_TEXTURE   = "Interface\\AddOns\\WhatGroup\\media\\logos\\whatgroup.logo.tga"   (WG-80)
```

### Write-path census (`architecture-§5`, TOC-loaded source)

```sh
git ls-files 'core/*.lua' 'modules/*.lua' 'settings/*.lua' 'defaults/*.lua' 'locales/*.lua' \
  | xargs grep -nE '^\s*[^-].*\b(db\.global\.[A-Za-z.]+|g\.schemaVersion|t\.hide|parent\[key\]|db\.profile\.[A-Za-z.]+)\s*=[^=]'
```

| Hit | Class |
|---|---|
| `core/Database.lua:27` `g.schemaVersion = g.schemaVersion or NS.SCHEMA_VERSION` | (c) load pass |
| `core/Database.lua:38` `g.schemaVersion = NS.SCHEMA_VERSION` | (c) load pass |
| `core/LauncherSetup.lua:102` `if t then t.hide = not shown end` | degraded `SetShown`, reached only from the helper's GLOBAL row |
| `core/Util.lua:70` `db.global.windows = db.global.windows or {}` | (e), named at `docs/ARCHITECTURE.md:106-111` |
| `modules/Frame.lua:359` `… db.global.windows.popup = nil end` | (e), named (Reset position) |
| `settings/Schema.lua:378` `if t then t.hide = not v end` | the helper |
| `settings/Schema.lua:418` `parent[key] = value` | the helper (`RawSet`) |

## §D — The stand-down census (WG-64, WG-65, WG-66)

The prompt's three orienting greps were run over **authored, TOC-loaded source**
(`git ls-files '*.lua' ':!libs' ':!tests/_kit' | grep -v '^tests/'`). The first grep is widened with
`RegisterCallback`, because an `EventRegistry` callback is a registration with a real unregister, and
`slash-commands-§7`'s carve-out does not extend to it.

```
== grep 1: what the addon registers
core/Compat.lua:156:       and EventRegistry and EventRegistry.RegisterCallback then      (presence probe, not a registration)
core/WhatGroup.lua:109:    EventRegistry:RegisterCallback("SetItemRef", function(_, linkArg)
core/WhatGroup.lua:250/269/270/271:  self.db.RegisterCallback(…OnProfileChanged/Copied/Reset…)   (setup — survives by §7)
core/WhatGroup.lua:294:    self:RegisterEvent("GROUP_ROSTER_UPDATE")
core/WhatGroup.lua:295:    self:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
core/WhatGroup.lua:301:    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStateChanged")
core/WhatGroup.lua:302:    self:RegisterEvent("PLAYER_REGEN_ENABLED",  "OnCombatStateChanged")
core/WhatGroup.lua:347:        self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnDisabledCombatEnded")   (the one sanctioned pending edge)
modules/Frame.lua:529:    f:RegisterEvent("PLAYER_REGEN_ENABLED")
modules/Frame.lua:1028:            waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
== grep 2: what it un-registers
core/WhatGroup.lua:331-334  self:UnregisterEvent(…the four…)
core/WhatGroup.lua:355, :366  self:UnregisterEvent("PLAYER_REGEN_ENABLED")
core/WhatGroup.lua:831, :879  self:CancelTimer(self.notifyTimer)
modules/Frame.lua:380      WhatGroup:CancelTimer(cooldownTimer)
modules/Frame.lua:532, :1030, :1116, :1121   frame Unregister*   (no UnregisterCallback anywhere)
== grep 3: `\benabled\b` consumers (non-comment lines): 14
```

- `grep -rn 'UnregisterCallback' core modules settings` → no output, exit 1.
- The survivor and its justification:
  - `core/WhatGroup.lua:108` — `if ADDON_LINK_TYPE then`.
  - `:109` — `EventRegistry:RegisterCallback("SetItemRef", function(_, linkArg)`.
  - `:96` — `-- The \`hooksecurefunc("SetItemRef", …)\` fallback route below has no un-hook, so the body gates`.
  - `:100` — `if NS.IsStoodDown() then return end`.
  - `:329` — `function NS.StandDown()`. Its body at `:331-348` unregisters the four AceEvent events,
    wipes the capture and calls `NS.FrameStandDown`, with no `EventRegistry` call.
- The mock models the unregister: `tests/wow_mock.lua:684` —
  `UnregisterCallback = function(_, event, owner)            -- :225-249`.
- The hub's claim (WG-65):
  - `docs/ARCHITECTURE.md:158` — `**Every row below is registered while the addon is ENABLED and gone while it is disabled**, except`.
  - `:159` — `the two \`hooksecurefunc\` rows, which have no un-hook and gate their own bodies instead, and one`.
  - `:170` — `` | `EventRegistry:RegisterCallback("SetItemRef", …, WhatGroup)` | `core/WhatGroup.lua`, file-load | … ``.
  - `:238` — `**The one sanctioned exception is a hook that cannot be undone.** \`hooksecurefunc\` has no un-hook,`.
- The survey gap (WG-66):
  - `tests/test_disabled.lua:76` — `local function regNames(mock)`.
  - `:78` — `for _, r in ipairs(mock.__registrations()) do out[#out + 1] = r.kind .. ":" .. r.event end`.
  - `:79` — `for _, r in ipairs(rawRegs(mock)) do out[#out + 1] = r end`.
  - `tests/wow_mock.lua:694` — `__callbacks = function(event) return registry[event] or {} end,`,
    which is never called from `tests/test_disabled.lua` (`grep -n 'EventRegistry\|SetItemRef' tests/test_disabled.lua` → no output).
- The rest of the stand-down is compliant. Suite lines `PASS disabled 7…`, `disabled 8…`, `disabled 9…`
  (×2), `disabled 10…` (×3), and `PASS disabled: a stand-down in combat holds the protected Hide pending,
  and one event with it`.

## §E — Debug messages pre-built before the gate (WG-69)

Scope: TOC-loaded source. Comment lines are skipped. Each call is gathered across lines until its
parentheses balance, string literals are blanked, and the remaining text is searched for `..`.

```python
# (script recorded in the audit scratch; logic as described above)
# → 17 raw hits; 1 false positive — settings/OptionsSetup.lua:188
#   `debug = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end` (the `...` vararg)  → 16 real sites
```

| Site | Text |
|---|---|
| `core/Database.lua:43` | `NS.Debug("Migrate", "v" .. tostring(from) .. " -> v" .. tostring(g.schemaVersion))` |
| `core/WhatGroup.lua:506` | `NS.Debug("Capture", "GetSearchResultInfo returned nil for id=" .. tostring(searchResultID))` |
| `core/WhatGroup.lua:786` | `NS.Debug("ChatLink", "clicked hasPending=" .. tostring(self.pendingInfo ~= nil))` |
| `core/WhatGroup.lua:818` | `NS.Debug("Notify", "skip: no pendingInfo (" .. reason .. ")")` |
| `core/WhatGroup.lua:832` | `NS.Debug("Notify", "scheduling in " .. tostring(delay) .. "s (" .. reason .. ")")` |
| `core/WhatGroup.lua:885` | `NS.Debug("Capture", "wiped (" .. reason .. ")")` |
| `core/WhatGroup.lua:916` | `NS.Debug("Roster", "inGroup=" .. tostring(inGroup)` … |
| `core/WhatGroup.lua:973` | `NS.Debug("LFG", "appID=" .. tostring(appID) .. " status=" .. tostring(newStatus))` |
| `core/WhatGroup.lua:1026` | `NS.Debug("Invite", "accepted appID=" .. tostring(appID) .. " → no capture")` |
| `core/WhatGroup.lua:1096` | `NS.Debug("Test", 'synthetic capture injected "' .. tostring(self.pendingInfo.title) .. '"')` |
| `modules/Frame.lua:425` | `NS.Debug("Frame", "teleport button pressed \226\134\146 /cast "` … `.. spellName ..` |
| `modules/Frame.lua:504` | `NS.Debug("Frame", "teleport spellID=" .. tostring(spellID)` … |
| `modules/Frame.lua:890` | `NS.Debug("Frame", info` … `and ('popup shown "' .. tostring(info.title) ..` … |
| `modules/Frame.lua:1050` | `NS.Debug("Frame", "popup built but not shown: visibility = "` … |
| `settings/Schema.lua:398` | `NS.Debug("Schema", "Get: no path -> " .. tostring(path))` |
| `settings/Schema.lua:465` | `NS.Debug("Set", tostring(path) .. " = " .. tostring(value))` |

For context, there are 38 non-comment `NS.Debug(` call lines in the same scope. Two of them are
descriptor forwarders: `core/LauncherSetup.lua:158` and `settings/OptionsSetup.lua:188`.

## §F — Citation sweep (WG-73, WG-74; WG-62 closure)

Scope: `git ls-files`, minus `libs/`, `tests/_kit/`, `docs/audits/`, `docs/reviews/`,
`docs/revendor/` and `docs/automated-tests/<run>/`, keeping `.lua`, `.md`, `.toc`, `.luacheckrc`,
`.pkgmeta` and `.gitattributes`. That is **76** files. `docs/superpowers/` is included, because
`documentation-§6`'s frozen list does not name it. `docs/test-cases.md` is included and reported
separately, because it is generated from the kit.

```
== out-of-range: 0
== bare-file-with-§N: 0          (lint/packaging/standalone-windows/… cited with a §N)
== unknown-file: 0               (e.g. code-quality-§3)
== malformed: 9
   core/LauncherSetup.lua:143: slash-commands-@   | -- GATED ON THE STAND-DOWN LATCH (slash-commands-@7). …
   docs/test-cases.md:784: line-endings-5         | - eol: .gitattributes is line-endings-5's canonical body …
   docs/test-cases.md:788: localization-5         | - prose: no authored file carries a British spelling from localization-5's …
   docs/test-cases.md:789: localization-5         | - prose: the gate carries localization-5's two lists whole, …
   docs/test-cases.md:808: layout-1               | - layoutcap: every over-cap census row carries one of layout-1's …
   tests/prose_waivers.lua:2: localization-5      | -- (tests/_kit/test_prose.lua, localization-5).
   tests/prose_waivers.lua:4: localization-5      | -- A waiver is localization-5's MAY for a British spelling …
   tests/run.lua:140: localization-5              | -- The US-English prose gate (localization-5) is the kit's too, …
   tests/run.lua:145: layout-1                    | -- The layout-1 cap gate, new in kit revision 25: …
== dotted §N.M: 0
```

- Authored sites: **5** (WG-73). Generated from the kit: **4** (WG-74). The kit origin, over the
  tracked `tests/_kit/` only (the vendored copy is excluded from the sweep above):

  ```sh
  git ls-files tests/_kit | xargs grep -cE '\b(localization|layout|line-endings|testing|documentation|library-stack|automated-tests|slash-commands|options-ui|performance|toc-file|events-frames-taint|debug-logging|architecture|savedvariables|launcher)-[0-9]+' | grep -v ':0$'
  # tests/_kit/framework.lua:5   tests/_kit/test_eol.lua:25   tests/_kit/test_layout_cap.lua:9   tests/_kit/test_prose.lua:35
  # total lines: 74
  ```

  Samples: `tests/_kit/test_eol.lua:687` (`line-endings-5`), `test_prose.lua:89` (`localization-5`),
  `test_prose.lua:938` (`testing-12`), `test_layout_cap.lua:249` (`layout-1`).
- WG-62 closure: `grep -rn 'lint-§\|code-quality-§' core modules settings tests/*.lua docs/*.md .luacheckrc | wc -l` → **0**.

## §G — `docs/` shape (WG-75, WG-76, WG-77)

```sh
git ls-files 'docs/*.md' 'docs/**/*.md' | grep -vE '^docs/(audits|reviews|revendor|superpowers|investigations)/|^docs/automated-tests/[0-9]{8}-[0-9]{6}/|^docs/perf-analysis/[0-9]{8}-[0-9]{6}/'
# 18 files: ARCHITECTURE.md automated-tests/README.md automated-tests/RESULTS.md common-tasks.md compat-layer.md
#           data-flow.md debug.md frame.md midnight-quirks.md module-map.md performance.md schema.md scope.md
#           settings-panel.md slash-dispatch.md smoke-tests.md test-cases.md testing.md
# rows in ## Documentation map (:440-483): 20; orphans: ARCHITECTURE.md only (self-row is a MAY);
# rows with no file: message-bus.md, profiles.md, perf-analysis/README.md — each a "Not applicable" row
```

- Excluded stores, read from `documentation-§3`: `docs/audits/`, `docs/reviews/`,
  `docs/automated-tests/<run>/`, `docs/perf-analysis/<run>/`, `docs/revendor/<date>-v<tag>/`,
  `docs/superpowers/`, `docs/investigations/`. The hub's own sentence at `:443` names the five it has.
- Tier 2 triggers, counted against the code:
  - `slash-dispatch.md`: `COMMANDS` holds 13 rows (`settings/Slash.lua:40-70`), which is ≥ 8.
  - `compat-layer.md`: `grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua` → **6**
    (`:67`, `:82`, `:108`, `:123`, `:135`, `:154`), which is ≥ 3.
    - `core/Compat.lua:50` — `Compat.GetSpellName = CompatLib and CompatLib.GetSpellName or function() return nil end`.
    - `:58` — `Compat.GetSpellTexture = CompatLib and CompatLib.GetSpellTexture or function() return nil end`.
    - `docs/ARCHITECTURE.md:464` — `` | `compat-layer.md` | Present | `core/Compat.lua` publishes eight addon-specific shims, over the three-or-more threshold | ``.
    - `docs/compat-layer.md:21` — `` | Spell | `GetSpellName(spellID)` | **the library's**: `C_Spell.GetSpellName` → … ``.
    - `:22` — `` | | `GetSpellTexture(spellID)` | **the library's**: `C_Spell.GetSpellTexture` → `GetSpellTexture`, one value | `nil` | ``.
  - `debug.md`: no dump verb and no window beyond the library console (see §C, `COMMANDS`).
    - `docs/ARCHITECTURE.md:462` — `` | `debug.md` | Present | The addon’s own debug surface beyond the library console | ``.
    - `docs/debug.md` headings include `## The window` (`:108`), `## Line format` (`:158`),
      `## Font` (`:251`) and `## Copy / Clear` (`:291`).
- Hub size: `wc -l docs/ARCHITECTURE.md` → **533**. Section starts: `:193` `## The stand-down`,
  `:313` `## Invariants worth not breaking`, `:349` `## External dependencies`, `:367` `## Load order`.
  Every mandated section is under ~60 lines. `## Settings Schema` runs `:63-120` (58 lines).
- Drift (WG-77):
  - `README.md:41` — `… Your settings persist, and so do the places you dragged the two windows to. …`.
  - `README.md:48` — `| Is anything saved between sessions? | Your settings, plus where you've dragged the popup and debug windows. …`.
  - `docs/debug.md:119` — `- **It does not remember its position.** The library owns the drag bar and`.
  - `libs/LibKa0s/DebugLog.lua:398` — `bar:SetScript("OnDragStop", function() parent:StopMovingOrSizing() end)`, with no save.
  - `docs/ARCHITECTURE.md:19` — `(FIFO queue + appID map)   \`notifiedFor\` flag prevents double-fire)`.
  - `docs/module-map.md:68` — `- [data-flow.md](./data-flow.md) — LFG state machine + FIFO + the details chat link …`.
  - `docs/data-flow.md:102` — `## Why a table keyed by \`searchResultID\`, not a single slot or a queue`.
  - `docs/ARCHITECTURE.md:55` — `| The shared library, its eight seams and the degraded install | …` (nine files listed).
  - `:319` — `… core/CoreSetup.lua, core/DebugLogSetup.lua, core/LauncherSetup.lua, settings/OptionsSetup.lua and settings/Slash.lua … because the other three read it on both paths; …`.
  - `:383` — `1. **libs/** — … → **\`LibKa0s\`** (last, via its own \`LibKa0s.xml\`, which spells out \`Core\` → \`Env\` → \`Pool\` → … → \`Perf\` → \`PerfPanel\`; …`.
    `grep -oE 'file="[^"]+"' libs/LibKa0s/LibKa0s.xml` → 21 files, including `Compat.lua`,
    `Lifecycle.lua`, `Bus.lua`, `Schema.lua` and `WidgetsDragHandle.lua`.
  - `:502` contains `the row above names` and `in favor of the exemption row above`. The row they
    refer to was retired at `:508` (`**Retired on 2026-09-08: the claimed \`performance-§12\` exemption.**`).
  - `core/MediaSetup.lua:33` — `-- own close controls, and modules/Frame.lua simply skips the mark beside its`.
- WG-56: `docs/settings-panel.md:331` holds the table header `| # | Tab | Rows | Subgroups | What it is for |`,
  with rows 8/8/3 at `:333-335`.

## §H — Re-vendor bundles (WG-71), `AUDIT.md`'s check verbatim

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)   # 2026-08-25
# vendored (payload side, CLAUDE.md at each commit touching libs/LibKa0s):
v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.24.0 v1.25.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0 v1.31.0 v1.32.0 v1.33.0
v1.34.0 v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.44.0 v1.45.0 v1.46.1 v1.47.0
v1.50.0 v1.51.0 v1.52.0 v1.53.0 v1.55.0                                                   # 31
# recorded (folder tag, else 01_DELTA.md first line):
v1.15.0 v1.25.0 v1.30.0 v1.31.0 v1.32.0 v1.33.0 v1.34.0 v1.55.0
grep -vxF -f recorded.txt vendored.txt | wc -l                                            # 25
git log --since=2026-08-25 --format=%h -- libs/LibKa0s | wc -l                            # 32
```

- Bundle heads (`head -1 */01_DELTA.md`):
  - `2026-08-25` → `… vs LibKa0s v1.15.0`
  - `2026-09-03` → `LibKa0s v1.24.0 → v1.25.0`
  - `2026-09-12` → `v1.29.0 → v1.30.0`
  - `2026-09-12-v1.31.0`, `v1.32.0`, `v1.33.0`
  - `2026-09-13-v1.34.0`
  - `2026-09-23-v1.55.0` → `# Re-vendor delta: LibKa0s v1.54.2 -> v1.55.0`
- The newest bundle covers one step only. No bundle names the v1.35.0 → v1.53.0 span, and no bundle
  names the v1.18.0 → v1.24.0 span.
- Folded re-vendors:
  - `f98ef41 2026-08-26 v1.18.0 | Adopt options-ui-§12: …`
  - `127baa1 2026-09-02 v1.24.0 | feat(settings): master controls …`
  - `f74893a 2026-09-17 v1.42.0 | Disabling the addon stands it down, …`
- The playbook's own grade for this check: `AUDIT.md` step 4 — *"A tag vendored with no bundle naming
  it and no `## Documented deviations` row saying why is a **High** finding."* Step 5 — *"A **doc-only
  or config-only failure is Low or Info even when the rule it fails is a MUST**"*. See 02 WG-71 and
  WG-82.

## §I — Per-finding citations not quoted above

- **WG-57** —
  - `core/WhatGroup.lua:294` — `self:RegisterEvent("GROUP_ROSTER_UPDATE")`.
  - `docs/ARCHITECTURE.md:124` — `**There is none, because** WhatGroup is a single-addon capture pipeline with no cross-module`.
  - The standard (`architecture.md` §4) says: *"This MUST binds an addon with **two or more feature
    modules**, or **any module that registers game events**."*
- **WG-67** —
  - `core/WhatGroup.lua:293` — `local function registerFeatureEvents(self)`.
  - `:294-295`, `:301-302` — the four bare `self:RegisterEvent(…)` calls.
  - `:373` — `registerFeatureEvents(self)`, the first statement of `OnEnable`.
  - `:388` — `self.Settings.Register()`.
  - `:397` — `if NS.Launcher then NS.Launcher:Register() end`.
  - `:405` — `NS.Lifecycle:Set(NS.HOLD_DISABLED, not (self.db and self.db.profile and self.db.profile.enabled))`.
  - `grep -rn 'pcall' core/WhatGroup.lua` has one hit, `:552`, on `GetApplicationInfo`. None is on
    a registration.
  - `grep -rn 'IsEventValid' core modules settings` → no output.
- **WG-68** —
  - `modules/Frame.lua:526` — `local function deferTeleportUntilCombatEnds(info)`.
  - `:529` — `f:RegisterEvent("PLAYER_REGEN_ENABLED")`.
  - `:530` — `f:SetScript("OnEvent", function(self, ev)`.
  - `:1026` — `buildWaitFrame = buildWaitFrame or CreateFrame("Frame")`.
  - `:1028` — `waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")`.
  - Teardown at `:1116` — `f:UnregisterEvent("PLAYER_REGEN_ENABLED")`, and `:1121` —
    `buildWaitFrame:UnregisterAllEvents()`.
  - History: `git log -S 'events-frames-taint'` shows the carve-out subsection added in `957b3c5`
    (v2.63.0, 2026-09-23), with hunk `+#### The one permitted private frame — a \`RegisterUnitEvent\` filter`.
- **WG-70** —
  - `WhatGroup.toc:41` — `core\Util.lua`.
  - `:42` — `core\Compat.lua`.
  - `:43` — `# The LibKa0s-Env seam. After Compat, and before settings\Panel.lua and settings\Slash.lua,`,
    which is EnvSetup's comment and not Compat's.
  - `core/WhatGroup.lua:87` — `local ADDON_LINK_TYPE    = NS.Compat.AddOnLinkType()`.
  - `git log -S 'NS.Compat.AddOnLinkType()' -- core/WhatGroup.lua` → `fcf8197 2026-09-12`.
- **WG-72** —
  - `tests/test_surface_parity.lua:3` — `-- WhatGroup adopts five LibKa0s seams with a degradation arm — Core, DebugLog, Slash, Options and`.
  - Suite lines `PASS parity: …` ×5: Core, DebugLog, Slash, Options, Compat.
  - `tests/test_launcher.lua:391` — `test("launcher: with LibKa0s absent the seam still answers every member", function()`.
  - Live members: `libs/LibKa0s/Launcher.lua:197`, `:250`, `:259`, `:270`, `:285` (`Register`,
    `IsRegistered`, `Object`, `IsShown`, `SetShown`); `libs/LibKa0s/Lifecycle.lua:137`, `:151`, `:163`,
    `:168`, `:173`, `:179`, `:193`, `:199` (`Hold`, `Release`, `Set`, `IsHeld`, `IsDown`, `Holds`,
    `Reevaluate`, `PrintHolds`).
  - Stubs: `core/LauncherSetup.lua:86-105`, `core/LifecycleSetup.lua:66-81`.
- **WG-76** — see §G.
- **WG-79** —
  - `DEPENDENCIES.md:190` — `  not build outputs. No image or font tooling is required, because nothing regenerates them from`.
  - `:192` — `  the author prefers; there is no committed pipeline to reproduce.`
  - `:92` — `### 2.3 lizard — **optional**, for the complexity report`.
  - `:97` — `- Not needed to build, run or test the addon. Absent \`lizard\` means the recorded complexity output is`.
- **WG-80** — `settings/Panel.lua:87`, quoted in §C. `core/LauncherSetup.lua:54-55` builds its path
  from `addonName`. Issue #17: *"WHATGROUP-R-12: settings/Panel.lua:207 hardcodes "WhatGroup" where
  the file already binds the vararg"* (closed, done).
- **WG-81** —
  - `core/LauncherSetup.lua:148` — `onClick = function()`.
  - `:152` — `or "Ka0s WhatGroup is disabled.")`.
  - `settings/Slash.lua:168` — `DisabledLine    = function()`.
  - `:169` — `return "Ka0s WhatGroup is disabled \226\128\148 enable it with |cFFFFFF00/wg enable|r"`.
- **WG-82** —
  - `.pkgmeta:30` — `  - media/logos/*.png`.
  - `:31` — `  - media/logos/*.jpg`.
  - `:27` — `  # Only the .tga logo is loadable at runtime; WoW cannot read .png or .jpg at all. The master .png`.
  - Sibling TOCs: `for d in */; do grep -m1 '^## Interface' $d*.toc; done` → `120100` in all twelve
    TOCs present.

## §J — Closure evidence

- **WG-51:** `tests/_kit/vendor_sync.lua:371` — `local line = rootGit(('ls-files -s -- "%s"'):format(RUNNER))`.
  `:373` — `T.assertEqual((line:match("^(%d+)%s")), "100755",`. The suite line is PASS.
- **WG-54:**
  - `core/WhatGroup.lua:60` — `-- forwarded them on, so \`text\`, \`button\` and two varargs traveled into handler bodies that read`.
  - `:979` — `-- Deliberately empty, and the emptiness is the behavior: "invited" is the client asking`.
  - `PASS prose: no authored file carries a British spelling from localization-5's published list`.
  - `PASS prose: the gate carries localization-5's two lists whole, and nothing of its own`.
  - Waivers: `tests/prose_waivers.lua:22-31`, four per-file, per-word `cancelled` entries, each with a reason.
- **WG-58:** packaging check (c) prints nothing, and `.superpowers` is absent.
- **WG-62:** §F, 0 hits.
