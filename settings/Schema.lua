-- settings/Schema.lua
-- Schema rows + Helpers (get/set/validate, AceDB defaults, restore/refresh).
--
-- Every option is one row in WhatGroup.Settings.Schema. The same row drives:
--   * the AceGUI widget rendered in the General sub-page
--   * /wg list (groups by `section`, prints path = formattedValue)
--   * /wg get <path>            (Helpers.FindSchema + Helpers.Get)
--   * /wg set <path> <value>    (type-aware parse → Helpers.Set → onChange → RefreshAll)
--   * AceDB defaults            (BuildDefaults walks Schema and threads `default`
--                                values into the nested `profile` table)
--   * /wg reset / Defaults btn  (Helpers.RestoreDefaults via WHATGROUP_RESET_ALL popup)
--
-- Adding a new option = one schema row.
--
-- The canvas-layout panel that renders these rows into AceGUI widgets lives in
-- settings/Panel.lua (loads after this file).

local addonName, NS = ...
local WhatGroup = NS.addon
local L         = NS.L

WhatGroup.Settings = WhatGroup.Settings or {}
local Settings    = WhatGroup.Settings
Settings.Schema   = {}
Settings.Helpers  = {}
Settings._refreshers = {}
-- Order array kept alongside the hash so RefreshAll iterates in schema
-- (= panel render) order, not pairs() hash order. Matters once any row
-- has a refresher that depends on another row's already-refreshed state.
Settings._refresherOrder = {}
Settings._panels = Settings._panels or {}

local Schema  = Settings.Schema
local Helpers = Settings.Helpers

-- Single chat-out routed through WhatGroup._print so the cyan [WG] prefix
-- lives in exactly one place. Falls back to raw print only if this file
-- somehow loads before WhatGroup.lua has set _print (shouldn't happen
-- given the TOC order, but the fallback keeps the panel from going dark).
local function pout(...)
    if WhatGroup._print then return WhatGroup._print(...) end
    print(...)
end

-- Deep-copy a value so table-valued schema defaults are never aliased into
-- the live profile: a shared reference would let a later profile mutation
-- corrupt the schema's canonical default. Scalars (every current row) pass
-- straight through, so this is a no-op until a table default is added.
local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, val in pairs(v) do c[k] = deepcopy(val) end
    return c
end

-- ---------------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------------
--
-- Rendered panel layout:
--
--   --- General ---
--   [Enable]        | [Auto Show]
--   [Print to Chat]
--     <afterGroup: Test button (160 px, left-aligned)>
--
--   --- Notify ---
--   [Notification Delay]
--   [Show Instance]
--   [Show Type]
--   [Show Leader]
--   [Show Playstyle]
--   [Show ClickLink]
--   [Show Teleport]

local function add(t) Schema[#Schema + 1] = t end

-- General

add{
    section = "general",  group = "General",
    path    = "enabled",  type = "bool",
    label   = "Enable",
    tooltip = "Master switch. When off, WhatGroup ignores group applications entirely — no capture, no notification, no popup. Re-enable to resume tracking on your next /lfg apply.",
    default = true,
    -- Off-flip wipes any in-flight capture so a pre-toggle apply can't
    -- still surface a notify/popup after the user has explicitly
    -- disabled the addon. WipeCapture also bumps notifyGen, cancelling
    -- any C_Timer.After callback already scheduled.
    onChange = function(v)
        -- Pass a reason so WipeCapture emits the material-effect log (debug-logging-§10):
        -- the [Set] line already shows `enabled = false`; WipeCapture logs the
        -- wipe only when there was an in-flight capture to drop, never a
        -- restatement of the value. Group-leave calls WipeCapture with no
        -- reason (silent — the [Roster] line already covers that path).
        if not v then WhatGroup:WipeCapture("addon disabled") end
    end,
}

add{
    section = "frame",  group = "General",
    path    = "frame.autoShow",  type = "bool",
    label   = "Auto Show",
    tooltip = "Open the group-info popup automatically when joining. With this off, the chat notification still prints and you can re-open the popup with /wg show or the chat link.",
    default = true,
}

add{
    section = "notify",  group = "General",
    path    = "notify.enabled",  type = "bool",
    label   = "Print to Chat",
    tooltip = "Print the group-details summary to chat after joining a group.",
    default = true,
}

-- Debug is intentionally NOT a schema row: it's session-only runtime
-- state (NS.State.debug), toggled via `/wg debug`, never persisted to
-- SavedVariables (WG-12 / debug-logging-§5). Keeping it out of the schema keeps it
-- out of BuildDefaults / `/wg list` / the saved profile. The General panel
-- does surface a "Debug console" checkbox, but as a session-only non-schema
-- affordance (settings/Panel.lua) bound straight to NS.State.debug via the
-- DebugLog seam — it never round-trips db.profile, so the WG-12 invariant
-- (debug never persists) still holds.

-- Notify — `solo = true` makes each row span the left half on its own
-- line, so the section reads as a vertical checklist of "include this
-- line when printing the notification." `notify.delay` joins the same
-- vertical column as a half-width slider above the show* checkboxes.

add{
    section = "notify",  group = "Notify",
    path    = "notify.delay",  type = "number",
    label   = "Notification Delay",
    tooltip = "Seconds to wait after joining before printing the notification and showing the popup. Lets the zone-in settle.",
    default = 0,
    min = 0, max = 10, step = 0.5, fmt = "%.1fs",
    solo    = true,
}

add{
    section = "notify",  group = "Notify",
    path    = "notify.showInstance",  type = "bool",
    label   = "Show Instance",
    tooltip = "Include the Instance line in the chat notification.",
    default = true,
    solo    = true,
}

add{
    section = "notify",  group = "Notify",
    path    = "notify.showType",  type = "bool",
    label   = "Show Type",
    tooltip = "Include the Type line (Mythic+, Raid, Dungeon, …) in the chat notification.",
    default = true,
    solo    = true,
}

add{
    section = "notify",  group = "Notify",
    path    = "notify.showLeader",  type = "bool",
    label   = "Show Leader",
    tooltip = "Include the Leader line in the chat notification.",
    default = true,
    solo    = true,
}

add{
    section = "notify",  group = "Notify",
    path    = "notify.showPlaystyle",  type = "bool",
    label   = "Show Playstyle",
    tooltip = "Include the Playstyle line (Learning / Fun (Relaxed) / Fun (Serious) / Expert) in the chat notification.",
    default = true,
    solo    = true,
}

add{
    section = "notify",  group = "Notify",
    path    = "notify.showClickLink",  type = "bool",
    label   = "Show \"Click here to view details\" link",
    tooltip = "Include the clickable chat link that re-opens the popup. Disable if you only want the chat summary.",
    default = true,
    solo    = true,
}

add{
    section = "notify",  group = "Notify",
    path    = "notify.showTeleport",  type = "bool",
    label   = "Show Teleport spell",
    tooltip = "Include a Teleport line with the dungeon's teleport spell link (and a \"not learned\" tag if you don't have it). Skipped silently when the dungeon has no known teleport.",
    default = true,
    solo    = true,
}

-- ---------------------------------------------------------------------------
-- db.profile path helpers
-- ---------------------------------------------------------------------------

local function Resolve(path)
    if not (WhatGroup.db and WhatGroup.db.profile) then return nil, nil end
    local segments = {}
    for part in string.gmatch(path, "[^.]+") do
        segments[#segments + 1] = part
    end
    if #segments == 0 then return nil, nil end
    local parent = WhatGroup.db.profile
    for i = 1, #segments - 1 do
        local k = segments[i]
        if type(parent[k]) ~= "table" then parent[k] = {} end
        parent = parent[k]
    end
    return parent, segments[#segments]
end

function Helpers.Get(path)
    local parent, key = Resolve(path)
    if not parent then
        NS.Debug("Schema", "Get: no path -> " .. tostring(path))
        return nil
    end
    return parent[key]
end

function Helpers.RawSet(path, value)
    local parent, key = Resolve(path)
    if not parent then return end
    parent[key] = value
end

-- Orchestrated single write-path: write the value, run the schema row's
-- onChange (if any), and re-sync open panel widgets. Every caller — CLI
-- (`/wg set`), panel widget callbacks, `/wg reset`, runtime toggles —
-- routes through here so the three side effects can't drift out of sync.
-- `opts.skipOnChange` suppresses the onChange call; `opts.skipRefresh`
-- suppresses RefreshAll (RestoreDefaults uses it to refresh once after
-- the loop instead of N times). Use `RawSet` only for genuinely
-- side-effect-free writes (none today).
function Helpers.Set(path, value, opts)
    Helpers.RawSet(path, value)
    -- Settings-change trace (debug-logging-§10): one canonical [Set] line at the single write
    -- seam. skipLog lets a bulk caller (RestoreDefaults) suppress the per-row
    -- lines and emit one coalesced summary instead (debug-logging-§9).
    if not (opts and opts.skipLog) then
        NS.Debug("Set", tostring(path) .. " = " .. tostring(value))
    end
    if not (opts and opts.skipOnChange) then
        local def = Helpers.FindSchema(path)
        if def and def.onChange then
            local ok, err = pcall(def.onChange, value)
            if not ok then
                pout("onChange for " .. path .. " failed: " .. tostring(err))
            end
        end
    end
    if not (opts and opts.skipRefresh) then
        Helpers.RefreshAll()
    end
end

function Helpers.FindSchema(path)
    for _, def in ipairs(Schema) do
        if def.path == path then return def end
    end
end

-- ---------------------------------------------------------------------------
-- Schema-shape validation
-- ---------------------------------------------------------------------------
--
-- Run once at panel-registration time. Catches missing `path`, unknown
-- `type`, non-string `section` / `group` / `label`. Errors are PRINTED
-- only — a broken row is an addon-author bug; the right user-visible
-- behaviour is "the option you wanted is missing AND a chat error tells
-- you why," not "the entire settings panel refuses to register."

local _validTypes = { bool = true, number = true }

function Helpers.ValidateSchema()
    local errors = 0
    for i, def in ipairs(Schema) do
        local where = "row #" .. i .. " (" .. tostring(def and def.path or "<no path>") .. ")"
        if type(def) ~= "table" then
            pout("|cffff0000schema error|r " .. where .. ": row is not a table")
            errors = errors + 1
        else
            if type(def.path) ~= "string" or def.path == "" then
                pout("|cffff0000schema error|r " .. where .. ": missing or empty `path`")
                errors = errors + 1
            end
            if not _validTypes[def.type] then
                pout("|cffff0000schema error|r " .. where
                     .. ": invalid `type` = " .. tostring(def.type)
                     .. " (expected one of: bool, number)")
                errors = errors + 1
            end
            if type(def.section) ~= "string" then
                pout("|cffff0000schema error|r " .. where .. ": missing or non-string `section`")
                errors = errors + 1
            end
            if type(def.group) ~= "string" then
                pout("|cffff0000schema error|r " .. where .. ": missing or non-string `group`")
                errors = errors + 1
            end
            if type(def.label) ~= "string" then
                pout("|cffff0000schema error|r " .. where .. ": missing or non-string `label`")
                errors = errors + 1
            end
        end
    end
    return errors
end

-- ---------------------------------------------------------------------------
-- Defaults
-- ---------------------------------------------------------------------------

-- Walk Schema and build the nested AceDB defaults table by threading each
-- row's `default` into the path it names.
function Settings.BuildDefaults()
    -- `global.schemaVersion` seeds AceDB's account-wide store so a fresh
    -- install lands at the current version; Database.lua's RunMigrations
    -- reads it (WG-08).
    local out = { profile = {}, global = { schemaVersion = NS.SCHEMA_VERSION or 1 } }
    for _, def in ipairs(Schema) do
        if def.path then
            local segs = {}
            for part in string.gmatch(def.path, "[^.]+") do
                segs[#segs + 1] = part
            end
            local parent = out.profile
            for i = 1, #segs - 1 do
                parent[segs[i]] = parent[segs[i]] or {}
                parent = parent[segs[i]]
            end
            parent[segs[#segs]] = deepcopy(def.default)
        end
    end
    return out
end

-- Reset the active profile to the schema's declared defaults, then refresh
-- open panel widgets. Both the Defaults button and `/wg reset` route through
-- this — the StaticPopup confirm step lives in the caller (WHATGROUP_RESET_ALL
-- OnAccept), so callers that want a silent reset (none today) could still
-- bypass the popup.
--
-- Two steps, so a reset yields a *pristine* profile rather than merely
-- default-valued known keys:
--   1. wipe(db.profile) drops any orphaned key a plain key-by-key overwrite
--      would leave behind — a value from a removed or renamed schema row, or
--      one hand-edited into SavedVariables. In-game this clears AceDB's raw
--      overrides while leaving its defaults metatable intact; the loop then
--      re-materialises the current defaults on top.
--   2. thread each current schema row's default back in. Table defaults are
--      deep-copied so the profile never aliases the schema's canonical default.
--
-- Per-row onChange is skipped (skipOnChange): the default baseline is already
-- the reconciled state, so firing N side effects mid-reset is wasteful and
-- asymmetric. The single RefreshAll below is the one post-reset reconcile that
-- re-syncs widgets. db.global (schemaVersion) is intentionally left untouched.
function Helpers.RestoreDefaults()
    if WhatGroup.db and WhatGroup.db.profile then
        wipe(WhatGroup.db.profile)
    end
    local n = 0
    for _, def in ipairs(Schema) do
        if def.path then
            -- skipRefresh inside the loop; one RefreshAll at the end avoids N
            -- refreshes for an N-row schema. skipLog suppresses the per-row
            -- [Set] spam — one [Reset] summary is emitted below instead (debug-logging-§9).
            Helpers.Set(def.path, deepcopy(def.default),
                        { skipRefresh = true, skipLog = true, skipOnChange = true })
            n = n + 1
        end
    end
    NS.Debug("Reset", "restored " .. n .. " settings to defaults (profile wiped)")
    Helpers.RefreshAll()
end

-- Re-sync every panel widget against the current db.profile value. Called
-- after a reset, after `/wg set`, and after profile switches (none today
-- but the hook is here if AceDBOptions is ever added).
function Helpers.RefreshAll()
    for _, path in ipairs(Settings._refresherOrder) do
        local refresher = Settings._refreshers[path]
        if refresher then
            local ok, err = pcall(refresher)
            if not ok then
                pout("refresher failed: " .. tostring(err))
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- StaticPopup — irreversible reset-all confirmation
-- ---------------------------------------------------------------------------
--
-- Single OnAccept body so the Defaults button (panel) and `/wg reset`
-- (slash) share one code path; no chance of the two diverging if a new
-- side effect lands later.
--
-- Registration is **lazy**: writing to `_G.StaticPopupDialogs` at
-- file-load was tainting Blizzard's GameMenu callbacks (every click on
-- Logout / Settings / Macros fired ADDON_ACTION_FORBIDDEN). The
-- StaticPopup table is read by Blizzard during GameMenu's button-init
-- closures, and any addon-author write to it before those closures are
-- built leaks taint into them. Deferring registration until the user
-- actually invokes a reset means the table is untouched during the
-- boot sequence.
function Settings.EnsureResetPopup()
    if Settings._resetPopupRegistered then return end
    Settings._resetPopupRegistered = true
    StaticPopupDialogs = StaticPopupDialogs or {}
    StaticPopupDialogs["WHATGROUP_RESET_ALL"] = {
        text         = L["Reset every WhatGroup setting to its default? The active profile is the only one affected."],
        button1      = YES or "Yes",
        button2      = NO  or "No",
        timeout      = 0,
        whileDead    = true,
        hideOnEscape = true,
        OnAccept     = function()
            Helpers.RestoreDefaults()
            pout(L["all settings reset to defaults"])
        end,
    }
end
