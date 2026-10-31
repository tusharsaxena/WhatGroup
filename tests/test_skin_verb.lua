-- tests/test_skin_verb.lua — the reserved `skin` verb (LibKa0s v1.82.0, OptionsSkinPicker minor 3's
-- O.SkinVerb; WG-01 of Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-16):
-- a `skin` row after `config` runs NS.RunSkinVerb, which hands O.SkinVerb the first-run spec, so
-- `/wg skin` shows the picker a new profile shows whatever skin.pickerSeen says. Refused while the
-- addon is disabled (the library dispatcher's gate: `skin` is a feature verb, not a live one), a
-- gray line on every call in combat (the library's), and the library-absent line without LibKa0s.

local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local REFUSAL = "WhatGroup is disabled"

local function run(NS, mock, input)
    local mark = #mock.prints
    NS.addon:OnSlashCommand(input)
    local out = {}
    for i = mark + 1, #mock.prints do out[#out + 1] = mock.prints[i] end
    return out
end

local function anyLine(lines, fragment)
    for _, l in ipairs(lines) do
        if tostring(l):find(fragment, 1, true) then return true end
    end
    return false
end

local function strings(mock) return mock.LibStub("LibKa0s-Options-1.0").SKIN_PICKER_STRINGS end

--- Logged in, the first-run picker stood down and the profile marked seen, so only the verb can
--- bring it back.
local function seenProfile()
    local NS, _, mock = T.enableAddon()
    NS.HideSkinPicker()
    NS.addon.db.profile.skin.pickerSeen = true
    return NS, mock, NS.addon.Settings.Helpers
end

--- Run `fn(calls)` with Helpers.SkinPicker replaced by a recorder that shows a stand-in frame.
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

test("skin verb: the row sits right after config, with the library's help words", function()
    local NS, _, mock = T.newAddon()
    local at
    for i, c in ipairs(NS.addon.COMMANDS) do
        if c[1] == "skin" then at = i end
    end
    assertTrue(at ~= nil, "a skin row")
    assertEqual(NS.addon.COMMANDS[at - 1][1], "config", "after config")
    assertEqual(NS.addon.COMMANDS[at][2], strings(mock).VERB_HELP, "one wording for every host")
end)

test("skin verb: /wg skin shows the picker on a profile that has closed it", function()
    -- red under: no skin row (the dispatcher answers "unknown command").
    local NS, mock, H = seenProfile()
    spying(H, function(calls)
        local out = run(NS, mock, "skin")
        assertEqual(#calls, 1, "the picker was asked for once")
        assertFalse(anyLine(out, "unknown command"), "a known verb")
    end)
end)

test("skin verb: the real picker comes up whatever pickerSeen says", function()
    local NS, mock = seenProfile()
    run(NS, mock, "skin")
    local f = select(1, NS.RunSkinVerb())
    assertTrue(f ~= nil and f:IsShown(), "the library's picker is up")
    assertEqual(f.title:GetText(), "Choose a skin")
end)

test("skin verb: NS.RunSkinVerb hands O.SkinVerb this addon's first-run spec", function()
    local NS, _, H = seenProfile()
    local live, seen = H.SkinVerb, nil
    H.SkinVerb = function(spec) seen = spec; return nil, "queued" end
    local win, why = NS.RunSkinVerb()
    H.SkinVerb = live
    assertTrue(type(seen) == "table", "a spec was handed over")
    assertEqual(seen.owner, "WhatGroup")
    assertTrue(seen.get == NS.SkinChoice and seen.set == NS.WriteSkinChoice, "the two seams")
    assertEqual(seen.page, "general")
    assertEqual(seen.tab, "Appearance")
    assertTrue(win == nil, "nothing shown")
    assertEqual(why, "queued", "the library's reason, passed on")
end)

test("skin verb: in combat every call prints the library's gray line and shows nothing", function()
    local NS, mock, H = seenProfile()
    mock.combat = true
    spying(H, function(calls)
        local first = run(NS, mock, "skin")
        local second = run(NS, mock, "skin")
        assertEqual(#calls, 0, "no picker mid-combat")
        assertTrue(anyLine(first, strings(mock).VERB_COMBAT), "the first call says why")
        assertTrue(anyLine(second, strings(mock).VERB_COMBAT), "and so does every later one")
    end)
    mock.combat = false
end)

test("skin verb: refused while the addon is disabled, and no picker shows", function()
    local NS, mock, H = seenProfile()
    NS.addon:OnSlashCommand("disable")
    spying(H, function(calls)
        local out = run(NS, mock, "skin")
        -- red under: no skin row (an unknown verb prints the help index, whose header line also
        -- says the addon is disabled, so the one-line count is what tells the two apart).
        assertEqual(#out, 1, "one refusal line")
        assertTrue(anyLine(out, REFUSAL), "the disabled line")
        assertEqual(#calls, 0, "no picker while disabled")
    end)
end)

test("skin verb: without LibKa0s the verb prints the library-absent line", function()
    local NS, _, mock = T.newAddon{ skip = T.loadAddon.libFiles }
    NS.addon:OnInitialize()
    local out = run(NS, mock, "skin")
    assertTrue(anyLine(out, "/wg skin is unavailable: the LibKa0s library did not load."), "names the verb")
    local win, why = NS.RunSkinVerb()
    assertTrue(win == nil)
    assertEqual(why, "absent")
end)
