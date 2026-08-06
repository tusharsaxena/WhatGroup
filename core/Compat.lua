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

--- Whether the player has learned the spell. Normalized to a plain
--- boolean so callers can use it directly in the teleport known/unknown
--- branch. Returns false when the API is unavailable.
function Compat.IsSpellKnown(spellID)
    if IsSpellKnown then
        return IsSpellKnown(spellID) and true or false
    end
    return false
end

-- The global cooldown is a cooldown as far as the API is concerned, and it is
-- the one every spell shares. Without a floor, casting anything at all would
-- make an eight-hour teleport report "on cooldown" for 1.5 seconds — a flicker
-- that says nothing true. No real teleport cooldown is anywhere near this
-- short, so the floor costs no accuracy.
local GCD_SECONDS = 1.5

--- Seconds left on a spell's cooldown, or 0 when it is ready, unavailable, or
--- only the GCD is running. Never negative and never nil, so the caller can
--- treat any positive number as "cannot cast yet" without a second guard.
---
--- Normalizes retail's table form and the legacy multi-return; `isEnabled`
--- false means "do not draw a cooldown" (the spell is mid-cast), which is not
--- a wait the player can be told to sit out, so it reads as ready.
function Compat.GetSpellCooldownRemaining(spellID)
    local start, duration, enabled
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if not info then return 0 end
        start, duration, enabled = info.startTime, info.duration, info.isEnabled
    elseif GetSpellCooldown then
        start, duration, enabled = GetSpellCooldown(spellID)
    else
        return 0
    end

    if enabled == false or enabled == 0 then return 0 end
    if not (start and duration) or start <= 0 or duration <= GCD_SECONDS then return 0 end

    local remaining = (start + duration) - GetTime()
    return remaining > 0 and remaining or 0
end

--- The raw (start, duration) pair the cooldown swipe needs, straight through
--- with no GCD floor — the widget draws whatever it is handed, and a swipe is
--- the one readout that can afford to be literal. Returns 0, 0 when ready.
function Compat.GetSpellCooldownTimes(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then return info.startTime or 0, info.duration or 0 end
        return 0, 0
    end
    if GetSpellCooldown then
        local start, duration = GetSpellCooldown(spellID)
        return start or 0, duration or 0
    end
    return 0, 0
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
