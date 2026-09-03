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

local addonName, NS = ...
local WhatGroup = NS.addon
local L         = NS.L

local function helpers() return WhatGroup.Settings and WhatGroup.Settings.Helpers end

local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local Sl                      -- forward-declared: the handlers below reach it at call time
local runShow, runTest, runConfig, runDebug, runReset, runResetAll

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
    {"test",     L["Inject synthetic group info and run the full notify + frame flow"],
        function() runTest() end},
    {"config",   L["Open the Ka0s WhatGroup Settings panel"],
        function() runConfig() end},
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
            if raw == "" then return Sl:PrintHelp() end
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

function runTest() WhatGroup:RunTest() end

function runConfig()
    -- Settings registration normally happens at login (OnEnable), so the panel is already in the
    -- AddOns list by the time the player runs this. This call is an idempotent fallback that also
    -- covers a login in combat, where OnEnable's registration bailed on its own guard.
    if WhatGroup.Settings and WhatGroup.Settings.Register then
        WhatGroup.Settings.Register()
    end
    local H = helpers()
    if not (H and H.OpenOptionsPanel) then
        return NS.Print("Settings panel is not available.")
    end
    -- The combat refusal and the sidebar-tree unfold both live inside OpenOptionsPanel
    -- (options-ui-§2). The gate belongs THERE rather than in this dispatcher so every caller is
    -- refused — this verb, a /run script, a future internal caller.
    H.OpenOptionsPanel()
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
-- resets every row and prints one acknowledgement, with no confirmation step. This one is
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
