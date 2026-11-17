-- tests/test_frame_header.lua — the popup's title-bar marks (LibKa0s#86, AD-86-WG; standalone-windows,
-- *Title-bar controls*, WowAddonStandards v2.113.0). The popup's title bar reads settings · close,
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

test("popup header: the title bar reads settings · close through W.HeaderButtons", function()
    -- red under: a title bar with no marks (the popup before AD-86-WG), or marks built by hand.
    local NS, _, mock = T.bootAddon()
    shown(NS, mock)
    local hb = strip(mock)
    assertEqual(table.concat(hb.order, ","), "settings,close", "left to right: settings, close")
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
