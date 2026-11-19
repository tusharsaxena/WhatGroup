-- tests/test_frame_tooltip.lua — where the popup's own tooltip opens (LibKa0s#92, AD-92-WG;
-- WowAddonStandards standalone-windows, *Tooltip placement*, v2.113.0).
--
-- The popup places one tooltip itself: the teleport button's spell tooltip (modules/Frame.lua,
-- onTeleportEnter). The button sits in the popup's content, so it is a BODY element and its
-- tooltip opens beside the window group (the popup alone: nothing docks to it), outside its outer
-- edge, right when it fits and otherwise left, its top level with the button's top, through
-- LibKa0s-Tooltip-1.0's PlaceBeside. Before AD-92-WG it was GameTooltip:SetOwner(self,
-- "ANCHOR_RIGHT"), the corner offset the rule names. The title-bar marks' tooltips are the
-- library's (W.HeaderButtons, PlaceAttached; tests/test_frame_header.lua).
--
-- The cases drive the kit's fake screen (tests/_kit/mock_screen.lua, kit revision 57) through a
-- right-fits and a right-does-not-fit layout (the standard's Verification SHOULD), then the two
-- ways the placer places nothing (unreadable geometry, the library absent), where the tooltip is
-- attached centered above the button and never put on the cursor.

local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local Fx = dofile("tests/frame_fixture.lua")
local pending, popup = Fx.pending, Fx.popup

local STONEVAULT_MAP, STONEVAULT_PORT = 2652, 445269
local GAP = 2

local function teleportBtn(mock)
    for _, f in ipairs(mock.frames) do
        if f.__template == "SecureActionButtonTemplate" then return f end
    end
end

-- A popup with a learned, ready Stonevault teleport, so the button carries its OnEnter.
local function armed()
    local NS, _, mock = T.enableAddon()
    mock.spellNames[STONEVAULT_PORT] = "Path of the Stonevault"
    mock.knownSpells[STONEVAULT_PORT] = true
    NS.TeleportSpells[STONEVAULT_MAP] = STONEVAULT_PORT
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    local f, btn = popup(mock), teleportBtn(mock)
    assertTrue(f ~= nil and btn ~= nil, "the popup and its teleport button are built")
    assertTrue(btn:GetScript("OnEnter") ~= nil, "the armed button carries its tooltip")
    return NS, mock, f, btn
end

-- Gives an addon-built frame a rect in its own units (scale 1), as mock_screen's frames answer.
local function place(frame, left, bottom, width, height)
    rawset(frame, "GetLeft", function() return left end)
    rawset(frame, "GetBottom", function() return bottom end)
    rawset(frame, "GetWidth", function() return width end)
    rawset(frame, "GetHeight", function() return height end)
    rawset(frame, "GetRight", function() return left + width end)
    rawset(frame, "GetTop", function() return bottom + height end)
    rawset(frame, "GetCenter", function() return left + width / 2, bottom + height / 2 end)
    rawset(frame, "GetEffectiveScale", function() return 1 end)
end

-- The fake screen and a recording tooltip standing in for GameTooltip (read at call time).
local function screen(mock)
    local scr = dofile("tests/_kit/mock_screen.lua")(mock, { width = 1920, height = 1080 })
    local tip = scr.tooltip{ width = 250, height = 90 }
    local shownID
    rawset(tip, "SetSpellByID", function(_, id) shownID = id end)
    mock.GameTooltip = tip
    return scr, tip, function() return shownID end
end

local CURSOR = { ANCHOR_CURSOR = true, ANCHOR_CURSOR_RIGHT = true, ANCHOR_CURSOR_LEFT = true,
                 ANCHOR_RIGHT = true, ANCHOR_TOPRIGHT = true, ANCHOR_TOPLEFT = true, ANCHOR_LEFT = true,
                 ANCHOR_TOP = true, ANCHOR_BOTTOM = true, ANCHOR_PRESERVE = true }

local function assertOwnedAtNone(tip, btn)
    assertEqual(tip.__owner, btn, "the tooltip is owned by the teleport button")
    assertEqual(tip.__anchor, "ANCHOR_NONE", "owned at ANCHOR_NONE, never a cursor or corner anchor")
    for _, e in ipairs(tip.__log) do
        if e.op == "SetOwner" then
            assertTrue(not CURSOR[e.anchor], "no cursor or corner owner anchor: " .. tostring(e.anchor))
        end
    end
end

test("teleport tooltip: a body element, it opens right of the popup, top level with the button", function()
    -- red under: GameTooltip:SetOwner(self, "ANCHOR_RIGHT") (the corner offset off the button).
    local _, mock, f, btn = armed()
    local scr, tip, shownID = screen(mock)
    place(f, 600, 400, 400, 260)        -- right edge 1000
    place(btn, 700, 500, 24, 24)        -- top 524
    btn.__fire("OnEnter")
    assertEqual(shownID(), STONEVAULT_PORT, "the content is the spell's own tooltip, unchanged")
    assertOwnedAtNone(tip, btn)
    local l, _, _, t = scr.rectOf(tip)
    scr.restore()
    assertEqual(l, 1000 + GAP, "TIP_GAP outside the popup's right outer edge")
    assertEqual(t, 524, "its top level with the button's top")
    assertEqual(tip.__point.rel, mock.UIParent, "one absolute point on UIParent")
end)

test("teleport tooltip: without room on the right it opens left of the popup", function()
    -- red under: a corner anchor that hangs off the screen's right edge, or one placed over the popup.
    local _, mock, f, btn = armed()
    local scr, tip = screen(mock)
    place(f, 1600, 400, 300, 260)       -- right edge 1900: 1902 + 250 does not fit in 1920
    place(btn, 1700, 500, 24, 24)
    btn.__fire("OnEnter")
    assertOwnedAtNone(tip, btn)
    local _, _, r, t = scr.rectOf(tip)
    scr.restore()
    assertEqual(r, 1600 - GAP, "TIP_GAP outside the popup's left outer edge")
    assertEqual(t, 524, "its top level with the button's top")
end)

test("teleport tooltip: the placer is PlaceBeside, with the button and the popup as its group", function()
    -- red under: PlaceAttached on the button (a chrome placement for a body element), or the
    -- button's own rect as the group.
    local _, mock, f, btn = armed()
    local Tip = mock.LibStub("LibKa0s-Tooltip-1.0")
    local calls = {}
    local real = Tip.PlaceBeside
    Tip.PlaceBeside = function(tip, el, group, opts)
        calls[#calls + 1] = { tip = tip, el = el, group = group }
        return real(tip, el, group, opts)
    end
    local scr, tip = screen(mock)
    place(f, 600, 400, 400, 260)
    place(btn, 700, 500, 24, 24)
    btn.__fire("OnEnter")
    Tip.PlaceBeside = real
    scr.restore()
    assertEqual(#calls, 1, "one body placement per hover")
    assertEqual(calls[1].tip, tip, "on GameTooltip")
    assertEqual(calls[1].el, btn, "against the hovered button")
    assertEqual(calls[1].group, f, "beside the popup, the whole window group")
end)

test("teleport tooltip: unreadable geometry attaches it centered above the button, never the cursor", function()
    -- red under: a cursor fallback, or a tooltip left with no point at all.
    local _, mock, _, btn = armed()
    local scr, tip = screen(mock)
    for _, m in ipairs({ "GetLeft", "GetBottom", "GetRight", "GetTop" }) do
        rawset(btn, m, function() return nil end)   -- an unplaced button: the placer places nothing
    end
    btn.__fire("OnEnter")
    scr.restore()
    assertOwnedAtNone(tip, btn)
    local p = tip.__point
    assertTrue(p ~= nil, "the tooltip is placed")
    assertEqual(p.point, "BOTTOM", "its bottom")
    assertEqual(p.rel, btn, "on the button")
    assertEqual(p.relPoint, "TOP", "at the button's top")
    assertEqual(p.x, 0, "centered")
    assertEqual(p.y, GAP, "TIP_GAP above")
end)

test("teleport tooltip: with the Tooltip major absent it is still attached above, never the cursor", function()
    -- red under: a library-less arm falling back to ANCHOR_RIGHT or ANCHOR_CURSOR.
    local _, mock, f, btn = armed()
    local realLibStub = mock.LibStub
    mock.LibStub = setmetatable({}, {
        __call = function(_, name, silent)
            if name == "LibKa0s-Tooltip-1.0" then return nil end
            return realLibStub(name, silent)
        end,
        __index = function(_, k) return realLibStub[k] end,
    })
    local scr, tip, shownID = screen(mock)
    place(f, 600, 400, 400, 260)
    place(btn, 700, 500, 24, 24)
    btn.__fire("OnEnter")
    mock.LibStub = realLibStub
    scr.restore()
    assertEqual(shownID(), STONEVAULT_PORT, "the spell's tooltip still shows")
    assertOwnedAtNone(tip, btn)
    local p = tip.__point
    assertTrue(p ~= nil and p.point == "BOTTOM" and p.rel == btn and p.relPoint == "TOP", "attached above the button")
    assertEqual(p.y, GAP, "TIP_GAP above")
end)

test("teleport tooltip: the leave hides it", function()
    local _, mock, _, btn = armed()
    local scr, tip = screen(mock)
    btn.__fire("OnEnter")
    assertTrue(tip:IsShown(), "shown on hover")
    btn.__fire("OnLeave")
    scr.restore()
    assertTrue(not tip:IsShown(), "hidden on leave")
end)

-- The addon's own placing code (core/, modules/; settings/ is the Settings canvas, which the rule
-- does not bind) names no cursor or corner anchor outside a comment.
test("teleport tooltip: no cursor or corner anchor in the addon's own placing code", function()
    -- red under: any ANCHOR_CURSOR*, ANCHOR_RIGHT, ANCHOR_TOP* or ANCHOR_LEFT left in core/ or modules/.
    local files = {}
    for _, dir in ipairs({ "core", "modules" }) do
        local p = io.popen('ls "' .. dir .. '"')
        for name in p:lines() do
            if name:match("%.lua$") then files[#files + 1] = dir .. "/" .. name end
        end
        p:close()
    end
    assertTrue(#files > 0, "found the addon's source")
    for _, path in ipairs(files) do
        local fh = assert(io.open(path, "rb"))
        local n = 0
        for line in fh:lines() do
            n = n + 1
            local code = line:gsub("%-%-.*$", "")
            local hit = code:match("ANCHOR_[%u_]+")
            if hit and hit ~= "ANCHOR_NONE" then
                fh:close()
                assertNil(hit, path .. ":" .. n .. " places a tooltip at " .. hit)
            end
        end
        fh:close()
    end
end)
