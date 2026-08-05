# Ka0s WhatGroup — Current State (2026-08-05)

**Audited against:** Ka0s WoW Addon Standard **v2.21.0 (2026-08-04)**.

**Standard provenance.** `AUDIT.md`, `standards/STANDARDS.md` and **all 25** section files linked
from the index's Sections list were fetched over the network with `curl -fsSL` from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` into a scratch directory
and read verbatim. Section filenames were discovered by following the Sections list, not hard-coded.
No section went unread; no rule below is reconstructed from memory.

**Addon under audit:** `/mnt/d/Profile/Users/Tushar/Documents/GIT/WhatGroup` at `b31c90d`
(2026-08-05), version **1.3.0**, TOC `## Interface: 120007`.

**Scope constraint on this run.** The engagement is single-repo: no sibling repository was read.
The two Ka0s-owned vendor diffs (`../LibKa0s/LibKa0s` vs `libs/LibKa0s`, `../LibKa0s/testkit` vs
`tests/_kit`) are therefore recorded as **NOT RUN / unverified** in `03_EVIDENCE.md`, never as a
pass.

---

## 1. Layout, TOC, packaging

- **layout** — the mandated modular tree is present and complete:
  `core/` (`CoreSetup`, `Util`, `Compat`, `Database`, `WhatGroup`, `DebugLogSetup`), `defaults/`
  (`Profile`, `TeleportSpells`), `locales/enUS.lua`, `modules/Frame.lua`, `settings/`
  (`Schema`, `OptionsSetup`, `Panel`, `Slash`), `libs/`, `tests/`, `media/` with typed subfolders
  (`fonts/`, `logos/`, `screenshots/`) and no loose files.
- No file is near a LOC band: largest shipped file is `core/WhatGroup.lua` at 718 lines, largest
  test `tests/test_libka0s.lua` at 645 — the 1000-LOC on-notice band is ~280 lines away.
- **toc-file** — `WhatGroup.toc:1-13` carries the metadata block in the mandated field order
  (`Interface`, `Title`, `Notes`, `Author`, `Version`, `IconTexture`, `SavedVariables`,
  `OptionalDeps`, `DefaultState`, `Category-enUS`, `X-License`, `X-Standard`,
  `X-Curse-Project-ID`), single Retail Interface, MIT license, no hard `Dependencies`. The file
  listing (`:15-49`) uses the `# Libraries → # Locales → # Core → # Defaults → # Modules →
  # Settings` section comments in load order, and lists `libs\LibKa0s\LibKa0s.xml` **once**, after
  Ace3 — never individual LibKa0s `.lua` files.
  - Deviation: **one** SavedVariables global, not the mandated two (`WG-31`).
  - Deviation: no `core/PerfSetup.lua` slot in `# Core` (`WG-30`).
- **packaging** — `.pkgmeta` declares `package-as: WhatGroup`, **no `externals:` block**, and
  ignores `.luacheckrc`, `.gitignore`, `.gitattributes`, `docs`, `tests`. `_dev` and lockfiles are
  missing from the ignore list (`WG-36`).

## 2. Library stack and the shared subsystems

- Vendored, committed: LibStub, CallbackHandler-1.0, AceAddon/AceEvent/AceConsole/AceTimer/AceDB/
  AceGUI-3.0, LibSharedMedia-3.0, and the Ka0s-owned `libs/LibKa0s/`.
- `libs/LibKa0s/` is the **whole ship folder**: `Core.lua` (minor 4), `DebugLog.lua` (7),
  `Slash.lua` (6), `Options.lua` (6), `OptionsWidgets.lua`, `OptionsScroll.lua`, `Perf.lua` (6),
  `PerfPanel.lua`, plus `LICENSE` and the aggregate `LibKa0s.xml`, which lists all eight `.lua`
  files. Nothing is missing on the addon side (**anti-pattern #48 clear**), and the TOC loads the
  aggregate once (`WhatGroup.toc:24`).
- **The addon owns descriptors and stubs, not implementations.** There is no `modules/DebugLog.lua`,
  no widget-maker file, no addon-local dispatcher, no hand-written test framework anywhere in the
  repo — **anti-pattern #47 is clear**. What it owns:
  - `core/CoreSetup.lua:39` — `LibStub("LibKa0s-Core-1.0", true)`; descriptor at `:126-129`
    (`prefix` as a function, explicit `sink`); library-absent branch `:41-100` publishes
    `IsConcatSafe`, `SafeToString`, `Util.print`, `Util.format`, `SKIN`, `ApplySkin`,
    `MakeCloseButton`.
  - `core/DebugLogSetup.lua:20` — `LibStub("LibKa0s-DebugLog-1.0", true)`; descriptor `:88-136`;
    stub `:22-86` answers 19 members plus `NS.Debug`.
  - `settings/OptionsSetup.lua:17` — `LibStub("LibKa0s-Options-1.0", true)`; descriptor `:98-141`;
    the **load-completing** stub `:19-84` (the documented options-ui-§1 exception, with its measured
    justification at `:26-31`).
  - `settings/Slash.lua:71` — `LibStub("LibKa0s-Slash-1.0", true)`; the addon's own `COMMANDS`
    table `:43-67` crosses as plain data; stub `:78-...` re-implements no formatter or parser.
  - `tests/_kit/` — the vendored headless harness (`framework.lua`, `loader.lua`, `mock_base.lua`,
    `run-automated-tests.sh`, `README.md`), correctly under `tests/`, never `libs/`.
  - **`LibKa0s-Perf-1.0` is vendored but not wired** — there is no `core/PerfSetup.lua` and no
    `NS.Perf` (`WG-30`). The decline is a recorded user decision (`docs/pending/LEDGER.md`,
    `LIBKA0S-15`).

## 3. Architecture, settings, slash, debug

- `local addonName, NS = ...` private-namespace bootstrap in every file; AceAddon object at
  `core/WhatGroup.lua`; `NS.Print` reclaimed after the AceConsole embed (anti-pattern #36 handled
  explicitly at `core/CoreSetup.lua:16-19`). No message bus — one feature module, direct calls.
- **savedvariables** — AceDB tree, `defaults/Profile.lua`, `schemaVersion` seeded and a real
  migration runner at `core/Database.lua:23-40`. Defaulting of stored settings is `== nil`-shaped or
  routed through AceDB; the `or` chains in `buildCapture` (`core/WhatGroup.lua:210-241`) are over
  **live API capture data**, not stored settings, and carry the reasoning at `:203-209` — not
  anti-pattern #54.
- **options-ui** — one Blizzard Settings category with a landing page and a `General` subcategory,
  built by the library from the descriptor; body lazy, category eager at `OnEnable`
  (`core/WhatGroup.lua:160-161`) — except that `Settings.Register()` refuses under combat
  (`settings/Panel.lua:268-272`, `WG-40`).
- **slash-commands** — AceConsole registration, eleven schema-driven verbs in `NS.COMMANDS`
  (`settings/Slash.lua:43-67`), cyan `[WG]` prefix on every line. The reserved `perf` verb is
  absent (`WG-32`).
- **debug-logging** — the on-screen console is the library's, wired at `core/DebugLogSetup.lua:88`;
  session-only flag stays the addon's; `NS.FONT_MONO` is the vendored JetBrains Mono path
  (`core/WhatGroup.lua:96`) with no Blizzard fetch-failure fallback (`WG-42`).
- **localization** — metatable-fallback `NS.L`, English-string keys, US English throughout the
  addon's own source and docs (checked: zero British-spelled tokens outside `libs/`).
- **compat** — `core/Compat.lua` owns the cross-patch spell/LFG calls.

## 4. Tests, lint, automated-test record

- Headless harness on the vendored kit: `tests/run.lua`, `tests/loader.lua`, `tests/wow_mock.lua`
  and 14 `test_*.lua` suites. **422 cases, 422 passing** (measured this run).
- `docs/test-cases.md` regenerates **identically** from `lua5.1 tests/run.lua --list` (diff empty).
- `luacheck .` — **0 warnings / 0 errors in 14 files** (measured). `.luacheckrc` excludes
  `libs/`, `docs/audits/`, `docs/reviews/`, `tests/`; it omits `debugprofilestop` and
  `WhatGroupPerfDB` (`WG-35`).
- `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` — **808 functions, 5573 NLOC, avg CCN 1.7,
  0 functions over CCN 15**, max CCN 13. **Zero drift** against the newest bundle
  `docs/automated-tests/20260804-233335/complexity.txt` — every footer figure matches.
- Three run bundles under `docs/automated-tests/`, each with `manifest.json`, `ANALYSIS.md`,
  `lint.txt`, `tests.txt`, `test-cases.md`, `complexity.txt`. `RESULTS.md` is one file with the
  trend table, the two watch-list tables (both **"None."**, correctly written as a result) and
  standing sections for all four suites. `.gitattributes` carries `*.sh text eol=lf`; the runner is
  vendored and executable (`-rwxrwxrwx`). **No retired `docs/complexity.md`** — correct as of
  standard v2.19.0.
- What the record does **not** say: the v2.21.0 **release gate** (all four suites pass plus
  `suites.complexity.warnings == 0` at the tag) appears nowhere in the addon's docs (`WG-45`).

## 5. The doc set

- **Root — exactly three docs plus LICENSE:** `README.md` (full, player-facing, canonical badge row
  with `_`-spaced standard badge, `[wow]` badge `Midnight_12.0.7` matching the TOC, `[tests]` badge
  `422/422` matching the inventory), `CLAUDE.md` (stub with `## Standards compliance (read first)`),
  `DEPENDENCIES.md` (runtime / development / release split, `pipx` instruction, per-tool
  verification commands). No fourth root doc.
- **The `docs/` canonical trio** — `ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`: all three
  present (`ARCHITECTURE.md` under its own headings, `WG-39`).
- **The five required topic-detail docs** — `test-cases.md` ✅ (generated, in sync),
  `automated-tests/README.md` ✅, `automated-tests/RESULTS.md` ✅, `performance.md` ❌,
  `perf-runs/README.md` ❌ (`WG-33`).
- **The three-place standards reference** — TOC `## X-Standard:` (`WhatGroup.toc:12`), README badge
  (`README.md:6`), `CLAUDE.md` `## Standards compliance (read first)` (`CLAUDE.md:6-25`). **All
  three present** — anti-pattern #34 clear.
- No `docs/agent-context.md` (anti-pattern #49 clear; `CLAUDE.md:33-38` says it must never return);
  no `TODO.md` anywhere.
- Frozen bundles: `docs/audits/{2026-07-12,2026-07-18,2026-08-04}/` and
  `docs/reviews/{2026-05-02,2026-08-03,2026-08-05}/`; none edited by this run.
</content>
</invoke>
