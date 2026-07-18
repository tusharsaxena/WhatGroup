-- core/Util.lua
-- Shared low-level seams loaded before every other addon file (see .toc):
--   * NS.IsConcatSafe / NS.SafeToString — the secret-safe stringifier
--     (events-frames-taint-§8): a combat-protected "secret" value raises when
--     concatenated or formatted, so every chat/debug line runs its arguments
--     through SafeToString first, yielding "<secret>" instead of an error that
--     would freeze the notify/popup path until /reload.
--   * NS.Util.print — the single secret-safe chat printer (slash-commands-§4):
--     prepends NS.PREFIX and joins SafeToString(arg) for each argument. Every
--     user-facing line funnels through this one seam (exposed as NS.Print /
--     WhatGroup._print by core/WhatGroup.lua).
--   * NS.Windows — standalone-window geometry persistence (store the anchor
--     point into db.global.windows on drag-stop, restore it on show).
--
-- Loaded first among the addon files, so NS.PREFIX / NS.addon / NS.db are not
-- set yet at this file's load time. Nothing here reads them at load — every
-- function reads them at call time, by which point the later files have run.

local addonName, NS = ...

NS.Util = NS.Util or {}

-- ---------------------------------------------------------------------------
-- Secret-safe stringifier (events-frames-taint-§8, anti-pattern #35)
-- ---------------------------------------------------------------------------

-- Probe whether a value can be stringified without raising. The probe is
-- `table.concat` (NOT `..`): concatenating a combat-protected value raises the
-- same forbidden-access error, but table.concat lets us catch it in one pcall
-- across all value types. nil and booleans are NOT concat-safe on their own, so
-- SafeToString handles them explicitly before ever probing.
function NS.IsConcatSafe(v)
    return (pcall(table.concat, { v }))
end

-- nil -> "nil", booleans -> tostring, concat-safe (string/number) -> tostring,
-- anything else (a protected "secret", or a raw table) -> "<secret>". This is
-- the reference form from events-frames-taint-§8: the guarantee is that no value
-- routed through here can raise in a downstream `..` / string.format /
-- table.concat, "even if never handed a secret today."
function NS.SafeToString(v)
    if v == nil then return "nil" end
    if type(v) == "boolean" then return tostring(v) end
    if NS.IsConcatSafe(v) then return tostring(v) end
    return "<secret>"
end

-- ---------------------------------------------------------------------------
-- Single secret-safe chat printer (slash-commands-§4)
-- ---------------------------------------------------------------------------

-- The one user-facing chat path. Prepends NS.PREFIX (the shared [WG] tag) and
-- stringifies every argument through SafeToString, so call sites pass label and
-- value as SEPARATE args (never pre-concatenated through `..`/tostring) and a
-- protected value can never raise here. core/WhatGroup.lua aliases this to the
-- file-local `p`, NS.Print, and WhatGroup._print.
function NS.Util.print(...)
    local n = select("#", ...)
    local parts = {}
    for i = 1, n do
        parts[i] = NS.SafeToString((select(i, ...)))
    end
    print(NS.PREFIX, table.concat(parts, " "))
end

-- ---------------------------------------------------------------------------
-- Standalone-window geometry persistence (standalone-windows, WG-26)
-- ---------------------------------------------------------------------------
--
-- Windows persist only their anchor POINT (all standalone windows here are
-- fixed-size). Saved under db.global.windows[name]; guarded on the db being
-- ready so a pre-login show (in theory) is a harmless no-op rather than a nil
-- index. Frame wiring: capture on OnDragStop, restore on the show path.

NS.Windows = NS.Windows or {}

-- Read a frame's primary anchor into a plain, persistable table, or nil if the
-- frame has no point yet.
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

-- Restore a saved point onto the frame. Returns true if a saved point was
-- applied, false if none exists (caller keeps its default point).
function NS.Windows.Restore(name, frame)
    if not (frame and frame.SetPoint and frame.ClearAllPoints) then return false end
    local db = NS.addon and NS.addon.db
    local saved = db and db.global and db.global.windows and db.global.windows[name]
    if not saved then return false end
    frame:ClearAllPoints()
    frame:SetPoint(saved.point, UIParent, saved.relPoint, saved.x, saved.y)
    return true
end
