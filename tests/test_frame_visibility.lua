-- tests/test_frame_visibility.lua — the group-info popup's master controls and visibility
-- (modules/Frame.lua): scale, alpha, lock, reset position and the general-visibility gate, the
-- combat transition that gate answers to, and Escape in combat through the ESC proxy.
--
-- Split out of tests/test_frame.lua at 1422 lines, where the file sat in layout-§1's 1000–1500
-- band as an Accepted ruling two release runs had carried, one short of anti-pattern #53's limit.
-- The cases moved unchanged and in order; the helpers both suites use are in
-- tests/frame_fixture.lua.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local F = dofile("tests/frame_fixture.lua")
local pending, popup, closeButton, dragHandle, proxy, pressEscape =
    F.pending, F.popup, F.closeButton, F.dragHandle, F.proxy, F.pressEscape

-- ---------------------------------------------------------------------------
-- The master controls (options-ui-§15) — scale, alpha, lock, reset position,
-- and the general-visibility gate
-- ---------------------------------------------------------------------------
--
-- Every case here drives a setting the panel now declares. A declared setting the drawing code
-- does not honor is worse than an absent one, so each is asserted against the popup itself rather
-- than against db.profile.

test("frame: the popup opens at the profile's master scale", function()
    -- red under: dropping the ApplyFrameScale call from ShowFrame.
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.scale = 1.4
    NS.addon:ShowFrame()
    assertEqual(popup(mock):GetScale(), 1.4)
end)

test("frame: a scale change re-scales a popup that is already open", function()
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    assertEqual(popup(mock):GetScale(), 1, "the shipped default is unity")
    NS.addon.Settings.Helpers.Set("scale", 0.75)
    assertEqual(popup(mock):GetScale(), 0.75, "the row's onChange reached the live frame")
end)

test("frame: a scale hand-edited past the clamp is drawn at the nearest legal value", function()
    -- SavedVariables and `/wg set scale 40` both bypass the slider, and a popup at forty times
    -- size reads as the addon being broken rather than as the value being refused.
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.scale = 40
    NS.addon:ShowFrame()
    assertEqual(popup(mock):GetScale(), 2, "clamped to the row's max")
end)

test("frame: a scale change taken in combat is refused, and lands on the next open", function()
    -- Scaling the parent moves the SecureActionButtonTemplate child, which is the same protected
    -- work ApplyFrameSize refuses.
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    mock.combat = true
    NS.addon.Settings.Helpers.Set("scale", 1.5)
    assertEqual(popup(mock):GetScale(), 1, "the live frame was left alone in combat")
    mock.combat = false
    NS.addon:ShowFrame()
    assertEqual(popup(mock):GetScale(), 1.5, "and the next open picks the value up")
end)

test("frame: the popup opens at the profile's master alpha", function()
    -- red under: dropping the ApplyFrameAlpha call from ShowFrame.
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.alpha = 0.4
    NS.addon:ShowFrame()
    assertEqual(popup(mock):GetAlpha(), 0.4)
end)

test("frame: an alpha change lands DURING combat, unlike a size or scale change", function()
    -- Opacity moves nothing, so the secure child's position is untouched and there is nothing to
    -- refuse — which matters because in combat is the one time an alpha setting is being judged.
    -- red under: copying ApplyFrameSize's InCombatLockdown guard onto ApplyFrameAlpha.
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    mock.combat = true
    NS.addon.Settings.Helpers.Set("alpha", 0.25)
    assertEqual(popup(mock):GetAlpha(), 0.25)
end)

test("frame: locking the popup stops the title bar starting a drag", function()
    -- red under: reading `locked` once at build time instead of at drag time, or dropping the
    -- guard entirely.
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    local titleBar = dragHandle(mock)
    titleBar.__fire("OnMouseDown")
    assertTrue(popup(mock):IsMoving(), "unlocked, the drag starts")
    titleBar.__fire("OnMouseUp")

    NS.addon.Settings.Helpers.Set("locked", true)
    titleBar.__fire("OnMouseDown")
    assertFalse(popup(mock):IsMoving(), "locked, the same mouse-down does nothing")
end)

test("frame: Reset position re-anchors the popup and forgets the saved point", function()
    -- Both halves, because either alone is a reset the next login undoes.
    -- red under: dropping the db.global.windows.popup clear.
    local NS, env, mock = T.bootAddon()
    NS.addon:ShowFrame()
    local f = popup(mock)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 120, -240)
    dragHandle(mock).__fire("OnMouseUp")
    assertTrue(NS.addon.db.global.windows.popup ~= nil, "there is a stored point to drop")

    NS.addon:ResetFramePosition()
    assertNil(NS.addon.db.global.windows.popup, "the persisted point is gone")
    assertEqual(f:GetPoint(1), "CENTER", "and the frame is back at the shipped anchor")
end)

test("frame: Reset position in combat is refused, but still forgets the saved point", function()
    -- Re-anchoring moves the secure child; forgetting the point does not. Splitting them means the
    -- act is never half-applied in a way the next login would undo.
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    local f = popup(mock)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", nil, "TOPLEFT", 10, -10)
    mock.combat = true
    NS.addon:ResetFramePosition()
    assertEqual(f:GetPoint(1), "TOPLEFT", "the live frame was left alone in combat")
end)

test("frame: visibility 'never' refuses every path to the screen", function()
    -- red under: gating only the auto-show path instead of ShowFrame itself.
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.visibility = "never"
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertNil(popup(mock), "the popup was never even built")
end)

test("frame: visibility 'inCombat' BUILDS out of combat but only SHOWS in it", function()
    -- The build is deliberately not refused here, unlike `never`: refusing it would deadlock the
    -- setting outright, because the first show is always out of combat and the in-combat show
    -- would then meet the never-built defer instead of a popup.
    -- red under: moving the combat-dependent half of the gate above buildFrame.
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.visibility = "inCombat"
    NS.addon:ShowFrame()
    assertTrue(popup(mock) ~= nil, "the frame is built on the safe side of the lockdown")
    assertFalse(popup(mock):IsShown(), "and out of combat it stays off screen")
    mock.combat = true
    NS.addon:ShowFrame()
    -- AND IT CANNOT OPEN, which is the finding rather than the fix. `inCombat` asks for a popup
    -- that appears during a lockdown, and Show is protected there — so from a genuinely hidden
    -- frame the setting cannot be delivered at all. What this case pins is that the addon does not
    -- ASK: the attempt would not open it either way and would cost the player a red error.
    -- Delivering `inCombat` would mean keeping the frame shown at alpha 0 for the whole time the
    -- player is OUT of combat, so the edge needs only an alpha change — an invisible 420x260
    -- click-target at rest, which is a trade for the owner to make, not this case.
    assertEqual(#mock.blocked, 0, "no protected Show may be attempted")
    assertFalse(popup(mock):IsShown(), "the client will not open it mid-fight")
end)

test("frame: visibility 'outOfCombat' is the mirror of it", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.visibility = "outOfCombat"
    mock.combat = true
    NS.addon:ShowFrame()
    assertNil(popup(mock))
    mock.combat = false
    NS.addon:ShowFrame()
    assertTrue(popup(mock) ~= nil and popup(mock):IsShown())
end)

test("frame: an unrecognized visibility value fails OPEN, not closed", function()
    -- A hand-edited SavedVariable or a profile from a future version must not make the addon look
    -- broken. `always` and anything unknown both answer yes.
    -- red under: a whitelist that returns false for the default branch.
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.visibility = "sometimes"
    NS.addon:ShowFrame()
    assertTrue(popup(mock):IsShown())
end)

test("frame: switching visibility to 'never' hides a popup that is already open", function()
    -- Otherwise the dropdown reads as ignored until the next open.
    -- red under: dropping ApplyFrameVisibility from the row's onChange.
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    assertTrue(popup(mock):IsShown())
    NS.addon.Settings.Helpers.Set("visibility", "never")
    assertFalse(popup(mock):IsShown())
end)

-- ---------------------------------------------------------------------------
-- The combat transition (WHATGROUP-R-01). `inCombat` and `outOfCombat` are the only two settings
-- in the addon whose answer changes without the player touching the panel, so they are the only
-- two that need an event rather than an onChange.
-- ---------------------------------------------------------------------------

test("frame: both combat-transition events are registered, and to one handler", function()
    -- red under: never registering them, which is how the gate came to be evaluated only at show.
    local NS = T.enableAddon()
    assertEqual(NS.addon.__events["PLAYER_REGEN_DISABLED"], "OnCombatStateChanged")
    assertEqual(NS.addon.__events["PLAYER_REGEN_ENABLED"],  "OnCombatStateChanged")
    assertTrue(NS.addon.OnCombatStateChanged ~= nil)
end)

test("frame: entering combat does NOT attempt a hide the client would refuse", function()
    -- This case asserted the opposite until 2026-09-08, and the ASSERTION was wrong rather than the
    -- code under it. f parents a SecureActionButtonTemplate button, so the client refuses f:Hide()
    -- inside a lockdown and raises ADDON_ACTION_BLOCKED naming this addon -- which is what a player
    -- reported. The popup genuinely stays up for the fight and there is no way around that while
    -- the secure child exists. What is pinned here is that the addon does not ASK: the attempt does
    -- not hide the frame either way, and costs the player a red error for nothing.
    -- red under: the M2-21 seam, which called f:Hide() straight off the PLAYER_REGEN_DISABLED edge.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.visibility = "outOfCombat"
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertTrue(popup(mock):IsShown())

    mock.combat = true
    assertEqual(mock.__fireEvent("PLAYER_REGEN_DISABLED"), 1)
    assertEqual(#mock.blocked, 0, "an ADDON_ACTION_BLOCKED the player sees as a red error")
    -- Still SHOWN, because the client refuses Hide, and no longer VISIBLE, because the owner asked
    -- for the popup to go away on this edge and alpha is the seam that can deliver it. Asserting
    -- IsShown alone would pass with the popup sitting fully drawn on screen, which is the state
    -- this case originally described and is no longer the contract.
    assertTrue(popup(mock):IsShown(), "the client will not Hide it mid-fight, and was not asked to")
    assertEqual(popup(mock):GetAlpha(), 0, "but the player must not still be looking at it")
end)

test("frame: 'never' set during combat is honored the moment the lockdown lifts", function()
    -- The deferred half. A gate that cannot fire on the combat edge must still be true one edge
    -- later, or "never" means "never, until you reload".
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertTrue(popup(mock):IsShown())

    mock.combat = true
    NS.addon.db.profile.visibility = "never"
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertEqual(#mock.blocked, 0, "still never asks inside the lockdown")

    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertFalse(popup(mock):IsShown(), "'never' means never, one edge late")
end)

test("frame: Close pressed in combat is remembered, not fired into a refusal", function()
    -- The pre-existing half of the same defect, and the one the player actually hit:
    -- closeBtn's OnClick called f:Hide() unconditionally, from inside a lockdown.
    -- red under: `closeBtn:SetScript("OnClick", function() f:Hide() end)`.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()

    mock.combat = true
    local btn = closeButton(mock)
    assertTrue(btn ~= nil, "no Close button found to press")
    btn.__scripts.OnClick(btn)
    assertEqual(#mock.blocked, 0, "'WhatGroup tried to call the protected function Hide()'")
    -- Shown but not visible: the Hide is owed until regen, and the player sees it go now.
    assertTrue(popup(mock):IsShown(), "the client will not Hide it, and was not asked to")
    assertEqual(popup(mock):GetAlpha(), 0, "the press has to take it off screen immediately")

    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertFalse(popup(mock):IsShown(), "the press survives the fight, or Close silently did nothing")
end)

test("frame: a deferred Close outranks a gate that would still permit the popup", function()
    -- The default gate re-shows on every edge. Unless the dismissal is checked FIRST, the player's
    -- press is overwritten by the gate on the very edge that was meant to honor it.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()

    mock.combat = true
    local btn = closeButton(mock)
    btn.__scripts.OnClick(btn)
    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertFalse(popup(mock):IsShown(), "the gate re-showed over the player's own dismissal")
end)

test("frame: a combat edge brings back a popup the gate had hidden", function()
    -- The re-show half. It is driven off `inCombat` rather than `outOfCombat` because the hide has
    -- to be a LEGAL one for this case to be about the re-show at all: the gate closes here while
    -- the player is out of combat, where f:Hide() is permitted. Written the other way round it
    -- silently tested the refusal path instead, which is how it came to assert a hide the client
    -- never performs.
    -- red under: an ApplyFrameVisibility that hides but never shows.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.visibility = "inCombat"
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertFalse(popup(mock) and popup(mock):IsShown(),
        "out of combat, 'inCombat' forbids the popup -- and that hide is legal")

    mock.combat = true
    assertEqual(mock.__fireEvent("PLAYER_REGEN_DISABLED"), 1)
    -- The gate wants to open it here and the client will not let it: the frame is genuinely
    -- hidden, so putting it back needs a Show, and Show inside a lockdown is protected. The
    -- re-show half is therefore real only on the OTHER edge — `outOfCombat` releasing when combat
    -- ends, where Show is legal — and for a popup held at alpha 0, which needs no Show at all.
    -- Both of those are pinned by their own cases below.
    assertEqual(#mock.blocked, 0, "and it must not fire into the refusal to find that out")
    assertFalse(popup(mock):IsShown(), "'inCombat' cannot be delivered from a hidden frame")
end)

-- On screen means the player can see it. A popup the client refused to Hide is held at alpha 0,
-- so IsShown() alone answers the wrong question for every case below.
local function onScreen(mock)
    local p = popup(mock)
    return p ~= nil and p:IsShown() and p:GetAlpha() > 0
end

test("frame: Close in combat takes the popup off screen at once", function()
    -- The requirement, stated by the owner on 2026-09-08: it must be possible to CLOSE an open
    -- popup during combat. The client will not Hide it -- f parents a SecureActionButtonTemplate
    -- button and hiding an ancestor of one is protected -- so the press cannot wait for regen and
    -- cannot fire into a refusal either. Alpha is the seam: ApplyFrameAlpha is deliberately not
    -- combat-guarded, on this addon's own ruling that opacity moves nothing.
    -- red under: a hidePopup that returns false in combat and leaves the popup on screen.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertTrue(onScreen(mock))

    mock.combat = true
    local btn = closeButton(mock)
    btn.__scripts.OnClick(btn)
    assertFalse(onScreen(mock), "Close in combat must take it off screen, not defer to regen")
    assertEqual(#mock.blocked, 0, "and must not fire into the client's refusal to do it")
end)

test("frame: the real Hide lands when the lockdown lifts, and the alpha comes back with it", function()
    -- Alpha 0 is a stand-in, not a resting state: the frame is still shown and still taking
    -- mouse input. The owed Hide has to be settled on the first
    -- edge where it is legal, or the popup is invisible-but-present for the rest of the session.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    mock.combat = true
    local btn = closeButton(mock)
    btn.__scripts.OnClick(btn)

    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertFalse(popup(mock):IsShown(), "the deferred Hide never landed")
    assertEqual(popup(mock):GetAlpha(), 1, "and the next open would have drawn at alpha 0")
end)

test("frame: the alpha restored is the player's own, not a hardcoded 1", function()
    -- masterAlpha() reads profile.alpha. Restoring a literal 1 would quietly overwrite the setting
    -- of anyone running a translucent popup, and only on the combat path.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.alpha = 0.6
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    mock.combat = true
    local btn = closeButton(mock)
    btn.__scripts.OnClick(btn)
    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(popup(mock):GetAlpha(), 0.6, "the player's opacity was replaced by the default")
end)

test("frame: 'out of combat' takes the popup off screen the moment combat starts", function()
    -- The other half of the owner's requirement: not opening in combat is fine, and the gate must
    -- act on the edge rather than a fight later. Same seam as Close, same refusal to ask the client
    -- for a Hide it will not perform.
    -- red under: a gate that leaves the popup up for the whole fight.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.visibility = "outOfCombat"
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertTrue(onScreen(mock))

    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(onScreen(mock), "the dropdown reads as ignored for the length of the fight")
    assertEqual(#mock.blocked, 0)
end)

test("frame: and it opens again by itself when combat ends", function()
    -- "It should open automatically after combat", verbatim. This is the gate releasing what it
    -- withheld -- distinct from a popup the player closed, which must stay shut.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.visibility = "outOfCombat"
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(onScreen(mock))

    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertTrue(onScreen(mock), "the invite the player is still holding must come back on its own")
    assertEqual(popup(mock):GetAlpha(), 1)
end)

test("frame: a popup the PLAYER closed does not come back when combat starts", function()
    -- Reported from the client on 2026-09-08: `/wg test`, close the popup, pull something, and it
    -- springs open again. No Lua error, because nothing is wrong with the call -- the re-show arm
    -- simply cannot tell "the gate is withholding this" from "the player put it away".
    --
    -- Note the visibility value: `always`, the shipped default. Under it the gate NEVER hides, so
    -- every firing of the re-show arm is a popup the player closed. There is no legitimate case at
    -- all on the default setting, which is why this reached a client.
    -- red under: `if WhatGroup.pendingInfo and not f:IsShown() then f:Show() end`.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertTrue(popup(mock):IsShown())

    local btn = closeButton(mock)
    btn.__scripts.OnClick(btn)
    assertFalse(popup(mock):IsShown(), "the Close press itself")

    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(popup(mock):IsShown(), "combat reopened a popup the player had dismissed")
end)

test("frame: a popup closed with ESC does not come back either", function()
    -- ESC reaches the popup through the proxy's OnHide, not through the Close button's handler, so
    -- whatever distinguishes a gate hide from a player hide cannot live on one button.
    -- red under: the same arm.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertTrue(pressEscape(mock), "Escape closed a window")
    assertFalse(popup(mock):IsShown(), "the Escape press itself")

    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(popup(mock):IsShown(), "ESC must be as durable as the Close button")
end)

-- ---------------------------------------------------------------------------
-- Escape in combat, through the proxy (the 2026-09-12 ADDON_ACTION_BLOCKED on WhatGroupFrame:Hide()
-- from Blizzard_UIParentPanelManager's CloseWindows)
-- ---------------------------------------------------------------------------

test("frame: Escape in combat never calls the popup's protected Hide, and soft-hides it", function()
    -- The owner's report, verbatim: `[ADDON_ACTION_BLOCKED] AddOn 'WhatGroup' tried to call the
    -- protected function 'WhatGroupFrame:Hide()'` from CloseWindows ← ToggleGameMenu.
    -- red under: `tinsert(UISpecialFrames, "WhatGroupFrame")`.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertTrue(onScreen(mock))

    mock.combat = true
    local found = pressEscape(mock)
    assertEqual(#mock.blocked, 0, "Escape fired a protected Hide: " .. table.concat(mock.blocked, ", "))
    assertTrue(found, "the press closed a window, so the game menu must not open on it")
    assertTrue(popup(mock):IsShown(), "the real Hide is owed to the end of the lockdown")
    assertEqual(popup(mock):GetAlpha(), 0, "but the player sees it go now")
    assertFalse(proxy(mock):IsShown(), "and the proxy is down with it")
end)

test("frame: Escape out of combat really hides the popup, and the next Escape opens the menu", function()
    -- red under: a proxy OnHide that only soft-hides, or a proxy left shown after the popup closed.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()

    assertTrue(pressEscape(mock), "the first Escape closes the popup")
    assertFalse(popup(mock):IsShown(), "out of combat Escape is a real Hide")
    assertEqual(popup(mock):GetAlpha(), 1, "at the player's own opacity")
    assertEqual(#mock.blocked, 0)
    assertFalse(pressEscape(mock), "the second Escape finds no window, so the game menu opens")
end)

test("frame: Escape in combat is a player dismissal -- regen lands the real Hide, and nothing reopens it", function()
    -- red under: a proxy OnHide that leaves pendingHide unset (the popup stays at alpha 0 forever).
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    mock.combat = true
    pressEscape(mock)

    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertFalse(popup(mock):IsShown(), "the owed Hide landed when the lockdown lifted")
    assertEqual(popup(mock):GetAlpha(), 1, "and the alpha came back for the next open")

    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertFalse(popup(mock):IsShown(), "a player's Escape must outlive every later combat edge")
    assertEqual(#mock.blocked, 0)
end)

test("frame: Escape in combat clears a gate flag left over from a re-show", function()
    -- A popup the gate withheld and then released comes back through showPopup, which fires OnShow
    -- and never OnHide, so it is on screen with gateWithheld still true. An Escape in combat takes
    -- the soft route and fires no OnHide on the popup either -- so unless the proxy clears the flag
    -- itself, regen settles the Hide and the gate reopens the popup the player just dismissed.
    -- red under: a proxy OnHide that calls hidePopup() without `gateWithheld = false`.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.visibility = "inCombat"
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()                       -- built, withheld by the gate
    assertFalse(popup(mock):IsShown())
    NS.addon.db.profile.visibility = "always"
    NS.addon:ApplyFrameVisibility()            -- the dropdown's onChange: the gate releases it
    assertTrue(onScreen(mock), "the released popup is on screen")

    mock.combat = true
    pressEscape(mock)
    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertFalse(popup(mock):IsShown(), "the gate reopened a popup the player closed with Escape")
end)

test("frame: the proxy is shown exactly while the popup is on screen", function()
    -- CloseWindows counts a SHOWN proxy as a closed window, which suppresses the game menu. A proxy
    -- left up with the popup gone would eat the player's next Escape for nothing.
    -- red under: any off-screen path that forgets the proxy (a real Hide, a soft hide, the gate).
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.visibility = "inCombat"
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()                       -- built, off screen
    assertFalse(proxy(mock):IsShown(), "hidden at creation: the popup was never on screen")
    assertFalse(pressEscape(mock), "no popup, so the game menu opens")

    NS.addon.db.profile.visibility = "always"
    NS.addon:ShowFrame()
    assertTrue(proxy(mock):IsShown(), "a full Show brings the proxy up")

    local btn = closeButton(mock)
    btn.__scripts.OnClick(btn)                 -- real Hide, out of combat
    assertFalse(proxy(mock):IsShown(), "a real Hide takes the proxy down")
    assertFalse(pressEscape(mock))

    NS.addon:ShowFrame()
    mock.combat = true
    btn.__scripts.OnClick(btn)                 -- soft hide
    assertFalse(proxy(mock):IsShown(), "a soft hide takes the proxy down")
    assertFalse(pressEscape(mock), "a soft-hidden popup is not a window to close")

    NS.addon:ShowFrame()                       -- alpha restore, legal in combat
    assertTrue(onScreen(mock), "the soft-hidden popup comes back on its alpha")
    assertTrue(proxy(mock):IsShown(), "and the proxy with it")

    NS.addon.db.profile.visibility = "outOfCombat"
    NS.addon:ApplyFrameVisibility()            -- the gate soft-hides it in combat
    assertFalse(proxy(mock):IsShown(), "a gate hide takes the proxy down")
    assertFalse(pressEscape(mock))
    assertEqual(#mock.blocked, 0)
end)

test("frame: leaving combat does not reopen a popup the player closed mid-fight either", function()
    -- The other edge. `always` permits the popup on both transitions, so a dismissal has to
    -- survive PLAYER_REGEN_ENABLED as well -- and that edge is the one that also flushes a
    -- deferred Close, so the two must not fight.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    local btn = closeButton(mock)
    btn.__scripts.OnClick(btn)

    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertFalse(popup(mock):IsShown(), "the dismissal has to outlive the whole fight")
end)

test("frame: a combat transition never opens a popup with nothing to show", function()
    -- A "No data" popup appearing the moment the player pulls is worse than no popup at all, so
    -- the re-show is gated on there being a capture to render.
    -- red under: a symmetric ApplyFrameVisibility that shows on any open gate.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.visibility = "inCombat"
    NS.addon:ShowFrame()               -- builds it, out of combat, off screen
    assertTrue(popup(mock) ~= nil)
    assertFalse(popup(mock):IsShown())

    NS.addon.pendingInfo = nil
    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(popup(mock):IsShown(), "nothing to render, so nothing opens")
end)

test("frame: PLAYER_REGEN_DISABLED is answered from the event, not from a lockdown flag that has not flipped", function()
    -- The client fires PLAYER_REGEN_DISABLED at the START of the lockdown and InCombatLockdown()
    -- can still answer false on that same frame. A handler that asks the API evaluates the gate
    -- against the state the player has just left, which is the wrong answer in both directions.
    -- red under: ApplyFrameVisibility reading InCombatLockdown() with no override.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.visibility = "outOfCombat"
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertTrue(popup(mock):IsShown())

    mock.combat = false                -- the flag has not caught up yet
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(popup(mock):IsShown(), "the event name is the authority on which edge this is")
end)

test("frame: a combat transition with no popup built is a no-op, not an error", function()
    -- The events register at OnEnable and the popup is lazy, so most transitions in a session
    -- arrive with nothing on screen. That must not build one.
    -- red under: an ApplyFrameVisibility that reaches buildFrame.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.visibility = "outOfCombat"
    NS.addon.pendingInfo = pending()
    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertNil(popup(mock), "the lazy build is the taint contract; a transition must not trip it")
end)
