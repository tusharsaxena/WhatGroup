-- settings/Schema.lua
-- Schema rows + Helpers (get/set/validate, AceDB defaults, restore/refresh).
--
-- Every option is one row in WhatGroup.Settings.Schema -- eleven of them declared here, and the
-- six-row Master controls block composed by LibKa0s and spliced at the head of the array by
-- settings/Panel.lua (options-ui-§15). The same row drives:
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
-- Default VALUES live in defaults/Profile.lua as NS.C (savedvariables-§2); each
-- schema row references its value via `default = C.<path>` so the schema stays
-- the single source of settings STRUCTURE (architecture-§5) without also being
-- the place the value is hardcoded. Loaded before this file (see .toc).
local C         = NS.C

WhatGroup.Settings = WhatGroup.Settings or {}
local Settings    = WhatGroup.Settings
Settings.Schema   = {}
Settings.Helpers  = Settings.Helpers or {}

-- The refresher registry and the panel list used to live here. They are now
-- LibKa0s-Options-1.0's, per-ctx rather than per-addon: every widget maker
-- appends its own updater closure to the ctx it rendered into, and a re-render
-- REASSIGNS that list so a released widget's closure cannot survive it
-- (options-ui-§11).

local Schema  = Settings.Schema
-- The table settings/OptionsSetup.lua moves onto the library instance a moment
-- later. This upvalue keeps pointing at the pre-move table on purpose: the
-- members are the same function objects, and no state lives on either table.
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
-- The page is TABBED (options-ui-§13). `LibKa0s-Options-1.0`'s RenderTabbedSchema
-- partitions this array by `group`, IN DECLARATION ORDER, and draws one tab per
-- distinct group -- so the order below IS the strip, and a group's rows must stay
-- CONTIGUOUS: a row filed under a group the array has already left would print
-- that heading a second time further down.
--
-- Three tabs, in the order a player meets the addon: what governs the addon as a
-- whole, then the chat line, then the window.
--
--   --- Master controls ---    options-ui-§15's canonical block, and NOT DECLARED HERE
--   [Enable WhatGroup]    | [General visibility]
--   [Master scale]        | [Master alpha]
--   [Lock frame]          | [Debug console]
--     <afterGroup: Reset position | Reset all settings>
--
--   --- Chat ---               when the summary fires, and what it says
--   -- Timing --
--   [Notification Delay]                       solo, on its own line
--   -- Text --
--   [Print to Chat]                            master toggle, on its own line
--   [Instance]            | [Type]
--   [Leader]              | [Playstyle]
--   [Details link]        | [Teleport spell]
--     <afterGroup: Test button (160 px, left-aligned)>
--
--   --- Popup ---              the group-info window
--   -- Behavior --
--   [Open Automatically]                       master toggle, on its own line
--   -- Layout --
--   [Width]               | [Height]
--
-- THE FIRST TAB IS COMPOSED, NOT WRITTEN (options-ui-§15). `H.MasterControls` emits the canonical
-- eight-control block from one declaration, and settings/Panel.lua splices what it returns at the
-- HEAD of this array -- so the strip's first tab is the same tab, in the same order, in all nine
-- addons, and this file cannot drift from them by editing a row. Nothing about the rows it emits
-- is special once they are here: they carry `path`, `type`, `label`, `default` like every row
-- below, and `/wg list`, `/wg set`, ValidateSchema and the panel read them identically.
--
-- `section` is NOT `group`: it is `/wg list`'s grouping key and it is unchanged
-- by the retabbing. `notify.delay` is EDITED on Chat and stored (and listed)
-- under `notify`, which is exactly the page-vs-path split options-ui-§13 allows:
-- a row's tab is where it is EDITED, its path is where it is STORED.
--
-- `subgroup` breaks a tab that mixes control kinds into named blocks (options-ui-§7): a slider
-- that says WHEN standing among seven checkboxes that say WHAT is two subjects under one label,
-- and so is a behaviour toggle above two size sliders. The heading is declared by the row exactly
-- as the tab is, and it is NOT suppressed the way the group heading is.

local function add(t) Schema[#Schema + 1] = t end

-- ---------------------------------------------------------------------------
-- Master controls -- see settings/Panel.lua
-- ---------------------------------------------------------------------------
--
-- `enabled` used to be the first row of this file. It is one of options-ui-§15's canonical eight
-- now, so it is emitted by the composer and its `onChange` -- the off-flip that wipes an
-- in-flight capture -- is stamped onto the composed row beside `scale`, `alpha`, `locked` and
-- `visibility`'s in settings/Panel.lua. The stored path is still `enabled`, unchanged, because
-- the composer is handed the addon's own defaults rather than inventing any.
--
-- The debug console is a canonical row now too, and it is still SESSION-ONLY: its path is
-- `state.debugConsole`, which SESSION below intercepts before Resolve ever sees it, so the
-- WG-12 invariant (nothing about debug reaches db.profile) holds exactly as it did when the
-- checkbox was drawn by hand through `pairWith`.

-- ---------------------------------------------------------------------------
-- Chat -- when the join summary fires, and what it says
-- ---------------------------------------------------------------------------

-- EDITED ON CHAT, STORED UNDER `notify`. It headed the Notify section once, then sat on the old
-- General tab with the master switch. Neither survives options-ui-§15: General is the Master
-- controls tab now, and this row is not one of its canonical eight. It reads as the notification's
-- own delay wherever it is filed -- the same timer does gate the popup, which the tooltip says --
-- so it lands on the tab named for the notification, under its own heading, above the seven rows
-- that choose what that notification contains.
--
-- `solo` survives the move for the reason it always had: a half-width slider paired against a
-- checkbox reads as though the checkbox gated it.
add{
    section = "notify",  group = "Chat",  subgroup = "Timing",
    path    = "notify.delay",  type = "number",
    label   = "Notification Delay",
    tooltip = "Seconds to wait after joining before printing the notification and showing the popup. Lets the zone-in settle.",
    default = C.notify.delay,
    min = 0, max = 10, step = 0.5, fmt = "%.1fs",
    solo    = true,
}

-- THE VERTICAL CHECKLIST IS OVER, and only half of the argument for it expired.
-- Every row here used to carry `solo = true` so the section read as a column of
-- "include this line" ticks. The tab now says that: six of these rows are the
-- only thing on the Chat tab under their master, so the reader no longer needs a
-- column to tell them apart from the rest of the panel -- and six half-empty
-- lines is a scroll where three full ones are a glance. What survives is the
-- solo on the MASTER: "Print to Chat" governs the six, and a master paired
-- against the first thing it governs reads as its equal.
--
-- The labels lost their "Show " prefix with the same move: under a tab called
-- Chat, seven rows beginning "Show" spend their first word saying what the tab
-- already said. The PATHS are untouched -- `notify.showInstance` is still
-- `notify.showInstance` for `/wg set` and for every saved profile.

add{
    section = "notify",  group = "Chat",  subgroup = "Text",
    path    = "notify.enabled",  type = "bool",
    label   = "Print to Chat",
    tooltip = "Print the group-details summary to chat after joining a group. The rows below choose what that summary contains.",
    default = C.notify.enabled,
    solo    = true,
}

add{
    section = "notify",  group = "Chat",  subgroup = "Text",
    path    = "notify.showInstance",  type = "bool",
    label   = "Instance",
    tooltip = "Include the Instance line in the chat notification.",
    default = C.notify.showInstance,
}

add{
    section = "notify",  group = "Chat",  subgroup = "Text",
    path    = "notify.showType",  type = "bool",
    label   = "Type",
    tooltip = "Include the Type line (Mythic+, Raid, Dungeon, ...) in the chat notification.",
    default = C.notify.showType,
}

add{
    section = "notify",  group = "Chat",  subgroup = "Text",
    path    = "notify.showLeader",  type = "bool",
    label   = "Leader",
    tooltip = "Include the Leader line in the chat notification.",
    default = C.notify.showLeader,
}

add{
    section = "notify",  group = "Chat",  subgroup = "Text",
    path    = "notify.showPlaystyle",  type = "bool",
    label   = "Playstyle",
    tooltip = "Include the Playstyle line (Learning / Fun (Relaxed) / Fun (Serious) / Expert) in the chat notification.",
    default = C.notify.showPlaystyle,
}

add{
    section = "notify",  group = "Chat",  subgroup = "Text",
    path    = "notify.showClickLink",  type = "bool",
    label   = "Details link",
    tooltip = "Include the clickable \"Click here to view details\" link that re-opens the popup. Disable if you only want the chat summary.",
    default = C.notify.showClickLink,
}

add{
    section = "notify",  group = "Chat",  subgroup = "Text",
    path    = "notify.showTeleport",  type = "bool",
    label   = "Teleport spell",
    tooltip = "Include a Teleport line with the dungeon's teleport spell link (and a \"not learned\" tag if you don't have it). Skipped silently when the dungeon has no known teleport.",
    default = C.notify.showTeleport,
}

-- ---------------------------------------------------------------------------
-- Popup -- the group-info window
-- ---------------------------------------------------------------------------

add{
    section = "frame",  group = "Popup",  subgroup = "Behavior",
    path    = "frame.autoShow",  type = "bool",
    label   = "Open Automatically",
    tooltip = "Open the group-info popup automatically when joining. With this off, the chat notification still prints and you can re-open the popup with /wg show or the chat link.",
    default = C.frame.autoShow,
    solo    = true,
}

-- WIDTH AND HEIGHT ARE TWO SETTINGS AND ONE LINE. They were `FRAME_WIDTH` and
-- `FRAME_HEIGHT`, two file-locals in modules/Frame.lua, and they ship as their
-- own defaults: 420 and 260, the numbers they replaced, so a popup nobody has
-- touched is drawn exactly as it was. They sit ACROSS one line rather than down
-- a column because the question a player has is the shape of the window, which
-- is both numbers at once.
--
-- The clamp is modules/Frame.lua's, not the slider's: the slider cannot produce
-- an illegal value, but SavedVariables and `/wg set frame.width 4000` both can,
-- and a popup wider than the screen is a control that reads as broken rather
-- than as refused.

add{
    section = "frame",  group = "Popup",  subgroup = "Layout",
    path    = "frame.width",  type = "number",
    label   = "Width",
    tooltip = "Width of the group-info popup, in pixels. The default 420 is the size the popup shipped at.",
    default = C.frame.width,
    min = 320, max = 700, step = 10, fmt = "%d px",
    onChange = function() if WhatGroup.ApplyFrameSize then WhatGroup:ApplyFrameSize() end end,
}

add{
    section = "frame",  group = "Popup",  subgroup = "Layout",
    path    = "frame.height",  type = "number",
    label   = "Height",
    tooltip = "Height of the group-info popup, in pixels. The default 260 is the size the popup shipped at.",
    default = C.frame.height,
    min = 200, max = 520, step = 10, fmt = "%d px",
    onChange = function() if WhatGroup.ApplyFrameSize then WhatGroup:ApplyFrameSize() end end,
}

-- ---------------------------------------------------------------------------
-- db.profile path helpers
-- ---------------------------------------------------------------------------

-- A READ DOES NOT WRITE (savedvariables-§2). `create` is what separates the two
-- callers. A WRITE may materialize the intermediate tables it walks through — a
-- schema row nested under a table SavedVariables has never held still has to be
-- writable — but a READ must not. Without the flag, `Helpers.Get` on a typo'd or
-- not-yet-existing path grew `db.profile` one empty table per segment, and that
-- junk then round-tripped into SavedVariables; worse, the typo the caller was
-- probing for became indistinguishable from a real-but-empty branch on the next
-- read. `Helpers.Get` passes no flag and gets nil; `Helpers.RawSet` passes true.
local function Resolve(path, create)
    if not (WhatGroup.db and WhatGroup.db.profile) then return nil, nil end
    local segments = {}
    for part in string.gmatch(path, "[^.]+") do
        segments[#segments + 1] = part
    end
    if #segments == 0 then return nil, nil end
    local parent = WhatGroup.db.profile
    for i = 1, #segments - 1 do
        local k = segments[i]
        if type(parent[k]) ~= "table" then
            if not create then return nil, nil end
            parent[k] = {}
        end
        parent = parent[k]
    end
    return parent, segments[#segments]
end

-- ---------------------------------------------------------------------------
-- Session-only paths (WG-12 / debug-logging-§5)
-- ---------------------------------------------------------------------------
--
-- A row marked `sessionOnly` is a setting whose storage is its own get/set rather than the db, and
-- the debug console is the collection's canonical one (options-ui-§15). It is a SCHEMA ROW now --
-- so it renders through the ordinary checkbox maker, appears in `/wg list` and answers `/wg set`
-- like any other -- and it still must never reach db.profile: the flag it moves is a window's
-- visibility, and a console left open is not a setting the next character inherits.
--
-- Intercepted HERE, in front of Resolve, rather than branched on at each call site: Get, Set,
-- ApplyDefault, the panel's widget maker and the CLI all funnel through these two functions, and a
-- routing decision made in one of them is a routing decision the other four cannot get wrong.
--
-- The pair is NS.DebugLog's own ConsoleCheckbox() contract, unchanged from when settings/Panel.lua
-- drew the checkbox by hand: the module that owns the window is still the one that says what
-- opening it means. Resolved at CALL time, because core/DebugLogSetup.lua loads before this file
-- but NS.DebugLog is replaced wholesale on the degraded path.
local SESSION = {
    ["state.debugConsole"] = function()
        local DL = NS.DebugLog
        return DL and DL.ConsoleCheckbox and DL:ConsoleCheckbox() or nil
    end,
}

function Helpers.Get(path)
    local session = SESSION[path]
    if session then
        local spec = session()
        return spec and spec.get() or false
    end
    local parent, key = Resolve(path)
    if not parent then
        NS.Debug("Schema", "Get: no path -> " .. tostring(path))
        return nil
    end
    return parent[key]
end

function Helpers.RawSet(path, value)
    local session = SESSION[path]
    if session then
        local spec = session()
        if spec then spec.set(value and true or false) end
        return
    end
    local parent, key = Resolve(path, true)
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
-- behavior is "the option you wanted is missing AND a chat error tells
-- you why," not "the entire settings panel refuses to register."

-- `string` arrived with the Master controls block: General visibility is a DROPDOWN, because a
-- boolean can only ever answer two of options-ui-§15's four states. It is the only enum row in
-- this addon and the library's flow engine and CLI parser both already read `values` / `sorting`.
local _validTypes = { bool = true, number = true, string = true }

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
                     .. " (expected one of: bool, number, string)")
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

-- Seed from defaults/Profile.lua, then walk Schema and thread each row's `default` into the path
-- it names.
--
-- THE SEED IS NOT REDUNDANT. Every schema row's `default` is still `C.<path>`, so on a full load
-- the two halves agree key for key and the walk writes back what the seed already put there. What
-- the seed buys is the DEGRADED load: the Master controls block is composed by the library
-- (options-ui-§15), so with LibKa0s absent those six rows are not in the schema, and a
-- schema-only sweep would hand AceDB a profile with no `enabled` key at all -- which reads as
-- false and silently turns the addon off for exactly the install that is already missing a
-- library. Seeding first makes the stored shape identical on both paths.
--
-- A `sessionOnly` row is skipped outright: its storage is its own set(), and threading a default
-- for it would materialize the very db.profile branch WG-12 exists to keep empty.
function Settings.BuildDefaults()
    -- `global.schemaVersion` seeds AceDB's account-wide store so a fresh
    -- install lands at the current version; Database.lua's RunMigrations
    -- reads it (WG-08). `global.windows` holds persisted standalone-window
    -- geometry (WG-26); an empty table so NS.Windows.Save/Restore never index
    -- a nil.
    local out = { profile = deepcopy(C),
                  global = { schemaVersion = NS.SCHEMA_VERSION or 1, windows = {} } }
    for _, def in ipairs(Schema) do
        if def.path and not def.sessionOnly then
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

-- Reset the ACTIVE PROFILE to the shipped defaults. Both the Defaults button and the slash reset
-- route through this -- the StaticPopup confirm step lives in the caller (WHATGROUP_RESET_ALL
-- OnAccept), so callers that want a silent reset (none today) could still bypass the popup.
--
-- IT IS A PROFILE RESET, and the same act as AceDBOptions' own Reset Profile (options-ui-§12). It
-- is named for, and DELIBERATELY OVERRIDES, LibKa0s-Options-1.0's RestoreAllDefaults (issue #10,
-- LIBKA0S-08).
--
-- The two halves this function used to be -- wipe the profile, then thread every current row's
-- default back in -- were the right instinct and the wrong mechanism. The wipe was there so a reset
-- yields a PRISTINE profile rather than default-valued known keys, dropping any orphaned key a
-- key-by-key overwrite leaves behind: a value from a removed or renamed schema row, or one
-- hand-edited into SavedVariables. `db:ResetProfile()` does exactly that and more: AceDB empties
-- the profile IN PLACE (so anything holding db.profile keeps the live table), merges the defaults
-- back, and fires OnProfileReset -- which core/WhatGroup.lua now answers by re-running the
-- migrations and refreshing every open panel.
--
-- What the loop bought and this does not lose: the per-row [Set] spam was already suppressed and a
-- single [Reset] summary emitted instead (debug-logging-§9); that summary is still emitted here.
-- What it could not buy at all: a stored ARRAY. A row-by-row sweep can only address rows, and a
-- schema row cannot name one member of a list.
--
-- The library's per-page `RestoreDefaults(pageKey, ctx)` is untouched and still reachable; nothing
-- calls it today because this addon's Defaults button is confirmation-gated and goes through the
-- popup instead.
--
-- db.global (schemaVersion) is intentionally left untouched: a profile reset is not a downgrade.
function Helpers.RestoreAllDefaults()
    local db = WhatGroup.db
    if db and db.ResetProfile then
        db:ResetProfile()
    end
    -- The one thing a profile reset cannot reach (options-ui-§12): a `sessionOnly` row's storage is
    -- its own set(), not the db, so it would otherwise outlive a reset that took everything around
    -- it. Restored row by row, which for the debug console means the window closes -- the state a
    -- freshly-created profile is in.
    -- The same three suppressions the row sweep this function replaced used: no per-row [Set]
    -- (one coalesced [Reset] stands in, debug-logging-§9), no per-row refresh (OnProfileReset's
    -- handler does the single reconcile), and no onChange (the row's own set() is the effect).
    for _, def in ipairs(Schema) do
        if def.sessionOnly then
            Helpers.Set(def.path, deepcopy(def.default),
                        { skipRefresh = true, skipLog = true, skipOnChange = true })
        end
    end
    NS.Debug("Reset", "active profile reset to defaults")
    -- NO RefreshAll HERE. `db:ResetProfile()` fires OnProfileReset, and core/WhatGroup.lua's
    -- handler runs the migrations and refreshes -- one reconcile, on the same path a profile
    -- SWITCH takes. Calling it here as well would refresh twice for one action, which is the
    -- N-refreshes problem this function has always been careful about in miniature.
end

-- Re-sync every open panel widget against the current db.profile value. Called
-- after a reset, after `/wg set`, and after profile switches (none today but the
-- hook is here if AceDBOptions is ever added).
--
-- The body is LibKa0s-Options-1.0's RefreshScalars, installed over this stub by
-- settings/OptionsSetup.lua. What survives here is the NAME, because the write
-- seam above calls it on every Set and the seam file loads later; and the
-- degraded path, where there are no panels and a reset must still not raise.
function Helpers.RefreshAll()
    local H = Settings.Helpers
    if H and H.RefreshScalars then H.RefreshScalars() end
end

-- Restore one row to its declared default. The library's per-page Defaults
-- button and (once it is wired) the schema CLI's `reset` both come through here,
-- so a single-row reset takes the same write path a `/wg set` does — same
-- [Set] line, same onChange, same refresh.
function Helpers.ApplyDefault(row)
    if not (row and row.path) then return end
    Helpers.Set(row.path, deepcopy(row.default))
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
        -- THE COLLECTION'S ONE WORDING (options-ui-§12), verbatim. Addon-agnostic on purpose --
        -- no addon enumerates its own nouns -- and explicit about the destruction. Eight
        -- phrasings of one act is how a collection reads as eight addons.
        text         = L["Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded \226\128\148 your other profiles are not affected."],
        button1      = YES or "Yes",
        button2      = NO  or "No",
        timeout      = 0,
        whileDead    = true,
        hideOnEscape = true,
        OnAccept     = function()
            Helpers.RestoreAllDefaults()
            pout(L["all settings reset to defaults"])
        end,
    }
end
