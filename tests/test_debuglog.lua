-- tests/test_debuglog.lua — debug console: pure formatters, font constant,
-- and the /wg debug window-vs-flag semantics (debug-logging-§2/§3/§5).
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
    -- The enable path appends the bracket line and THEN a [Init] state snapshot
    -- (debug-logging-§8), so assert containment rather than last-line.
    local found = false
    for _, line in ipairs(NS.DebugLog.buffer) do
        if line:find("[Debug] logging enabled", 1, true) then found = true end
    end
    assertTrue(found, "enabling should log '[Debug] logging enabled'")
end)

test("debuglog: enabling debug appends the [Init] session summary after the bracket (debug-logging-§5)", function()
    local NS = T.bootAddon()
    NS.State.debug = false
    debugCmd(NS, "on")
    local buf = NS.DebugLog.buffer
    local last = buf[#buf]
    assertTrue(last and last:find("[Init]", 1, true) ~= nil,
        "the on path must end with the [Init] summary, after the bracket line")
    -- Identity content: addon/version, schema, profile (debug-logging-§5).
    assertTrue(last:find("WhatGroup v", 1, true) ~= nil, "carries addon + version")
    assertTrue(last:find("schema v", 1, true) ~= nil, "carries schema version")
    assertTrue(last:find("profile 'Default'", 1, true) ~= nil, "carries active profile")
    -- Order: the bracket line comes immediately before the [Init] line.
    assertTrue(buf[#buf - 1]:find("[Debug] logging enabled", 1, true) ~= nil,
        "[Init] follows the enable bracket line")
end)

test("debuglog: [Init] fires only on enable, not on disable (debug-logging-§5)", function()
    local NS = T.bootAddon()
    NS.State.debug = false
    debugCmd(NS, "on")
    local afterOn = #NS.DebugLog.buffer
    debugCmd(NS, "off")
    for i = afterOn + 1, #NS.DebugLog.buffer do
        assertTrue(NS.DebugLog.buffer[i]:find("[Init]", 1, true) == nil,
            "disable must not emit an [Init] line")
    end
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

test("debuglog: NS.Debug survives an unsafe format arg without raising (WG-22)", function()
    local NS = T.newAddon()
    NS.State.debug = true
    -- `%d` with a table raises in string.format in every Lua version, exactly
    -- as a combat-protected secret would; the sink must catch it and still land
    -- a line with "<secret>" instead of freezing the caller.
    local ok = pcall(function() NS.Debug("Capture", "n=%d", {}) end)
    assertTrue(ok, "NS.Debug must not propagate a format error")
    local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
    assertTrue(last and last:find("<secret>", 1, true) ~= nil,
        "the unsafe value degrades to <secret> in the logged line")
end)

test("debuglog: NS.Debug is a no-op (no console write) when debug is off", function()
    local NS = T.newAddon()
    NS.State.debug = false
    local before = #NS.DebugLog.buffer
    NS.Debug("Capture", "should not append")
    assertEqual(#NS.DebugLog.buffer, before)
end)

-- ── message coverage / coalescing (debug-logging-§8/§9/§10) ────────────────

-- Count buffer lines containing a literal fragment (plain-text buffer, no colours).
local function countLines(NS, fragment)
    local n = 0
    for _, line in ipairs(NS.DebugLog.buffer) do
        if line:find(fragment, 1, true) then n = n + 1 end
    end
    return n
end

test("debuglog: settings change logs one [Set] line at the write seam (debug-logging-§10)", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    local before = countLines(NS, "[Set]")
    NS.addon.Settings.Helpers.Set("notify.delay", 3.0)
    assertEqual(countLines(NS, "[Set]") - before, 1, "exactly one [Set] line")
    assertTrue(countLines(NS, "notify.delay = 3") >= 1, "line shows path = value")
end)

test("debuglog: RestoreDefaults coalesces to one [Reset], zero [Set] (debug-logging-§9)", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    local setBefore = countLines(NS, "[Set]")
    NS.addon.Settings.Helpers.RestoreDefaults()
    assertEqual(countLines(NS, "[Set]") - setBefore, 0, "per-row [Set] suppressed")
    assertEqual(countLines(NS, "[Reset]"), 1, "one [Reset] summary")
    assertTrue(countLines(NS, "settings to defaults") >= 1, "summary names the count")
end)

test("debuglog: InitSummary leads with the debug-logging-§5 identity fields, then runtime state", function()
    local NS = T.bootAddon()
    local s = NS.addon:InitSummary()
    -- Standard-mandated identity prefix (name/version/schema/profile) comes first.
    assertEqual(s:sub(1, #("WhatGroup v" .. NS.addon.VERSION .. ", schema v1, profile 'Default'")),
        "WhatGroup v" .. NS.addon.VERSION .. ", schema v1, profile 'Default'")
    -- Runtime state appended on the same one line.
    for _, frag in ipairs({ "enabled=true", "notify.delay=0s", "autoShow=true",
                            "inGroup=false", "hasPending=false" }) do
        assertTrue(s:find(frag, 1, true) ~= nil, "summary carries " .. frag)
    end
end)

test("debuglog: enable ack is colour-coded green/red matching the header (debug-logging-§5)", function()
    -- The chat ack routes through NS.Print (prefixed). Assert the state word
    -- carries the mandated colour codes: ON 40ff40, OFF ff4040.
    local NS, _, mock = T.newAddon()
    NS.State.debug = false
    debugCmd(NS, "on")
    local onAck = mock.prints[#mock.prints]
    assertTrue(onAck:find("|cff40ff40ON|r", 1, true) ~= nil, "ON ack is green 40ff40")
    debugCmd(NS, "off")
    local offAck = mock.prints[#mock.prints]
    assertTrue(offAck:find("|cffff4040OFF|r", 1, true) ~= nil, "OFF ack is red ff4040")
end)
