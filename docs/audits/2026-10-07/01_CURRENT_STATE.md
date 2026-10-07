# 01 — Current state (2026-10-07)

**Addon:** Ka0s WhatGroup · **Repo:** `tusharsaxena/WhatGroup` · **Audited at:** `57a08e9`
(branch `feat/2026-10-07-review-audit-remediation`, clean tree at the start of the run; every census
below starts from `git ls-files`, so this bundle's own folder is outside all of them).

**Standard:** **v2.76.1 (2026-10-07)**, fetched with `curl -fsSL` from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`: `AUDIT.md`,
`standards/STANDARDS.md`, all **27** section files its Sections list links (discovered from the list,
not hard-coded), and `standards/ADDONS.md`. Nothing was read from memory.

**Repo kind: Addon.** `dev-copilot-profile` reports `profile=wow`, `kind=addon`, `reason=toc:## Interface`,
and `ADDONS.md:29` lists `Ka0s WhatGroup` in the addon table with the launcher menu entries
"Enabled · Locked · Test mode · Show window". The detector and the table agree. The whole addon rule
set applies. The library-repo and documentation-and-tooling lists do not.

**Prior audit:** `docs/audits/2026-09-23/`, run against v2.64.0. Prefix **`WG-`** (stable since
2026-07-12), IDs up to WG-83. This run reuses the prefix and the IDs of recurring deviations. Two are
**reopened** (WG-71, WG-77) and one is **carried** (WG-48). The one new ID is **WG-84**. The
remediation since then (`d1334f1` and the later merges, 120 commits from `1124ac4`) closed every other
2026-09-23 root. See `02_DEVIATIONS.md` → *Closed since 2026-09-23*.

**Tooling this run used.** Every `lua`, `luacheck` and complexity run went through
`~/.claude/dev-copilot/bin/ka0s-bounded` (a symlink into the dev-copilot 2.0.1 plugin cache). Lua 5.1.5,
`luacheck` at `/usr/local/bin/luacheck`, `lizard` 1.24.0, `gh` present. The sibling `../LibKa0s` is
present (HEAD `353f286`, `v1.70.0-5-g353f286`), and tag `v1.70.0` resolves there (`162a7fd`).

---

## Layout (`layout`)

- Modular skeleton: `core/` (10 files), `defaults/` (2), `locales/` (1), `modules/` (2), `settings/` (6).
  Nothing loose at the root. `media/` holds only `logos/` and `screenshots/`.
- **LOC census, `layout-§1` scope** (`git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`, 59 files,
  `tests/` included): nothing over 1500. Three files sit in the 1000–1500 band: `modules/Frame.lua`
  1319, `core/WhatGroup.lua` 1313, `tests/test_libka0s.lua` 1037.
- The census heading `### Files over the 1500-line cap` sits under `## Documented deviations`
  (`docs/ARCHITECTURE.md:389`). It reads "Nothing is over the cap today" and names the same three
  largest files at the same line counts. The kit gate is wired by path
  (`tests/run.lua:186`, `{ name = "test_layout_cap", dir = "tests/_kit/" }`).
- Generators: `git ls-files '*.py' '*.sh'` returns only `tests/_kit/run-automated-tests.sh`, which is
  vendored and a runner. There is no `tools/` folder, and none is owed.
- Logo: `media/logos/whatgroup.logo.128.tga` header bytes read type **2**, **128×128**, **32** bpp.

## TOC (`toc-file`)

- `WhatGroup.toc:1-13`, in canonical order: Interface `120100` · Title `Ka0s WhatGroup` · Notes ·
  Author · Version `1.5.0` · IconTexture `Interface\AddOns\WhatGroup\media\logos\whatgroup.logo.128.tga`
  · SavedVariables `WhatGroupDB` · OptionalDeps · DefaultState · Category-enUS `Chat` · X-License MIT ·
  X-Standard · X-Curse-Project-ID `1489907`.
- Interface `120100` is what all eleven sibling TOCs carry. The README `[wow]` badge reads
  `Midnight_12.1.0`, which matches.
- File listing: `# Libraries` → `# Locales` → `# Core` → `# Defaults` → `# Modules` → `# Settings`.
  `libs\LibKa0s\LibKa0s.xml` appears once (`:39`). Every load-bearing position is annotated and names
  what resolves: CoreSetup, MediaSetup (`NS.FONT_MONO`), Compat (`core/WhatGroup.lua:108`),
  DebugLogSetup (`:142`), Profile (`settings/Schema.lua:29`), SchemaSetup (`:418`), Schema
  (`settings/Panel.lua:308`), OptionsSetup (`settings/Panel.lua:214`). The conventional groups are
  marked as well. Every TOC line citation resolves (03 §C).

## Libraries (`library-stack`)

- Ace3 vendored under `libs/`, plus LibSharedMedia-3.0, LibDataBroker-1.1, LibDBIcon-1.0 and
  `libs/LibKa0s/`.
- **LibKa0s v1.70.0**, per root `CLAUDE.md:46`, which is the only provenance line. README carries none,
  has no library heading, and shows no logo.
- Both `diff -r` runs against the `v1.70.0` tag are **empty**: the ship payload and the test kit
  (03 §A). The kit is revision **37** (`tests/_kit/framework.lua:20`).
- Ten majors are wired through ten setup files, each resolved with `LibStub(major, true)` and each with
  a degradation stub. They are Core, Env, Compat, Media, DebugLog, Schema, Options, Slash, Launcher
  and Lifecycle. Perf is declined under a ratified row. Bus, Widgets, Item and Pool are declined by
  `state:will-not-do` issues, and none of them is required.
- `tests/test_surface_parity.lua` pins every stub against its live instance by name, including
  Launcher and Lifecycle.

## Architecture and SavedVariables

- `local addonName, NS = ...` in nine source files and `local _, NS = ...` in the other twelve. There
  is no `_G.WhatGroup`.
- AceAddon shell `core/WhatGroup.lua` with one feature module, `modules/Frame.lua`, which registers no
  event. That is below `architecture-§4`'s bus threshold, and there are no `Ka0s_` messages (03 §D).
- AceDB `WhatGroupDB`. `global.schemaVersion` defaults to 0, `NS.SCHEMA_VERSION = 1`
  (`core/Database.lua:27`), and `NS:RunMigrations` is the runner.
- Named non-setting state is written down in the hub: `db.global.windows` (owner `NS.Windows`) and
  LibDBIcon's `minimapPos`. The write-path grep finds no schema-row write outside the seam (03 §D).

## Settings (`options-ui`)

- Landing page (logo, notes, one Label per `COMMANDS` row), the **General** page tabbed **Master
  controls / Chat / Popup**, and an AceConfig **Profiles** sub-page.
- The Master controls block is composed by the library. The schema runtime is
  `LibKa0s-Schema-1.0` (`settings/Schema.lua:418`). The Options descriptor passes
  `addonName = addonName` (`settings/OptionsSetup.lua:195`, v2.75.0) and
  `debug` (`:198`).
- **Schema rows, counted from the code:** 8 composed + **12** declared in `settings/Schema.lua`
  (9 Chat + 3 Popup) = **20**. The hub and `module-map.md` still say nineteen, eleven and Chat (8)
  (WG-77).
- No color rows, no `disabledIf`, no reorder arrows, no `LSM30_` controls, no `SettingsPanel` /
  `HideUIPanel` / `OpenToCategory` call outside comments.

## Slash (`slash-commands`)

- `/wg` and `/whatgroup` (`core/WhatGroup.lua:353-354`). **15** `COMMANDS` rows: help, show, test, config,
  enable, disable, version, list, get, set, reset, resetall, profile, debug, diagnostics.
- `enable`/`disable` write the `enabled` row through the seam. `liveVerbs` is `lib.LIVE_VERBS` plus
  `profile`. `perf` is reserved and unregistered under the ratified row. `lock`/`unlock` are absent,
  which is the `slash-commands-§8` MAY.
- **Stand-down:** one `LibKa0s-Lifecycle-1.0` latch with `disabled` and `perf` holds. `NS.StandDown`
  unregisters all four AceEvent registrations and the `EventRegistry` callback, cancels both timers
  and stands the popup down. It keeps `PLAYER_REGEN_ENABLED` only while it owes a protected `Hide`, and
  that registration (`core/WhatGroup.lua:436`) is bare rather than routed through the helper (WG-84).
  `tests/test_disabled.lua` (646 lines) surveys the registration set, including `EventRegistry`.

## Launcher (`launcher`)

- One object built in `core/LauncherSetup.lua`, labeled `"Ka0s WhatGroup"`.
- The descriptor passes `isEnabled`/`setEnabled`, `isLocked`/`toggleLock`,
  `isTestMode`/`toggleTestMode` and `isWindowShown`/`toggleWindow`, which matches the four entries in
  `ADDONS.md`. It also passes `version`, `debug` and `debugAtEnable`.
- There is no `onTooltipShow` and no host menu.
- The minimap row path is `global.minimap.shown`, and it is `resetExempt` in the schema runtime.

## Debug (`debug-logging`)

- `LibKa0s-DebugLog-1.0` descriptor at `core/DebugLogSetup.lua:142`, with `addonName` at `:155`.
- The stub (`:79-137`) carries `DebugOnce`, `DebugChanged`, `DebugForget`, `DebugAtEnable` and
  `RunDiagnostics`.
- The diagnostics report is one `COMMANDS` row (`settings/Slash.lua:81`) plus the `debug diagnostics`
  word (`:495`). Sections live in `modules/Diagnostics.lua`. There is no alias, no host `SetEnabled`
  around the run, and no `diagnosticsEnablesLogging`.
- The Slash, Options, Launcher and Lifecycle descriptors each pass `debug`.
- The console's own gates replace the host memos (`core/WhatGroup.lua:60`, `modules/Frame.lua:627`).

## Events, frames, taint

- The four feature events go through `NS.SafeRegisterEvent` (`core/WhatGroup.lua:374-382`), and
  rejections surface in `[Init]` and in diagnostics (`:510-512`, `modules/Diagnostics.lua:96`).
- The stand-down's transient registration at `:436` is the one bare `RegisterEvent` (WG-84).
- `hooksecurefunc` is used for `ApplyToGroup` and, on a degraded client only, `SetItemRef`. There is no
  AceHook. The trigger-set sweep returns **0** (03 §B).

## Tests, lint, complexity

- `lua tests/run.lua` (bounded): **914 passed, 0 failed, 1 skipped, 915 total**, exit 0. The skip is the
  kit's opt-out diagnostics case, with its reason printed. `docs/test-cases.md` is byte-identical
  (CR-stripped) to `--list`. The README badge reads `914/914`, which agrees, because skips count in
  neither figure (`testing-§5`).
- `luacheck .` (bounded): **0 warnings / 0 errors in 59 files**. `exclude_files` holds only the frozen
  stores, `_dev/` and `tests/_kit/`. There is no top-level `ignore`.
- The vendor gate passes against `v1.70.0`, and the EOL, prose, layout-cap, diagnostics-contract and
  lizard-sighted kit suites are all declared by path (`tests/run.lua:177-192`).
- **Sighted complexity** (`bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`,
  bounded): pass, **0 warnings**, max CCN **15**, 1792 functions, 13412 NLOC, parity clean (0 blind
  files). The newest bundle, `20260927-031637`, measured `62680d3`, which is **50 commits** behind HEAD
  and predates the sighted kit (WG-48).

## Performance

- Perf is declined under the `performance-§12` row.
- `tests/perf.lua` runs 8 offline scenarios.
- `docs/performance.md` carries the committed sweep. Regenerated today, it is **24 lines across 5
  files**, exactly the figure the page states, with one repeating timer (`modules/Frame.lua:587`).

## Packaging and line endings

- `.pkgmeta`: no `externals`. The ignore list covers every named dev entry and every root dot-entry
  except `.git`. There is no false conditional line. A comment's inventory is stale (WG-77).
- `.gitattributes`: the 84-line client-bound canonical body, byte-identical after a CR strip, with no
  appendix. It has `* text=auto eol=crlf`, `*.sh text eol=lf`, `*.py text eol=lf` and 20 `binary`
  lines.
- Working-tree check (e) = **0**. The kit gate `test_eol` is wired.

## Root doc set and `docs/`

- `README.md` follows the canonical section order.
  - Bare standard badge.
  - No numbered list, no logo, no library inventory.
  - `## Reporting a bug` is verbatim, with three bullets.
  - Highlights are bulleted.
  - `## Credits` names only the JetBrains Mono font.
- `CLAUDE.md` is the documentation-§2 stub: title, adherence line, the compliance section, the
  docs pointer, the green gate and the provenance line.
- `DEPENDENCIES.md` covers runtime, development and release (Python 3 + Pillow, `lizard` required at
  release). One evidence citation is stale (WG-77).
- `docs/`:
  - All six Tier 1 docs are present.
  - Tier 2: `slash-dispatch.md`, `midnight-quirks.md`, `compat-layer.md`, `profiles.md` and
    `debug.md` are present. `message-bus.md` and `perf-analysis/README.md` are *Not applicable*
    rows carrying their trigger.
  - Tier 3: `frame.md`, `stand-down.md`, `debug-content.md`.
  - The map has four tables and registers every live `.md` exactly once. Its only rows without a
    file behind them are the two *Not applicable* rows.
  - Hub: **393 lines**, and no mandated section is past ~60 lines.
  - No retired doc, no `docs/pending/`, no `docs/perf-runs/`.

## Register and issues (`audit-review-history`)

- `## Documented deviations` (`docs/ARCHITECTURE.md:372`) holds **six** rows. Every trigger was evaluated
  against today's tree and none has fired. Every evidence id resolves. All six are accepted
  (`02_DEVIATIONS.md`).
- `gh issue list --state all`: 22 issues, every one with one `state:` and one `severity:` label and
  no `[status]` title prefix. One is open (#2, `state:triaged`).
- Re-vendor store `docs/revendor/`: horizon `2026-08-25`. 51 tags vendored, 49 recorded. **v1.69.0 and
  v1.70.0 are unrecorded** (WG-71).
