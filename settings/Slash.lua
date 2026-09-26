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

-- The `enabled` row's path, in one place. `/wg enable`, `/wg disable` and the Master controls
-- checkbox all write it, through the same Helpers.Set, and core/LifecycleSetup.lua's `disabled`
-- hold is taken from it — so the switch and what it gates cannot disagree.
local ENABLED_PATH = "enabled"

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
    -- The diagnostics dump (debug-logging-§14): one of exactly two forms, the other being
    -- `/wg debug diagnostics`. Reserved and on the library's live list (Slash 16), so it answers
    -- while the addon is disabled. The report itself is the library's; the sections are
    -- modules/Diagnostics.lua's. Looked up at call time, like every NS member here.
    {"diagnostics", L["Write the diagnostics report to the debug console"],
        function() NS.DebugLog:RunDiagnostics() end},
}

-- ---------------------------------------------------------------------------
-- The disabled gate (slash-commands-§2, slash-commands-§7) — THE LIBRARY'S, NOT THIS FILE'S
-- ---------------------------------------------------------------------------
--
-- A DISABLED ADDON REFUSES A FEATURE VERB RATHER THAN ACTING ON IT, on one tagged line naming
-- `/wg enable` and nothing else. Two of this addon's fourteen verbs drive features — `show` and
-- `test`, the two that put the popup on screen — which is enough for a silent `/wg show` to read
-- as a bug, so this addon takes slash-commands-§2's SHOULD.
--
-- EVERYTHING ELSE ANSWERS NORMALLY, and that is a ruling rather than a default. The standard
-- narrowed the disabled surface to `enable` and `help` at v2.56.0 and REVERSED it at v2.57.0: the
-- first thing anyone tried was `/wg` on a disabled addon, which answered with a refusal instead of
-- opening the settings panel — the one surface a player uses to switch it back on by hand. A rule
-- that hides the off switch has mistaken which half of the pair it protects. So while this addon
-- is off, `/wg` opens the panel, `config` and `version` and the whole schema CLI —
-- `get` / `set` / `list` / `reset` / `resetall` — read and repair settings, `debug` runs as the
-- diagnostic it is, and `enable` above all still works.
--
-- THIS FILE OWNS NONE OF THAT ANY MORE. It carried its own ALWAYS_LIVE table and its own refusal
-- wording until today, wrapping every feature verb's handler as it built COMMANDS. Both are the
-- library's from Slash minor 13: `lib.LIVE_VERBS` is the standard's thirteen reserved verbs and the
-- gate sits after the COMMANDS lookup, which is what keeps a TYPO answering `unknown command`
-- rather than "the addon is disabled" — a true sentence and the wrong answer, since it tells a
-- player who mistyped that their spelling was fine. The wording lives in
-- `lib.DISABLED_LINE_FORMAT` and is built by `Sl:DisabledLine()`, and it MUST NOT be re-spelled
-- host-side: one sentence is exactly the kind of thing eleven addons each end up writing their own
-- of, and a player who runs four of them then reads four answers to the same question.
--
-- WHAT THE HOST STILL OWNS is two descriptor fields, below: `isEnabled`, asked at DISPATCH time so
-- the command after an `enable` works, and `brandName`, the plain-text `Ka0s WhatGroup` that
-- core/LauncherSetup.lua already gives the LDB object as `label` — launcher-§1 forbids escape
-- sequences there, which is what makes it safe to drop into a colored line.
--
-- `liveVerbs` is deliberately NOT passed. The library's default IS the standard's list; passing a
-- copy would be this addon's own opinion about which verbs a player may use on a disabled addon,
-- which is the opinion v2.57.0 settled.

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

    -- A BYTE COPY of libs/LibKa0s/Slash.lua's `lib.DISABLED_LINE_FORMAT` (:84), and the only place
    -- this addon may spell the refusal line (slash-commands-§7). It is a copy because this is the
    -- branch where the library is absent and there is nothing to ask; it is pinned to the live
    -- library's bytes by tests/test_libka0s.lua through Kit.assertLibraryConstant, so a library-side
    -- rewording reddens here instead of leaving two sentences in the collection.
    local DISABLED_LINE_FORMAT = "%s is disabled \226\128\148 enable it with |cFFFFFF00%s|r"

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
        -- A member of the library instance, so the degraded shape answers it too (the surface
        -- parity tests/test_surface_parity.lua pins). Same sentence, built from the same format
        -- and the same two pieces the library builds it from — there is no lib here to ask.
        DisabledLine    = function()
            return DISABLED_LINE_FORMAT:format("Ka0s WhatGroup", "/wg enable")
        end,
        -- Published for the byte pin above. A `__` key sits outside Kit.publicMembers, so the
        -- surface-parity case against the library instance is unaffected.
        __disabledLineFormat = DISABLED_LINE_FORMAT,
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

    -- THE GATE (slash-commands-§7). A function, asked at dispatch time and never cached, because
    -- the value changes between two commands and a cached answer would refuse the one that follows
    -- the `enable` that just worked. It asks the LATCH rather than `db.profile.enabled`, so the
    -- perf hold and the disabled hold give the CLI one answer between them.
    isEnabled = function() return not NS.IsStoodDown() end,
    -- Required alongside `isEnabled`, and it is the same string core/LauncherSetup.lua gives the
    -- LDB object as `label`. One brand spelling per addon, not a second one invented for a message.
    brandName = "Ka0s WhatGroup",

    print   = function(line) NS.Print(line) end,
    -- The TOC first, then this addon's in-code constant, through the one seam that knows both
    -- (core/EnvSetup.lua). The library calls this at render time, so passing the function
    -- rather than a string keeps the banner reading the manifest rather than a load-time copy.
    version = NS.Version,

    -- The single write seam again — the schema runtime's members, the same ones
    -- settings/OptionsSetup.lua hands the options module, so a CLI change and a checkbox click take
    -- one path (slash-commands-§5). Bound as VALUES: `set = S.Set` answers `false, err` on a
    -- refusal, and CliSet prints the seam's own refusal rather than a success line.
    get          = NS.SchemaRuntime.Get,
    set          = NS.SchemaRuntime.Set,
    findRow      = NS.SchemaRuntime.FindRow,
    allRows      = function() return WhatGroup.Settings.Schema end,
    applyDefault = NS.SchemaRuntime.ApplyDefault,

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
-- by startTestMode's one gray line (the guard that serves this verb; the checkbox itself is
-- refused first by LibKa0s's combat lock, options-ui-§2), and the [Set] trace logs. Bare toggles it; `on|off` sets it.
-- `notify` keeps the one-shot join notice + popup flow, WhatGroup:RunTest, which the panel's Test
-- button also runs.
local TEST_MODE_PATH = "state.testMode"

-- THE LIBRARY-ABSENT LINE (options-ui-§1 route (b); the owner's ruling on WhatGroup#22). The rows
-- `enable`, `disable` and `test` write are composed by LibKa0s (options-ui-§15), so a load without
-- it has no row for them, and the schema seam refuses a path no row declares. WhatGroup passes the
-- seam no `writeThrough` list, so these verbs say they are unavailable instead: no Lua error, no
-- write, no ack. The SHOULD deviation is recorded in docs/ARCHITECTURE.md.
local function libraryAbsent(verb)
    NS.Print(L["%s is unavailable: the LibKa0s library did not load."]:format(verb))
end

function runTest(rest)
    local sub = (rest or ""):match("^(%S+)")
    sub = sub and sub:lower() or ""
    if sub == "notify" then return WhatGroup:RunTest() end
    local H = helpers()
    if (sub == "" or sub == "on" or sub == "off") and not H.FindSchema(TEST_MODE_PATH) then
        return libraryAbsent("/wg test")
    end
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
-- LEFT click opens the panel on every addon in the collection (launcher-§2, standard v2.67.0), and
-- its right click does where the client has no context-menu API. core/LauncherSetup.lua reaches
-- this rather than keeping a second copy of the ladder below, so a change to how the panel opens
-- reaches both surfaces.
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
    -- refused — this verb, a /run script, the launcher's left click.
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
-- false — the chat command, the dispatcher and this table are SETUP, not features, and they come up
-- on load in either state. What the stored `false` now does is take the latch's `disabled` hold,
-- which unregisters every event, cancels every timer and takes the popup off screen
-- (core/WhatGroup.lua's NS.StandDown). The addon is inert; its command surface is not the addon.
-- tests/test_slash.lua and tests/test_disabled.lua pin both halves.
--
-- The ack is the CLI's own `key = value` line, built from the library's formatters rather than
-- respelled here, and it RE-READS the stored value rather than echoing the argument. The plain
-- fallback is for the install with no LibKa0s at all, where there is no formatter to call and the
-- rest of this file already renders plainly.
--
-- `ENABLED_PATH` is declared at the top of this file. The other reader of that row is
-- core/LifecycleSetup.lua's `disabled` hold, taken from it at OnEnable and re-taken on every
-- profile switch, so these verbs, the checkbox and the latch are three surfaces over ONE value.
--
-- These two verbs are on the library's live set, so they answer while the addon is off — `enable`
-- above all, or the pair is one-way and the only route back is the panel the player was trying not
-- to open (slash-commands-§7).

function runEnabled(on)
    local H = helpers()
    if not (H and H.Set) then return NS.Print(CLI_MISSING) end
    local row = H.FindSchema(ENABLED_PATH)
    if not row then return libraryAbsent(on and "/wg enable" or "/wg disable") end
    -- Never ack a write that did not land: a refusal prints the seam's own words instead.
    local ok, err = H.Set(ENABLED_PATH, on)
    if ok == false then return NS.Print(tostring(err)) end
    local value = H.Get(ENABLED_PATH)
    if lib then
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

-- `/wg debug diagnostics` writes the diagnostics report (debug-logging-§14), tested FIRST and
--                    case-insensitively. No other word runs it: `diag` is an unknown word.
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

    if sub == "diagnostics" then
        DL:RunDiagnostics()
    elseif sub == "on" or sub == "off" then
        DL:SetEnabled(sub == "on")
    elseif sub == "" then
        DL:Toggle()
    else
        NS.Print("Usage: /wg debug        (toggle the debug window)")
        NS.Print("       /wg debug on|off (enable/disable logging)")
        NS.Print("       /wg debug diagnostics (write the diagnostics report)")
    end
end

-- ---------------------------------------------------------------------------
-- The launcher's options menu (launcher-§2, standard v2.67.0; LibKa0s-Launcher-1.0 minor 4)
-- ---------------------------------------------------------------------------
--
-- The minimap button's right-click menu toggles through the addon's OWN verb bodies, so its
-- refusals, combat rules and chat acks are the ones the player gets from typing the command.
-- core/LauncherSetup.lua reaches these three methods; they are ON THE ADDON because the bodies
-- they wrap are file-locals here, and a second copy of any of them would be anti-pattern #81.
--
--   SlashEnabled(on)      runEnabled -- the one body `/wg enable` and `/wg disable` both call.
--   SlashToggleTestMode() runTest("") -- bare `/wg test`, the toggle form.
--   SlashToggleLock()     `/wg set locked toggle`. There is no `/wg lock` verb: the lock is a
--                         checkbox here (slash-commands-§8 MAY), so its CLI form is the schema
--                         verb over the Lock frame row's own path, through the same seam.
function WhatGroup:SlashEnabled(on) runEnabled(on and true or false) end
function WhatGroup:SlashToggleTestMode() runTest("") end
function WhatGroup:SlashToggleLock() Sl:CliSet("locked toggle") end

-- AceConsole registers both chat commands (core/WhatGroup.lua's OnInitialize); the library
-- registers none of its own, which is what keeps every verb's output flowing through the tagged
-- printer (slash-commands-§1).
function WhatGroup:OnSlashCommand(input)
    Sl:OnSlash(input)
end
