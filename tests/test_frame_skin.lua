-- tests/test_frame_skin.lua — the popup's look on the skin (WG-02; modules/FrameSkin.lua over
-- core/SkinSetup.lua's NS.Skin, LibKa0s-Skin-1.0, skinning-§3).
--
-- What this pins: every string and control the popup draws takes its look from the skin's tokens,
-- never from a literal (anti-pattern #107). Under Ka0s Default that is today's pixels exactly: the
-- FFD700 brand span and field labels and the 888888 placeholders and teleport note through this
-- addon's owner tokens (the rollout's X1), the white values through `text.highlight`. A skin switch
-- repaints all of it live, the title's brand span included, and moves the secure teleport button
-- back beside its label when the new font moved the label (inventory risk R2), out of combat only.
--
-- THE RECORD. The library records every primitive call on its target (`Skin.painted[target]`,
-- owner and arguments), and tests/wow_mock.lua records the text color a string was given, so a
-- case reads both what the popup asked for and what the switch then drew.
--
-- Every case builds its own instance (tests/run.lua), so no skin state leaks between cases.

local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local F = dofile("tests/frame_fixture.lua")
local pending, popup = F.pending, F.popup

local OWNER = "WhatGroup"
local OTHER = "obsidian"

local function skinLib(mock) return mock.LibStub("LibKa0s-Skin-1.0") end

--- Run `fn` with chat output swallowed, so a skin switch's own lines stay out of the run's log.
local function quietly(NS, fn)
    local print = NS.Print
    NS.Print = function() end
    local ok, err = pcall(fn)
    NS.Print = print
    if not ok then error(err, 0) end
end

-- The popup's content strings, in buildFrame's order: six label/value pairs, then the Teleport
-- label and the note beside the button. `content` is the frame carrying the most FontStrings, as
-- tests/test_frame.lua finds it.
local function strings(mock)
    local content, most = nil, 0
    for _, f in ipairs(mock.frames) do
        if #f.__fontStrings > most then content, most = f, #f.__fontStrings end
    end
    assertTrue(content ~= nil, "the popup content frame must exist")
    local fs = content.__fontStrings
    local s = { labels = {}, values = {}, port = fs[13], note = fs[14] }
    for i = 1, 6 do
        s.labels[i] = fs[2 * i - 1]
        s.values[i] = fs[2 * i]
    end
    s.labels[7] = fs[13]
    return s
end

local function closeBtn(mock)
    for _, f in ipairs(mock.frames) do
        if f.__template == "UIPanelButtonTemplate" then return f end
    end
end

local function teleportBtn(mock)
    for _, f in ipairs(mock.frames) do
        if f.__template == "SecureActionButtonTemplate" then return f end
    end
end

--- The token a primitive was asked to paint `fs` with: S.Text's second argument.
local function textRole(mock, fs)
    local rec = skinLib(mock).painted[fs]
    if not rec or rec.owner ~= OWNER or not rec.calls.Text then return nil end
    return rec.calls.Text[1]
end

local function rgb(r, g, b) return ("%.3f,%.3f,%.3f"):format(r, g, b) end
local function colorOf(fs)
    local c = fs.__textColor
    if not c then return "unpainted" end
    return rgb(c[1], c[2], c[3])
end
local function tokenColor(NS, name) return rgb(NS.Skin.Color(name)) end

-- ── Ka0s Default: today's pixels, through tokens ─────────────────────────────────────────────

test("popup skin: the title's brand span reads wg.brand, FFD700 byte for byte on Ka0s Default", function()
    -- red under: the old inline |cffFFD700 literal (#107), or the brand span snapped to title.text.
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    local title = popup(mock).title
    assertEqual(title:GetText(), NS.SkinEscape("wg.brand") .. "WhatGroup|r — Group Info")
    assertEqual(title:GetText():sub(1, 10), "|cffffd700", "the brand gold, byte for byte")
end)

test("popup skin: every field label is painted in wg.label, with no inline color", function()
    -- red under: a label that still carries |cffFFD700, or one painted from text.heading (6/255 off).
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    for i, label in ipairs(strings(mock).labels) do
        assertFalse(label:GetText():find("|c", 1, true) ~= nil, "label " .. i .. " carries inline markup")
        assertEqual(textRole(mock, label), "wg.label", "label " .. i .. " is not painted from wg.label")
        assertEqual(colorOf(label), rgb(1, 215 / 255, 0), "label " .. i .. ": FFD700 on Ka0s Default")
    end
end)

test("popup skin: values read text.highlight, and every placeholder wg.placeholder", function()
    -- red under: a |cff888888 placeholder escape left in PopulateFields, or a value that keeps the
    -- placeholder's gray after real data arrives (S.Text's arguments are replaced on each call).
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    local s = strings(mock)
    for i, value in ipairs(s.values) do
        assertFalse((value:GetText() or ""):find("|c", 1, true) ~= nil, "value " .. i .. " carries inline markup")
        assertEqual(textRole(mock, value), "wg.placeholder", "placeholder " .. i)
        assertEqual(colorOf(value), rgb(136 / 255, 136 / 255, 136 / 255), "placeholder " .. i .. ": 888888")
    end
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    for i = 1, 4 do
        assertEqual(textRole(mock, s.values[i]), "text.highlight", "value " .. i .. " with data")
        assertEqual(colorOf(s.values[i]), rgb(1, 1, 1), "value " .. i .. ": white on Ka0s Default")
    end
    assertEqual(s.values[1]:GetText(), "Stonevault Speedrun")
end)

test("popup skin: the teleport note is painted in wg.placeholder, its text plain", function()
    -- red under: the note's |cff888888 escape, which a skin switch could never repaint.
    local NS, _, mock = T.bootAddon()
    NS.TeleportSpells[2652] = 445269   -- never marked known
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    local note = strings(mock).note
    assertEqual(note:GetText(), "Teleport spell not learned")
    assertEqual(textRole(mock, note), "wg.placeholder")
    assertEqual(colorOf(note), rgb(136 / 255, 136 / 255, 136 / 255))
end)

test("popup skin: the Close button is the skin's button, painted after its click script", function()
    -- red under: no S.Button (the stock red art under every skin), or a SetScript after the paint,
    -- which would replace the primitive's hover hook.
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    local btn = closeBtn(mock)
    local rec = skinLib(mock).painted[btn]
    assertTrue(rec ~= nil and rec.owner == OWNER and rec.calls.Button ~= nil, "Close is not S.Button'd")
    assertTrue(btn.__hooks.OnEnter ~= nil and #btn.__hooks.OnEnter > 0, "the hover hook is missing")
    btn.__fire("OnClick")
    assertFalse(popup(mock):IsShown(), "the Close button still closes")
end)

test("popup skin: the window is the owner's Shell, so a switch repaints its edge and title", function()
    -- red under: NS.ApplySkin(f) with no owner (Core's fixed SKIN, never recorded, never repainted).
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    local rec = skinLib(mock).painted[popup(mock)]
    assertTrue(rec ~= nil and rec.owner == OWNER and rec.calls.Shell ~= nil, "the popup is not the owner's Shell")
end)

-- ── a skin switch ─────────────────────────────────────────────────────────────────────────────

test("popup skin: a skin switch repaints the labels, values, note and brand span live", function()
    -- red under: a brand escape baked once at build (the title stays FFD700 under every skin), or
    -- a label colored with SetTextColor outside the facade (no replay on the switch).
    local NS, _, mock = T.bootAddon()
    NS.TeleportSpells[2652] = 445269
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    local s = strings(mock)
    quietly(NS, function() NS.ApplySkinChoice("ka0s", OTHER) end)
    local _, applied = skinLib(mock):GetChoice(OWNER)
    assertEqual(applied, OTHER)
    for i, label in ipairs(s.labels) do
        assertEqual(colorOf(label), tokenColor(NS, "text.heading"), "label " .. i .. " under " .. OTHER)
    end
    assertEqual(colorOf(s.values[1]), tokenColor(NS, "text.highlight"), "a value under " .. OTHER)
    assertEqual(colorOf(s.note), tokenColor(NS, "text.disabled"), "the note under " .. OTHER)
    local title = popup(mock).title
    assertEqual(title:GetText(), NS.SkinEscape("title.text") .. "WhatGroup|r — Group Info",
        "the brand span follows title.text under " .. OTHER)
    quietly(NS, function() NS.ApplySkinChoice("ka0s", "ka0s") end)
    assertEqual(title:GetText():sub(1, 10), "|cffffd700", "and is FFD700 again on Ka0s Default")
    assertEqual(colorOf(s.labels[1]), rgb(1, 215 / 255, 0), "the labels are FFD700 again")
end)

test("popup skin: a repopulate paints only the values whose token moved, and the look survives", function()
    -- red under: S.Text on every Value (3712 bytes and 25 API calls per group join, tests/perf.lua),
    -- or a cache that skips a real move and leaves data in the placeholder's gray.
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    local s = strings(mock)
    local real, seen = NS.Skin.Text, {}
    NS.Skin.Text = function(fs, role, opts)
        seen[#seen + 1] = role
        return real(fs, role, opts)
    end
    NS.addon:ShowFrame()
    assertEqual(#seen, 0, "the same tokens repaint nothing")
    NS.addon.pendingInfo = nil
    NS.addon:ShowFrame()
    assertEqual(#seen, 5, "five values moved to their placeholder; the role was already on its own")
    assertEqual(seen[1], "wg.placeholder")
    assertEqual(colorOf(s.values[1]), rgb(136 / 255, 136 / 255, 136 / 255), "the placeholder's gray")
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertEqual(colorOf(s.values[1]), rgb(1, 1, 1), "and back to data's white")
    NS.Skin.Text = real
    quietly(NS, function() NS.ApplySkinChoice("ka0s", OTHER) end)
    NS.addon:ShowFrame()
    assertEqual(colorOf(s.values[1]), tokenColor(NS, "text.highlight"), "a skipped paint still follows a switch")
end)

-- ── the secure teleport button's anchor (inventory R2) ───────────────────────────────────────

test("popup skin: a skin switch re-anchors the teleport button beside its moved label", function()
    -- A skin with a larger body font moves the Teleport label down; the secure button's TOPLEFT
    -- is computed from the label's rendered top, so it is computed again after the switch.
    -- red under: the anchor computed once at build (the button drifts off its label).
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    local s, btn = strings(mock), teleportBtn(mock)
    local _, _, _, _, y0 = btn:GetPoint(1)
    assertEqual(y0, 0, "the mock's label sits at the frame's top at build")
    rawset(s.port, "GetTop", function() return -150 end)
    quietly(NS, function() NS.ApplySkinChoice("ka0s", OTHER) end)
    assertEqual(btn:GetNumPoints(), 1, "one anchor, replaced rather than stacked")
    local point, _, _, x, y = btn:GetPoint(1)
    assertEqual(point, "TOPLEFT")
    assertEqual(y, -150, "the button follows the label's new top")
    assertEqual(x, 72 + 6, "beside the label, as at build")
end)

test("popup skin: in combat the re-anchor waits for combat end, then lands", function()
    -- SetPoint on a protected frame is refused under lockdown; `/wg set skin.skin` can arrive in
    -- combat (the CLI is not combat-locked like the panel).
    -- red under: an unguarded SetPoint in combat, or a deferred anchor that is never replayed.
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    local s, btn = strings(mock), teleportBtn(mock)
    rawset(s.port, "GetTop", function() return -150 end)
    mock.combat = true
    quietly(NS, function() NS.ApplySkinChoice("ka0s", OTHER) end)
    local _, _, _, _, y = btn:GetPoint(1)
    assertEqual(y, 0, "the protected anchor must not move in combat")
    mock.combat = false
    NS.FrameDrainCombatEnd()
    _, _, _, _, y = btn:GetPoint(1)
    assertEqual(y, -150, "the queued anchor lands at combat end")
end)

test("popup skin: a switch while stood down queues no anchor; the stand-up re-anchors", function()
    -- A disabled addon has no PLAYER_REGEN_ENABLED drain, so an anchor queued after
    -- NS.FrameStandDown wiped the queue would sit there until re-enable. Another Ka0s addon's
    -- "Copy to every Ka0s addon" or an EllesmereUI repaint can move this skin while it is off.
    -- red under: an AnchorTeleport with no stand-down gate (combatQueue holds "teleportAnchor"),
    -- or a stand-up that does not re-anchor (the button stays beside the label's old top).
    local NS, _, mock = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    NS.addon:ShowFrame()
    local s, btn = strings(mock), teleportBtn(mock)
    quietly(NS, function() H.Set("enabled", false) end)
    assertTrue(NS.IsStoodDown(), "the switch stood the addon down")
    rawset(s.port, "GetTop", function() return -150 end)
    mock.combat = true
    quietly(NS, function() NS.ApplySkinChoice("ka0s", OTHER) end)
    assertEqual(#NS.FrameSnapshot().combatQueue, 0, "a stood-down skin switch queued protected work")
    mock.combat = false
    quietly(NS, function() NS.ApplySkinChoice("ka0s", "ka0s") end)
    local _, _, _, _, y = btn:GetPoint(1)
    assertEqual(y, 0, "a stood-down skin switch moved the protected button")
    quietly(NS, function() H.Set("enabled", true) end)
    assertFalse(NS.IsStoodDown(), "and the switch stood it back up")
    _, _, _, _, y = btn:GetPoint(1)
    assertEqual(y, -150, "the stand-up re-anchors the button beside its label")
end)

test("popup skin: a switch before the popup exists builds nothing", function()
    -- The look is lazy like the popup: OnLooksChanged before the first show must not build it.
    local NS, _, mock = T.bootAddon()
    quietly(NS, function() NS.ApplySkinChoice("ka0s", OTHER) end)
    assertTrue(popup(mock) == nil, "a skin switch built the popup")
end)

-- ── the degraded facade ───────────────────────────────────────────────────────────────────────

test("popup skin: the degraded facade paints a token name with that token's color", function()
    -- Without the library S.Text is core/SkinSetup.lua's: a role maps to text.<role>, and a token
    -- name (wg.label, text.highlight) is read as itself, from the host copy of Ka0s Default.
    local degraded = T.newAddon{ skip = T.loadAddon.libFiles }
    local seen = {}
    local fs = { SetTextColor = function(_, r, g, b) seen[1] = rgb(r, g, b) end }
    degraded.Skin.Text(fs, "wg.label")
    assertEqual(seen[1], rgb(1, 215 / 255, 0))
    degraded.Skin.Text(fs, "text.highlight")
    assertEqual(seen[1], rgb(1, 1, 1))
    degraded.Skin.Text(fs, "wg.placeholder")
    assertEqual(seen[1], rgb(136 / 255, 136 / 255, 136 / 255))
end)
