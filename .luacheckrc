-- .luacheckrc — lint config for the Ka0s WhatGroup addon (lint).
-- Run `luacheck .` with 0 errors before every commit.

std = "lua51"
max_line_length = false
codes = true

-- libs/ holds vendored code, including libs/LibKa0s/ whose upstream is the LibKa0s repo, so it is
-- linted there and not here. tests/_kit/ is the same fact one level down: it is a byte copy of the
-- library's testkit/, linted in LibKa0s as source, and linting the copy too would report every
-- finding twice while letting the copy drift green as the original went red -- the one state
-- tests/test_vendor_sync.lua exists to make impossible. Everything else under tests/ is ours and is
-- linted (lint-§1). Under docs/ only the FROZEN evidence bundles are excluded; a blanket docs/
-- exclude would silently drop any Lua a future doc directory carries out of the gate. _dev/ is the
-- scratch directory .pkgmeta:12 already reserves, listed here so the two config files agree about
-- it whether or not it exists today.
exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }

ignore = {
  "211/addonName", -- canonical `local addonName, NS = ...` header; NS is what's used
  "212",           -- unused args are idiomatic in Blizzard hook/event signatures
  "542",           -- intentional empty branch documenting an LFG state (invited)
}

-- SavedVariables + the one global table the addon writes (lazily) to.
globals = {
  "WhatGroupDB",
  "StaticPopupDialogs",
}

-- The WoW API surface the addon reads. Compat.lua owns the version-variant
-- spell / LFG calls; the rest are frame, settings, timer, and combat APIs.
read_globals = {
  "_G",
  "LibStub", "hooksecurefunc",
  "CreateFrame", "UIParent", "UISpecialFrames",
  "InCombatLockdown", "IsInGroup",
  "C_Timer", "C_AddOns", "GetAddOnMetadata",
  "C_Spell", "C_LFGList",
  "IsSpellKnown", "GetSpellInfo", "GetSpellTexture", "GetSpellCooldown", "CastSpellByID",
  "GetTime",
  "Enum",
  "GROUP_FINDER_GENERAL_PLAYSTYLE1", "GROUP_FINDER_GENERAL_PLAYSTYLE2",
  "GROUP_FINDER_GENERAL_PLAYSTYLE3", "GROUP_FINDER_GENERAL_PLAYSTYLE4",
  "Settings", "SettingsPanel", "StaticPopup_Show",
  "GameTooltip", "YES", "NO",
  "wipe", "tinsert", "date",
}

-- The harness publishes its exposed table under a per-repo global, written at tests/run.lua:75 and
-- read by every suite file. It is declared HERE rather than in the top-level `read_globals` on
-- purpose: a name granted at the top level is granted to core/, modules/ and settings/ as much as
-- to a suite, and no shipped file may ever reach for the test harness. `globals` rather than
-- `read_globals` because tests/run.lua is the writer.
files["tests/"] = {
  globals = {
    "_G.WHATGROUP_TEST",
    -- The SavedVariables table, named as a field rather than bare because tests/loader.lua:91
    -- CLEARS it before each boot -- the kit's AceDB fake resolves the name against the real _G, so
    -- a previous instance's table would otherwise be adopted by the next one. The bare name is
    -- already writable above, for the shipped files that own it.
    "_G.WhatGroupDB",
  },
}
