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
