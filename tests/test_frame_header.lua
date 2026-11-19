-- tests/test_frame_header.lua — the popup's title-bar marks (LibKa0s#86, AD-86-WG; standalone-windows,
-- *Title-bar controls*, WowAddonStandards v2.113.0). The popup's title bar reads lock · settings · close
-- (the lock from AF-HDR-WG: standalone-windows, *Which marks a window owes*, v2.115.0),
-- right-aligned, built by LibKa0s-Widgets-1.0's W.HeaderButtons (modules/FrameLayout.lua): the
-- settings mark opens WhatGroup's settings through the opener the launcher registered for the
-- folder, and the close mark runs the same dismissPopup body the footer Close button and Escape run,
-- so a close in combat soft-hides rather than calling a refused f:Hide(). Both go mouse-dead with the
-- combat soft hide (frame-layering-§4) and come back on every show. The header lays them on the
-- skin's band through S.Header's `right`, at the offsets HeaderButtons laid them.
--
-- Every case builds its own instance (tests/run.lua), so no state leaks between cases.

local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local Fx = dofile("tests/frame_fixture.lua")
local pending, popup, dragHandle = Fx.pending, Fx.popup, Fx.dragHandle

local OWNER = "WhatGroup"

local function shown(NS, mock)
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    local f = popup(mock)
    assertTrue(f and f:IsShown(), "the popup is up")
    return f
end

--- The strip HeaderButtons answered, which it sets on `spec.frame` (the popup).
local function strip(mock)
    local f = popup(mock)
    local hb = f and rawget(f, "headerButtons")
    assertTrue(type(hb) == "table", "the popup carries no headerButtons: its marks are not W.HeaderButtons'")
    return hb
end

test("popup header: the title bar reads lock · settings · close through W.HeaderButtons", function()
    -- red under: a title bar with no marks (the popup before AD-86-WG), marks built by hand, or no
    -- lock (the popup before AF-HDR-WG; standalone-windows, *Which marks a window owes*).
    local NS, _, mock = T.bootAddon()
    shown(NS, mock)
    local hb = strip(mock)
    assertEqual(table.concat(hb.order, ","), "lock,settings,close", "left to right: lock, settings, close")
    assertTrue(hb.settings ~= nil, "a settings mark")
    assertTrue(hb.close ~= nil, "a close mark")
    assertTrue(hb.optOut == nil, "no opt-out")
    local bar = dragHandle(mock)
    assertTrue(rawget(hb.settings, "__parent") == bar, "the settings mark is on the title bar")
    assertTrue(rawget(hb.close, "__parent") == bar, "the close mark is on the title bar")
end)

test("popup header: the marks sit right-aligned at the strip's one pitch, close in the corner", function()
    -- red under: a hand-placed gear or X at its own offset, or the order reversed.
    local NS, _, mock = T.bootAddon()
    shown(NS, mock)
    local hb = strip(mock)
    local W = mock.LibStub("LibKa0s-Widgets-1.0")
    local H = W.HEADER
    assertEqual(hb.offsets.close, -H.PAD, "the close mark PAD in from the corner")
    assertEqual(hb.offsets.settings, -(H.PAD + H.SIZE + H.GAP), "settings one mark and one GAP inward")
end)

test("popup header: S.Header lays the marks on the band at the strip's offsets", function()
    -- red under: S.Header called without `right`, which leaves the marks where the build put them
    -- while the skin moves the bar onto its band.
    local NS, _, mock = T.bootAddon()
    shown(NS, mock)
    local hb = strip(mock)
    local rec = mock.LibStub("LibKa0s-Skin-1.0").painted[popup(mock)]
    assertTrue(rec ~= nil and rec.owner == OWNER and rec.calls.Header ~= nil, "the popup's header is the owner's")
    local spec = rec.calls.Header[1]
    assertTrue(type(spec) == "table" and spec.right == hb.right, "S.Header takes HeaderButtons' `right`")
end)

test("popup header: the settings mark's click opens WhatGroup's settings through the launcher", function()
    -- red under: settings = false, or a settings mark wired to anything but the registered opener.
    local NS, _, mock = T.enableAddon()
    shown(NS, mock)
    local hb = strip(mock)
    local opened = 0
    NS.addon.OpenSettings = function() opened = opened + 1 end
    hb.settings.__scripts.OnClick(hb.settings, "LeftButton")
    assertEqual(opened, 1, "one click opens the settings once")
    assertTrue(popup(mock):IsShown(), "no hideOnSettings: the popup stays above the panel it is previewed from")
end)

test("popup header: the settings mark in combat leaves the popup exactly as it was", function()
    -- red under: a `settings` that hides the popup before the opener (the hideOnSettings reversal
    -- POPUP-13 leaves to the owner) without the combat soft hide, or any protected write on the click.
    -- The opener refuses in combat on its own; the gear must not lose the popup on the way.
    local NS, _, mock = T.bootAddon()
    local f = shown(NS, mock)
    local hb = strip(mock)
    local opened = 0
    NS.addon.OpenSettings = function() opened = opened + 1 end
    mock.combat = true
    hb.settings.__scripts.OnClick(hb.settings, "LeftButton")
    assertEqual(opened, 1, "the click still reaches the opener, which owns the combat refusal")
    assertTrue(f:IsShown(), "the popup stays shown")
    assertEqual(f:GetAlpha(), 1, "and is not soft-hidden")
    assertEqual(#mock.blocked, 0, "nothing protected was written: " .. table.concat(mock.blocked, ","))
end)

test("popup header: every mark carries its tooltip, settings' own words and the close's Close", function()
    -- red under: a mark built without a tip, or a close with no title tip hooked (SR-L2).
    local NS, _, mock = T.bootAddon()
    shown(NS, mock)
    local hb = strip(mock)
    assertEqual(hb.settings.__tip, mock.LibStub("LibKa0s-Widgets-1.0").HEADER_STRINGS.SETTINGS_TIP)
    assertTrue(rawget(hb.close, "__titleTip") ~= nil, "the close mark carries the close tooltip")
end)

test("popup header: the settings mark is the owner's Mark, so it rests in icon.tint and lights text.link", function()
    -- red under: a mark built with no owner (Ka0s Default's two colors under every skin, never repainted).
    local NS, _, mock = T.bootAddon()
    shown(NS, mock)
    local hb = strip(mock)
    local icon = hb.settings.icon
    assertTrue(icon ~= nil, "the settings mark draws the catalog's settings art")
    local rec = mock.LibStub("LibKa0s-Skin-1.0").painted[icon]
    assertTrue(rec ~= nil and rec.owner == OWNER and rec.calls.Mark ~= nil, "the art is painted by the owner's Mark")
    hb.settings.__scripts.OnEnter(hb.settings)
    local hot = rec.calls.Mark[1]
    assertTrue(type(hot) == "table" and hot.token == "text.link", "under the pointer it lights text.link")
    hb.settings.__scripts.OnLeave(hb.settings)
    assertTrue((rec.calls.Mark[1] or {}).token == nil, "and rests again in icon.tint (no token: the default)")
end)

test("popup header: the close mark runs dismissPopup, out of combat a real hide", function()
    -- red under: HeaderButtons' default close (a bare f:Hide()).
    local NS, _, mock = T.bootAddon()
    local f = shown(NS, mock)
    local hb = strip(mock)
    hb.close.__scripts.OnClick(hb.close, "LeftButton")
    assertFalse(f:IsShown(), "the close mark closes the popup")
end)

test("popup header: the close mark in combat soft-hides and writes nothing protected", function()
    -- red under: a bare f:Hide() in the close mark's click, which the client refuses in combat
    -- (f parents a SecureActionButtonTemplate) and attributes to the addon.
    local NS, _, mock = T.bootAddon()
    local f = shown(NS, mock)
    local hb = strip(mock)
    mock.combat = true
    hb.close.__scripts.OnClick(hb.close, "LeftButton")
    assertEqual(f:GetAlpha(), 0, "the alpha-0 soft hide")
    assertEqual(#mock.blocked, 0, "nothing protected was written: " .. table.concat(mock.blocked, ","))
end)

-- ---------------------------------------------------------------------------
-- The lock mark (AF-HDR-WG; standalone-windows, *Which marks a window owes*, v2.115.0)
-- ---------------------------------------------------------------------------
--
-- The popup is this addon's primary window, so its header carries a lock beside the settings and
-- close marks: a W.HeaderButtons `extras` entry whose click is the one lock seam the launcher's
-- Locked entry and `/wg lock` also reach (WhatGroup:SlashToggleLock, the `locked` row's write), and
-- whose art and tooltip are repainted from profile.locked whenever the row changes, from any surface.

local function lockMark(mock)
    local hb = strip(mock)
    local b = hb.extras and hb.extras.lock
    assertTrue(b ~= nil, "the popup carries a lock mark among its extras")
    return b
end

local function art(b) return b.icon and b.icon:GetTexture() end

test("popup header: the lock mark draws unlock and offers to lock while the popup is unlocked", function()
    -- red under: no lock mark, a mark drawing `lock` on an unlocked popup, or a tip that names the
    -- state rather than what a click does.
    local NS, _, mock = T.bootAddon()
    shown(NS, mock)
    local b = lockMark(mock)
    assertFalse(NS.addon.db.profile.locked, "unlocked by default")
    assertTrue(art(b) ~= nil and art(b) == NS.Icon("unlock"), "the catalog's unlock art")
    assertEqual(b.__tip, NS.L["Lock the popup in place"], "the tip says what a click does")
end)

test("popup header: a popup first shown locked builds its lock mark locked", function()
    -- red under: art chosen once from the default rather than read from the profile at build.
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.locked = true
    shown(NS, mock)
    local b = lockMark(mock)
    assertEqual(art(b), NS.Icon("lock"), "the catalog's lock art")
    assertEqual(b.__tip, NS.L["Unlock the popup so it can be dragged"])
end)

test("popup header: the lock mark's click runs SlashToggleLock and repaints from the profile", function()
    -- red under: a click that writes db.profile.locked itself (a second lock path), or art and tip
    -- left as built after the write.
    local NS, _, mock = T.bootAddon()
    shown(NS, mock)
    local b = lockMark(mock)
    local original, calls = NS.addon.SlashToggleLock, 0
    NS.addon.SlashToggleLock = function(self) calls = calls + 1; return original(self) end
    b.__scripts.OnClick(b, "LeftButton")
    assertEqual(calls, 1, "one click, one toggle through the launcher's seam")
    assertTrue(NS.addon.db.profile.locked, "the popup is locked")
    assertEqual(art(b), NS.Icon("lock"), "the mark now draws lock")
    assertEqual(b.__tip, NS.L["Unlock the popup so it can be dragged"], "and offers to unlock")
    b.__scripts.OnClick(b, "LeftButton")
    assertFalse(NS.addon.db.profile.locked, "a second click unlocks")
    assertEqual(art(b), NS.Icon("unlock"))
end)

--- A tooltip stand-in that tracks its owner and its text, so a hovered mark's tip is assertable.
local function recordingTip(mock)
    local tip = { shown = false }
    function tip:SetOwner(o) self.owner = o end
    function tip:IsOwned(o) return self.shown and self.owner == o end
    function tip:SetText(t) self.text = t end
    function tip:Show() self.shown = true end
    function tip:Hide() self.shown = false; self.owner = nil end
    tip.ClearAllPoints = function() end
    tip.SetPoint = function() end
    mock.GameTooltip = tip
    return tip
end

test("popup header: a click under the pointer re-shows the lock mark's tooltip with the new words", function()
    -- red under: PaintLock swapping __tip only, so the open tooltip keeps the old words until the
    -- next hover (POPUP-14 reads the new tip right after the click); or a repaint that shows a tip
    -- the mark does not own.
    local NS, _, mock = T.bootAddon()
    shown(NS, mock)
    local b = lockMark(mock)
    local tip = recordingTip(mock)
    b.__scripts.OnEnter(b)
    assertEqual(tip.text, NS.L["Lock the popup in place"], "the hover shows what a click does")
    b.__scripts.OnClick(b, "LeftButton")
    assertTrue(tip:IsOwned(b), "the tip stays up on the mark")
    assertEqual(tip.text, NS.L["Unlock the popup so it can be dragged"], "and now offers to unlock")
    b.__scripts.OnLeave(b)
    NS.addon:OnSlashCommand("unlock")
    assertFalse(tip.shown, "a repaint with the pointer elsewhere shows no tip")
end)

test("popup header: the lock mark follows the row whichever surface writes it", function()
    -- red under: a repaint wired to the mark's click alone, so `/wg lock`, `/wg set locked`, the
    -- Lock frame checkbox and the launcher's Locked entry leave the mark showing the old state.
    local NS, _, mock = T.bootAddon()
    shown(NS, mock)
    local b = lockMark(mock)
    NS.addon:OnSlashCommand("lock")
    assertEqual(art(b), NS.Icon("lock"), "/wg lock")
    NS.addon:OnSlashCommand("unlock")
    assertEqual(art(b), NS.Icon("unlock"), "/wg unlock")
    NS.addon:OnSlashCommand("set locked true")
    assertEqual(art(b), NS.Icon("lock"), "/wg set locked true")
    NS.addon.Settings.Helpers.Set("locked", false)
    assertEqual(art(b), NS.Icon("unlock"), "the Lock frame checkbox's write")
    NS.addon:SlashToggleLock()
    assertEqual(art(b), NS.Icon("lock"), "the launcher's Locked entry")
end)

test("popup header: a profile switch repaints the lock mark from the incoming profile", function()
    -- red under: a repaint only on the row's onChange, which a profile event never fires.
    local NS, _, mock = T.bootAddon()
    shown(NS, mock)
    local b = lockMark(mock)
    NS.addon.db.profile.locked = true
    NS.addon:OnProfileChanged(nil, nil, "Default")
    assertEqual(art(b), NS.Icon("lock"), "the incoming profile is locked")
    assertEqual(b.__tip, NS.L["Unlock the popup so it can be dragged"])
end)

test("popup header: the lock mark is the owner's Mark and carries a hover tooltip", function()
    -- red under: a lock mark built with no owner, so it never takes the skin's icon.tint / text.link.
    local NS, _, mock = T.bootAddon()
    shown(NS, mock)
    local b = lockMark(mock)
    local rec = mock.LibStub("LibKa0s-Skin-1.0").painted[b.icon]
    assertTrue(rec ~= nil and rec.owner == OWNER and rec.calls.Mark ~= nil, "painted by the owner's Mark")
    assertTrue(type(b.__scripts.OnEnter) == "function", "a hover handler shows the tip")
end)

test("popup header: with LibKa0s absent the popup builds with no marks and still closes", function()
    -- red under: an unguarded W.HeaderButtons call on a library-less install.
    local NS, _, mock = T.newAddon{ skip = T.loadAddon.libFiles }
    NS.addon:OnInitialize()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    local f = popup(mock)
    assertTrue(f ~= nil and f:IsShown(), "the popup still opens")
    assertTrue(rawget(f, "headerButtons") == nil, "no marks without the library")
    Fx.closeButton(mock).__scripts.OnClick()
    assertFalse(f:IsShown(), "the footer Close still closes")
end)
