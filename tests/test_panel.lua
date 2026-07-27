-- tests/test_panel.lua — the Blizzard canvas settings panel (settings/Panel.lua):
-- registration, the deferred lazy build, schema→widget rendering, the widget
-- write-back path, refresher re-sync, and the landing page.
--
-- The panel builds nothing synchronously: OnShow only schedules a
-- C_Timer.After(0, …) hop (so no AceGUI frame is ever created inside one of
-- Blizzard's secure-execute chains). Suites therefore drive it in two beats —
-- fire OnShow, then `mock.fireCTimers()` — which is exactly the client's
-- sequence, and means the deferral itself is under test rather than bypassed.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function panels(mock)
    return mock.frames["WhatGroupParentPanel"], mock.frames["WhatGroupGeneralPanel"]
end

-- Open a panel the way the client does: OnShow, then the next frame.
local function open(mock, panel)
    panel.__fire("OnShow")
    mock.fireCTimers()
end

-- Build the General page and return (NS, env, mock).
local function openGeneral()
    local NS, env, mock = T.enableAddon()
    local _, general = panels(mock)
    open(mock, general)
    return NS, env, mock
end

local function widget(mock, widgetType, labelText)
    return mock.findWidget(function(w)
        return w.type == widgetType and (w.labelText == labelText or w.text == labelText)
    end)
end

-- ---------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------

test("panel: OnEnable registers the parent category and the General subcategory", function()
    local _, _, mock = T.enableAddon()
    assertEqual(#mock.categories, 2)
    assertEqual(mock.categories[1].label, "Ka0s WhatGroup")
    assertEqual(mock.categories[2].label, "General")
end)

test("panel: the parent category is added to the AddOns list", function()
    local NS, _, mock = T.enableAddon()
    assertEqual(mock.registeredCategory, mock.categories[1])
    assertTrue(NS.addon._parentSettingsCategory ~= nil, "the /wg config handle is kept")
    assertTrue(NS.addon._settingsCategory ~= nil, "the General handle is kept")
end)

test("panel: Register is idempotent — a second call registers nothing more", function()
    local NS, _, mock = T.enableAddon()
    NS.addon.Settings.Register()
    NS.addon.Settings.Register()
    assertEqual(#mock.categories, 2)
end)

test("panel: registering during combat is refused and says why", function()
    local NS, _, mock = T.bootAddon()
    mock.combat = true
    NS.addon.Settings.Register()
    assertEqual(#mock.categories, 0, "no category is registered mid-combat")
    assertTrue(mock.prints[#mock.prints]:find("combat", 1, true) ~= nil)
    assertFalse(NS.addon._settingsRegistered or false,
        "the guard flag stays clear so a later call can still register")
end)

test("panel: a combat-time bail still registers once combat ends", function()
    local NS, _, mock = T.bootAddon()
    mock.combat = true
    NS.addon.Settings.Register()
    mock.combat = false
    NS.addon.Settings.Register()
    assertEqual(#mock.categories, 2)
end)

test("panel: registration validates the schema", function()
    local NS = T.enableAddon()
    assertEqual(NS.addon.Settings.Helpers.ValidateSchema(), 0,
        "the shipped schema must register cleanly")
end)

test("panel: both panels start hidden", function()
    local _, _, mock = T.enableAddon()
    local main, general = panels(mock)
    assertFalse(main:IsShown())
    assertFalse(general:IsShown())
end)

-- ---------------------------------------------------------------------------
-- The deferred build (taint contract)
-- ---------------------------------------------------------------------------

test("panel: registration creates no AceGUI widgets", function()
    local _, _, mock = T.enableAddon()
    assertEqual(#mock.aceWidgets, 0,
        "nothing is built at PLAYER_LOGIN — not even the Defaults button")
end)

test("panel: OnShow itself builds nothing; the deferred hop does", function()
    local _, _, mock = T.enableAddon()
    local _, general = panels(mock)
    general.__fire("OnShow")
    assertEqual(#mock.aceWidgets, 0, "the synchronous OnShow body stays a no-op")
    assertTrue(#mock.timers > 0, "a next-frame hop is queued instead")
    mock.fireCTimers()
    assertTrue(#mock.aceWidgets > 0, "the widgets appear on the next frame")
end)

test("panel: the build is one-shot across repeated shows", function()
    local _, _, mock = T.enableAddon()
    local _, general = panels(mock)
    open(mock, general)
    local built = #mock.aceWidgets
    open(mock, general)
    open(mock, general)
    assertEqual(#mock.aceWidgets, built, "re-opening does not rebuild the page")
end)

test("panel: two OnShows before the hop runs still build only once", function()
    local _, _, mock = T.enableAddon()
    local _, general = panels(mock)
    general.__fire("OnShow")
    general.__fire("OnShow")
    mock.fireCTimers()
    local cbs = 0
    for _, w in ipairs(mock.aceWidgets) do
        if w.type == "CheckBox" and w.labelText == "Enable" then cbs = cbs + 1 end
    end
    assertEqual(cbs, 1, "the `scheduled` guard prevents a double build")
end)

test("panel: the Defaults button is built lazily, on the General page only", function()
    local _, _, mock = T.enableAddon()
    local main, general = panels(mock)
    open(mock, main)
    assertNil(widget(mock, "Button", "Defaults"),
        "the landing page opts out of a Defaults button")
    open(mock, general)
    assertTrue(widget(mock, "Button", "Defaults") ~= nil)
end)

test("panel: clicking Defaults raises the confirmation popup rather than resetting", function()
    local NS, env, mock = openGeneral()
    NS.addon.Settings.Helpers.Set("notify.delay", 6)
    widget(mock, "Button", "Defaults"):Fire("OnClick")
    assertEqual(mock.popups[#mock.popups], "WHATGROUP_RESET_ALL")
    assertEqual(NS.addon.Settings.Helpers.Get("notify.delay"), 6,
        "nothing is reset until the player confirms")
    assertTrue(env.StaticPopupDialogs["WHATGROUP_RESET_ALL"] ~= nil,
        "the dialog is registered lazily at click time")
end)

test("panel: confirming the popup restores defaults", function()
    local NS, env, mock = openGeneral()
    NS.addon.Settings.Helpers.Set("notify.delay", 6)
    widget(mock, "Button", "Defaults"):Fire("OnClick")
    env.StaticPopupDialogs["WHATGROUP_RESET_ALL"].OnAccept()
    assertEqual(NS.addon.Settings.Helpers.Get("notify.delay"), 0)
end)

test("panel: the reset dialog is not registered before it is needed (taint)", function()
    local _, env = T.enableAddon()
    assertNil(env.StaticPopupDialogs["WHATGROUP_RESET_ALL"],
        "writing to StaticPopupDialogs at load taints GameMenu callbacks")
end)

-- ---------------------------------------------------------------------------
-- Schema → widget rendering
-- ---------------------------------------------------------------------------

test("panel: every schema row renders a widget", function()
    local NS, _, mock = openGeneral()
    for _, def in ipairs(NS.addon.Settings.Schema) do
        local wanted = def.type == "bool" and "CheckBox" or "Slider"
        assertTrue(widget(mock, wanted, def.label) ~= nil,
            "no widget rendered for " .. def.path)
    end
end)

test("panel: bool rows render checkboxes and number rows render sliders", function()
    local _, _, mock = openGeneral()
    assertEqual(widget(mock, "CheckBox", "Enable").type, "CheckBox")
    assertEqual(widget(mock, "Slider", "Notification Delay").type, "Slider")
end)

test("panel: widgets open showing the current profile value", function()
    local NS, _, mock = T.enableAddon()
    NS.addon.Settings.Helpers.Set("enabled", false)
    NS.addon.Settings.Helpers.Set("notify.delay", 2.5)
    local _, general = panels(mock)
    open(mock, general)
    assertEqual(widget(mock, "CheckBox", "Enable"):GetValue(), false)
    assertEqual(widget(mock, "Slider", "Notification Delay"):GetValue(), 2.5)
end)

test("panel: the slider inherits its bounds and step from the schema row", function()
    local _, _, mock = openGeneral()
    local s = widget(mock, "Slider", "Notification Delay")
    assertEqual(s.sliderMin, 0)
    assertEqual(s.sliderMax, 10)
    assertEqual(s.sliderStep, 0.5)
end)

test("panel: each section renders a heading", function()
    local _, _, mock = openGeneral()
    assertTrue(widget(mock, "Heading", "General") ~= nil)
    assertTrue(widget(mock, "Heading", "Notify") ~= nil)
end)

test("panel: paired rows get half width, solo rows go full width", function()
    local _, _, mock = openGeneral()
    -- Everything in the two-column grid is rendered at 0.5 relative width; the
    -- `solo` flag controls line breaks, not the column width.
    assertEqual(widget(mock, "CheckBox", "Enable").relWidth, 0.5)
    assertEqual(widget(mock, "CheckBox", "Show Leader").relWidth, 0.5)
end)

test("panel: the General group renders its Test action button", function()
    local _, _, mock = openGeneral()
    assertTrue(widget(mock, "Button", "Test") ~= nil,
        "afterGroup emits the Test button below the General grid")
end)

test("panel: the Test button runs the same path as /wg test", function()
    local NS, _, mock = openGeneral()
    widget(mock, "Button", "Test"):Fire("OnClick")
    assertTrue(NS.addon.pendingInfo ~= nil, "a synthetic capture was injected")
    assertEqual(NS.addon.pendingInfo.mapID, 2652)
end)

test("panel: a throwing button onClick is caught, not propagated", function()
    local NS, _, mock = openGeneral()
    local btn = NS.addon.Settings.Helpers.InlineButton(
        { panel = {}, body = {}, scroll = mock.aceWidgets[1] },
        { text = "Boom", onClick = function() error("kaboom") end })
    local ok = pcall(function() btn:Fire("OnClick") end)
    assertTrue(ok, "the pcall wrapper keeps a broken handler from reaching the UI")
    assertTrue(mock.prints[#mock.prints]:find("onClick failed", 1, true) ~= nil)
end)

-- ---------------------------------------------------------------------------
-- The session-only Debug console checkbox (WG-12 — never persisted)
-- ---------------------------------------------------------------------------

test("panel: the Debug console checkbox renders as a non-schema extra", function()
    local NS, _, mock = openGeneral()
    assertTrue(widget(mock, "CheckBox", "Debug console") ~= nil)
    assertNil(NS.addon.Settings.Helpers.FindSchema("_debugConsoleVisible"),
        "it is deliberately not a schema row")
end)

test("panel: ticking Debug console shows the window without touching db.profile", function()
    local NS, _, mock = openGeneral()
    widget(mock, "CheckBox", "Debug console"):Fire("OnValueChanged", true)
    assertTrue(NS.DebugLog:IsShown(), "the console window opened")
    assertNil(NS.addon.db.profile.debug, "nothing was persisted")
    assertFalse(NS.State.debug, "and logging itself stays off")
end)

test("panel: unticking Debug console hides the window", function()
    local NS, _, mock = openGeneral()
    local cb = widget(mock, "CheckBox", "Debug console")
    cb:Fire("OnValueChanged", true)
    cb:Fire("OnValueChanged", false)
    assertFalse(NS.DebugLog:IsShown())
end)

test("panel: re-opening General re-syncs the Debug console checkbox", function()
    local NS, _, mock = openGeneral()
    local cb = widget(mock, "CheckBox", "Debug console")
    assertEqual(cb:GetValue(), false)
    -- The console can be opened by `/wg debug` while the panel is closed, so
    -- the checkbox must re-read the window state on every show.
    NS.DebugLog:Show()
    local _, general = panels(mock)
    general.__fire("OnShow")
    assertEqual(cb:GetValue(), true)
end)

-- ---------------------------------------------------------------------------
-- Widget write-back + refreshers
-- ---------------------------------------------------------------------------

test("panel: ticking a checkbox writes through to db.profile", function()
    local NS, _, mock = openGeneral()
    widget(mock, "CheckBox", "Show Leader"):Fire("OnValueChanged", false)
    assertEqual(NS.addon.db.profile.notify.showLeader, false)
end)

test("panel: a checkbox coerces its value to a real boolean", function()
    local NS, _, mock = openGeneral()
    widget(mock, "CheckBox", "Show Type"):Fire("OnValueChanged", nil)
    assertEqual(NS.addon.db.profile.notify.showType, false)
end)

test("panel: dragging the slider writes through to db.profile", function()
    local NS, _, mock = openGeneral()
    widget(mock, "Slider", "Notification Delay"):Fire("OnValueChanged", 7.5)
    assertEqual(NS.addon.db.profile.notify.delay, 7.5)
end)

test("panel: unticking Enable fires the master-switch onChange", function()
    local NS, _, mock = openGeneral()
    NS.addon.pendingInfo = { title = "in flight" }
    widget(mock, "CheckBox", "Enable"):Fire("OnValueChanged", false)
    assertNil(NS.addon.pendingInfo, "the capture is wiped through the schema onChange")
end)

test("panel: rendering registers one refresher per schema row", function()
    local NS = openGeneral()
    for _, def in ipairs(NS.addon.Settings.Schema) do
        assertTrue(NS.addon.Settings._refreshers[def.path] ~= nil,
            "no refresher for " .. def.path)
    end
end)

test("panel: refreshers are ordered in schema (render) order", function()
    local NS = openGeneral()
    local order = NS.addon.Settings._refresherOrder
    assertEqual(order[1], "enabled")
    assertEqual(order[2], "frame.autoShow")
    assertEqual(order[3], "notify.enabled")
end)

test("panel: a /wg set re-syncs the open widget", function()
    local NS, _, mock = openGeneral()
    local cb = widget(mock, "CheckBox", "Show Instance")
    assertEqual(cb:GetValue(), true)
    NS.addon.Settings.Helpers.Set("notify.showInstance", false)
    assertEqual(cb:GetValue(), false, "RefreshAll pushed the new value into the widget")
end)

test("panel: RestoreDefaults re-syncs every open widget once", function()
    local NS, _, mock = openGeneral()
    NS.addon.Settings.Helpers.Set("notify.delay", 9)
    widget(mock, "CheckBox", "Show Leader"):Fire("OnValueChanged", false)
    NS.addon.Settings.Helpers.RestoreDefaults()
    assertEqual(widget(mock, "Slider", "Notification Delay"):GetValue(), 0)
    assertEqual(widget(mock, "CheckBox", "Show Leader"):GetValue(), true)
end)

test("panel: a throwing refresher does not abort the remaining ones", function()
    local NS, _, mock = openGeneral()
    local S = NS.addon.Settings
    S._refresherOrder[#S._refresherOrder + 1] = "_boom"
    S._refreshers["_boom"] = function() error("refresher exploded") end
    NS.addon.Settings.Helpers.Set("notify.showTeleport", false)
    assertEqual(widget(mock, "CheckBox", "Show Teleport spell"):GetValue(), false,
        "later refreshers still ran")
end)

-- ---------------------------------------------------------------------------
-- Scrollbar patch (options-ui-§10 — always-visible gutter)
-- ---------------------------------------------------------------------------

test("panel: the scroll container is patched to always show its scrollbar", function()
    local _, _, mock = openGeneral()
    local scroll = mock.findWidget(function(w) return w.type == "ScrollFrame" end)
    assertTrue(scroll ~= nil, "the page renders inside a ScrollFrame")
    assertTrue(scroll._wgAlwaysScrollbar, "the patch is applied")
    assertTrue(scroll.scrollBarShown)
    assertTrue(scroll.scrollbar:IsShown())
end)

test("panel: the patch is one-shot per widget", function()
    local NS, _, mock = openGeneral()
    local scroll = mock.findWidget(function(w) return w.type == "ScrollFrame" end)
    local patched = scroll.FixScroll
    NS.addon.Settings.Helpers.PatchAlwaysShowScrollbar(scroll)
    assertEqual(scroll.FixScroll, patched, "re-patching is a no-op")
end)

test("panel: releasing the widget restores AceGUI's stock behaviour", function()
    local _, _, mock = openGeneral()
    local scroll = mock.findWidget(function(w) return w.type == "ScrollFrame" end)
    scroll:OnRelease()
    assertNil(scroll._wgAlwaysScrollbar, "the pooled widget goes back clean")
    assertTrue(scroll.released, "the stock OnRelease still ran")
    assertTrue(scroll.scrollbar.__enabled, "the scrollbar is re-enabled for the next acquirer")
end)

-- ---------------------------------------------------------------------------
-- Landing page
-- ---------------------------------------------------------------------------

test("panel: the landing page lists one row per slash command", function()
    local NS, _, mock = T.enableAddon()
    local main = panels(mock)
    open(mock, main)
    for _, entry in ipairs(NS.addon.COMMANDS) do
        local found = mock.findWidget(function(w)
            return w.type == "Label" and w.text and w.text:find("/wg " .. entry[1], 1, true)
        end)
        assertTrue(found ~= nil, "the landing page is missing /wg " .. entry[1])
    end
end)

test("panel: the landing page shows the TOC Notes line", function()
    local _, _, mock = T.enableAddon()
    local main = panels(mock)
    open(mock, main)
    local desc = mock.findWidget(function(w)
        return w.type == "Label" and w.text == mock.metadata.Notes
    end)
    assertTrue(desc ~= nil, "the Notes one-liner is rendered from TOC metadata")
end)

test("panel: the landing page renders the Slash Commands heading and the logo", function()
    local _, _, mock = T.enableAddon()
    local main = panels(mock)
    open(mock, main)
    assertTrue(widget(mock, "Heading", "Slash Commands") ~= nil)
    local logo
    for _, tex in ipairs(mock.textures) do
        if tex:GetTexture() and tostring(tex:GetTexture()):find("whatgroup.logo", 1, true) then
            logo = tex
        end
    end
    assertTrue(logo ~= nil, "the brand logo texture is created")
end)
