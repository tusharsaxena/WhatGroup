-- tests/test_harness.lua — the harness's own wiring: the TOC-derived load list, the explicit
-- LibKa0s file list, and the kit revision (testing-§9, testing-§11).
--
-- Both failure modes these cases exist for are SILENT. A suite named in the runner but missing from
-- disk is skipped rather than failed, and a library file omitted from the load list makes the
-- dependent module refuse to register — so the host's setup file falls back to its stub and the
-- suite happily measures the stub, green, testing nothing.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local Loader = dofile("tests/_kit/loader.lua")

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local body = f:read("*a")
    f:close()
    return body
end

test("harness: the runner is on the shared kit and reports its revision", function()
    assertEqual(type(T.KIT_VERSION), "number", "Kit.expose merged KIT_VERSION in")
    assertTrue(T.KIT_VERSION >= 1, "the kit revision is a positive integer")
end)

test("harness: the addon's load list is DERIVED from the TOC, in TOC order (testing-§9)", function()
    -- Compared against a FRESH derivation rather than a hand-written list: a hand-written copy is
    -- the thing this rule exists to remove.
    local fresh = Loader.tocFiles("WhatGroup.toc")
    assertTrue(#fresh > 0, "the TOC yielded files")
    assertEqual(#T.loadAddon.tocFiles, #fresh, "same number of addon files")
    for i, path in ipairs(fresh) do
        assertEqual(T.loadAddon.tocFiles[i], path, "load-list entry " .. i)
    end
end)

test("harness: every derived addon path exists on disk", function()
    for _, path in ipairs(T.loadAddon.tocFiles) do
        assertTrue(readFile(path) ~= nil, "missing source file: " .. path)
    end
end)

test("harness: no libs/ path leaked into the derived addon list", function()
    for _, path in ipairs(T.loadAddon.tocFiles) do
        assertFalse(path:lower():match("^libs/") ~= nil,
            "a vendored library came through tocFiles: " .. path)
    end
end)

test("harness: the explicit LibKa0s list matches LibKa0s.xml, in XML order (anti-patterns #48)", function()
    -- The runner spells the library's files out because tocFiles cannot see through the XML. This
    -- is what stops the list drifting from the payload: a file added to the XML and forgotten here
    -- makes its module refuse to register, and every seam then measures its own fallback stub.
    local xml = readFile("libs/LibKa0s/LibKa0s.xml")
    assertTrue(xml ~= nil, "libs/LibKa0s/LibKa0s.xml is vendored")
    local fromXml = {}
    for file in xml:gmatch('<Script%s+file="([^"]+)"') do
        fromXml[#fromXml + 1] = "libs/LibKa0s/" .. file
    end
    assertEqual(#T.loadAddon.libFiles, #fromXml, "same number of library files")
    for i, path in ipairs(fromXml) do
        assertEqual(T.loadAddon.libFiles[i], path, "library load-list entry " .. i)
    end
end)

test("harness: every LibKa0s file the runner loads exists on disk", function()
    for _, path in ipairs(T.loadAddon.libFiles) do
        assertTrue(readFile(path) ~= nil, "missing vendored library file: " .. path)
    end
end)

test("harness: the libraries load BEFORE the addon's own files", function()
    -- LibKa0s registers through LibStub at file load; an addon seam that ran first would resolve
    -- nil and take its degraded path while the suite stayed green.
    local sources = T.loadAddon.sources
    local sawAddon = false
    for _, src in ipairs(sources) do
        if src.lib then
            assertFalse(sawAddon, "library file after an addon file: " .. src.path)
        else
            sawAddon = true
        end
    end
    assertTrue(sawAddon, "the addon's own files are in the list too")
end)

-- ---------------------------------------------------------------------------
-- The addon object runs on the kit's Ace fakes (WhatGroup#19, kit revision 17)
-- ---------------------------------------------------------------------------
--
-- Until #19 tests/wow_mock.lua replaced the kit's AceAddon with its own: a RegisterEvent that
-- recorded into `mock.addonEvents` without validating, a `fireAddonEvent` that read that table, a
-- timer queue of its own and a no-op Enable/Disable. The kit's fakes follow the real Ace3 source,
-- so these cases pin what the addon object gets from them now that nothing is in between.

test("harness: the addon is a named AceAddon the kit can look up", function()
    local NS, _, mock = T.newAddon()
    assertEqual(tostring(NS.addon), "WhatGroup", "NewAddon was handed the folder name")
    assertEqual(mock.LibStub("AceAddon-3.0"):GetAddon("WhatGroup"), NS.addon)
end)

test("harness: the addon's event registrations reach the kit's dispatcher", function()
    -- red under: a local RegisterEvent that records somewhere M.__fireEvent never reads.
    local NS, _, mock = T.enableAddon()
    assertEqual(NS.addon.__events["PLAYER_REGEN_DISABLED"], "OnCombatStateChanged")
    assertEqual(mock.__fireEvent("PLAYER_REGEN_DISABLED"), 1, "one handler ran")
end)

test("harness: UnregisterAllEvents silences what the dispatcher reaches", function()
    -- The latent gap #19 recorded: the kit's UnregisterAllEvents sat on the addon object beside a
    -- local recorder it could not see, so it cleared one table and left the one suites read.
    local NS, _, mock = T.enableAddon()
    assertEqual(mock.__fireEvent("GROUP_ROSTER_UPDATE"), 1)
    NS.addon:UnregisterAllEvents()
    assertNil(NS.addon.__events["GROUP_ROSTER_UPDATE"])
    assertEqual(mock.__fireEvent("GROUP_ROSTER_UPDATE"), 0, "nothing is left to run")
end)

test("harness: a registration naming a method the addon lacks is refused", function()
    -- The kit's fidelity rule 1: a registration the client refuses must not pass headlessly.
    local NS = T.bootAddon()
    local ok = pcall(NS.addon.RegisterEvent, NS.addon, "PLAYER_LOGIN", "NoSuchHandler")
    assertFalse(ok, "AceEvent raises for a string method self does not carry")
end)

test("harness: the addon's AceTimer handles are the kit's, on the kit's queue", function()
    local NS, _, mock = T.bootAddon()
    local handle = NS.addon:ScheduleTimer(function() end, 2)
    assertEqual(mock.__timers[#mock.__timers].timer, handle, "queued on M.__timers")
    assertEqual(NS.addon:CancelTimer(handle), true, "CancelTimer answers for a live timer")
    assertEqual(mock.__fireTimers(), 0, "a canceled timer does not run")
    assertEqual(#mock.timers, 0, "and the C_Timer.After queue stays separate")
end)

-- ---------------------------------------------------------------------------
-- One retired event name costs only itself (events-frames-taint-§1, WHATGROUP-A-07)
-- ---------------------------------------------------------------------------
--
-- registerFeatureEvents is the first thing OnEnable runs, and it used to make four bare
-- self:RegisterEvent calls. The client raises on a name it does not know, so one event retired by a
-- patch took the settings category, the launcher and the latch down with it. The four calls now go
-- through NS.SafeRegisterEvent (LibKa0s-Core minor 8) and a refused name lands in the session-only
-- NS.RejectedEvents, which the [Init] summary reads.

local NO_LIBKA0S = T.loadAddon.libFiles
local OTHER_THREE = {
    LFG_LIST_APPLICATION_STATUS_UPDATED = true,
    PLAYER_REGEN_DISABLED = "OnCombatStateChanged",
    PLAYER_REGEN_ENABLED  = "OnCombatStateChanged",
}

local function badRoster(extra)
    return function(m)
        m.__badEvents = { GROUP_ROSTER_UPDATE = true }
        if extra then extra(m) end
    end
end

local function assertEnableSurvived(NS, mock)
    for event, handler in pairs(OTHER_THREE) do
        assertTrue(NS.addon.__events[event] ~= nil, event .. " still registered")
        if handler ~= true then assertEqual(NS.addon.__events[event], handler, event .. " handler") end
    end
    assertEqual(#mock.categories, 2, "Settings.Register ran after the refusal")
    assertTrue(NS.Launcher:IsRegistered(), "NS.Launcher:Register ran after the refusal")
    assertFalse(NS.Lifecycle:IsDown(), "the latch was evaluated and stands up")
    assertEqual(#NS.RejectedEvents, 1, "one name refused")
    assertEqual(NS.RejectedEvents[1], "GROUP_ROSTER_UPDATE")
    assertTrue(NS.addon:InitSummary():find("rejected events: GROUP_ROSTER_UPDATE", 1, true) ~= nil,
        "the [Init] summary names the refused event")
end

test("events: one retired event name does not abort OnEnable", function()
    -- red under: a bare self:RegisterEvent in registerFeatureEvents
    local NS, _, mock = T.enableAddon{ mock = badRoster() }
    assertEnableSurvived(NS, mock)
end)

test("events: one retired event name does not abort OnEnable on a client without C_EventUtils", function()
    -- red under: a bare self:RegisterEvent in registerFeatureEvents
    -- No front gate: the library's probe frame and the target's pcall decide.
    local NS, _, mock = T.enableAddon{ mock = badRoster(function(m) m.C_EventUtils = nil end) }
    assertEnableSurvived(NS, mock)
end)

test("events: the [Init] summary carries no rejected clause when every name registered", function()
    local NS = T.enableAddon()
    assertEqual(#NS.RejectedEvents, 0)
    assertTrue(NS.addon:InitSummary():find("rejected", 1, true) == nil, "no clause on a clean enable")
end)

test("degraded: the Core stub's SafeRegisterEvent survives a bad name", function()
    -- red under: a degraded branch in core/CoreSetup.lua that publishes no SafeRegisterEvent
    local NS = T.enableAddon{ skip = NO_LIBKA0S, mock = badRoster() }
    for event in pairs(OTHER_THREE) do
        assertTrue(NS.addon.__events[event] ~= nil, event .. " still registered")
    end
    assertEqual(#NS.RejectedEvents, 1, "one name refused")
    assertEqual(NS.RejectedEvents[1], "GROUP_ROSTER_UPDATE")
end)

test("events: a stand-up after a rejection records the name once", function()
    -- red under: a rejected list the stand-up path appends to on every cycle
    local NS = T.enableAddon{ mock = badRoster() }
    NS.Lifecycle:Set(NS.HOLD_DISABLED, true)
    NS.Lifecycle:Set(NS.HOLD_DISABLED, false)
    assertFalse(NS.Lifecycle:IsDown(), "stood back up")
    assertEqual(#NS.RejectedEvents, 1, "the name is recorded once across the cycle")
    assertEqual(NS.RejectedEvents[1], "GROUP_ROSTER_UPDATE")
end)
