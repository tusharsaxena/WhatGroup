-- tests/test_notify.lua — the delayed join-notify pipeline
-- (WhatGroup:_TryFireJoinNotify / WipeCapture) and the chat summary
-- ShowNotification renders from it.
--
-- This whole surface was previously invisible to the harness: the AceTimer
-- mock was a no-op, so the delay, the supersede check and CancelTimer all
-- did nothing observable and a broken debounce passed. `mock.fireAceTimers()`
-- now advances the timer queue and returns how many callbacks actually ran,
-- which is what makes "the canceled notify did NOT fire" an assertion rather
-- than an assumption.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

-- A capture shaped like the ones CaptureGroupInfo produces.
local function pending(overrides)
    local i = {
        title            = "Stonevault Speedrun",
        leaderName       = "Testadin-Silvermoon",
        numMembers       = 3,
        voiceChat        = "",
        age              = 0,
        activityIDs      = { 2516 },
        activityID       = 2516,
        fullName         = "Dungeons > Mythic+ > The Stonevault",
        activityName     = "The Stonevault",
        maxNumPlayers    = 5,
        isMythicPlus     = true,
        isCurrentRaid    = false,
        isHeroicRaid     = false,
        categoryID       = 1,
        mapID            = 2652,
        generalPlaystyle = 3,
        playstyleString  = "",
        shortName        = "",
    }
    for k, v in pairs(overrides or {}) do i[k] = v end
    return i
end

-- Every chat line printed since `mark`, joined — handy for "did the summary
-- include an Instance row" style assertions.
local function linesSince(mock, mark)
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

-- ---------------------------------------------------------------------------
-- _TryFireJoinNotify — scheduling gates
-- ---------------------------------------------------------------------------

test("notify: no pendingInfo schedules no timer", function()
    local NS, _, mock = T.bootAddon()
    mock.inGroup = true
    NS.addon:_TryFireJoinNotify("test")
    assertEqual(#mock.aceTimers, 0)
end)

test("notify: out of a group schedules no timer even with pendingInfo", function()
    local NS, _, mock = T.bootAddon()
    mock.inGroup = false
    NS.addon.pendingInfo = pending()
    NS.addon:_TryFireJoinNotify("test")
    assertEqual(#mock.aceTimers, 0)
end)

test("notify: in a group with pendingInfo schedules exactly one timer", function()
    local NS, _, mock = T.bootAddon()
    mock.inGroup = true
    NS.addon.pendingInfo = pending()
    NS.addon:_TryFireJoinNotify("test")
    assertEqual(#mock.aceTimers, 1)
    assertTrue(NS.addon.notifyTimer ~= nil, "the handle is stashed for cancellation")
end)

test("notify: the scheduled delay comes from notify.delay", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.Settings.Helpers.Set("notify.delay", 4.5)
    mock.inGroup = true
    NS.addon.pendingInfo = pending()
    NS.addon:_TryFireJoinNotify("test")
    assertEqual(mock.aceTimers[1].delay, 4.5)
end)

test("notify: firing the timer prints the summary and clears the handle", function()
    local NS, _, mock = T.bootAddon()
    mock.inGroup = true
    NS.addon.pendingInfo = pending()
    local mark = #mock.prints
    NS.addon:_TryFireJoinNotify("test")
    assertEqual(#mock.prints, mark, "nothing is printed until the timer fires")
    assertEqual(mock.fireAceTimers(), 1)
    assertTrue(anyLine(linesSince(mock, mark), "You have joined a group!"),
        "the summary lands once the delay elapses")
    assertNil(NS.addon.notifyTimer, "the handle is released inside the callback")
end)

-- ---------------------------------------------------------------------------
-- Double-fire protection (notifiedFor) — the reason both the ROSTER and the
-- inviteaccepted path can call this without printing the summary twice.
-- ---------------------------------------------------------------------------

test("notify: a second call for the SAME pendingInfo schedules nothing more", function()
    local NS, _, mock = T.bootAddon()
    mock.inGroup = true
    NS.addon.pendingInfo = pending()
    NS.addon:_TryFireJoinNotify("ROSTER transition")
    NS.addon:_TryFireJoinNotify("inviteaccepted")
    assertEqual(#mock.aceTimers, 1, "notifiedFor gates the duplicate")
end)

test("notify: both event paths together fire the summary exactly once", function()
    local NS, _, mock = T.bootAddon()
    mock.inGroup = true
    NS.addon.pendingInfo = pending()
    local mark = #mock.prints
    NS.addon:_TryFireJoinNotify("ROSTER transition")
    NS.addon:_TryFireJoinNotify("inviteaccepted")
    assertEqual(mock.fireAceTimers(), 1)
    local joined = 0
    for _, l in ipairs(linesSince(mock, mark)) do
        if l:find("You have joined a group!", 1, true) then joined = joined + 1 end
    end
    assertEqual(joined, 1, "exactly one join summary across both paths")
end)

test("notify: a NEW pendingInfo is eligible to fire again", function()
    local NS, _, mock = T.bootAddon()
    mock.inGroup = true
    NS.addon.pendingInfo = pending()
    NS.addon:_TryFireJoinNotify("first")
    mock.fireAceTimers()
    NS.addon.pendingInfo = pending({ title = "Second Group" })
    NS.addon:_TryFireJoinNotify("second")
    assertEqual(#mock.aceTimers, 1, "a different capture identity re-arms")
end)

-- ---------------------------------------------------------------------------
-- Supersede + cancellation
-- ---------------------------------------------------------------------------

test("notify: a re-fire cancels the in-flight timer so two can't race", function()
    local NS, _, mock = T.bootAddon()
    mock.inGroup = true
    NS.addon.pendingInfo = pending()
    NS.addon:_TryFireJoinNotify("first")
    local firstHandle = mock.aceTimers[1]
    -- A fresh capture arrives before the first delay elapsed.
    NS.addon.pendingInfo = pending({ title = "Replacement" })
    NS.addon:_TryFireJoinNotify("second")
    assertTrue(firstHandle.canceled, "the superseded timer is canceled, not left running")
    assertEqual(mock.fireAceTimers(), 1, "only the surviving timer fires")
end)

test("notify: a callback whose pendingInfo was replaced mid-flight prints nothing", function()
    local NS, _, mock = T.bootAddon()
    mock.inGroup = true
    NS.addon.pendingInfo = pending()
    NS.addon:_TryFireJoinNotify("test")
    -- Swap the capture WITHOUT going through _TryFireJoinNotify (i.e. the
    -- timer handle is still live), so only the in-callback identity check can
    -- catch it. This is the guard that stops a stale group's summary printing.
    NS.addon.pendingInfo = pending({ title = "Different Group" })
    local mark = #mock.prints
    mock.fireAceTimers()
    assertFalse(anyLine(linesSince(mock, mark), "You have joined a group!"),
        "the superseded callback bails on the identity check")
end)

test("notify: WipeCapture cancels an in-flight notify so it never fires", function()
    local NS, _, mock = T.bootAddon()
    mock.inGroup = true
    NS.addon.pendingInfo = pending()
    NS.addon:_TryFireJoinNotify("test")
    local mark = #mock.prints
    NS.addon:WipeCapture()
    assertEqual(mock.fireAceTimers(), 0, "the canceled handle is skipped entirely")
    assertFalse(anyLine(linesSince(mock, mark), "You have joined a group!"))
    assertNil(NS.addon.notifyTimer)
end)

test("notify: WipeCapture clears pendingInfo", function()
    local NS = T.bootAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:WipeCapture()
    assertNil(NS.addon.pendingInfo)
end)

test("notify: WipeCapture re-arms a later capture (notifiedFor is cleared)", function()
    local NS, _, mock = T.bootAddon()
    mock.inGroup = true
    NS.addon.pendingInfo = pending()
    NS.addon:_TryFireJoinNotify("first")
    mock.fireAceTimers()
    NS.addon:WipeCapture()
    NS.addon.pendingInfo = pending()
    NS.addon:_TryFireJoinNotify("second")
    assertEqual(#mock.aceTimers, 1)
end)

test("notify: the master-switch off-flip wipes an in-flight capture (Schema onChange)", function()
    local NS, _, mock = T.bootAddon()
    mock.inGroup = true
    NS.addon.pendingInfo = pending()
    NS.addon:_TryFireJoinNotify("test")
    NS.addon.Settings.Helpers.Set("enabled", false)
    assertNil(NS.addon.pendingInfo, "disabling drops the capture")
    assertEqual(mock.fireAceTimers(), 0, "and cancels its scheduled notify")
end)

-- ---------------------------------------------------------------------------
-- autoShow — the popup half of the callback
-- ---------------------------------------------------------------------------

test("notify: autoShow on opens the popup when the timer fires", function()
    local NS, _, mock = T.bootAddon()
    mock.inGroup = true
    NS.addon.pendingInfo = pending()
    NS.addon:_TryFireJoinNotify("test")
    mock.fireAceTimers()
    assertTrue(mock.frames["WhatGroupFrame"] ~= nil, "the popup was built")
    assertTrue(mock.frames["WhatGroupFrame"]:IsShown(), "and shown")
end)

test("notify: autoShow off prints the summary but never builds the popup", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.Settings.Helpers.Set("frame.autoShow", false)
    mock.inGroup = true
    NS.addon.pendingInfo = pending()
    local mark = #mock.prints
    NS.addon:_TryFireJoinNotify("test")
    mock.fireAceTimers()
    assertTrue(anyLine(linesSince(mock, mark), "You have joined a group!"),
        "chat summary still prints")
    assertNil(mock.frames["WhatGroupFrame"], "no popup is created")
end)

test("notify: autoShow is read at SCHEDULE time, not at fire time", function()
    local NS, _, mock = T.bootAddon()
    mock.inGroup = true
    NS.addon.pendingInfo = pending()
    NS.addon:_TryFireJoinNotify("test")
    -- Flipping the setting after the timer is armed must not retroactively
    -- change the queued behavior — the value was captured as an upvalue.
    NS.addon.Settings.Helpers.Set("frame.autoShow", false)
    mock.fireAceTimers()
    assertTrue(mock.frames["WhatGroupFrame"] ~= nil,
        "the popup still opens; autoShow was captured when the timer was armed")
end)

-- ---------------------------------------------------------------------------
-- ShowNotification — per-row gating from db.profile.notify
-- ---------------------------------------------------------------------------

test("notify: notify.enabled off prints nothing at all", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.Settings.Helpers.Set("notify.enabled", false)
    NS.addon.pendingInfo = pending()
    local mark = #mock.prints
    NS.addon:ShowNotification()
    assertEqual(#mock.prints, mark)
end)

test("notify: no pendingInfo prints nothing", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = nil
    local mark = #mock.prints
    NS.addon:ShowNotification()
    assertEqual(#mock.prints, mark)
end)

test("notify: the default summary carries every row", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending()
    local mark = #mock.prints
    NS.addon:ShowNotification()
    local lines = linesSince(mock, mark)
    for _, frag in ipairs({ "You have joined a group!", "Group:", "Instance:",
                            "Type:", "Leader:", "Playstyle:", "Teleport:",
                            "[Click here to view details]" }) do
        assertTrue(anyLine(lines, frag), "summary carries " .. frag)
    end
end)

test("notify: the Group row always prints, even with every toggle off", function()
    local NS, _, mock = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    for _, path in ipairs({ "notify.showInstance", "notify.showType",
                            "notify.showLeader", "notify.showPlaystyle",
                            "notify.showTeleport", "notify.showClickLink" }) do
        H.Set(path, false)
    end
    NS.addon.pendingInfo = pending()
    local mark = #mock.prints
    NS.addon:ShowNotification()
    local lines = linesSince(mock, mark)
    assertTrue(anyLine(lines, "Group:"), "the group title is not gated")
    assertEqual(#lines, 2, "only the header and the Group row remain")
end)

-- One case per toggle: flipping it off removes exactly that row.
local ROWS = {
    { path = "notify.showInstance",  frag = "Instance:" },
    { path = "notify.showType",      frag = "Type:" },
    { path = "notify.showLeader",    frag = "Leader:" },
    { path = "notify.showPlaystyle", frag = "Playstyle:" },
    { path = "notify.showTeleport",  frag = "Teleport:" },
    { path = "notify.showClickLink", frag = "[Click here to view details]" },
}

for _, row in ipairs(ROWS) do
    test("notify: " .. row.path .. " off drops the " .. row.frag .. " row", function()
        local NS, _, mock = T.bootAddon()
        NS.addon.Settings.Helpers.Set(row.path, false)
        NS.addon.pendingInfo = pending()
        local mark = #mock.prints
        NS.addon:ShowNotification()
        assertFalse(anyLine(linesSince(mock, mark), row.frag))
    end)

    test("notify: " .. row.path .. " on keeps the " .. row.frag .. " row", function()
        local NS, _, mock = T.bootAddon()
        NS.addon.Settings.Helpers.Set(row.path, true)
        NS.addon.pendingInfo = pending()
        local mark = #mock.prints
        NS.addon:ShowNotification()
        assertTrue(anyLine(linesSince(mock, mark), row.frag))
    end)
end

-- ---------------------------------------------------------------------------
-- ShowNotification — row CONTENT
-- ---------------------------------------------------------------------------

test("notify: the Instance row falls back to Unknown when fullName is empty", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending({ fullName = "" })
    local mark = #mock.prints
    NS.addon:ShowNotification()
    assertTrue(anyLine(linesSince(mock, mark), "Unknown"))
end)

test("notify: the Type row prefers shortName over the derived label", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending({ shortName = "M+" })
    local mark = #mock.prints
    NS.addon:ShowNotification()
    assertTrue(anyLine(linesSince(mock, mark), "M+"))
end)

test("notify: the Type row derives the label when shortName is empty", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending({ shortName = "", isMythicPlus = true })
    local mark = #mock.prints
    NS.addon:ShowNotification()
    assertTrue(anyLine(linesSince(mock, mark), "Mythic+"))
end)

test("notify: the Playstyle row is skipped when the label resolves empty", function()
    local NS, _, mock = T.bootAddon()
    -- playstyleString empty AND generalPlaystyle = None (0) → no label at all,
    -- so the row must be omitted rather than printed blank.
    NS.addon.pendingInfo = pending({ playstyleString = "", generalPlaystyle = 0 })
    local mark = #mock.prints
    NS.addon:ShowNotification()
    assertFalse(anyLine(linesSince(mock, mark), "Playstyle:"))
end)

test("notify: the Teleport row is skipped when the map has no teleport spell", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending({ mapID = 999999, activityID = 888888 })
    local mark = #mock.prints
    NS.addon:ShowNotification()
    assertFalse(anyLine(linesSince(mock, mark), "Teleport:"))
end)

test("notify: an unlearned teleport is tagged '(not learned)'", function()
    local NS, _, mock = T.bootAddon()
    NS.TeleportSpells[770001] = 424242    -- never marked known in the mock
    NS.addon.pendingInfo = pending({ mapID = 770001 })
    local mark = #mock.prints
    NS.addon:ShowNotification()
    assertTrue(anyLine(linesSince(mock, mark), "(not learned)"))
end)

test("notify: a learned teleport carries no '(not learned)' tag", function()
    local NS, _, mock = T.bootAddon()
    NS.TeleportSpells[770002] = 424243
    mock.knownSpells[424243] = true
    NS.addon.pendingInfo = pending({ mapID = 770002 })
    local mark = #mock.prints
    NS.addon:ShowNotification()
    local lines = linesSince(mock, mark)
    assertTrue(anyLine(lines, "Teleport:"))
    assertFalse(anyLine(lines, "(not learned)"))
end)

test("notify: every summary line carries the shared [WG] prefix", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending()
    local mark = #mock.prints
    NS.addon:ShowNotification()
    for _, line in ipairs(linesSince(mock, mark)) do
        assertTrue(line:find(NS.PREFIX, 1, true) ~= nil,
            "line must carry the prefix: " .. line)
    end
end)

test("notify: a secret-like title degrades in place instead of raising", function()
    local NS, _, mock = T.bootAddon()
    -- A table stands in for a combat-protected value: it raises in any naive
    -- `..`/format path, so this proves the summary routes through SafeToString.
    NS.addon.pendingInfo = pending({ title = {} })
    local mark = #mock.prints
    local ok = pcall(function() NS.addon:ShowNotification() end)
    assertTrue(ok, "the notify path must not propagate a concat error")
    assertTrue(anyLine(linesSince(mock, mark), "<secret>"))
end)

-- Behavior pin (CCN split): the Leader row has NO nil guard and never had one. When
-- pendingInfo.leaderName is nil the row still prints, with the value degraded by the
-- NS.SafeToString seam rather than the row being dropped. A refactor that gives every
-- notification row a uniform "value is nil, emit nothing" gate silently deletes this line —
-- an absent row and a row reading "nil" are different chat output.
test("notify: the Leader row still prints when leaderName is nil", function()
    local NS, _, mock = T.bootAddon()
    local info = pending()
    info.leaderName = nil
    NS.addon.pendingInfo = info
    local mark = #mock.prints
    NS.addon:ShowNotification()
    assertTrue(anyLine(linesSince(mock, mark), "Leader:"),
        "the Leader row is emitted even with no leader name to put in it")
end)

-- The counterpart: Playstyle and Teleport DO suppress their own row, and that asymmetry is the
-- reason the nil gate has to be opt-in rather than blanket.
test("notify: Playstyle and Teleport drop their rows while Leader keeps its own", function()
    local NS, _, mock = T.bootAddon()
    -- generalPlaystyle 0 with an empty playstyleString => GetPlaystyleLabel is "".
    local info = pending({ generalPlaystyle = 0, playstyleString = "" })
    -- Cleared after the fact, not through the overrides table: `{ mapID = nil }` sets no key at
    -- all in Lua, so pending()'s pairs() merge would never see it and the fixture's real mapID
    -- would survive. With neither key, GetTeleportSpell has nothing to look up.
    info.mapID = nil
    info.activityID = nil
    info.leaderName = nil
    NS.addon.pendingInfo = info
    local mark = #mock.prints
    NS.addon:ShowNotification()
    local lines = linesSince(mock, mark)
    assertFalse(anyLine(lines, "Playstyle:"), "no playstyle label means no row")
    assertFalse(anyLine(lines, "Teleport:"), "no teleport spell means no row")
    assertTrue(anyLine(lines, "Leader:"), "Leader is not subject to the same suppression")
end)
