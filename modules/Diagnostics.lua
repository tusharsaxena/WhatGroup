-- modules/Diagnostics.lua — WhatGroup's sections of `/wg diagnostics` (debug-logging-§14, DX-WG).
--
-- The library writes everything around these (LibKa0s-DebugLog-1.0 14.1): both markers, its half
-- of the identity header (the [Init] summary, client build, locale, the debug flag, both combat
-- reads, the running LibKa0s minors), one pcall per section so a raise costs one line, the cap and
-- the `truncated` line. This file writes sections and nothing else; a line buffer, pcall wrapper
-- or marker set of its own would be anti-pattern #90.
--
-- READ, NEVER ACT. Nothing here takes or releases a Lifecycle hold, registers an event, arms a
-- timer, builds the popup or touches the secure teleport button: the report runs while the addon
-- is stood down and in combat, and it must leave both states exactly as it found them. The state
-- that is file-local elsewhere arrives through the two read-only accessors,
-- WhatGroup:CaptureSnapshot() (core/WhatGroup.lua) and NS.FrameSnapshot() (modules/Frame.lua), which
-- hand out copies and never build.
--
-- SECRET-SAFE. `out:add` runs every argument through NS.SafeToString and formats `%s`-only, so the
-- sections pass RAW values and never build a string with `..` or a `%d`. The one number this addon
-- would do arithmetic on, the teleport cooldown, is printed as its raw readable pair or named
-- unreadable; Compat.GetSpellCooldownRemaining is not called here, because it subtracts.
--
-- TOC slot: after modules/Frame.lua. Conventional: the DebugLog descriptor reads
-- NS.Diagnostics.Sections at RUN time (core/DebugLogSetup.lua), and every read below is at call time.

local _, NS = ...
local WhatGroup = NS.addon

NS.Diagnostics = NS.Diagnostics or {}

local TAG = "Diag"

-- The events core/WhatGroup.lua's registerFeatureEvents asks for, in its order.
local EVENTS = {
    "GROUP_ROSTER_UPDATE", "LFG_LIST_APPLICATION_STATUS_UPDATED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}

-- The rows printed whatever their value (DX-WG): the three switches a "nothing happened" report
-- turns on first.
local ALWAYS = { "enabled", "notify.enabled", "frame.autoShow" }

--- A client read, pcall'd: the value, `unavailable` when the API is missing, `unreadable` if it raised.
local function read(fn, ...)
    if type(fn) ~= "function" then return "unavailable" end
    local ok, v = pcall(fn, ...)
    if not ok then return "unreadable" end
    return v
end

local function stoodDown() return NS.IsStoodDown and NS.IsStoodDown() or false end

--- True, with the one line that says so, when the latch has released this section's runtime state.
local function released(out, name)
    if not stoodDown() then return false end
    out:add(TAG, "%s: stood down, runtime state released", name)
    return true
end

-- ---------------------------------------------------------------------------
-- The sections
-- ---------------------------------------------------------------------------

local function identity(out)
    local db = WhatGroup.db
    local LC = NS.Lifecycle
    out:add(TAG, "schema stored=%s code=%s", db and db.global and db.global.schemaVersion,
        NS.SCHEMA_VERSION)
    out:add(TAG, "profile=%s", db and db.GetCurrentProfile and db:GetCurrentProfile())
    out:add(TAG, "enabled=%s stoodDown=%s", db and db.profile and db.profile.enabled, stoodDown())
    out:joined(TAG, "holds", LC and LC.Holds and LC:Holds() or {})
    out:add(TAG, "testMode=%s", (NS.State and NS.State.testMode) and true or false)
end

local function settings(out)
    local S = NS.SchemaRuntime
    out:nonDefaults(WhatGroup.Settings and WhatGroup.Settings.Schema,
        function(row) return S.Get(row.path) end, nil, nil, { always = ALWAYS })
end

--- Is `event` registered on the addon right now? Read from AceEvent's own registry.
local function registered(event)
    local AE = LibStub and LibStub("AceEvent-3.0", true)
    local reg = AE and AE.events and AE.events.events
    if type(reg) ~= "table" then return "unknown" end
    return (reg[event] and reg[event][WhatGroup]) and "yes" or "no"
end

local function registration(out)
    local parts = {}
    for i, event in ipairs(EVENTS) do parts[i] = event .. "=" .. registered(event) end
    out:joined(TAG, "events registered:", parts)
    local linkType = NS.Compat and NS.Compat.AddOnLinkType and NS.Compat.AddOnLinkType()
    out:add(TAG, "chat link route: %s", linkType and "EventRegistry addon link"
        or "SetItemRef post-hook (degraded client)")
    out:list(TAG, "rejected events", NS.RejectedEvents or {})
end

local function group(out)
    out:add(TAG, "group: inGroup=%s inRaid=%s members=%s", read(IsInGroup), read(IsInRaid),
        read(GetNumGroupMembers))
end

--- The client's own applications, as `id=status`: what C_LFGList holds, beside what we captured.
local function clientApplications()
    local api = C_LFGList
    if not (api and type(api.GetApplications) == "function") then return nil end
    local ok, ids = pcall(api.GetApplications)
    if not ok or type(ids) ~= "table" then return nil end
    local parts = {}
    for i, id in ipairs(ids) do
        -- Multi-return (id, appStatus, pendingStatus, ...): the status is the second value.
        local okInfo, _, status = pcall(api.GetApplicationInfo, id)
        parts[i] = NS.SafeToString(id) .. "=" .. NS.SafeToString(okInfo and status or "unreadable")
    end
    return parts
end

--- A capture table as `key=title`, keys sorted so two reports diff cleanly.
local function titled(t)
    local keys = {}
    for k in pairs(t or {}) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for i, k in ipairs(keys) do
        parts[i] = NS.SafeToString(k) .. "=" .. NS.SafeToString(t[k] and t[k].title)
    end
    return parts
end

local function capture(out)
    if released(out, "capture") then return end
    local snap = WhatGroup:CaptureSnapshot()
    local client = clientApplications()
    if client then
        out:list(TAG, "client applications:", client)
    else
        out:add(TAG, "client applications: unavailable")
    end
    out:list(TAG, "capturesByResult:", titled(snap.byResult))
    out:list(TAG, "pendingApplications:", titled(snap.applications))
    out:add(TAG, "wasInGroup=%s notified=%s", snap.wasInGroup, snap.notified)
end

local function pending(out)
    local info = WhatGroup.pendingInfo
    if not info then
        out:add(TAG, "pending: none")
    else
        out:add(TAG, "pending: title=%s leader=%s voiceChat=%s", info.title, info.leaderName,
            info.voiceChat)
        out:add(TAG, "pending activity: activityID=%s mapID=%s fullName=%s", info.activityID,
            info.mapID, info.fullName)
    end
    local timer = WhatGroup.notifyTimer
    out:add(TAG, "notify timer armed=%s left=%s", timer ~= nil,
        timer and read(WhatGroup.TimeLeft, WhatGroup, timer) or "-")
    out:add(TAG, "deferred first show queued=%s", WhatGroup._frameBuildQueued and true or false)
end

--- The cooldown as its raw pair when both halves are readable numbers, else named unreadable.
local function cooldown(out, spellID)
    local ok, start, duration = pcall(NS.Compat.GetSpellCooldownTimes, spellID)
    if ok and out:readable(start) and out:readable(duration) then
        out:add(TAG, "teleport cooldown start=%s duration=%s", start, duration)
    else
        out:add(TAG, "teleport cooldown unreadable")
    end
end

local function teleport(out)
    local info = WhatGroup.pendingInfo
    if not info then return out:add(TAG, "teleport: no pending group") end
    local spells = WhatGroup.TeleportSpells or NS.TeleportSpells or {}
    local entry = (info.mapID ~= nil and spells[info.mapID] ~= nil)
        or (info.activityID ~= nil and spells[info.activityID] ~= nil)
    local spellID, known = WhatGroup:GetTeleportSpell(info.activityID, info.mapID)
    out:add(TAG, "teleport: spell=%s known=%s entry=%s", spellID, known, entry)
    if spellID then cooldown(out, spellID) end
end

local function point(p)
    if not p then return nil end
    return { p.point, p.relPoint, p.x, p.y }
end

local function popup(out)
    local snap = NS.FrameSnapshot()
    if not snap.built then
        out:add(TAG, "popup: not built")
    else
        out:add(TAG, "popup: built=%s shown=%s onScreen=%s softHidden=%s pendingHide=%s", snap.built,
            snap.shown, snap.onScreen, snap.softHidden, snap.pendingHide)
        out:add(TAG, "popup: gateWithheld=%s testMode=%s teleportDeferred=%s cooldownTicking=%s "
            .. "escProxyShown=%s", snap.gateWithheld, snap.testMode, snap.teleportDeferred,
            snap.cooldownTicking, snap.escProxyShown)
        out:joined(TAG, "popup combat-end queue", snap.combatQueue)
    end
    local db = WhatGroup.db
    local saved = db and db.global and db.global.windows and db.global.windows.popup
    out:joined(TAG, "popup saved point", point(saved) or {})
    out:joined(TAG, "popup live point", point(snap.point) or {})
end

local function launcher(out)
    local L = NS.Launcher
    out:add(TAG, "launcher: registered=%s shown=%s", L and read(L.IsRegistered, L),
        L and read(L.IsShown, L))
end

--- The report's sections, in order. Called by the DebugLog descriptor at run time.
function NS.Diagnostics.Sections()
    return {
        { "identity",     identity },
        { "settings",     settings },
        { "registration", registration },
        { "group",        group },
        { "capture",      capture },
        { "pending",      pending },
        { "teleport",     teleport },
        { "popup",        popup },
        { "launcher",     launcher },
    }
end
