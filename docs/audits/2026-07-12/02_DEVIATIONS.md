# 02 — Deviations

**Addon:** Ka0s WhatGroup · **Prefix:** `WG-` · **Standard:** v1.0.0 (2026-07-12) · **Date:** 2026-07-12

Stable per-addon IDs. Reuse these exact IDs in future audits for any deviation that persists. Severity:
**MUST** = standard violation (bug); **SHOULD** = strongly-preferred, deviation needs a code comment.
Evidence for every row is in `03_EVIDENCE.md`; remediation in `04`/`05` keyed by ID.

## Summary

| Severity | Count | IDs |
|---|---|---|
| MUST | 13 | WG-01 · WG-02 · WG-03 · WG-04 · WG-05 · WG-06 · WG-07 · WG-08 · WG-09 · WG-10 · WG-11 · WG-12 · WG-13 |
| SHOULD | 6 | WG-14 · WG-15 · WG-16 · WG-17 · WG-18 · WG-19 |

**Verdict: major deviations.** The architecture-shaping rules (private namespace, eager settings
registration, Compat, tests, lint, packaging, locale) are unmet, though the schema/panel/slash/taint
core is strong.

---

## MUST

### WG-01 — Global namespace instead of private `NS` (§4.1, §10, anti-pattern #1)
The addon builds and exposes `_G.WhatGroup` as its table; no file uses `local addonName, NS = ...`.
Anti-pattern #1 forbids `_G[addonName]`. Any public surface must go through `NS.API.v1`, not the whole
table. **Fix:** introduce the `local addonName, NS = ...` header in every file, thread `NS` through the
TOC-ordered files, keep the AceAddon object on `NS.addon`; expose only a versioned `NS.API.v1` (if any)
via `_G[addonName]`.

### WG-02 — Settings category registration deferred to first `/wg config` (§6.1, §6.9, anti-pattern #22)
`runConfig` calls `Settings.Register()` on first `/wg config`, so the addon is **missing from the
Blizzard options list until the user runs the slash command**. §6.9 names this exact defect. **Fix:**
register the category **eagerly** from a bootstrap frame on `ADDON_LOADED(Blizzard_Settings)` /
`PLAYER_LOGIN` (taint-safe once `Blizzard_Settings` is loaded); keep only the panel **body** lazy.

### WG-03 — No `Compat.lua`; deprecated/variant APIs called inline (§11, anti-pattern #10)
`GetSpellInfo`, `C_Spell.GetSpellLink/GetSpellName/GetSpellTexture`, `IsSpellKnown`,
`C_LFGList.GetActivityInfoTable` are called directly across `WhatGroup.lua` and `WhatGroup_Frame.lua`
with ad-hoc fallbacks. **Fix:** add `Compat.lua` (loaded first) as the sole caller of version-variant
APIs, exposing `Compat.GetSpellInfo/GetSpellName/GetSpellTexture/GetSpellLink/IsSpellKnown`; route all
call sites through it.

### WG-04 — No headless test harness / not test-first (§14A, anti-pattern #24)
No `tests/` directory, no runner/loader/wow_mock, no covering suites. **Fix:** add the standard
`tests/{run.lua,loader.lua,wow_mock.lua,test_*.lua}` Lua-5.1 harness; cover the pure logic first
(schema validation, defaults build, path resolve, playstyle/type/teleport label selection,
`pickKnownSpell`, capture-merge preference).

### WG-05 — No `.luacheckrc` (§14)
Lint config absent; `luacheck .` cannot run to a defined standard. **Fix:** ship the standard
`.luacheckrc` (`std=lua51`, exclude `libs/ audit/ tests/`, `read_globals` for the WoW API surface used,
`globals = { "WhatGroupDB" }`).

### WG-06 — No `.pkgmeta` (§13)
No packager manifest at root. **Fix:** ship `.pkgmeta` with `package-as: WhatGroup`, **no `externals:`
block**, and an `ignore:` list covering `audit/ docs/ tests/ reviews/ .luacheckrc .gitignore`.

### WG-07 — No locale module (§8.3)
No `enUS.lua` / `NS.L`; UI strings are inline English and playstyle labels read Blizzard `_G` strings.
§8.3 requires at minimum an `enUS.lua` shell and forbids `_G` strings as a locale substitute. **Fix:**
add `Locale.lua` exporting `NS.L = setmetatable({}, {__index=function(_,k) return k end})`; route
user-facing strings through `L[...]`.

### WG-08 — No `schemaVersion` and no `Database.lua` migration runner (§2.2, §5.1)
Defaults build only `profile`; there is no `global.schemaVersion` and no migration function. §2.2/§5.1
make schema migration a from-day-one MUST. **Fix:** add `global = { schemaVersion = 1 }` to defaults and
a `Database.lua` (or `WhatGroup:RunMigrations()`) called after `AceDB:New`, even if the body is empty.

### WG-09 — TOC missing `X-Standard` / `X-Curse-Project-ID` / `X-Wago-ID` (§2.1, §15)
`X-Standard` is a MUST for every addon; the Curse/Wago IDs are MUST **once published** — and WhatGroup
is published (CurseForge 1489907, tagged releases). **Fix:** add `X-Standard: https://github.com/
tusharsaxena/WowAddonStandards`, `X-Curse-Project-ID: 1489907`, and `X-Wago-ID` in the mandated field
order.

### WG-10 — Root `CLAUDE.md` is a full brief, not a stub; `ARCHITECTURE.md` at root (§15.2, §15.3, #26)
Root `CLAUDE.md` carries the whole agent brief and does not declare the tier; §15.2 mandates a **stub**
that names the tier, cites the Standard, and points into `docs/`. `ARCHITECTURE.md` sits at root but
§15.3 places it under `docs/`. **Fix:** move the brief + `ARCHITECTURE.md` into `docs/`, leave a root
`CLAUDE.md` stub declaring **Tier 1** and linking the Standard and `docs/`.

### WG-11 — Logo shipped under `media/screenshots/`, not `media/logos/` (§1.4, §6.5)
`whatgroup.logo.tga`/`.png` live in `media/screenshots/`; §1.4 mandates typed subfolders with the logo
under `media/logos/`. The panel texture path (`WhatGroup_Settings.lua:873`) points at the screenshots
path. **Fix:** move both logo files to `media/logos/` and update the texture path constant.

### WG-12 — Debug flag persisted in SavedVariables (§12.5, anti-pattern #18 context)
`debug` is a schema row persisted to `db.profile.debug` and seeded into `self.debug` at
`OnInitialize`; §12.5 mandates a **session-only** flag (`NS.State.debug`), off on every reload/login,
never in SavedVariables. **Fix:** hold debug state in session-only runtime state, default off, reset each
login; drop `debug` from persisted defaults. (Full on-screen debug console per §12.1–§12.6 is optional
here since there is no §6A data-browser window — chat fallback stays acceptable per §12.7.)

### WG-13 — README non-canonical: missing `## Testing`, missing Standard badge/link, stray section, badge drift (§15.1, §2.3, anti-pattern #28)
README lacks the mandated `## Testing` section and a Standard badge/line, adds a non-canonical
`## For contributors` section, and its `[wow]` badge ("Midnight 12.0.5") is not in lockstep with TOC
`## Interface: 120007`. **Fix:** add `## Testing` (harness + lint + smoke-tests link), add a Standard
badge/link to the badge row, fold/remove `## For contributors`, and sync the `[wow]` badge to `120007`.

---

## SHOULD

### WG-14 — TOC file-listing section headers depart from Tier-1 shape (§2.5)
Uses `# Libraries` + `# Core`; Tier 1 wants `# Libraries (must load first)` then a single `# Addon`
section (no `# Core`). **Fix:** rename `# Core` → `# Addon`.

### WG-15 — TOC field hygiene: no `OptionalDeps`, mis-cased `iconTexture`, out-of-enum `Category-enUS` (§2.1)
Missing `## OptionalDeps: Ace3, LibStub, CallbackHandler-1.0`; `## iconTexture:` should be
`## IconTexture:`; `Category-enUS: Chat & Communication` should be one of the allowed values (`Chat`).
**Fix:** add `OptionalDeps`, correct the casing, set `Category-enUS: Chat`.

### WG-16 — Source file in a `data/` subfolder at Tier 1 (§1.1)
`data/TeleportSpells.lua` is a source file in a subfolder; Tier 1 MUST stay flat. **Fix:** move to a
flat root file (e.g. `TeleportSpells.lua`) and update the TOC line — or, if data files warrant a folder,
document the deviation.

### WG-17 — Mandatory `AceTimer-3.0` neither vendored nor mixed in (§3.1)
The mandatory-lib table lists AceTimer; the addon uses raw `C_Timer.After` and omits AceTimer from
`libs/` and the `NewAddon` mixin list. **Fix:** either vendor AceTimer-3.0 and use it, or add a code
comment recording the deliberate `C_Timer` deviation (§0 SHOULD-comment rule).

### WG-18 — Schema boot-validation runs lazily, not at load (§4.5)
`Helpers.ValidateSchema()` is called from `Settings.Register` (first `/wg config`), so a broken schema
row is not caught until the user opens options. §4.5 mandates validation **at boot**. **Fix:** call
`ValidateSchema` from `OnInitialize`/`OnEnable`, independent of panel registration.

### WG-19 — Chat prefix is a file-local, not exposed `NS.PREFIX`; help header format drift (§7.4)
`CHAT_PREFIX` is a `WhatGroup.lua` local; §7.4 wants a single shared `NS.PREFIX`. The help header also
omits the leading tag/uses a slightly different shape than the mandated `<tag> v<ver> slash commands`.
**Fix:** expose `NS.PREFIX` as the one shared constant and align the help header string.
</content>
