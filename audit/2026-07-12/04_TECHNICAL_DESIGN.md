# 04 — Technical Design (remediation)

**Addon:** Ka0s WhatGroup · **Prefix:** `WG-` · **Standard:** v1.0.0 (2026-07-12) · **Date:** 2026-07-12

How to close each gap in `02_DEVIATIONS.md`. This is a **design**, not an edit — remediation is a
separate engagement (execution ordered in `05_EXECUTION_PLAN.md`). Every heading is keyed to its
deviation ID(s). Remediation must preserve the addon's genuine strengths (schema/panel/slash/taint).

---

## Guiding constraints (from `CLAUDE.md`, honoured by this design)

- **Observation-only, direct `hooksecurefunc` only** — no AceHook. Remediation must not reintroduce
  AceHook while restructuring the namespace.
- **Taint discipline is real.** The deferred registration (WG-02), lazy StaticPopup, and lazy frame
  build all exist to dodge the GameMenu-Logout `ADDON_ACTION_FORBIDDEN` taint. The WG-02 fix must
  re-implement eager registration the **taint-safe** way the standard prescribes (register **after
  `Blizzard_Settings` is loaded**, body stays lazy) — verified against the Logout smoke test — not by
  naively moving `Settings.Register()` to file-load.
- **English-only** is a project stance, but §8.3 still mandates a locale **shell** (WG-07). The shell
  satisfies the standard without adding translations.
- **No version bump** and **no auto-commit** as part of remediation unless the human asks.

---

## A. Namespace refactor — WG-01 (foundational; do first)

Introduce the private-namespace pattern the rest of the standard assumes.

- Add `local addonName, NS = ...` as the first line of every source file (`WhatGroup.lua`,
  `WhatGroup_Settings.lua`, `WhatGroup_Frame.lua`, `TeleportSpells.lua`, and the new `Compat.lua`,
  `Locale.lua`, `Database.lua`).
- Promote the bootstrap: `NS.addon = AceAddon:NewAddon(NS, addonName, "AceConsole-3.0", "AceEvent-3.0"
  [, "AceTimer-3.0"])`. Keep method definitions on `NS.addon` (or `NS` mixed) so existing
  `WhatGroup:Method` call sites migrate to `NS.addon:Method`.
- Replace `_G.WhatGroup` reads in Settings/Frame with the shared `NS` upvalue. If nothing third-party
  anchors to the addon, **remove** the global entirely; if a public surface is ever needed, expose only
  `NS.API.v1` via `_G[addonName]` (§10).
- **Risk:** highest-churn change; touches nearly every function. Land it before anything else so later
  files are authored against `NS`. Mitigate with the new test harness (WG-04) as a regression net —
  which is why the harness lands alongside, not after.

## B. Eager, taint-safe settings registration — WG-02, WG-18

- Add a bootstrap frame (or `OnInitialize` + an `ADDON_LOADED == "Blizzard_Settings"` guard) that calls
  `Settings.Register()` **once, eagerly**, after `Blizzard_Settings` is available — so the category is
  always in the options list. Keep the panel **body** lazy in first `OnShow` (already implemented,
  `WhatGroup_Settings.lua:1000-1050`).
- Move `Helpers.ValidateSchema()` (WG-18) out of `Settings.Register` into the load/`OnInitialize` path
  so schema shape is validated at boot regardless of whether the panel is opened.
- Keep `/wg config` as a pure **open** (`Settings.OpenToCategory`) with its existing `InCombatLockdown`
  gate; registration no longer lives behind it.
- **Risk:** taint regression. This is the delicate one — the whole deferral exists to avoid Logout
  taint. Validate against the exact repro in `docs/wow-quirks.md` (fresh `/reload`, open GameMenu, click
  Logout → no `ADDON_ACTION_FORBIDDEN`). Registering after `Blizzard_Settings` loads is the standard's
  attested taint-free timing.

## C. Compat layer — WG-03

- New `Compat.lua` (first source file after libs). Expose `NS.Compat.GetSpellInfo/GetSpellName/
  GetSpellTexture/GetSpellLink/IsSpellKnown/GetActivityInfoTable`, each wrapping the `C_Spell.*`/legacy
  fallback currently inlined.
- Rewrite call sites in `WhatGroup.lua` (`:173`, `:202-208`, `:310`) and `WhatGroup_Frame.lua`
  (`:203-206`) to call `NS.Compat.*`. Compat becomes the sole caller of the variant APIs.
- **Risk:** low; pure extraction. Cover each shim with a `test_compat.lua` case using the wow_mock.

## D. Database / schemaVersion — WG-08

- Add `global = { schemaVersion = 1 }` to the defaults (extend `BuildDefaults` to emit a `global`
  block, or merge one in `OnInitialize`).
- New `Database.lua` with `function NS:RunMigrations()` (empty body guarded by `schemaVersion`), called
  right after `AceDB:New`. Establishes the migration seam from day one.
- **Risk:** low. Add `test_database.lua` asserting a fresh DB lands at `schemaVersion == 1` and
  migrations are idempotent.

## E. Locale shell — WG-07

- New `Locale.lua`: `NS.L = setmetatable({}, {__index=function(_,k) return k end})`, loaded early
  (after Compat/Constants). Populate keys for the user-facing literals (notify labels, popup labels,
  slash descriptions, StaticPopup text).
- Route those literals through `L[...]`. Playstyle enum labels may still source Blizzard `_G` strings
  for their *values*, but the locale module must exist (§8.3) and own the addon's own strings.
- **Risk:** low, mechanical. No translations required to satisfy the shell.

## F. Test harness + lint + packaging — WG-04, WG-05, WG-06

- `tests/{run.lua, loader.lua, wow_mock.lua}` per §14A.1: build the env by loading sources in TOC order
  under `setfenv`, mock the WoW surface used (C_LFGList, C_Spell, IsSpellKnown, C_Timer, Settings,
  CreateFrame, LibStub/AceDB/AceAddon fakes, `GROUP_FINDER_*` globals, `Enum.LFGEntryGeneralPlaystyle`).
- Suites (pure logic first): `test_settings.lua` (schema validate, BuildDefaults, Resolve/Get/Set,
  RestoreDefaults), `test_labels.lua` (`GetGroupTypeLabel`, `GetPlaystyleLabel`, `pickKnownSpell`),
  `test_capture.lua` (fresh-vs-queued mapID-preference merge in `LFG_LIST_APPLICATION_STATUS_UPDATED`),
  `test_compat.lua`, `test_database.lua`.
- `.luacheckrc`: `std=lua51`, `exclude_files={"libs/","audit/","tests/","reviews/"}`, `read_globals` for
  the WoW API surface, `globals={"WhatGroupDB"}` (with justifying comment).
- `.pkgmeta`: `package-as: WhatGroup`, **no `externals:`**, `ignore: [audit, docs, tests, reviews,
  .luacheckrc, .gitignore]`.
- **Risk:** the capture-merge path is event-timing heavy; model real dispatch in the mock (no-op mocks
  hide bugs — §14A). Getting the harness green also protects the WG-01 refactor.

## G. Docs restructure — WG-10, WG-13

- Move the full agent brief from root `CLAUDE.md` into `docs/` (e.g. `docs/agent-context.md`), and move
  `ARCHITECTURE.md` → `docs/ARCHITECTURE.md`. Leave a root `CLAUDE.md` **stub**: declares **Tier 1**,
  states adherence to the Ka0s Standard (link), and points into `docs/`.
- README (§15.1): add `## Testing` (harness `lua tests/run.lua`, `luacheck .`, link
  `docs/smoke-tests.md`), add a Standard badge/link to the badge row, fold `## For contributors` into
  `## Testing`/`## Issues and feature requests` (remove the non-canonical heading), and sync the `[wow]`
  badge to `120007`.
- **Risk:** none functional; ensure internal doc links (CLAUDE.md's doc index) are repointed.

## H. TOC + media hygiene — WG-09, WG-11, WG-14, WG-15, WG-16

- TOC: insert `X-Standard`, `X-Curse-Project-ID: 1489907`, `X-Wago-ID` (WG-09); add `OptionalDeps`, fix
  `IconTexture` casing, set `Category-enUS: Chat` (WG-15); rename `# Core` → `# Addon` (WG-14); if
  vendoring AceTimer (WG-17) add its lib lines in the `# Libraries` block. Keep the mandated field order.
- Move `media/screenshots/whatgroup.logo.{tga,png}` → `media/logos/` and update `MAIN_LOGO_TEXTURE`
  (`WhatGroup_Settings.lua:873`) (WG-11).
- Move `data/TeleportSpells.lua` → root `TeleportSpells.lua`, update the TOC line (WG-16).
- **Risk:** low; verify the panel logo still resolves in-game after the path change.

## I. Debug flag → session-only — WG-12

- Remove `debug` from persisted defaults; hold it in session-only runtime state (`NS.State.debug`, or a
  module local), default **off**, reset each login. `/wg debug` toggles the runtime flag only.
- Keep chat-frame debug output (acceptable via §12.7 — no §6A data-browser window). A full on-screen
  console (§12.1–§12.6) is **optional** here and out of scope unless a persistent main window is added.
- **Risk:** low; drop the `WhatGroup.lua:110` seed and the schema row; ensure `runDebug` no longer
  writes to `db.profile`.

## J. AceTimer decision — WG-17

- Either (a) vendor `AceTimer-3.0`, add to `libs/`, mix into `NewAddon`, and replace `C_Timer.After`
  usages; or (b) keep `C_Timer` and add a one-line SHOULD-justification comment at each use plus a note
  in `docs/ARCHITECTURE.md`. Pick one; (b) is lower-churn and the addon's timer needs are trivial.

## K. Prefix constant — WG-19

- Expose the cyan tag as `NS.PREFIX` (single shared constant); repoint `WhatGroup.lua:53` and the
  Settings `pout` path at it. Align the `printHelp` header with the §7.4 `<tag> v<ver> slash commands`
  shape.
- **Risk:** trivial.

---

## Cross-cutting risks & ordering notes

- **WG-01 first, WG-04 in lockstep.** The namespace refactor is the riskiest change; do it with the
  harness as a net. Everything else assumes `NS`.
- **WG-02 needs in-game taint verification** — it cannot be signed off by headless tests alone; it rides
  the GameMenu-Logout smoke test.
- New files (`Compat.lua`, `Locale.lua`, `Database.lua`, moved `TeleportSpells.lua`) each need a TOC
  line in correct load order: Libraries → `Compat` → `Locale` → `Database`/data → `WhatGroup.lua` →
  `Settings` → `Frame`.
- No behaviour change is intended for the capture pipeline; the merge logic and event timing are
  correct today and must be preserved (covered by `test_capture.lua`).
</content>
