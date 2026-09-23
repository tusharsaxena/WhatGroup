# WhatGroup — full-scope review, 2026-09-23

**Verdict: minor issues.** Two High functional bugs on the combat path of the popup (both
reproduced headlessly against the shipped mock, both needing an in-client confirmation), one
latent SavedVariables-migration defect inherited from the standard's own template, one degraded-
path reset that reports success while doing nothing, and a tail of Medium/Low hygiene. Nothing
blocks a release on a default profile; F-001 and F-002 should land before the next tag.

Reviewed at `feat/2026-09-23-review-audit-remediation` @ `1124ac4`, addon v1.4.0, bundling LibKa0s
v1.55.0. Standard cross-check against **Ka0s WoW Addon Standard v2.64.0 (2026-09-23)**, fetched
verbatim with `curl` from `raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`.

## Measurement run (Step 0 — measured today, not read off disk)

`ka0s-bounded` is not on `PATH` in this shell, but it is installed at
`~/.claude/wow-addon/bin/ka0s-bounded` and every run below went through it by absolute path
(abbreviated `B` here). No run hit 124 or 137. All fresh output was written to a scratch path
outside the repo; no committed artifact was touched.

| Suite | Result | Command (from repo root) |
|---|---|---|
| luacheck | **pass**: 0 warnings / 0 errors in 48 files | `B luacheck .` |
| Headless suite | **pass**: 727 passed, 0 failed, 0 skipped, 727 total | `B lua5.1 tests/run.lua` |
| Fresh `--list` inventory | **727 cases**. It matches the committed `docs/test-cases.md` exactly (CR-normalized `diff` is empty) | `B lua5.1 tests/run.lua --list > $SCRATCH/test-cases.md` |
| `tests/perf.lua` | **ran**, 8 scenarios. `cooldownTick` 2.0 api/iter and 240.4 B/iter, `formatDurationLong` 34.5, `formatDurationShort` 0.8, `combatGateSteady` 0.0/0.0, `combatGateFlipping` 7.0 and 1064.1, `showFrameRepeat` 18.0 and 1872.5, `applyScale` 1.0/0.0, `applyAlpha` 1.0/0.0 | `B lua5.1 tests/perf.lua` |
| lizard | **pass**: 0 functions warned. 1368 functions, 10462 NLOC, avg CCN 1.8, **max CCN 14** (`WhatGroup:ShowFrame`, `modules/Frame.lua:980-1055`) | `B lizard -l lua -x "./libs/*" -x "./tests/_kit/*" . > $SCRATCH/lizard.txt` |
| `make test` | **skipped**: there is no root `Makefile` | none |
| Vendor sync | **pass**: both `diff -rq` runs are empty. The in-suite tag gate (`libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles`, `tests/_kit is the test kit that shipped with that release`) is green against v1.55.0. The sibling checkout is at `v1.55.0-3-g46ccaa6` | `diff -rq libs/LibKa0s ../LibKa0s/LibKa0s`; `diff -rq tests/_kit ../LibKa0s/testkit` |
| Cross-addon: slash tokens | **clean**: 20 roots across 10 addons, 0 duplicates, 0 raw `SLASH_*` in TOC-loaded source | the two loops in *The cross-addon pass*, run over the TOC-derived load list |
| Cross-addon: vendored minors | **clean**: one line for all ten, `Bus:1 Compat:1 Core:7 DebugLog:12 Env:1 Item:1 Launcher:1 Lifecycle:1 Media:3 Options:23 Perf:12 Pool:3 Schema:1 Slash:14 Widgets:9` | `grep -rhoE 'local MAJOR, MINOR = …' <addon>/libs/LibKa0s \| … \| sort -u` |
| Cross-addon: payload bytes | **clean**: `diff -rq WhatGroup/libs/LibKa0s <addon>/libs/LibKa0s` is empty for all ten (reference: WhatGroup) | as in the section |
| Cross-addon: `## Interface:` | **clean**: `120100`, uniform | `grep -h '^## Interface:' <addon>/*.toc \| tr -d '\r' \| sort -u` |

**Cross-addon scope.** The addon set is the ten Ka0s addons (the nine the review brief lists plus
AuraMaster, which the collection roster now counts). Each count is scoped to the addon's
**TOC-derived load list** (`tr -d '\r' < *.toc | grep -iE '\.lua$' | grep -v '^#'`). **How this
departs from the 2026-09-07 baseline:** every change is directional and none is a finding. The
Interface value moved from `120007` to `120100` (a patch bump, still uniform). The minors moved up
with LibKa0s v1.55.0 and there are now 15 majors, not 10. There are 20 roots rather than 18 because
AuraMaster adds `am` and `auramaster`. PrettyChat's two former CR-only stragglers are now
byte-identical.

**Committed artifacts that disagree with today's run:**

- `docs/automated-tests/RESULTS.md` is **stale, not non-compliant**. Its newest bundle,
  `20260916-184548` (manifest: SHA `d64656b`, v1.4.0), records 667 tests, NLOC 9903, 1298 functions,
  max CCN 15 and two files in the `layout-§1` 1000–1500 band. Today's run measures 727 tests, NLOC
  10462, 1368 functions and max CCN 14, and finds **three** files in the band, because
  `core/WhatGroup.lua` (1099 LOC) has crossed into it since then (see F-014).
- `docs/test-cases.md` **agrees** with today's run (727).
- `docs/performance.md` **agrees** on every `api/iter` and `bytes/iter` figure. Its call-site census
  (`grep -rnE 'RegisterEvent|SetScript\("OnUpdate"|C_Timer|ScheduleRepeatingTimer|ScheduleTimer|hooksecurefunc' core modules settings defaults locales`)
  re-measures at **20 lines across 4 files**, which is the number the page gives.

**Not run here, and why.** Nothing in this step needs the game client. Every in-client check
(the two High repros, the taint checks, the cross-addon dispatch check) is a checklist in
`03_SMOKE_TESTS.md`.

**Scratch repros.** F-001, F-002 and F-004 were reproduced with a throwaway suite,
`tests/test_zrepro.lua`, run in a **scratch copy** of the tracked tree
(`git ls-files | grep -v ^docs/`, copied to `$SCRATCH/wgcopy`). No file in the repo was edited.
The copy leaves out `docs/`, so its doc-structure cases fail by construction. Only the repro cases'
output is quoted.

---

## High

### F-001 — Reopening a soft-hidden popup in combat with no capture calls `Hide()` on the secure teleport button `[taint]` `[ux]`

- **Where:** `modules/Frame.lua:852`, `fields.teleportBtn:Hide()`. This is `PopulateFields`'
  no-capture branch. It is reached through `preparePopup` (`modules/Frame.lua:888-893`) from
  `ShowFrame`. The combat defer at `modules/Frame.lua:1014`,
  `if InCombatLockdown() and not (f and f:IsShown()) then`, only covers a popup that is **not**
  shown, so a popup soft-hidden at alpha 0 passes straight through to it.
- **Problem:** `teleportBtn` is a `SecureActionButtonTemplate` child. `Hide()` on it is protected
  under lockdown, and this branch calls it without the guard that `endTestMode` carries for exactly
  this reason (`modules/Frame.lua:947`,
  `if fields and not InCombatLockdown() then PopulateFields() end`). The teleport-configure path is
  guarded (`deferTeleportUntilCombatEnds`). This path is not.
- **Impact:** the client refuses the call and raises `ADDON_ACTION_BLOCKED` naming WhatGroup. That
  is the same class of error this file has been fixed for three times already.
- **Reachability:** a player who, **during combat**, reopens the popup from the **minimap button**
  (`ToggleFrame`, launcher-§2 rung (a)) after it was closed or gate-hidden mid-fight, **with no
  capture pending**. Two ordinary ways to be in that state: the popup was opened on its "No data"
  fallback, or the capture was wiped when the player left the group. `/wg show` and the chat link
  refuse the no-capture case before they reach `ShowFrame`, so the launcher is the one route in.
- **Evidence:** a scratch repro (enable, show with a teleport, enter combat, press Close, clear
  `pendingInfo`, call `ToggleFrame()`) records `mock.blocked = { "<anonymous>:Hide()" }`. The anonymous
  frame is the teleport button. Whether the client also blocks `Hide()` on a protected button that is
  **already hidden** (the "No data" variant) is **unverified** headlessly: the mock blocks it, and
  `03_SMOKE_TESTS.md` S-001 confirms it in the client.
- **Coverage:** none. See F-006.
- **Fix direction:** the no-capture branch must go through the same combat-deferred path the
  capture branch uses (events-frames-taint-§2). Never call a protected `Hide` under lockdown.

### F-002 — `preparePopup` restores the alpha of a soft-hidden popup before the visibility gate is asked `[ux]` `[logic]`

- **Where:** `modules/Frame.lua:888`, `WhatGroup:ApplyFrameAlpha()`, which runs unconditionally
  inside `preparePopup`. `ApplyFrameAlpha` itself is `modules/Frame.lua:148-151`
  (`f:SetAlpha(masterAlpha())`) and has no knowledge of `softHidden`. The gate is asked only
  afterwards (`modules/Frame.lua:1045`, `if not visibilityAllows() then`).
- **Problem:** a popup soft-hidden at alpha 0 (the combat stand-in for a refused `Hide`) is put
  back on screen by any `ShowFrame` call. If the gate then declines, `ShowFrame` returns with the
  popup **visible** and `softHidden` still `true`. From then on `onScreen()`
  (`modules/Frame.lua:284-286`) answers "off screen" for a popup the player can see.
- **Impact:**
  - Under **General visibility = Only out of combat**, the gate's hide at the pull is undone by the
    player's next `/wg show`, chat-link click or minimap click, while the fight is still on.
  - The **minimap button can no longer close it**: `ToggleFrame` (`modules/Frame.lua:1076`,
    `if onScreen() then`) takes the open arm again, and that arm restores the alpha again.
  - **Escape does nothing either**, because the ESC proxy stayed hidden.
  - Only the Close button works until combat ends.
  - `/wg set alpha …` mid-combat reveals a soft-hidden popup the same way (the alpha row's
    `onChange` is `ApplyFrameAlpha`, `settings/Panel.lua:276`).
- **Reachability:** any player who sets **General visibility** to *Only out of combat*, has the
  popup up when a pull starts, and asks for it during the fight. `/wg show`, the chat link and the
  minimap button are all documented surfaces. On the shipped default (`always`) the gate never
  declines, so the default profile does not reach it.
- **Evidence:** the scratch repro (`visibility = "outOfCombat"`, show, combat, fire
  `PLAYER_REGEN_DISABLED`, `/wg show`, `ToggleFrame()`) prints `AFTER PULL shown=true alpha=0`, then
  `AFTER SHOW shown=true alpha=1`, then `TOGGLE returned=false alpha=1`. The popup is visible, and
  the launcher reports it closed and leaves it up.
- **Coverage:** none. See F-006.
- **Fix direction:** the alpha seam must answer 0 while the popup is soft-hidden. Restoring it
  belongs to `showPopup`, which already clears `softHidden` first.

## Medium

### F-003 — `global.schemaVersion` is an AceDB default, so it is never persisted and the first real migration will be skipped `[design]` `[upstream: WowAddonStandards]`

- **Where:** `settings/Schema.lua:609`,
  `global = { schemaVersion = NS.SCHEMA_VERSION or 1, windows = {},`, and `core/Database.lua:27`,
  `g.schemaVersion = g.schemaVersion or NS.SCHEMA_VERSION`.
- **Problem:** at logout AceDB's `removeDefaults` (`libs/AceDB-3.0/AceDB-3.0.lua:134`, called for
  every section at `:425`) strips any stored value equal to its default. A stamp of 1 against a
  default of 1 is stripped, so **no existing SavedVariables file carries a stamp**. The day
  `NS.SCHEMA_VERSION` becomes 2, the default becomes 2 as well. Every existing user's `g.schemaVersion`
  then reads 2 through AceDB's metatable, and the `1 → 2` step never runs. The `or` on
  `Database.lua:27` is dead on the same account: the value is never nil to begin with.
- **Impact:** the migration seam `savedvariables-§1` exists for silently does nothing, for every
  existing user, on the first release that needs it. Nothing reports it. The profile is simply read
  in its old shape.
- **Reachability:** nobody today (`SCHEMA_VERSION = 1`, and the loop at `core/Database.lua:31-36`
  is commented out). Every existing user, on the release that bumps it.
- **Coverage:** `tests/test_database.lua` "an older saved DB is stepped up to the current version"
  sets `schemaVersion = 0` **explicitly**. It never models the case that actually occurs: a stored
  file with no stamp, read against a newer default. That makes it a `testing-§12` near-miss. It
  passes, and it cannot see this.
- **Upstream note:** `savedvariables-§1`'s own template
  (`global = { schemaVersion = 1, ignored = {} }`) prescribes exactly this shape, so the hazard is
  collection-wide rather than WhatGroup's alone. The template belongs upstream as a standard
  change. It is **not** a local deviation to register.
- **Fix direction (compliant):** keep declaring `schemaVersion` in the global namespace, as
  `savedvariables-§1` MUSTs, but declare it at the **pre-versioning** value (0). Then any real
  stamp differs from the default and survives `removeDefaults`. A fresh DB steps through the
  (idempotent) chain once.

### F-004 — The Options degradation stub overwrites the host's real `RestoreAllDefaults` with a no-op `[design]`

- **Where:** `settings/OptionsSetup.lua:150`, `H.RestoreAllDefaults   = function() end`. On the
  degraded path `H` **is** the host table, the one `settings/Schema.lua:691` hung the real
  `Helpers.RestoreAllDefaults` on.
- **Problem:** the stub means to add inert members for shape. This one replaces a live host member
  instead. `/wg resetall` still answers: it is a host verb, and `runResetAll` finds a
  `RestoreAllDefaults` (`settings/Slash.lua:396-405`). After confirmation the popup's `OnAccept`
  runs `Helpers.RestoreAllDefaults()` (`settings/Schema.lua:791`), which is now a no-op, and then
  prints `L["all settings reset to defaults"]` (`settings/Schema.lua:792`).
- **Impact:** a false success line. The player is told their settings are reset while nothing
  changed. `options-ui-§1` says the stub **SHOULD** keep the global-reset entry point real, because
  a player whose panel will not open is exactly the one who needs it.
- **Reachability:** any install on which `libs/LibKa0s` fails to load (a partial or corrupt
  download), when the player runs `/wg resetall` and confirms. This is a degraded path, but a real
  one reachable by a documented verb, so it is not capped.
- **Evidence:** a scratch repro loads with `NO_LIBKA0S` skipped, sets `notify.delay = 7` and calls
  `Settings.Helpers.RestoreAllDefaults()`. It prints `DELAY after direct RestoreAllDefaults: 7`.
- **Coverage:** none. `tests/test_libka0s.lua`'s degraded block pins `enable`/`disable` and
  `test on|off` (`:637-661`), but not `resetall`.

### F-005 — 16 `NS.Debug` call sites build their message before the call `[perf]` `[lint]`

- **Where** (census below): `core/Database.lua:43`; `core/WhatGroup.lua:506, 786, 818, 832, 885,
  916, 973, 1026, 1096`; `modules/Frame.lua:425, 504, 890, 1050`; `settings/Schema.lua:398, 465`.
  Examples: `settings/Schema.lua:465`,
  `NS.Debug("Set", tostring(path) .. " = " .. tostring(value))`, and `core/WhatGroup.lua:973`,
  `NS.Debug("LFG", "appID=" .. tostring(appID) .. " status=" .. tostring(newStatus))`.
- **Problem:** `debug-logging-§4` **MUST NOT build the message before the call**. The sink is
  zero-allocation when off only if the arguments are. These sites concatenate unconditionally, and
  they `tostring` their values outside the sink's `safeToString`.
- **Impact:** a small, permanent allocation with debug off, on every settings write, every LFG
  application status event and every teleport configure. There is no correctness effect today (no
  value here is a secret), but the sites sit outside the secret-safe seam the standard routes every
  value through.
- **Reachability:** every player, every session. The cost is small: bytes per event, and no
  measured scenario isolates it.
- **Census:** 16 sites out of 39 `NS.Debug(` lines. Scope: tracked, authored, TOC-loaded Lua
  (`libs/` and `tests/` excluded). Command:
  ```sh
  git ls-files '*.lua' | grep -vE '^(libs/|tests/)' | xargs awk '/NS\.Debug\(/ {…paren-balanced join…; if (buf ~ /\.\./ || buf ~ /:format\(/) print FILENAME":"FNR}'
  ```
  The awk printed 17 hits. The 17th, `settings/OptionsSetup.lua:188`, is a false positive: `...`
  there is a vararg, not a concatenation.

### F-006 — No case exercises `ShowFrame` against a soft-hidden popup `[tests]`

- **Where:** `tests/test_frame.lua`. Of its 90 cases, 28 name combat in their title (`grep -c '^test(".*[Cc]ombat' tests/test_frame.lua`); the closest is
  `:684` "a popup held at alpha 0 comes back in combat without a Show". It covers only the
  path where a capture exists **and** the gate allows the show.
- **Problem:** neither the no-capture branch (F-001) nor the gate-declines branch (F-002) of a
  soft-hidden reopen has a case. Both High findings sit on a path the inventory reads as covered
  ("frame: …combat…").
- **Impact:** a combat regression of the kind this file has shipped three times can come back
  without reddening anything.
- **Reachability:** the test inventory only. The shipped behavior is covered by F-001 and F-002.

## Low

### F-007 — Stale and contradictory comments in `modules/Frame.lua` `[naming]`

- `:194-206` still describe the pre-soft-hide design. At `:199` the `outOfCombat` popup "STAYS UP
  for the fight". At `:205`, "f:Show() on an already-built frame is not a secure write". Both are
  contradicted a few lines later (`:255-258`, "SHOW IS PROTECTED EXACTLY AS HIDE IS") and by the
  behavior that `tests/test_frame.lua:1172` pins.
- `:748-751` "zero Lua-side repeat is the condition LIBKA0S-15 … rests on" is contradicted by
  `:366-369` (the repeating ticker "ends `performance-§12`'s no-combat-path exemption") and by
  `docs/performance.md`.
- `:385-402` stack four detached doc comments (a deferral function, `resolveTeleportState`, the
  note, the action) above `applyTeleportAction` alone.
- `:1003-1005` "subsequent calls are safe in combat" is contradicted by `:1006-1009`, which follow
  it immediately.
- `:608` `stopCooldownTicker(self)` passes an argument to a zero-argument function.
- **Reachability:** comments only. There is no runtime effect, but two of them misstate a taint rule
  to the next editor.

### F-008 — File headers name the wrong homes `[naming]`

`core/WhatGroup.lua:2` still says "slash dispatch" (it moved to `settings/Slash.lua`, as `:1047`
itself says). `:20`, `:44` and `:129` attribute the printer and `SafeToString` to `core/Util.lua`,
but they live in `core/CoreSetup.lua`. `core/Util.lua:2` calls `NS.Windows` "the one low-level seam"
in a file that also defines `NS.FormatDuration` (`:40`), and its Windows comment block (`:21-25`) is
separated from the Windows code by the duration section. **Reachability:** comments only.

### F-009 — Counts in comments disagree with each other and with the code `[naming]`

The composed Master-controls block is **8 rows** (measured: `enabled, visibility, scale, alpha,
locked, state.debugConsole, global.minimap.hide, state.testMode`, 19 schema rows in all). The
comments call it "seven-row" (`settings/Schema.lua:5`), "canonical nine" (`settings/Schema.lua:125`,
`settings/Panel.lua:313`), "eight" (`settings/Schema.lua:589`, `settings/Panel.lua:284`) and "six"
(`defaults/Profile.lua:15`). The collection is ten addons, but the comments say "all nine addons"
(`settings/Schema.lua:104`, `defaults/Profile.lua:25`) and "all eleven addons"
(`settings/Panel.lua:192`). `core/LauncherSetup.lua:143` cites "slash-commands-@7" for §7.
**Reachability:** comments only.

### F-010 — A locale key with no reader, and a locale header describing strings that no longer exist `[locale]`

`locales/enUS.lua:122`, `L["WhatGroup is disabled — |cffFFFF00/wg enable|r turns it back on"]`,
has no reader. The refusal line is the library's since Slash minor 13 (`settings/Slash.lua:90-98`).
The file's own header (`:33-35`) calls such a key a defect. The header also lists "the
disabled-addon refusal" as routed (`:20-21`) and cites a `"Settings layer not ready yet"` diagnostic
(`:22`) that exists nowhere in the source. **Reachability:** translator-facing surface only.

### F-011 — `.luacheckrc` grants globals no production file reads `[lint]`

`read_globals` still lists `GetSpellInfo`, `GetSpellTexture`, `GetSpellCooldown`, `CastSpellByID`
(`.luacheckrc:47`), `SettingsPanel` (`:52`) and `date` (`:54`). No authored runtime file reads any of
them, now that the spell ladder is LibKa0s-Compat's. `GetSpellInfo`, `GetSpellTexture` and
`GetSpellCooldown` are removed globals on retail, so a regression that reintroduced one would
**lint clean** and fail only in the client. **Reachability:** nobody today; a future edit.

### F-012 — Terminal application statuses missing from `APPLICATION_ENDED` `[logic]`

`core/WhatGroup.lua:936-941` ends an application on `declined`, `declined_full`,
`declined_delisted` and `cancelled`. It does not end one on `timedout`, `invitedeclined` or
`failed`, which Blizzard's LFG list code also reports as terminal (**verify** the spellings against
`LFGListUtil`/`C_LFGList` status strings at 12.1.0 before relying on this list). Those captures stay
in `capturesByResult`/`pendingApplications` until the next `inviteaccepted` or group-leave wipe.
The tables are keyed by id, so the leftover is bounded and cannot be handed to another invite.
**Reachability:** any player whose application times out or who declines an invite. The only effect
is a few stale session tables.

### F-013 — Two addon fields are written and never read, and a test pins them `[dead-code]` `[tests]`

`settings/Panel.lua:387`, `WhatGroup._settingsCategory = sub`, and `:390`,
`WhatGroup._parentSettingsCategory = parentCategory`, have no production reader. Opening the panel
goes through `Helpers.OpenOptionsPanel`, which "holds its own" (`:388-389`).
`tests/test_panel.lua:90-91` asserts they are non-nil ("the /wg config handle is kept"), which pins
dead state rather than behavior. **Reachability:** none.

### F-014 — `layout-§1` band drift since the last recorded run `[complexity]`

Today's census puts three authored files in the 1000–1500 band. Scope: tracked authored Lua,
`libs/` and `tests/_kit/` excluded, `tests/` included. Command:
`git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | tr '\n' '\0' | xargs -0 wc -l`. The three
files are `tests/test_frame.lua` 1421 (unchanged), `modules/Frame.lua` **1144** (1063 at
`20260916-184548`) and `core/WhatGroup.lua` **1099**, which is **new to the band** and absent from
`RESULTS.md`'s watch list. None is over the 1500 cap, and `test_layout_cap` is green. **Reachability:**
maintainability only. A disposition is for the next release run to record, not this review.

### F-015 — The minimap row's CLI path reads inverted `[ux]` `[upstream: WowAddonStandards]`

`settings/Schema.lua:361`, `local MINIMAP_PATH = "global.minimap.hide"`. The row's value means
**shown**, so `/wg get global.minimap.hide` answers `true` while the button is visible, and
`/wg set global.minimap.hide false` **hides** it. The path and the inversion are mandated
(`launcher-§3`, `options-ui-§15`), so WhatGroup is compliant. This is a collection-wide CLI wart to
raise on the standard, not to fix locally. **Reachability:** any player who uses the schema CLI on
this row.

### F-016 — The teleport configure allocates three closures per call `[perf]`

`applyTeleportAction` (`modules/Frame.lua:411`, `btn:SetScript("OnEnter", function(self)`, plus the
`OnLeave` and `PreClick` closures at `:416` and `:423`, and again at `:444-449`) builds fresh
closures on every configure. Together with `resolveTeleportState`'s per-call table (`:516-523`),
that is most of `showFrameRepeat`'s **1872.5 B/iter** (today's `tests/perf.lua`). The path runs once
per popup show or cooldown expiry, so this is hygiene, not a hot path. **Reachability:** every popup
show. The cost is negligible.

---

## Upstream findings (do not land in this repo)

- **F-003** and **F-015** belong to **WowAddonStandards**, not to any vendored code. F-003 is a
  defect in `savedvariables-§1`'s template. F-015 is the CLI shape `launcher-§3` fixes. Both change
  the standard first, and each addon conforms afterwards.
- **No defect was found in `libs/LibKa0s/` or `tests/_kit/`.** Vendor sync is clean, and nothing
  here proposes an edit under either path.
