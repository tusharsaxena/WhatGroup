-- tests/test_snapshot.lua — the two read-only snapshot accessors the diagnostics report reads.
--
-- The state the report needs is file-local: the capture tables in core/WhatGroup.lua
-- (capturesByResult, pendingApplications, wasInGroup, notifiedFor) and the popup's locals in
-- modules/Frame.lua (the frame itself, softHidden, pendingHide, gateWithheld, test mode, the
-- combat-end queue, the cooldown ticker). WhatGroup:CaptureSnapshot() and NS.FrameSnapshot() hand
-- out COPIES of it, so a report can never mutate what it is describing, and the frame accessor
-- never builds the popup: building it creates the secure teleport button, which is the one thing a
-- diagnostics dump must not do.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function baseInfo(overrides)
    local i = {
        name = "G", leaderName = "L", numMembers = 3, voiceChat = "",
        generalPlaystyle = 0, playstyleString = "", age = 0,
        activityIDs = { 500 },
    }
    for k, v in pairs(overrides or {}) do i[k] = v end
    return i
end

local function popup(mock) return mock.frames["WhatGroupFrame"] end

-- ---------------------------------------------------------------------------
-- WhatGroup:CaptureSnapshot (core/WhatGroup.lua)
-- ---------------------------------------------------------------------------

test("snapshot: a fresh session reports empty capture tables", function()
    local NS = T.bootAddon()
    local s = NS.addon:CaptureSnapshot()
    assertEqual(next(s.byResult), nil, "no apply yet, so nothing keyed by search result")
    assertEqual(next(s.applications), nil, "and nothing keyed by application")
    assertFalse(s.wasInGroup)
    assertFalse(s.notified)
end)

test("snapshot: an apply shows under byResult, and applied moves it to applications", function()
    -- red under: an accessor that reads one table for both fields.
    local NS, _, mock = T.bootAddon()
    local addon = NS.addon
    mock.searchResults[100] = baseInfo({ name = "Keys", activityIDs = { 500 } })
    mock.activities[500] = { fullName = "Q", mapID = 111 }
    addon:OnApplyToGroup(100)
    local s = addon:CaptureSnapshot()
    assertEqual(s.byResult[100].title, "Keys")
    assertEqual(next(s.applications), nil)

    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "applied")
    s = addon:CaptureSnapshot()
    assertEqual(next(s.byResult), nil, "paired, so no longer waiting on its search result")
    assertEqual(s.applications[100].title, "Keys")
    assertEqual(s.applications[100].mapID, 111)
end)

test("snapshot: the capture copy is deep, so a report cannot mutate a capture", function()
    -- red under: returning the live tables, or copying only the outer level.
    local NS, _, mock = T.bootAddon()
    local addon = NS.addon
    mock.searchResults[100] = baseInfo({ name = "Keys", activityIDs = { 500 } })
    mock.activities[500] = { fullName = "Q", mapID = 111 }
    addon:OnApplyToGroup(100)
    local s = addon:CaptureSnapshot()
    s.byResult[100].title = "Mutated"
    s.byResult[100].activityIDs[1] = 999
    s.byResult[200] = { title = "Injected" }
    local again = addon:CaptureSnapshot()
    assertEqual(again.byResult[100].title, "Keys")
    assertEqual(again.byResult[100].activityIDs[1], 500)
    assertNil(again.byResult[200])
end)

test("snapshot: notified is true only for the pendingInfo notify fired for", function()
    local NS, _, mock = T.bootAddon()
    local addon = NS.addon
    mock.inGroup = true
    addon.pendingInfo = addon:SampleInfo()
    addon:_TryFireJoinNotify("test")
    assertTrue(addon:CaptureSnapshot().notified, "fired for the current capture")
    addon.pendingInfo = addon:SampleInfo()
    assertFalse(addon:CaptureSnapshot().notified, "a replaced capture has not been notified")
end)

-- ---------------------------------------------------------------------------
-- NS.FrameSnapshot (modules/Frame.lua)
-- ---------------------------------------------------------------------------

test("snapshot: the frame accessor reports not built, and never builds the popup", function()
    -- red under: an accessor that calls ShowFrame / buildFrame to read the popup's state.
    local NS, _, mock = T.bootAddon()
    local s = NS.FrameSnapshot()
    assertFalse(s.built)
    assertFalse(s.shown)
    assertFalse(s.onScreen)
    assertNil(s.point)
    assertNil(popup(mock), "the snapshot must not create the popup or its secure button")
end)

test("snapshot: a shown popup reports built, shown, on screen and its live point", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = NS.addon:SampleInfo()
    NS.addon:ShowFrame()
    local s = NS.FrameSnapshot()
    assertTrue(s.built)
    assertTrue(s.shown)
    assertTrue(s.onScreen)
    assertFalse(s.softHidden)
    assertFalse(s.testMode)
    local live = NS.Windows.PointOf(popup(mock))
    assertEqual(s.point.point, live.point)
    assertEqual(s.point.x, live.x)
    assertEqual(s.point.y, live.y)
end)

test("snapshot: a first show in combat reports the queued replay", function()
    local NS, _, mock = T.bootAddon()
    mock.combat = true
    NS.addon.pendingInfo = NS.addon:SampleInfo()
    NS.addon:ShowFrame()
    local s = NS.FrameSnapshot()
    assertFalse(s.built)
    assertEqual(#s.combatQueue, 1)
    assertEqual(s.combatQueue[1], "firstShow")
end)

test("snapshot: a hide in combat reports soft-hidden with a Hide owed", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = NS.addon:SampleInfo()
    NS.addon:ShowFrame()
    mock.combat = true
    NS.addon:ToggleFrame()
    local s = NS.FrameSnapshot()
    assertTrue(s.shown, "still shown, at alpha 0")
    assertFalse(s.onScreen)
    assertTrue(s.softHidden)
    assertTrue(s.pendingHide)
end)

test("snapshot: the frame copy is fresh, so a report cannot edit the queue", function()
    local NS, _, mock = T.bootAddon()
    mock.combat = true
    NS.addon.pendingInfo = NS.addon:SampleInfo()
    NS.addon:ShowFrame()
    local s = NS.FrameSnapshot()
    s.combatQueue[1] = nil
    s.combatQueue[2] = "teleport"
    local again = NS.FrameSnapshot()
    assertEqual(#again.combatQueue, 1)
    assertEqual(again.combatQueue[1], "firstShow")
end)

test("snapshot: every coerced frame flag is a strict boolean, built or not", function()
    -- Pins the `and true or false` coercions before WG-ATS-01 moves them: a nil where the report
    -- expects false would print as a missing field. red under: a flag that leaks the frame or nil.
    local flags = { "built", "shown", "onScreen", "testMode", "teleportDeferred",
                    "cooldownTicking", "escProxyShown" }
    local NS = T.bootAddon()
    local s = NS.FrameSnapshot()
    for _, k in ipairs(flags) do
        assertEqual(type(s[k]), "boolean", "unbuilt " .. k)
        assertFalse(s[k], "unbuilt " .. k)
    end
    NS.addon.pendingInfo = NS.addon:SampleInfo()
    NS.addon:ShowFrame()
    s = NS.FrameSnapshot()
    for _, k in ipairs(flags) do assertEqual(type(s[k]), "boolean", "shown " .. k) end
    assertTrue(s.escProxyShown, "a shown popup shows its Escape proxy")
    assertFalse(s.teleportDeferred)
end)
