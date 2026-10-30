-- tests/test_skin_picker.lua — the first-run skin picker on this addon's seam (WG-04;
-- core/SkinSetup.lua over LibKa0s OptionsSkinPicker 1, the rollout's O3 and X6).
--
-- What this addon owes the picker, and nothing the library pins itself: the spec it hands
-- Helpers.SkinPicker (its owner, its two seams, General's page key and the Skin tab's key, the eye,
-- the close); WHEN it shows (a profile whose `skin.pickerSeen` is false, two seconds after login and
-- after every profile event, never while the addon stands down, held through combat on the popup's
-- combat-end queue); and that only the player's close marks it seen. The trigger cases spy on
-- Helpers.SkinPicker; the rest drive the library's real window: a pick previews and Apply saves
-- through NS.WriteSkinChoice, the close control puts the stored skin back, the gear opens General
-- on its Skin tab, the eye starts the popup's test mode, a profile switch with a preview pending
-- wears the new profile's skin, and the stand-down puts a pending preview back, unseen. Last, the
-- degraded install, where the picker is absent and nothing raises.
--
-- Every case builds its own instance (tests/run.lua), so no picker, queue or skin state leaks.

local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local OWNER = "WhatGroup"
local PATH = "skin.pickerSeen"

--- A fully enabled instance with chat output swallowed (a test-mode start and the [Set] lines print).
local function enabled(opts)
    local NS, env, mock = T.enableAddon(opts)
    NS.Print = function() end
    return NS, env, mock, NS.addon.Settings.Helpers
end

--- Run `fn(calls)` with Helpers.SkinPicker replaced by a recorder: each call's spec, in order.
local function spying(H, fn)
    local real = H.SkinPicker
    local calls = {}
    H.SkinPicker = function(spec)
        calls[#calls + 1] = spec
        return { spy = true }
    end
    local ok, err = pcall(fn, calls)
    H.SkinPicker = real
    if not ok then error(err, 0) end
end

--- The login start's AceTimer entry on the kit's queue: the one with the two-second delay.
local function loginFuse(mock)
    for _, e in ipairs(mock.__timers) do
        if e.delay == 2 then return e end
    end
end

local function skinLib(mock) return mock.LibStub("LibKa0s-Skin-1.0") end
local function worn(mock) return select(2, skinLib(mock):GetChoice(OWNER)) end
local function stored(NS) return select(2, NS.SkinChoice()) end

--- Open the window's list and click the row for skin `key`, as the player does. The rows are the
--- list's children, read off the mock's frame list.
local function pickRow(mock, f, key)
    f.dd.__fire("OnClick")
    local hit = false
    for _, r in ipairs(mock.frames) do
        if r.__parent == f.list and r.key == key then r.__fire("OnClick"); hit = true end
    end
    assertTrue(hit, "no row for " .. key)
end

--- The real window, shown for this instance's owner.
local function window(NS)
    local f = NS.MaybeShowSkinPicker()
    assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
    return f
end

-- ── the key and the spec ─────────────────────────────────────────────────────────────────────

test("skin picker: pickerSeen defaults to false, a skip-render row on the Appearance group", function()
    -- red under: a default of true (no profile would ever show it, O3), or a row that draws itself.
    local NS, _, _, H = enabled()
    assertEqual(NS.C.skin.pickerSeen, false)
    assertEqual(H.Get(PATH), false)
    local row = H.FindSchema(PATH)
    assertTrue(row ~= nil, PATH .. " is not a schema row")
    assertEqual(row.type, "bool")
    assertEqual(row.group, "Appearance")
end)

test("skin picker: the spec names this owner, its seams, General's Skin tab and the eye", function()
    -- red under: a set that is not the write seam (Apply would save nothing), or a page key the
    -- library cannot find (the gear would open the landing page, or nothing).
    local NS, _, _, H = enabled()
    local spec = NS.SkinPickerSpec()
    assertEqual(spec.owner, OWNER)
    assertTrue(rawequal(spec.get, NS.SkinChoice), "get is the read seam")
    assertTrue(rawequal(spec.set, NS.WriteSkinChoice), "set is the write seam")
    assertEqual(spec.page, "general")
    assertEqual(spec.tab, "Appearance", "the Skin tab's key")
    assertTrue(H.__panelFor("general") ~= nil, "\"general\" is the page key the library finds")
    assertEqual(type(spec.onPreview), "function", "X6: this addon has a test mode, so the eye shows")
    assertEqual(type(spec.onClose), "function")
end)

-- ── when it shows ────────────────────────────────────────────────────────────────────────────

test("skin picker: an unseen profile shows it; a seen one does not", function()
    local NS, _, _, H = enabled()
    spying(H, function(calls)
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 1, "pickerSeen false: the picker shows")
        assertEqual(calls[1].owner, OWNER)
        H.Set(PATH, true)
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 1, "pickerSeen true: it does not show again")
    end)
end)

test("skin picker: it shows two seconds after login, through the addon's own AceTimer", function()
    -- red under: dropping the call from OnEnable, showing it inside OnEnable (the boot path,
    -- inventory R8), or a C_Timer.After the stand-down cannot cancel.
    local NS, _, mock = T.bootAddon()
    NS.Print = function() end
    local H = NS.addon.Settings.Helpers
    spying(H, function(calls)
        NS.addon:OnEnable()
        assertEqual(#calls, 0, "nothing shows inside OnEnable")
        local fuse = loginFuse(mock)
        assertTrue(fuse ~= nil, "OnEnable lit no two-second AceTimer")
        assertEqual(mock.__fireTimers(), 1)
        assertEqual(#calls, 1, "the login fuse shows the picker")
    end)
end)

test("skin picker: a stand-down before the fuse fires cancels the login start", function()
    -- red under: a NS.StandDown without HideSkinPicker (the fuse would still run) AND a fuse that
    -- does not re-check the stand-down when it fires.
    local NS, _, mock, H = enabled()
    assertTrue(loginFuse(mock) ~= nil, "OnEnable lit the login start")
    H.Set("enabled", false)
    assertTrue(NS.IsStoodDown(), "the switch stood the addon down")
    spying(H, function(calls)
        assertEqual(mock.__fireTimers(), 0, "the stand-down canceled the login start")
        assertEqual(#calls, 0, "a disabled addon shows no picker")
    end)
end)

test("skin picker: in combat a start waits for combat end, once", function()
    -- red under: an unguarded show in combat, or a held start that is never replayed.
    local NS, _, mock, H = enabled()
    spying(H, function(calls)
        mock.combat = true
        assertNil(NS.MaybeShowSkinPicker())
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 0, "nothing shows in combat")
        mock.combat = false
        mock.__fireEvent("PLAYER_REGEN_ENABLED")
        assertEqual(#calls, 1, "combat's end shows it, once for two held starts")
        mock.__fireEvent("PLAYER_REGEN_ENABLED")
        assertEqual(#calls, 1, "the queue slot is spent")
    end)
end)

test("skin picker: a held start is dropped by HideSkinPicker", function()
    local NS, _, mock, H = enabled()
    spying(H, function(calls)
        mock.combat = true
        NS.MaybeShowSkinPicker()
        NS.HideSkinPicker()
        mock.combat = false
        mock.__fireEvent("PLAYER_REGEN_ENABLED")
        assertEqual(#calls, 0, "a dropped start must not fire on the combat edge")
    end)
end)

test("skin picker: never while the addon is switched off", function()
    local NS, _, _, H = enabled()
    spying(H, function(calls)
        H.Set("enabled", false)
        assertTrue(NS.IsStoodDown(), "the switch stood the addon down")
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 0, "a disabled addon shows no picker")
    end)
end)

test("skin picker: a new profile and a reset profile show it again", function()
    -- O3: both start from the defaults, pickerSeen false. red under: no call on reloadProfile, or
    -- one before the latch re-reads the incoming profile's switch.
    local NS, _, _, H = enabled()
    local db = NS.addon.db
    H.Set(PATH, true)
    spying(H, function(calls)
        db:SetProfile("PickerProbe")
        assertEqual(#calls, 1, "a new profile shows the picker")
        H.Set(PATH, true)
        db:ResetProfile()
        assertEqual(#calls, 2, "a reset profile shows it again")
        H.Set(PATH, true)
        db:SetProfile("Default")
        assertEqual(#calls, 2, "back on a profile that has seen it: no picker")
    end)
end)

-- ── the real window ──────────────────────────────────────────────────────────────────────────

-- LibKa0s v1.81.0 (OptionsSkinPicker minor 2, ruling R-11): the title no longer carries the addon's
-- name, which the client cut off; the name has its own line above the dropdown, frame.ownerLabel.
test("skin picker: the title asks for a skin and the addon's name sits above the dropdown", function()
    local NS = enabled()
    local f = window(NS)
    assertEqual(f.title:GetText(), "Choose a skin", "the title carries no addon name")
    assertTrue(f.ownerLabel ~= nil, "the picker has its owner line")
    assertEqual(f.ownerLabel:GetText(), NS.BRAND_NAME, "the owner line names this addon")
end)

test("skin picker: the player's close marks it seen; this addon's own hide does not", function()
    local NS, _, _, H = enabled()
    local f = window(NS)
    NS.HideSkinPicker()
    assertFalse(f:IsShown(), "the quiet hide takes the window down")
    assertEqual(H.Get(PATH), false, "a quiet hide is not the player's close")
    f = window(NS)
    f.close.__fire("OnClick")
    assertFalse(f:IsShown(), "the close control closes the window")
    assertEqual(H.Get(PATH), true, "the player's close sets pickerSeen")
    assertNil(NS.MaybeShowSkinPicker(), "and it does not show again")
end)

test("skin picker: a profile that has seen it takes a shown picker down, unmarked", function()
    local NS = enabled()
    local f = window(NS)
    NS.addon.db.profile.skin.pickerSeen = true
    NS.MaybeShowSkinPicker()
    assertFalse(f:IsShown(), "the picker stayed up on a profile that has seen it")
end)

test("skin picker: a pick previews, unsaved; Apply saves it and marks the picker seen", function()
    local NS, _, mock, H = enabled()
    local f = window(NS)
    pickRow(mock, f, "obsidian")
    assertEqual(worn(mock), "obsidian", "the pick is worn at once")
    assertEqual(stored(NS), "ka0s", "a pick alone writes nothing to the profile")
    assertEqual(H.Get(PATH), false, "a pick does not end the showing")
    f.apply.__fire("OnClick")
    assertFalse(f:IsShown(), "Apply closes the window")
    assertEqual(stored(NS), "obsidian", "Apply saves through NS.WriteSkinChoice")
    assertEqual(H.Get(PATH), true, "Apply marks the picker seen")
end)

test("skin picker: the close control puts the stored skin back and saves nothing", function()
    local NS, _, mock = enabled()
    local f = window(NS)
    pickRow(mock, f, "obsidian")
    f.close.__fire("OnClick")
    assertEqual(worn(mock), "ka0s", "closing puts back the stored skin")
    assertEqual(stored(NS), "ka0s", "and writes nothing")
end)

test("skin picker: the gear saves the pick and opens General on its Skin tab", function()
    -- red under: a page key the library does not know, or a tab key that is not the Skin tab's.
    local NS, _, mock, H = enabled()
    local f = window(NS)
    local realOpen, opened = H.OpenOptionsPanel, {}
    H.OpenOptionsPanel = function(page) opened[#opened + 1] = page; return realOpen(page) end
    local ok, err = pcall(function()
        pickRow(mock, f, "obsidian")
        f.settings.__fire("OnClick")
    end)
    H.OpenOptionsPanel = realOpen
    if not ok then error(err, 0) end
    assertEqual(#opened, 1, "the gear opens the settings once")
    assertEqual(opened[1], "general", "on this addon's General page")
    assertEqual(H.__panelFor("general").activeTab, "Appearance", "on its Skin tab")
    assertFalse(f:IsShown(), "the gear closes the window")
    assertEqual(stored(NS), "obsidian", "the gear saves the pending pick")
    assertEqual(H.Get(PATH), true, "and marks the picker seen")
end)

test("skin picker: the eye starts the popup's test mode and leaves the picker up", function()
    -- X6: the preview is this addon's own window wearing the skin. red under: an eye that opens
    -- nothing, or one that bypasses the session row (the Master controls box would read unticked).
    local NS, _, mock, H = enabled()
    local f = window(NS)
    f.preview.__fire("OnClick")
    assertTrue(NS.State.testMode == true, "the eye did not start test mode")
    assertTrue(H.Get("state.testMode") == true, "through the session row /wg test on writes")
    local popup = mock.frames["WhatGroupFrame"]
    assertTrue(popup ~= nil and popup:IsShown(), "the eye did not show the popup")
    assertTrue(f:IsShown(), "the eye leaves the picker up")
    f.preview.__fire("OnClick")
    assertTrue(NS.State.testMode == true, "a second click keeps test mode on")
end)

test("skin picker: a profile switch with a preview pending wears the new profile's skin", function()
    -- red under: taking the picker down after the new profile's skin is applied (its put-back would
    -- wear the old profile's skin over the new one's).
    local NS, _, mock, H = enabled()
    local db = NS.addon.db
    db:SetProfile("PickerProbe")
    H.Set(PATH, true)
    NS.WriteSkinChoice("ka0s", "azeroth")
    NS.ApplySkinChoice()
    db:SetProfile("Default")
    local f = window(NS)
    pickRow(mock, f, "obsidian")
    db:SetProfile("PickerProbe")
    assertFalse(f:IsShown(), "a profile that has seen it takes the picker down")
    assertEqual(worn(mock), "azeroth", "the new profile's skin is worn, not the preview")
    db:SetProfile("Default")
    assertEqual(worn(mock), "ka0s", "and back on Default, its own stored skin")
end)

test("skin picker: a switch to an unseen profile starts a fresh showing, the old preview dropped", function()
    -- The picker comes straight back up on a new profile (pickerSeen false), so the old showing has
    -- to be taken down FIRST: a second Helpers.SkinPicker call on a window that is up keeps its
    -- pending pick. red under: dropping reloadProfile's leading HideSkinPicker (Apply on the new
    -- profile would save the old profile's preview into it).
    local NS, _, mock = enabled()
    local f = window(NS)
    pickRow(mock, f, "obsidian")
    NS.addon.db:SetProfile("FreshProbe")
    assertTrue(f:IsShown(), "the new profile has not seen the picker: it shows again")
    assertEqual(worn(mock), "ka0s", "the new profile's skin is worn")
    f.apply.__fire("OnClick")
    assertEqual(stored(NS), "ka0s", "Apply on the fresh showing saved the old profile's preview")
end)

test("skin picker: the stand-down with a preview pending puts the old skin back, unseen", function()
    local NS, _, mock, H = enabled()
    local f = window(NS)
    pickRow(mock, f, "obsidian")
    H.Set("enabled", false)
    assertTrue(NS.IsStoodDown(), "the switch stood the addon down")
    assertFalse(f:IsShown(), "the stand-down takes the picker down")
    assertEqual(worn(mock), "ka0s", "the pending preview is put back")
    assertEqual(stored(NS), "ka0s", "and never saved")
    assertEqual(H.Get(PATH), false, "a stand-down is not the player's close")
end)

-- ── degraded ─────────────────────────────────────────────────────────────────────────────────

test("skin picker: degraded, there is no picker and nothing raises", function()
    local NS = T.newAddon{ skip = T.loadAddon.libFiles }
    NS.addon:OnInitialize()
    NS.addon:OnEnable()
    local ok, f = pcall(NS.MaybeShowSkinPicker)
    assertTrue(ok, "MaybeShowSkinPicker raised without the library: " .. tostring(f))
    assertNil(f, "the stub's SkinPicker answers nil")
    assertTrue(pcall(NS.HideSkinPicker), "HideSkinPicker raised without the library")
end)
