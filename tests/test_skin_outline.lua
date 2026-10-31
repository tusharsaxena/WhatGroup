-- tests/test_skin_outline.lua — the font outline (LibKa0s v1.82.0, Skin minor 9; WG-01 of
-- Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-06): stored as
-- skin.outline ("all", "hud", the default since LibKa0s v1.83.0 (D-10), "off"), written only through the skin write seam
-- (NS.WriteSkinChoice's `media.outline`), and applied with Skin:SetOutline at load, on every
-- profile event and on the row's own write. The popup is window text, so "hud" takes its outline.

local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "WhatGroup"

local function lib(mock) return mock.LibStub("LibKa0s-Skin-1.0") end
local function profileSkin(NS) return NS.addon.db.profile.skin end

--- Run `fn` with chat output swallowed, so a verb's own lines stay out of the run's log.
local function quietly(NS, fn)
    local print = NS.Print
    NS.Print = function() end
    local ok, err = pcall(fn)
    NS.Print = print
    if not ok then error(err, 0) end
end

test("outline: a fresh profile stores HUD text only, the library's default", function()
    local NS, _, mock = T.bootAddon()
    assertEqual(profileSkin(NS).outline, "hud")
    assertEqual(NS.C.skin.outline, lib(mock).OUTLINE_DEFAULT, "the value lives in defaults/Profile.lua")
    assertEqual(lib(mock):GetOutline(OWNER), "hud")
end)

test("outline: the schema row offers the library's three modes, in its order", function()
    local NS, _, mock = T.newAddon()
    local row = NS.addon.Settings.Helpers.FindSchema("skin.outline")
    assertTrue(row ~= nil, "a skin.outline row")
    assertTrue(row.skipRender == true, "the Skin tab draws it")
    assertEqual(row.group, "Appearance")
    assertEqual(row.section, "skin")
    local got = {}
    for _, opt in ipairs(row.values) do got[#got + 1] = opt.value end
    assertEqual(table.concat(got, ","), table.concat(lib(mock).OUTLINE_MODES, ","))
end)

test("outline: the write seam stores media.outline, and leaves it alone when it is nil", function()
    -- red under: WriteSkinChoice dropping media.outline (the Skin tab's Font outline and another
    -- addon's copy would move the look and never store it).
    local NS = T.bootAddon()
    quietly(NS, function()
        NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "hud" })
    end)
    assertEqual(profileSkin(NS).outline, "hud")
    quietly(NS, function() NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false }) end)
    assertEqual(profileSkin(NS).outline, "hud", "a media without outline leaves it")
    quietly(NS, function()
        NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "off" })
    end)
    assertEqual(profileSkin(NS).outline, "off")
end)

test("outline: another addon's copy reaches the store through WriteChoice", function()
    local NS, _, mock = T.bootAddon()
    quietly(NS, function()
        lib(mock):WriteChoice(OWNER, "ka0s", "ember", nil, { font = false, texture = false, outline = "off" })
    end)
    assertEqual(profileSkin(NS).outline, "off")
end)

test("outline: the row's write applies the mode live", function()
    local NS, _, mock = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    quietly(NS, function() H.Set("skin.outline", "hud") end)
    assertEqual(lib(mock):GetOutline(OWNER), "hud")
    assertEqual(NS.Skin.Token("font.outline"), "", "window text, the popup's, loses its outline")
    assertEqual(NS.Skin.Token("hud.outline"), "OUTLINE", "the HUD keeps it")
    quietly(NS, function() H.Set("skin.outline", "off") end)
    assertEqual(NS.Skin.Token("hud.outline"), "", "Off takes both")
    quietly(NS, function() H.Set("skin.outline", "all") end)
    assertEqual(NS.Skin.Token("font.outline"), "OUTLINE")
end)

test("outline: /wg set refuses a mode the library does not know", function()
    local NS = T.bootAddon()
    quietly(NS, function() NS.addon:OnSlashCommand("set skin.outline thick") end)
    assertEqual(profileSkin(NS).outline, "hud")
end)

test("outline: OnInitialize applies the stored mode", function()
    -- red under: ApplySkinChoice's whole-pair path not applying the stored outline.
    local NS = T.newAddon()
    local real, calls = NS.ApplySkinOutline, 0
    NS.ApplySkinOutline = function(...)
        calls = calls + 1
        return real(...)
    end
    NS.addon:OnInitialize()
    NS.ApplySkinOutline = real
    assertEqual(calls, 1, "OnInitialize applies the stored outline once, with the pair")
end)

test("outline: a profile event applies the incoming profile's mode", function()
    local NS, _, mock = T.bootAddon()
    local db = NS.addon.db
    quietly(NS, function()
        db.profile.skin.outline = "all"
        NS.addon:OnProfileChanged(nil, db, "Default")
    end)
    assertEqual(lib(mock):GetOutline(OWNER), "all", "OnProfileChanged did not apply the outline")
    quietly(NS, function() db:ResetProfile() end)
    assertEqual(lib(mock):GetOutline(OWNER), "hud", "a reset puts HUD text only back")
end)

test("outline: without the skin engine the apply is a quiet no-op", function()
    local NS = T.bootAddon{ skip = { "libs/LibKa0s/Skin.lua" } }
    assertEqual(NS.ApplySkinOutline(), false)
    quietly(NS, function() NS.addon.Settings.Helpers.Set("skin.outline", "off") end)
    assertEqual(profileSkin(NS).outline, "off", "the store still takes the write")
end)
