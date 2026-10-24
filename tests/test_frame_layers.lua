-- tests/test_frame_layers.lua — where the popup and its helper frames sit (frame-layering, item 030):
-- the one layers table (core/Constants.lua), the popup's strata, toplevel, clamp and child levels,
-- and the combat soft hide leaving nothing invisible mouse-live (frame-layering-§4, WHA-Z01).
--
-- On the kit's opt-in frame-layer recorder (tests/_kit/mock_layers.lua), installed before the
-- addon's files load so every frame they build records its layers. The mouse is spied here: the
-- base mock no-ops EnableMouse, and this suite needs to read it back and to see a refused write. The
-- spy refuses EnableMouse in combat on a frame that is or holds a protected frame, as the client does
-- (the popup parents a SecureActionButtonTemplate), and records it in mock.blocked.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse

local Fx = dofile("tests/frame_fixture.lua")
local pending, popup, closeButton, dragHandle = Fx.pending, Fx.popup, Fx.closeButton, Fx.dragHandle

local installLayers = dofile("tests/_kit/mock_layers.lua")

local function spyMouse(mock)
    local prev = mock.CreateFrame
    mock.CreateFrame = function(...)
        local f = prev(...)
        if type(f) == "table" then
            rawset(f, "EnableMouse", function(self, on)
                if mock.combat and self.__holdsProtected and self.__holdsProtected() then
                    mock.blocked[#mock.blocked + 1] = (self.__name or "<anonymous>") .. ":EnableMouse()"
                    return
                end
                rawset(self, "__mouse", on and true or false)
            end)
            -- The client's defaults: a Button takes the mouse until told otherwise, a Frame does not.
            rawset(f, "IsMouseEnabled", function(self)
                local on = rawget(self, "__mouse")
                if on == nil then return self.__kind == "Button" end
                return on
            end)
        end
        return f
    end
end

local function layered()
    return T.enableAddon({ mock = function(m) installLayers(m); spyMouse(m) end })
end

local function shown(NS, mock)
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    local f = popup(mock)
    assertTrue(f and f:IsShown(), "the popup is up")
    return f
end

local function teleportBtn(mock)
    for _, fr in ipairs(mock.frames) do
        if fr.__template == "SecureActionButtonTemplate" then return fr end
    end
end

test("layers: one table, the modal strata the popup reads (frame-layering-§5)", function()
    local NS = layered()
    local L = NS.Constants and NS.Constants.LAYERS
    assertTrue(type(L) == "table" and type(L.STRATA) == "table", "NS.Constants.LAYERS.STRATA exists")
    assertEqual(L.STRATA.MODAL, "DIALOG")
end)

test("layers: the popup is DIALOG, not toplevel, clamped, and Raise()d on an explicit show", function()
    local NS, _, mock = layered()
    local f = shown(NS, mock)
    local s = mock.__layers(f)
    assertEqual(s.strata, NS.Constants.LAYERS.STRATA.MODAL, "the dialog tier, read from the table")
    assertFalse(s.toplevel, "the event-raised-notice exception: not toplevel")
    assertTrue(s.clamped, "clamped to the screen")
    assertEqual(s.raised, 1, "one Raise on the show")
end)

test("layers: the popup's children inherit its strata at parent + 1, no explicit level", function()
    local NS, _, mock = layered()
    local f = shown(NS, mock)
    local base = mock.__layers(f).level
    for label, kid in pairs({ title = dragHandle(mock), close = closeButton(mock), teleport = teleportBtn(mock) }) do
        local s = mock.__layers(kid)
        assertEqual(s.strata, "DIALOG", label .. " inherits DIALOG")
        assertEqual(s.level, base + 1, label .. " sits at the popup's level + 1")
        assertTrue(rawget(kid, "__level") == nil, label .. " has no explicit level")
    end
end)

test("layers: the ESC proxy and the binding button set no strata and are never raised", function()
    local NS, _, mock = layered()
    shown(NS, mock)
    for _, name in ipairs({ "WhatGroupFrameEscape", "WhatGroupTogglePopup" }) do
        local fr = mock.frames[name]
        assertTrue(fr ~= nil, name .. " exists")
        assertTrue(rawget(fr, "__strata") == nil, name .. " sets no strata (T0, exempt)")
        assertEqual(mock.__layers(fr).raised, 0, name .. " is never raised")
    end
end)

test("layers: the popup body takes no mouse; the title bar is the drag handle (WHA-Z01)", function()
    local NS, _, mock = layered()
    local f = shown(NS, mock)
    assertFalse(f:IsMouseEnabled(), "the body serves no drag, so it catches no click")
    assertTrue(dragHandle(mock):IsMouseEnabled(), "the title bar takes the mouse")
    assertTrue(closeButton(mock):IsMouseEnabled(), "the Close button takes the mouse")
end)

test("layers: a combat soft hide leaves no plain control mouse-live, and a reopen restores them", function()
    -- red under: hidePopup's combat branch setting only the alpha
    local NS, _, mock = layered()
    local f = shown(NS, mock)
    mock.combat = true
    local close = closeButton(mock)
    close.__scripts.OnClick(close)
    assertEqual(f:GetAlpha(), 0, "the alpha-0 soft hide")
    assertFalse(dragHandle(mock):IsMouseEnabled(), "the invisible title bar is mouse-dead")
    assertFalse(close:IsMouseEnabled(), "the invisible Close button is mouse-dead")
    assertFalse(f:IsMouseEnabled(), "the body stays mouse-dead")
    assertEqual(#mock.blocked, 0, "nothing protected was written: " .. table.concat(mock.blocked, ","))

    NS.addon:ShowFrame()          -- the soft show, still in combat
    assertTrue(f:GetAlpha() > 0, "back on screen")
    assertTrue(dragHandle(mock):IsMouseEnabled(), "the soft show gives the title bar its mouse back")
    assertTrue(close:IsMouseEnabled(), "and the Close button")
    assertEqual(#mock.blocked, 0)
end)

test("layers: the owed Hide at combat end leaves the controls ready for the next show", function()
    local NS, _, mock = layered()
    local f = shown(NS, mock)
    mock.combat = true
    local close = closeButton(mock)
    close.__scripts.OnClick(close)
    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertFalse(f:IsShown(), "the owed Hide landed")
    NS.addon:ShowFrame()
    assertTrue(dragHandle(mock):IsMouseEnabled(), "the title bar takes the mouse again")
    assertTrue(closeButton(mock):IsMouseEnabled(), "and the Close button")
end)

-- Static: every strata write reads the layers table, and no level is absolute (frame-layering-§5).
local function sourceFiles()
    local out = {}
    for _, dir in ipairs({ "core", "modules", "settings" }) do
        local p = io.popen('ls "' .. dir .. '"/*.lua 2>/dev/null')
        for line in p:lines() do out[#out + 1] = line end
        p:close()
    end
    return out
end

test("layers: no SetFrameStrata literal and no absolute SetFrameLevel in core, modules or settings", function()
    local files = sourceFiles()
    assertTrue(#files > 0, "found the authored sources")
    for _, path in ipairs(files) do
        local fh = assert(io.open(path, "r"))
        local n = 0
        for line in fh:lines() do
            n = n + 1
            local code = line:gsub("%-%-.*$", "")
            assertFalse(code:find("SetFrameStrata%(%s*[\"']") ~= nil,
                ("%s:%d types a strata literal"):format(path, n))
            assertFalse(code:find("SetFrameLevel%(%s*%d") ~= nil,
                ("%s:%d sets an absolute level"):format(path, n))
        end
        fh:close()
    end
end)
