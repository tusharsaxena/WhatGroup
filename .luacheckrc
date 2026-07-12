-- .luacheckrc — lint config for the Ka0s WhatGroup addon (§14).
-- Run `luacheck .` with 0 errors before every commit.

std = "lua51"
max_line_length = false
codes = true

-- Vendored libs and the audit/review/test trees are not ours to lint.
exclude_files = { "libs/", "audit/", "reviews/", "tests/" }

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
  "IsSpellKnown", "GetSpellInfo", "GetSpellTexture", "CastSpellByID",
  "Enum",
  "GROUP_FINDER_GENERAL_PLAYSTYLE1", "GROUP_FINDER_GENERAL_PLAYSTYLE2",
  "GROUP_FINDER_GENERAL_PLAYSTYLE3", "GROUP_FINDER_GENERAL_PLAYSTYLE4",
  "Settings", "SettingsPanel", "StaticPopup_Show",
  "GameTooltip", "YES", "NO",
  "wipe", "tinsert",
}
