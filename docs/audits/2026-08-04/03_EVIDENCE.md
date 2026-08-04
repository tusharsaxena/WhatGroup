# Ka0s WhatGroup — Evidence (2026-08-04)

Every claim in `01_CURRENT_STATE.md` and `02_DEVIATIONS.md` is sourced here. Mechanical checks were
**run**, not reasoned about; the real commands and their real output are reproduced verbatim.

---

## 0. Standard provenance

```
$ curl -fsSL --max-time 15 -o std/AUDIT.md      .../master/AUDIT.md            ; echo rc=$?
rc=0
$ curl -fsSL --max-time 15 -o std/STANDARDS.md  .../master/standards/STANDARDS.md ; echo rc=$?
rc=0
$ for f in anti-patterns architecture audit-review-history compat debug-logging documentation \
    events-frames-taint layout library-stack lint localization naming-cheatsheet open-evolutions \
    options-ui packaging performance preview-mode public-api savedvariables slash-commands \
    standalone-windows testing tiered-layout toc-file versioning-git; do
      curl -fsSL --max-time 10 -o fetched/$f.md ".../master/standards/standards/$f.md" || echo "FAIL $f"
  done
curl: (22) The requested URL returned error: 404
FAIL tiered-layout
$ ls fetched | wc -l
24
```

`tiered-layout` is **not** a live section — it appears only inside `STANDARDS.md:114`'s v2.0.0
changelog entry, which records its rename to `layout.md`. The Sections list names 24 files and all
24 fetched.

```
$ diff -r fetched ../WowAddonStandards/standards/standards/ ; echo "diff rc=$?"
diff rc=0
$ diff std/AUDIT.md ../WowAddonStandards/AUDIT.md \
  && diff std/STANDARDS.md ../WowAddonStandards/standards/STANDARDS.md \
  && echo "BYTE-IDENTICAL"
BYTE-IDENTICAL
$ cd ../WowAddonStandards && git status --porcelain && git log -1 --format='%H %s'
214122996c6c2db2e1c4a88a1f5d152dce2de928 v2.17.1 — finish the v2.17.0 rollout: no fourth slot, no drop-in imperative
```

Clean tree, no output from `--porcelain`. The network copy and the local checkout are the same
bytes, so every rule cited below is the published one. Nothing was written under
`WowAddonStandards/`.

---

## 1. `luacheck .`

```
$ luacheck .
Checking core/Compat.lua                          OK
Checking core/CoreSetup.lua                       OK
Checking core/Database.lua                        OK
Checking core/DebugLogSetup.lua                   OK
Checking core/Util.lua                            OK
Checking core/WhatGroup.lua                       OK
Checking defaults/Profile.lua                     OK
Checking defaults/TeleportSpells.lua              OK
Checking locales/enUS.lua                         OK
Checking modules/Frame.lua                        OK
Checking settings/OptionsSetup.lua                OK
Checking settings/Panel.lua                       OK
Checking settings/Schema.lua                      OK
Checking settings/Slash.lua                       OK

Total: 0 warnings / 0 errors in 14 files
```

**Clean.** The lint half of the commit gate (testing-§4) passes.

## 2. `lua tests/run.lua`

```
$ lua tests/run.lua
... (415 cases)
  PASS  debuglog: InitSummary leads with the debug-logging-§5 identity fields, then runtime state
  PASS  debuglog: enable ack is color-coded green/red matching the header (debug-logging-§5)

415 passed, 0 failed, 415 total
```

**Green.** `lua5.1` is installed (`/usr/bin/lua5.1`); `luajit` is absent, which is irrelevant — the
kit targets 5.1.

Cross-check against the generated inventory and the badge:

- `docs/test-cases.md:484` — `| **Total** | **415** |`
- `README.md:7` — `![Tests](https://img.shields.io/badge/Tests-415%2F415_passing-green)`

All three agree, so testing-§5's lockstep rule holds.

## 3. Vendored Ka0s-owned library drift (`anti-patterns` #45, #48)

Source repo located as a sibling of the addon repo:

```
$ ls -d ../LibKa0s && ls ../LibKa0s
../LibKa0s
CHANGELOG.md
LICENSE
LibKa0s          <- the ship folder
README.md
docs
testkit          <- the headless harness, a SIBLING of the ship folder
tests
```

Confirmed to be the `LibKa0s` repo (its own `CHANGELOG.md`, `tests/`, and an inner ship folder of
the same name), so the diffs below are against the correct source.

```
$ diff -r ../LibKa0s/LibKa0s /mnt/d/.../WhatGroup/libs/LibKa0s ; echo rc=$?
rc=0

$ diff -r ../LibKa0s/testkit /mnt/d/.../WhatGroup/tests/_kit ; echo rc=$?
rc=0
```

**Both empty.** No drift (#45) and no partial vendoring (#48). The check is the only thing that could
have found either: both repos are green regardless.

Whole-folder payload confirmed on disk — the addon carries every file of the ship folder, including
the two `Perf` files it does not wire:

```
libs/LibKa0s/Core.lua  DebugLog.lua  LibKa0s.xml  LICENSE  Options.lua
              OptionsScroll.lua  OptionsWidgets.lua  Perf.lua  PerfPanel.lua  Slash.lua
```

And the harness is under `tests/`, never `libs/` — `tests/_kit/{README.md, framework.lua,
loader.lua, mock_base.lua}` (testing-§1).

TOC lists the single aggregate once:

- `WhatGroup.toc:25` — `libs\LibKa0s\LibKa0s.xml`, after Ace3 and LibSharedMedia. No individual
  module `.lua` is named (toc-file-§5, library-stack-§7).

---

## 4. Evidence per deviation

### WG-30 — Perf not wired

- No `core/PerfSetup.lua` in the repo (full file listing walked; `core/` holds `Compat.lua`,
  `CoreSetup.lua`, `Database.lua`, `DebugLogSetup.lua`, `Util.lua`, `WhatGroup.lua`).
- `WhatGroup.toc:30-37` — the `# Core` block: `CoreSetup` → `Util` → `Compat` → `Database` →
  `WhatGroup` → `DebugLogSetup`. No `PerfSetup.lua` slot.
- `grep -rni perf core modules settings tests/run.lua` returns **no addon source hits** — only two
  doc mentions, `docs/ARCHITECTURE.md:104` and `:115`, both explaining the decline.
- The decision record: `docs/pending/LEDGER.md:63` — *"`LibKa0s-Perf-1.0` is declined on structural
  grounds … this is an **accepted deviation from performance-§1's MUST wiring** rather than an
  oversight — the user was asked and took it (2026-08-02)."* Two grounds given: zero `OnUpdate`,
  zero tickers, zero repeating timers (so every bucket reads `0.000`, which performance-§3 calls a
  lie in every report); and `suspend` making a capture addon miss the applies and invites it exists
  to record.
- Rule text: `performance.md:7` (*"**MUST** for the **wiring** — vendor the instrumentation lib,
  create one instance at load, expose the `perf` verb, declare `<Addon>PerfDB`, implement the
  `suspend`/`resume` contract"*) and `performance.md:14`.

### WG-31 — one SavedVariables global

- `WhatGroup.toc:7` — `## SavedVariables: WhatGroupDB`
- Rule: `toc-file.md:36` — *"**MUST** declare exactly **two** SavedVariables globals in the order
  above: `<Addon>DB` … and `<Addon>PerfDB`"*; `savedvariables.md:41`.

### WG-32 — no `perf` verb

- `settings/Slash.lua:44-67` — the `COMMANDS` table, eleven rows: `help`, `show`, `test`, `config`,
  `version`, `list`, `get`, `set`, `reset`, `resetall`, `debug`. No `perf`.
- Dispatch is exhaustive over that table (`settings/Slash.lua:94-98` in the stub arm; the library's
  dispatcher in the wired arm), so `/wg perf` reaches the unknown-verb path.
- Rule: `slash-commands.md:30` — *"`perf` … **MUST NOT** be re-used for anything else, and … the verb
  **MUST** be registered by the addon through its own `COMMANDS` table"*; `performance.md:60-64`.

### WG-33 — two required topic-detail docs absent

- `docs/` contains `ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`, `test-cases.md`,
  `capture-pipeline.md`, `common-tasks.md`, `debug-console.md`, `file-index.md`, `frame.md`,
  `scope.md`, `settings-system.md`, `slash-dispatch.md`, `wow-quirks.md`, plus `pending/`,
  `superpowers/`, `audits/`, `reviews/`. **No** `performance.md`; **no** `perf-runs/`.
- Rule: `documentation.md:87-91` — *"**Three** topic-detail docs are **required**, not optional"*,
  naming `docs/test-cases.md`, `docs/performance.md`, `docs/perf-runs/README.md`.

### WG-34 — no `tests/perf.lua`

- `tests/` contains `_kit/`, `loader.lua`, `run.lua`, `wow_mock.lua` and fourteen `test_*.lua`
  suites. No `perf.lua`.
- Rule: `performance.md:110` (*"**MUST** live at `tests/perf.lua`"*) and `:113` (the zero-overhead
  scenario as *required evidence*).

### WG-35 — `.luacheckrc` declarations

- `.luacheckrc:18-21` — `globals = { "WhatGroupDB", "StaticPopupDialogs" }`. No `WhatGroupPerfDB`.
- `.luacheckrc:25-39` — `read_globals` lists 30 symbols; `debugprofilestop` is not among them.
- Rule: `lint.md:23` (`debugprofilestop` in `read_globals`, *"ms CPU clock behind the perf brackets"*)
  and `lint.md:26-29` (`<Addon>PerfDB` in `globals`), reinforced by `lint.md:34`.

### WG-36 — `.pkgmeta` ignore list

```
$ cat .pkgmeta
package-as: WhatGroup

# Every library is vendored under libs/ and committed to git — this addon
# declares NO externals: block (§3.3, §13). The packager ships the repo as-is.

ignore:
  - .luacheckrc
  - .gitignore
  - .gitattributes
  - docs        # includes docs/audits and docs/reviews
  - tests
```

- No `externals:` — correct (packaging, anti-pattern #7). `docs` and `tests` ignored — correct.
- `_dev` absent; lockfiles absent.
- Rule: `packaging.md:24` — *"**MUST** ignore `docs/` …, `_dev/`, `tests/`, and lockfiles in the
  package"*.
- (The `(§3.3, §13)` on line 4 is the `WG-43` citation.)

### WG-37 — global `print()` fallbacks

```lua
-- settings/Panel.lua:20-25
-- Chat-out via WhatGroup._print so the cyan [WG] prefix lives in one place (mirrors
-- settings/Schema.lua's pout).
local function pout(...)
    if WhatGroup._print then return WhatGroup._print(...) end
    print(...)
end
```

```lua
-- settings/Schema.lua:44-51
-- Single chat-out routed through WhatGroup._print so the cyan [WG] prefix
-- lives in exactly one place. Falls back to raw print only if this file
-- somehow loads before WhatGroup.lua has set _print (shouldn't happen
-- given the TOC order, but the fallback keeps the panel from going dark).
local function pout(...)
    if WhatGroup._print then return WhatGroup._print(...) end
    print(...)
end
```

Reachability: `core/WhatGroup.lua:83` sets `WhatGroup._print = p`, and `WhatGroup.toc:32-50` loads
`# Core` before `# Settings`, so the second arm is dead code today.

- Rule: `events-frames-taint.md:108-113` — call sites **MUST NOT** *"call the global `print()`
  directly (it neither carries the `NS.PREFIX` tag nor secret-stringifies its args)"*, and
  *"non-compliant even if it is never handed a secret today"*. The single sanctioned second copy is
  `events-frames-taint.md:104-106` — the library-absent branch **in `core/CoreSetup.lua`**.
- The sanctioned copies, for contrast: `core/CoreSetup.lua:65`, `:70` (inside `if not lib`) and
  `:128` (the descriptor's `sink`, which is how the line reaches chat at all in this addon and is a
  library-invoked callback, not a call site).

### WG-38 — extra README section

```
README.md:75   ## How it works
README.md:81   ## Bundled libraries
README.md:85   ## FAQ
```

Line 83 is the section body — the vendored stack, LibKa0s v1.5.0 (MIT), and the license path.

- Rule: `documentation.md:29` — *"Every Ka0s `README.md` **MUST** follow one structure so all addons
  read identically … Sections in **this exact order**"*, the twelve-item list at `:31-59`;
  `anti-patterns.md:34` (#28).
- Everything else checks out: badges at `README.md:3-7` in canonical order with the `_` standard
  badge; logo `:9`; `## What's new in 1.3.0` `:18` immediately above `## Screenshots` `:27`; Usage
  `:41` with both subsections; Issues `:110`; Version History `:114` whose top row matches What's
  new. The only `<…>` in shipped content is `<br>` inside Version-History table cells
  (`README.md:118-119`) — deliberate HTML, which `documentation.md:26-27` protects from a sweep.

### WG-39 — `docs/ARCHITECTURE.md` headings

```
$ grep -n '^#\{1,3\} ' docs/ARCHITECTURE.md
1:# Architecture
5:## What it does
11:## Subsystems at a glance
57:## Invariants worth not breaking
85:## Working environment
91:## External dependencies
108:## Load order
```

Mapped against `documentation.md:83`'s list — *"Sections: Overview, Module Map, Settings Schema,
Message Bus (named messages with sender/payload/consumers), Slash Commands (table from
`NS.COMMANDS`), Event Subscriptions, Taint Notes, Known Limitations"*:

| Required | Present as |
|---|---|
| Overview | `## What it does` (`:5-9`) |
| Module Map | `## Subsystems at a glance` table (`:42-55`) |
| Settings Schema | **absent** — delegated to `docs/settings-system.md` (`:47`) |
| Message Bus | **absent** — and the addon has none (`grep SendMessage\|RegisterMessage core modules settings` → no hits) |
| Slash Commands table | **absent** — delegated to `docs/slash-dispatch.md` (`:48`) |
| Event Subscriptions | `## Load order` → Lifecycle (`:134`) |
| Taint Notes | `## Invariants worth not breaking` (`:59`, `:72`) |
| Known Limitations | **absent** |

### WG-40 — combat-gated category registration

```lua
-- settings/Panel.lua:245-256
    -- Defense in depth: `runConfig` already refuses under combat, but registering Settings
    -- categories during combat taints the GameMenu callback chain. Refuse here too so any future
    -- caller that bypasses the slash-handler guard doesn't reintroduce the Logout taint.
    if InCombatLockdown() then
        pout("Cannot register settings panel during combat.")
        return
    end

    Helpers.CreateOptionsPanel()
```

- Called from `OnEnable` (PLAYER_LOGIN) — `settings/Panel.lua:231-236`, `docs/ARCHITECTURE.md:134`.
- The addon's own record of where its taint actually comes from: `settings/Panel.lua:232-236` and
  `docs/ARCHITECTURE.md:66` — *"WhatGroup's real boot-taint sources (the secure teleport button +
  `UISpecialFrames` insert) stay deferred in `modules/Frame.lua`"*.
- Rule: `options-ui.md:75` (**MUST** register eagerly at load) and `options-ui.md:170` — *"**The
  category registration itself never taints** — don't confuse it with the genuine boot-taint sources
  (secure buttons/frames, `UISpecialFrames`, insecure hooks), which are what stay deferred."*
- The recovery path exists but requires the user: `settings/Slash.lua:208-214` re-calls
  `Settings.Register()` from `runConfig` — the comment there names this exact scenario, *"a login in
  combat, where OnEnable's registration bailed on its own guard"*.

### WG-41 — no `docs/complexity.md`

Absent from the `docs/` listing above. Rule: `performance.md:119`.

### WG-42 — no mono-font fallback

```lua
-- core/WhatGroup.lua:96-100
NS.FONT_MONO = "Interface\\AddOns\\WhatGroup\\media\\fonts\\JetBrainsMono-Regular.ttf"
do
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM.Register then LSM:Register("font", "JetBrains Mono", NS.FONT_MONO) end
end
```

Vendored assets confirmed present: `media/fonts/JetBrainsMono-Regular.ttf` and `media/fonts/OFL.txt`.
Handed to the descriptor at `core/DebugLogSetup.lua:95` (`font = NS.FONT_MONO`).

- Rule: `debug-logging.md:28` — *"expose the path as a constant …, with a Blizzard font (e.g.
  `Fonts\ARIALN.TTF`) as the fetch-failure fallback"*.
- Explicitly **not** a deviation and not flagged: the font itself, per `debug-logging.md:30`
  (*"a standards audit **MUST NOT** flag the shipped debug console font (nor the addon logo …)"*).

### WG-43 — retired `§N.M` citations

- `.luacheckrc:1` — `-- .luacheckrc — lint config for the Ka0s WhatGroup addon (§14).`
- `.pkgmeta:4` — `# declares NO externals: block (§3.3, §13).`
- Rule: `STANDARDS.md:37-42` — *"This is the **only** cross-reference form — the old global `§N.M`
  numbering is retired."*
- Contrast, and why this is only advisory: the rest of the repo is already on the current scheme —
  `core/CoreSetup.lua:16` (`anti-patterns #36`), `settings/OptionsSetup.lua:11` (`options-ui-§1`),
  `settings/Slash.lua:26` (`slash-commands-§3`), `docs/ARCHITECTURE.md` throughout.

---

## 5. Evidence for the compliance claims

### Shared subsystems — descriptors, not implementations

- `core/CoreSetup.lua:39` — `local lib = LibStub and LibStub("LibKa0s-Core-1.0", true)`; guarded
  `:New` at `:126-129`; stub at `:41-100`; instance members published unwrapped at `:105-116` and
  `:134-135`.
- `core/DebugLogSetup.lua:20` — `LibStub("LibKa0s-DebugLog-1.0", true)`; `lib:New{...}` at `:88-136`;
  stub at `:22-85`; bare sink bound at `:141` (`NS.Debug = NS.DebugLog.Debug`, debug-logging-§1).
- `settings/OptionsSetup.lua:17` — `LibStub("LibKa0s-Options-1.0", true)`; `lib:New{...}` at
  `:98-141`; the load-completing stub at `:19-84`; the instance published **as** the namespace member
  at `:203-206` (options-ui-§1's *"the host member MUST be the library instance"*).
- `settings/Slash.lua:73` — `LibStub("LibKa0s-Slash-1.0", true)`; `lib:New{...}` at `:156-189`; stub
  at `:78-127`.
- No console, widget-maker, dispatcher or test-framework implementation exists in the addon: the
  repo has no `modules/DebugLog.lua`, no widget file, no parser, and `tests/_kit/` is vendored
  (anti-pattern #47 clear).

### Stub coverage, member by member

- **Core** — the addon reaches `NS.IsConcatSafe`, `NS.SafeToString`, `NS.Util.print`,
  `NS.Util.format`, `NS.SKIN`, `NS.ApplySkin`, `NS.MakeCloseButton`. All seven are answered by the
  `if not lib` branch (`:50`, `:54`, `:62`, `:76`, `:88`, `:89`, `:98`). `NS.Util.format` is
  published on **both** paths with the reason written down at `:73-75` — nothing calls it today,
  which is exactly why its absence would go unnoticed.
- **DebugLog** — call sites reach `Debug`, `Add`, `SetEnabled`, `IsEnabled`, `Show`, `Hide`,
  `Toggle`, `IsShown`, `Clear`, `ConsoleCheckbox`, `buffer`, `RefreshHeader`, `ShowCopy`,
  `UpdateScrollBar`, `UpdateStatus`, `BufferSize`, `LastLine`, `FindLine`, `CopyText`,
  `MakeCloseButton`, `Text`. All twenty-two appear in the stub table (`:47-83`). The stub still
  flips the flag and prints the ack (`:67-74`), as debug-logging-§7 requires, and announces **once
  per entry point** (`:34-42`) — a deliberate refinement over one shared token, with the reasoning at
  `:30-33`. It copies no formatter, with the prohibition cited in-code at `:44-46`.
- **Slash** — `OnSlash`, `PrintHelp`, `HelpRows`, `LandingRows`, `HelpHeader`, `CliList`, `CliGet`,
  `CliSet`, `CliReset`, `CliResetAll`, `CliVersion`, `BuildListLines`, `SetRowAnnotator`, `Text` —
  all present (`:88-126`), each lost verb naming the missing library through `CLI_MISSING` (`:76`,
  `:86`). No row formatter or parser is re-implemented.
- **Options** — the **documented exception**. `settings/OptionsSetup.lua:19-34` states the rule and
  the measurement: WhatGroup's load-time member set is **empty**, and `tests/test_libka0s.lua` pins
  it by loading with the library absent and comparing schema row counts against a full load. Per
  `AUDIT.md` and options-ui-§1 this is **correct**, not an inconsistency, and is not flagged. The
  stub also declines to carry `ROW_VSPACER` / `SECTION_HEADING_H` / `BUTTON_PAIR_REL`, with
  options-ui-§1/§8 cited at `:78-82`.

### Testing wiring (testing-§9)

```
$ grep -n "tocFiles\|libs/\|exists on disk\|XML order" tests/test_harness.lua
27:test("harness: the addon's load list is DERIVED from the TOC, in TOC order (testing-§9)", ...
38:test("harness: every derived addon path exists on disk", ...
44:test("harness: no libs/ path leaked into the derived addon list", ...
51:test("harness: the explicit LibKa0s list matches LibKa0s.xml, in XML order (anti-patterns #48)", ...
67:test("harness: every LibKa0s file the runner loads exists on disk", ...
```

`tests/loader.lua:20-32` spells out all eight LibKa0s files in XML order, as testing-§9 requires,
and case 51 pins that list against the XML itself rather than against a hand-written copy.

### Anti-pattern spot checks

- **#38** (`embeds.xml`): none in the repo; `WhatGroup.toc:16-25` names every library directly.
- **#36** (AceConsole `:Print` clobber): both sanctioned fixes applied — printer published as
  `NS.Util.print` (`core/CoreSetup.lua:134`) and reclaimed after `NewAddon`
  (`core/WhatGroup.lua:84`).
- **#46** (British spelling): sweep across `README.md`, `CLAUDE.md`, `core/`, `modules/`,
  `settings/`, `locales/`, `defaults/` and every live `docs/*.md` for
  `colour|grey|behaviour|centre|cancelled|analyse|catalogue|defence|licence|favour|labelled|-is(e|ation)`
  → **zero hits**.
- **#37** (localized matching): game data is keyed on `mapID` (`defaults/TeleportSpells.lua`),
  `spellID`, and Blizzard's `GROUP_FINDER_GENERAL_PLAYSTYLE1..4` GlobalStrings
  (`.luacheckrc:34-35` declares them as reads) — never on an English literal.
- **#22** (deferred category registration): registration runs at `OnEnable`, not behind `/wg config`
  (`settings/Panel.lua:238`, `docs/ARCHITECTURE.md:134`). The residual combat guard is `WG-40`, a
  different and narrower defect.
- **#49** (shipped scaffolding pack): no `docs/agent-context.md`; `CLAUDE.md:27-42` records that it
  was deleted at standard v2.17.0 and must not be recreated, and marks the older bundles that still
  name it as frozen history.

### Window edge (standalone-windows-§2)

- `modules/Frame.lua:54-91` — `f.title` and `f.divider` are assigned first, then `NS.ApplySkin(f)`
  is called; the comment at `:54-62` records that the values are the library's and that the popup
  now wears the normative edge (a black outer border in place of the old gray one).
- `core/CoreSetup.lua:114-116` binds `NS.SKIN` / `NS.ApplySkin` / `NS.MakeCloseButton` to the
  library's own objects — not copies — so there is no second implementation to disagree.
- `core/DebugLogSetup.lua:132-135` passes **no** `skin`, `applySkin` or `makeCloseButton`, with the
  reason written down: the console is a library window and keeps the library's close glyph
  (standalone-windows-§2's *"the edge is shared; the close control is not"*).
- The degraded fallback at `core/CoreSetup.lua:84-97` deliberately does **not** hand-copy the SKIN
  hex values, citing anti-pattern #47 at `:85-87` — the correct call.
