-- modules/Frame.lua
-- Custom popup dialog frame for displaying group details.
--
-- Everything in this file is **lazy** — no frames are created at file
-- load. The popup, the Close button, the SecureActionButtonTemplate
-- teleport button, and the UISpecialFrames registration (of the ESC
-- proxy `WhatGroupFrameEscape`, never of the popup itself) all happen
-- inside `buildFrame()`, which fires on the first `WhatGroup:ShowFrame()`
-- call.
--
-- The reason for the lazy approach is taint: creating the popup +
-- secure button + UISpecialFrames entry at PLAYER_LOGIN was leaving a
-- taint trace that surfaced as `ADDON_ACTION_FORBIDDEN ... 'callback()'`
-- when the player clicked the GameMenu's Logout button — even on a
-- fresh /reload with no addon use. Deferring all of that until the
-- player actually opens the popup means the addon adds nothing to
-- Blizzard's secure-execute or UISpecialFrames lists during the boot
-- sequence, so GameMenu's `InitButtons` runs in a clean context and
-- the closures it builds for Logout / Settings / Macros are
-- taint-free. See [docs/midnight-quirks.md] for the full taint analysis.

local _, NS = ...
local WhatGroup = NS.addon
local L         = NS.L

local LABEL_WIDTH  = 72
local yGap         = -18

-- These get assigned inside buildFrame() and are nil until the popup
-- is first shown. PopulateFields and ConfigureTeleportButton both
-- read them after buildFrame() has run, so they're always non-nil
-- by the time those functions execute.
local f, fields, ConfigureTeleportButton

-- THE POPUP'S SIZE IS A SETTING NOW. `FRAME_WIDTH = 420` and `FRAME_HEIGHT = 260` used to be two
-- file-locals here; they are `frame.width` and `frame.height` in the schema, and their shipped
-- defaults ARE those two numbers (defaults/Profile.lua), so a profile that never touches either
-- slider draws the popup that shipped.
--
-- CLAMPED ON READ, not on write. The slider cannot produce an illegal value, but SavedVariables
-- and `/wg set frame.width 4000` both can, and a popup wider than the monitor reads as the setting
-- being broken rather than as the value being refused. Bounds are stated once, here, and mirrored
-- by the schema row's `min`/`max` so the slider cannot travel anywhere this would then correct.
local FRAME_W_MIN, FRAME_W_MAX = 320, 700
local FRAME_H_MIN, FRAME_H_MAX = 200, 520

local function clamp(v, lo, hi, fallback)
    v = tonumber(v)
    if not v then return fallback end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- The size to draw at: the profile's, clamped, falling back to the shipped default for a value
-- that is missing or not a number at all. NS.C is defaults/Profile.lua's table, which is the one
-- place either number is hardcoded.
local function popupSize()
    local pr = WhatGroup.db and WhatGroup.db.profile and WhatGroup.db.profile.frame
    local dw = NS.C and NS.C.frame and NS.C.frame.width  or FRAME_W_MIN
    local dh = NS.C and NS.C.frame and NS.C.frame.height or FRAME_H_MIN
    return clamp(pr and pr.width,  FRAME_W_MIN, FRAME_W_MAX, dw),
           clamp(pr and pr.height, FRAME_H_MIN, FRAME_H_MAX, dh)
end

-- Re-size a popup that already exists. Called from the two schema rows' `onChange` and from
-- ShowFrame, so a change made while the popup is open lands immediately and a change made while it
-- is closed lands on the next open.
--
-- REFUSED IN COMBAT, not deferred. The popup parents a SecureActionButtonTemplate button whose
-- anchor is derived from the frame's own edges, and resizing the parent moves it -- protected work,
-- and the same reason ConfigureTeleportButton has a combat guard. There is nothing to queue: the
-- next ShowFrame out of combat applies the current value, which is the value the player set.
function WhatGroup:ApplyFrameSize()
    if not f then return end
    if InCombatLockdown() then return end
    f:SetSize(popupSize())
end

-- ---------------------------------------------------------------------------
-- The master controls (options-ui-§15)
-- ---------------------------------------------------------------------------
--
-- Master scale, master alpha, lock frame and reset position are the four rows options-ui-§15 gives
-- every addon that draws a positionable frame, and this one does: the popup is SetMovable(true)
-- with a drag handle and persisted geometry (WG-26). They are declared by the composer in
-- settings/Panel.lua and stored at the profile ROOT — `scale`, `alpha`, `locked` — because they
-- govern the addon's display as a whole rather than this one window's shape; `frame.width` /
-- `frame.height` are the window's own and stay where they are.
--
-- Read and CLAMPED here for the reason popupSize gives: the sliders cannot produce an illegal
-- value but SavedVariables and `/wg set scale 40` both can, and a popup drawn at forty times size
-- reads as the addon being broken rather than as the value being refused. The bounds mirror the
-- composer's own slider bounds, which is what keeps a drag to either end from being silently
-- corrected.
local SCALE_MIN, SCALE_MAX = 0.5, 2
local ALPHA_MIN, ALPHA_MAX = 0, 1

local function masterScale()
    local pr = WhatGroup.db and WhatGroup.db.profile
    return clamp(pr and pr.scale, SCALE_MIN, SCALE_MAX, NS.C and NS.C.scale or 1)
end

local function masterAlpha()
    local pr = WhatGroup.db and WhatGroup.db.profile
    return clamp(pr and pr.alpha, ALPHA_MIN, ALPHA_MAX, NS.C and NS.C.alpha or 1)
end

-- The shipped anchor, in one place: buildFrame's first point and the Reset position button's
-- destination are the same two lines, and a second copy of them is a second answer to "where did
-- it start".
local function anchorDefault(frame)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, math.floor(UIParent:GetHeight() * 0.25))
end

-- REFUSED IN COMBAT, exactly as ApplyFrameSize is and for the same reason: the popup parents a
-- SecureActionButtonTemplate button, and scaling the parent moves the child. There is nothing to
-- queue — the next ShowFrame out of combat applies the current value, which is the value the
-- player set.
function WhatGroup:ApplyFrameScale()
    if not f then return end
    if InCombatLockdown() then return end
    f:SetScale(masterScale())
end

-- NOT refused in combat: opacity moves nothing, so the secure child's position is untouched and
-- the change can land while the player is fighting — which is the one time an alpha setting is
-- actually being judged.
function WhatGroup:ApplyFrameAlpha()
    if not f then return end
    f:SetAlpha(masterAlpha())
end

-- Is the popup allowed on screen right now? `always` and anything unrecognized (a hand-edited
-- SavedVariable, a profile from a future version) answer yes: a display setting that fails closed
-- would make the addon look broken rather than configured.
--
-- `inCombat` OVERRIDES the live InCombatLockdown() read, and exists for exactly one caller: the
-- PLAYER_REGEN_DISABLED handler. That event fires at the START of the lockdown and
-- InCombatLockdown() can still answer false on the same frame — a client quirk this collection has
-- been bitten by before — so a handler that asked the API would evaluate the gate against the state
-- the player has just left. The event NAME is the authority on which edge this is; every other
-- caller passes nothing and gets the live read, which is correct for them because they are not on
-- an edge.
local function visibilityAllows(inCombat)
    if inCombat == nil then inCombat = InCombatLockdown() and true or false end
    local v = WhatGroup.db and WhatGroup.db.profile and WhatGroup.db.profile.visibility
    if v == "never"       then return false end
    if v == "inCombat"    then return inCombat end
    if v == "outOfCombat" then return not inCombat end
    return true
end

-- SYMMETRIC, and that is the whole point (options-ui-§15). Two of `visibility`'s four values are
-- functions of combat state, which the player changes without touching the panel, so the gate has
-- to be re-asked on the transition rather than only when something opens the popup. A popup already
-- on screen when the gate closes has to go, or the dropdown reads as ignored until the next open;
-- a popup the gate hid has to come back when it opens again, or "hide in combat" quietly means
-- "close for the rest of the session".
--
-- ASYMMETRIC IN COMBAT, AND THAT IS THE CLIENT'S RULE RATHER THAN A CHOICE. This comment used to
-- read "neither direction is combat-guarded ... this addon has always taken f:Hide() as
-- unprotected". That was false, and it is what shipped WG's ADDON_ACTION_BLOCKED: buildFrame parents
-- a SecureActionButtonTemplate button to f (see the teleport button), and the client refuses Hide on
-- a protected frame AND on every ancestor of one while in combat. So f:Hide() is protected, from
-- every call site — the Close button, ESC, this gate.
--
-- What that costs, per value, because it is not uniform:
--   * `inCombat`   — hides when combat ENDS. InCombatLockdown() is already false on that edge, so
--                    the hide is legal and the gate is honored exactly.
--   * `outOfCombat` — would hide when combat STARTS, which is inside the lockdown and refused. The
--                    popup therefore STAYS UP for the fight and the gate is honored late, at
--                    PLAYER_REGEN_ENABLED. There is no way to do better while the secure child
--                    exists; the only real alternative is to stop parenting it to f, which costs a
--                    floating orphan button the client will equally refuse to hide.
-- Attempting it anyway is strictly worse than deferring: the frame does not hide either way, and the
-- player additionally gets a red error naming this addon.
--
-- f:Show() on an already-built frame is not a secure write — the secure work is buildFrame's, and it
-- has already happened by the time f exists. Only the hide direction is constrained.
--
-- The re-show is gated on there being a capture to render: a "No data" popup appearing the moment
-- the player pulls is worse than no popup at all. It is deliberately NOT gated on the caller, so
-- the dropdown's own onChange re-shows too — moving `General visibility` back to a value that
-- permits the popup applies that answer on the spot, exactly as moving it to `never` closes an open
-- one. One seam, both directions, every caller.
-- The ONE seam allowed to take the popup off screen. Never calls Hide in combat, so the addon
-- cannot raise ADDON_ACTION_BLOCKED through this path. Every caller must go through it.
--
-- ALPHA IS THE SEAM, and it is this file's own ruling rather than a trick. `ApplyFrameAlpha` above
-- is deliberately NOT combat-guarded — "opacity moves nothing, and in combat is the one time an
-- alpha setting is being judged" — while `ApplyFrameSize` and `ApplyFrameScale` both refuse,
-- because those move the secure child. Hide is refused for the same reason size is, so a close in
-- combat takes the frame to alpha 0 and owes the real Hide to the next legal edge.
--
-- The player gets a popup that closes when they press Close, in combat or out, which is the
-- requirement. What they do not get is the frame leaving the screen's hit-testing until the
-- lockdown lifts: alpha 0 is invisible, not absent, so the title bar still drags and the teleport
-- button still takes a click it cannot act on — a teleport cannot be cast in combat anyway. That
-- residue is exactly why `pendingHide` exists and why the soft state is never a resting one.
local softHidden  = false   -- alpha-0 stand-in for a Hide the client refused
local pendingHide = false   -- a real Hide owed once the lockdown lifts

-- The ESC proxy: the name in UISpecialFrames, standing in for the popup's own (buildEscapeProxy
-- below). Unprotected, so its Show and Hide are legal in combat, and kept SHOWN exactly while the
-- popup is on screen (`onScreen()`), because CloseWindows only closes a shown entry.
local escProxy

local function hidePopup()
    if not f then return true end
    if InCombatLockdown() then
        softHidden, pendingHide = true, true
        f:SetAlpha(0)
        -- The soft route fires no OnHide on f, so the proxy is taken down here. After softHidden is
        -- set, never before: the proxy's own OnHide re-enters only while the popup is on screen.
        if escProxy then escProxy:Hide() end
        return true
    end
    softHidden, pendingHide = false, false
    f:Hide()
    WhatGroup:ApplyFrameAlpha()
    return true
end

-- SHOW IS PROTECTED EXACTLY AS HIDE IS, and this file claimed the opposite until 2026-09-09 —
-- "f:Show() on an already-built frame is not a secure write". It is: the rule is about changing a
-- protected frame's visibility, and showing an ancestor changes it just as hiding one does. A
-- player ran `/wg test` mid-fight and got ADDON_ACTION_BLOCKED on `WhatGroupFrame:Show()`.
--
-- There is one legal way to put the popup back during a lockdown, and it is the mirror of the way
-- it goes away: a frame that is still SHOWN at alpha 0 needs no Show call, only its alpha back.
-- Anything else waits for combat to end. Returns false when it could not, so the caller can defer
-- rather than fire into a refusal.
local function showPopup()
    if not f then return false end
    if f:IsShown() then
        softHidden, pendingHide = false, false
        WhatGroup:ApplyFrameAlpha()
        if not InCombatLockdown() then f:Raise() end
        if escProxy then escProxy:Show() end
        return true
    end
    if InCombatLockdown() then return false end
    softHidden, pendingHide = false, false
    WhatGroup:ApplyFrameAlpha()
    f:Show()
    f:Raise()
    if escProxy then escProxy:Show() end
    return true
end

-- On screen means the player can SEE it. A soft-hidden popup is still shown and still anchored, so
-- IsShown() alone answers the wrong question everywhere the gate asks it.
local function onScreen()
    return f and f:IsShown() and not softHidden
end


-- WHY THE POPUP IS OFF SCREEN — the question the re-show arm has to answer, and could not. Four
-- states reach "hidden", and only two of them are the gate's doing:
--
--   never shown                        -- leave it shut
--   the gate DECLINED a requested show -- reopen when the gate opens  (ShowFrame's refusal)
--   the gate HID a shown popup         -- reopen when the gate opens  (the hide below)
--   the player dismissed it            -- leave it shut               (Close, ESC, any Hide)
--
-- Reported from a client on 2026-09-08: `/wg test`, close it, pull something, and it springs back
-- open. No Lua error, because nothing about the call is wrong. Under `always` — the SHIPPED DEFAULT
-- — the gate never hides at all, so every firing of the re-show arm was a popup the player had put
-- away. On the default value the arm had no legitimate case whatsoever, which is how it reached a
-- client through 559 green cases.
--
-- The bookkeeping is inverted on purpose, so the next hide path cannot forget it: `OnHide` clears
-- this for EVERY hide, and only the gate's own two sites set it back, immediately after. The two
-- player hides that can take the soft route in combat, where OnHide never fires, clear it
-- themselves: the Close button's OnClick, and the ESC proxy's OnHide (buildEscapeProxy). ESC never
-- reaches f directly -- UISpecialFrames holds the proxy, not "WhatGroupFrame" -- so anything keyed
-- off one button's handler is wrong by construction rather than by oversight.
local gateWithheld = false

function WhatGroup:ApplyFrameVisibility(inCombat)
    if not f then return end
    -- Settle what the lockdown deferred, before the gate is asked anything. `hidePopup` performs
    -- the real Hide now that it is legal and restores the alpha, so a popup that spent the fight at
    -- alpha 0 is genuinely gone rather than invisibly present.
    --
    -- `gateWithheld` is saved across it because that real Hide fires OnHide, which clears the flag
    -- for every hide. WHO withheld the popup was decided when it went off screen, and settling the
    -- debt must not relitigate it — otherwise a gate hide would come back as a player dismissal and
    -- never reopen, which is the whole bug this pair of flags exists to prevent.
    if pendingHide and not InCombatLockdown() then
        local wasGate = gateWithheld
        hidePopup()
        gateWithheld = wasGate
    end
    if not visibilityAllows(inCombat) then
        local down = hidePopup()
        -- After the hide, never before: the real Hide fires OnHide, which clears the flag for every
        -- hide including this one. Setting it first would be undone by our own call.
        if down then gateWithheld = true end
        return down
    end
    if gateWithheld and WhatGroup.pendingInfo and not onScreen() then
        showPopup()
    end
end

-- The Reset position button (options-ui-§15). Drops the persisted point (WG-26) as well as
-- re-anchoring, or the next login would restore the position the player just asked to forget.
-- Combat-guarded because re-anchoring moves the secure child.
function WhatGroup:ResetFramePosition()
    local db = self.db
    if db and db.global and db.global.windows then db.global.windows.popup = nil end
    if not f then return end
    if InCombatLockdown() then return end
    anchorDefault(f)
    NS.Debug("Frame", "popup position reset to the shipped anchor")
end

-- The cooldown countdown's repeating timer, and the ONLY repeating anything in this addon. It is a
-- ratified deviation, not an oversight: it ends `performance-§12`'s no-combat-path exemption, and
-- the row that records that — with the reasoning and the re-check trigger — is in
-- `docs/ARCHITECTURE.md`'s `## Documented deviations`.
--
-- What makes it defensible is that it cannot outlive the window that armed it. It exists only
-- while the popup is BOTH open and showing a live cooldown; `stopCooldownTicker` is called from
-- the popup's OnHide, from the top of every ConfigureTeleportButton run, and from the tick that
-- sees the cooldown reach zero. A single handle, replaced rather than stacked, so re-opening the
-- popup ten times leaves one timer and closing it leaves none.
local cooldownTimer

local function stopCooldownTicker()
    if cooldownTimer then
        WhatGroup:CancelTimer(cooldownTimer)
        cooldownTimer = nil
    end
end

-- Secure-button attribute writes (`type`, `macrotext`) and Show/Hide are protected while in
-- combat — silently dropped, not erroring. Stash the info, queue a re-run on combat-end, and tell
-- the caller to bail. The button retains its prior visual state until PLAYER_REGEN_ENABLED fires;
-- at that point we Configure with the most recently-stashed info.
--
-- Returns true when the work was deferred, so the caller's guard reads as one line.
-- Resolves everything the button's appearance depends on, in one place, and returns nil when this
-- activity has no teleport at all — the caller's cue to clear the button rather than paint it.
--
-- A learned teleport that is still recharging is its own state (WG-31). The player owns the spell,
-- so "not learned" would be a lie and hiding the icon would be worse; it renders like the unlearned
-- state but says why, and the swipe shows the wait draining. `remaining` is only asked of a spell
-- the player actually has: an unlearned one has no meaningful cooldown, and answering with one
-- answers a question nobody asked.
-- The note beneath the button: three states, one line of text, and the only place the cooldown
-- countdown lives.
-- Arms or disarms the click. Everything here is protected-frame work, which is why the caller
-- has already established it is out of combat.
local function applyTeleportAction(btn, spellID, spellName, known, ready)
    if ready and spellName then
        -- Secure-handler macro path: clicking runs `/cast <SpellName>`
        -- through Blizzard's secure action system, side-stepping the
        -- ADDON_ACTION_FORBIDDEN that a non-secure CastSpellByID hits.
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", "/cast " .. spellName)
        btn:EnableMouse(true)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(spellID)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- Material-effect trace (debug-logging-§10): log the actual press.
        -- The button registers the down edge only (see RegisterForClicks in buildFrame), so
        -- one press is one line. The `down` check stays as a guard rather than a filter: it
        -- costs nothing and keeps the trace honest if the registration is ever widened again.
        -- PreClick is non-secure work that runs alongside the secure /cast, so it's taint-free
        -- even in combat.
        btn:SetScript("PreClick", function(_, mouseButton, down)
            if down then
                NS.Debug("Frame", "teleport button pressed \226\134\146 /cast "
                    .. spellName .. " (spellID=" .. tostring(spellID)
                    .. ", button=" .. tostring(mouseButton) .. ")")
            end
        end)
    else
        -- Clearing the attributes IS the disable: the button still takes the click, the
        -- secure handler finds no action to run, and nothing is cast. Calling :Disable() would
        -- be the obvious alternative and is the wrong tool — this is a protected frame, and
        -- the state has to be reachable from the same code path that runs in combat.
        btn:SetAttribute("type", nil)
        btn:SetAttribute("macrotext", nil)
        btn:SetScript("PreClick", nil)
        -- The tooltip survives a cooldown but not an unlearned spell. On cooldown it is the
        -- one place the exact time-remaining and the spell's own text live, and a player who
        -- owns the teleport is entitled to it; unlearned, there is nothing to hover for and
        -- the note beside the button already says so.
        if known then
            btn:EnableMouse(true)
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(spellID)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        else
            btn:EnableMouse(false)
            btn:SetScript("OnEnter", nil)
            btn:SetScript("OnLeave", nil)
        end
    end
end

local function applyTeleportNote(spellID, known, remaining, info)
    local note = fields.teleportNote
    local function renderNote(secondsLeft)
        note:SetText("|cff888888" .. L["On cooldown"] .. " — "
            .. NS.FormatDuration(secondsLeft) .. "|r")
        note:Show()
    end

    -- Three states, one note. Order matters: an unlearned spell can still report a cooldown,
    -- and "on cooldown" would answer a question nobody asked while burying the one that
    -- explains the gray icon. A ready teleport needs no explanation, so the note goes.
    if not known then
        note:SetText("|cff888888" .. L["Teleport spell not learned"] .. "|r")
        note:Show()
    elseif remaining > 0 then
        renderNote(remaining)
        -- ARMED ONLY AGAINST A POPUP THAT IS ACTUALLY ON SCREEN, and that condition is the whole
        -- of the `performance-§12` deviation row's argument rather than a tidiness. `OnHide` — the
        -- ticker's hard stop — fires on a TRANSITION, so a ticker armed against a frame that was
        -- never shown has no cancel site at all and runs for the rest of the session. The popup
        -- reaches this function while still hidden on two ordinary paths: `PopulateFields` runs
        -- before `ShowFrame`'s `f:Show()`, and the `inCombat` / `outOfCombat` gate can build the
        -- popup and decline to show it. The note above is rendered either way, so a later `Show`
        -- finds the right text; the popup's `OnShow` re-runs the configure and arms from there.
        if not (f and f:IsShown()) then return end

        -- One second: the smallest unit the note renders, so a faster tick would repaint an
        -- identical string and a slower one would visibly skip.
        cooldownTimer = WhatGroup:ScheduleRepeatingTimer(function()
            local left = NS.Compat.GetSpellCooldownRemaining(spellID)
            if left > 0 then return renderNote(left) end
            -- Reaching zero is the interesting tick: stop first so the reconfigure below sees
            -- no live handle, then re-run the whole state machine rather than hand-reversing
            -- the four things the cooldown branch changed. The player gets a usable button
            -- without closing the popup, which is the entire point of ticking.
            stopCooldownTicker()
            ConfigureTeleportButton(fields.teleportBtn, fields.teleportIcon, info)
        end, 1)
    else
        note:SetText("")
        note:Hide()
    end
end

local function resolveTeleportState(info)
    local spellID, known = WhatGroup:GetTeleportSpell(info and info.activityID, info and info.mapID)
    NS.Debug("Frame", "teleport spellID=" .. tostring(spellID)
        .. " known=" .. tostring(known)
        .. " (activity=" .. tostring(info and info.activityID)
        .. " map=" .. tostring(info and info.mapID) .. ")")
    if not spellID then return nil end

    local remaining = known and NS.Compat.GetSpellCooldownRemaining(spellID) or 0
    if remaining > 0 then
        NS.Debug("Frame", "teleport on cooldown, %s remaining (spellID=%s)",
            NS.FormatDuration(remaining), NS.SafeToString(spellID))
    end

    return {
        spellID   = spellID,
        known     = known,
        remaining = remaining,
        ready     = known and remaining <= 0,
        spellName = NS.Compat.GetSpellName(spellID),
        texID     = NS.Compat.GetSpellTexture(spellID) or 134400,
    }
end

local function deferTeleportUntilCombatEnds(info)
    if not InCombatLockdown() then return false end
    f._pendingTeleportInfo = info
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(self, ev)
        if ev ~= "PLAYER_REGEN_ENABLED" then return end
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        self:SetScript("OnEvent", nil)
        local pending = self._pendingTeleportInfo
        self._pendingTeleportInfo = nil
        if pending then
            ConfigureTeleportButton(fields.teleportBtn, fields.teleportIcon, pending)
        end
    end)
    return true
end

-- ESC-to-close, through a PROXY rather than the popup (the standalone-windows row in
-- docs/ARCHITECTURE.md's `## Documented deviations`). Blizzard's CloseWindows calls a bare `:Hide()`
-- on every shown UISpecialFrames entry. On WhatGroupFrame that call is protected in combat -- f
-- parents the SecureActionButtonTemplate teleport button -- and the tainted entry blamed this
-- addon: `ADDON_ACTION_BLOCKED ... 'WhatGroupFrame:Hide()'` from ToggleGameMenu, 2026-09-12.
--
-- So the entry is a small frame that owns nothing: no textures, no mouse, no secure children,
-- parented to UIParent. Its Show and Hide are unprotected and legal in combat. It is shown exactly
-- while the popup is on screen (showPopup brings it up; hidePopup and f's OnHide take it down), so
-- Escape with the popup up hides the proxy, counts as a closed window, and the game menu stays shut
-- on that press. Escape with the popup soft-hidden or gone finds nothing and the menu opens.
--
-- Its OnHide routes the press through hidePopup(): a real Hide out of combat, the alpha-0 soft hide
-- with pendingHide in combat, settled at PLAYER_REGEN_ENABLED by ApplyFrameVisibility. The
-- onScreen() check is the recursion guard -- every other hide of the proxy comes from hidePopup or
-- f's OnHide, after the popup has already left the screen, so it does nothing there.
--
-- Built from buildFrame, i.e. on the first ShowFrame, and never at load: the UISpecialFrames insert
-- is one of the two boot-taint sources behind the GameMenu Logout failure (docs/midnight-quirks.md).
local ESC_PROXY_NAME = "WhatGroupFrameEscape"

local function buildEscapeProxy()
    local p = CreateFrame("Frame", ESC_PROXY_NAME, UIParent)
    -- Hidden BEFORE the OnHide is set: frames are born shown, a shown proxy with no popup would eat
    -- the player's next Escape, and this Hide must not reach hidePopup.
    p:Hide()
    p:SetScript("OnHide", function()
        if not onScreen() then return end
        hidePopup()
        -- A player dismissal, so the gate must not reopen it. Set here as the Close button sets it:
        -- in combat hidePopup takes the alpha route and never fires f's OnHide.
        gateWithheld = false
    end)
    tinsert(UISpecialFrames, ESC_PROXY_NAME)
    return p
end

local function buildFrame()
    if f then return end   -- one-shot

    f = CreateFrame("Frame", "WhatGroupFrame", UIParent, "BackdropTemplate")
    f:SetSize(popupSize())
    anchorDefault(f)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    -- Restore the saved position over the default center if the player has moved
    -- the popup before (WG-26; no-op on a fresh profile). Anchored offsets for
    -- the secure teleport button below are computed relative to f, so they stay
    -- aligned wherever f ends up.
    NS.Windows.Restore("popup", f)
    f:Hide()

    -- The ticker's hard stop, and the same reasoning now carries two more passengers. OnHide covers
    -- every REAL hide — the Close button, ESC through the proxy, the gate, a `f:Hide()` from
    -- anywhere — so no exit path has to remember any of them. (The combat soft hide fires no
    -- OnHide; hidePopup and its two player callers cover that route themselves.)
    --
    -- Clearing `gateWithheld` here is what makes a player's dismissal stick: this runs for the
    -- gate's own hide too, and the gate sets the flag back immediately afterwards. Every OTHER hide
    -- therefore leaves it false, which is exactly the answer the re-show arm needs and the one it
    -- could not previously get.
    --
    -- The ESC proxy comes down with the popup, so a later Escape finds no window and opens the game
    -- menu. By now f:IsShown() is false, so the proxy's OnHide sees the popup off screen and stops.
    f:SetScript("OnHide", function(self)
        gateWithheld = false
        stopCooldownTicker(self)
        if escProxy then escProxy:Hide() end
    end)

    -- And OnShow is where it arms, the exact mirror, for the same reason: the ticker is armed only
    -- against a visible popup (see applyTeleportNote), so the arm has to sit on the one seam every
    -- path to the screen crosses. There is more than one such path now — `ShowFrame`, and the
    -- `PLAYER_REGEN_ENABLED` re-evaluation that returns a popup the combat gate had hidden — and a
    -- per-caller arm would be the thing the next path forgets. Re-running the whole configure
    -- rather than starting a timer here keeps ONE owner of the button's state;
    -- ConfigureTeleportButton cancels any live handle first, so it cannot stack. Guarded on
    -- pendingInfo exactly as PopulateFields is: with no capture there is no teleport to draw.
    f:SetScript("OnShow", function()
        if fields and ConfigureTeleportButton and WhatGroup.pendingInfo then
            ConfigureTeleportButton(fields.teleportBtn, fields.teleportIcon, WhatGroup.pendingInfo)
        end
    end)

    -- The whole look — backdrop AND colors — now comes from LibKa0s-Core-1.0's shared SKIN
    -- through NS.ApplySkin (standalone-windows: the Ka0s window edge is normative, and a window
    -- MUST NOT draw one that diverges from it). The popup's own 1px hairline is what the shared
    -- edge already is, so the geometry is unchanged; what it gains is the 1px gray inner highlight
    -- ApplySkin synthesizes, and a black outer border in place of the old gray one.
    --
    -- `f.title` and `f.divider` are assigned first, below, because ApplySkin tints whichever of
    -- them the frame carries and skips the ones it does not — which is why the call itself sits
    -- after the header rather than here. The title's own |cffFFD700 span survives the tint (an
    -- inline color code wins over SetTextColor for its span), and the gold ApplySkin sets is the
    -- color GameFontNormalLarge already renders in, so the header reads exactly as before.

    -- Title bar (drag handle)
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(30)
    titleBar:EnableMouse(true)
    -- LOCKED IS READ AT DRAG TIME, not wired once: the checkbox is a plain profile value with no
    -- onChange, because there is nothing to apply -- the next mouse-down is where it takes effect.
    -- StopMovingOrSizing and the save still run unconditionally; both are harmless on a frame that
    -- never started moving, and guarding them would leave a drag that began before the lock was
    -- ticked stuck to the cursor.
    titleBar:SetScript("OnMouseDown", function()
        local pr = WhatGroup.db and WhatGroup.db.profile
        if pr and pr.locked then return end
        f:StartMoving()
    end)
    titleBar:SetScript("OnMouseUp",   function()
        f:StopMovingOrSizing()
        NS.Windows.Save("popup", f)   -- persist geometry (WG-26)
    end)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("CENTER", titleBar, "CENTER", 0, -2)
    titleText:SetText("|cffFFD700" .. L["WhatGroup"] .. "|r — " .. L["Group Info"])
    f.title = titleText

    -- Separator line under title. The color is set by ApplySkin below (0.24, 0.24, 0.27, 0.85 —
    -- the normative Ka0s divider), so no literal here.
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  14, -30)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -30)
    f.divider = sep

    -- Wear the shared skin, now that the two regions it tints exist.
    NS.ApplySkin(f)

    -- Content frame (plain, no scroll)
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT",     f, "TOPLEFT",   14, -38)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 44)

    -- Label builder
    local function MakeLabel(parent, anchor, yOffset, labelText, valueText)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
        label:SetWidth(LABEL_WIDTH)
        label:SetText("|cffFFD700" .. labelText .. "|r")
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)

        local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        value:SetPoint("TOPLEFT", label, "TOPLEFT", LABEL_WIDTH + 6, 0)
        value:SetJustifyH("LEFT")
        value:SetText(valueText or "")

        return label, value
    end

    local topAnchor = CreateFrame("Frame", nil, content)
    topAnchor:SetSize(1, 1)
    topAnchor:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -4)

    local lblGroup, valGroup = MakeLabel(content, topAnchor, 0,    L["Group:"],     "—")
    local lblInst,  valInst  = MakeLabel(content, lblGroup,  yGap, L["Instance:"],  "—")
    local lblType,  valType  = MakeLabel(content, lblInst,   yGap, L["Type:"],      "—")
    local lblLead,  valLead  = MakeLabel(content, lblType,   yGap, L["Leader:"],    "—")
    local lblStyle, valStyle = MakeLabel(content, lblLead,   yGap, L["Playstyle:"], "—")

    local lblPort = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lblPort:SetPoint("TOPLEFT", lblStyle, "BOTTOMLEFT", 0, yGap)
    lblPort:SetText("|cffFFD700" .. L["Teleport:"] .. "|r")
    lblPort:SetJustifyH("LEFT")
    lblPort:SetWidth(LABEL_WIDTH)
    lblPort:SetWordWrap(false)

    -- Secure cast button — anonymous (no global name), parented directly
    -- to f. The implicit-parent SetPoint form is the only one the
    -- secure-frame system accepts on a protected frame, so we anchor
    -- the button's TOPLEFT against f's TOPLEFT with offsets derived
    -- from the Teleport label's actual rendered position. This way the
    -- button stays aligned with its label even if LABEL_WIDTH, yGap,
    -- or the row count changes — no magic offsets to retune.
    local btnX = (lblPort:GetLeft() - f:GetLeft()) + LABEL_WIDTH + 6
    local btnY = lblPort:GetTop()  - f:GetTop()   -- negative; lblPort sits below f.TOPLEFT

    local teleportBtn = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
    teleportBtn:SetSize(24, 24)
    teleportBtn:SetPoint("TOPLEFT", btnX, btnY)
    -- BOTH edges are required, and this comment is the reason. WG-R-05 offered two resolutions —
    -- "register one click edge" OR "document the PreClick gate as the reason both are needed" —
    -- and this is the second one, taken on measured in-game evidence.
    --
    -- A bare SecureActionButtonTemplate with type="macro" does NOT run its macro on the down
    -- edge. Blizzard's own action buttons cast on down because they opt into it; this button
    -- inherits none of that, so "AnyUp" is the edge that actually executes `/cast`.
    -- Registering "AnyDown" alone is SILENT failure with no Lua error: the button still receives
    -- the down edge — the PreClick trace below proves it, by printing — and nothing is cast.
    -- That regression shipped once, in [M4-24], on the reasoned-but-never-tested premise that two
    -- registered edges meant two casts per press. In the client it means one cast, on the up edge.
    --
    -- The PreClick trace gates on `down` precisely so that carrying both edges still yields
    -- exactly one debug line per press. That gate is what makes the second edge free.
    teleportBtn:RegisterForClicks("AnyUp", "AnyDown")
    teleportBtn:Hide()

    local teleportIcon = teleportBtn:CreateTexture(nil, "ARTWORK")
    teleportIcon:SetAllPoints()

    -- The swipe is the ONLY live element in this popup, and it is live without costing the addon
    -- an OnUpdate or a repeating timer: the Cooldown widget animates engine-side once armed. That
    -- distinction is load-bearing — zero Lua-side repeat is the condition LIBKA0S-15 (issue #7) rests on for
    -- declining LibKa0s-Perf (docs/performance.md). The numbers are hidden because at 24px they
    -- are unreadable, and the note beside the button carries the figure instead.
    local teleportSwipe = CreateFrame("Cooldown", nil, teleportBtn, "CooldownFrameTemplate")
    teleportSwipe:SetAllPoints()
    teleportSwipe:SetHideCountdownNumbers(true)

    -- Sits beside the button rather than on it, for the same reason: a readable sentence at the
    -- popup's own font size, where a 24px overlay would be a smear. Anchored to the Teleport label
    -- (a plain frame region) rather than to the secure button, whose anchoring is restricted.
    local teleportNote = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    teleportNote:SetPoint("TOPLEFT", lblPort, "TOPLEFT", LABEL_WIDTH + 6 + 24 + 8, -6)
    teleportNote:SetJustifyH("LEFT")
    teleportNote:Hide()

    -- (No content:SetHeight here — content's TOPLEFT and BOTTOMRIGHT
    -- anchors fully determine its size, so a SetHeight call would be a
    -- no-op overridden by the anchors.)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 24)
    closeBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
    closeBtn:SetText(L["Close"])
    -- Goes through hidePopup for the reason spelled out at ApplyFrameVisibility: f parents a
    -- SecureActionButtonTemplate button, so f:Hide() is refused in combat and calling it anyway
    -- raised ADDON_ACTION_BLOCKED naming this addon. The press is remembered instead and honored
    -- the moment the lockdown lifts, which is the closest thing to "close" the client permits.
    closeBtn:SetScript("OnClick", function()
        hidePopup()
        -- The player owns this one, so the gate must not undo it on the next combat edge. Set
        -- explicitly rather than left to OnHide: in combat `hidePopup` takes the alpha route and
        -- never fires it.
        gateWithheld = false
    end)

    -- ESC to close — register the PROXY with UISpecialFrames *now*, lazily (buildEscapeProxy says
    -- why it is a proxy and not "WhatGroupFrame"). Earlier versions registered at file-load and that
    -- addition was leaving taint that surfaced on Logout. Deferring it to here means the entry only
    -- exists once the player has actually opened the popup, by which point Blizzard's GameMenu has
    -- already initialized its button callbacks in a clean context.
    escProxy = buildEscapeProxy()

    fields = {
        group        = valGroup,
        instance     = valInst,
        type         = valType,
        leader       = valLead,
        playstyle    = valStyle,
        teleportBtn   = teleportBtn,
        teleportIcon  = teleportIcon,
        teleportSwipe = teleportSwipe,
        teleportNote  = teleportNote,
    }

    -- ConfigureTeleportButton is closed over `teleportBtn` /
    -- `teleportIcon` indirectly via the `fields` table. Defining it
    -- here (inside buildFrame) means it doesn't exist until the popup
    -- exists, which keeps it out of any addon-load-time iteration.
    ConfigureTeleportButton = function(btn, icon, info)
        -- Unconditionally first: every path out of this function either arms a fresh ticker or
        -- wants none, and dropping the old handle here is what keeps repeated shows from stacking.
        stopCooldownTicker()

        if deferTeleportUntilCombatEnds(info) then return end

        local st = resolveTeleportState(info)
        if not st then
            btn:SetAttribute("type", nil)
            btn:SetAttribute("macrotext", nil)
            btn:Hide()
            fields.teleportNote:Hide()
            return
        end
        local spellID, known, remaining, ready = st.spellID, st.known, st.remaining, st.ready
        local spellName, texID = st.spellName, st.texID

        icon:SetTexture(texID)
        icon:SetDesaturated(not ready)
        btn:SetAlpha(ready and 1.0 or 0.5)

        -- Armed with the RAW pair, not the GCD-floored one: the widget draws what it is handed,
        -- and (0, 0) is how a Cooldown frame is cleared. Both branches call it, so a swipe never
        -- outlives the cooldown that armed it.
        local swipe = fields.teleportSwipe
        if remaining > 0 then
            swipe:SetCooldown(NS.Compat.GetSpellCooldownTimes(spellID))
        else
            swipe:SetCooldown(0, 0)
        end

        applyTeleportNote(spellID, known, remaining, info)

        applyTeleportAction(btn, spellID, spellName, known, ready)

        btn:Show()
    end
end

local function PopulateFields()
    local info = WhatGroup.pendingInfo
    if not info then
        local noData = "|cff888888" .. L["No data"] .. "|r"
        fields.group:SetText(noData)
        fields.instance:SetText(noData)
        fields.type:SetText(noData)
        fields.leader:SetText(noData)
        fields.playstyle:SetText("|cff888888—|r")
        fields.teleportBtn:Hide()
        fields.teleportNote:Hide()
        return
    end

    fields.group:SetText(info.title)

    local instText = info.fullName ~= "" and info.fullName or L["Unknown"]
    fields.instance:SetText(instText)

    local Labels = WhatGroup.Labels
    local typeStr = info.shortName ~= "" and info.shortName or Labels.GetGroupTypeLabel(info)
    fields.type:SetText(typeStr)

    fields.leader:SetText(info.leaderName)

    -- Through the sibling of the GetGroupTypeLabel call above, not open-coded: the helper already
    -- prefers the server-rendered playstyleString and falls back to the PLAYSTYLE enum lookup, and
    -- a second copy here is the copy that would keep the old rule the day the helper changes.
    -- Empty string ("") and Enum.LFGEntryGeneralPlaystyle.None (= 0) both come back as "" and fall
    -- through to the dim em-dash placeholder, which stays the POPUP's decision — the chat summary
    -- renders the same absence differently.
    local playStyle = Labels.GetPlaystyleLabel(info)
    fields.playstyle:SetText(playStyle ~= "" and playStyle or "|cff888888—|r")

    ConfigureTeleportButton(fields.teleportBtn, fields.teleportIcon, info)
end

-- Public API
function WhatGroup:ShowFrame()
    -- THE VISIBILITY GATE (options-ui-§15), and it is TWO checks rather than one because the
    -- question is time-varying. Every way the popup reaches the screen -- the join notify,
    -- `/wg show`, the chat link, `/wg test` -- comes through here, so gating here covers them all.
    --
    -- `never` is a standing no, so it refuses before anything is built: adding the secure button
    -- and the UISpecialFrames entry to a session for a window the player has said they never want
    -- is exactly the taint surface this file defers to avoid. The combat-dependent answers cannot
    -- refuse the BUILD, though, or `Only in combat` would deadlock -- the first show would be
    -- refused out of combat, the build would never happen, and the in-combat show would then hit
    -- the never-built defer instead of the popup. So those two are gated at the Show below: the
    -- frame is built and populated on the safe side, and simply not put on screen.
    if (self.db and self.db.profile and self.db.profile.visibility) == "never" then
        NS.Debug("Frame", "popup suppressed: visibility = never")
        return
    end
    -- First-show-in-combat defer: buildFrame creates a
    -- SecureActionButtonTemplate button and inserts into UISpecialFrames;
    -- both operations are protected. If we're in combat AND the popup
    -- has never been built, queue the build on PLAYER_REGEN_ENABLED and
    -- print a chat hint. Once buildFrame has run once, subsequent calls
    -- are safe in combat (only the secure-button reconfigure, handled
    -- by ConfigureTeleportButton's own combat guard, is at risk).
    -- REFUSED IN COMBAT, and it is the show that is refused now, not only the build. Building
    -- creates the secure button and the UISpecialFrames entry, both protected; showing changes a
    -- protected frame's visibility through its ancestor, equally protected. `/wg test` mid-fight
    -- proved the second half in a client after this file spent a release asserting it was safe.
    --
    -- The one case that does NOT defer is a popup still shown at alpha 0: putting that back needs
    -- no protected call at all, only its alpha, which is the exact mirror of how it went away.
    -- That is what keeps "hiding an open popup in combat" reversible rather than one-way.
    if InCombatLockdown() and not (f and f:IsShown()) then
        if WhatGroup._print then
            WhatGroup._print(L["Popup deferred until combat ends."])
        end
        if not WhatGroup._frameBuildQueued then
            WhatGroup._frameBuildQueued = true
            local pending = WhatGroup.pendingInfo
            local waitFrame = CreateFrame("Frame")
            waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            waitFrame:SetScript("OnEvent", function(wf)
                wf:UnregisterAllEvents()
                wf:SetScript("OnEvent", nil)
                WhatGroup._frameBuildQueued = nil
                -- Restore the captured pendingInfo only if it was
                -- cleared (e.g. group-leave) during the wait window;
                -- the user's intent was to see *this* group's popup.
                WhatGroup.pendingInfo = WhatGroup.pendingInfo or pending
                WhatGroup:ShowFrame()
            end)
        end
        return
    end

    buildFrame()    -- lazy: creates the popup + secure button +
                    -- UISpecialFrames entry on first call only.
    -- Every open re-applies the size, the scale and the opacity, so a change taken while the popup
    -- was closed -- or refused because it was taken in combat -- lands here.
    WhatGroup:ApplyFrameSize()
    WhatGroup:ApplyFrameScale()
    WhatGroup:ApplyFrameAlpha()
    do
        local info = WhatGroup.pendingInfo
        NS.Debug("Frame", info
            and ('popup shown "' .. tostring(info.title) .. '" map='
                 .. tostring(info.mapID))
            or "popup shown (no pendingInfo → 'No data' fallbacks)")
    end
    PopulateFields()
    if not visibilityAllows() then
        -- The gate DECLINED a show the player asked for, which is the second of the two states the
        -- re-show arm is allowed to act on. Without this, `Only in combat` would show once on the
        -- next pull and never again — the request would be forgotten the moment it was refused.
        gateWithheld = true
        NS.Debug("Frame", "popup built but not shown: visibility = "
            .. tostring(self.db and self.db.profile and self.db.profile.visibility))
        return
    end
    showPopup()
end
