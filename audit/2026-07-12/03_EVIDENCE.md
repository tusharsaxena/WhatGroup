# 03 — Evidence

**Addon:** Ka0s WhatGroup · **Prefix:** `WG-` · **Standard:** v1.0.0 (2026-07-12) · **Date:** 2026-07-12

`file:line` citations backing every deviation in `02_DEVIATIONS.md` and the key compliance claims in
`01_CURRENT_STATE.md`. Line numbers reflect the working tree at audit time.

---

## Deviation evidence

### WG-01 — Global namespace (§4.1, §10, #1)
- `WhatGroup.lua:22` — `local existing = _G.WhatGroup or {}`
- `WhatGroup.lua:23-25` — `NewAddon(existing, "WhatGroup", "AceConsole-3.0", "AceEvent-3.0")`
- `WhatGroup.lua:26` — `_G.WhatGroup = WhatGroup` (global surface = the whole addon table)
- `WhatGroup_Settings.lua:27` — `LibStub("AceAddon-3.0"):GetAddon("WhatGroup")` (downstream file re-fetches the global, no `NS`)
- `WhatGroup_Frame.lua:1-30` — reads `WhatGroup.*` directly; no `local addonName, NS = ...`
- Confirmed: `grep 'local addonName, NS' *.lua data/*.lua` → **no matches** in any file.

### WG-02 — Deferred settings registration (§6.1, §6.9, #22)
- `WhatGroup.lua:751-753` — `runConfig` calls `self.Settings.Register()` on first `/wg config`
- `WhatGroup.lua:744-750` — comment: "we deliberately don't register at PLAYER_LOGIN … Registering on first /wg config"
- `WhatGroup.lua:116-126` — `OnEnable` comment: "Settings panel registration is deferred to first `/wg config`"
- `WhatGroup_Settings.lua:963-968` — `Settings.Register()` guarded by `_settingsRegistered`; only entered from the slash path
- `WhatGroup_Settings.lua:947-953` — comment: "Called lazily from `runConfig` … **Not** called from `OnEnable`"

### WG-03 — Deprecated/variant APIs inline, no Compat (§11, #10)
- `WhatGroup.lua:310` — `C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(spellID)`
- `WhatGroup.lua:202` / `:206-208` — `IsSpellKnown(...)` direct
- `WhatGroup.lua:173-174` — `C_LFGList.GetActivityInfoTable(firstActivityID)` direct
- `WhatGroup_Frame.lua:203-204` — `C_Spell.GetSpellName(...) or GetSpellInfo(spellID)`
- `WhatGroup_Frame.lua:205-206` — `C_Spell.GetSpellTexture(...) or 134400`
- No `Compat.lua` at root (dir listing) — the "only file that calls deprecated APIs" does not exist.

### WG-04 — No test harness (§14A, #24)
- `ls tests/` → **NO tests/** directory. No `run.lua`/`loader.lua`/`wow_mock.lua`/`test_*.lua`.
- `CLAUDE.md` → "No automated tests. Validation is manual, in-game." (confirms no headless suite)

### WG-05 — No `.luacheckrc` (§14)
- `test -f .luacheckrc` → **NO .luacheckrc** at repo root.

### WG-06 — No `.pkgmeta` (§13)
- `test -f .pkgmeta` → **NO .pkgmeta** at repo root.

### WG-07 — No locale module (§8.3)
- `find … -name '*.lua'` → no `Locale.lua` / `enUS.lua`; no `NS.L` in any file.
- `WhatGroup.lua:236-239` — playstyle labels read Blizzard `_G` strings `GROUP_FINDER_GENERAL_PLAYSTYLE1..4`
- `WhatGroup.lua:242-260` — `GetGroupTypeLabel` returns inline English literals ("Mythic+", "Raid (Current)", …)
- `CLAUDE.md` → "English-only … Localization plumbing is a deliberate non-goal"

### WG-08 — No schemaVersion / no migration runner (§2.2, §5.1)
- `WhatGroup_Settings.lua:306-323` — `BuildDefaults()` returns `{ profile = {...} }` only; no `global`, no `schemaVersion`
- `WhatGroup.lua:105` — `AceDB:New("WhatGroupDB", defaults, true)`; no `RunMigrations` call follows
- No `Database.lua` at root (dir listing).

### WG-09 — TOC missing X-Standard / Curse / Wago (§2.1, §15)
- `WhatGroup.toc:1-10` — fields stop at `## X-License: MIT`; no `X-Standard`, `X-Curse-Project-ID`, `X-Wago-ID`
- `README.md:4` — `![CurseForge Version](https://img.shields.io/curseforge/v/1489907)` (proof it is published → Curse ID 1489907)
- `git tag` → `1.0.0-release`, `1.1.0-release`, `1.2.0-release` (published/tagged)

### WG-10 — Root CLAUDE.md not a stub; ARCHITECTURE.md at root (§15.2, §15.3, #26)
- `CLAUDE.md:1-3` — "# CLAUDE.md — working notes for future sessions" + full hard-rules brief (8.4 KB); no tier declaration, not a stub
- `ARCHITECTURE.md` present at **repo root** (14 KB); §15.3 places it under `docs/`
- Root doc set is README + CLAUDE(full) + ARCHITECTURE + LICENSE; §15 mandates root = README + CLAUDE(stub) + LICENSE only.

### WG-11 — Logo in media/screenshots/ not media/logos/ (§1.4, §6.5)
- `find media -type f` → `media/screenshots/whatgroup.logo.tga`, `…/whatgroup.logo.png` (no `media/logos/`)
- `WhatGroup_Settings.lua:873` — `MAIN_LOGO_TEXTURE = "Interface\\AddOns\\WhatGroup\\media\\screenshots\\whatgroup.logo.tga"`

### WG-12 — Debug flag persisted (§12.5)
- `WhatGroup_Settings.lua:108-115` — schema row `path = "debug"`, `default = false` → threaded into `db.profile` by `BuildDefaults`
- `WhatGroup.lua:110` — `self.debug = self.db.profile.debug and true or false` (seeded from SavedVariables at `OnInitialize`)
- `WhatGroup.lua:107-109` — comment: "Seed runtime debug flag from the persisted preference"
- Debug output goes to chat: `WhatGroup.lua:63-67` — `dbg()` uses `print(CHAT_PREFIX, "[DBG]", ...)`

### WG-13 — README non-canonical (§15.1, §2.3, #28)
- `README.md` headings: `## Screenshots`, `## Usage`, `## How It Works`, `## FAQ`, `## Troubleshooting`, `## For contributors`, `## Issues and feature requests`, `## Version History`
- `grep -ci testing README.md` → **0** (no `## Testing` section)
- `grep -ci 'WowAddonStandards\|Addon Standard' README.md` → **0** (no Standard badge/link)
- `README.md:79` — `## For contributors` (non-canonical section)
- `README.md:3` — `![wow](…/WoW-Midnight_12.0.5-orange)` vs `WhatGroup.toc:1` `## Interface: 120007` (badge not in lockstep)

### WG-14 — TOC section headers (§2.5)
- `WhatGroup.toc:12` — `# Libraries (must load first)`; `WhatGroup.toc:21` — `# Core` (Tier 1 wants `# Addon`)

### WG-15 — TOC field hygiene (§2.1)
- `WhatGroup.toc:1-10` — no `## OptionalDeps:` line
- `WhatGroup.toc:6` — `## iconTexture: 134149` (should be `IconTexture`)
- `WhatGroup.toc:9` — `## Category-enUS: Chat & Communication` (allowed set: Combat|Group|Auction|Chat|UI|Misc)

### WG-16 — data/ source subfolder at Tier 1 (§1.1)
- `WhatGroup.toc:23` — `data\TeleportSpells.lua` listed as source; file lives at `data/TeleportSpells.lua`

### WG-17 — AceTimer not vendored/mixed (§3.1)
- `ls libs/` → AceAddon, AceConsole, AceDB, AceEvent, AceGUI, CallbackHandler-1.0, LibStub — **no AceTimer-3.0**
- `WhatGroup.lua:23-25` — `NewAddon(...)` mixes only `AceConsole-3.0`, `AceEvent-3.0`
- `WhatGroup.lua:393` — `C_Timer.After(delay, …)` (raw C_Timer instead of AceTimer)

### WG-18 — Schema validation lazy, not boot (§4.5)
- `WhatGroup_Settings.lua:982` — `Helpers.ValidateSchema()` called inside `Settings.Register` (first `/wg config`)
- `WhatGroup.lua:97-114` — `OnInitialize` does not call `ValidateSchema`

### WG-19 — Prefix not NS.PREFIX; help header drift (§7.4)
- `WhatGroup.lua:53` — `local CHAT_PREFIX = "|cff00FFFF[WG]|r"` (file-local, not exposed `NS.PREFIX`)
- `WhatGroup.lua:553-558` — `printHelp` header `"v" .. VERSION .. " — slash commands (…)"` (differs from `<tag> v<ver> slash commands`)

---

## Compliance evidence (claims that the addon already meets the standard)

- **Schema-as-single-source (§4.5):** schema array `WhatGroup_Settings.lua:73-184`; single write-path `Helpers.Set` `WhatGroup_Settings.lua:231-245`; defaults from schema `:306-323`; slash `list/get/set` `WhatGroup.lua:582-669`.
- **Options panel look (§6.5–§6.10):** landing page + General subcategory `WhatGroup_Settings.lua:986-1054`; two-column render `:817-862`; always-visible scrollbar `:534-641`; gold header/divider + breadcrumb `:442-483`; lazy `OnShow` body in `C_Timer.After(0,…)` `:1000-1008`, `:1032-1050`.
- **Slash dispatch (§7.1–§7.3):** `RegisterChatCommand("wg"/"whatgroup")` `WhatGroup.lua:112-113`; ordered `COMMANDS` `:525-545`; generated help `:553-559`; unknown-verb + help `:574-576`; case-preserving remainder `:566-569`.
- **Taint / observation-only (§9):** direct `hooksecurefunc` `WhatGroup.lua:39-51`; no AceHook (per `CLAUDE.md`); combat guards `WhatGroup.lua:739-740`, `WhatGroup_Frame.lua:173-187`, `:282-303`; secure teleport via `SecureActionButtonTemplate` macro `WhatGroup_Frame.lua:124-127`, `:216-217`.
- **AceDB single global (§5.1 structure):** `WhatGroup.lua:105`; session-only capture state `:55-61`, wiped on leave `:406-412`.
- **Vendored, committed, no externals (§3.3):** `ls libs/` folder-per-lib; no `.pkgmeta externals` (no `.pkgmeta` at all).
- **Single Retail Interface (§2.3):** `WhatGroup.toc:1` `## Interface: 120007` (single value).
- **File-size cap (§1.1):** `wc -l` → 792 / 1056 / 319 / 120 LOC, all < 1500.
- **Semver (§17):** `WhatGroup.toc:5` `1.2.0`; `WhatGroup.lua:27` `VERSION = "1.2.0"`.
</content>
