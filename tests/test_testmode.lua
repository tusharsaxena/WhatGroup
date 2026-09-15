-- tests/test_testmode.lua — the popup's test mode (options-ui-§15, preview-mode): the session-only
-- `Test mode` checkbox in General > Master controls, composed from `testModePath`, that puts the
-- popup up with placeholder group info and leaves it there until it is turned off.
--
-- What it must never do is touch `pendingInfo`: the placeholder is a record of its own, so a real
-- capture the player is still holding survives a round of placing the popup. And it must never be
-- on in a fight: it is refused in combat and ends at PLAYER_REGEN_DISABLED, because the popup
-- parents a secure button.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local PATH = "state.testMode"

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local body = f:read("*a")
    f:close()
    return body
end

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

local function popup(mock) return mock.frames["WhatGroupFrame"] end

local function onScreen(mock)
    local f = popup(mock)
    return f ~= nil and f:IsShown() and f:GetAlpha() > 0
end

-- The Group row's value: the second FontString on the popup's content frame, which is the popup
-- child carrying the most FontStrings (tests/test_frame.lua's `fields` explains the layout).
local function groupText(mock)
    local content, most = nil, 0
    for _, kid in ipairs(popup(mock).__children or {}) do
        local n = #(kid.__fontStrings or {})
        if n > most then content, most = kid, n end
    end
    assertTrue(content ~= nil, "the popup content frame must exist")
    return content.__fontStrings[2]:GetText()
end

local function closeButton(mock)
    for _, kid in ipairs(popup(mock).__children or {}) do
        if kid.__text == "Close" and kid.__scripts and kid.__scripts.OnClick then return kid end
    end
end

local function pressEscape(mock)
    for _, name in ipairs(mock.UISpecialFrames) do
        local fr = mock.frames[name]
        if fr and fr:IsShown() then fr:Hide() end
    end
end

local function printedSince(mock, mark, needle)
    for i = mark + 1, #mock.prints do
        if mock.prints[i]:find(needle, 1, true) then return true end
    end
    return false
end

-- The General page, open on its first tab (Master controls), the way the client opens it.
local function openGeneral()
    local NS, env, mock = T.enableAddon()
    local general = mock.frames["WhatGroupGeneralPanel"]
    general:Show()
    mock.fireCTimers()
    return NS, env, mock
end

-- The LAST checkbox with this label: a refresh can re-render, and the stale widget stays in the
-- mock's ledger.
local function checkbox(mock, label)
    local found
    for _, w in ipairs(mock.aceWidgets) do
        if w.type == "CheckBox" and w.labelText == label then found = w end
    end
    return found
end

local function on(NS)  NS.addon.Settings.Helpers.Set(PATH, true)  end
local function isOn(NS) return NS.addon.Settings.Helpers.Get(PATH) end

-- `/wg test <rest>`, through the COMMANDS row the dispatcher runs (handler takes `rest` alone).
local function wgTest(NS, rest)
    for _, c in ipairs(NS.addon.COMMANDS) do
        if c[1] == "test" then return c[3](rest or "") end
    end
    error("no test verb")
end

-- ---------------------------------------------------------------------------
-- The verb: `/wg test` IS the test mode, on the checkbox's own setter
-- ---------------------------------------------------------------------------

test("testmode: bare /wg test toggles test mode, and the checkbox follows", function()
    -- red under: /wg test still running the one-shot RunTest flow.
    local NS, _, mock = openGeneral()
    NS.addon.pendingInfo = pending()
    wgTest(NS, "")
    assertTrue(isOn(NS), "the first /wg test turns it on")
    assertTrue(onScreen(mock))
    assertEqual(groupText(mock), NS.addon:SampleInfo().title, "showing the sample")
    assertEqual(NS.addon.pendingInfo.title, "Stonevault Speedrun", "and no capture was injected")
    assertEqual(checkbox(mock, "Test mode"):GetValue(), true, "the box follows the verb")
    wgTest(NS, "")
    assertFalse(isOn(NS), "the second turns it off")
    assertFalse(onScreen(mock))
    assertEqual(checkbox(mock, "Test mode"):GetValue(), false)
end)

test("testmode: /wg test on|off sets it, and repeating either changes nothing", function()
    local NS, _, mock = T.enableAddon()
    wgTest(NS, "on")
    assertTrue(isOn(NS))
    wgTest(NS, "ON")
    assertTrue(isOn(NS), "on is on, whatever it was; case-insensitive")
    assertTrue(onScreen(mock))
    wgTest(NS, "off")
    assertFalse(isOn(NS))
    wgTest(NS, "off")
    assertFalse(isOn(NS), "off is off")
    assertFalse(onScreen(mock))
end)

test("testmode: /wg test in combat is refused with one line and leaves it off", function()
    -- options-ui-§15 (v2.48.0): a start during combat is refused, with one line, box unticked.
    local NS, _, mock = openGeneral()
    mock.combat = true
    local mark = #mock.prints
    wgTest(NS, "")
    assertFalse(isOn(NS), "refused")
    assertEqual(#mock.prints - mark, 1, "one line")
    assertTrue(printedSince(mock, mark, "cannot start test mode during combat"))
    assertEqual(#mock.blocked, 0, "no protected call was attempted")
    assertEqual(checkbox(mock, "Test mode"):GetValue(), false, "the box stays unticked")
    wgTest(NS, "on")
    assertFalse(isOn(NS), "/wg test on is refused the same way")
end)

test("testmode: /wg test with an unknown word prints usage and changes nothing", function()
    local NS, _, mock = T.enableAddon()
    local mark = #mock.prints
    wgTest(NS, "sideways")
    assertFalse(isOn(NS))
    assertNil(NS.addon.pendingInfo, "and no one-shot flow ran either")
    assertTrue(printedSince(mock, mark, "/wg test"), "the usage names the verb")
end)

test("testmode: the COMMANDS row describes the mode and the notify sub-word", function()
    local NS = T.newAddon()
    local desc
    for _, c in ipairs(NS.addon.COMMANDS) do
        if c[1] == "test" then desc = c[2] end
    end
    assertTrue(desc ~= nil and desc:find("test mode", 1, true) ~= nil, tostring(desc))
    assertTrue(desc:find("notify", 1, true) ~= nil, "it names /wg test notify")
end)

-- ---------------------------------------------------------------------------
-- The row (options-ui-§15)
-- ---------------------------------------------------------------------------

test("testmode: the Test mode row is composed right after the Debug console, on its own line",
function()
    -- red under: no `testModePath` in the MasterControls call, or a hand-written row.
    local NS = T.newAddon()
    local S = NS.addon.Settings.Schema
    local at
    for i, row in ipairs(S) do
        if row.path == PATH then at = i end
    end
    assertTrue(at ~= nil, "the row exists")
    assertEqual(S[at - 1].path, "state.debugConsole", "directly below Lock frame / Debug console")
    local row = S[at]
    assertEqual(row.label, "Test mode")
    assertEqual(row.type, "bool")
    assertEqual(row.group, "Master controls")
    assertTrue(row.sessionOnly, "session-only")
    assertTrue(row.startsLine, "it starts its own line")
    assertEqual(row.default, false, "declared default = false, so Reset all settings ends it")
    assertNil(readFile("settings/Schema.lua"):match('path%s*=%s*"state%.testMode"'),
        "composed by the library, never declared by hand")
    assertTrue(readFile("settings/Panel.lua"):find('testModePath%s*=%s*"state%.testMode"') ~= nil,
        "handed to the composer as testModePath")
end)

test("testmode: the row's tooltip is this addon's, not the composer's generic one", function()
    local NS = T.newAddon()
    local tip = NS.addon.Settings.Helpers.FindSchema(PATH).tooltip
    assertTrue(type(tip) == "string" and tip:find("popup", 1, true) ~= nil,
        "it says what test mode shows here: " .. tostring(tip))
end)

test("testmode: it is session-only and never reaches db.profile", function()
    local NS = T.bootAddon()
    assertFalse(isOn(NS), "off at login")
    assertNil(NS.addon.Settings.BuildDefaults().profile.state, "no default is stored for it")
    on(NS)
    assertTrue(isOn(NS))
    assertNil(NS.addon.db.profile.state, "nothing was written to the profile")
    assertNil(NS.addon.db.profile.testMode)
end)

-- ---------------------------------------------------------------------------
-- On and off
-- ---------------------------------------------------------------------------

test("testmode: ticking the box shows the popup with placeholder content, pendingInfo untouched",
function()
    local NS, _, mock = openGeneral()
    local real = pending()
    NS.addon.pendingInfo = real
    checkbox(mock, "Test mode"):Fire("OnValueChanged", true)
    assertTrue(isOn(NS), "the mode is on")
    assertTrue(onScreen(mock), "the popup is up")
    assertEqual(groupText(mock), NS.addon:SampleInfo().title, "showing the placeholder capture")
    assertEqual(NS.addon.pendingInfo, real, "the real capture is the same table, untouched")
    assertEqual(NS.addon.pendingInfo.title, "Stonevault Speedrun")
    assertEqual(checkbox(mock, "Test mode"):GetValue(), true, "and the box reads ticked")
end)

test("testmode: with no capture at all, it still shows the placeholder and leaves pendingInfo nil",
function()
    local NS, _, mock = T.enableAddon()
    on(NS)
    assertTrue(onScreen(mock))
    assertEqual(groupText(mock), NS.addon:SampleInfo().title)
    assertNil(NS.addon.pendingInfo, "test mode never injects a capture")
end)

test("testmode: it shows the popup whatever General visibility and Open Automatically say",
function()
    -- An explicit request to see the popup, so neither the join-time autoShow nor the visibility
    -- gate applies to it.
    local NS, _, mock = T.enableAddon()
    local H = NS.addon.Settings.Helpers
    H.Set("visibility", "never")
    H.Set("frame.autoShow", false)
    on(NS)
    assertTrue(onScreen(mock), "visibility = never does not stop test mode")
    H.Set("visibility", "outOfCombat")
    H.Set("visibility", "always")
    assertTrue(onScreen(mock), "and moving the gate while it is up does not take it down")
end)

test("testmode: unticking hides the popup and puts the real capture back", function()
    local NS, _, mock = openGeneral()
    NS.addon.pendingInfo = pending()
    local cb = checkbox(mock, "Test mode")
    cb:Fire("OnValueChanged", true)
    checkbox(mock, "Test mode"):Fire("OnValueChanged", false)
    assertFalse(isOn(NS))
    assertFalse(onScreen(mock), "the popup went away with the mode")
    assertEqual(checkbox(mock, "Test mode"):GetValue(), false)
    NS.addon:ShowFrame()
    assertEqual(groupText(mock), "Stonevault Speedrun", "the real capture is what shows next")
end)

test("testmode: the popup's Close button ends test mode and unticks the box", function()
    local NS, _, mock = openGeneral()
    checkbox(mock, "Test mode"):Fire("OnValueChanged", true)
    local btn = closeButton(mock)
    btn.__scripts.OnClick(btn)
    assertFalse(onScreen(mock))
    assertFalse(isOn(NS), "closing the placeholder popup turns test mode off")
    assertEqual(checkbox(mock, "Test mode"):GetValue(), false, "and the box follows")
end)

test("testmode: ESC ends test mode and unticks the box", function()
    local NS, _, mock = openGeneral()
    checkbox(mock, "Test mode"):Fire("OnValueChanged", true)
    pressEscape(mock)
    assertFalse(onScreen(mock))
    assertFalse(isOn(NS))
    assertEqual(checkbox(mock, "Test mode"):GetValue(), false)
end)

test("testmode: the lock is honored while it is up", function()
    -- Test mode shows the popup; it does not unlock it. `locked` is read at drag time.
    local NS, _, mock = T.enableAddon()
    NS.addon.Settings.Helpers.Set("locked", true)
    on(NS)
    local handle
    for _, fr in ipairs(mock.frames) do
        if fr.__scripts.OnMouseUp then handle = fr end
    end
    local started = false
    local f = popup(mock)
    local orig = f.StartMoving
    f.StartMoving = function(...) started = true; if orig then return orig(...) end end
    handle.__scripts.OnMouseDown(handle)
    assertFalse(started, "a locked popup does not drag in test mode either")
    NS.addon.Settings.Helpers.Set("locked", false)
    handle.__scripts.OnMouseDown(handle)
    assertTrue(started, "unlocked, it drags")
end)

-- ---------------------------------------------------------------------------
-- Combat
-- ---------------------------------------------------------------------------

test("testmode: a start in combat is refused with one gray line and leaves the box unticked",
function()
    local NS, _, mock = openGeneral()
    mock.combat = true
    local mark = #mock.prints
    checkbox(mock, "Test mode"):Fire("OnValueChanged", true)
    assertFalse(isOn(NS), "refused")
    assertTrue(popup(mock) == nil or not popup(mock):IsShown(), "nothing was shown")
    assertEqual(#mock.blocked, 0, "no protected call was attempted")
    assertTrue(printedSince(mock, mark, "cannot start test mode during combat"), "the refusal says why")
    assertTrue(printedSince(mock, mark, "|cff808080"), "in gray")
    assertEqual(checkbox(mock, "Test mode"):GetValue(), false, "the box redraws unticked")
end)

test("testmode: combat starting ends it, says so once, and unticks the box", function()
    local NS, _, mock = openGeneral()
    checkbox(mock, "Test mode"):Fire("OnValueChanged", true)
    assertTrue(onScreen(mock))
    local mark = #mock.prints
    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(isOn(NS), "combat ended it")
    assertFalse(onScreen(mock), "no placeholder covers the screen in a fight")
    assertEqual(#mock.blocked, 0, "and it came down without a refused protected call")
    local n = 0
    for i = mark + 1, #mock.prints do
        if mock.prints[i]:find("Test mode off \226\128\148 combat started", 1, true) then n = n + 1 end
    end
    assertEqual(n, 1, "one line")
    assertEqual(checkbox(mock, "Test mode"):GetValue(), false, "the box follows")

    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertFalse(onScreen(mock), "and it does not come back when combat ends")
end)

test("testmode: combat with test mode off prints nothing about it", function()
    local _, _, mock = T.enableAddon()
    local mark = #mock.prints
    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(printedSince(mock, mark, "Test mode"))
end)

-- ---------------------------------------------------------------------------
-- Reset and the one-shot test
-- ---------------------------------------------------------------------------

test("testmode: Reset all settings ends it", function()
    local NS, _, mock = T.enableAddon()
    on(NS)
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    assertFalse(isOn(NS), "the sessionOnly sweep turned it off")
    assertFalse(onScreen(mock), "and the popup went with it")
end)

test("testmode: /wg test notify is the one-shot notify + popup flow, and ends test mode", function()
    local NS, _, mock = T.enableAddon()
    on(NS)
    local mark = #mock.prints
    wgTest(NS, "notify")
    assertFalse(isOn(NS), "the real flow takes the popup back")
    assertEqual(NS.addon.pendingInfo.mapID, 2805, "RunTest's capture was injected")
    assertTrue(printedSince(mock, mark, "You have joined a group!"), "the chat summary printed")
    assertTrue(onScreen(mock), "and the popup is up, showing that capture")
    assertEqual(groupText(mock), NS.addon.pendingInfo.title)
end)

test("testmode: /wg show ends it and shows the real capture", function()
    local NS, _, mock = T.enableAddon()
    on(NS)
    NS.addon.pendingInfo = pending()
    for _, c in ipairs(NS.addon.COMMANDS) do
        if c[1] == "show" then c[3]("") end
    end
    assertFalse(isOn(NS), "asking for the real popup turns test mode off")
    assertTrue(onScreen(mock))
    assertEqual(groupText(mock), "Stonevault Speedrun")
end)

test("testmode: the join popup does NOT end it; the capture waits for the chat link", function()
    -- options-ui-§15: the mode is left on until it is turned off. A join is not the player turning it
    -- off, so the summary prints and the popup keeps the sample; the link is the explicit show.
    -- red under: _TryFireJoinNotify calling ShowFrame while test mode is on.
    local NS, _, mock = T.enableAddon()
    on(NS)
    local mark = #mock.prints
    NS.addon.pendingInfo = pending()
    mock.inGroup = true
    NS.addon:_TryFireJoinNotify("test")
    mock.__fireTimers()
    assertTrue(printedSince(mock, mark, "You have joined a group!"), "the chat summary still prints")
    assertTrue(isOn(NS), "test mode is still on")
    assertTrue(onScreen(mock))
    assertEqual(groupText(mock), NS.addon:SampleInfo().title, "still showing the sample")
    assertEqual(NS.addon.pendingInfo.title, "Stonevault Speedrun", "the real capture is pending")

    NS.addon:OnSetItemRef()
    assertFalse(isOn(NS), "the details link is an explicit show, and ends it")
    assertEqual(groupText(mock), "Stonevault Speedrun")
end)

test("testmode: the sample capture is a fresh table each time", function()
    -- Test mode and /wg test both draw on it; neither may hand the other a table it then mutates.
    local NS = T.newAddon()
    local a, b = NS.addon:SampleInfo(), NS.addon:SampleInfo()
    assertTrue(a ~= b)
    assertEqual(a.mapID, 2805)
    assertEqual(a.title, b.title)
end)
