-- core/Compat.lua
-- Thin compatibility shims for the version-variant spell / LFG APIs the
-- addon consumes. Loaded first among the addon files (see WhatGroup.toc)
-- so every later file can reach NS.Compat.* without doing its own
-- C_Spell-vs-legacy detection inline.
--
-- Compat is the SOLE caller of the variant APIs (C_Spell.*, the global
-- GetSpell* fallbacks, IsSpellKnown, C_LFGList.GetActivityInfoTable).
-- When a patch renames or moves one of these, this file is the only
-- place that changes. Every shim degrades to a safe default (nil / false)
-- rather than throwing when the underlying API is absent.

local addonName, NS = ...

local Compat = {}
NS.Compat = Compat

-- ---------------------------------------------------------------------------
-- Spell APIs (C_Spell.* on modern clients, legacy globals as fallback)
-- ---------------------------------------------------------------------------

--- Localized spell name for a spellID (used for the secure /cast macrotext
--- and the popup teleport tooltip label). Returns nil when unknown.
function Compat.GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        -- Fall through to the legacy path when the modern API is present
        -- but returns nil, matching the old inline `A(x) or B(x)` chain.
        local name = C_Spell.GetSpellName(spellID)
        if name then return name end
    end
    if GetSpellInfo then
        return (GetSpellInfo(spellID))
    end
    return nil
end

--- Basic spell info collapsed to the fields the addon needs. Currently
--- only `name` is consumed anywhere; kept as a full shim for parity with
--- the standard Compat surface and for future callers. Returns nil when
--- the spell is unknown.
-- @return name, iconID, castTime, minRange, maxRange, returnedSpellID
function Compat.GetSpellInfo(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local i = C_Spell.GetSpellInfo(spellID)
        if not i then return nil end
        return i.name, i.iconID, i.castTime, i.minRange, i.maxRange, i.spellID
    end
    if GetSpellInfo then
        return GetSpellInfo(spellID)
    end
    return nil
end

--- File ID of the spell's icon texture, or nil when unavailable. Callers
--- supply their own default (the popup uses 134400, the question-mark
--- icon) so a nil return stays visible rather than blank.
function Compat.GetSpellTexture(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID)
    end
    if GetSpellTexture then
        return GetSpellTexture(spellID)
    end
    return nil
end

--- Clickable spell hyperlink for the chat teleport line, or nil when the
--- API is missing (the caller then renders a plain "[Spell <id>]" tag).
function Compat.GetSpellLink(spellID)
    if C_Spell and C_Spell.GetSpellLink then
        return C_Spell.GetSpellLink(spellID)
    end
    return nil
end

--- Whether the player has learned the spell. Normalised to a plain
--- boolean so callers can use it directly in the teleport known/unknown
--- branch. Returns false when the API is unavailable.
function Compat.IsSpellKnown(spellID)
    if IsSpellKnown then
        return IsSpellKnown(spellID) and true or false
    end
    return false
end

-- ---------------------------------------------------------------------------
-- LFG APIs
-- ---------------------------------------------------------------------------

--- Activity info table for an activityID (fullName / mapID / maxNumPlayers /
--- category flags used by CaptureGroupInfo). Returns nil when the activity
--- is unknown or the API is missing.
function Compat.GetActivityInfoTable(activityID)
    if C_LFGList and C_LFGList.GetActivityInfoTable then
        return C_LFGList.GetActivityInfoTable(activityID)
    end
    return nil
end
