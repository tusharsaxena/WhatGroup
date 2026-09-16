-- settings/Slash.lua — the addon's own verbs, and the descriptor that hands the rest to
-- LibKa0s-Slash-1.0.
--
-- What moved out of core/WhatGroup.lua: the dispatcher, the help header and rows, the landing-page
-- rows, the `key = value` and command-row formatters, the type-aware value parser and the
-- list/get/set/reset schema verbs. What stayed: the COMMANDS table itself — a host owns its verbs,
-- and the table crossing to the library as plain DATA is what keeps an options library and a slash
-- library from having to resolve each other (slash-commands-§3) — plus the five verbs whose
-- behavior is genuinely this addon's: `show`, `test`, `config`, `resetall` and `debug`.
--
-- TOC slot: last. It reads Settings.Helpers (settings/OptionsSetup.lua) and publishes
-- WhatGroup.COMMANDS, which settings/Panel.lua's landing page renders — at render time, not at
-- load, so nothing here has to precede it.

local _, NS = ...
local WhatGroup = NS.addon
local L         = NS.L

local function helpers() return WhatGroup.Settings and WhatGroup.Settings.Helpers end

local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local Sl                      -- forward-declared: the handlers below reach it at call time
local runShow, runTest, runConfig, runDebug, runReset, runResetAll, runEnabled

-- Positional triples, the shape the library reads (entry[1] / [2] / [3]); a table of named fields
-- is silently invisible to it. The handler takes `rest` alone — everything after the verb, case and
-- internal spacing preserved.
--
-- Descriptions route through NS.L at DECLARATION rather than at render, because the library renders
-- the table verbatim. The metatable fallback answers each key with itself, so this is
-- behavior-preserving today and the translator's surface tomorrow (localization-§1).
local COMMANDS = {
    {"help",     L["List available commands"],
        function() Sl:PrintHelp() end},
    {"show",     L["Show the last group info dialog"],
        function() runShow() end},
    {"test",     L["Toggle test mode (sample group info on the popup) — `/wg test on|off`; `/wg test notify` runs the join notice + popup once"],
        function(rest) runTest(rest) end},
    {"config",   L["Open the Ka0s WhatGroup Settings panel"],
        function() runConfig() end},
    -- The reserved pair (slash-commands-§2), and they are ALIASES rather than a switch: both write
    -- the `enabled` row the Master controls checkbox writes, through the same Helpers.Set. No second
    -- key, no session flag -- the box and the verbs cannot show the player two different answers.
    {"enable",   L["Enable the addon"],
        function() runEnabled(true) end},
    {"disable",  L["Disable the addon"],
        function() runEnabled(false) end},
    {"version",  L["Print the addon version"],
        function() Sl:CliVersion() end},
    {"list",     L["List every setting and its current value"],
        function() Sl:CliList() end},
    {"get",      L["Print a setting's current value — `/wg get <path>`"],
        function(rest) Sl:CliGet(rest) end},
    {"set",      L["Set a setting — `/wg set <path> <value>` (try /wg list)"],
        function(rest) Sl:CliSet(rest) end},
    {"reset",    L["Reset one setting to its default — `/wg reset <path>`"],
        function(rest) runReset(rest) end},
    {"resetall", L["Reset every setting to defaults"],
        function() runResetAll() end},
    {"debug",    L["Open/close the debug window — `/wg debug on|off` toggles logging"],
        function(rest) runDebug(rest) end},
}

-- ---------------------------------------------------------------------------
-- The disabled gate (slash-commands-§2)
-- ---------------------------------------------------------------------------
--
-- A DISABLED ADDON REFUSES A FEATURE VERB RATHER THAN ACTING ON IT. Acting is wrong twice over:
-- the player asked for something the addon is currently standing down from doing, and a silent
-- no-op leaves them with no clue why nothing happened. One tagged line naming `/wg enable`, and
-- NOTHING ELSE -- no partial work, no side effect, no second line. It is a SHOULD in the standard
-- and this addon takes it; two of its thirteen verbs drive features, which is enough for a silent
-- `/wg show` to read as a bug.
--
-- ONE PLACE, AND IT IS HERE. A guard pasted into runShow and runTest would be two places to forget
-- and a third the next verb forgets by default -- the gate belongs where every verb already passes
-- through. Wrapping entry[3] is that seam: both dispatchers, the library's and the no-LibKa0s stub
-- above, call the handler out of this table and neither has any other way in. It also survives the
-- table crossing to settings/Panel.lua's landing page, which reads entry[1] and entry[2] and never
-- the handler, so the help index and the panel list the refused verbs exactly as before.
--
-- THE LIVE SET IS NAMED ONCE, AS DATA, and it is the standard's list verbatim rather than "the ones
-- that felt safe". A player must be able to READ AND REPAIR SETTINGS and REACH THE PANEL while the
-- addon is off -- which is precisely when they are most likely to need to -- and `enable` above
-- all, or the pair is one-way again. `debug` is a diagnostic rather than a feature: the usual
-- reason to reach for it is that the addon is misbehaving. `perf` is on the list because the
-- standard reserves it collection-wide; this addon does not register it (LIBKA0S-15), so the entry
-- is what keeps the set readable as the rule rather than as this addon's subset of it.
--
-- What is left refusing is `show` and `test`: the two that draw the popup.
local ENABLED_PATH = "enabled"

local ALWAYS_LIVE = {
    help = true, config = true, version = true, enable = true, disable = true,
    debug = true, perf = true,
    get = true, set = true, list = true, reset = true, resetall = true,
}

-- FAIL OPEN. Only a stored `false` refuses: a nil -- no db yet, no Helpers yet, a path the profile
-- has never held -- is not the player having turned the addon off, and reading it as one would
-- refuse every feature verb on an install that is merely early or degraded.
local function standingDown()
    local H = helpers()
    return H ~= nil and H.Get ~= nil and H.Get(ENABLED_PATH) == false
end

for _, entry in ipairs(COMMANDS) do
    if not ALWAYS_LIVE[entry[1]] then
        local handler = entry[3]
        entry[3] = function(rest)
            if standingDown() then
                return NS.Print(L["WhatGroup is disabled — |cffFFFF00/wg enable|r turns it back on"])
            end
            return handler(rest)
        end
    end
end

-- Published so settings/Panel.lua's landing page renders the same table the help index does. It
-- crosses as plain data; neither library resolves the other.
WhatGroup.COMMANDS = COMMANDS

local lib = LibStub and LibStub("LibKa0s-Slash-1.0", true)

-- The one sentence every lost verb says.
local CLI_MISSING = NS.LIBKA0S_MISSING .. ", so the settings CLI is unavailable."

if not lib then
    -- `/wg` is registered unconditionally, so something has to answer it. The host verbs never went
    -- to the library, so they keep working; what is lost is the schema CLI and the shared
    -- rendering, and each lost verb names the missing library rather than going quiet
    -- (slash-commands-§1).
    --
    -- Nothing here re-implements a row formatter, a `key = value` shape or the parser. A degraded
    -- help row renders plainly and says so.
    local function unavailable() NS.Print(CLI_MISSING) end

    Sl = {
        OnSlash = function(_, msg)
            local raw = trim(msg)
            -- Bare `/wg` runs the `config` row, as the library does (slash-commands-§4); help
            -- only if no such row exists.
            if raw == "" then
                for _, entry in ipairs(COMMANDS) do
                    if entry[1] == "config" then return entry[3]("") end
                end
                return Sl:PrintHelp()
            end
            local name, rest = raw:match("^(%S+)%s*(.*)$")
            name = (name or ""):lower()
            for _, entry in ipairs(COMMANDS) do
                if entry[1] == name then return entry[3](rest or "") end
            end
            NS.Print("unknown command '" .. name .. "'")
            Sl:PrintHelp()
        end,
        PrintHelp = function()
            NS.Print("v" .. NS.Version() .. " slash commands")
            for _, entry in ipairs(COMMANDS) do
                NS.Print("  /wg " .. entry[1] .. " — " .. entry[2])
            end
        end,
        HelpRows = function()
            local out = {}
            for i, entry in ipairs(COMMANDS) do out[i] = "  /wg " .. entry[1] .. " — " .. entry[2] end
            return out
        end,
        LandingRows = function()
            local out = {}
            for i, entry in ipairs(COMMANDS) do out[i] = "/wg " .. entry[1] .. " — " .. entry[2] end
            return out
        end,
        HelpHeader      = function() return "v" .. NS.Version() .. " slash commands" end,
        CliList         = unavailable,
        CliGet          = unavailable,
        CliSet          = unavailable,
        CliReset        = unavailable,
        CliResetAll     = unavailable,
        CliVersion      = function() NS.Print("v" .. NS.Version()) end,
        BuildListLines  = function() return { CLI_MISSING } end,
        SetRowAnnotator = function() end,
        Text            = function(_, key) return key end,
    }
    NS.SlashCommands = Sl
else

-- `toggle` is this addon's own boolean grammar and the library has none: its parseBool accepts
-- true/false/on/off/1/0/yes/no and nothing else. Handled here rather than dropped, because
-- `/wg set notify.showLeader toggle` is a shipped verb — a `parse` adapter is the sanctioned seam
-- for exactly this (slash-commands-§6), and delegating everything else keeps the clamping, the enum
-- validation and the error strings the library's.
--
-- Returns a real boolean, never nil, so it stays distinguishable from a parse failure.
local function parseValue(row, text)
    if row and row.type == "bool" then
        local first = (text or ""):match("^(%S+)")
        if first and first:lower() == "toggle" then
            local H = helpers()
            return not (H and H.Get(row.path))
        end
    end
    local v, err = lib.ParseValue(row, text)
    -- `lib.ParseValue` is lib-level and stateless, so it answers with `lib.STRINGS.ERR_BOOL`
    -- literally — it has no instance and therefore no way to see the descriptor's `L`. Mapping the
    -- one message the descriptor overrides is the adapter for that; every other row type keeps the
    -- library's wording, which is the point of overriding one key rather than a table.
    if v == nil and err == lib.STRINGS.ERR_BOOL then
        return nil, Sl:Text("ERR_BOOL")
    end
    return v, err
end

Sl = lib:New({
    slash        = "/wg",
    slashAliases = { "/whatgroup" },
    commands     = COMMANDS,

    print   = function(line) NS.Print(line) end,
    -- The TOC first, then this addon's in-code constant, through the one seam that knows both
    -- (core/EnvSetup.lua). The library calls this at render time, so passing the function
    -- rather than a string keeps the banner reading the manifest rather than a load-time copy.
    version = NS.Version,

    -- The single write seam again — the same functions settings/OptionsSetup.lua hands the options
    -- module, so a CLI change and a checkbox click take one path (slash-commands-§5).
    get          = function(path) local H = helpers(); return H and H.Get(path) end,
    set          = function(path, value) local H = helpers(); if H then H.Set(path, value) end end,
    findRow      = function(path) local H = helpers(); return H and H.FindSchema(path) end,
    allRows      = function() return WhatGroup.Settings.Schema end,
    applyDefault = function(row) local H = helpers(); if H then H.ApplyDefault(row) end end,

    -- `list` groups by the schema's own `section`, which is what it has always grouped by; the
    -- library's default would have used `row.page`, which these rows do not carry.
    groupKey = function(row) return row.section or "?" end,

    parse = parseValue,

    -- A PLAIN table holding the one key this addon actually overrides — never NS.L, whose metatable
    -- answers every key with the key itself and would render the whole CLI as SCREAMING_SNAKE.
    -- The library's ERR_BOOL lists yes/no and not `toggle`; ours has to name the grammar the
    -- adapter above actually accepts, or the error tells the user to stop using a working word.
    L = { ERR_BOOL = "expected true/false/on/off/1/0/toggle" },

    -- Deliberately NOT passed:
    --   colorDecode / colorEncode — the schema is bool and number only.
    --   format                    — lib.FormatValue already renders both types exactly as this
    --                               addon's own formatter did, including the number row's `fmt`.
    --   aliases                   — no verb has ever had a second spelling here.
})
NS.SlashCommands = Sl

end

-- ---------------------------------------------------------------------------
-- The host's own verbs
-- ---------------------------------------------------------------------------

function runShow()
    if WhatGroup.pendingInfo then
        WhatGroup:ShowFrame()
    else
        NS.Print(L["No group info available. Use |cffFFFF00/wg test|r to preview."])
    end
end

-- `/wg test` IS the test mode (options-ui-§15): it writes the same session row the Master controls
-- checkbox writes, through the same Helpers.Set, so the box follows, a start in combat is refused
-- with the checkbox's one line, and the [Set] trace logs. Bare toggles it; `on|off` sets it.
-- `notify` keeps the one-shot join notice + popup flow, WhatGroup:RunTest, which the panel's Test
-- button also runs.
local TEST_MODE_PATH = "state.testMode"

function runTest(rest)
    local sub = (rest or ""):match("^(%S+)")
    sub = sub and sub:lower() or ""
    if sub == "notify" then return WhatGroup:RunTest() end
    local H = helpers()
    if sub == "" then
        H.Set(TEST_MODE_PATH, not H.Get(TEST_MODE_PATH))
    elseif sub == "on" or sub == "off" then
        H.Set(TEST_MODE_PATH, sub == "on")
    else
        NS.Print("Usage: /wg test          (toggle test mode)")
        NS.Print("       /wg test on|off   (turn it on or off)")
        NS.Print("       /wg test notify   (run the join notice + popup once)")
    end
end

-- ON THE ADDON, not a file-local, because `/wg config` is no longer the only caller: the launcher's
-- RIGHT click opens the panel on every addon in the collection, and its LEFT click does on rung
-- (c) (launcher-§2). core/LauncherSetup.lua reaches this rather than keeping a second copy of the
-- ladder below, so a change to how the panel opens reaches both surfaces.
function WhatGroup:OpenSettings()
    -- Settings registration normally happens at login (OnEnable), so the panel is already in the
    -- AddOns list by the time the player runs this. This call is an idempotent fallback that also
    -- covers a login in combat, where OnEnable's registration bailed on its own guard.
    if self.Settings and self.Settings.Register then
        self.Settings.Register()
    end
    local H = helpers()
    if not (H and H.OpenOptionsPanel) then
        return NS.Print("Settings panel is not available.")
    end
    -- The combat refusal and the sidebar-tree unfold both live inside OpenOptionsPanel
    -- (options-ui-§2). The gate belongs THERE rather than in this dispatcher so every caller is
    -- refused — this verb, a /run script, the launcher's right click.
    H.OpenOptionsPanel()
end

-- The verb, now one line over the body above.
function runConfig() WhatGroup:OpenSettings() end

-- ---------------------------------------------------------------------------
-- `enable` / `disable` (slash-commands-§2)
-- ---------------------------------------------------------------------------
--
-- ONE stored path, `enabled`, written through the ONE seam -- the same Helpers.Set the Master
-- controls checkbox and `/wg set enabled true` take, so the row's onChange (the off-flip capture
-- wipe, settings/Panel.lua) runs whichever surface the player used and the [Set] trace logs once.
-- These verbs hold NO state: there is no NS.enabled, no session flag and no second key to keep in
-- step, which is the whole content of the rule.
--
-- THE DISPATCHER SURVIVES THE DISABLED STATE, which is what stops the pair being one-way. Nothing
-- in this addon unregisters `/wg`, drops COMMANDS or tears down the dispatcher when `enabled` goes
-- false: the master switch is read at the capture entry points (core/WhatGroup.lua's OnApplyToGroup
-- and the inviteaccepted arm) and nowhere else, so `/wg`, `/wg enable`, `/wg help`, `/wg config` and
-- `/wg version` all answer exactly as before. tests/test_slash.lua pins it.
--
-- The ack is the CLI's own `key = value` line, built from the library's formatters rather than
-- respelled here, and it RE-READS the stored value rather than echoing the argument. The plain
-- fallback is for the install with no LibKa0s at all, where there is no formatter to call and the
-- rest of this file already renders plainly.
--
-- `ENABLED_PATH` is declared beside the disabled gate above, which is the other reader of it: the
-- gate asks the same row these two verbs write, so the switch and what it gates cannot disagree.

function runEnabled(on)
    local H = helpers()
    if not (H and H.Set) then return NS.Print(CLI_MISSING) end
    H.Set(ENABLED_PATH, on)
    local value = H.Get(ENABLED_PATH)
    local row   = H.FindSchema and H.FindSchema(ENABLED_PATH)
    if lib and row then
        return NS.Print(lib.FormatKV(row.path, lib.FormatValue(row, value)))
    end
    NS.Print(ENABLED_PATH .. " = " .. tostring(value))
end

-- ---------------------------------------------------------------------------
-- `reset` takes a PATH, not everything (slash-commands-§2, convergence #1)
-- ---------------------------------------------------------------------------
--
-- This is a BREAKING change to a verb this addon has shipped since 1.0: `/wg reset` used to be a
-- confirmation-gated wipe of every setting. It is deliberate — the collection's `reset` resets ONE
-- setting by path everywhere else, and a verb that means "one row" in six addons and "everything"
-- in the seventh is a trap the first time somebody types it in the wrong window.
--
-- The capability did not move: `/wg resetall` is the same wipe, behind the SAME confirmation popup,
-- so the destructive path kept its guard on both entry points (it and the panel's Defaults button
-- reach one OnAccept body).
--
-- It ships with a deprecation message rather than silently, because the old form still PARSES as
-- something: a bare `/wg reset` would otherwise answer "Usage: /wg reset <path>", which tells a
-- user their syntax is wrong rather than that the verb changed.
function runReset(rest)
    if trim(rest) == "" then
        NS.Print("|cffFFFF00/wg reset|r now takes a setting PATH.")
        NS.Print("  To reset one setting: |cffFFFF00/wg reset <path>|r (try |cffFFFF00/wg list|r)")
        NS.Print("  To reset everything: |cffFFFF00/wg resetall|r, or the "
                 .. "|cffFFFF00Defaults|r button on the settings page.")
        return
    end
    Sl:CliReset(rest)
end

-- Kept host-owned rather than delegated to CliResetAll, and the popup is why: the library's form
-- resets every row and prints one acknowledgment, with no confirmation step. This one is
-- irreversible, so it routes through the same StaticPopup the Defaults button uses — one OnAccept
-- body, which also resets the whole profile to drop orphaned keys (settings/Schema.lua).
function runResetAll()
    local H = helpers()
    if not (H and H.RestoreAllDefaults) then
        return NS.Print(CLI_MISSING)
    end
    if StaticPopup_Show and WhatGroup.Settings.EnsureResetPopup then
        WhatGroup.Settings.EnsureResetPopup()
        StaticPopup_Show("WHATGROUP_RESET_ALL")
    else
        H.RestoreAllDefaults()
        NS.Print(L["all settings reset to defaults"])
    end
end

-- `/wg debug`        toggles the on-screen console WINDOW (logging state untouched).
-- `/wg debug on|off` sets the session-only NS.State.debug flag through the single
--                    DebugLog:SetEnabled seam, which owns the chat ack, the header label and the
--                    console bracket line (debug-logging-§5). The flag is never persisted — off
--                    again on the next login (WG-12).
function runDebug(rest)
    local sub = (rest or ""):match("^(%S+)")
    sub = sub and sub:lower() or ""
    local DL = NS.DebugLog
    if not DL then return NS.Print("Debug console not ready yet") end

    if sub == "on" or sub == "off" then
        DL:SetEnabled(sub == "on")
    elseif sub == "" then
        DL:Toggle()
    else
        NS.Print("Usage: /wg debug        (toggle the debug window)")
        NS.Print("       /wg debug on|off (enable/disable logging)")
    end
end

-- AceConsole registers both chat commands (core/WhatGroup.lua's OnInitialize); the library
-- registers none of its own, which is what keeps every verb's output flowing through the tagged
-- printer (slash-commands-§1).
function WhatGroup:OnSlashCommand(input)
    Sl:OnSlash(input)
end
