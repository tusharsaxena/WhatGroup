-- tests/test_debuglog.lua — debug console: pure formatters, font constant,
-- and the /wg debug window-vs-flag semantics (debug-logging §2/§3/§5).
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function debugCmd(NS, rest)
    for _, c in ipairs(NS.addon.COMMANDS) do
        if c[1] == "debug" then return c[3](NS.addon, rest) end
    end
    error("no debug command")
end

test("debuglog: FONT_MONO points at the vendored JetBrains Mono TTF", function()
    local NS = T.newAddon()
    assertTrue(type(NS.FONT_MONO) == "string", "FONT_MONO must be a string")
    assertTrue(NS.FONT_MONO:match("JetBrainsMono.-%.ttf$") ~= nil,
        "FONT_MONO must point at the vendored JetBrainsMono TTF")
end)

test("debuglog: FormatPlain wraps the tag in brackets, single-space separators", function()
    local NS = T.newAddon()
    assertEqual(NS.DebugLog.FormatPlain("15:04:43", "Capture", "title=X"),
        "15:04:43 | [Capture] title=X")
end)

test("debuglog: FormatPlain tolerates a nil tag", function()
    local NS = T.newAddon()
    assertEqual(NS.DebugLog.FormatPlain("15:04:43", nil, "hi"), "15:04:43 | [] hi")
end)

test("debuglog: FormatColored colours timestamp + tag; pipe and content default", function()
    local NS = T.newAddon()
    assertEqual(NS.DebugLog.FormatColored("15:04:43", "Capture", "title=X"),
        "|cff6f8faf15:04:43|r || |cffc9a66b[Capture]|r title=X")
end)

test("debuglog: /wg debug on enables session state", function()
    local NS = T.newAddon()
    NS.State.debug = false
    debugCmd(NS, "on")
    assertTrue(NS.State.debug == true, "state should be on")
end)

test("debuglog: /wg debug off disables session state", function()
    local NS = T.newAddon()
    NS.State.debug = true
    debugCmd(NS, "off")
    assertTrue(NS.State.debug == false, "state should be off")
end)

test("debuglog: /wg debug (no arg) toggles the window, not the state", function()
    local NS = T.newAddon()
    NS.State.debug = true
    debugCmd(NS, "")
    assertTrue(NS.State.debug == true, "bare toggle must not change state")
    NS.State.debug = false
    debugCmd(NS, "")
    assertTrue(NS.State.debug == false, "bare toggle must not change state")
end)

test("debuglog: header toggle click flips debug state", function()
    local NS = T.newAddon()
    NS.State.debug = false
    NS.DebugLog:Show()
    local click = NS.DebugLog._toggleClickForTest
    assertTrue(type(click) == "function", "toggle click closure must be exposed")
    click(); assertTrue(NS.State.debug == true, "click should turn state on")
    click(); assertTrue(NS.State.debug == false, "second click should turn state off")
end)

test("debuglog: enabling writes a '[Debug] logging enabled' console line", function()
    local NS = T.newAddon()
    NS.State.debug = false
    debugCmd(NS, "on")
    local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
    assertTrue(last and last:find("[Debug] logging enabled", 1, true) ~= nil,
        "enabling should log '[Debug] logging enabled'")
end)

test("debuglog: disabling still appends a '[Debug] logging disabled' line", function()
    local NS = T.newAddon()
    NS.State.debug = true
    local before = #NS.DebugLog.buffer
    debugCmd(NS, "off")
    assertTrue(#NS.DebugLog.buffer > before, "disabling should still append a console line")
    local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
    assertTrue(last and last:find("[Debug] logging disabled", 1, true) ~= nil,
        "disabling should log '[Debug] logging disabled'")
end)

test("debuglog: NS.Debug is a no-op (no console write) when debug is off", function()
    local NS = T.newAddon()
    NS.State.debug = false
    local before = #NS.DebugLog.buffer
    NS.Debug("Capture", "should not append")
    assertEqual(#NS.DebugLog.buffer, before)
end)
