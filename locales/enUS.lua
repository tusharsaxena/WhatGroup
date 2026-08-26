-- locales/enUS.lua
-- Localization shell. Loaded first among the addon files (the `# Locales`
-- section precedes `# Core`, toc-file-§5 / WG-14) so every later file can
-- route its user-facing literals through NS.L[...].
--
-- English-only is a deliberate project stance (see docs/scope.md), but the
-- Ka0s Standard (localization-§3) still mandates a locale MODULE so strings are never
-- hardcoded at the call site and never sourced from Blizzard `_G` globals
-- as a substitute. NS.L carries a fall-back metatable: any missing key
-- returns the key itself, so routing a literal through L[...] is behavior-
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
-- keeps this table focused on the strings a player actually reads. So are the
-- library's own strings (the "Defaults" button, the combat-refusal notice):
-- LibKa0s-Options-1.0 authors those, and a copy here would be a second source
-- of truth that drifts.
--
-- That partial routing is a RATIFIED deviation from localization-§3's routing
-- SHOULD, not an oversight — see `## Documented deviations` in
-- docs/ARCHITECTURE.md, whose re-check trigger is the first non-English locale
-- file. A key with no L[...] reader is a defect either way: it tells a
-- translator a surface is covered when it is not. This table therefore holds
-- only keys something actually looks up.

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
L["(on cooldown)"]            = "(on cooldown)"
L["On cooldown"]              = "On cooldown"
L["Teleport spell not learned"] = "Teleport spell not learned"
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

-- Settings panel. Only the landing page's own heading lives here. Three former
-- rows were dropped as unroutable rather than left as keys nothing reads:
-- "Ka0s WhatGroup" is the brand (the TOC Title and the Blizzard category label,
-- not prose); "General" is simultaneously the page id, the schema `group` key
-- and the subcategory label, so translating the display copy alone would
-- silently unmatch the schema; "Defaults" is the library's DEFAULTS_LABEL, not
-- a string this addon authors.
L["Slash Commands"]           = "Slash Commands"

-- StaticPopup / reset
L["Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded \226\128\148 your other profiles are not affected."] =
    "Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded \226\128\148 your other profiles are not affected."
L["all settings reset to defaults"] = "all settings reset to defaults"

-- Slash command descriptions (settings/Slash.lua's COMMANDS table). The help
-- HEADER is no longer routed through here: LibKa0s-Slash-1.0 composes it from
-- the addon's version and its slash alias, and translating it would mean
-- overriding the library's HELP_HEADER through a descriptor `L` — which is a
-- decision for a translator to take, not a string this file can hold.
L["List available commands"]  = "List available commands"
L["Show the last group info dialog"] = "Show the last group info dialog"
L["Inject synthetic group info and run the full notify + frame flow"] =
    "Inject synthetic group info and run the full notify + frame flow"
L["Open the Ka0s WhatGroup Settings panel"] = "Open the Ka0s WhatGroup Settings panel"
L["Print the addon version"]  = "Print the addon version"
L["List every setting and its current value"] = "List every setting and its current value"
L["Print a setting's current value — `/wg get <path>`"] =
    "Print a setting's current value — `/wg get <path>`"
L["Set a setting — `/wg set <path> <value>` (try /wg list)"] =
    "Set a setting — `/wg set <path> <value>` (try /wg list)"
L["Reset one setting to its default — `/wg reset <path>`"] =
    "Reset one setting to its default — `/wg reset <path>`"
L["Reset every setting to defaults"] = "Reset every setting to defaults"
L["Open/close the debug window — `/wg debug on|off` toggles logging"] =
    "Open/close the debug window — `/wg debug on|off` toggles logging"

-- Slash / hint messages
L["No group info available. Use |cffFFFF00/wg test|r to preview."] =
    "No group info available. Use |cffFFFF00/wg test|r to preview."
L["Group info no longer available — captures clear on group-leave or |cffFFFF00/reload|r. Use |cffFFFF00/wg test|r to preview."] =
    "Group info no longer available — captures clear on group-leave or |cffFFFF00/reload|r. Use |cffFFFF00/wg test|r to preview."
L["Popup deferred until combat ends."] = "Popup deferred until combat ends."
