-- core/Util.lua
-- Standalone-window geometry persistence (WG-26) — the one low-level seam in this addon that has
-- no LibKa0s equivalent.
--
-- Everything else that used to live here is now the library's and is wired up in
-- core/CoreSetup.lua, which loads immediately before this file:
--   * NS.IsConcatSafe / NS.SafeToString — LibKa0s-Core-1.0's secret-safe stringifier
--     (events-frames-taint-§8, anti-patterns #35)
--   * NS.Util.print                     — its prefixed, secret-safe chat printer
--     (slash-commands-§4)
--   * NS.SKIN / NS.ApplySkin            — its shared window chrome (standalone-windows)
--
-- Nothing here reads NS.PREFIX / NS.addon / NS.db at load — every function reads them at call
-- time, by which point the later files have run.

local addonName, NS = ...

-- ---------------------------------------------------------------------------
-- Standalone-window geometry persistence (standalone-windows, WG-26)
-- ---------------------------------------------------------------------------
--
-- Windows persist only their anchor POINT (all standalone windows here are fixed-size). Saved
-- under db.global.windows[name]; guarded on the db being ready so a pre-login show (in theory) is a
-- harmless no-op rather than a nil index. Frame wiring: capture on OnDragStop, restore on the show
-- path.

-- ---------------------------------------------------------------------------
-- Duration rendering
-- ---------------------------------------------------------------------------

--- Seconds → "7h 58m 12s". Units above the largest non-zero one are dropped
--- (a 90-second wait reads "1m 30s", not "0h 1m 30s"); units below it are kept,
--- so the string holds a stable shape while it is on screen.
---
--- Rounds UP, because the caller is telling a player how long they must wait:
--- rounding down would let a spell that still refuses to cast read "0s".
--- Deliberately NOT localized — h/m/s are the units Blizzard's own cooldown
--- text uses in every locale this addon ships (localization-§1 covers prose,
--- and these are symbols).
function NS.FormatDuration(seconds)
    seconds = math.ceil(tonumber(seconds) or 0)
    if seconds <= 0 then return "0s" end

    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60

    if h > 0 then return string.format("%dh %dm %ds", h, m, s) end
    if m > 0 then return string.format("%dm %ds", m, s) end
    return string.format("%ds", s)
end

NS.Windows = NS.Windows or {}

-- Read a frame's primary anchor into a plain, persistable table, or nil if the frame has no point
-- yet.
function NS.Windows.PointOf(frame)
    if not (frame and frame.GetPoint) then return nil end
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if type(point) ~= "string" then return nil end
    return { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end

-- Persist the frame's current point under db.global.windows[name].
function NS.Windows.Save(name, frame)
    local db = NS.addon and NS.addon.db
    if not (db and db.global) then return end
    local pt = NS.Windows.PointOf(frame)
    if not pt then return end
    db.global.windows = db.global.windows or {}
    db.global.windows[name] = pt
end

-- Restore a saved point onto the frame. Returns true if a saved point was applied, false if none
-- exists (caller keeps its default point).
function NS.Windows.Restore(name, frame)
    if not (frame and frame.SetPoint and frame.ClearAllPoints) then return false end
    local db = NS.addon and NS.addon.db
    local saved = db and db.global and db.global.windows and db.global.windows[name]
    if not saved then return false end
    frame:ClearAllPoints()
    frame:SetPoint(saved.point, UIParent, saved.relPoint, saved.x, saved.y)
    return true
end
