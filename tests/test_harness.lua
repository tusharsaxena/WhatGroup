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
