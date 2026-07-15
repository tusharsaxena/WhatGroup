-- locales/enUS.lua
-- Localization shell. Loaded early (after Compat) so every later file can
-- route its user-facing literals through NS.L[...].
--
-- English-only is a deliberate project stance (see docs/scope.md), but the
-- Ka0s Standard (§8.3) still mandates a locale MODULE so strings are never
-- hardcoded at the call site and never sourced from Blizzard `_G` globals
-- as a substitute. NS.L carries a fall-back metatable: any missing key
-- returns the key itself, so routing a literal through L[...] is behaviour-
-- preserving even before a translation exists. A future translator copies
-- this file, changes the right-hand values, and gates it with
-- `if GetLocale() ~= "<locale>" then return end`.
--
-- Playstyle enum VALUES still source Blizzard's own localized
-- GROUP_FINDER_GENERAL_PLAYSTYLE1..4 globals (WhatGroup.lua) — those are
-- Blizzard's strings, not the addon's, so they stay on the Blizzard side.
--
-- SCOPE: the player-facing surfaces route through L — the join notification,
-- the popup dialog, the help header + command descriptions, and the reset
-- confirmation. Slash-CLI diagnostics ("unknown command", "Usage: …",
-- "Settings layer not ready yet", "debug logging ON/OFF") are deliberately
-- NOT routed: they are developer/power-user feedback for the `/wg`
-- command line, not chrome a translator would localize. Keeping them out
-- keeps this table focused on the strings a player actually reads.

local addonName, NS = ...

local L = setmetatable({}, {
    __index = function(_, k) return k end,
})
NS.L = L

-- ---------------------------------------------------------------------------
-- Strings
-- ---------------------------------------------------------------------------
-- Keep the right-hand side identical to the key: the key IS the English
-- phrase, the fall-back metatable already returns it, and these explicit
-- rows exist so a translator has the full surface in one place.

-- Chat notification
L["You have joined a group!"] = "You have joined a group!"
L["Group:"]                   = "Group:"
L["Instance:"]                = "Instance:"
L["Type:"]                    = "Type:"
L["Leader:"]                  = "Leader:"
L["Playstyle:"]               = "Playstyle:"
L["Teleport:"]                = "Teleport:"
L["[Click here to view details]"] = "[Click here to view details]"
L["(not learned)"]            = "(not learned)"
L["Unknown"]                  = "Unknown"

-- Popup dialog
L["WhatGroup"]                = "WhatGroup"
L["Group Info"]               = "Group Info"
L["Close"]                    = "Close"
L["No data"]                  = "No data"

-- Group-type labels (GetGroupTypeLabel)
L["Mythic+"]                  = "Mythic+"
L["Raid (Current)"]           = "Raid (Current)"
L["Heroic Raid"]              = "Heroic Raid"
L["PvP"]                      = "PvP"
L["Dungeon"]                  = "Dungeon"
L["Raid"]                     = "Raid"
L["Group"]                    = "Group"

-- Settings panel
L["Ka0s WhatGroup"]           = "Ka0s WhatGroup"
L["General"]                  = "General"
L["Slash Commands"]           = "Slash Commands"
L["Defaults"]                 = "Defaults"

-- StaticPopup / reset
L["Reset every WhatGroup setting to its default? The active profile is the only one affected."] =
    "Reset every WhatGroup setting to its default? The active profile is the only one affected."
L["all settings reset to defaults"] = "all settings reset to defaults"

-- Slash / hint messages
L["slash commands"]           = "slash commands"
L["No group info available. Use |cffFFFF00/wg test|r to preview."] =
    "No group info available. Use |cffFFFF00/wg test|r to preview."
L["Group info no longer available — captures clear on group-leave or |cffFFFF00/reload|r. Use |cffFFFF00/wg test|r to preview."] =
    "Group info no longer available — captures clear on group-leave or |cffFFFF00/reload|r. Use |cffFFFF00/wg test|r to preview."
L["Cannot open the settings panel during combat. Try again after combat ends."] =
    "Cannot open the settings panel during combat. Try again after combat ends."
L["Popup deferred until combat ends."] = "Popup deferred until combat ends."
