-- tests/test_frame_secure.lua — the popup's secure child: reopening a soft-hidden popup, its alpha,
-- and the teleport handlers (modules/Frame.lua).
--
-- A sibling of tests/test_frame.lua rather than more of it: that suite sits near the layout-1
-- 1500-line cap. The cases here are the ones where the popup is still SHOWN at alpha 0 during a
-- lockdown, so ShowFrame's first-show defer lets the reopen through and every protected call on
-- the SecureActionButtonTemplate teleport button has to be deferred by the code that makes it.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local STONEVAULT_MAP, STONEVAULT_PORT = 2652, 445269

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
        mapID            = STONEVAULT_MAP,
        generalPlaystyle = 3,
        playstyleString  = "",
        shortName        = "",
    }
    for k, v in pairs(overrides or {}) do i[k] = v end
    return i
end

local function popup(mock) return mock.frames["WhatGroupFrame"] end

-- The secure cast button is the only SecureActionButtonTemplate frame.
local function teleportBtn(mock)
    for _, f in ipairs(mock.frames) do
        if f.__template == "SecureActionButtonTemplate" then return f end
    end
end

-- The Close button, found by its label under the popup (the same lookup tests/test_frame.lua uses).
local function closeButton(mock)
    for _, kid in ipairs(popup(mock).__children or {}) do
        if kid.__text == "Close" and kid.__scripts and kid.__scripts.OnClick then return kid end
    end
end

-- A learned Stonevault teleport, so a capture on that map arms the button with a macro.
local function learnStonevault(NS, mock)
    mock.spellNames[STONEVAULT_PORT] = "Path of the Stonevault"
    mock.knownSpells[STONEVAULT_PORT] = true
    NS.TeleportSpells[STONEVAULT_MAP] = STONEVAULT_PORT
end

-- The lockdown lifts: AceEvent's dispatch for the addon's handlers, and the popup's own frame
-- event, which is where deferTeleportUntilCombatEnds parks its replay.
local function endCombat(mock)
    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    local f = popup(mock)
    if f.__events and f.__events["PLAYER_REGEN_ENABLED"] and f.__scripts.OnEvent then
        f.__fire("OnEvent", "PLAYER_REGEN_ENABLED")
    end
end

test("frame: reopening a soft-hidden popup in combat with no capture never Hides the secure button", function()
    -- red under: PopulateFields calling fields.teleportBtn:Hide() directly (mock.blocked =
    -- {"<anonymous>:Hide()"}). A soft-hidden popup is still IsShown, so ShowFrame's first-show
    -- defer lets the reopen through to PopulateFields' no-capture branch inside the lockdown.
    local NS, _, mock = T.enableAddon()
    learnStonevault(NS, mock)
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    local btn = teleportBtn(mock)
    assertTrue(btn:IsShown(), "the capture armed the teleport button")

    mock.combat = true
    local close = closeButton(mock)
    close.__scripts.OnClick(close)
    assertEqual(popup(mock):GetAlpha(), 0, "Close in combat is the alpha-0 soft hide")
    NS.addon:WipeCapture("test")

    NS.addon:ToggleFrame()
    assertEqual(#mock.blocked, 0, "no protected call may be attempted inside the lockdown: " .. table.concat(mock.blocked, ","))

    endCombat(mock)
    assertFalse(btn:IsShown(), "the deferred no-capture configure hid the button at combat end")
    assertNil(btn:GetAttribute("type"), "and cleared its secure action")
end)

test("frame: a deferred no-capture configure is replayed, not dropped", function()
    -- red under: deferTeleportUntilCombatEnds stashing a plain `info` -- a nil stash reads as
    -- "nothing pending" at the `if pending` replay, so the stale macro survives combat.
    local NS, _, mock = T.enableAddon()
    learnStonevault(NS, mock)
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    local btn = teleportBtn(mock)
    assertEqual(btn:GetAttribute("macrotext"), "/cast Path of the Stonevault")

    mock.combat = true
    NS.addon:WipeCapture("test")
    NS.addon:ShowFrame()          -- still on screen, so this refills the fields in the lockdown
    assertEqual(#mock.blocked, 0)
    assertEqual(btn:GetAttribute("macrotext"), "/cast Path of the Stonevault",
        "nothing secure is written inside the lockdown")

    endCombat(mock)
    assertFalse(btn:IsShown())
    assertNil(btn:GetAttribute("type"))
    assertNil(btn:GetAttribute("macrotext"))
end)
