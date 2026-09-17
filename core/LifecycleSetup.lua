-- core/LifecycleSetup.lua — the stand-down latch (slash-commands-§7).
--
-- ONE LibKa0s-Lifecycle-1.0 instance, and it is the only thing in this addon that decides whether
-- the addon is RUNNING. Two named holds sit on it:
--
--   "disabled"  taken from the stored `enabled` path -- the Master controls checkbox, `/wg enable`
--               and `/wg disable`, `/wg set enabled false`, and a profile switch that carries a
--               different answer. Persisted, because surviving a `/reload` is the whole point of
--               that setting.
--   "perf"      taken by LibKa0s-Perf-1.0 for a capture's suspended arm. This addon DECLINES Perf
--               on structural grounds (LIBKA0S-15), so nothing takes it today -- but the key is
--               the library's and the latch is the same latch, so the day the exemption is
--               re-examined the wiring is already here and there is no second teardown path to
--               reconcile.
--
-- WHY A LATCH AND NOT A BOOLEAN. Two independent reasons to be down means four states, and the
-- interesting one is the state a boolean cannot hold: perf-suspended AND player-disabled, the run
-- finishes, `resume` releases its hold, and a bare stand-up brings the addon back to life under a
-- player who switched it off. Releasing one hold must not resurrect an addon the other is still
-- holding down, and that sentence is the whole reason this file exists rather than an
-- `if enabled then` in two capture entry points -- which is what this addon shipped until today.
--
-- WHAT DISABLED USED TO MEAN HERE, AND WHY THAT WAS WRONG. Two reads of `db.profile.enabled`, at
-- OnApplyToGroup and at the `inviteaccepted` arm, and nothing else. The four events stayed
-- registered, so the client went on walking this addon's registration list on every
-- GROUP_ROSTER_UPDATE and building the argument frame and entering Lua to run a comparison that
-- decided to leave. That cost is precisely what a player switching the addon off is trying to stop
-- paying, and it is invisible from every surface they can see. The registrations are now GONE while
-- the addon is off; tests/test_disabled.lua asserts on the registration set rather than on a
-- handler's return value, which is the only assertion that can tell the two apart.
--
-- TOC SLOT: last in # Core, after core/LauncherSetup.lua. Conventional -- the two callbacks below
-- resolve `NS.addon` members at CALL time, and the first call is from OnEnable, long after every
-- file has loaded.

local addonName, NS = ...

local lib = LibStub and LibStub("LibKa0s-Lifecycle-1.0", true)

-- The one seam the rest of the addon asks. Everything that used to read `db.profile.enabled` to
-- decide whether to act reads THIS instead, so "is the addon off" has one answer and the
-- hooksecurefunc bodies that cannot be un-hooked agree with the show ladder that can.
--
-- FAIL OPEN. No latch, or a latch not yet asked, means the addon is running: a nil is an install
-- that is merely early or degraded, not a player who turned something off.
function NS.IsStoodDown()
    return NS.Lifecycle ~= nil and NS.Lifecycle:IsDown() == true
end

if not lib then
    -- The degradation stub every other setup file in core/ carries, and this one has to be
    -- FUNCTIONAL rather than inert: without LibKa0s there is still a Master controls checkbox and
    -- still an `/wg disable` verb, and an addon that answered "never down" to both would ignore the
    -- switch entirely. So the stub is the hold set, minus the diagnostics.
    local held = {}
    local down = false

    local function reevaluate()
        local anyHeld = next(held) ~= nil
        if anyHeld == down then return false end
        down = anyHeld
        if down then NS.StandDown() else NS.StandUp() end
        return true
    end

    NS.Lifecycle = {
        name    = addonName,
        Hold    = function(_, key) held[key] = true;  return reevaluate() end,
        Release = function(_, key) held[key] = nil;   return reevaluate() end,
        Set     = function(self, key, on) if on then return self:Hold(key) end return self:Release(key) end,
        IsHeld  = function(_, key) return held[key] == true end,
        IsDown  = function() return down end,
        Holds   = function()
            local out = {}
            for k in pairs(held) do out[#out + 1] = k end
            table.sort(out)
            return out
        end,
        Reevaluate = function() return reevaluate() end,
        PrintHolds = function() return false end,
    }
    NS.HOLD_DISABLED = "disabled"
    NS.HOLD_PERF     = "perf"
    return
end

NS.HOLD_DISABLED = lib.HOLD_DISABLED
NS.HOLD_PERF     = lib.HOLD_PERF

-- The two host callbacks. They are thin on purpose: WHAT comes down lives with the code that put
-- it up (core/WhatGroup.lua owns the events and the capture state, modules/Frame.lua owns the
-- popup and the cooldown ticker), and this file owns only the decision about WHEN.
NS.Lifecycle = lib:New({
    name      = addonName,
    standDown = function() NS.StandDown() end,
    standUp   = function() NS.StandUp() end,
    print     = function(line) NS.Print(line) end,
})
