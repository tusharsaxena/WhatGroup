-- core/Compat.lua
-- Thin compatibility shims for the version-variant spell / LFG APIs the
-- addon consumes. Loaded first among the addon files (see WhatGroup.toc)
-- so every later file can reach NS.Compat.* without doing its own
-- C_Spell-vs-legacy detection inline.
--
-- NS.Compat stays the ONE surface the rest of the addon calls, and this file
-- the one place that decides who answers. Since LibKa0s v1.55.0 the spell
-- readers two or more Ka0s addons wrote alike come from LibKa0s-Compat-1.0
-- (GetSpellName and GetSpellTexture as the library's own members, the two
-- cooldown shims built on its GetSpellCooldown); what stays here is what is
-- this addon's alone: the spell link, the spell-known ladder (its namespaced
-- answer is final, which another addon's ladder disagrees with), the GCD floor,
-- the activity table and the chat-link detection. So this file and the library
-- are between them the SOLE callers of the variant APIs (C_Spell.*, the global
-- GetSpell* fallbacks, C_SpellBook.IsSpellKnown and the IsSpellKnown global,
-- C_LFGList.GetActivityInfoTable, LinkTypes.AddOn plus EventRegistry).
-- When a patch renames or moves one of these, one of the two changes. Every
-- shim degrades to a safe default (nil / false / 0) rather than throwing when
-- the underlying API, or the library, is absent.

local _, NS = ...

local Compat = {}
NS.Compat = Compat

-- ---------------------------------------------------------------------------
-- Spell APIs (C_Spell.* on modern clients, legacy globals as fallback)
-- ---------------------------------------------------------------------------

-- LibKa0s-Compat-1.0 when the payload loaded, nil when it did not. Looked up once, here: the
-- library reads the client's globals at CALL time, so a suite that removes a rung after load still
-- watches the ladder move (tests/test_compat.lua).
local CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)

-- THE READER ARM (LibKa0s docs/api/Compat/version-1-docs.md, "Readers: the stub answers the absent
-- value"). Without the library each reader answers the value the library documents for a client
-- with no rung at all, and copies none of its ladder: a stub that re-implemented the top rung would
-- re-create the duplication the major exists to remove. A degraded install therefore draws the
-- teleport button with the question-mark icon and no spell name, and never raises. That install is
-- already announced once by core/CoreSetup.lua, so no second line is printed here.
local function absentSpellCooldown() return 0, 0, false, 1, false end

--- Localized spell name for a spellID (used for the secure /cast macrotext
--- and the popup teleport tooltip label). Returns nil when unknown.
---
--- The library's member: C_Spell.GetSpellName, then C_Spell.GetSpellInfo's name, then the legacy
--- global, the first rung that ANSWERS winning (a nil or a plain "" falls through). A non-number,
--- non-string id answers nil without calling the client.
Compat.GetSpellName = CompatLib and CompatLib.GetSpellName or function() return nil end

--- File ID of the spell's icon texture, or nil when unavailable. Callers
--- supply their own default (the popup uses 134400, the question-mark
--- icon) so a nil return stays visible rather than blank.
---
--- The library's member: exactly one value (the client's second return, the original icon, is
--- dropped), so it can be spread into SetTexture.
Compat.GetSpellTexture = CompatLib and CompatLib.GetSpellTexture or function() return nil end

-- `startTime, duration, isEnabled, modRate, isActive` -- always five values. Kept file-local
-- rather than published: the two cooldown shims below are this addon's call surface, and each
-- keeps its own contract on top of it.
local spellCooldown = CompatLib and CompatLib.GetSpellCooldown or absentSpellCooldown

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
---
--- Only the spellID is passed: C_SpellBook.IsSpellKnown's spellBank argument
--- defaults to Player, the bank teleports live in. Its answer is final. A
--- false does not fall through to the global, which would turn the ladder
--- into "either says yes" and hide a disagreement between the two.
function Compat.IsSpellKnown(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellID) and true or false
    end
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
--- The reading of the client is LibKa0s-Compat-1.0's GetSpellCooldown, which normalizes retail's
--- table form and the legacy multi-return (a legacy `isEnabled` of 0 reads disabled, nil reads
--- enabled) and answers `0, 0, false` for a nil table or no API. The POLICY is this addon's and
--- stays here: `isEnabled` false means "do not draw a cooldown" (the spell is mid-cast), which is
--- not a wait the player can be told to sit out, so it reads as ready; and the GCD floor above.
function Compat.GetSpellCooldownRemaining(spellID)
    local start, duration, enabled = spellCooldown(spellID)
    if not enabled then return 0 end
    if start <= 0 or duration <= GCD_SECONDS then return 0 end

    local remaining = (start + duration) - GetTime()
    return remaining > 0 and remaining or 0
end

--- The raw (start, duration) pair the cooldown swipe needs, straight through
--- with no GCD floor — the widget draws whatever it is handed, and a swipe is
--- the one readout that can afford to be literal. Returns 0, 0 when ready.
---
--- Truncated to TWO values on purpose: the caller spreads this into Cooldown:SetCooldown, whose
--- third parameter is modRate, and the library's third return is the enabled flag.
function Compat.GetSpellCooldownTimes(spellID)
    local start, duration = spellCooldown(spellID)
    return start, duration
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

-- ---------------------------------------------------------------------------
-- Chat links
-- ---------------------------------------------------------------------------

--- Blizzard's link type for addon chat links ("addon"), or nil when this client
--- cannot deliver a click on one. A `|Haddon:…|h` link is handled by a handler
--- Blizzard registers (Blizzard_UIPanels_Game/Shared/ItemRefHandlersShared.lua:278-281
--- at 12.1.0), which re-raises the click as EventRegistry's "SetItemRef" event
--- and counts as Handled, so SetItemRef returns before its ItemRef-tooltip
--- fallthrough. Both halves are required: the link type with no EventRegistry
--- to subscribe to is a link nothing can hear. nil sends the caller back to an
--- unregistered link type and a SetItemRef post-hook.
function Compat.AddOnLinkType()
    if LinkTypes and LinkTypes.AddOn
       and EventRegistry and EventRegistry.RegisterCallback then
        return LinkTypes.AddOn
    end
    return nil
end
