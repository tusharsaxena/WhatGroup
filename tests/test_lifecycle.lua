-- tests/test_lifecycle.lua — the addon shell: OnInitialize / OnEnable wiring,
-- the file-load hooksecurefunc post-hooks, the GROUP_ROSTER_UPDATE state
-- machine, the chat-link handler, and the action slash commands.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function pending(overrides)
    local i = {
        title = "Stonevault Speedrun", leaderName = "Testadin", numMembers = 3,
        voiceChat = "", age = 0, activityIDs = { 2516 }, activityID = 2516,
        fullName = "The Stonevault", activityName = "The Stonevault",
        maxNumPlayers = 5, isMythicPlus = true, isCurrentRaid = false,
        isHeroicRaid = false, categoryID = 1, mapID = 2652,
        generalPlaystyle = 3, playstyleString = "", shortName = "",
    }
    for k, v in pairs(overrides or {}) do i[k] = v end
    return i
end

-- ---------------------------------------------------------------------------
-- Namespace + bootstrap invariants
-- ---------------------------------------------------------------------------

test("lifecycle: the addon exposes no public global (WG-01)", function()
    local NS = T.bootAddon()
    assertNil(rawget(_G, "WhatGroup"), "the addon must stay in its private namespace")
    assertTrue(NS.addon ~= nil, "NS.addon is the only handle")
end)

test("lifecycle: NS IS the addon object (AceAddon mixes into the namespace)", function()
    local NS = T.bootAddon()
    assertEqual(NS.addon, NS, "NS.addon aliases the same table")
end)

test("lifecycle: earlier files' fields survive NewAddon", function()
    local NS = T.bootAddon()
    -- locales, Util, Compat and Database all hang fields on NS BEFORE
    -- AceAddon:NewAddon runs; NewAddon must preserve them.
    for _, field in ipairs({ "L", "Util", "Compat", "Windows", "SafeToString" }) do
        assertTrue(NS[field] ~= nil, "NewAddon dropped NS." .. field)
    end
    assertEqual(type(NS.RunMigrations), "function")
end)

test("lifecycle: the shared chat prefix is the cyan [WG] tag", function()
    local NS = T.bootAddon()
    assertEqual(NS.PREFIX, "|cff00FFFF[WG]|r")
end)

test("lifecycle: NS.Print, WhatGroup._print and NS.Util.print are one seam", function()
    local NS = T.bootAddon()
    assertEqual(NS.Print, NS.Util.print)
    assertEqual(NS.addon._print, NS.Util.print)
end)

test("lifecycle: debug state is session-only and starts off", function()
    local NS = T.bootAddon()
    assertFalse(NS.State.debug)
    assertNil(NS.addon.db.profile.debug, "it is never persisted (WG-12)")
end)

-- ---------------------------------------------------------------------------
-- OnInitialize / OnEnable
-- ---------------------------------------------------------------------------

test("lifecycle: OnInitialize builds the db from the schema defaults", function()
    local NS = T.bootAddon()
    assertTrue(NS.addon.db ~= nil)
    assertEqual(NS.addon.db.profile.enabled, true)
    assertEqual(NS.addon.db.global.schemaVersion, 1)
end)

test("lifecycle: OnInitialize registers both slash verbs", function()
    local _, _, mock = T.bootAddon()
    assertEqual(mock.chatCommands["wg"], "OnSlashCommand")
    assertEqual(mock.chatCommands["whatgroup"], "OnSlashCommand")
end)

test("lifecycle: OnEnable registers the two capture events", function()
    local _, _, mock = T.enableAddon()
    assertTrue(mock.addonEvents["GROUP_ROSTER_UPDATE"])
    assertTrue(mock.addonEvents["LFG_LIST_APPLICATION_STATUS_UPDATED"])
end)

test("lifecycle: no events are registered before OnEnable", function()
    local _, _, mock = T.bootAddon()
    assertNil(mock.addonEvents["GROUP_ROSTER_UPDATE"])
end)

test("lifecycle: OnEnable seeds wasInGroup from the current roster state", function()
    local NS, _, mock = T.bootAddon()
    mock.inGroup = true
    NS.addon:OnEnable()
    NS.addon.pendingInfo = pending()
    -- Already in a group at login → GROUP_ROSTER_UPDATE is not a transition,
    -- so it must not fire a join notify for a group we were already in.
    NS.addon:GROUP_ROSTER_UPDATE()
    assertEqual(#mock.aceTimers, 0)
end)

-- ---------------------------------------------------------------------------
-- File-load post-hooks (installed at load, NOT in OnEnable — taint)
-- ---------------------------------------------------------------------------

test("lifecycle: the ApplyToGroup and SetItemRef hooks install at file load", function()
    local _, _, mock = T.newAddon()
    assertEqual(#(mock.hooks["ApplyToGroup"] or {}), 1)
    assertEqual(#(mock.hooks["SetItemRef"] or {}), 1)
end)

test("lifecycle: the ApplyToGroup hook routes into the capture pipeline", function()
    local NS, _, mock = T.bootAddon()
    mock.searchResults[42] = { name = "Hooked Group", activityIDs = { 500 } }
    mock.activities[500] = { fullName = "Somewhere", mapID = 111 }
    mock.fireHook("ApplyToGroup", 42)
    NS.addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 42, "applied")
    mock.searchResults[42] = nil
    NS.addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 42, "inviteaccepted")
    assertEqual(NS.addon.pendingInfo.title, "Hooked Group")
end)

test("lifecycle: the SetItemRef hook ignores links that aren't ours", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending()
    mock.fireHook("SetItemRef", "item:12345", "[Some Item]", "LeftButton")
    assertNil(mock.frames["WhatGroupFrame"], "another addon's link must not open our popup")
end)

test("lifecycle: the SetItemRef hook ignores a non-string link argument", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending()
    local ok = pcall(function() mock.fireHook("SetItemRef", nil, "", "LeftButton") end)
    assertTrue(ok, "a nil link must not raise inside the hook")
    assertNil(mock.frames["WhatGroupFrame"])
end)

test("lifecycle: clicking the chat link opens the popup", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending()
    mock.fireHook("SetItemRef", "WhatGroup:show", "[Click here]", "LeftButton")
    assertTrue(mock.frames["WhatGroupFrame"] ~= nil)
    assertTrue(mock.frames["WhatGroupFrame"]:IsShown())
end)

test("lifecycle: a stale chat link prints a hint instead of an empty popup", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = nil
    mock.fireHook("SetItemRef", "WhatGroup:show", "[Click here]", "LeftButton")
    assertNil(mock.frames["WhatGroupFrame"], "no 'No data' popup for a dead link")
    assertTrue(mock.prints[#mock.prints]:find("no longer available", 1, true) ~= nil)
end)

-- ---------------------------------------------------------------------------
-- GROUP_ROSTER_UPDATE
-- ---------------------------------------------------------------------------

test("lifecycle: joining a group with a capture waiting fires the notify", function()
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    mock.inGroup = true
    NS.addon:GROUP_ROSTER_UPDATE()
    assertEqual(#mock.aceTimers, 1)
end)

test("lifecycle: a roster tick while already grouped is not a transition", function()
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    mock.inGroup = true
    NS.addon:GROUP_ROSTER_UPDATE()
    mock.fireAceTimers()
    NS.addon:GROUP_ROSTER_UPDATE()
    NS.addon:GROUP_ROSTER_UPDATE()
    assertEqual(#mock.aceTimers, 0, "repeat ticks schedule nothing")
end)

test("lifecycle: leaving the group wipes the capture", function()
    local NS, _, mock = T.enableAddon()
    mock.inGroup = true
    NS.addon:GROUP_ROSTER_UPDATE()
    NS.addon.pendingInfo = pending()
    mock.inGroup = false
    NS.addon:GROUP_ROSTER_UPDATE()
    assertNil(NS.addon.pendingInfo)
end)

test("lifecycle: leaving the group cancels an in-flight notify", function()
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    mock.inGroup = true
    NS.addon:GROUP_ROSTER_UPDATE()
    mock.inGroup = false
    NS.addon:GROUP_ROSTER_UPDATE()
    assertEqual(mock.fireAceTimers(), 0)
end)

test("lifecycle: rejoining after a leave fires a fresh notify", function()
    local NS, _, mock = T.enableAddon()
    mock.inGroup = true
    NS.addon.pendingInfo = pending()
    NS.addon:GROUP_ROSTER_UPDATE()
    mock.fireAceTimers()
    mock.inGroup = false
    NS.addon:GROUP_ROSTER_UPDATE()
    mock.inGroup = true
    NS.addon.pendingInfo = pending({ title = "Next Group" })
    NS.addon:GROUP_ROSTER_UPDATE()
    assertEqual(#mock.aceTimers, 1)
end)

test("lifecycle: the retail ordering (ROSTER before inviteaccepted) still notifies", function()
    local NS, _, mock = T.enableAddon()
    -- On retail GROUP_ROSTER_UPDATE usually lands BEFORE the inviteaccepted
    -- status, i.e. while pendingInfo is still nil — so the transition is missed
    -- and only the inviteaccepted fallback can catch up.
    mock.inGroup = true
    NS.addon:GROUP_ROSTER_UPDATE()
    assertEqual(#mock.aceTimers, 0, "the transition passed with nothing to show")

    mock.searchResults[7] = { name = "Late Group", activityIDs = { 500 } }
    mock.activities[500] = { fullName = "Somewhere", mapID = 111 }
    NS.addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 7, "inviteaccepted")
    assertEqual(#mock.aceTimers, 1, "the inviteaccepted path catches up")
    mock.fireAceTimers()
    assertEqual(NS.addon.pendingInfo.title, "Late Group")
end)

-- ---------------------------------------------------------------------------
-- InitSummary (debug-logging-§5)
-- ---------------------------------------------------------------------------

test("lifecycle: InitSummary reflects live runtime state", function()
    local NS, _, mock = T.bootAddon()
    mock.inGroup = true
    NS.addon.pendingInfo = pending()
    NS.addon.Settings.Helpers.Set("enabled", false)
    local s = NS.addon:InitSummary()
    assertTrue(s:find("enabled=false", 1, true) ~= nil)
    assertTrue(s:find("inGroup=true", 1, true) ~= nil)
end)

test("lifecycle: InitSummary is safe before the db exists", function()
    local NS = T.newAddon()   -- no OnInitialize → no db
    local ok, s = pcall(function() return NS.addon:InitSummary() end)
    assertTrue(ok, "the summary must not raise pre-login")
    assertTrue(s:find("WhatGroup v", 1, true) ~= nil)
end)

-- ---------------------------------------------------------------------------
-- /wg config
-- ---------------------------------------------------------------------------

local function runCmd(NS, name, rest)
    for _, c in ipairs(NS.addon.COMMANDS) do
        -- Positional triples, and the handler takes `rest` ALONE: the library calls
        -- entry[3](rest), never entry[3](self, rest).
        if c[1] == name then return c[3](rest) end
    end
    error("no command: " .. tostring(name))
end

test("lifecycle: /wg config opens the parent settings category", function()
    local NS, _, mock = T.enableAddon()
    runCmd(NS, "config")
    assertEqual(#mock.openedTo, 1)
    assertEqual(mock.openedTo[1], mock.categories[1]:GetID())
end)

test("lifecycle: /wg config is refused during combat (options-ui-§2)", function()
    local NS, _, mock = T.enableAddon()
    mock.combat = true
    runCmd(NS, "config")
    assertEqual(#mock.openedTo, 0, "no defer-and-replay; it simply refuses")
    assertTrue(mock.prints[#mock.prints]:find("combat", 1, true) ~= nil)
end)

test("lifecycle: /wg config registers the panel if login-in-combat skipped it", function()
    local NS, _, mock = T.bootAddon()
    mock.combat = true
    NS.addon:OnEnable()             -- registration bails on the combat guard
    assertEqual(#mock.categories, 0)
    mock.combat = false
    runCmd(NS, "config")
    assertEqual(#mock.categories, 2, "the fallback registration covers it")
    assertEqual(#mock.openedTo, 1)
end)

-- ---------------------------------------------------------------------------
-- /wg test and /wg show
-- ---------------------------------------------------------------------------

test("lifecycle: /wg test injects a synthetic capture and runs the full flow", function()
    local NS, _, mock = T.bootAddon()
    local mark = #mock.prints
    runCmd(NS, "test")
    assertTrue(NS.addon.pendingInfo ~= nil)
    assertEqual(NS.addon.pendingInfo.mapID, 2652)
    assertTrue(#mock.prints > mark, "the chat summary printed")
    assertTrue(mock.frames["WhatGroupFrame"]:IsShown(), "and the popup opened")
end)

test("lifecycle: /wg test bypasses the master switch", function()
    local NS = T.bootAddon()
    NS.addon.Settings.Helpers.Set("enabled", false)
    runCmd(NS, "test")
    assertTrue(NS.addon.pendingInfo ~= nil,
        "a preview must still work with the addon disabled")
end)

test("lifecycle: /wg test fires immediately, without the notify delay", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.Settings.Helpers.Set("notify.delay", 8)
    local mark = #mock.prints
    runCmd(NS, "test")
    assertTrue(#mock.prints > mark, "the preview is synchronous, not scheduled")
    assertEqual(#mock.aceTimers, 0)
end)

test("lifecycle: /wg show opens the popup when a capture exists", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending()
    runCmd(NS, "show")
    assertTrue(mock.frames["WhatGroupFrame"]:IsShown())
end)

test("lifecycle: /wg show with no capture prints a hint and opens nothing", function()
    local NS, _, mock = T.bootAddon()
    runCmd(NS, "show")
    assertNil(mock.frames["WhatGroupFrame"])
    assertTrue(mock.prints[#mock.prints]:find("No group info available", 1, true) ~= nil)
end)

-- ---------------------------------------------------------------------------
-- /wg reset
-- ---------------------------------------------------------------------------

-- `reset` takes a PATH now (convergence #1). The global wipe moved to `resetall`, which kept the
-- confirmation the destructive path has always had — on BOTH entry points, since it and the panel's
-- Defaults button reach one OnAccept body.

test("lifecycle: /wg reset <path> resets one setting, with no confirmation", function()
    local NS, _, mock = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    H.Set("notify.delay", 5)
    H.Set("notify.showLeader", false)
    local before = #mock.popups
    runCmd(NS, "reset", "notify.delay")
    assertEqual(H.Get("notify.delay"), 0, "the named row went back to its default")
    assertEqual(H.Get("notify.showLeader"), false, "and nothing else moved")
    assertEqual(#mock.popups, before, "a one-row reset is not destructive enough to confirm")
end)

test("lifecycle: a bare /wg reset explains the change rather than resetting or erroring", function()
    -- It ships with a deprecation message rather than silently: the old form still PARSES as
    -- something, so "Usage: /wg reset <path>" would tell a user their syntax is wrong rather than
    -- that the verb changed.
    local NS, _, mock = T.bootAddon()
    NS.addon.Settings.Helpers.Set("notify.delay", 5)
    local mark = #mock.prints
    runCmd(NS, "reset")
    assertEqual(NS.addon.Settings.Helpers.Get("notify.delay"), 5, "nothing was reset")
    local said, pointed = false, false
    for i = mark + 1, #mock.prints do
        if mock.prints[i]:find("takes a setting PATH", 1, true) then said = true end
        if mock.prints[i]:find("/wg resetall", 1, true) then pointed = true end
    end
    assertTrue(said, "it says what changed")
    assertTrue(pointed, "and names the replacement for the old behavior")
end)

test("lifecycle: /wg resetall asks for confirmation rather than resetting outright", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.Settings.Helpers.Set("notify.delay", 5)
    runCmd(NS, "resetall")
    assertEqual(mock.popups[#mock.popups], "WHATGROUP_RESET_ALL")
    assertEqual(NS.addon.Settings.Helpers.Get("notify.delay"), 5)
end)

test("lifecycle: /wg resetall and the Defaults button share one OnAccept body", function()
    local NS, env = T.bootAddon()
    NS.addon.Settings.Helpers.Set("notify.delay", 5)
    runCmd(NS, "resetall")
    env.StaticPopupDialogs["WHATGROUP_RESET_ALL"].OnAccept()
    assertEqual(NS.addon.Settings.Helpers.Get("notify.delay"), 0)
end)
