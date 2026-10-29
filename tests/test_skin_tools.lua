-- tests/test_skin_tools.lua — this addon's own AceGUI acquisitions and its tool surfaces on the
-- skin (WG-04; core/SkinSetup.lua's NS.SkinPaintAce / NS.SkinPaintAceTree over LibKa0s-Skin-1.0's
-- SkinAce, skinning-§3).
--
-- What this pins: the two AceGUI widgets this addon acquires itself are painted for this owner,
-- EVEN THROUGH A HANDLE THAT IS NOT THE LIBRARY'S OWNER PROXY (Helpers.AceGUI normally is one,
-- painting on Create; the button cases swap in the raw AceGUI-3.0, and AceConfigDialog acquires
-- from the raw one anyway), so only the host's own call paints them: the "Test notification" button (settings/Panel.lua's
-- InlineButton) and the tree AceConfigDialog draws into the Profiles page (settings/Profiles.lua),
-- after every Open. Both follow the Scope's "Ignore settings panel" (on by default, so a new
-- profile leaves them stock), Ka0s Default paints like every other skin, and a release hands the
-- widget back stock. And the debug console and its copy window, which the library paints for the
-- descriptor's `addonName` because core/DebugLogSetup.lua passes neither `skin` nor `applySkin`.
--
-- The kit's widgets are recorders without AceGUI's regions, so "painted" is read where the library
-- keeps it: `Skin.__ace[widget].owner`, set while owned and cleared by the restore.
--
-- Every case builds its own instance (tests/run.lua), so no skin state leaks between cases.

local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local OWNER = "WhatGroup"

local function skinLib(mock) return mock.LibStub("LibKa0s-Skin-1.0") end

local function ownerOf(mock, w)
    local st = skinLib(mock).__ace and skinLib(mock).__ace[w]
    return st and st.owner or nil
end

--- An enabled instance on `skin`, its settings panel skinned unless `ignorePanel`. Chat swallowed.
local function onSkin(skin, ignorePanel, opts)
    local NS, env, mock = T.enableAddon(opts)
    NS.Print = function() end
    local H = NS.addon.Settings.Helpers
    H.Set("skin.ignorePanel", ignorePanel == true)
    NS.ApplySkinChoice("ka0s", skin)
    return NS, env, mock, H
end

--- The General page open on its Notifications tab, and the Test notification button it drew,
--- rendered through the raw AceGUI-3.0 (Helpers.AceGUI put back after).
local function testButton(mock, H)
    local proxy = H.AceGUI
    H.AceGUI = mock.LibStub("AceGUI-3.0")
    local ok, err = pcall(function()
        mock.frames["WhatGroupGeneralPanel"]:Show()
        mock.fireCTimers()
        local tab
        for _, f in ipairs(mock.frames) do
            if f.__kind == "Button" and f.__text == "Notifications" then tab = f end
        end
        assertTrue(tab ~= nil, "no Notifications tab")
        tab.__fire("OnClick")
    end)
    H.AceGUI = proxy
    if not ok then error(err, 0) end
    local found
    for _, w in ipairs(mock.aceWidgets) do
        if w.type == "Button" and w.text == "Test notification" then found = w end
    end
    assertTrue(found ~= nil, "the Notifications tab drew no Test notification button")
    return found
end

-- ── the Test notification button ─────────────────────────────────────────────────────────────

test("skin tools: the Test notification button is painted for this owner, past the raw handle", function()
    -- red under: dropping NS.SkinPaintAce from settings/Panel.lua's InlineButton (the raw
    -- AceGUI-3.0 handle paints nothing of its own).
    local _, _, mock, H = onSkin("obsidian", false)
    local btn = testButton(mock, H)
    assertEqual(ownerOf(mock, btn), OWNER, "the button is painted for " .. OWNER)
    assertTrue(type(rawget(btn, "OnRelease")) == "function", "its release is wrapped")
    mock.LibStub("AceGUI-3.0"):Release(btn)
    assertNil(ownerOf(mock, btn), "a release hands it back stock")
end)

test("skin tools: under Ka0s Default the button paints like every skin's", function()
    local _, _, mock, H = onSkin("ka0s", false)
    assertEqual(ownerOf(mock, testButton(mock, H)), OWNER, "Ka0s Default is a skin like the others")
end)

test("skin tools: the Scope's Ignore settings panel (the default) leaves the button stock", function()
    -- red under: a host paint that skipped the library's ignore check.
    local _, _, mock, H = onSkin("obsidian", true)
    assertNil(ownerOf(mock, testButton(mock, H)), "the panel is the client's while it is ignored")
end)

-- ── the Profiles page ────────────────────────────────────────────────────────────────────────

--- AceDBOptions, AceConfig and AceConfigDialog as fakes whose Open draws one raw CheckBox into the
--- container, as AceConfigDialog acquires from AceGUI itself. `drawn` collects each row it drew.
local function profileLibs(drawn)
    return function(m)
        m.__libs["AceDBOptions-3.0"] = { GetOptionsTable = function() return { type = "group" } end }
        m.__libs["AceConfig-3.0"] = { RegisterOptionsTable = function() end }
        m.__libs["AceConfigDialog-3.0"] = { Open = function(_, _, container)
            container:ReleaseChildren()
            local row = m.__libs["AceGUI-3.0"]:Create("CheckBox")
            container:AddChild(row)
            drawn[#drawn + 1] = row
        end }
    end
end

test("skin tools: the Profiles page paints the tree AceConfigDialog drew, after every Open", function()
    -- red under: dropping NS.SkinPaintAceTree from the Profiles renderer, or calling it once at
    -- build instead of after each Open (the next Open re-acquires every row).
    local drawn = {}
    local NS, _, mock = onSkin("obsidian", false, { mock = profileLibs(drawn) })
    local panel = mock.frames["WhatGroupProfilesPanel"]
    assertTrue(panel ~= nil, "the Profiles page registered")
    panel:Show()
    mock.fireCTimers()
    assertEqual(#drawn, 1, "the page drew once")
    assertEqual(ownerOf(mock, drawn[1]), OWNER, "the drawn row is painted for this owner")
    NS.addon.Settings.RefreshProfilesPage()
    mock.fireCTimers()
    assertTrue(#drawn >= 2, "a refresh re-drew the page")
    assertEqual(ownerOf(mock, drawn[#drawn]), OWNER, "the re-drawn row is painted too")
end)

-- ── the debug console ────────────────────────────────────────────────────────────────────────

test("skin tools: the debug console and its copy window are painted for this owner", function()
    -- red under: a host `skin` or `applySkin` on core/DebugLogSetup.lua's descriptor (a host hook
    -- owns the whole job and the library never paints the console for its owner), or an
    -- `addonName` that is not the folder.
    local NS, _, mock = onSkin("obsidian", false)
    NS.DebugLog:Show()
    local f = NS.DebugLog._frameForTest
    assertTrue(f ~= nil, "the console frame")
    local rec = skinLib(mock).painted[f]
    assertTrue(rec ~= nil and rec.owner == OWNER, "the console window is recorded for " .. OWNER)
    NS.DebugLog:ShowCopy()
    local cf = NS.DebugLog._copyFrameForTest
    assertTrue(cf ~= nil, "the console's copy window")
    assertTrue(rawget(cf, "__copyDesc") ~= nil, "the copy window was not painted for an owner")
    cf:Hide()
    NS.DebugLog:Hide()
end)
