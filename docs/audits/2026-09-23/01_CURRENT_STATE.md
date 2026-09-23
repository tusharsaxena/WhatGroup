# 01 — Current state (2026-09-23)

**Addon:** Ka0s WhatGroup · **Repo:** `tusharsaxena/WhatGroup` · **Audited at:** `1124ac4`
(branch `feat/2026-09-23-review-audit-remediation`, clean apart from an **untracked**
`docs/reviews/2026-09-23/` written by a review run in parallel with this one; every census below starts
from `git ls-files`, so that folder is outside all of them).

**Standard:** **v2.64.0 (2026-09-23)**, fetched with `curl -fsSL` from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`: `AUDIT.md`,
`standards/STANDARDS.md`, all **27** section files its Sections list links, and `standards/ADDONS.md`.
The local `../WowAddonStandards` checkout (HEAD `e68795f`, 2026-09-23) was read only for `git log`
history of the section files, never as the rule text.

**Repo kind: Addon.** It has a `.toc` (`WhatGroup.toc`) and is the `Ka0s WhatGroup` row of
`ADDONS.md`'s addon table, rung **(a)**, "the group popup". The whole addon rule set applies. The
library-repo and documentation-and-tooling lists do not.

**Prior audit:** `docs/audits/2026-09-08/`, run against v2.39.0. Prefix **`WG-`** (stable since
2026-07-12), IDs through WG-63. This run reuses the prefix and every recurring ID, and new IDs start
at **WG-64**. WG-57 is **reopened** on a different reading (see 02).

**Tooling this run used.** `ka0s-bounded` is not on `PATH` in this shell, but it is installed at
`~/.claude/wow-addon/bin/ka0s-bounded` (a symlink into the wow-addon 2.3.0 plugin cache). Every
`lua`, `luacheck` and `lizard` run went through it, so the `timeout 900` fallback was not needed.
Lua 5.1.5, luacheck at `/usr/local/bin/luacheck`, lizard 1.24.0, `gh` present. The sibling
`../LibKa0s` is present (HEAD `46ccaa6`, `v1.55.0-3-g46ccaa6`), and tag `v1.55.0` resolves there.

---

## Layout (`layout`)

- Modular skeleton: `core/` (10 files), `defaults/` (2), `locales/` (1), `modules/` (1), `settings/` (4).
  Nothing loose at the root. `media/logos/` and `media/screenshots/` are the only media folders.
- **LOC cap census, `layout-§1` scope** (`git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`, 48
  files, tests included): nothing over 1500. Three files sit in the 1000–1500 band:
  `tests/test_frame.lua` 1421, `modules/Frame.lua` 1144, `core/WhatGroup.lua` 1099.
- The census heading `### Files over the 1500-line cap` is at `docs/ARCHITECTURE.md:523`, under
  `## Documented deviations` (`:485`). It reads "Nothing is over the cap today" (`:529`), which matches
  the tree. The kit gate `test_layout_cap` is wired as `{ name = "test_layout_cap", dir = "tests/_kit/" }`
  (`tests/run.lua:148`), and its 13 cases pass.
- Generators: `git ls-files '*.py' '*.sh'` returns only `tests/_kit/run-automated-tests.sh`, which is
  vendored and a runner. There is no `tools/` folder, and none is owed.
- Logo files: `media/logos/whatgroup.logo.128.tga` reads as TGA type **2**, **128×128**, **32** bpp
  (header bytes). The landing logo `whatgroup.logo.tga` and the `.png`/`.jpg` sources sit beside it.

## TOC (`toc-file`)

- Field order, `WhatGroup.toc:1-13`: Interface `120100` · Title `Ka0s WhatGroup` · Notes · Author ·
  Version `1.4.0` · IconTexture `Interface\AddOns\WhatGroup\media\logos\whatgroup.logo.128.tga` ·
  SavedVariables `WhatGroupDB` · OptionalDeps (Ace3, LibStub, CallbackHandler-1.0,
  LibSharedMedia-3.0, LibDataBroker-1.1, LibDBIcon-1.0) · DefaultState · Category-enUS `Chat` ·
  X-License MIT · X-Standard · X-Curse-Project-ID `1489907`. This is the canonical order.
- **Interface 120100** is what every sibling Ka0s TOC carries today. The standard's
  "currently `120007`" (`toc-file-§3`) is stale upstream text (WG-82). The README `[wow]` badge
  reads `Midnight_12.1.0` and agrees with the TOC.
- File listing: `# Libraries` (16-30, `libs\LibKa0s\LibKa0s.xml` once at `:30`) → `# Locales` →
  `# Core` → `# Defaults` → `# Modules` → `# Settings`. Load-bearing annotations are present for
  CoreSetup (`:35-36`), MediaSetup (`:38-39`), DebugLogSetup (`:49-51`), Profile (`:64-65`),
  Schema (`:76-77`) and OptionsSetup (`:79-81`). **`core\Compat.lua` (`:42`) is load-bearing and
  carries no annotation**, because `core/WhatGroup.lua:87` calls `NS.Compat.AddOnLinkType()` at file
  load (WG-70).

## Libraries (`library-stack`)

- Vendored under `libs/`: LibStub, CallbackHandler-1.0, AceAddon/AceEvent/AceConsole/AceTimer/AceDB/
  AceGUI-3.0, LibSharedMedia-3.0, LibDataBroker-1.1, LibDBIcon-1.0, LibKa0s. No `externals:`.
- **LibKa0s v1.55.0**. The provenance line is at `CLAUDE.md:79` and nowhere else: `README.md` returns
  no `Bundles [LibKa0s]` hit and no library-inventory heading.
- `diff -r` of the `v1.55.0` tag (`git archive`) against `libs/LibKa0s` and `tests/_kit`: **both
  empty**, content and bytes. The payload is whole, 24 top-level entries on each side, and
  `LibKa0s.xml` lists 21 `<Script>` files.
- Majors wired (nine): Core, Env, Compat, Media, DebugLog, Options, Slash, Launcher, Lifecycle, through
  `core/CoreSetup.lua`, `core/EnvSetup.lua`, `core/Compat.lua`, `core/MediaSetup.lua`,
  `core/DebugLogSetup.lua`, `settings/OptionsSetup.lua`, `settings/Slash.lua`,
  `core/LauncherSetup.lua` and `core/LifecycleSetup.lua`.
  - **Perf is declined**, under the ratified `performance-§12` row.
  - **Bus is declined**, because the addon has no bus (#21, will-not-do). v2.64.0 requires no
    adoption.
  - **Schema is deferred** (#22, triaged). v2.64.0 requires no adoption.
- **Shared media:** `core/MediaSetup.lua` passes the vararg `addonName` and calls
  `Media.RegisterLSM(addonName)` once at file load. There is no private font, icon or texture copy.
  `NS.Icon` is published and has no caller today, because the footer mark was removed (register row).
- **Close-button grep** (outside `libs/` and `tests/`): the wrapper definition
  `core/CoreSetup.lua:135-137` and its degraded twin at `:100`. Nothing else. The popup has no
  title-bar close. Its footer **Close** is a labeled `UIPanelButtonTemplate`, covered by a ratified
  `standalone-windows` row.
- **Degradation stubs:**
  - Core (`core/CoreSetup.lua:41-102`) prints once and publishes every member.
  - DebugLog (`core/DebugLogSetup.lua` stub) answers every member and announces once per entry point.
  - Options (`settings/OptionsSetup.lua:19-166`) is **load-completing**, the documented exception.
    Its measured load-time set is only `MasterControls`, which answers `{}` and a no-op.
  - Slash (`settings/Slash.lua:118-181`): the host verbs work, and the CLI verbs name the missing
    library.
  - Launcher (`core/LauncherSetup.lua` stub): 5 members. The live instance has the same 5.
  - Lifecycle (`core/LifecycleSetup.lua:50-85`) is a functional hold set. The live instance has the
    same 8 members.
  - Compat (`core/Compat.lua:42-63`) uses the reader arm.

## Patterns (`architecture`, `savedvariables`, `events-frames-taint`)

- Every source file binds `local addonName, NS = ...` (8 files) or `local _, NS = ...` (10 files).
  There is no `_G.WhatGroup`. The AceAddon object is `NS` itself (`core/WhatGroup.lua:32-35`).
  `NS.Print` is reclaimed after `NewAddon` (`:135-137`).
- **Message bus:** none. `docs/ARCHITECTURE.md:122-129` says why. The addon does register game
  events (`core/WhatGroup.lua:294-302`), which puts it on the MUST side of `architecture-§4`'s
  applicability clause as literally written (WG-57, reopened).
- **Schema-as-single-source:** 19 rows. 11 are declared in `settings/Schema.lua` and 8 are composed by
  `MasterControls` (`settings/Panel.lua:204-247`). One write seam, `Helpers.Set` (`Schema.lua:451`).
  `global.minimap.hide` is intercepted at `Schema.lua:368-386` and `state.*` at `:328-336`.
- **Write-path census** of the authored TOC-loaded Lua:
  - Every hit outside the helper is the load pass (`core/Database.lua:27`, `:38`), the Launcher
    stub's `SetShown`, which is reached only from the helper's GLOBAL row, or named non-setting state.
  - The named state is `db.global.windows.popup`, written by `NS.Windows.Save` at `core/Util.lua:70-71`
    and by `ResetFramePosition` at `modules/Frame.lua:359`. It is named at
    `docs/ARCHITECTURE.md:106-111`.
  - There is no structural registry, which `:118-120` records.
- `schemaVersion` is 1 and the migration runner is `core/Database.lua` (empty body).
  `visibility` (`defaults/Profile.lua:27`) was born a string on 2026-09-02 (`127baa1`) and never
  existed as a boolean, so `options-ui-§15` owes no migration.
- **Events:**
  - AceEvent registers four events, bare, in `registerFeatureEvents` (`core/WhatGroup.lua:293-304`).
    No per-event `pcall` and no rejected-name record (WG-67).
  - Two raw `PLAYER_REGEN_ENABLED` registrations sit on private frames (`modules/Frame.lua:529`,
    `:1028`) (WG-68).
  - `hooksecurefunc(C_LFGList, "ApplyToGroup")` is installed at file load (`:63`).
  - The chat link is `EventRegistry:RegisterCallback("SetItemRef", …, WhatGroup)` (`:108-114`), with
    a `hooksecurefunc("SetItemRef")` fallback on a degraded client.
- **Secret values:** the chat and debug seams are LibKa0s-Core's. The protected-API sweep returns 0,
  and the pre-formatting SHOULD is a ratified row.

## Settings (`options-ui`, `launcher`, `preview-mode`)

- Landing page plus one **General** subcategory. The General page is tabbed **Master controls (8) →
  Chat (8) → Popup (3)**, derived from the schema's `group` order. The first tab is the composed
  `Master controls`. `subgroup` headings: Chat has Timing/Text, and Popup has Behavior/Layout.
- `options-ui-§15` rows: Enable WhatGroup · General visibility (dropdown) · Master scale · Master
  alpha · Lock frame · Debug console (session) · Minimap button (global) · Test mode (session) ·
  Reset position | Reset all settings. The addon is not frameless (`modules/Frame.lua:584`
  `f:SetMovable(true)`).
- The global reset is `db:ResetProfile()` behind `WHATGROUP_RESET_ALL`, with the verbatim wording
  (`settings/Schema.lua:784`), Yes/No, `timeout = 0`, `whileDead`, `hideOnEscape`. Session rows are
  swept row by row.
- **Launcher:** one LDB object from LibKa0s-Launcher, `label = "Ka0s WhatGroup"`, icon = the 128 TGA
  derived from `addonName` (`core/LauncherSetup.lua:54-55`). Left-click toggles the popup (rung a).
  Right-click opens settings. Visibility is `db.global.minimap.hide`. No broker toggle.
- **Test mode:** a session checkbox (`modules/Frame.lua:957-966`). It ends at `PLAYER_REGEN_DISABLED`
  and is refused in combat. `/wg test` is its verb, and `/wg test notify` is the one-shot.
- No color rows, no LSM rows, no reorder lists, no `disabledIf`. `options-ui-§16/§17/§18` do not engage.

## Slash (`slash-commands`)

- The `/wg` and `/whatgroup` AceConsole registrations sit in `core/WhatGroup.lua:280-281`, and the
  dispatcher is LibKa0s-Slash (`settings/Slash.lua:210-256`).
- `COMMANDS` holds 13 verbs: help, show, test, config, enable, disable, version, list, get, set, reset,
  resetall, debug. `perf` is reserved and deliberately unregistered under the `performance-§12` row.
  There is no `lock`/`unlock`, which is a declined MAY and not a finding.
- **Disabled state (`slash-commands-§7`):** one LibKa0s-Lifecycle latch with the `disabled` and `perf`
  holds (`core/LifecycleSetup.lua`).
  - `NS.StandDown` (`core/WhatGroup.lua:329-349`) unregisters the four AceEvent registrations, wipes
    the capture and runs `NS.FrameStandDown`. That cancels the ticker, hides the popup and ESC proxy,
    and unregisters both raw frame registrations.
  - The single combat-deferred `PLAYER_REGEN_ENABLED` is released on fire (`:354-357`).
  - **Survivor:** the `EventRegistry` "SetItemRef" callback is not unregistered. Its body gates on
    `NS.IsStoodDown()` instead (`:100`) (WG-64).
  - Slash surface: every reserved verb answers. `show` and `test` take the feature-verb SHOULD with
    the library's refusal line. The launcher's left-click is refused, and right-click opens the panel.
  - `tests/test_disabled.lua` is present, listed and green (steps 1–10). Its registration survey
    cannot see EventRegistry callbacks (WG-66).

## Debug (`debug-logging`)

- `core/DebugLogSetup.lua` builds the LibKa0s-DebugLog descriptor with `name`, `addonName`, title,
  font (JetBrains Mono through the Media seam with a `CreateFont` probe fallback), `slash`,
  `isEnabled`/`setEnabled` over the session-only `NS.State.debug`, forwarders, `initSummary` and
  `onVisibilityChanged`. The sink is bound bare as `NS.Debug`.
- 38 non-comment `NS.Debug(` call lines in authored TOC-loaded Lua, two of them descriptor
  forwarders. **16** of them build the message with `..` before the gate (WG-69).

## Tests (`testing`), lint (`lint`), performance, automated tests

- `ka0s-bounded lua tests/run.lua`: **727 passed, 0 failed, 0 skipped, 727 total**, exit 0, wall
  7.24 s, max RSS ~21 MB. `docs/test-cases.md` is byte-equal to `--list` (Total 727), and the README
  badge reads `727/727`.
- Kit revision 25 suites are wired by kit path: `test_eol`, `test_prose` and `test_layout_cap`
  (`tests/run.lua:139`, `:144`, `:148`). `tests/test_vendor_sync.lua` delegates to the kit and passes
  its three cases, including `100755`.
- Stub-surface parity cases exist for Core, DebugLog, Slash, Options and Compat. There are none for
  Launcher or Lifecycle (WG-72).
- `ka0s-bounded luacheck .`: **0 warnings / 0 errors in 48 files**. `exclude_files` is `libs/`,
  `docs/audits/`, `docs/reviews/`, `_dev/`, `tests/_kit/` (`.luacheckrc:17`). The harness global is in
  `files["tests/"]` (`:62-71`). There is no top-level `ignore`. `docs/revendor/` is not excluded
  (WG-83, Info).
- `ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` (verbatim): **10462 NLOC, 1368
  functions, avg NLOC 6.7, avg CCN 1.8, 0 warnings**. The max CCN is 14 (`WhatGroup:ShowFrame`,
  `modules/Frame.lua:980-1055`).
- Newest bundle `20260916-184548`: commit `d64656b`, clean. It recorded 9903 NLOC, 1298 functions,
  max CCN 15, 0 warnings and 667 tests. HEAD is **29 commits** past it
  (`git rev-list --count d64656b..HEAD`). `core/WhatGroup.lua` has entered the 1000–1500 band since
  (WG-48, Info).
- The release run for 1.4.0 is `20260910-234511` (release `1.4.0`, green, `ANALYSIS.md` present).
- `tests/perf.lua` exists (8 scenarios). The in-game Perf wiring is declined by the register row.
- Watch list: two **Accepted** band entries. `tests/test_frame.lua` has been carried by one release
  run and `modules/Frame.lua` by none. Neither is near `anti-patterns` #53's three-release shelf life.

## Packaging (`packaging`)

- `.pkgmeta` ignores `.luacheckrc`, `.gitignore`, `.gitattributes`, `docs`, `tests`, `_dev`, `*.bak`,
  `.pkgmeta`, `.claude`, `media/screenshots`, `CLAUDE.md`, `DEPENDENCIES.md`, `media/logos/*.png` and
  `*.jpg`.
- AUDIT check (a), run under bash: nothing unignored. Check (b): only `.git`, which is exempt. Check
  (c): no false claim. `.superpowers` is absent and not named, which is compliant since v2.63.0.

## Line endings (`line-endings`)

- `.gitattributes` exists. Its pin is `* text=auto eol=crlf` (`:26`), with `*.sh text eol=lf` (`:36`)
  and `*.py text eol=lf` (`:37`), and 20 `binary` lines.
- `diff <(head -n 84 .gitattributes) <canonical client-bound body>` is **empty** (CR stripped from the
  working tree). There is no appendix.
- The working-tree check (e) over the whole tracked set returns **0**. The kit's `test_eol` passes both
  cases, including the §5 body case.

## Root docs (`documentation-§1/§2/§7`)

- `README.md`:
  - H1, five badges in order, the **bare** standard badge (`:6`) and no logo image.
  - Description, Screenshots, Usage (prose, no tables), How it works, FAQ, Troubleshooting, Issues,
    Version History with `- ` bullets.
  - No placeholders and no `%20`.
  - It claims the debug window's position is saved (`:41`, `:48`), which the library does not do
    (WG-77).
- `CLAUDE.md`: stub H1, adherence, `## Standards compliance (read first)`, docs pointer list, green
  gate, and the provenance line at `:79`.
- `DEPENDENCIES.md`:
  - Runtime, Development and Release groups, with install and verify commands.
  - The Release group says no image tooling is needed, although `layout-§4` fixes a Pillow recipe for
    the committed 128 TGA.
  - lizard is labeled optional even though the release gate needs it (WG-79).

## `docs/` (`documentation-§3`)

- The canonical trio is present.
- Tier 1: all six are present under canonical names.
- Tier 2:
  - `slash-dispatch.md` is **Present** (13 verbs, ≥ 8).
  - `midnight-quirks.md` is **Present** (workarounds exist).
  - `compat-layer.md` is **Present**. The standard's grep counts **6** shims (≥ 3), where the map row
    says "eight" (WG-75).
  - `debug.md` is **Present**, but on a trigger that has not fired (WG-75).
  - `message-bus.md`, `profiles.md` and `perf-analysis/README.md` are **Not applicable**, and each
    carries its trigger.
- `## Documentation map` (`docs/ARCHITECTURE.md:440`) has four tables in order. Checked in both
  directions against the tracked `docs/**/*.md` minus the stores `documentation-§3` names:
  - No orphans. `ARCHITECTURE.md` itself has no self-row, which is a MAY and not filed.
  - No dangling rows. Three rows point at absent files, and all three are Not applicable rows.
- Tier 3: `frame.md`.
- No retired `file-index.md`, `conventions.md`, `complexity.md` or `docs/perf-runs/`. No
  `agent-context.md`. No `docs/pending/`.
- Hub shape: `docs/ARCHITECTURE.md` is **533** lines (`wc -l`), which is past the ~400 SHOULD. No
  mandated section is past ~60 lines (WG-76).

## Register and issue store (`audit-review-history`)

- `## Documented deviations` (`docs/ARCHITECTURE.md:485`) has **five** rows: `performance-§12`
  (`:502`), `localization-§3` (`:503`), `events-frames-taint-§8` (`:504`), and two `standalone-windows`
  rows (`:505`, `:506`). Every trigger was evaluated against the tree and **none has fired** (02, 03 §B).
- `gh issue list --state all --limit 200 --json …` returns 22 issues, all labeled `state:` and
  `severity:`, with no `[status]` title prefix.
  - Open and triaged: #1, #2, #4, #22.
  - The will-not-do issues #5, #7, #9–#14, #18 and #21 decline no standard rule that lacks a row. #7
    and #18 back the Perf row. The rest decline optional modules, a MAY field, or a host-owned
    helper the library does not provide.
- Re-vendor store: `docs/revendor/`, 8 bundles. The horizon is `2026-08-25`. There are **31** distinct
  tags vendored since the horizon, **25** of them unrecorded (WG-71).

## Shared-subsystem wiring

The console, options toolkit, dispatcher, launcher, latch and harness are consumed from LibKa0s
through descriptors, not hand-rolled. There is no `anti-patterns` #47 or #48.
