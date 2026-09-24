-- tests/test_frame_secure.lua — the popup's secure child: reopening a soft-hidden popup, its alpha,
-- and the teleport handlers (modules/Frame.lua).
--
-- A sibling of tests/test_frame.lua rather than more of it: that suite sits near the layout-§1
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

-- The lockdown lifts: AceEvent's dispatch for the addon's handlers, which is also what drains
-- modules/Frame.lua's combat-end queue, where deferTeleportUntilCombatEnds parks its replay.
local function endCombat(mock)
    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
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

-- The gate-declined reopen (WHATGROUP-R-02). With `outOfCombat`, PLAYER_REGEN_DISABLED soft-hides
-- the popup at alpha 0. A reopen in combat runs preparePopup, which re-applies the opacity BEFORE
-- the gate is asked, and the gate then declines -- so the alpha write is the only thing standing
-- between the player and a popup that onScreen() says is not there.
local ESC_PROXY = "WhatGroupFrameEscape"

local function softHideByGate(NS, mock)
    NS.addon.db.profile.visibility = "outOfCombat"
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertEqual(popup(mock):GetAlpha(), 1, "shown out of combat at the master alpha")
    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertTrue(popup(mock):IsShown(), "the client will not Hide it mid-fight")
    assertEqual(popup(mock):GetAlpha(), 0, "the gate soft-hid it on the combat edge")
end

test("frame: a gate-declined reopen in combat leaves a soft-hidden popup at alpha 0, and the launcher still closes it", function()
    -- red under: ApplyFrameAlpha setting masterAlpha() unconditionally
    local NS, _, mock = T.enableAddon()
    softHideByGate(NS, mock)

    NS.addon:OnSlashCommand("show")
    assertEqual(popup(mock):GetAlpha(), 0, "the gate declined, so the popup must stay invisible")
    assertFalse(mock.frames[ESC_PROXY]:IsShown(), "the ESC proxy stays down for a popup not on screen")

    -- onScreen() is truthful, so the launcher OPENS (again declined) rather than dismissing an
    -- invisible popup, and the popup stays invisible either way.
    assertFalse(NS.addon:ToggleFrame(), "the launcher click opens, and the gate declines it")
    assertEqual(popup(mock):GetAlpha(), 0)
    assertEqual(#mock.blocked, 0)
end)

test("frame: an alpha write while soft-hidden does not reveal the popup", function()
    -- red under: ApplyFrameAlpha setting masterAlpha() unconditionally
    local NS, _, mock = T.enableAddon()
    softHideByGate(NS, mock)

    NS.addon:OnSlashCommand("set alpha 0.8")
    assertEqual(NS.addon.db.profile.alpha, 0.8, "the write itself lands in combat")
    assertEqual(popup(mock):GetAlpha(), 0, "but a soft-hidden popup stays invisible")
end)

test("frame: a real show after the soft hide restores the master alpha", function()
    -- red under: ApplyFrameAlpha setting masterAlpha() unconditionally -- the guard must clear with
    -- softHidden, or the popup comes back invisible.
    local NS, _, mock = T.enableAddon()
    softHideByGate(NS, mock)
    NS.addon.db.profile.alpha = 0.8
    NS.addon:ApplyFrameAlpha()
    assertEqual(popup(mock):GetAlpha(), 0)

    endCombat(mock)
    assertTrue(popup(mock):IsShown(), "the gate reopens what it withheld when combat ends")
    assertEqual(popup(mock):GetAlpha(), 0.8, "at the master alpha, not stuck at 0")
    assertTrue(mock.frames[ESC_PROXY]:IsShown())
end)

test("frame: a stand-down in combat drops a queued first show and a queued teleport configure", function()
    -- Both replays wait in modules/Frame.lua's combat-end queue, and NS.FrameStandDown wipes it:
    -- work deferred for an addon that has since been switched off is not work it still owes.
    -- red under: an NS.FrameStandDown that leaves the combat-end queue (or its stashes) in place --
    -- the re-enable below re-registers OnCombatStateChanged, whose drain would then replay both.
    -- The first show: never built, deferred in combat, then the addon goes down and comes back.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    mock.combat = true
    NS.addon:ShowFrame()
    assertTrue(NS.addon._frameBuildQueued, "the first show is queued for combat end")
    NS.addon:OnSlashCommand("disable")
    assertNil(NS.addon._frameBuildQueued, "the stand-down drops the queued show")
    NS.addon:OnSlashCommand("enable")
    NS.addon.pendingInfo = pending()
    endCombat(mock)
    assertNil(popup(mock), "nothing is built or shown for the dropped show")

    -- The teleport configure: armed out of combat, a new capture refilled in combat, then disabled.
    NS, _, mock = T.enableAddon()
    learnStonevault(NS, mock)
    NS.addon:ShowFrame()          -- built out of combat, no capture yet
    local btn = teleportBtn(mock)
    assertNil(btn:GetAttribute("macrotext"))
    mock.combat = true
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()          -- still shown, so the configure is deferred
    NS.addon:OnSlashCommand("disable")
    NS.addon:OnSlashCommand("enable")
    endCombat(mock)
    assertNil(btn:GetAttribute("macrotext"), "the dropped configure never arms the button")
    assertEqual(#mock.blocked, 0)
end)

-- WHATGROUP-R-16. The OnEnter / OnLeave / PreClick trio is defined once at file scope and reads the
-- spell off the button, so a reconfigure swaps the data on the button and never allocates fresh
-- closures. The second capture's spell must still be what the tooltip and the trace name.
test("frame: reconfiguring the teleport button reuses the same three script handlers", function()
    -- red under: per-call closures in applyTeleportAction
    local NS, _, mock = T.enableAddon()
    learnStonevault(NS, mock)
    local SECOND_MAP, SECOND_PORT = 2660, 445417
    mock.spellNames[SECOND_PORT] = "Path of the Ara-Kara"
    mock.knownSpells[SECOND_PORT] = true
    NS.TeleportSpells[SECOND_MAP] = SECOND_PORT

    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    local btn = teleportBtn(mock)
    local enter, leave, pre = btn:GetScript("OnEnter"), btn:GetScript("OnLeave"), btn:GetScript("PreClick")
    assertTrue(enter and leave and pre, "the first capture wired all three handlers")

    NS.addon.pendingInfo = pending({ mapID = SECOND_MAP, activityName = "Ara-Kara" })
    NS.addon:ShowFrame()
    assertEqual(btn:GetAttribute("macrotext"), "/cast Path of the Ara-Kara", "the second capture re-armed it")
    assertTrue(rawequal(btn:GetScript("OnEnter"), enter), "OnEnter is the same function across configures")
    assertTrue(rawequal(btn:GetScript("OnLeave"), leave), "OnLeave is the same function across configures")
    assertTrue(rawequal(btn:GetScript("PreClick"), pre), "PreClick is the same function across configures")

    local tip = mock.GameTooltip
    local shownID
    tip.SetSpellByID = function(_, id) shownID = id end
    btn.__fire("OnEnter")
    assertEqual(shownID, SECOND_PORT, "the tooltip shows the second capture's spell")

    NS.State.debug = true
    btn.__fire("PreClick", "LeftButton", true)
    local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
    assertTrue(last and last:find("/cast Path of the Ara-Kara (spellID=445417, button=LeftButton)", 1, true) ~= nil,
        "the PreClick trace names the second spell: " .. tostring(last))
end)
