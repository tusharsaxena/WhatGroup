-- tests/test_envsetup.lua — core/EnvSetup.lua, the LibKa0s-Env-1.0 seam.
--
-- What is asserted here is THE SEAM, not the library. The library's own suite covers the ladder
-- inside GetAddOnMetadata; a second copy of those cases here is exactly the consumer-side
-- duplication testing-§8 forbids. What only this repo can check is that this addon's helpers answer
-- what its two INLINE copies answered, that they ask about THIS addon, and that the copies are gone.
--
-- This addon stamps neither a zone nor a map id, so the seam publishes NS.Meta and NS.Version only
-- and there is nothing here about either.

local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertNil

-- The library files that ARE the payload, for the degraded case — the same list, and the same
-- reason, as tests/test_mediasetup.lua: Core.lua absent means every other major returns before
-- LibStub:NewLibrary too, so this is the whole-library-missing scenario rather than an Env-only one.
local NO_LIBKA0S = {
    "libs/LibKa0s/Core.lua", "libs/LibKa0s/Env.lua", "libs/LibKa0s/Pool.lua",
    "libs/LibKa0s/Item.lua", "libs/LibKa0s/Media.lua", "libs/LibKa0s/Widgets.lua",
    "libs/LibKa0s/DebugLog.lua",
    "libs/LibKa0s/Slash.lua", "libs/LibKa0s/Options.lua", "libs/LibKa0s/OptionsWidgets.lua",
    "libs/LibKa0s/OptionsScroll.lua", "libs/LibKa0s/Perf.lua", "libs/LibKa0s/PerfPanel.lua",
}

-- ---------------------------------------------------------------------------
-- The seam
-- ---------------------------------------------------------------------------

test("envsetup: NS.Meta reads this addon's TOC", function()
    local NS = T.newAddon()
    assertEqual(NS.Meta("Version"), "1.3.0")
    assertEqual(NS.Meta("Notes"), "Tells you what group you just joined.")
end)

test("envsetup: NS.Meta asks about this addon's FOLDER, not its title or its frame prefix",
    function()
        -- The one thing the library cannot get right on its own: LibKa0s is vendored, so the folder
        -- name has to come from the host's first vararg. "WhatGroup", "Ka0s WhatGroup" and "[WG]"
        -- are all live strings in this repo and only the first is the folder; a wrong one reads
        -- another addon's manifest, or none, and answers nil without raising a thing. The deleted
        -- settings/Panel.lua copy typed the folder name as a LITERAL, which is the spelling that
        -- goes stale silently.
        local asked = {}
        local NS = T.newAddon{ mock = function(m)
            m.C_AddOns = { GetAddOnMetadata = function(name, field)
                asked[#asked + 1] = name
                return field == "Version" and "9.9.9" or nil
            end }
        end }
        assertEqual(NS.Meta("Version"), "9.9.9")
        assertEqual(asked[1], "WhatGroup")
    end)

test("envsetup: NS.Meta degrades to nil when the client exposes no manifest reader", function()
    -- The behaviour both inline copies had: nil, never a raise. Panel's caller supplies "" and
    -- Slash's supplies the in-code constant, which only works because this answers rather than
    -- throws.
    local NS = T.newAddon{ mock = function(m) m.C_AddOns = nil end }
    assertNil(NS.Meta("Version"))
end)

test("envsetup: NS.Version prefers the TOC over this addon's own constant", function()
    -- A packaged addon whose TOC can be read must never report the constant somebody forgot to
    -- edit, which is what the deleted settings/Slash.lua ladder was for.
    local NS = T.newAddon{ mock = function(m)
        m.C_AddOns = { GetAddOnMetadata = function(_name, field)
            return field == "Version" and "9.9.9" or nil
        end }
    end }
    assertEqual(NS.Version(), "9.9.9")
end)

test("envsetup: NS.Version falls back to this addon's own constant", function()
    -- The fallback lives at the call site rather than in the library, because which constant this
    -- addon falls back to is genuinely its own business — so it is the seam's job to prove it still
    -- works. No reader is stubbed here, which is what a client that cannot answer looks like.
    local NS = T.newAddon{ mock = function(m) m.C_AddOns = nil end }
    local v = NS.Version()
    assertEqual(v, NS.addon.VERSION)
    assertTrue(v ~= nil and v ~= "", "a version string, never nil — it goes straight into a banner")
end)

test("envsetup degraded: an install with no LibKa0s still reads its own TOC", function()
    -- The case that earns the written-out fallbacks. Without LibKa0s the seam answers nil for
    -- everything unless it repeats the ladder the two inline copies ran, and nil is not an error a
    -- player would ever see reported: it is a blank Notes line on the options panel and a blank
    -- version in the slash banner. Nothing here loads the library, so this runs the else-branch of
    -- both helpers.
    local NS = T.newAddon{ skip = NO_LIBKA0S }
    assertEqual(NS.Meta("Version"), "1.3.0")
    assertEqual(NS.Version(), "1.3.0")
end)

-- ---------------------------------------------------------------------------
-- The copies are gone
-- ---------------------------------------------------------------------------

test("envsetup: no file inlines its own C_AddOns ladder any more", function()
    -- Both of this addon's copies were INLINE, at the call site, where no audit of core/Compat.lua
    -- would ever have found them. A seam that leaves one in place is a second answer nobody
    -- removed, and the next caller copies whichever one it lands on first — which is how there came
    -- to be eleven of these across nine addons.
    local hits = 0
    for _, path in ipairs({ "settings/Slash.lua", "settings/Panel.lua" }) do
        local f = io.open(path)
        local body = f:read("*a"); f:close()
        local _, n = body:gsub("C_AddOns%s*and%s*C_AddOns%.GetAddOnMetadata", "")
        local _, m = body:gsub("_G%.GetAddOnMetadata", "")
        hits = hits + n + m
    end
    assertEqual(hits, 0, "the ladder belongs in core/EnvSetup.lua and nowhere else")
end)

test("envsetup: the ladder did not land in Compat either", function()
    -- This addon never had a Compat.GetAddOnMetadata — both copies were inline — so this is not the
    -- deletion the other adoptions assert but the same invariant stated forwards: core/Compat.lua
    -- is for the version-variant spell and LFG APIs that are genuinely WhatGroup's, and the TOC
    -- reader that nine addons shared is not one of them.
    local NS = T.newAddon()
    assertNil(NS.Compat.GetAddOnMetadata)
end)
