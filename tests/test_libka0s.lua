-- tests/test_libka0s.lua — the LibKa0s seams this addon owns: that the vendored library actually
-- registers, that each descriptor is well-formed, that the degraded install answers rather than
-- errors, and the `L`-trap guards (testing-§8).
--
-- The library's own behaviour is tested where it lives. What is pinned here is the WIRING, and
-- above all the two things nothing else can see: that the modules are really present (a seam
-- measuring its own fallback stub is green and proves nothing), and that no descriptor was handed
-- this addon's locale table.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local body = f:read("*a")
    f:close()
    return body
end

-- Every file the addon's own source may hand a descriptor to a LibKa0s module from. The `L`-trap
-- source guard below sweeps exactly these.
local SEAM_FILES = {
    "core/CoreSetup.lua",
    "core/DebugLogSetup.lua",
    "settings/OptionsSetup.lua",
    "settings/Slash.lua",
}

-- ---------------------------------------------------------------------------
-- The vendored library is really there
-- ---------------------------------------------------------------------------

test("libka0s: every vendored major registers under LibStub", function()
    local _, env = T.newAddon()
    for _, major in ipairs({
        "LibKa0s-Core-1.0", "LibKa0s-DebugLog-1.0", "LibKa0s-Slash-1.0",
        "LibKa0s-Options-1.0", "LibKa0s-Perf-1.0",
    }) do
        assertTrue(env.LibStub(major, true) ~= nil, major .. " did not register")
    end
end)

test("libka0s: MODULES names every file of every major, at a positive integer minor", function()
    local _, env = T.newAddon()
    local expected = {
        ["LibKa0s-Core-1.0"]     = { "Core" },
        ["LibKa0s-DebugLog-1.0"] = { "DebugLog" },
        ["LibKa0s-Slash-1.0"]    = { "Slash" },
        ["LibKa0s-Options-1.0"]  = { "Options", "OptionsWidgets", "OptionsScroll" },
        ["LibKa0s-Perf-1.0"]     = { "Perf", "PerfPanel" },
    }
    for major, files in pairs(expected) do
        local lib = env.LibStub(major, true)
        assertTrue(type(lib.MODULES) == "table", major .. " has no MODULES registry")
        for _, file in ipairs(files) do
            local minor = lib.MODULES[file]
            assertEqual(type(minor), "number", major .. " does not report " .. file)
            assertTrue(minor > 0 and minor == math.floor(minor),
                major .. "." .. file .. " minor must be a positive integer")
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Core (core/CoreSetup.lua)
-- ---------------------------------------------------------------------------

test("core: the published seams ARE the library's, not a lookalike", function()
    -- Identity, not behaviour. Two implementations that agree today is exactly the drift the
    -- extraction exists to end, and a behavioural assertion cannot tell them apart.
    local NS, env = T.newAddon()
    local core = env.LibStub("LibKa0s-Core-1.0", true)
    assertEqual(NS.SafeToString, core.SafeToString)
    assertEqual(NS.IsConcatSafe, core.IsConcatSafe)
    assertEqual(NS.SKIN, core.SKIN, "the skin table is shared, never copied")
    assertEqual(NS.ApplySkin, core.ApplySkin)
    assertEqual(NS.MakeCloseButton, core.MakeCloseButton)
end)

test("core: the printer emits <prefix><space><body> as one line", function()
    -- The byte-level half of the formatter handover. The old seam called
    -- `print(NS.PREFIX, body)` and let the client join the two; Core composes the line itself and
    -- hands it to the sink, so this pins that the composed bytes are the same.
    local NS, _, mock = T.newAddon()
    NS.Print("   - Group:", "My Group")
    assertEqual(mock.prints[#mock.prints], NS.PREFIX .. " " .. "   - Group: My Group")
end)

test("core: the prefix is read at CALL time, not captured at load", function()
    -- core/CoreSetup.lua loads before core/WhatGroup.lua defines NS.PREFIX, so the string form
    -- would have captured nil forever. Move the constant and the next line must move with it.
    local NS, _, mock = T.newAddon()
    NS.PREFIX = "|cff00FF00[XX]|r"
    NS.Print("after")
    assertEqual(mock.prints[#mock.prints], "|cff00FF00[XX]|r after")
end)

test("core: the sink is the Lua global print, so the harness can see chat output", function()
    -- Core defaults to DEFAULT_CHAT_FRAME:AddMessage. This addon has always printed through the
    -- global, and the mock captures the global — without the explicit `sink` every chat assertion
    -- in this suite would go silent while still passing.
    local NS, _, mock = T.newAddon()
    local before = #mock.prints
    NS.Print("routed")
    assertEqual(#mock.prints, before + 1, "the line landed in the global-print capture")
end)

-- ---------------------------------------------------------------------------
-- DebugLog (core/DebugLogSetup.lua)
-- ---------------------------------------------------------------------------

test("debuglog: the console is the library's instance, and the sink is bound bare", function()
    local NS = T.newAddon()
    assertEqual(type(NS.DebugLog.SetEnabled), "function", "the instance surface is there")
    assertEqual(NS.Debug, NS.DebugLog.Debug,
        "NS.Debug must BE the instance's plain function, not a wrapper — ~20 call sites bind it")
end)

test("debuglog: the descriptor keeps the frame globals the old console used", function()
    -- A rename here is invisible until a player's Esc stops closing the window or /framestack
    -- attributes it to nobody.
    local NS, _, mock = T.newAddon()
    NS.DebugLog:Show()
    assertTrue(mock.frames["WhatGroupDebugWindow"] ~= nil, "the console window keeps its name")
    NS.DebugLog:ShowCopy()
    assertTrue(mock.frames["WhatGroupDebugCopyWindow"] ~= nil, "and so does the copy window")
    assertTrue(mock.frames["WhatGroupDebugCopyScroll"] ~= nil, "and its scroll frame")
end)

test("debuglog: the composed window title is unchanged", function()
    -- The library appends its own " — Debug" to the descriptor's `title`, so this is the byte-level
    -- check that the two halves still compose to what the hand-written console rendered.
    local NS, _, mock = T.newAddon()
    NS.DebugLog:Show()
    assertEqual(mock.frames["WhatGroupDebugWindow"].titleText, "Ka0s WhatGroup \226\128\148 Debug")
end)

test("debuglog: the flag stays the addon's — the library never keeps a copy", function()
    local NS = T.newAddon()
    NS.State.debug = false
    NS.DebugLog:SetEnabled(true)
    assertTrue(NS.State.debug, "SetEnabled wrote through to NS.State.debug")
    assertTrue(NS.DebugLog:IsEnabled(), "and IsEnabled reads the same flag")
    NS.State.debug = false
    assertFalse(NS.DebugLog:IsEnabled(), "a write straight to the flag is seen too")
end)

test("debuglog: the [Init] summary is the addon's, reached through the descriptor", function()
    local NS = T.bootAddon()
    NS.State.debug = false
    NS.DebugLog:SetEnabled(true)
    local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
    assertEqual(last:find("[Init]", 1, true) ~= nil, true, "the enable path ends with [Init]")
    assertTrue(last:find(NS.addon:InitSummary(), 1, true) ~= nil,
        "and the line IS this addon's summary, not a library default")
end)

test("debuglog: the console's user-visible strings resolve to prose, not to their own keys", function()
    -- The rendered half of the `L` trap, for the one adopted module that can express it and does
    -- render a real library string. Reached through a REAL accessor: a case that guards on
    -- `if label then` passes vacuously when the accessor does not exist.
    --
    -- red under: `L = { CHECKBOX_LABEL = "CHECKBOX_LABEL" }` on the descriptor. Note that
    -- `L = NS.L` alone does NOT redden this one — DebugLog's resolver has used `rawget` since
    -- minor 3, so a metatable-backed table falls through correctly and the trap is invisible from
    -- the rendered end on this copy. The SOURCE guard above is what catches that spelling; this
    -- case guards what the user actually sees, and would go red the day the resolver changed or
    -- the accessor stopped answering.
    local NS = T.newAddon()
    local spec = NS.DebugLog:ConsoleCheckbox()
    assertEqual(type(spec.label), "string", "ConsoleCheckbox really returns a label")
    assertEqual(type(spec.tooltip), "string", "and a tooltip")
    -- No English label is SCREAMING_SNAKE_CASE. A resolved string is prose; an unresolved one is
    -- the key.
    assertNil(spec.label:match("^[A-Z][A-Z0-9_]+$"), "label rendered as a raw key: " .. spec.label)
    assertNil(spec.tooltip:match("^[A-Z][A-Z0-9_]+$"),
        "tooltip rendered as a raw key: " .. spec.tooltip)
    -- Non-vacuity: couple it to the library's own value, so the case fails if the accessor ever
    -- stops answering rather than passing on an empty string.
    local _, env = T.newAddon()
    local lib = env.LibStub("LibKa0s-DebugLog-1.0", true)
    assertEqual(spec.label, lib.STRINGS.CHECKBOX_LABEL)
    assertTrue(spec.tooltip:find("/wg debug", 1, true) ~= nil,
        "the tooltip is composed from the descriptor's own slash")
end)

test("debuglog: the gated sink survives a format its arguments cannot satisfy (WG-22)", function()
    -- The library gained this at DebugLog minor 7, driven by this addon: `%d` handed the
    -- stringified sentinel used to raise inside the sink. Pinned here as well as upstream, because
    -- it is the behaviour WhatGroup's own hand-written sink guaranteed and would otherwise have
    -- lost on adoption.
    local NS = T.newAddon()
    NS.State.debug = true
    local ok = pcall(function() NS.Debug("Capture", "n=%d", {}) end)
    assertTrue(ok, "NS.Debug must not propagate a format error")
    local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
    assertTrue(last:find("<secret>", 1, true) ~= nil, "and the value degrades to the sentinel")
end)

-- ---------------------------------------------------------------------------
-- The degraded install — the library genuinely absent
-- ---------------------------------------------------------------------------
--
-- Loaded with the file MISSING, never by hand-stubbing the namespace member under test
-- (testing-§8). Core.lua absent means every other major returns before LibStub:NewLibrary too, so
-- this is the whole-library-missing scenario as well as the Core one.

local NO_LIBKA0S = {
    "libs/LibKa0s/Core.lua", "libs/LibKa0s/DebugLog.lua", "libs/LibKa0s/Slash.lua",
    "libs/LibKa0s/Options.lua", "libs/LibKa0s/OptionsWidgets.lua",
    "libs/LibKa0s/OptionsScroll.lua", "libs/LibKa0s/Perf.lua", "libs/LibKa0s/PerfPanel.lua",
}

test("degraded: the addon loads with LibKa0s absent", function()
    local NS, env = T.newAddon{ skip = NO_LIBKA0S }
    assertNil(env.LibStub("LibKa0s-Core-1.0", true), "the library really is absent")
    assertEqual(type(NS.Print), "function", "the printer still answers")
    assertEqual(type(NS.SafeToString), "function", "the stringifier still answers")
end)

test("degraded: the cause clause is published on BOTH paths", function()
    -- Every later seam appends its own consequence to this one sentence, so it has to exist even
    -- when the library is present.
    local withLib = T.newAddon()
    local withOut = T.newAddon{ skip = NO_LIBKA0S }
    assertEqual(withLib.LIBKA0S_MISSING, withOut.LIBKA0S_MISSING)
    assertTrue(withLib.LIBKA0S_MISSING:find("LibKa0s", 1, true) ~= nil, "it names the library")
    assertTrue(withLib.LIBKA0S_MISSING:find("libs/LibKa0s", 1, true) ~= nil,
        "and where it was expected")
end)

test("degraded: the printer announces the absence exactly ONCE, then prints normally", function()
    local NS, _, mock = T.newAddon{ skip = NO_LIBKA0S }
    NS.Print("first")
    NS.Print("second")
    NS.Print("third")
    local notices = 0
    for _, line in ipairs(mock.prints) do
        if line:find("running on reduced built-in fallbacks", 1, true) then notices = notices + 1 end
    end
    assertEqual(notices, 1, "one notice, not one per line and not none")
    assertTrue(mock.prints[1]:find(NS.LIBKA0S_MISSING, 1, true) ~= nil,
        "the notice carries the shared cause clause verbatim")
    assertTrue(mock.prints[#mock.prints]:find("third", 1, true) ~= nil,
        "and the line the user asked for still lands")
end)

test("degraded: the fallback printer still degrades a secret in place", function()
    local NS, _, mock = T.newAddon{ skip = NO_LIBKA0S }
    NS.Print("value:", {})
    assertTrue(mock.prints[#mock.prints]:find("<secret>", 1, true) ~= nil)
end)

test("degraded: every DebugLog member the addon calls still answers", function()
    -- The stub has to cover the whole surface, not the members that happened to be convenient:
    -- `/wg debug`, the panel's console checkbox and every NS.Debug trace site reach it.
    local NS = T.newAddon{ skip = NO_LIBKA0S }
    for _, member in ipairs({
        "Add", "Debug", "Clear", "Show", "Hide", "Toggle", "IsShown", "IsEnabled",
        "RefreshHeader", "ShowCopy", "UpdateScrollBar", "UpdateStatus", "BufferSize",
        "LastLine", "FindLine", "CopyText", "MakeCloseButton", "SetEnabled", "ConsoleCheckbox",
        "Text",
    }) do
        assertEqual(type(NS.DebugLog[member]), "function", "the stub does not answer " .. member)
    end
    assertEqual(type(NS.DebugLog.buffer), "table", "and the buffer every test reads is present")
    assertEqual(NS.Debug, NS.DebugLog.Debug, "the sink is still bound bare")
end)

test("degraded: the console stub copies NO library formatter", function()
    -- debug-logging-§3: hand-copying the exact colour codes whose seven-way drift the extraction
    -- exists to end is the one duplicate the standard most specifically forbids. The stub must not
    -- carry FormatPlain/FormatColored at all.
    local NS = T.newAddon{ skip = NO_LIBKA0S }
    assertNil(NS.DebugLog.FormatPlain, "the stub must not reimplement the plain formatter")
    assertNil(NS.DebugLog.FormatColored, "nor the coloured one")
    local src = readFile("core/DebugLogSetup.lua")
    assertNil(src:match("6f8faf"), "no console colour code may appear in the seam file")
    assertNil(src:match("c9a66b"), "nor the tag colour")
end)

test("degraded: `/wg debug on` still moves the flag and explains the missing window ONCE", function()
    -- The flag is ours, so it must keep working; the WINDOW is what is lost, and one announce per
    -- entry point is what keeps `/wg debug` from going silent after `/wg debug on` spent the token.
    local NS, _, mock = T.newAddon{ skip = NO_LIBKA0S }
    NS.addon:OnSlashCommand("debug on")
    assertTrue(NS.State.debug, "the session flag still flips")
    NS.addon:OnSlashCommand("debug on")
    NS.addon:OnSlashCommand("debug")
    NS.addon:OnSlashCommand("debug")
    local notices = 0
    for _, line in ipairs(mock.prints) do
        if line:find("debug console window is unavailable", 1, true) then notices = notices + 1 end
    end
    assertEqual(notices, 2, "once for the enable path, once for the window path — never more")
    for _, line in ipairs(mock.prints) do
        if line:find("debug console window is unavailable", 1, true) then
            assertTrue(line:find(NS.LIBKA0S_MISSING, 1, true) ~= nil,
                "and each explains the absence through the shared cause clause")
        end
    end
end)

-- ---------------------------------------------------------------------------
-- The `L` trap — the source guard
-- ---------------------------------------------------------------------------
--
-- A descriptor field is not observable after `lib:New` returns, so the only way to see a locale
-- table handed to one is to read the seam files. The obvious pattern is wrong:
--
--     L = NS.L                     -- the table itself                        OFFENDER
--     L = NS.L or { ... }          -- NS.L is always truthy, so: the table    OFFENDER
--     L = NS.L and { ... } or nil  -- evaluates to the plain table            fine
--
-- so the matcher keys on what the expression EVALUATES TO — flag any `L =` whose value starts with
-- the locale table unless the next token is `and`.

local function offendingL(src)
    for value in src:gmatch("[%s,{]L%s*=%s*([^\r\n]+)") do
        local rest = value:match("^NS%.L%s*(.-)%s*$") or value:match("^L%s*(.-)%s*$")
        if rest and not rest:match("^and%f[%W]") then return value end
    end
    return nil
end

test("libka0s: the L-trap matcher flags the table and the `or` spelling, not the `and` one", function()
    -- A matcher nothing tests can be narrowed back to a single anchored form while still reporting
    -- green, which is exactly how it got there. Drive it against all three spellings.
    assertTrue(offendingL("local d = { L = NS.L }") ~= nil, "the bare table must be flagged")
    assertTrue(offendingL('local d = { L = NS.L or { A = "a" } }') ~= nil,
        "the `or` spelling still evaluates to the locale table")
    assertNil(offendingL('local d = { L = NS.L and { A = "a" } or nil }'),
        "the `and` spelling evaluates to the plain table and is legitimate")
    assertNil(offendingL('local d = { L = { ERR_BOOL = "expected" } }'),
        "a plain literal table is the contract")
end)

test("libka0s: no seam file hands a descriptor this addon's locale table (the L trap)", function()
    for _, path in ipairs(SEAM_FILES) do
        local src = readFile(path)
        if src then
            local bad = offendingL(src)
            assertNil(bad, path .. " hands a descriptor NS.L: " .. tostring(bad))
        end
    end
end)

-- ---------------------------------------------------------------------------
-- The two majors that CANNOT express the trap — library tripwires
-- ---------------------------------------------------------------------------
--
-- Core ships no STRINGS and reads no descriptor `L`; Options ships STRINGS but reads no descriptor
-- `L`. A rendered assertion for either is a case that cannot fail — worse than no case, because it
-- reads as coverage. These two stand in for it, and each goes red the day the module grows one.

test("libka0s: Core has no STRINGS and reads no descriptor L (tripwire)", function()
    local _, env = T.newAddon()
    local core = env.LibStub("LibKa0s-Core-1.0", true)
    assertNil(core.STRINGS, "Core grew a STRINGS table; the L trap now applies to it")
    local src = readFile("libs/LibKa0s/Core.lua")
    assertTrue(src ~= nil, "the vendored Core.lua is readable")
    assertNil(src:match("lib%.STRINGS"), "Core.lua now defines STRINGS")
    assertNil(src:match("d%.L"), "Core.lua now reads a descriptor L")
end)

test("libka0s: Options reads no descriptor L (tripwire)", function()
    -- Options DOES ship a STRINGS table, so the "STRINGS is absent" half does not transfer and
    -- asserting it would fail on a module that is behaving correctly. The source half alone is the
    -- tripwire, and the settings panel is where a raw SCREAMING_SNAKE key is most visible.
    local src = readFile("libs/LibKa0s/Options.lua")
    assertTrue(src ~= nil, "the vendored Options.lua is readable")
    assertNil(src:match("d%.L"), "Options.lua now reads a descriptor L")
    local widgets = readFile("libs/LibKa0s/OptionsWidgets.lua")
    assertTrue(widgets ~= nil, "the vendored OptionsWidgets.lua is readable")
    assertNil(widgets:match("d%.L"), "OptionsWidgets.lua now reads a descriptor L")
end)
