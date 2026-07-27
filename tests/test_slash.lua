-- tests/test_slash.lua — slash surface: the standalone version verb (WG-29)
-- and the colon-free help header (WG-19), driven through the COMMANDS table.
local T = _G.WHATGROUP_TEST
local test, assertTrue, assertFalse = T.test, T.assertTrue, T.assertFalse

local function runCmd(NS, name, rest)
    for _, c in ipairs(NS.addon.COMMANDS) do
        if c[1] == name then return c[3](NS.addon, rest) end
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

test("slash: a bare /wg prints the help index", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("") end)
    assertTrue(anyLine(lines, "slash commands"))
end)

test("slash: whitespace-only input is treated as bare /wg", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("   ") end)
    assertTrue(anyLine(lines, "slash commands"))
end)

test("slash: nil input is tolerated", function()
    local NS, _, mock = T.bootAddon()
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

test("slash: /wg debug with a bad subcommand prints both usage lines", function()
    local NS, _, mock = T.bootAddon()
    local lines = capture(mock, function() NS.addon:OnSlashCommand("debug wat") end)
    assertTrue(anyLine(lines, "/wg debug        (toggle the debug window)"))
    assertTrue(anyLine(lines, "/wg debug on|off (enable/disable logging)"))
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
