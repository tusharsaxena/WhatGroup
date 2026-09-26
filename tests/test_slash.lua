-- tests/test_slash.lua — slash surface: the standalone version verb (WG-29)
-- and the colon-free help header (WG-19), driven through the COMMANDS table.
local T = _G.WHATGROUP_TEST
local test, assertTrue, assertFalse = T.test, T.assertTrue, T.assertFalse

local function runCmd(NS, name, rest)
    for _, c in ipairs(NS.addon.COMMANDS) do
        -- Positional triples, and the handler takes `rest` ALONE: the library calls
        -- entry[3](rest), never entry[3](self, rest).
        if c[1] == name then return c[3](rest) end
    end
    error("no command: " .. tostring(name))
end

test("slash: COMMANDS has a standalone version verb (WG-29)", function()
    local NS = T.newAddon()
    local found = false
    for _, c in ipairs(NS.addon.COMMANDS) do
        if c[1] == "version" then found = true end
    end
    assertTrue(found, "a 'version' command row must exist")
end)

test("slash: /wg version prints [WG] v<version> on its own line (WG-29)", function()
    local NS, _, mock = T.bootAddon()
    runCmd(NS, "version")
    local line = mock.prints[#mock.prints]
    assertTrue(line:find(NS.PREFIX, 1, true) ~= nil, "carries the [WG] tag")
    assertTrue(line:find("v" .. NS.addon.VERSION, 1, true) ~= nil,
        "shows v<version> (TOC metadata, falling back to the constant)")
end)

test("slash: help header has no trailing colon (WG-19)", function()
    local NS, _, mock = T.newAddon()
    runCmd(NS, "help")
    local header
    for _, line in ipairs(mock.prints) do
        if line:find("slash commands", 1, true) then header = line; break end
    end
    assertTrue(header ~= nil, "help header was printed")
    assertFalse(header:match(":%s*$") ~= nil, "header must not end in a trailing colon")
end)

-- ---------------------------------------------------------------------------
-- Dispatch (WhatGroup:OnSlashCommand)
-- ---------------------------------------------------------------------------

local T2 = _G.WHATGROUP_TEST
local assertEqual, assertNil = T2.assertEqual, T2.assertNil

-- Chat lines printed by `body`, in order.
local function capture(mock, body)
    local mark = #mock.prints
    body()
    local out = {}
    for i = mark + 1, #mock.prints do out[#out + 1] = mock.prints[i] end
    return out
end

local function anyLine(lines, fragment)
    for _, l in ipairs(lines) do
        if l:find(fragment, 1, true) then return true end
    end
    return false
end

test("slash: a bare /wg opens the settings landing page through `config`", function()
    -- slash-commands-§4: bare opens the Settings panel on its home page; `help` is the index.
    local NS, _, mock = T.enableAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("") end)
    assertEqual(#mock.openedTo, 1, "the panel opened, once")
    assertEqual(mock.openedTo[1], mock.categories[1]:GetID(), "on the parent (landing) category")
    assertFalse(anyLine(lines, "slash commands"), "and no help index printed")
    lines = capture(mock, function() NS.addon:OnSlashCommand("help") end)
    assertTrue(anyLine(lines, "slash commands"), "`/wg help` is where the index lives")
    assertEqual(#mock.openedTo, 1, "and it opens nothing")
end)

test("slash: whitespace-only input is treated as bare /wg", function()
    local NS, _, mock = T.enableAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("   ") end)
    assertEqual(#mock.openedTo, 1, "the panel opened, as for a bare /wg")
    assertEqual(mock.openedTo[1], mock.categories[1]:GetID())
    assertFalse(anyLine(lines, "slash commands"))
end)

test("slash: nil input is tolerated", function()
    local NS = T.bootAddon()
    local ok = pcall(function() NS.addon:OnSlashCommand(nil) end)
    assertTrue(ok, "the dispatcher must not raise on nil input")
end)

test("slash: help lists one row per COMMANDS entry, plus the header", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("help") end)
    assertEqual(#lines, #NS.addon.COMMANDS + 1)
end)

test("slash: every COMMANDS row carries a verb, a description and a handler", function()
    local NS = T.bootAddon()
    for _, entry in ipairs(NS.addon.COMMANDS) do
        assertEqual(type(entry[1]), "string")
        assertTrue(entry[2] ~= nil and entry[2] ~= "", "missing description for " .. entry[1])
        assertEqual(type(entry[3]), "function")
    end
end)

test("slash: an unknown verb says so and then prints the help index", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("nonsense") end)
    assertTrue(anyLine(lines, "unknown command 'nonsense'"))
    assertTrue(anyLine(lines, "slash commands"))
end)

test("slash: the verb is case-insensitive", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("VERSION") end)
    assertTrue(anyLine(lines, "v" .. NS.addon.VERSION))
end)

test("slash: only the verb is lower-cased — the argument keeps its case", function()
    local NS, _, mock = T.bootAddon()
    -- `notify.showInstance` is camelCase; lower-casing the whole input would
    -- make every nested schema path unreachable from the CLI.
    local lines = capture(mock, function() NS.addon:OnSlashCommand("GET notify.showInstance") end)
    assertTrue(anyLine(lines, "notify.showInstance"))
end)

test("slash: /wg version reads the version from TOC metadata", function()
    local NS, _, mock = T.bootAddon()
    mock.metadata.Version = "9.9.9"
    local lines = capture(mock, function() NS.addon:OnSlashCommand("version") end)
    assertTrue(anyLine(lines, "v9.9.9"))
end)

test("slash: /wg version falls back to the in-code constant", function()
    local NS, _, mock = T.bootAddon()
    mock.metadata.Version = ""
    local lines = capture(mock, function() NS.addon:OnSlashCommand("version") end)
    assertTrue(anyLine(lines, "v" .. NS.addon.VERSION))
end)

-- ---------------------------------------------------------------------------
-- /wg list
-- ---------------------------------------------------------------------------

test("slash: /wg list prints every schema row", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("list") end)
    for _, def in ipairs(NS.addon.Settings.Schema) do
        assertTrue(anyLine(lines, def.path), "list omitted " .. def.path)
    end
end)

test("slash: /wg list groups rows under their section header", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("list") end)
    assertTrue(anyLine(lines, "[general]"))
    assertTrue(anyLine(lines, "[notify]"))
    assertTrue(anyLine(lines, "[frame]"))
end)

test("slash: /wg list shows current values, not defaults", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.Settings.Helpers.Set("notify.delay", 3)
    local lines = capture(mock, function() NS.addon:OnSlashCommand("list") end)
    assertTrue(anyLine(lines, "3.0s"), "the number row renders through its fmt")
end)

-- ---------------------------------------------------------------------------
-- /wg get
-- ---------------------------------------------------------------------------

test("slash: /wg get prints key = value", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("get enabled") end)
    assertTrue(anyLine(lines, "enabled"))
    assertTrue(anyLine(lines, "true"))
end)

test("slash: /wg get with no path prints usage", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("get") end)
    assertTrue(anyLine(lines, "Usage: /wg get <path>"))
end)

test("slash: /wg get reports an unknown path rather than printing nil", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("get nope.nope") end)
    assertTrue(anyLine(lines, "Setting not found: nope.nope"))
end)

test("slash: /wg get formats a number through the schema fmt", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.Settings.Helpers.Set("notify.delay", 2.5)
    local lines = capture(mock, function() NS.addon:OnSlashCommand("get notify.delay") end)
    assertTrue(anyLine(lines, "2.5s"))
end)

-- ---------------------------------------------------------------------------
-- /wg set
-- ---------------------------------------------------------------------------

test("slash: /wg set with no path prints usage", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("set") end)
    assertTrue(anyLine(lines, "Usage: /wg set <path> <value>"))
end)

test("slash: /wg set reports an unknown path", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("set nope true") end)
    assertTrue(anyLine(lines, "Setting not found: nope"))
end)

-- Every accepted spelling of a boolean, per applyFromText.
for _, case in ipairs({
    { word = "true",  want = true  }, { word = "1",   want = true  },
    { word = "on",    want = true  }, { word = "yes", want = true  },
    { word = "false", want = false }, { word = "0",   want = false },
    { word = "off",   want = false }, { word = "no",  want = false },
}) do
    test("slash: /wg set accepts '" .. case.word .. "' as " .. tostring(case.want), function()
        local NS = T.bootAddon()
        NS.addon.Settings.Helpers.Set("notify.showLeader", not case.want)
        NS.addon:OnSlashCommand("set notify.showLeader " .. case.word)
        assertEqual(NS.addon.Settings.Helpers.Get("notify.showLeader"), case.want)
    end)
end

test("slash: /wg set bool words are case-insensitive", function()
    local NS = T.bootAddon()
    NS.addon:OnSlashCommand("set notify.showLeader OFF")
    assertEqual(NS.addon.Settings.Helpers.Get("notify.showLeader"), false)
end)

test("slash: /wg set toggle flips the current value", function()
    local NS = T.bootAddon()
    NS.addon:OnSlashCommand("set notify.showLeader toggle")
    assertEqual(NS.addon.Settings.Helpers.Get("notify.showLeader"), false)
    NS.addon:OnSlashCommand("set notify.showLeader toggle")
    assertEqual(NS.addon.Settings.Helpers.Get("notify.showLeader"), true)
end)

test("slash: /wg set rejects a non-boolean word and lists the accepted ones", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function()
        NS.addon:OnSlashCommand("set notify.showLeader maybe")
    end)
    assertTrue(anyLine(lines, "Invalid value for notify.showLeader"))
    assertTrue(anyLine(lines, "expected true/false/on/off/1/0/toggle"))
    assertEqual(NS.addon.Settings.Helpers.Get("notify.showLeader"), true,
        "a rejected value leaves the setting untouched")
end)

test("slash: /wg set writes a number", function()
    local NS = T.bootAddon()
    NS.addon:OnSlashCommand("set notify.delay 4")
    assertEqual(NS.addon.Settings.Helpers.Get("notify.delay"), 4)
end)

test("slash: /wg set rejects a non-numeric value for a number row", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("set notify.delay soon") end)
    assertTrue(anyLine(lines, "expected a number"))
    assertEqual(NS.addon.Settings.Helpers.Get("notify.delay"), 0)
end)

test("slash: /wg set clamps a number below the schema min", function()
    local NS = T.bootAddon()
    NS.addon:OnSlashCommand("set notify.delay -5")
    assertEqual(NS.addon.Settings.Helpers.Get("notify.delay"), 0)
end)

test("slash: /wg set clamps a number above the schema max", function()
    local NS = T.bootAddon()
    NS.addon:OnSlashCommand("set notify.delay 999")
    assertEqual(NS.addon.Settings.Helpers.Get("notify.delay"), 10)
end)

test("slash: /wg set echoes the STORED value back, not the typed one", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("set notify.delay 999") end)
    assertTrue(anyLine(lines, "10.0s"), "the clamp is visible in the echo")
end)

test("slash: /wg set with a missing value is rejected, not silently applied", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("set notify.delay") end)
    assertTrue(anyLine(lines, "Invalid value for notify.delay"))
end)

test("slash: /wg set enabled false runs the master-switch onChange", function()
    local NS = T.bootAddon()
    NS.addon.pendingInfo = { title = "in flight" }
    NS.addon:OnSlashCommand("set enabled false")
    assertNil(NS.addon.pendingInfo)
end)

-- ---------------------------------------------------------------------------
-- /wg debug
-- ---------------------------------------------------------------------------

test("slash: /wg debug with a bad subcommand prints all three usage lines", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("debug wat") end)
    assertTrue(anyLine(lines, "/wg debug        (toggle the debug window)"))
    assertTrue(anyLine(lines, "/wg debug on|off (enable/disable logging)"))
    assertTrue(anyLine(lines, "/wg debug diagnostics (write the diagnostics report)"))
end)

test("slash: /wg debug diag is an unknown word: usage, and no report (debug-logging-§14)", function()
    -- `diag` was never a WhatGroup word, and the standard rules out any short alias: it answers as
    -- every other unknown word does. red under: a `diag` branch in runDebug.
    local NS, _, mock = T.bootAddon()
    local before = #NS.DebugLog.buffer
    local lines = capture(mock, function() NS.addon:OnSlashCommand("debug diag") end)
    assertTrue(anyLine(lines, "/wg debug diagnostics (write the diagnostics report)"))
    assertEqual(#NS.DebugLog.buffer, before, "nothing was written to the console")
end)

test("slash: /wg debug (bare) toggles the console window's visibility", function()
    local NS = T.bootAddon()
    assertFalse(NS.DebugLog:IsShown())
    NS.addon:OnSlashCommand("debug")
    assertTrue(NS.DebugLog:IsShown(), "the window opened")
    NS.addon:OnSlashCommand("debug")
    assertFalse(NS.DebugLog:IsShown(), "and closed again")
end)

test("slash: /wg debug on does not open the window", function()
    local NS = T.bootAddon()
    NS.addon:OnSlashCommand("debug on")
    assertTrue(NS.State.debug, "logging is on")
    assertFalse(NS.DebugLog:IsShown(), "but the window stays closed until asked for")
end)

-- ---------------------------------------------------------------------------
-- The enum row — `visibility` is the addon's first `type = "string"` (options-ui-§15)
-- ---------------------------------------------------------------------------

test("slash: /wg set writes an enum value from the row's own value set", function()
    -- The CLI half of the dropdown. `ValidateSchema` had to learn `string` for this row to exist
    -- at all, and the library's parser validates against `values` rather than accepting any word.
    local NS = T.bootAddon()
    NS.addon:OnSlashCommand("set visibility inCombat")
    assertEqual(NS.addon.Settings.Helpers.Get("visibility"), "inCombat")
end)

test("slash: /wg set rejects a value the enum does not offer", function()
    -- red under: dropping `values` from the composed row, which would make any word legal.
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function()
        NS.addon:OnSlashCommand("set visibility whenever")
    end)
    assertTrue(#lines > 0, "the refusal is reported")
    assertEqual(NS.addon.Settings.Helpers.Get("visibility"), "always",
        "a rejected value leaves the setting untouched")
end)

test("slash: /wg list carries the Master controls rows under their section", function()
    -- They are composed, not declared here, and `section` is stamped onto them in
    -- settings/Panel.lua because the composer cannot know a host's `/wg list` key.
    -- red under: dropping that stamp, which would file them under "?".
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("list") end)
    for _, path in ipairs({ "enabled", "visibility", "scale", "alpha", "locked" }) do
        assertTrue(anyLine(lines, path), path .. " is missing from /wg list")
    end
end)

-- ---------------------------------------------------------------------------
-- The reserved pair — `enable` / `disable` (slash-commands-§2)
-- ---------------------------------------------------------------------------
--
-- They are ALIASES for the Master-controls `Enable WhatGroup` checkbox, not a second switch. What
-- is pinned here is that they hold no state of their own, that they take the one write seam, and
-- that the dispatcher outlives the state they set — a pair that could turn the addon off but not
-- back on would be one-way, and the only route left would be the settings panel the player was
-- trying not to open.

test("slash: /wg enable and /wg disable write the checkbox's own stored path", function()
    -- red under: a second key, an NS.enabled local, or a session flag beside the stored row.
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    NS.addon:OnSlashCommand("disable")
    assertEqual(H.Get("enabled"), false)
    assertEqual(NS.addon.db.profile.enabled, false, "the STORED row, not a copy of it")
    NS.addon:OnSlashCommand("enable")
    assertEqual(H.Get("enabled"), true)
    assertEqual(NS.addon.db.profile.enabled, true)
end)

test("slash: the verbs and the checkbox are the same row, so they cannot disagree", function()
    -- The checkbox reads through the same Helpers.Get the verb writes through, which is the whole
    -- content of "aliases, never a second switch".
    -- red under: the verb writing anything but `enabled`.
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    H.Set("enabled", false)
    NS.addon:OnSlashCommand("enable")
    assertEqual(H.FindSchema("enabled").path, "enabled")
    assertTrue(H.Get("enabled"), "the box follows the verb")
    NS.addon:OnSlashCommand("disable")
    assertFalse(H.Get("enabled"), "and the verb follows the box's path back")
end)

test("slash: `disable` runs the row's onChange, exactly as the checkbox does", function()
    -- The off-flip capture wipe is stamped onto the composed row in settings/Panel.lua, and it must
    -- run whichever surface the player used — or a pre-toggle apply could still surface a popup
    -- after the addon has been switched off.
    -- red under: the verb writing through RawSet, or setting db.profile.enabled directly.
    local NS = T.bootAddon()
    NS.addon.pendingInfo = { title = "Stonevault" }
    NS.addon:OnSlashCommand("disable")
    assertNil(NS.addon.pendingInfo, "WipeCapture ran")
end)

test("slash: each verb acknowledges on one `key = value` line", function()
    -- slash-commands-§5's `set` shape, re-READ from the store rather than echoing the argument.
    -- red under: a silent verb, or one that answers in its own words.
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("disable") end)
    assertEqual(#lines, 1, "one line")
    assertTrue(anyLine(lines, "enabled"), "names the path")
    assertTrue(anyLine(lines, "false"), "and the value that was stored")
end)

test("slash: the dispatcher answers while the addon is disabled", function()
    -- slash-commands-§2: `/wg` and every verb reachable from it — `enable` above all, and with it
    -- `help`, `config` and `version` — keep working while the addon is off. The master switch is
    -- read at the capture entry points and nowhere else, so nothing here unregisters the chat
    -- command, drops COMMANDS or tears down the dispatcher.
    -- red under: gating OnSlashCommand, or unregistering `/wg` on the off-flip.
    local NS, _, mock = T.enableAddon()
    NS.addon:OnSlashCommand("disable")

    local help = capture(mock, function() NS.addon:OnSlashCommand("help") end)
    assertTrue(#help > 1, "help still answers")
    local version = capture(mock, function() NS.addon:OnSlashCommand("version") end)
    assertTrue(anyLine(version, "v" .. NS.addon.VERSION), "version still answers")
    local opened = #mock.openedTo
    NS.addon:OnSlashCommand("")
    assertTrue(#mock.openedTo > opened, "a bare /wg still opens the panel")

    -- And the one that matters: the way back.
    NS.addon:OnSlashCommand("enable")
    assertTrue(NS.addon.Settings.Helpers.Get("enabled"), "the switch is not one-way")
end)

test("slash: the reserved pair is in COMMANDS, so help and the landing page carry it", function()
    -- A verb that works but is not in the table is a verb nobody finds: the help index and the
    -- panel's landing page both render this table (slash-commands-§4).
    -- red under: wiring the pair straight into the dispatcher.
    local NS = T.newAddon()
    local seen = {}
    for _, c in ipairs(NS.addon.COMMANDS) do seen[c[1]] = c end
    assertTrue(seen.enable ~= nil, "enable is a COMMANDS row")
    assertTrue(seen.disable ~= nil, "disable is a COMMANDS row")
    assertEqual(type(seen.enable[3]), "function")
    assertEqual(type(seen.disable[2]), "string")
end)

-- ---------------------------------------------------------------------------
-- The disabled gate — a feature verb refuses rather than acting (slash-commands-§2)
-- ---------------------------------------------------------------------------
--
-- The standard's trailing SHOULD, made precise in v2.54.0 and taken here. A verb that DRIVES THE
-- ADDON'S FEATURES answers on one tagged line naming `/wg enable` and does nothing else; the
-- reserved surface and the schema CLI stay live, because a player has to be able to read and repair
-- settings and reach the panel while the addon is off — and `enable` above all, or the pair the
-- block above pins is one-way again.
--
-- WhatGroup's feature verbs are `show` and `test`. What is pinned below is BOTH halves of each
-- refusal: that it said so, AND that it did not act. A case that only checked the message would
-- pass over a verb that printed and then went ahead anyway, which is the exact failure this rule
-- exists to prevent.

local FEATURE_VERBS = { "show", "test" }

-- The verbs that keep answering, named here the way settings/Slash.lua names them: the standard's
-- list, not this addon's subset. `perf` is absent from COMMANDS (LIBKA0S-15) and is checked as a
-- non-row rather than run. `diagnostics` joined the library's list at Slash minor 16 (LibKa0s
-- v1.60.0, debug-logging-§14).
local LIVE_VERBS = {
    "help", "config", "version", "enable", "disable", "debug",
    "get", "set", "list", "reset", "resetall", "diagnostics",
}

local function disabled()
    local NS, env, mock = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    return NS, env, mock
end

-- The refusal is recognized by its OWN words, not by the `/wg enable` it names: `help` prints a
-- `/wg enable — Enable the addon` row of its own, so a fragment match on the verb would call the
-- help index a refusal and this whole block would pass for the wrong reason.
local REFUSAL = "WhatGroup is disabled"

local function popupShown(mock)
    local f = mock.frames["WhatGroupFrame"]
    return f ~= nil and f:IsShown() and f:GetAlpha() > 0
end

test("slash: `/wg show` refuses while disabled, and does not show the popup", function()
    -- BOTH halves. A capture is waiting, so a verb that ignored the gate would put a window on
    -- screen — which is what "did nothing else" has to mean to be worth writing down.
    -- red under: the gate printing and falling through, or guarding only `test`.
    local NS, _, mock = disabled()
    NS.addon.pendingInfo = { title = "Stonevault", leaderName = "Testadin",
                             fullName = "The Stonevault", shortName = "", playstyleString = "",
                             generalPlaystyle = 0, activityID = 2516, mapID = 2652 }
    local lines = capture(mock, function() NS.addon:OnSlashCommand("show") end)
    assertEqual(#lines, 1, "one line, not a paragraph")
    assertTrue(anyLine(lines, REFUSAL), "it says the addon is standing down")
    assertTrue(anyLine(lines, "/wg enable"), "and names the verb that undoes the state")
    assertTrue(lines[1]:find(NS.PREFIX, 1, true) ~= nil, "carrying the [WG] tag")
    assertFalse(popupShown(mock), "the popup stayed shut")
end)

test("slash: `/wg test on` refuses while disabled, and does not enter test mode", function()
    -- The other feature verb, and the one whose act is a STORED row rather than a frame: test mode
    -- must still read false afterwards, or the checkbox and the refusal disagree.
    -- red under: the wrapper returning the handler's result instead of replacing the call.
    local NS, _, mock = disabled()
    local H = NS.addon.Settings.Helpers
    local lines = capture(mock, function() NS.addon:OnSlashCommand("test on") end)
    assertEqual(#lines, 1)
    assertTrue(anyLine(lines, REFUSAL))
    assertTrue(anyLine(lines, "/wg enable"))
    assertFalse(H.Get("state.testMode"), "test mode did not start")
    assertFalse(popupShown(mock))
end)

test("slash: every verb is either on the live list or refuses — there is no third kind", function()
    -- THE COVERAGE CASE, and the reason the gate is one wrapper over COMMANDS rather than a guard
    -- pasted into each handler. It derives the feature half from the table instead of listing it,
    -- so a verb added tomorrow is checked the day it lands: if it drives a feature and the gate
    -- missed it, it acts here and reddens; if it belongs on the live list, it has to be put there
    -- deliberately, which is the decision the standard wants taken once per verb.
    -- red under: a per-verb guard that the next verb forgets, or narrowing the library's live set
    -- host-side — dropping `debug` or a schema-CLI verb from it reddens the other half.
    local NS, _, mock = disabled()
    local live = {}
    for _, verb in ipairs(LIVE_VERBS) do live[verb] = true end

    local refused, allowed = 0, 0
    for _, entry in ipairs(NS.addon.COMMANDS) do
        local verb  = entry[1]
        -- A bare verb for each: `test` and `debug` print usage for an unknown argument and
        -- `get`/`set`/`reset` print their own Usage line, none of which is the refusal.
        local lines = capture(mock, function() NS.addon:OnSlashCommand(verb) end)
        if live[verb] then
            allowed = allowed + 1
            -- `help` IS THE ONE EXCEPTION, and it is not a refusal OF help: the index prints in
            -- full — the player has to be able to SEE `enable` in the list — with the line
            -- immediately under the header as a statement about the whole index, because some of
            -- the rows below it are this addon's own feature verbs. Every other live verb answers
            -- with no refusal anywhere in its output.
            if verb == "help" then
                assertTrue(#lines > #NS.addon.COMMANDS, "the index still prints in full")
            else
                assertFalse(anyLine(lines, REFUSAL), verb .. " is on the live list and never refuses")
            end
        else
            refused = refused + 1
            assertTrue(anyLine(lines, REFUSAL), verb .. " drives a feature, so it refuses")
            assertEqual(#lines, 1, verb .. " answers on ONE line and never the index")
        end
    end
    assertEqual(refused, #FEATURE_VERBS, "show and test, and nothing else, refuse today")
    assertEqual(allowed, #LIVE_VERBS, "and every live verb is a row — `perf` aside")

    -- The one that matters most: the way back is on the live list, so the pair is never one-way.
    NS.addon:OnSlashCommand("enable")
    assertTrue(NS.addon.Settings.Helpers.Get("enabled"))
end)

test("slash: the gate lifts the moment the addon is enabled again", function()
    -- It reads the stored row at CALL time rather than latching anything at load, so `/wg enable`
    -- followed by `/wg show` works in one breath.
    -- red under: caching the enabled state in the wrapper.
    local NS, _, mock = disabled()
    NS.addon.pendingInfo = { title = "Stonevault", leaderName = "Testadin",
                             fullName = "The Stonevault", shortName = "", playstyleString = "",
                             generalPlaystyle = 0, activityID = 2516, mapID = 2652 }
    NS.addon:OnSlashCommand("enable")
    NS.addon:OnSlashCommand("show")
    assertTrue(popupShown(mock), "the verb acts again")
end)

test("slash: the refusal REPLACES the handler — not even its own empty-state hint prints", function()
    -- "Does nothing else" from a third angle. `/wg show` with no capture normally prints its own
    -- "No group info available" hint, so a gate that ran before the handler but let it through, or
    -- one placed a line too low inside runShow, would still emit that second line.
    -- red under: printing the refusal and falling through.
    local NS, _, mock = disabled()
    assertNil(NS.addon.pendingInfo, "there is no capture, so the verb has a hint of its own to print")
    local lines = capture(mock, function() NS.addon:OnSlashCommand("show") end)
    assertEqual(#lines, 1, "the handler never ran at all")
    assertFalse(anyLine(lines, "No group info available"), "not even its own empty-state hint")
end)

test("slash: the refusal does not touch the help index or the landing page", function()
    -- The gate wraps handlers; settings/Panel.lua and the help renderer read entry[1] and entry[2].
    -- A disabled addon still LISTS `show` and `test`, which is what lets the player find out the
    -- addon has them.
    -- red under: removing the rows from COMMANDS while disabled instead of refusing them.
    local NS, _, mock = disabled()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("help") end)
    assertTrue(anyLine(lines, "/wg show"), "show is still in the index")
    assertTrue(anyLine(lines, "/wg test"), "and so is test")
end)

test("slash: `perf` is reserved here but not registered (LIBKA0S-15)", function()
    -- It is on the never-refused list in settings/Slash.lua because the standard reserves it
    -- collection-wide, and the entry is what keeps that list readable as the rule rather than as
    -- this addon's subset of it. There is no instance to dispatch into, so there is no row.
    -- red under: registering `perf` without the harness behind it.
    local NS = T.newAddon()
    for _, c in ipairs(NS.addon.COMMANDS) do
        assertFalse(c[1] == "perf", "no perf row while the Perf major is declined")
    end
end)
