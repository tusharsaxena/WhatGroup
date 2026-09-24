-- settings/Schema.lua
-- Schema rows + Helpers (get/set/validate, AceDB defaults, restore/refresh), over ONE
-- LibKa0s-Schema-1.0 runtime (NS.SchemaRuntime; settings/SchemaSetup.lua resolves the library or
-- its degradation stub).
--
-- Every option is one row in WhatGroup.Settings.Schema -- the addon's own rows declared here, and
-- the composed Master controls block built by LibKa0s and spliced at the head of the array by
-- settings/Panel.lua (options-ui-§15). The same row drives:
--   * the AceGUI widget rendered in the General sub-page
--   * /wg list (groups by `section`, prints path = formattedValue)
--   * /wg get <path>            (Helpers.FindSchema + Helpers.Get)
--   * /wg set <path> <value>    (type-aware parse → the runtime's Set → onChange → RefreshAll)
--   * AceDB defaults            (BuildDefaults walks Schema and threads `default`
--                                values into the nested `profile` table)
--   * /wg reset / Defaults btn  (Helpers.RestoreDefaults via WHATGROUP_RESET_ALL popup)
--
-- Adding a new option = one schema row.
--
-- The canvas-layout panel that renders these rows into AceGUI widgets lives in
-- settings/Panel.lua (loads after this file).

local _, NS = ...
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
--   [Test mode]                                session-only, on its own line
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
-- Master controls block from one declaration, and settings/Panel.lua splices what it returns at
-- the HEAD of this array -- so the strip's first tab is the same tab, in the same order, in every
-- Ka0s addon, and this file cannot drift from them by editing a row. Nothing about the rows it emits
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
-- and so is a behavior toggle above two size sliders. The heading is declared by the row exactly
-- as the tab is, and it is NOT suppressed the way the group heading is.

local function add(t) Schema[#Schema + 1] = t end

-- ---------------------------------------------------------------------------
-- Master controls -- see settings/Panel.lua
-- ---------------------------------------------------------------------------
--
-- `enabled` used to be the first row of this file. It is one of options-ui-§15's canonical
-- Master controls now, so it is emitted by the composer and its `onChange` -- the off-flip that wipes an
-- in-flight capture -- is stamped onto the composed row beside `scale`, `alpha`, `locked` and
-- `visibility`'s in settings/Panel.lua. The stored path is still `enabled`, unchanged, because
-- the composer is handed the addon's own defaults rather than inventing any.
--
-- The debug console is a canonical row now too, and it is still SESSION-ONLY: its path is
-- `state.debugConsole`, whose row carries SESSION's get/set below and never reaches db.profile, so the
-- WG-12 invariant (nothing about debug reaches db.profile) holds exactly as it did when the
-- checkbox was drawn by hand through `pairWith`. `state.testMode`, the popup's test mode, is the
-- block's other session-only row and takes the same route.

-- ---------------------------------------------------------------------------
-- Chat -- when the join summary fires, and what it says
-- ---------------------------------------------------------------------------

-- EDITED ON CHAT, STORED UNDER `notify`. It headed the Notify section once, then sat on the old
-- General tab with the master switch. Neither survives options-ui-§15: General is the Master
-- controls tab now, and this row is not one of its canonical rows. It reads as the notification's
-- own delay wherever it is filed -- the same timer does gate the popup, which the tooltip says --
-- so it lands on the tab named for the notification, under its own heading, above the six rows
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
-- Chat, six rows beginning "Show" spend their first word saying what the tab
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
-- Session-only paths (WG-12 / debug-logging-§5)
-- ---------------------------------------------------------------------------
--
-- A row marked `sessionOnly` is a setting whose storage is its own get/set rather than the db, and
-- the debug console is the collection's canonical one (options-ui-§15). It is a SCHEMA ROW now --
-- so it renders through the ordinary checkbox maker, appears in `/wg list` and answers `/wg set`
-- like any other -- and it still must never reach db.profile: the flag it moves is a window's
-- visibility, and a console left open is not a setting the next character inherits.
--
-- STAMPED ONTO THE ROW, not branched on at each call site. The row is composed by LibKa0s
-- (settings/Panel.lua), so Settings.StampClosureRows below gives it a `get` and a `set` before it
-- is added to the schema, and the schema runtime reads and writes a row that carries both through
-- them (LibKa0s-Schema-1.0): Get, Set, ApplyDefault, the panel's widget maker and the CLI all
-- funnel through that one seam, and a routing decision made there is one the others cannot get
-- wrong.
--
-- The pair is NS.DebugLog's own ConsoleCheckbox() contract, unchanged from when settings/Panel.lua
-- drew the checkbox by hand: the module that owns the window is still the one that says what
-- opening it means. Resolved at CALL time, because core/DebugLogSetup.lua loads before this file
-- but NS.DebugLog is replaced wholesale on the degraded path.
--
-- `state.testMode` is the second: the popup's test mode (options-ui-§15), whose get/set are
-- modules/Frame.lua's, the module that owns the popup. Same call-time resolution.
local SESSION = {
    ["state.debugConsole"] = function()
        local DL = NS.DebugLog
        return DL and DL.ConsoleCheckbox and DL:ConsoleCheckbox() or nil
    end,
    ["state.testMode"] = function()
        return WhatGroup.TestModeCheckbox and WhatGroup:TestModeCheckbox() or nil
    end,
}

-- ---------------------------------------------------------------------------
-- The one GLOBAL path (launcher-§3)
-- ---------------------------------------------------------------------------
--
-- Every other stored row in this schema lives under `db.profile`, the runtime's `resolveRoot`
-- below. The minimap button's does not: the standard fixes it in the global store because a
-- profile switch must not move a player's buttons -- the ring around the minimap is furniture the
-- INSTALLATION arranged, not something a profile copy carries. So the path is taken VERBATIM from
-- the composer (`minimapPath`, settings/Panel.lua), it names the global store, and its row carries
-- its own closures exactly as the session rows do.
--
-- SURVIVING A RESET IS ITS OWN RULE and is no longer derived from the store (launcher-§3, standard
-- v2.54.0): the row is a per-installation display preference and must survive both *Reset all
-- settings* and a page-scoped Defaults button. RestoreAllDefaults below is `db:ResetProfile()`
-- plus a sweep narrowed to `sessionOnly` rows, and this row is neither a profile row nor
-- sessionOnly. The runtime's `resetExempt` names it as well, so a bracketed sweep -- the library's
-- per-page Defaults walk, should anything ever call it -- vetoes it too.
--
-- THE PATH READS IN THE ROW'S OWN SENSE; THE STORE DOES NOT MOVE (launcher-§3, standard v2.65.0).
-- The path is also the row's CLI name, so it is `global.minimap.shown`: `/wg get` answers true
-- while the button is on the minimap. What is STORED is still LibDBIcon's own `minimap.hide` --
-- there is ONE boolean, LibDBIcon writes it too from its own right-click menu, and a `shown` key
-- beside it would be a copy free to disagree (anti-pattern #81). So `shown` names the row and
-- nothing is ever written or declared at it; the two closures below invert onto `hide`, at the
-- single write seam, and everything downstream (the checkbox, `/wg get`, `/wg set`, `/wg reset`)
-- inverts with them. The old `global.minimap.hide` path is no alias: it answers "Setting not
-- found" like any path no row declares. An existing store needs no migration -- a saved
-- `hide = true` simply reads as `shown = false`.
local MINIMAP_PATH = "global.minimap.shown"

local function minimapStore()
    local db = WhatGroup.db
    return db and db.global and db.global.minimap
end

local GLOBAL = {
    [MINIMAP_PATH] = {
        get = function()
            local t = minimapStore()
            -- No table yet (pre-OnInitialize, or a db that predates the default) reads as SHOWN,
            -- which is the row's own default and what LibDBIcon does with an empty table.
            return not (t and t.hide)
        end,
        set = function(v)
            local t = minimapStore()
            if t then t.hide = not v end
            -- The button follows the checkbox NOW rather than at the next reload (launcher-§3).
            -- SetShown writes `hide` a second time with the same value, which the library
            -- documents and which is what keeps a caller that reaches it directly honest; the
            -- write above is what moves the store on an install with no LibDBIcon at all.
            if NS.Launcher then NS.Launcher:SetShown(v and true or false) end
        end,
    },
}

-- Give every composed row whose path is in SESSION or GLOBAL its own `get` and `set`, which the
-- schema runtime then reads and writes through in place of `resolveRoot`. settings/Panel.lua calls
-- this on the Master controls block before adding it to the schema. The coercion to a real boolean
-- is the one the old host seam applied to both kinds of row: a closure row never stores nil.
function Settings.StampClosureRows(rows)
    for _, row in ipairs(rows or {}) do
        local path = type(row) == "table" and row.path or nil
        local session, g = SESSION[path], GLOBAL[path]
        if session then
            row.get = function()
                local spec = session()
                return spec and spec.get() or false
            end
            row.set = function(v)
                local spec = session()
                if spec then spec.set(v and true or false) end
            end
        elseif g then
            row.get = g.get
            row.set = function(v) g.set(v and true or false) end
        end
    end
end

-- ---------------------------------------------------------------------------
-- The schema runtime (LibKa0s-Schema-1.0, WhatGroup#22)
-- ---------------------------------------------------------------------------
--
-- ONE instance over this file's rows, held by reference, and the single write seam every caller
-- takes (architecture-§5): the panel's widgets and the CLI through their descriptors
-- (settings/OptionsSetup.lua, settings/Slash.lua), the host verbs, Reset all settings. Its order is
-- the library's contract: refuse a path no row declares, validate, refuse a missing root, store (a
-- copy), the `[Set]` line (muted inside a bracket, whose one line stands for the act,
-- debug-logging-§10), the row's `onChange`, then `announce` -- the panel refresh.
--
-- Settings.SchemaLib is the library, or settings/SchemaSetup.lua's write-completing, log-silent
-- stub on an install without it. NO `writeThrough` list is passed, to either: WhatGroup takes
-- options-ui-§1's route (b) under the owner's ruling on WhatGroup#22, so on a library-absent load
-- the row-less `enabled` and `state.testMode` are refused here and settings/Slash.lua's verbs print
-- the library-absent line instead (docs/ARCHITECTURE.md, Documented deviations).
local S = Settings.SchemaLib:New{
    rows         = Schema,
    resolveRoot  = function() return WhatGroup.db and WhatGroup.db.profile, 1 end,
    announce     = function() Helpers.RefreshAll() end,
    debug        = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,
    debugEnabled = function() return NS.State.debug == true end,
    print        = pout,
    resetExempt  = { [MINIMAP_PATH] = true },
}
NS.SchemaRuntime = S

-- The host's names for the seam, bound to the instance's members as values. settings/OptionsSetup.lua
-- moves them onto the Options instance with the rest of Helpers.
Helpers.Get, Helpers.Set, Helpers.FindSchema, Helpers.ApplyDefault =
    S.Get, S.Set, S.FindRow, S.ApplyDefault

-- The bulk bracket (debug-logging-§10), under the names tests and the Options descriptor have
-- always reached it by. On Settings rather than Helpers, so the pair is not copied onto the
-- Options instance and the instance's surface does not move.
Settings.Bulk = { begin = S.BulkBegin, finish = S.BulkEnd }

-- The OnProfileReset handler's count, taken once (core/WhatGroup.lua). nil when the reset did not
-- come through RestoreAllDefaults. Also silences a bracket open around the reset: the handler's
-- line stands for the act.
Settings.ConsumeResetCount = S.ConsumeResetCount

-- ---------------------------------------------------------------------------
-- Schema-shape validation
-- ---------------------------------------------------------------------------
--
-- Run once at panel-registration time. Errors are PRINTED only — a broken row is an addon-author
-- bug; the right user-visible behavior is "the option you wanted is missing AND a chat error tells
-- you why," not "the entire settings panel refuses to register."
--
-- The runtime's Validate checks what every host's rows share: a row that is not a table, a
-- missing `path`, an unknown `type`, a missing `group`, a duplicate path. What is this addon's
-- alone stays here, in the library's line shape: `section` (`/wg list`'s grouping key, which no
-- other host reads) and `label`. The two counts are summed.

-- `string` arrived with the Master controls block: General visibility is a DROPDOWN, because a
-- boolean can only ever answer two of options-ui-§15's four states. It is the only enum row in
-- this addon and the library's flow engine and CLI parser both already read `values` / `sorting`.
local VALID_TYPES = { bool = true, number = true, string = true }

function Helpers.ValidateSchema()
    local errors = S.Validate{ types = VALID_TYPES }
    for i, def in ipairs(Schema) do
        if type(def) == "table" then
            local where = "row #" .. i .. " (" .. tostring(def.path or "<no path>") .. ")"
            if type(def.section) ~= "string" then
                pout("|cffff0000schema error|r: " .. where .. ": missing or non-string `section`")
                errors = errors + 1
            end
            if type(def.label) ~= "string" then
                pout("|cffff0000schema error|r: " .. where .. ": missing or non-string `label`")
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
-- (options-ui-§15), so with LibKa0s absent that composed block is not in the schema, and a
-- schema-only sweep would hand AceDB a profile with no `enabled` key at all -- which reads as
-- false and silently turns the addon off for exactly the install that is already missing a
-- library. Seeding first makes the stored shape identical on both paths.
--
-- A `sessionOnly` row is skipped outright: its storage is its own set(), and threading a default
-- for it would materialize the very db.profile branch WG-12 exists to keep empty.
function Settings.BuildDefaults()
    -- `global.schemaVersion` declares 0, the PRE-VERSIONING value, never NS.SCHEMA_VERSION
    -- (savedvariables-§1). AceDB's removeDefaults strips a stored value equal to its default at
    -- logout, so a default equal to the current version would never persist, and the first real
    -- bump would read the new default back as the stored version and skip its own step. With 0
    -- declared, a fresh install walks core/Database.lua's steps from 0 like any old one, and the
    -- stamp RunMigrations writes always differs from the default and survives logout.
    -- `global.windows` holds persisted standalone-window geometry (WG-26); an empty table so
    -- NS.Windows.Save/Restore never index a nil.
    -- `global.minimap` is LibDBIcon's OWN table (launcher-§3), and this declared default is what
    -- MATERIALIZES it -- architecture-§5, not a whole-section write over a schema row: the
    -- `global.minimap.shown` row's closures address the stored `hide` key and nothing else writes
    -- the branch. `hide = false` is that row's default (SHOWN) through the inversion above, and no
    -- `shown` default is declared beside it (a second copy, anti-pattern #81). LibDBIcon adds
    -- `minimapPos` to the same table when the player drags the button, which is the library's own
    -- write into its own key and needs no row.
    local out = { profile = deepcopy(C),
                  global = { schemaVersion = 0, windows = {},
                             minimap = { hide = false } } }
    for _, def in ipairs(Schema) do
        -- A GLOBAL row is not a profile row: threading its default through this walk would write
        -- `profile.global.minimap.shown` -- a branch nothing reads, in the store the standard
        -- deliberately keeps it out of. Its default is the literal above.
        if def.path and not def.sessionOnly and not GLOBAL[def.path] then
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
-- The log: ONE line, `[Set] reset profile '<name>' to defaults (N rows)`, and it is not emitted
-- here. A profile reset is wholesale replacement, not a write through the helper, so
-- debug-logging-§10 has the profile-event handler log it once; core/WhatGroup.lua's OnProfileReset
-- handler does, for this reset and for one driven straight at the db. What this function adds is
-- the count, because only it runs BEFORE the reset: N is the profile rows whose stored value differs
-- from the default just before the reset, the rows it actually changes. A row already at its
-- default is not counted, and neither is a key no row names. The handler takes it through
-- Settings.ConsumeResetCount.
--
-- What the old loop could not buy at all: a stored ARRAY. A row-by-row sweep can only address rows,
-- and a schema row cannot name one member of a list.
--
-- The library's per-page `RestoreDefaults(pageKey, ctx)` is untouched and still reachable; nothing
-- calls it today because this addon's Defaults button is confirmation-gated and goes through the
-- popup instead.
--
-- db.global (schemaVersion) is intentionally left untouched: a profile reset is not a downgrade.
--
-- The count is the runtime's ResetCounted: the stored rows off their default just before the
-- reset, pending until the handler takes it through Settings.ConsumeResetCount and cleared on both
-- exits. The predicate drops the GLOBAL row for the same reason sessionOnly rows are dropped: N is
-- the rows the PROFILE reset actually changes, and `db:ResetProfile()` cannot reach either store.
local STOPPED = " (stopped by an error)"

local function notGlobal(row) return not GLOBAL[row.path] end

function Helpers.RestoreAllDefaults()
    local db = WhatGroup.db
    if db and db.ResetProfile then
        local ok, err = pcall(S.ResetCounted, function() db:ResetProfile() end, notGlobal)
        if not ok then
            -- The act still gets its one line, once, saying it did not finish. The reset raised
            -- before AceDB fired OnProfileReset, so the handler never logged; it is logged here, with
            -- no count: nothing knows how many rows a reset that raised part-way changed. (A raise
            -- from inside a handler cannot reach here in the client, where CallbackHandler swallows
            -- handler errors.) Then the error is re-raised, unchanged, and the sessionOnly sweep
            -- below does not run.
            NS.Debug("Set", "reset profile '%s' to defaults%s", db:GetCurrentProfile(), STOPPED)
            error(err, 0)
        end
    end
    -- The one thing a profile reset cannot reach (options-ui-§12): a `sessionOnly` row's storage is
    -- its own set(), not the db, so it would otherwise outlive a reset that took everything around
    -- it. Restored row by row through the seam, which for the debug console means the window closes
    -- -- the state a freshly-created profile is in.
    --
    -- Inside one bracket marked as a profile reset, so no row logs its own [Set] line and the
    -- bracket adds none: the OnProfileReset handler's one line stands for the whole act
    -- (debug-logging-§10). Each row's write still runs the seam's announce, the panel refresh.
    S.BulkRun("reset", "profile", function(info)
        info.profileReset = true
        for _, def in ipairs(Schema) do
            if def.sessionOnly then S.ApplyDefault(def) end
        end
    end)
end

-- Re-sync every open panel widget against the current db.profile value. Called
-- after a reset, after `/wg set`, and after profile switches (none today but the
-- hook is here if AceDBOptions is ever added).
--
-- The body is LibKa0s-Options-1.0's RefreshScalars, installed over this stub by
-- settings/OptionsSetup.lua. What survives here is the NAME, because the runtime's
-- `announce` calls it on every write and the seam file loads later; and the
-- degraded path, where there are no panels and a reset must still not raise.
function Helpers.RefreshAll()
    local H = Settings.Helpers
    if H and H.RefreshScalars then H.RefreshScalars() end
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
--
-- There is deliberately no `StaticPopupDialogs = StaticPopupDialogs or {}`
-- guard below. Assigning the global is precisely the write the paragraph
-- above exists to avoid, and it guards nothing: every retail client has
-- the table built long before an addon file runs. Only the key is set.
function Settings.EnsureResetPopup()
    if Settings._resetPopupRegistered then return end
    Settings._resetPopupRegistered = true
    StaticPopupDialogs["WHATGROUP_RESET_ALL"] = {
        -- THE COLLECTION'S ONE WORDING (options-ui-§12), verbatim. Addon-agnostic on purpose --
        -- no addon enumerates its own nouns -- and explicit about the destruction. Separate
        -- phrasings of one act is how a collection reads as separate addons.
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
