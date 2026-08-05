-- tests/test_capture.lua — the fresh-vs-queued mapID-preference merge in
-- LFG_LIST_APPLICATION_STATUS_UPDATED, and the master-switch capture gate.
-- Models the real event dispatch order: apply -> applied -> inviteaccepted.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertNil = T.test, T.assertEqual, T.assertNil

local function baseInfo(overrides)
    local i = {
        name = "G", leaderName = "L", numMembers = 3, voiceChat = "",
        generalPlaystyle = 0, playstyleString = "", age = 0,
        activityIDs = { 500 },
    }
    for k, v in pairs(overrides or {}) do i[k] = v end
    return i
end

test("capture: inviteaccepted prefers FRESH when both have mapID", function()
    local NS, _, mock = T.bootAddon()
    local addon = NS.addon
    mock.searchResults[100] = baseInfo({ name = "Queued", activityIDs = { 500 } })
    mock.activities[500] = { fullName = "Q", mapID = 111 }
    addon:OnApplyToGroup(100)
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "applied")

    mock.searchResults[100] = baseInfo({ name = "Fresh", activityIDs = { 501 } })
    mock.activities[501] = { fullName = "F", mapID = 222 }
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "inviteaccepted")

    assertEqual(addon.pendingInfo.title, "Fresh")
    assertEqual(addon.pendingInfo.mapID, 222)
end)

test("capture: inviteaccepted falls back to QUEUED when fresh lacks mapID", function()
    local NS, _, mock = T.bootAddon()
    local addon = NS.addon
    mock.searchResults[100] = baseInfo({ name = "Queued", activityIDs = { 500 } })
    mock.activities[500] = { fullName = "Q", mapID = 111 }
    addon:OnApplyToGroup(100)
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "applied")

    mock.searchResults[100] = baseInfo({ name = "Fresh", activityIDs = { 502 } })
    mock.activities[502] = { fullName = "F" }  -- no mapID
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "inviteaccepted")

    assertEqual(addon.pendingInfo.title, "Queued")
    assertEqual(addon.pendingInfo.mapID, 111)
end)

test("capture: enabled queues so pendingInfo survives a nil fresh fetch", function()
    local NS, _, mock = T.bootAddon()
    local addon = NS.addon
    mock.searchResults[100] = baseInfo({ name = "Queued", activityIDs = { 500 } })
    mock.activities[500] = { fullName = "Q", mapID = 111 }
    addon:OnApplyToGroup(100)
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "applied")

    mock.searchResults[100] = nil  -- fresh fetch returns nil
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "inviteaccepted")

    assertEqual(addon.pendingInfo.title, "Queued")
    assertEqual(addon.pendingInfo.mapID, 111)
end)

test("capture: master switch off means nothing is queued", function()
    local NS, _, mock = T.bootAddon()
    local addon = NS.addon
    addon.db.profile.enabled = false
    mock.searchResults[100] = baseInfo({ activityIDs = { 500 } })
    mock.activities[500] = { mapID = 111 }
    addon:OnApplyToGroup(100)  -- returns early, nothing enqueued
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "applied")

    mock.searchResults[100] = nil  -- fresh fetch nil -> no data anywhere
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "inviteaccepted")

    assertNil(addon.pendingInfo)
end)

-- WG-R-01: the case above hides the fresh-fetch path by nil'ing the search
-- result before the accept. With the result still live, a disabled addon must
-- STILL capture nothing — the inviteaccepted branch re-fetches straight from
-- the LFG API, so the gate in OnApplyToGroup alone does not cover it.
test("capture: master switch off blocks the inviteaccepted fresh fetch too", function()
    local NS, _, mock = T.bootAddon()
    local addon = NS.addon
    addon.db.profile.enabled = false
    mock.searchResults[100] = baseInfo({ name = "Fresh", activityIDs = { 500 } })
    mock.activities[500] = { fullName = "F", mapID = 111 }

    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "inviteaccepted")

    assertNil(addon.pendingInfo)
end)

-- ---------------------------------------------------------------------------
-- CaptureGroupInfo — field mapping
-- ---------------------------------------------------------------------------

local assertTrue, assertFalse = T.assertTrue, T.assertFalse

test("capture: CaptureGroupInfo maps the search-result fields", function()
    local NS, _, mock = T.bootAddon()
    mock.searchResults[1] = baseInfo({
        name = "Push Group", leaderName = "Tank-Realm", numMembers = 4,
        voiceChat = "Discord", age = 900, playstyleString = "No Leavers",
        generalPlaystyle = 3,
    })
    local c = NS.addon:CaptureGroupInfo(1)
    assertEqual(c.title, "Push Group")
    assertEqual(c.leaderName, "Tank-Realm")
    assertEqual(c.numMembers, 4)
    assertEqual(c.voiceChat, "Discord")
    assertEqual(c.age, 900)
    assertEqual(c.playstyleString, "No Leavers")
    assertEqual(c.generalPlaystyle, 3)
end)

test("capture: CaptureGroupInfo maps the activity fields", function()
    local NS, _, mock = T.bootAddon()
    mock.searchResults[1] = baseInfo({ activityIDs = { 500 } })
    mock.activities[500] = {
        fullName = "Dungeons > Mythic+ > The Stonevault",
        activityName = "The Stonevault", shortName = "M+",
        maxNumPlayers = 5, isMythicPlusActivity = true,
        categoryID = 1, mapID = 2652,
    }
    local c = NS.addon:CaptureGroupInfo(1)
    assertEqual(c.activityID, 500)
    assertEqual(c.fullName, "Dungeons > Mythic+ > The Stonevault")
    assertEqual(c.activityName, "The Stonevault")
    assertEqual(c.shortName, "M+")
    assertEqual(c.maxNumPlayers, 5)
    assertEqual(c.categoryID, 1)
    assertEqual(c.mapID, 2652)
    assertTrue(c.isMythicPlus)
end)

test("capture: CaptureGroupInfo returns nil when the search result is gone", function()
    local NS = T.bootAddon()
    assertNil(NS.addon:CaptureGroupInfo(4242))
end)

test("capture: missing search-result fields fall back to safe defaults", function()
    local NS, _, mock = T.bootAddon()
    mock.searchResults[1] = {}   -- an API that returned an all-but-empty table
    local c = NS.addon:CaptureGroupInfo(1)
    assertEqual(c.title, "Unknown")
    assertEqual(c.leaderName, "Unknown")
    assertEqual(c.numMembers, 0)
    assertEqual(c.voiceChat, "")
    assertEqual(c.age, 0)
    assertEqual(c.generalPlaystyle, 0)
    assertEqual(c.playstyleString, "")
    assertEqual(type(c.activityIDs), "table")
end)

test("capture: an unknown activity leaves the activity fields at their defaults", function()
    local NS, _, mock = T.bootAddon()
    mock.searchResults[1] = baseInfo({ activityIDs = { 777 } })   -- not in mock.activities
    local c = NS.addon:CaptureGroupInfo(1)
    assertEqual(c.activityID, 777, "the ID is still recorded")
    assertEqual(c.fullName, "")
    assertEqual(c.maxNumPlayers, 0)
    assertNil(c.mapID)
    assertFalse(c.isMythicPlus)
end)

test("capture: no activityIDs at all leaves activityID nil", function()
    local NS, _, mock = T.bootAddon()
    mock.searchResults[1] = baseInfo({ activityIDs = {} })
    local c = NS.addon:CaptureGroupInfo(1)
    assertNil(c.activityID)
    assertNil(c.mapID)
end)

test("capture: fullName falls back to the activity name", function()
    local NS, _, mock = T.bootAddon()
    mock.searchResults[1] = baseInfo({ activityIDs = { 500 } })
    mock.activities[500] = { activityName = "The Stonevault" }   -- no fullName
    assertEqual(NS.addon:CaptureGroupInfo(1).fullName, "The Stonevault")
end)

test("capture: the legacy `playstyle` field is used when generalPlaystyle is absent", function()
    local NS, _, mock = T.bootAddon()
    mock.searchResults[1] = { name = "G", playstyle = 4, activityIDs = {} }
    local c = NS.addon:CaptureGroupInfo(1)
    assertEqual(c.generalPlaystyle, 4)
    assertEqual(c.playstyle, 4, "both aliases carry the same value")
end)

test("capture: the raid flags are carried through", function()
    local NS, _, mock = T.bootAddon()
    mock.searchResults[1] = baseInfo({ activityIDs = { 500 } })
    mock.activities[500] = { isCurrentRaidActivity = true, isHeroicRaidActivity = true }
    local c = NS.addon:CaptureGroupInfo(1)
    assertTrue(c.isCurrentRaid)
    assertTrue(c.isHeroicRaid)
end)

-- ---------------------------------------------------------------------------
-- The apply → applied → inviteaccepted queue
-- ---------------------------------------------------------------------------

test("capture: applications are matched to captures in FIFO order", function()
    local NS, _, mock = T.bootAddon()
    local addon = NS.addon
    mock.searchResults[10] = baseInfo({ name = "First", activityIDs = { 500 } })
    mock.activities[500] = { mapID = 111 }
    addon:OnApplyToGroup(10)
    mock.searchResults[20] = baseInfo({ name = "Second", activityIDs = { 501 } })
    mock.activities[501] = { mapID = 222 }
    addon:OnApplyToGroup(20)

    -- The first "applied" claims the first capture, the second the second.
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 10, "applied")
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 20, "applied")
    mock.searchResults[20] = nil    -- force the queued capture to be used
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 20, "inviteaccepted")
    assertEqual(addon.pendingInfo.title, "Second")
end)

test("capture: an 'invited' status changes nothing — it waits for the accept", function()
    local NS, _, mock = T.bootAddon()
    local addon = NS.addon
    mock.searchResults[10] = baseInfo({ activityIDs = { 500 } })
    mock.activities[500] = { mapID = 111 }
    addon:OnApplyToGroup(10)
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 10, "applied")
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 10, "invited")
    assertNil(addon.pendingInfo, "nothing is committed until the invite is accepted")
end)

test("capture: an unrecognized status is ignored", function()
    local NS, _, mock = T.bootAddon()
    local addon = NS.addon
    mock.searchResults[10] = baseInfo({ activityIDs = { 500 } })
    addon:OnApplyToGroup(10)
    local ok = pcall(function()
        addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 10, "declined")
    end)
    assertTrue(ok)
    assertNil(addon.pendingInfo)
end)

test("capture: accepting clears the queue so a stale apply can't resurface", function()
    local NS, _, mock = T.bootAddon()
    local addon = NS.addon
    mock.searchResults[10] = baseInfo({ name = "Stale", activityIDs = { 500 } })
    mock.activities[500] = { mapID = 111 }
    addon:OnApplyToGroup(10)         -- queued but never "applied"
    mock.searchResults[20] = baseInfo({ name = "Accepted", activityIDs = { 501 } })
    mock.activities[501] = { mapID = 222 }
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 20, "inviteaccepted")
    assertEqual(addon.pendingInfo.title, "Accepted")

    -- The stale capture must be gone, not waiting to be matched to the next appID.
    mock.searchResults[30] = nil
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 30, "applied")
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 30, "inviteaccepted")
    assertNil(addon.pendingInfo)
end)

test("capture: 'applied' with nothing queued is a harmless no-op", function()
    local NS = T.bootAddon()
    local ok = pcall(function()
        NS.addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 99, "applied")
    end)
    assertTrue(ok)
end)

test("capture: accepting with no data anywhere leaves pendingInfo nil", function()
    local NS = T.bootAddon()
    NS.addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 99, "inviteaccepted")
    assertNil(NS.addon.pendingInfo)
end)

test("capture: re-enabling the master switch resumes capturing", function()
    local NS, _, mock = T.bootAddon()
    local addon = NS.addon
    addon.Settings.Helpers.Set("enabled", false)
    mock.searchResults[10] = baseInfo({ activityIDs = { 500 } })
    mock.activities[500] = { mapID = 111 }
    addon:OnApplyToGroup(10)
    addon.Settings.Helpers.Set("enabled", true)
    addon:OnApplyToGroup(10)
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 10, "applied")
    mock.searchResults[10] = nil
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 10, "inviteaccepted")
    assertTrue(addon.pendingInfo ~= nil, "captures flow again once re-enabled")
end)

-- ---------------------------------------------------------------------------
-- F-004: appID -> searchResultID via C_LFGList.GetApplicationInfo
-- ---------------------------------------------------------------------------

test("capture: inviteaccepted resolves the searchResultID via GetApplicationInfo", function()
    local NS, _, mock = T.bootAddon()
    local addon = NS.addon
    -- appID 100 was made against search result 900 — the two differ, which is
    -- exactly what the old appID-as-searchResultID shortcut could not express.
    mock.applications[100] = 900
    mock.searchResults[900] = baseInfo({ name = "Resolved", activityIDs = { 501 } })
    mock.activities[501] = { fullName = "R", mapID = 222 }

    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "inviteaccepted")

    assertEqual(addon.pendingInfo.title, "Resolved")
    assertEqual(addon.pendingInfo.mapID, 222)
end)

test("capture: GetApplicationInfo may return a table; the id is read off it", function()
    local NS, env, mock = T.bootAddon()
    local addon = NS.addon
    env.C_LFGList.GetApplicationInfo = function() return { searchResultID = 901 } end
    mock.searchResults[901] = baseInfo({ name = "TableShape", activityIDs = { 501 } })
    mock.activities[501] = { fullName = "T", mapID = 333 }

    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "inviteaccepted")

    assertEqual(addon.pendingInfo.title, "TableShape")
    assertEqual(addon.pendingInfo.mapID, 333)
end)

test("capture: an unmapped application falls back to treating appID as the id", function()
    local NS, _, mock = T.bootAddon()
    local addon = NS.addon
    -- mock.applications left empty -> GetApplicationInfo yields nothing.
    mock.searchResults[100] = baseInfo({ name = "Fallback", activityIDs = { 501 } })
    mock.activities[501] = { fullName = "F", mapID = 444 }

    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "inviteaccepted")

    assertEqual(addon.pendingInfo.title, "Fallback")
    assertEqual(addon.pendingInfo.mapID, 444)
end)

test("capture: a missing GetApplicationInfo degrades to the appID path", function()
    local NS, env, mock = T.bootAddon()
    local addon = NS.addon
    env.C_LFGList.GetApplicationInfo = nil
    mock.searchResults[100] = baseInfo({ name = "Degraded", activityIDs = { 501 } })
    mock.activities[501] = { fullName = "D", mapID = 555 }

    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "inviteaccepted")

    assertEqual(addon.pendingInfo.title, "Degraded")
    assertEqual(addon.pendingInfo.mapID, 555)
end)

test("capture: a raising GetApplicationInfo is caught and falls back", function()
    local NS, env, mock = T.bootAddon()
    local addon = NS.addon
    env.C_LFGList.GetApplicationInfo = function() error("forbidden") end
    mock.searchResults[100] = baseInfo({ name = "Raised", activityIDs = { 501 } })
    mock.activities[501] = { fullName = "X", mapID = 666 }

    local ok = pcall(function()
        addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "inviteaccepted")
    end)

    assertTrue(ok, "the raise is contained inside CaptureGroupInfoFromApplication")
    assertEqual(addon.pendingInfo.title, "Raised")
    assertEqual(addon.pendingInfo.mapID, 666)
end)

-- ---------------------------------------------------------------------------
-- Behavior pin (CCN split): the defaults are `or`, not `== nil`
-- ---------------------------------------------------------------------------
--
-- Every default in buildCapture/applyActivityInfo is an `or` chain, which means a source field
-- holding `false` is REPLACED by the default, not stored. `if src == nil then src = default end`
-- looks equivalent and is not: it would store the `false`. That matters downstream —
-- Labels.GetGroupTypeLabel compares categoryID/maxNumPlayers numerically and ShowNotification
-- tests `shortName ~= ""`, so a boolean reaching either degrades the output with no error.
--
-- Note the reason it is `false` and not `0` being tested: 0 and "" are TRUTHY in Lua, so
-- `(0 or 99)` is 0 and an `or` chain never swallows a stored zero. `false` and `nil` are the
-- only values an `or` default replaces, and `false` is the only one of those two that
-- distinguishes the two spellings.

test("capture: a search field holding false takes the default, not the false", function()
    local NS, _, mock = T.bootAddon()
    mock.searchResults[1] = {
        name = false, leaderName = false, numMembers = false, voiceChat = false,
        playstyleString = false, age = false, generalPlaystyle = false,
        playstyle = false, activityIDs = { },
    }
    local c = NS.addon:CaptureGroupInfo(1)
    assertEqual(c.title, "Unknown")
    assertEqual(c.leaderName, "Unknown")
    assertEqual(c.numMembers, 0)
    assertEqual(c.voiceChat, "")
    assertEqual(c.playstyleString, "")
    assertEqual(c.age, 0)
    assertEqual(c.generalPlaystyle, 0)
    assertEqual(c.playstyle, 0)
end)

test("capture: an activity field holding false takes the default, not the false", function()
    local NS, _, mock = T.bootAddon()
    mock.searchResults[1] = baseInfo({ activityIDs = { 500 } })
    mock.activities[500] = {
        fullName = false, activityName = false, shortName = false,
        maxNumPlayers = false, categoryID = false,
        isMythicPlusActivity = false, isCurrentRaidActivity = false,
        isHeroicRaidActivity = false,
    }
    local c = NS.addon:CaptureGroupInfo(1)
    assertEqual(c.fullName, "")
    assertEqual(c.activityName, "")
    assertEqual(c.shortName, "")
    assertEqual(c.maxNumPlayers, 0)
    assertEqual(c.categoryID, 0)
    assertFalse(c.isMythicPlus)
    assertFalse(c.isCurrentRaid)
    assertFalse(c.isHeroicRaid)
end)

test("capture: a stored zero survives the defaults, because 0 is truthy in Lua", function()
    local NS, _, mock = T.bootAddon()
    mock.searchResults[1] = baseInfo({ numMembers = 0, age = 0, activityIDs = { 500 } })
    mock.activities[500] = { maxNumPlayers = 0, categoryID = 0 }
    local c = NS.addon:CaptureGroupInfo(1)
    assertEqual(c.numMembers, 0)
    assertEqual(c.age, 0)
    assertEqual(c.maxNumPlayers, 0)
    assertEqual(c.categoryID, 0)
end)
