# 05 — Execution Plan (remediation hand-off)

**Addon:** Ka0s WhatGroup · **Prefix:** `WG-` · **Standard:** v1.0.0 (2026-07-12) · **Date:** 2026-07-12

Ordered, checkable remediation steps grouped into sprints, each tied to its deviation ID(s) and the
`04_TECHNICAL_DESIGN.md` section. This is the hand-off to the **separate** remediation engagement — the
audit itself changes no code. Honour `CLAUDE.md`: **no version bump** and **no staging/committing** unless
the human asks in that turn. The §14A commit gate (green `lua tests/run.lua` + clean `luacheck .`) applies
to every commit made during remediation.

Legend: `[ ]` = todo · **MUST** rows block "compliant" · in-game (IG) rows need the client.

---

## Sprint 0 — Toolchain & safety net (enables everything, verifies nothing regresses)
*Design F. Do this first so the risky refactor lands against a net.*

- [ ] **WG-05** Add `.luacheckrc` (std lua51; exclude `libs/ audit/ tests/ reviews/`; read_globals for the WoW surface; `globals={"WhatGroupDB"}`). — MUST
- [ ] **WG-06** Add `.pkgmeta` (`package-as: WhatGroup`; **no `externals:`**; ignore `audit docs tests reviews .luacheckrc .gitignore`). — MUST
- [ ] **WG-04** Add `tests/{run.lua, loader.lua, wow_mock.lua}` harness (Lua 5.1, TOC-order load under `setfenv`, real-dispatch mocks). — MUST
- [ ] **WG-04** Add suites against **current** behaviour: `test_settings.lua`, `test_labels.lua`, `test_capture.lua` (green on today's code — pins behaviour before the refactor). — MUST
- [ ] Gate: `lua tests/run.lua` green, `luacheck .` clean.

## Sprint 1 — Namespace foundation (highest churn; land early)
*Design A, K.*

- [ ] **WG-01** Add `local addonName, NS = ...` to every source file; promote `NS.addon = AceAddon:NewAddon(NS, addonName, …)`; keep methods on `NS.addon`. — MUST
- [ ] **WG-01** Replace `_G.WhatGroup` reads in `WhatGroup_Settings.lua` / `WhatGroup_Frame.lua` with the shared `NS`; remove the global (or reduce it to `NS.API.v1` if a public surface is required). — MUST
- [ ] **WG-19** Expose `NS.PREFIX`; repoint chat output; align `printHelp` header to `<tag> v<ver> slash commands`. — SHOULD
- [ ] Gate: Sprint-0 suites still green (they now exercise the `NS` build); `luacheck .` clean.

## Sprint 2 — Core standard files (Compat, Database, Locale)
*Design C, D, E.*

- [ ] **WG-03** Add `Compat.lua`; move `GetSpellInfo/GetSpellName/GetSpellTexture/GetSpellLink/IsSpellKnown/GetActivityInfoTable` behind `NS.Compat.*`; repoint all call sites. — MUST
- [ ] **WG-08** Add `global.schemaVersion = 1` to defaults + `Database.lua` `NS:RunMigrations()` called after `AceDB:New`. — MUST
- [ ] **WG-07** Add `Locale.lua` (`NS.L` metatable shell); route the addon's own user-facing literals through `L[...]`. — MUST
- [ ] **WG-04** Add `test_compat.lua`, `test_database.lua`; extend suites for the locale/route changes. — MUST (TDD)
- [ ] Gate: `lua tests/run.lua` green, `luacheck .` clean.

## Sprint 3 — Settings registration & boot validation (taint-sensitive)
*Design B. Needs in-game verification — cannot be signed off headlessly.*

- [ ] **WG-02** Register the Settings category **eagerly** after `Blizzard_Settings` loads (bootstrap frame / `OnInitialize`); keep the body lazy. Remove registration from the `/wg config` path (leave `/wg config` as open-only with its combat gate). — MUST
- [ ] **WG-18** Call `Helpers.ValidateSchema()` at load/`OnInitialize`, independent of panel open. — SHOULD
- [ ] **IG** Smoke test the taint repro: fresh `/reload` → GameMenu → Logout → **no `ADDON_ACTION_FORBIDDEN`**; addon entry present in options list **before** first `/wg config`; `/wg config` opens; combat gate holds.

## Sprint 4 — Debug flag session-scoping
*Design I.*

- [ ] **WG-12** Remove `debug` from persisted defaults; hold `NS.State.debug` session-only, default off, reset each login; `/wg debug` toggles runtime flag only; drop the `OnInitialize` seed. — MUST
- [ ] **WG-04** Test: fresh env → debug defaults off; toggling does not write SavedVariables. — MUST (TDD)
- [ ] Gate: `lua tests/run.lua` green, `luacheck .` clean.

## Sprint 5 — TOC, media, file-layout hygiene
*Design H, J.*

- [ ] **WG-09** TOC: add `X-Standard`, `X-Curse-Project-ID: 1489907`, `X-Wago-ID` in mandated order. — MUST
- [ ] **WG-15** TOC: add `OptionalDeps`; fix `IconTexture` casing; `Category-enUS: Chat`. — SHOULD
- [ ] **WG-14** TOC: rename `# Core` → `# Addon`. — SHOULD
- [ ] **WG-16** Move `data/TeleportSpells.lua` → root `TeleportSpells.lua`; update TOC line. — SHOULD
- [ ] **WG-11** Move `media/screenshots/whatgroup.logo.{tga,png}` → `media/logos/`; update `MAIN_LOGO_TEXTURE`. — MUST
- [ ] **WG-17** Decide AceTimer: vendor + mix in + adopt, **or** keep `C_Timer` with a SHOULD-justification comment + ARCHITECTURE note. — SHOULD
- [ ] TOC: add load-order lines for new `Compat.lua` / `Locale.lua` / `Database.lua`.
- [ ] **IG** Smoke test: panel logo renders from new path; addon boots with reordered TOC.

## Sprint 6 — Docs to standard shape
*Design G.*

- [ ] **WG-10** Move full brief → `docs/`; move `ARCHITECTURE.md` → `docs/ARCHITECTURE.md`; leave root `CLAUDE.md` **stub** (declares Tier 1 + Standard link + docs pointer). — MUST
- [ ] **WG-13** README: add `## Testing`; add Standard badge/link; remove/fold `## For contributors`; sync `[wow]` badge to `120007`. — MUST
- [ ] **WG-13** Confirm README section order matches §15.1; repoint internal doc links. — MUST

## Sprint 7 — Final verification
- [ ] `lua tests/run.lua` green; `luacheck .` 0 errors.
- [ ] Full `docs/smoke-tests.md` in-game pass (boot, slash, settings panel present-at-boot, `/wg test`, real LFG join, Logout taint check).
- [ ] Re-audit against the standard: confirm every WG-* MUST is closed; record residual SHOULDs (e.g. WG-17 if the documented-deviation path was chosen) with their justifying comments.

---

## Dependency notes
- Sprint 0 precedes Sprint 1 (net before refactor). Sprint 1 precedes 2–6 (all assume `NS`).
- Sprint 3 is the taint-risk sprint — schedule the in-game Logout smoke test with it, not after.
- Sprints 4, 5, 6 are largely independent of each other and can be parallelised once Sprint 2 lands.
- **Definition of done for "compliant":** all 13 MUST IDs closed and green-gated; SHOULD IDs either
  closed or carrying an in-code justification comment per §0.
</content>
